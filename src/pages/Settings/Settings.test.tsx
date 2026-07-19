import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import Settings from './index';
import { useLogStore } from '@/stores/logStore';
import { useEmotionStore } from '@/stores/emotionStore';
import { useToastStore } from '@/stores/toastStore';
import { exportBackup, MAX_BACKUP_SIZE_BYTES } from '@/lib/backup';
import * as storageModule from '@/lib/storage';
import { MemoryStorageAdapter } from '@/lib/storage/memoryAdapter';
import type { LogItem } from '@/stores/logStore';
import type { EmotionRecord } from '@/stores/emotionStore';

vi.mock('@/lib/storage', async () => {
  const actual = await vi.importActual<typeof storageModule>('@/lib/storage');
  const { MemoryStorageAdapter } = actual;
  return {
    ...actual,
    getStorageAdapter: vi.fn(async () => {
      const adapter = new MemoryStorageAdapter();
      await adapter.init();
      return adapter;
    }),
  };
});

const VALID_LOG_ID = 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1';
const VALID_EMOTION_ID = 'b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2';

const makeValidLog = (id: string): LogItem => ({
  id,
  content: 'valid log',
  colorTag: 'daily',
  category: 'log',
  importance: 0,
  createdAt: '2026-07-13T10:00:00.000Z',
  recordDate: '2026-07-13',
});

const makeValidEmotion = (id: string): EmotionRecord => ({
  id,
  level: 1,
  subEmotion: null,
  status: null,
  note: null,
  recordDate: '2026-07-13',
  createdAt: '2026-07-13T10:00:00.000Z',
});

const selectFile = (content: unknown) => {
  const input = screen.getByTestId('import-file-input');
  const file = new File([JSON.stringify(content)], 'backup.json', {
    type: 'application/json',
  });
  fireEvent.change(input, { target: { files: [file] } });
};

describe('Settings', () => {
  beforeEach(() => {
    useLogStore.setState({ logs: [] });
    useEmotionStore.setState({ emotions: [] });
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('renders export and import buttons', () => {
    render(<Settings />);
    expect(screen.getByText('导出备份')).toBeInTheDocument();
    expect(screen.getByText('导入备份')).toBeInTheDocument();
  });

  it('rejects import files larger than the backup size limit', async () => {
    render(<Settings />);

    const input = screen.getByTestId('import-file-input');
    const oversized = new File(['x'.repeat(MAX_BACKUP_SIZE_BYTES + 1)], 'oversized.json', {
      type: 'application/json',
    });
    fireEvent.change(input, { target: { files: [oversized] } });

    await waitFor(() => {
      expect(useToastStore.getState().toast?.message).toBe('文件过大，请检查是否为 Flash 备份');
    });
  });

  it('opens export drawer when export button is clicked', () => {
    render(<Settings />);
    fireEvent.click(screen.getByText('导出备份'));
    // The drawer opens; clicking export inside would show toast; test the drawer presence instead
    expect(screen.getByPlaceholderText(/备份/i)).toBeInTheDocument();
  });

  it('clears stale import issues when a new file is selected', async () => {
    render(<Settings />);

    const invalidBackup = exportBackup([{ id: 'not-a-uuid' } as unknown as LogItem], []);
    selectFile(invalidBackup);

    await waitFor(() => {
      expect(screen.getByText('备份中没有可导入的有效记录，未执行覆盖')).toBeInTheDocument();
    });

    const validBackup = exportBackup(
      [makeValidLog(VALID_LOG_ID)],
      [makeValidEmotion(VALID_EMOTION_ID)]
    );
    selectFile(validBackup);

    await waitFor(() => {
      expect(screen.queryByText('备份中没有可导入的有效记录，未执行覆盖')).not.toBeInTheDocument();
    });
    expect(screen.getByTestId('preview-log-count')).toHaveTextContent('1');
    expect(screen.getByTestId('preview-emotion-count')).toHaveTextContent('1');
    expect(screen.getByRole('button', { name: '合并导入' })).toBeEnabled();
  });

  it('blocks overwrite when the backup has no valid records', async () => {
    useLogStore.setState({ logs: [makeValidLog(VALID_LOG_ID)] });
    useEmotionStore.setState({ emotions: [makeValidEmotion(VALID_EMOTION_ID)] });

    render(<Settings />);

    const invalidBackup = exportBackup(
      [{ id: 'bad', content: 123 } as unknown as LogItem],
      [{ id: 'bad', level: 99 } as unknown as EmotionRecord]
    );
    selectFile(invalidBackup);

    await waitFor(() => {
      expect(screen.getByText('确认导入')).toBeInTheDocument();
    });

    fireEvent.click(screen.getByText('覆盖导入'));

    const importButton = screen.getByRole('button', { name: '无法导入' });
    expect(importButton).toBeDisabled();

    fireEvent.click(importButton);

    expect(useLogStore.getState().logs).toHaveLength(1);
    expect(useEmotionStore.getState().emotions).toHaveLength(1);
    expect(screen.getByText('备份中没有可导入的有效记录，未执行覆盖')).toBeInTheDocument();
  });

  it('overwrite import replaces storage contents via replaceAll, dropping old records', async () => {
    const replaceAllSpy = vi.spyOn(MemoryStorageAdapter.prototype, 'replaceAll');
    const saveLogsSpy = vi.spyOn(MemoryStorageAdapter.prototype, 'saveLogs');

    const NEW_LOG_ID = 'c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3';
    const NEW_EMOTION_ID = 'd4d4d4d4-d4d4-d4d4-d4d4-d4d4d4d4d4d4';

    useLogStore.setState({ logs: [makeValidLog(VALID_LOG_ID)] });
    useEmotionStore.setState({ emotions: [makeValidEmotion(VALID_EMOTION_ID)] });

    render(<Settings />);

    const backup = exportBackup([makeValidLog(NEW_LOG_ID)], [makeValidEmotion(NEW_EMOTION_ID)]);
    selectFile(backup);

    await waitFor(() => {
      expect(screen.getByText('确认导入')).toBeInTheDocument();
    });

    fireEvent.click(screen.getByText('覆盖导入'));
    fireEvent.click(screen.getByRole('button', { name: '确认覆盖' }));

    await waitFor(() => {
      expect(replaceAllSpy).toHaveBeenCalledTimes(1);
    });

    // Storage is replaced with only the backup records; pre-existing ones are dropped.
    const [logsArg, emotionsArg] = replaceAllSpy.mock.calls[0];
    expect(logsArg.map((l) => l.id)).toEqual([NEW_LOG_ID]);
    expect(emotionsArg.map((e) => e.id)).toEqual([NEW_EMOTION_ID]);
    // Upsert-only persistence must not be used for imports.
    expect(saveLogsSpy).not.toHaveBeenCalled();

    await waitFor(() => {
      expect(useLogStore.getState().logs.map((l) => l.id)).toEqual([NEW_LOG_ID]);
      expect(useEmotionStore.getState().emotions.map((e) => e.id)).toEqual([NEW_EMOTION_ID]);
    });
  });
});
