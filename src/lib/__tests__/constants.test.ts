import { describe, expect, it } from 'vitest';
import {
  CATEGORY_LABELS,
  COLOR_TAGS,
  getImportanceFromContent,
  getImportanceDisplay,
} from '@/lib/constants';

describe('constants', () => {
  it('exports category labels', () => {
    expect(CATEGORY_LABELS.log.text).toBe('LOG');
    expect(CATEGORY_LABELS.idea.text).toBe('IDEA');
  });

  it('exports all color tags', () => {
    expect(COLOR_TAGS).toContain('urgent');
    expect(COLOR_TAGS).toContain('daily');
    expect(COLOR_TAGS).toHaveLength(6);
  });

  it('parses importance from content', () => {
    expect(getImportanceFromContent('')).toBe(0);
    expect(getImportanceFromContent('!!')).toBe(2);
    expect(getImportanceFromContent('!!!')).toBe(3);
    expect(getImportanceFromContent('!!!!')).toBe(4);
  });

  it('returns importance display', () => {
    expect(getImportanceDisplay(0)).toEqual({ mark: '', color: '' });
    expect(getImportanceDisplay(2)).toEqual({ mark: '!!', color: '#FF9F43' });
    expect(getImportanceDisplay(4)).toEqual({ mark: '!!!!', color: '#DC2626' });
  });
});
