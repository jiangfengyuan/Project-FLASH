import { common } from '@kit.AbilityKit';
import { FeedbackState } from './FeatureStates';

/** Platform context and short-lived feedback are bound only while the root is mounted. */
export class ControllerRuntime {
  private host?: common.UIAbilityContext;
  private timer: number = 0;
  private feedback: FeedbackState;
  constructor(feedback: FeedbackState) { this.feedback = feedback; }
  bind(context: common.UIAbilityContext): void { this.host = context; }
  context(): common.UIAbilityContext {
    if (!this.host) throw new Error('页面尚未准备完成，请稍后重试');
    return this.host;
  }
  notify(message: string): void {
    if (!this.host) return;
    clearTimeout(this.timer);
    this.feedback.notice = { message: message };
    this.timer = setTimeout(() => { this.feedback.notice = undefined; }, 2200);
  }
  errorMessage(error: Error): string { return error.message || '操作失败'; }
  dispose(): void { clearTimeout(this.timer); this.feedback.notice = undefined; this.host = undefined; }
}
