// 应用锁（可选，默认关闭）：冷启动锁定；离开前台超过宽限期后回来再锁定。
// 与 Apple `AppLockPolicy`、Android `AppLock.kt` 同口径。纯逻辑，不依赖系统能力，主机测试直接运行。

export const APP_LOCK_GRACE_MS: number = 60000;

export class AppLockPolicy {
  readonly gracePeriodMs: number;

  constructor(gracePeriodMs: number) {
    this.gracePeriodMs = Math.max(0, gracePeriodMs);
  }

  // 系统时间被往回拨（now 早于离开时刻）按超时处理，不能靠改时钟绕过。
  shouldLockOnReturn(enabled: boolean, backgroundedAt: number | undefined, now: number): boolean {
    if (!enabled || backgroundedAt === undefined) return false;
    const elapsed = now - backgroundedAt;
    return elapsed < 0 || elapsed >= this.gracePeriodMs;
  }
}

export enum AppLockAuthResult {
  SUCCESS = 'success',
  // 用户或系统取消：留在锁定页，可再点「解锁」
  CANCELLED = 'cancelled',
  FAILED = 'failed',
  // 验证途中发现设备没有锁屏密码：视同放行
  UNAVAILABLE = 'unavailable'
}

export enum AppLockToggleStart {
  VERIFY = 'verify',
  APPLY = 'apply',
  REFUSE_UNAVAILABLE = 'refuse-unavailable',
  BUSY = 'busy'
}

export enum AppLockToggleOutcome {
  APPLY = 'apply',
  REFUSE_UNAVAILABLE = 'refuse-unavailable',
  REFUSE_FAILED = 'refuse-failed',
  NONE = 'none'
}

export interface AppLockSnapshot {
  locked: boolean;
  lastAttemptFailed: boolean;
  authenticating: boolean;
}

export type AppLockListener = (snapshot: AppLockSnapshot) => void;

// 锁定状态机；系统验证由 AppLockAuth 发起，状态经 listener 同步到 AppStorage。
// 只有「设备没设锁屏密码」时才不可用：此时绝不锁住用户。
export class AppLockController {
  private isEnabled: () => boolean;
  private isAvailable: () => boolean;
  private policy: AppLockPolicy;
  private clock: () => number;
  private listener?: AppLockListener;
  private locked: boolean;
  private lastAttemptFailed: boolean = false;
  private authenticating: boolean = false;
  private backgroundedAt: number | undefined = undefined;
  // 每次上锁后自动弹一次验证；取消后只能手动点「解锁」，不循环弹窗
  private autoPromptPending: boolean;

  constructor(isEnabled: () => boolean, isAvailable: () => boolean,
    policy: AppLockPolicy = new AppLockPolicy(APP_LOCK_GRACE_MS), clock: () => number = () => Date.now()) {
    this.isEnabled = isEnabled;
    this.isAvailable = isAvailable;
    this.policy = policy;
    this.clock = clock;
    this.locked = isEnabled() && isAvailable();
    this.autoPromptPending = this.locked;
  }

  setListener(listener: AppLockListener | undefined): void {
    this.listener = listener;
    this.emit();
  }

  snapshot(): AppLockSnapshot {
    return { locked: this.locked, lastAttemptFailed: this.lastAttemptFailed, authenticating: this.authenticating };
  }

  isLocked(): boolean {
    return this.locked;
  }

  // UIAbility onBackground。验证界面本身引起的切换不计时。
  onBackground(): void {
    if (this.authenticating || this.backgroundedAt !== undefined) return;
    this.backgroundedAt = this.clock();
  }

  // UIAbility onForeground：超过宽限期就上锁。
  onForeground(): void {
    const at = this.backgroundedAt;
    this.backgroundedAt = undefined;
    if (this.authenticating) return;
    if (this.policy.shouldLockOnReturn(this.isEnabled(), at, this.clock())) this.lockNow();
  }

  lockNow(): void {
    if (!this.isEnabled() || this.locked || !this.isAvailable()) return;
    this.locked = true;
    this.lastAttemptFailed = false;
    this.autoPromptPending = true;
    this.emit();
  }

  // 锁定页可见且应用在前台时调用：true 表示现在该自动弹一次验证。
  consumeAutoPrompt(): boolean {
    if (!this.locked || !this.autoPromptPending || this.authenticating) return false;
    this.autoPromptPending = false;
    return true;
  }

  // 准备解锁：true 表示需要调起系统验证；false 表示已直接放行（设置被关 / 设备无密码）或正在验证。
  beginUnlock(): boolean {
    if (!this.locked || this.authenticating) return false;
    if (!this.isEnabled() || !this.isAvailable()) {
      this.locked = false;
      this.emit();
      return false;
    }
    this.authenticating = true;
    this.emit();
    return true;
  }

  finishUnlock(result: AppLockAuthResult): void {
    this.authenticating = false;
    this.lastAttemptFailed = result === AppLockAuthResult.FAILED;
    if (result === AppLockAuthResult.SUCCESS || result === AppLockAuthResult.UNAVAILABLE) {
      this.locked = false;
      this.backgroundedAt = undefined;
    }
    this.emit();
  }

  // 设置页开关：开、关都先验证；设备没密码时不许开启（关闭总是允许）。
  beginToggle(enable: boolean): AppLockToggleStart {
    if (this.authenticating) return AppLockToggleStart.BUSY;
    if (!this.isAvailable()) return enable ? AppLockToggleStart.REFUSE_UNAVAILABLE : AppLockToggleStart.APPLY;
    this.authenticating = true;
    this.emit();
    return AppLockToggleStart.VERIFY;
  }

  finishToggle(enable: boolean, result: AppLockAuthResult): AppLockToggleOutcome {
    this.authenticating = false;
    this.emit();
    switch (result) {
      case AppLockAuthResult.SUCCESS:
        return AppLockToggleOutcome.APPLY;
      case AppLockAuthResult.CANCELLED:
        return AppLockToggleOutcome.NONE;
      case AppLockAuthResult.FAILED:
        return AppLockToggleOutcome.REFUSE_FAILED;
      default:
        return enable ? AppLockToggleOutcome.REFUSE_UNAVAILABLE : AppLockToggleOutcome.APPLY;
    }
  }

  // 设置变化后同步：关闭即解锁。
  settingChanged(enabled: boolean): void {
    if (!enabled) {
      this.locked = false;
      this.autoPromptPending = false;
      this.emit();
    }
  }

  private emit(): void {
    this.listener?.(this.snapshot());
  }
}
