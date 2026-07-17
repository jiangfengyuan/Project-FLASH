import type { LogItem } from '@/stores/logStore';
import type { EmotionRecord } from '@/stores/emotionStore';
import { exportBackup } from '@/lib/backup';
import { exportToFile } from '@/lib/fileIO';

export interface ExportPayload {
  logs: LogItem[];
  emotions: EmotionRecord[];
  notes: string;
}

export async function exportData({ logs, emotions, notes }: ExportPayload): Promise<void> {
  const backup = exportBackup(logs, emotions, notes);
  const filename = `flash-backup-${new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-')}.json`;
  await exportToFile(backup, filename);
}
