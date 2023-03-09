import CinderSocket from "./cinder/socket";
import * as Messages from "./cinder/messages";

declare global {
  interface Window {
    cinder: Cinder;
  }
}

export * as Component from "./cinder/component";

export class Cinder {
  components: Object;
  socket: CinderSocket;
  mainElement: HTMLElement;

  constructor(components: Object) {
    this.components = components;
    window.cinder = this;

    window.addEventListener('load', () => {
      let requestId = document.querySelector('meta[name="cinder-request-id"]')?.getAttribute('content');
      let mainElement = document.querySelector('[data-cinder-main]');
      if (requestId && mainElement) {
        this.mainElement = mainElement as HTMLElement;
        this.socket = new CinderSocket(this)
        this.socket.connect(requestId);
        this.enableExistingComponents()
      }
      else {
        throw new Error("Cannot initialise Cinder application - no request ID found.");
      }
    });
  }

  transitionTo(target: string) {
    let command = new Messages.TransitionTo(target);
    this.socket.send(command).then((_) => {
      window.history.pushState({}, "", target);
    });
  }

  executeCommand(message: Messages.Command) {
    if (message instanceof Messages.Rerender) {
      if (message.data.has("page")) {
        this.mainElement.innerHTML = message.data.get("page");
        this.enableExistingComponents();
      }
    }
  }

  private enableExistingComponents() {
    document.querySelectorAll('[data-cinder-component]').forEach((element) => {
      if (element instanceof HTMLElement && element.dataset.cinderComponent && this.components.hasOwnProperty(element.dataset.cinderComponent)) {
        let componentClass = this.components[element.dataset.cinderComponent];
        if (componentClass) {
          new componentClass(element, this);
        }
      }
    });
  }
}
