import type { FlashBackup } from './backup';

function isCapacitorNative(): boolean {
  return typeof window !== 'undefined' &&
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (window as any).__CAPACITOR__ === true;
}

export async function exportToFile(backup: FlashBackup, filename: string): Promise<void> {
  const json = JSON.stringify(backup, null, 2);

  if (isCapacitorNative()) {
    const { Filesystem, Directory, Encoding } = await import('@capacitor/filesystem');
    const { Share } = await import('@capacitor/share');

    await Filesystem.writeFile({
      path: filename,
      data: json,
      directory: Directory.Documents,
      encoding: Encoding.UTF8,
    });

    const uriResult = await Filesystem.getUri({
      path: filename,
      directory: Directory.Documents,
    });

    await Share.share({
      title: 'Flash 备份',
      text: '分享 Flash 数据备份',
      url: uriResult.uri,
      dialogTitle: '保存备份到',
    });
    return;
  }

  const blob = new Blob([json], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export function readTextFromFile(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(new Error('读取文件失败'));
    reader.readAsText(file);
  });
}
