// 应用锁运行时：EntryAbility 冷启动时同步读设置并建好状态机，状态镜像到 AppStorage 供界面绑定。
// AppStorage 键：flashAppLocked / flashAppLockFailed / flashAppLockBusy / flashAppLockEnabled。
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AppLockAuthResult, AppLockController, AppLockSnapshot, AppLockToggleOutcome, AppLockToggleStart } from '../data/AppLock';
import { appLockAuthenticate, appLockAvailable } from '../data/AppLockAuth';
import { tr } from '../data/I18n';

// 与 AppController 的主题 / 减少动态效果同一个 Preferences 存储
const PREFERENCES_STORE = 'flash-aero-data';
const APP_LOCK_KEY = 'appLockEnabled';

class AppLockRuntime {
  private context?: common.UIAbilityContext;
  private enabled: boolean = false;
  controller: AppLockController = new AppLockController(() => false, () => false);

  // 冷启动：必须在 loadContent 之前调用，首帧就按锁定状态渲染
  install(context: common.UIAbilityContext): void {
    this.context = context;
    try {
      const store = preferences.getPreferencesSync(context, { name: PREFERENCES_STORE });
      this.enabled = store.getSync(APP_LOCK_KEY, false) === true;
    } catch (_) {
      // 读取失败按关闭处理（默认值）：宁可不锁，也不能把用户关在门外
      this.enabled = false;
    }
    this.controller = new AppLockController(() => this.enabled, () => appLockAvailable());
    AppStorage.setOrCreate<boolean>('flashAppLockEnabled', this.enabled);
    this.controller.setListener((snapshot: AppLockSnapshot) => {
      AppStorage.setOrCreate<boolean>('flashAppLocked', snapshot.locked);
      AppStorage.setOrCreate<boolean>('flashAppLockFailed', snapshot.lastAttemptFailed);
      AppStorage.setOrCreate<boolean>('flashAppLockBusy', snapshot.authenticating);
    });
  }

  requestUnlock(): void {
    if (!this.controller.beginUnlock()) return;
    appLockAuthenticate(tr('解锁 Flash 以查看你的记录')).then((result: AppLockAuthResult) => this.controller.finishUnlock(result));
  }

  autoPromptIfNeeded(): void {
    if (this.controller.consumeAutoPrompt()) this.requestUnlock();
  }

  // 设置页开关。onMessage 只在拒绝时调用（文案已本地化）。
  toggle(enable: boolean, onMessage: (message: string) => void): void {
    // 拨回真实状态时控件也会回调 onChange：与当前设置相同就什么都不做
    if (enable === this.enabled) return;
    switch (this.controller.beginToggle(enable)) {
      case AppLockToggleStart.BUSY:
        return;
      case AppLockToggleStart.APPLY:
        this.apply(enable);
        return;
      case AppLockToggleStart.REFUSE_UNAVAILABLE:
        onMessage(tr('此设备未设置锁屏密码，无法开启应用锁'));
        this.syncToggle();
        return;
      default:
        break;
    }
    appLockAuthenticate(enable ? tr('验证身份以开启应用锁') : tr('验证身份以关闭应用锁')).then((result: AppLockAuthResult) => {
      const outcome = this.controller.finishToggle(enable, result);
      if (outcome === AppLockToggleOutcome.APPLY) {
        this.apply(enable);
        return;
      }
      if (outcome === AppLockToggleOutcome.REFUSE_UNAVAILABLE) onMessage(tr('此设备未设置锁屏密码，无法开启应用锁'));
      if (outcome === AppLockToggleOutcome.REFUSE_FAILED) onMessage(tr('未能验证身份，设置未更改'));
      this.syncToggle();
    });
  }

  private apply(enable: boolean): void {
    this.enabled = enable;
    this.controller.settingChanged(enable);
    AppStorage.setOrCreate<boolean>('flashAppLockEnabled', enable);
    const context = this.context;
    if (context === undefined) return;
    try {
      const store = preferences.getPreferencesSync(context, { name: PREFERENCES_STORE });
      store.putSync(APP_LOCK_KEY, enable);
      store.flush().catch(() => {});
    } catch (_) {
    }
  }

  // 开关是双向绑定、已先翻转：未生效时拨回真实状态
  private syncToggle(): void {
    AppStorage.setOrCreate<boolean>('flashAppLockEnabled', this.enabled);
  }
}

export const appLockRuntime: AppLockRuntime = new AppLockRuntime();
