export default class CinderSocket {
  socket: WebSocket;

  constructor(url: string, requestId: string) {
    this.socket = new WebSocket(url);

    this.socket.addEventListener('open', (event) => {
      console.log(`Connected to ${url}.`);
      console.log(event);
      this.socket.send(JSON.stringify({ request_id: requestId }));
    });

    this.socket.addEventListener('close', (event) => {
      console.log(`Disconnected from ${url}.`);
      console.log(event);
    });

    this.socket.addEventListener('message', (event) => {

      let parsed = JSON.parse(event.data);

      if (parsed.hasOwnProperty('replace_main')) {
        let main = document.querySelector('div[data="cinder-main"]')
        if (main) {
          main.innerHTML = parsed.replace_main;
        }
      }
    });

    this.socket.addEventListener('error', (event) => {
      console.log(`Error from ${url}.`);
      console.log(event);
    });
  }
}

window.addEventListener('load', () => {
  let wsp = 'wss:';
  if (window.location.protocol === 'http:') {
    wsp = 'ws:';
  }

  let url = `${wsp}//${window.location.host}/ws`;
  let requestId = document.querySelector('meta[name="cinder-request-id"]')?.getAttribute('content');
  if (url && requestId) {
    let socket = new CinderSocket(url, requestId);
    window.cinderSocket = socket;
  }
});
