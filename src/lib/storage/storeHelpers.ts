/**
 * Execute a mutation with optimistic UI update and snapshot rollback on persistence failure.
 */
export async function withStorageRollback<T>(
  mutate: () => void,
  persist: () => Promise<T>,
  rollback: () => void
): Promise<void> {
  mutate();
  try {
    await persist();
  } catch (error) {
    rollback();
    throw error;
  }
}

export function createMutationQueue() {
  let queue: Promise<unknown> = Promise.resolve();

  function enqueue(operation: () => Promise<void>): Promise<void> {
    const result = queue.then(operation);
    queue = result.catch(() => {});
    return result;
  }

  async function flush(): Promise<void> {
    await queue;
  }

  return { enqueue, flush };
}
