export default class CinderComponent {
  element: HTMLElement;
  id: string;
  eventHandlers: Map<string, (event: Event) => void>;

  constructor(element: HTMLElement) {
    this.element = element;

    let maybeId = element.dataset['cinderId'];
    if (maybeId) {
      this.id = maybeId;
    } else {
      throw new Error('Missing "cinderId" data attribute');
    }
  }

  registerEvent(eventName: string, callback: (event: Event) => void) {
    this.eventHandlers[eventName] = callback;
    this.element.addEventListener(eventName, this);
  }

  handleEvent(event: Event) {
    let handler = this.eventHandlers[event.type];
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
