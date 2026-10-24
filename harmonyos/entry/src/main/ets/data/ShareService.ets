// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { Category, colorTagName, LogItem } from '../models/Models';

/** 系统分享面板（ShareKit systemShare）的 syscap；受限能力先探测再展示入口。 */
const SYSTEM_SHARE_SYSCAP = 'SystemCapability.Collaboration.SystemShare';
const TEXT_UTD = 'general.plain-text';
const FILE_UTD = 'general.file';

export function systemShareSupported(): boolean {
  try {
    return typeof canIUse === 'function' && canIUse(SYSTEM_SHARE_SYSCAP);
  } catch (_) {
    return false;
  }
}

/** 分享文案：正文在前，元数据收尾（对齐 Android 分享 EXTRA_TEXT 的语义）。 */
export function logShareText(item: LogItem): string {
  const kind = item.category === Category.IDEA ? '灵感' : '记录';
  const importance = item.importance > 0 ? ` · 重要度 ${item.importance}` : '';
  return `${item.content}\n\n—— Flash ${kind}｜${item.recordDate} · ${colorTagName(item.colorTag)}${importance}`;
}

/** 分享单条记录文本。调用方须先以 systemShareSupported() 守卫入口。 */
export async function shareLog(context: common.UIAbilityContext, item: LogItem): Promise<void> {
  if (!systemShareSupported()) throw new Error('当前设备不支持系统分享');
  const record: systemShare.SharedRecord = {
    utd: TEXT_UTD,
    content: logShareText(item),
    title: item.category === Category.IDEA ? 'Flash 灵感' : 'Flash 记录'
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
  if (!systemShareSupported()) throw new Error('当前设备不支持系统分享');
  const path = `${context.cacheDir}/${fileName}`;
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
    throw new Error('备份写入不完整，分享已取消');
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
