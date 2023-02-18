import CinderSocket from "./cinder/socket";
import CinderComponent from "./cinder/component";

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
