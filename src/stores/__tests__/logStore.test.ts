import { beforeEach, describe, expect, it } from 'vitest';
import { useLogStore } from '@/stores/logStore';
import { getImportanceFromContent } from '@/lib/constants';

describe('logStore', () => {
  beforeEach(() => {
    localStorage.clear();
    useLogStore.setState(useLogStore.getInitialState(), true);
  });

  it('adds a log', () => {
    useLogStore.getState().addLog('hello', 'daily', 'log');
    const logs = useLogStore.getState().logs;
    expect(logs).toHaveLength(6); // 5 demo + 1 new
    expect(logs[0].content).toBe('hello');
    expect(logs[0].colorTag).toBe('daily');
    expect(logs[0].category).toBe('log');
    expect(logs[0].importance).toBe(0);
  });

  it('updates a log', () => {
    const id = useLogStore.getState().logs[0].id;
    useLogStore.getState().updateLog(id, { content: 'updated' });
    expect(useLogStore.getState().logs[0].content).toBe('updated');
  });

  it('deletes a log', () => {
    const id = useLogStore.getState().logs[0].id;
    useLogStore.getState().deleteLog(id);
    expect(useLogStore.getState().logs).toHaveLength(4);
  });

  it('filters logs by search query', () => {
    useLogStore.getState().setSearchQuery('AI');
    const filtered = useLogStore.getState().getFilteredLogs();
    expect(filtered.length).toBeGreaterThan(0);
    expect(filtered.every((l) => l.content.toLowerCase().includes('ai'))).toBe(true);
  });

  it('filters logs by tag', () => {
    useLogStore.getState().setFilterTag('urgent');
    const filtered = useLogStore.getState().getFilteredLogs();
    expect(filtered.every((l) => l.colorTag === 'urgent')).toBe(true);
  });

  it('moves a log to idea', () => {
    const id = useLogStore.getState().logs[0].id;
    useLogStore.getState().moveToIdea(id);
    expect(useLogStore.getState().logs.find((l) => l.id === id)?.category).toBe('idea');
  });

  it('parses importance from content', () => {
    expect(getImportanceFromContent('plain')).toBe(0);
    expect(getImportanceFromContent('urgent !!')).toBe(2);
    expect(getImportanceFromContent('very urgent !!!')).toBe(3);
    expect(getImportanceFromContent('critical !!!!')).toBe(4);
  });
});
