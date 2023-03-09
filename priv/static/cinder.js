(() => {
  var __defProp = Object.defineProperty;
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };

  // ts/cinder/messages.ts
  function uniqueId() {
    let buffer = new Uint8Array(16);
    window.crypto.getRandomValues(buffer);
    return btoa(buffer.toString());
  }
  var Command = class {
    constructor(commandName, id) {
      this.expectsReply = false;
      this.id = id || uniqueId();
      this.commandName = commandName;
      this.data = /* @__PURE__ */ new Map();
    }
    toJSON() {
      return JSON.stringify({
        command: this.commandName,
        data: this.data,
        id: this.id
      }, this.jsonReplacer);
    }
    jsonReplacer(_key, value) {
      if (value instanceof Map) {
        return Object.fromEntries(value);
      }
      return value;
    }
  };
  var Reply = class {
    constructor(command, ok) {
      this.command = command;
      this.data = /* @__PURE__ */ new Map();
      this.ok = ok || false;
    }
  };
  var Connect = class extends Command {
    constructor(requestId) {
      super("connect");
      this.data.set("requestId", requestId);
      this.expectsReply = true;
    }
  };
  var TransitionTo = class extends Command {
    constructor(target) {
      super("transitionTo");
      this.data.set("target", target);
    }
  };
  var Rerender = class extends Command {
    constructor(page, id) {
      super("rerender", id);
      this.data.set("page", page);
    }
  };

  // ts/cinder/socket.ts
  var defaultSendOptions = {
    replyTimeout: 5e3
  };
  var CinderSocket = class {
    constructor(cinder) {
      this.cinder = cinder;
      this.inFlight = /* @__PURE__ */ new Map();
      let wsp = "wss:";
      if (window.location.protocol === "http:") {
        wsp = "ws:";
      }
      this.url = `${wsp}//${window.location.host}/ws`;
    }
    connect(requestId) {
      this.requestId = requestId;
      this.socket = new WebSocket(this.url);
      this.cancelAllInFlight("Establishing new connection");
      this.socket.addEventListener("error", (event) => {
        this.cancelAllInFlight(event);
        console.log(`Error from ${this.url}.`);
        console.log(event);
      });
      let defaultCloseHandler = (_event) => {
        this.cancelAllInFlight("Disconnected during server connection");
      };
      this.socket.addEventListener("close", defaultCloseHandler);
      this.socket.addEventListener("message", (event) => {
        let json = JSON.parse(event.data);
        if (json.hasOwnProperty("replyTo")) {
          let inFlight = this.inFlight.get(json.replyTo);
          if (inFlight) {
            this.inFlight.delete(json.replyTo);
            clearTimeout(inFlight.timerId);
            let reply = new Reply(inFlight.message, json.ok);
            reply.data = new Map(Object.entries(json.data));
            if (reply.ok) {
              inFlight.resolve(reply);
            } else {
              inFlight.reject(reply);
            }
          }
        } else if (json.hasOwnProperty("command")) {
          switch (json.command) {
            case "rerender":
              let message = new Rerender(json.data.page, json.id);
              this.cinder.executeCommand(message);
            default:
              break;
          }
        }
      });
      this.socket.addEventListener("open", (_event) => {
        this.send(new Connect(this.requestId)).then((reply) => {
          this.cinder.socket = this;
          this.socket.removeEventListener("close", defaultCloseHandler);
          this.socket.addEventListener("close", (_event2) => {
            this.connect(this.requestId);
          });
        }).catch((error) => {
          console.error("Unable to connect to Cinder: " + error);
        });
      });
    }
    cancelAllInFlight(reason) {
      this.inFlight.forEach((inFlight) => {
        clearTimeout(inFlight.timerId);
        inFlight.reject(reason);
      });
    }
    send(message, options) {
      let opts = options || defaultSendOptions;
      return new Promise((resolve, reject) => {
        let json = message.toJSON();
        this.socket.send(json);
        if (message.expectsReply) {
          let timerId = setTimeout(() => {
            if (this.inFlight.has(message.id)) {
              this.inFlight.delete(message.id);
              reject(new Error("Timeout waiting for reply from the server"));
            }
          }, opts.replyTimeout);
          this.inFlight.set(message.id, { message, resolve, reject, timerId });
        } else {
          resolve(new Reply(message, true));
        }
      });
    }
  };

  // ts/cinder/component.ts
  var component_exports = {};
  __export(component_exports, {
    default: () => CinderComponent
  });
  var CinderComponent = class {
    constructor(element, cinder) {
      this.element = element;
      this.cinder = cinder;
      this.eventHandlers = /* @__PURE__ */ new Map();
    }
    registerEvent(eventName, callback) {
      this.eventHandlers.set(eventName, callback);
      this.element.addEventListener(eventName, this);
    }
    handleEvent(event) {
      let handler = this.eventHandlers.get(event.type);
      if (handler) {
        handler.call(this.element, event);
        return;
      }
      console.warn(`Received unexpected event ${event.type}`);
    }
    supportedEvents() {
      return this.eventHandlers.keys;
    }
  };

  // ts/cinder.ts
  var Cinder = class {
    constructor(components) {
      this.components = components;
      window.cinder = this;
      window.addEventListener("load", () => {
        var _a;
        let requestId = (_a = document.querySelector('meta[name="cinder-request-id"]')) == null ? void 0 : _a.getAttribute("content");
        let mainElement = document.querySelector("[data-cinder-main]");
        if (requestId && mainElement) {
          this.mainElement = mainElement;
          this.socket = new CinderSocket(this);
          this.socket.connect(requestId);
          this.enableExistingComponents();
        } else {
          throw new Error("Cannot initialise Cinder application - no request ID found.");
        }
      });
    }
    transitionTo(target) {
      let command = new TransitionTo(target);
      this.socket.send(command).then((_) => {
        window.history.pushState({}, "", target);
      });
    }
    executeCommand(message) {
      if (message instanceof Rerender) {
        if (message.data.has("page")) {
          this.mainElement.innerHTML = message.data.get("page");
          this.enableExistingComponents();
        }
      }
    }
    enableExistingComponents() {
      document.querySelectorAll("[data-cinder-component]").forEach((element) => {
        if (element instanceof HTMLElement && element.dataset.cinderComponent && this.components.hasOwnProperty(element.dataset.cinderComponent)) {
          let componentClass = this.components[element.dataset.cinderComponent];
          if (componentClass) {
            new componentClass(element, this);
          }
        }
      });
    }
  };
})();
