import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { Environment, fileIo, picker } from '@kit.CoreFileKit';
import { BackupService } from './BackupService';
import { dayString } from './DateUtils';

export enum SharedExportStatus {
  READY = 'ready',
  EXPORTED = 'exported',
  UNSUPPORTED = 'unsupported',
  DENIED = 'denied'
}

export interface SharedExportResult {
  status: SharedExportStatus;
  path?: string;
}

export class BackupFiles {
  private static readonly SHARED_EXPORT_DIR: string = 'Flash';
  private static readonly SHARED_EXPORT_SYSCAP: string =
    'SystemCapability.FileManagement.File.Environment.FolderObtain';
  static async exportJSON(
    context: common.UIAbilityContext,
    json: string,
    filePrefix: string = 'flash-aero-backup'
  ): Promise<void> {
    const options = new picker.DocumentSaveOptions();
    const day = dayString();
    options.newFileNames = [`${filePrefix}-${day}.json`];
    options.fileSuffixChoices = ['JSON 备份|.json'];
    const viewPicker = new picker.DocumentViewPicker(context);
    const uris = await viewPicker.save(options);
    if (uris.length === 0) throw new Error('未选择保存位置');
    const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    let written: number = 0;
    try {
      written = fileIo.writeSync(file.fd, json, { encoding: 'utf-8' });
    } finally {
      fileIo.closeSync(file);
    }
    // writeSync may report a short write (e.g. full disk) instead of throwing;
    // a truncated backup must never look like a successful export.
    const expected = new util.TextEncoder().encodeInto(json).length;
    if (written !== expected) {
      try { fileIo.unlinkSync(uris[0]); } catch (_) {}
      throw new Error('备份写入不完整，导出失败');
    }
  }

  static async importJSON(context: common.UIAbilityContext): Promise<string> {
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    options.fileSuffixFilters = ['JSON 备份|.json'];
    const viewPicker = new picker.DocumentViewPicker(context);
    const uris = await viewPicker.select(options);
    if (uris.length === 0) throw new Error('未选择备份文件');
    const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
    try {
      const size = fileIo.statSync(file.fd).size;
      if (size > BackupService.MAX_BYTES) throw new Error('备份文件超过 50 MB');
      if (size < 1) throw new Error('备份文件为空');
      const buffer = new ArrayBuffer(size);
      const bytesRead = fileIo.readSync(file.fd, buffer, { length: size });
      if (bytesRead !== size) throw new Error('备份文件读取不完整');
      // No ignoreBOM: a UTF-8 BOM decodes to U+FEFF and the strict importer
      // rejects it, matching the Android and macOS import paths.
      const decoder = util.TextDecoder.create('utf-8', { fatal: true });
      return decoder.decodeToString(new Uint8Array(buffer));
    } finally {
      fileIo.closeSync(file);
    }
  }

  static sharedExportName(filePrefix: string, day: string): string {
    return `${filePrefix}-${day}.json`;
  }

  static sharedExportStatus(): SharedExportStatus {
    try {
      if (!canIUse(BackupFiles.SHARED_EXPORT_SYSCAP)) return SharedExportStatus.UNSUPPORTED;
    } catch (_) {
      return SharedExportStatus.UNSUPPORTED;
    }
    try {
      Environment.getUserDownloadDir();
    } catch (_) {
      return SharedExportStatus.DENIED;
    }
    return SharedExportStatus.READY;
  }

  static async exportToSharedDir(
    json: string,
    filePrefix: string = 'flash-aero-backup'
  ): Promise<SharedExportResult> {
    const status = BackupFiles.sharedExportStatus();
    if (status !== SharedExportStatus.READY) return { status };
    let baseDir: string = '';
    try {
      baseDir = Environment.getUserDownloadDir();
    } catch (_) {
      return { status: SharedExportStatus.DENIED };
    }
    let dir = BackupFiles.joinPath(baseDir, BackupFiles.SHARED_EXPORT_DIR);
    try {
      if (!fileIo.accessSync(dir)) fileIo.mkdirSync(dir);
    } catch (_) {
      dir = baseDir;
    }
    const day = dayString();
    const target = BackupFiles.joinPath(dir, BackupFiles.sharedExportName(filePrefix, day));
    const temp = `${target}.tmp`;
    try { fileIo.unlinkSync(temp); } catch (_) {}
    const file = fileIo.openSync(temp, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    let written: number = 0;
    try {
      written = fileIo.writeSync(file.fd, json, { encoding: 'utf-8' });
    } finally {
      fileIo.closeSync(file);
    }
    const expected = new util.TextEncoder().encodeInto(json).length;
    if (written !== expected) {
      try { fileIo.unlinkSync(temp); } catch (_) {}
      throw new Error('备份写入不完整，导出失败');
    }
    fileIo.renameSync(temp, target);
    return { status: SharedExportStatus.EXPORTED, path: target };
  }

  private static joinPath(base: string, child: string): string {
    return base.endsWith('/') ? base + child : `${base}/${child}`;
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
