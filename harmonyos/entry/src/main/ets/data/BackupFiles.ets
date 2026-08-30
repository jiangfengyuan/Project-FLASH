import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo, picker } from '@kit.CoreFileKit';
import { BackupService } from './BackupService';

export class BackupFiles {
  static async exportJSON(context: common.UIAbilityContext, json: string): Promise<void> {
    const options = new picker.DocumentSaveOptions();
    const day = new Date().toISOString().slice(0, 10);
    options.newFileNames = [`flash-aero-backup-${day}.json`];
    options.fileSuffixChoices = ['JSON 备份|.json'];
    const viewPicker = new picker.DocumentViewPicker(context);
    const uris = await viewPicker.save(options);
    if (uris.length === 0) throw new Error('未选择保存位置');
    const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, json, { encoding: 'utf-8' });
    } finally {
      fileIo.closeSync(file);
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
      const decoder = util.TextDecoder.create('utf-8', { fatal: true, ignoreBOM: true });
      return decoder.decodeToString(new Uint8Array(buffer));
    } finally {
      fileIo.closeSync(file);
    }
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
