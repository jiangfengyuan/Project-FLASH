import { tr } from '../data/I18n';
import { common } from '@kit.AbilityKit';
import { FeedbackState, normalizeToastLevel } from './FeatureStates';

/** Platform context and short-lived feedback are bound only while the root is mounted. */
export class ControllerRuntime {
  private host?: common.UIAbilityContext;
  private timer: number = 0;
  private feedback: FeedbackState;
  constructor(feedback: FeedbackState) { this.feedback = feedback; }
  bind(context: common.UIAbilityContext): void { this.host = context; }
  context(): common.UIAbilityContext {
    if (!this.host) throw new Error(tr('页面尚未准备完成，请稍后重试'));
    return this.host;
  }
  notify(message: string, level: string = 'info'): void {
    if (!this.host) return;
    clearTimeout(this.timer);
    this.feedback.notice = { message: message, level: normalizeToastLevel(level) };
    this.timer = setTimeout(() => { this.feedback.notice = undefined; }, 2200);
  }
  /** 带撤销的提示：4 秒，点操作后立即收起。 */
  notifyUndo(message: string, actionLabel: string, action: () => void): void {
    if (!this.host) return;
    clearTimeout(this.timer);
    this.feedback.notice = {
      message: message, level: 'info', actionLabel: actionLabel,
      action: () => {
        clearTimeout(this.timer);
        this.feedback.notice = undefined;
        action();
      }
    };
    this.timer = setTimeout(() => { this.feedback.notice = undefined; }, 4000);
  }
  errorMessage(error: Error): string { return error.message || tr('操作失败'); }
  dispose(): void { clearTimeout(this.timer); this.feedback.notice = undefined; this.host = undefined; }
}
