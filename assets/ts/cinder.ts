export default class CinderSocket {
  socket: WebSocket;
  url: string;
  requestId: string;
  path: string;

  constructor(url: string, requestId: string, path: string) {
    this.url = url;
    this.requestId = requestId;
    this.path = path;
  }

  connect() {
    this.socket = new WebSocket(this.url);

    this.socket.addEventListener('open', (event) => {
      this.socket.send(JSON.stringify({ request_id: this.requestId, path: this.path }));
    });

    this.socket.addEventListener('close', (event) => {
      this.connect();
    });

    this.socket.addEventListener('message', (event) => {
      let parsed = JSON.parse(event.data);

      if (parsed.hasOwnProperty('replace_main')) {
        let main = document.querySelector('div[data="cinder-main"]')
        if (main) {
          main.innerHTML = parsed.replace_main;
        }
      }

      if (parsed.hasOwnProperty('status') && parsed.hasOwnProperty('request_id') && parsed.status === 'connected') {
        this.requestId = parsed.request_id;
      }
    });

    this.socket.addEventListener('error', (event) => {
      console.log(`Error from ${this.url}.`);
      console.log(event);
    });
  }
}

declare global {
  interface Window {
    cinderSocket: CinderSocket;
  }
}

window.addEventListener('load', () => {
  let wsp = 'wss:';
  if (window.location.protocol === 'http:') {
    wsp = 'ws:';
  }

  let url = `${wsp}//${window.location.host}/ws`;
  let requestId = document.querySelector('meta[name="cinder-request-id"]')?.getAttribute('content');
  let path = `${window.location.pathname}${window.location.search}`;
  if (url && requestId && path) {
    let socket = new CinderSocket(url, requestId, path);
    socket.connect();
    window.cinderSocket = socket;
  }
});
