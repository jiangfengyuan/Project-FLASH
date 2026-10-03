import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData, formInfo } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  FormUpdateHelper, registerTodaySummaryForm, summarizeToday, todaySummaryFormData, unregisterTodaySummaryForm
} from '../data/FormUpdateHelper';
import { FlashStore } from '../data/FlashStore';

const DOMAIN = 0x0001;

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = this.formId(want);
    if (formId) {
      registerTodaySummaryForm(this.context, formId)
        .then(() => FormUpdateHelper.updateForms(this.context))
        .catch((error: Error) => {
          hilog.error(DOMAIN, 'FlashAero', 'Failed to refresh form on add: %{public}s', error.message);
        });
    }
    const store = FlashStore.instance;
    return todaySummaryFormData(summarizeToday(store.logs, store.emotions, store.tasks));
  }

  onCastToNormalForm(formId: string): void {
  }

  onUpdateForm(formId: string): void {
    FormUpdateHelper.updateForms(this.context).catch((error: Error) => {
      hilog.error(DOMAIN, 'FlashAero', 'Failed to refresh form: %{public}s', error.message);
    });
  }

  onChangeFormVisibility(newStatus: Record<string, number>): void {
  }

  onFormEvent(formId: string, message: string): void {
  }

  onRemoveForm(formId: string): void {
    unregisterTodaySummaryForm(this.context, formId).catch((error: Error) => {
      hilog.error(DOMAIN, 'FlashAero', 'Failed to unregister form: %{public}s', error.message);
    });
  }

  private formId(want: Want): string {
    const value = want?.parameters?.[formInfo.FormParam.IDENTITY_KEY];
    return typeof value === 'string' ? value : '';
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
