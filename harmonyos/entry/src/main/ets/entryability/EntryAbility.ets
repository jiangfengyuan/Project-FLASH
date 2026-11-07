import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, window } from '@kit.ArkUI';
import { FlashStore } from '../data/FlashStore';
import { systemEnvironment } from '../state/FeatureStates';
import { i18n } from '@kit.LocalizationKit';
import { AppEntry, namedEntry, parseDeepLink, sharedEntry } from '../data/AppEntry';
import { resourceManager } from '@kit.LocalizationKit';
import { installI18n, StringSource } from '../data/I18n';
import { setFontScale } from '../components/DesignTokens';

const DOMAIN = 0x0000;

class ManagerStrings implements StringSource {
  private manager: resourceManager.ResourceManager;

  constructor(manager: resourceManager.ResourceManager) {
    this.manager = manager;
  }

  getStringByNameSync(name: string): string {
    return this.manager.getStringByNameSync(name);
  }

  getPluralStringByNameSync(name: string, count: number): string {
    return this.manager.getPluralStringByNameSync(name, count);
  }
}

export default class EntryAbility extends UIAbility {
  private mainWindow?: window.Window;
  private avoidAreaChangeCallback?: () => void;
  private windowSizeChangeCallback?: () => void;
  private foldStatusChangeCallback?: (status: display.FoldStatus) => void;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'FlashAero', 'EntryAbility created');
    this.syncSystemColorMode(this.context.config.colorMode);
    installI18n(new ManagerStrings(this.context.resourceManager), i18n.System.getSystemLanguage());
    setFontScale(this.context.config.fontSizeScale ?? 1);
    this.deliverEntry(want);
    this.watchFoldStatus();
    FlashStore.instance.initialize(this.context).catch((error: Error) => {
      hilog.error(DOMAIN, 'FlashAero', 'Failed to initialize store: %{public}s', error.message);
    });
  }

  onNewWant(want: Want): void {
    this.deliverEntry(want);
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    this.syncSystemColorMode(newConfig.colorMode);
    installI18n(new ManagerStrings(this.context.resourceManager), i18n.System.getSystemLanguage());
    setFontScale(newConfig.fontSizeScale ?? 1);
  }

  // 深链、快捷方式、小组件、通知与系统分享：交给界面层，等加载完成后处理。
  private deliverEntry(want: Want): void {
    const entry = this.parseWant(want);
    if (entry !== undefined) AppStorage.setOrCreate<AppEntry | undefined>('flashPendingEntry', entry);
  }

  private parseWant(want: Want): AppEntry | undefined {
    const parameters: Record<string, Object> = want.parameters ?? {};
    const named = parameters['flashEntry'];
    if (typeof named === 'string') {
      const entry = namedEntry(named);
      if (entry !== undefined) return entry;
    }
    if (want.action === 'ohos.want.action.sendData') {
      const text = parameters['ability.params.stream'] === undefined ? parameters['content'] : undefined;
      if (typeof text === 'string') return sharedEntry(text);
    }
    return parseDeepLink(want.uri);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    let mainWindow: window.Window | undefined;
    try {
      mainWindow = windowStage.getMainWindowSync();
    } catch (error) {
      hilog.error(DOMAIN, 'FlashAero', 'Failed to get main window: %{public}s', (error as Error).message);
    }
    if (mainWindow) {
      const host = mainWindow;
      this.mainWindow = host;
      host.setWindowLayoutFullScreen(true).then(() => {
        this.updateAvoidAreas(host);
      }).catch((error: Error) => {
        hilog.error(DOMAIN, 'FlashAero', 'Failed to enable immersive layout: %{public}s', error.message);
      });
      this.avoidAreaChangeCallback = () => this.updateAvoidAreas(host);
      this.windowSizeChangeCallback = () => this.updateAvoidAreas(host);
      host.on('avoidAreaChange', this.avoidAreaChangeCallback);
      host.on('windowSizeChange', this.windowSizeChangeCallback);
    }
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        hilog.error(DOMAIN, 'FlashAero', 'Failed to load content: %{public}s', JSON.stringify(error));
      }
    });
  }

  onWindowStageDestroy(): void {
    const host = this.mainWindow;
    if (host) {
      if (this.avoidAreaChangeCallback) {
        try {
          host.off('avoidAreaChange', this.avoidAreaChangeCallback);
        } catch (_) {
        }
      }
      if (this.windowSizeChangeCallback) {
        try {
          host.off('windowSizeChange', this.windowSizeChangeCallback);
        } catch (_) {
        }
      }
    }
    this.mainWindow = undefined;
    this.avoidAreaChangeCallback = undefined;
    this.windowSizeChangeCallback = undefined;
  }

  onDestroy(): void {
    this.onWindowStageDestroy();
    if (this.foldStatusChangeCallback) {
      try {
        display.off('foldStatusChange', this.foldStatusChangeCallback);
      } catch (_) {
      }
      this.foldStatusChangeCallback = undefined;
    }
  }

  private syncSystemColorMode(mode?: ConfigurationConstant.ColorMode): void {
    systemEnvironment.systemDark = mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  private watchFoldStatus(): void {
    try {
      if (!canIUse('SystemCapability.Window.SessionManager') || !display.isFoldable()) return;
      systemEnvironment.foldable = true;
      systemEnvironment.foldStatus = display.getFoldStatus();
      this.foldStatusChangeCallback = (status: display.FoldStatus) => {
        systemEnvironment.foldStatus = status;
      };
      display.on('foldStatusChange', this.foldStatusChangeCallback);
    } catch (error) {
      hilog.error(DOMAIN, 'FlashAero', 'Failed to watch fold status: %{public}s', (error as Error).message);
    }
  }

  private updateAvoidAreas(mainWindow: window.Window): void {
    try {
      const systemArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      let navigationBarHeight = systemArea.bottomRect.height;
      try {
        const indicatorArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        navigationBarHeight = Math.max(navigationBarHeight, indicatorArea.bottomRect.height);
      } catch (_) {
      }
      systemEnvironment.statusBarHeightPx = systemArea.topRect.height;
      systemEnvironment.navigationBarHeightPx = navigationBarHeight;
    } catch (error) {
      hilog.error(DOMAIN, 'FlashAero', 'Failed to update avoid areas: %{public}s', (error as Error).message);
    }
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
