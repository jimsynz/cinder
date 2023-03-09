import Cinder from "../cinder";
import * as Messages from "./messages";

interface SendOptions {
  replyTimeout?: number;
}

interface InFlight {
  message: Messages.Command;
  resolve: (value: Messages.Reply | PromiseLike<Messages.Reply>) => void;
  reject: (reason?: any) => void;
  timerId: number;
}

const defaultSendOptions: SendOptions = {
  replyTimeout: 5000,
};

export default class CinderSocket {
  socket: WebSocket;
  url: string;
  requestId: string;
  cinder: Cinder;
  inFlight: Map<string, InFlight>;

  constructor(cinder: Cinder) {
    this.cinder = cinder;
    this.inFlight = new Map();

    let wsp = 'wss:';
    if (window.location.protocol === 'http:') {
      wsp = 'ws:';
    }

    this.url = `${wsp}//${window.location.host}/ws`;
  }

  connect(requestId: string) {
    this.requestId = requestId;
    this.socket = new WebSocket(this.url);

    this.cancelAllInFlight("Establishing new connection");

    this.socket.addEventListener('error', (event) => {
      this.cancelAllInFlight(event);
      console.log(`Error from ${this.url}.`);
      console.log(event);
    });


    let defaultCloseHandler = (_event: Event) => {
      this.cancelAllInFlight("Disconnected during server connection");
    };

    this.socket.addEventListener('close', defaultCloseHandler);

    this.socket.addEventListener('message', (event) => {
      let json = JSON.parse(event.data);

      if (json.hasOwnProperty('replyTo')) {
        let inFlight = this.inFlight.get(json.replyTo);
        if (inFlight) {
          this.inFlight.delete(json.replyTo);
          clearTimeout(inFlight.timerId);
          let reply = new Messages.Reply(inFlight.message, json.ok);
          reply.data = new Map(Object.entries(json.data));
          if (reply.ok) {
            inFlight.resolve(reply);
          } else {
            inFlight.reject(reply);
          }
        }
      } else if (json.hasOwnProperty('command')) {
        switch (json.command) {
          case "rerender":
            let message = new Messages.Rerender(json.data.page, json.id);
            this.cinder.executeCommand(message);
          default: break;
        }
      }
    });

    this.socket.addEventListener('open', (_event) => {
      this.send(new Messages.Connect(this.requestId)).then((reply: Messages.Reply) => {
        this.cinder.socket = this;
        // Emit a connected event.

        this.socket.removeEventListener('close', defaultCloseHandler);

        this.socket.addEventListener('close', (_event) => {
          this.connect(this.requestId);
        });
      }).catch((error) => {
        console.error("Unable to connect to Cinder: " + error);
      });
    });

  }

  private cancelAllInFlight(reason) {
    this.inFlight.forEach((inFlight) => {
      clearTimeout(inFlight.timerId);
      inFlight.reject(reason);
    });
  }

  send(message: Messages.Command, options?: SendOptions): Promise<Messages.Reply> {
    let opts = options || defaultSendOptions;

    return new Promise((resolve, reject) => {
      let json = message.toJSON();
      this.socket.send(json);
      if (message.expectsReply) {

        let timerId = setTimeout(() => {
          if (this.inFlight.has(message.id)) {
            this.inFlight.delete(message.id);
            reject(new Error('Timeout waiting for reply from the server'));
          }
        }, opts.replyTimeout);

        this.inFlight.set(message.id, { message, resolve, reject, timerId });

      } else {
        resolve(new Messages.Reply(message, true));
      }
    });
  }
}
