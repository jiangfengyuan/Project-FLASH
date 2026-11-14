// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { SettingsState } from './FeatureStates';

// 新手引导（四端同一内容与顺序：欢迎 → 能做什么 → 隐私 → 偏好）。
// 文案与翻页规则是纯数据 / 纯函数，Node 测试直接覆盖；渲染在 components/WelcomeOverlay。

export interface OnboardingRow {
  // 图标键：由 WelcomeOverlay 映射到系统 Symbol 资源。
  icon: string;
  title: string;
  detail: string;
}

export interface OnboardingStepContent {
  key: string;
  icon: string;
  title: string;
  subtitle: string;
  rows: OnboardingRow[];
}

export const ONBOARDING_STEPS: OnboardingStepContent[] = [
  {
    key: 'welcome',
    icon: 'bolt',
    title: '欢迎来到 Flash',
    subtitle: '闪过即留，一目了然。\n把一闪而过的念头、情绪与待办，安心留在这台设备上。',
    rows: []
  },
  {
    key: 'features',
    icon: 'lightbulb',
    title: 'Flash 能帮你做什么',
    subtitle: '四个模块，覆盖从记下到回看的全过程。',
    rows: [
      { icon: 'record', title: '随手记录', detail: '日志与灵感一键记下，用 !! 标记重要程度。' },
      { icon: 'emotion', title: '情绪觉察', detail: '七级情绪加上具体感受，看见自己的变化。' },
      { icon: 'calendar', title: '任务与日历', detail: '按日期回看记录；任务可设系统提醒。' },
      { icon: 'review', title: '回顾', detail: '周、月趋势与情绪分布，发现记录的节奏。' }
    ]
  },
  {
    key: 'privacy',
    icon: 'device',
    title: '你的记录只属于你',
    subtitle: '本地优先：没有账号，也没有后端。',
    rows: [
      { icon: 'device', title: '数据保存在这台设备', detail: '无需注册，不上传到任何服务器。' },
      { icon: 'backup', title: '备份与传输由你发起', detail: '随时导出 JSON 备份，或在可信局域网内直传到另一台设备。' },
      { icon: 'caution', title: '妥善保管备份文件', detail: '备份是明文 JSON，请只保存或分享到可信的位置。' }
    ]
  },
  {
    key: 'preferences',
    icon: 'preferences',
    title: '让 Flash 更适合你',
    subtitle: '以下选项随时可在「设置 › 辅助功能」中修改。',
    rows: []
  }
];

export const ONBOARDING_STEP_COUNT: number = ONBOARDING_STEPS.length;

export function clampStep(step: number): number {
  if (!Number.isFinite(step)) return 0;
  return Math.min(ONBOARDING_STEP_COUNT - 1, Math.max(0, Math.trunc(step)));
}

export function nextStep(step: number): number {
  return clampStep(clampStep(step) + 1);
}

export function previousStep(step: number): number {
  return clampStep(clampStep(step) - 1);
}

export function isFirstStep(step: number): boolean {
  return clampStep(step) === 0;
}

export function isLastStep(step: number): boolean {
  return clampStep(step) === ONBOARDING_STEP_COUNT - 1;
}

// 读屏播报的步骤位置。
export function stepAnnouncement(step: number): string {
  return `第 ${clampStep(step) + 1} 步，共 ${ONBOARDING_STEP_COUNT} 步`;
}

// 打开引导（首次安装或从设置重新查看）：总是从第一步开始。
export function openOnboarding(settings: SettingsState, replay: boolean): void {
  settings.welcomeStep = 0;
  settings.welcomeReplay = replay;
  settings.showWelcome = true;
}

// 引导结束（跳过或开始使用）后的界面状态；持久化由 AppController.finishWelcome 负责。
export function closeOnboarding(settings: SettingsState): void {
  settings.showWelcome = false;
  settings.welcomeReplay = false;
  settings.welcomeStep = 0;
}

// 系统返回键：中途回上一步；重新查看时第一步直接关闭；首次安装第一步交给系统（返回 false）。
export function onboardingBack(settings: SettingsState): boolean {
  if (!settings.showWelcome) return false;
  if (!isFirstStep(settings.welcomeStep)) {
    settings.welcomeStep = previousStep(settings.welcomeStep);
    return true;
  }
  if (settings.welcomeReplay) {
    closeOnboarding(settings);
    return true;
  }
  return false;
}
