// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { tr } from './I18n';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { Category, colorTagName, LogItem } from '../models/Models';

/** 系统分享面板（ShareKit systemShare）的 syscap；受限能力先探测再展示入口。 */
const SYSTEM_SHARE_SYSCAP = 'SystemCapability.Collaboration.SystemShare';
const TEXT_UTD = 'general.plain-text';
const FILE_UTD = 'general.file';
/** 分享用的明文备份副本放在 cacheDir 下的独立子目录（对齐 Android `shared-backups/`）。 */
export const SHARE_DIRECTORY = 'shared-backups';
const SHARE_FILE_PREFIX = 'flash-aero-backup-';
/** 一次性分享副本 24 小时后删除（对齐 Android / Apple 的 BackupTransfer）。 */
export const SHARE_MAX_AGE_MILLIS = 24 * 60 * 60 * 1000;

export function systemShareSupported(): boolean {
  try {
    return typeof canIUse === 'function' && canIUse(SYSTEM_SHARE_SYSCAP);
  } catch (_) {
    return false;
  }
}

/** 分享文案：正文在前，元数据收尾（对齐 Android 分享 EXTRA_TEXT 的语义）。 */
export function logShareText(item: LogItem): string {
  const kind = item.category === Category.IDEA ? tr('灵感') : tr('记录');
  const importance = item.importance > 0 ? tr(' · 重要度 {0}', item.importance) : '';
  return `${item.content}\n\n—— Flash ${kind}｜${item.recordDate} · ${colorTagName(item.colorTag)}${importance}`;
}

/** 分享单条记录文本。调用方须先以 systemShareSupported() 守卫入口。 */
export async function shareLog(context: common.UIAbilityContext, item: LogItem): Promise<void> {
  if (!systemShareSupported()) throw new Error(tr('当前设备不支持系统分享'));
  const record: systemShare.SharedRecord = {
    utd: TEXT_UTD,
    content: logShareText(item),
    title: item.category === Category.IDEA ? tr('Flash 灵感') : tr('Flash 记录')
  };
  const data = new systemShare.SharedData(record);
  const controller = new systemShare.ShareController(data);
  await controller.show(context, {
    selectionMode: systemShare.SelectionMode.SINGLE,
    previewMode: systemShare.SharePreviewMode.DEFAULT
  });
}

/** 备份文件写入沙箱缓存目录后通过系统分享发送（对齐 Android FileProvider /
 * macOS 系统分享的导出路径）。临时文件 + rename 保证不分享写了一半的文件。 */
export async function shareBackupFile(context: common.UIAbilityContext, json: string, fileName: string): Promise<void> {
  if (!systemShareSupported()) throw new Error(tr('当前设备不支持系统分享'));
  const directory = `${context.cacheDir}/${SHARE_DIRECTORY}`;
  if (!(await fileIo.access(directory))) await fileIo.mkdir(directory);
  await cleanupExpiredShareCopies(context.cacheDir);
  const path = `${directory}/${fileName}`;
  const temp = `${path}.tmp`;
  try { await fileIo.unlink(temp); } catch (_) {}
  const file = await fileIo.open(temp, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
  let written: number = 0;
  try {
    written = await fileIo.write(file.fd, json, { encoding: 'utf-8' });
  } finally {
    await fileIo.close(file);
  }
  const expected = new util.TextEncoder().encodeInto(json).length;
  if (written !== expected) {
    try { await fileIo.unlink(temp); } catch (_) {}
    throw new Error(tr('备份写入不完整，分享已取消'));
  }
  await fileIo.rename(temp, path);
  const record: systemShare.SharedRecord = {
    utd: FILE_UTD,
    uri: new fileUri.FileUri(path).toString(),
    title: fileName
  };
  const data = new systemShare.SharedData(record);
  const controller = new systemShare.ShareController(data);
  await controller.show(context, {
    selectionMode: systemShare.SelectionMode.SINGLE,
    previewMode: systemShare.SharePreviewMode.DEFAULT
  });
}

/**
 * 删除过期的明文分享副本：`shared-backups/` 内及旧版本直接写在 cacheDir 根下的
 * `flash-aero-backup-*.json(.tmp)`。分享时与应用启动时各调用一次，尽力而为：
 * 清理失败不影响分享或启动。
 */
export async function cleanupExpiredShareCopies(cacheDir: string, now: number = Date.now()): Promise<void> {
  if (!cacheDir) return;
  for (const directory of [`${cacheDir}/${SHARE_DIRECTORY}`, cacheDir]) {
    let names: string[] = [];
    try {
      if (!(await fileIo.access(directory))) continue;
      names = await fileIo.listFile(directory);
    } catch (_) {
      continue;
    }
    for (const name of names) {
      if (!name.startsWith(SHARE_FILE_PREFIX) || !(name.endsWith('.json') || name.endsWith('.json.tmp'))) continue;
      const path = `${directory}/${name}`;
      try {
        const file = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
        let expired = false;
        try {
          // Stat.mtime 文档为秒，部分 API 级别返回毫秒：按量级归一（同 FlashStore 隔离区清理）
          const mtime = (await fileIo.stat(file.fd)).mtime;
          const mtimeMillis = mtime > 1e12 ? mtime : mtime * 1000;
          expired = Number.isFinite(mtimeMillis) && (now - mtimeMillis) > SHARE_MAX_AGE_MILLIS;
        } finally {
          await fileIo.close(file);
        }
        if (expired) await fileIo.unlink(path);
      } catch (_) {
        console.error('Flash share copy cleanup failed');
      }
    }
  }
}
