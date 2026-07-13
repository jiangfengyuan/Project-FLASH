import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/**
 * Returns today's date as 'YYYY-MM-DD' in the user's local timezone.
 * Prefer this over `new Date().toISOString().split('T')[0]` which uses UTC.
 */
export function getTodayStr(date: Date = new Date()): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Parses a 'YYYY-MM-DD' string in the user's local timezone.
 * `new Date('YYYY-MM-DD')` can shift to the previous day in negative UTC offsets.
 * Throws on malformed input so invalid dates fail fast instead of producing an Invalid Date.
 */
export function parseLocalDate(dateStr: string): Date {
  const [year, month, day] = dateStr.split('-').map(Number);
  if (
    !Number.isFinite(year) ||
    !Number.isFinite(month) ||
    !Number.isFinite(day) ||
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > 31
  ) {
    throw new RangeError(`Invalid date string: ${dateStr}`);
  }
  return new Date(year, month - 1, day);
}
