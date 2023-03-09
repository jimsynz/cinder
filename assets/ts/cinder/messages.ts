function uniqueId() {
  let buffer = new Uint8Array(16);
  window.crypto.getRandomValues(buffer);
  return btoa(buffer.toString());
}

class Command {
  commandName: string;
  id: string;
  data: Map<string, any>;
  expectsReply: boolean = false;

  constructor(commandName: string, id?: string) {
    this.id = id || uniqueId();
    this.commandName = commandName;
    this.data = new Map<string, any>();
  }

  toJSON() {
    return JSON.stringify({
      command: this.commandName,
      data: this.data,
      id: this.id,
    }, this.jsonReplacer);
  }

  private jsonReplacer(_key: any, value: any) {
    if (value instanceof Map) {
      return Object.fromEntries(value);
    }
    return value;
  }
}

class Reply {
  command: Command;
  data: Map<string, any>;
  ok: boolean;

  constructor(command: Command, ok?: boolean) {
    this.command = command;
    this.data = new Map<string, any>();
    this.ok = ok || false;
  }
}

class Connect extends Command {
  constructor(requestId: string) {
    super('connect');
    this.data.set('requestId', requestId);
    this.expectsReply = true;
  }
}

class TransitionTo extends Command {
  constructor(target: string) {
    super('transitionTo');
    this.data.set('target', target);
  }
}

class Rerender extends Command {
  constructor(page: string, id: string) {
    super('rerender', id);
    this.data.set('page', page);
  }
}

export { Command, Connect, Reply, Rerender, TransitionTo };
