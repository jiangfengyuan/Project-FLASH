import type { LogItem } from '@/stores/logStore';
import type { ColorTag } from '@/lib/constants';

export interface LogFilterState {
  searchQuery: string;
  startDate: string | null;
  endDate: string | null;
  filterTags: ColorTag[];
  sortBy: 'newest' | 'oldest' | 'tag';
}

export function getFilteredLogs(logs: LogItem[], filters: LogFilterState): LogItem[] {
  const { searchQuery, filterTags, startDate, endDate, sortBy } = filters;
  const query = searchQuery.toLowerCase();

  const filtered = logs.filter((log) => {
    if (log.category !== 'log') return false;
    const matchesSearch = !query || log.content.toLowerCase().includes(query);
    const matchesTags = filterTags.length === 0 || filterTags.includes(log.colorTag);
    const matchesStart = !startDate || log.recordDate >= startDate;
    const matchesEnd = !endDate || log.recordDate <= endDate;
    return matchesSearch && matchesTags && matchesStart && matchesEnd;
  });

  if (sortBy === 'tag') {
    return [...filtered].sort((a, b) => a.colorTag.localeCompare(b.colorTag));
  }

  // Precompute timestamps once so the comparator does not parse ISO strings on every comparison.
  const withTimestamp = filtered.map((log) => ({
    log,
    timestamp: new Date(log.createdAt).getTime(),
  }));

  withTimestamp.sort((a, b) =>
    sortBy === 'oldest' ? a.timestamp - b.timestamp : b.timestamp - a.timestamp
  );

  return withTimestamp.map(({ log }) => log);
}
