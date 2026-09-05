/** A successful commit invalidates only the affected feature projections. */
export enum StorePartition {
  LOGS = 'logs',
  EMOTIONS = 'emotions',
  TASKS = 'tasks',
  ALL = 'all'
}

export class StoreChanges {
  private listeners: Array<(partition: StorePartition) => void> = [];

  subscribe(listener: (partition: StorePartition) => void): () => void {
    this.listeners.push(listener);
    return () => { this.listeners = this.listeners.filter((item) => item !== listener); };
  }

  publish(partition: StorePartition): void {
    for (const listener of this.listeners.slice()) {
      try {
        listener(partition);
      } catch (_) {
        // An observer cannot turn an already committed write into a reported
        // database failure or stop the other observers from seeing the commit.
        console.error('Flash feature projection update failed');
      }
    }
  }
}
