import Cinder from "../cinder";

export default class CinderComponent {
  element: HTMLElement;
  id: string;
  eventHandlers: Map<string, (event: Event) => void>;
  cinder: Cinder;

  constructor(element: HTMLElement, cinder: Cinder) {
    this.element = element;
    this.cinder = cinder;
    this.eventHandlers = new Map<string, (event: Event) => void>();
  }

  registerEvent(eventName: string, callback: (event: Event) => void) {
    this.eventHandlers.set(eventName, callback);
    this.element.addEventListener(eventName, this);
  }

  handleEvent(event: Event) {
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
}
