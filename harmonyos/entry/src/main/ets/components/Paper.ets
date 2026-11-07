// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { ThemeState } from '../state/FeatureStates';
import { handCircleCommands, handLineCommands, stickyOffset, tornEdgeMaskCommands, tornLineCommands } from './PaperGeometry';
import { cardShadowColor, parchmentColor, hairlineColor, CARD_SHADOW_RADIUS, CARD_SHADOW_Y, RADIUS_ROW } from './DesignTokens';

// 「纸上书写」手作元素（品牌标准 §08）。形状由种子决定、重绘一致，只作装饰，读屏忽略。
// ArkUI Path 的 commands 单位是 px，这里统一按当前密度换算。

/** 横向毛边分隔线 */
@Component
export struct TornDivider {
  @ObjectLink theme: ThemeState;
  seed: string = 'divider';
  @State private commands: string = '';

  build() {
    Stack() {
      if (this.commands !== '') {
        Path()
          .commands(this.commands)
          .fillOpacity(0)
          .stroke(hairlineColor(this.theme))
          .strokeWidth(1.1)
          .strokeLineCap(LineCapStyle.Round)
      }
    }
    .width('100%')
    .height(4)
    .accessibilityLevel('no')
    .onAreaChange((_: Area, area: Area) => {
      const ui = this.getUIContext();
      this.commands = tornLineCommands(this.seed, ui.vp2px(Number(area.width)), ui.vp2px(4), ui.vp2px(1.6), ui.vp2px(7));
    })
  }
}

/** 撕开的区块断口：一条窄窄的羊皮纸带 */
@Component
export struct TornSectionBreak {
  @ObjectLink theme: ThemeState;
  seed: string = 'break';
  @State private edge: string = '';
  @State private line: string = '';

  build() {
    Stack() {
      Row().width('100%').height(5).backgroundColor(parchmentColor(this.theme)).opacity(0.55)
      if (this.line !== '') {
        Path()
          .commands(this.line)
          .fillOpacity(0)
          .stroke(hairlineColor(this.theme))
          .strokeWidth(0.8)
      }
    }
    .width('100%')
    .height(8)
    .accessibilityLevel('no')
    .onAreaChange((_: Area, area: Area) => {
      const ui = this.getUIContext();
      this.line = tornLineCommands(this.seed, ui.vp2px(Number(area.width)), ui.vp2px(8), ui.vp2px(1.2), ui.vp2px(7));
    })
  }
}

/** 标题下的手绘下划线 */
@Component
export struct HandUnderline {
  color: string = '#A84A24';
  seed: string = 'underline';
  widthVp: number = 96;
  private commands: string = '';

  aboutToAppear(): void {
    const ui = this.getUIContext();
    this.commands = handLineCommands(this.seed, ui.vp2px(this.widthVp), ui.vp2px(6), ui.vp2px(1.4), ui.vp2px(36));
  }

  build() {
    Path()
      .commands(this.commands)
      .width(this.widthVp)
      .height(6)
      .fillOpacity(0)
      .stroke(this.color)
      .strokeOpacity(0.75)
      .strokeWidth(2.2)
      .strokeLineCap(LineCapStyle.Round)
      .accessibilityLevel('no')
  }
}

/** 手绘圈：图标后的淡色圆底 + 两笔错开的描边 */
@Component
export struct HandRing {
  seed: string = 'ring';
  tint: string = '#A84A24';
  sizeVp: number = 76;
  private first: string = '';
  private second: string = '';

  aboutToAppear(): void {
    const px = this.getUIContext().vp2px(this.sizeVp);
    this.first = handCircleCommands(this.seed, px, 0.035);
    this.second = handCircleCommands(`${this.seed}·2`, px, 0.05);
  }

  build() {
    Stack() {
      Circle().width(this.sizeVp - 8).height(this.sizeVp - 8).fill(this.tint).fillOpacity(0.12)
      Path().commands(this.first).width(this.sizeVp).height(this.sizeVp).fillOpacity(0)
        .stroke(this.tint).strokeOpacity(0.85).strokeWidth(1.6).strokeLineCap(LineCapStyle.Round)
      Path().commands(this.second).width(this.sizeVp).height(this.sizeVp).fillOpacity(0)
        .stroke(this.tint).strokeOpacity(0.35).strokeWidth(1)
    }
    .width(this.sizeVp)
    .height(this.sizeVp)
    .accessibilityLevel('no')
  }
}

/** 主卡片底边的撕口：盖一条页面色毛边，形成撕开的纸边 */
@Component
export struct TornCardEdge {
  @ObjectLink theme: ThemeState;
  seed: string = 'card';
  @State private commands: string = '';

  build() {
    Stack() {
      if (this.commands !== '') {
        Path().commands(this.commands).fill(this.theme.themeBackground).strokeOpacity(0)
      }
    }
    .width('100%')
    .height(8)
    .accessibilityLevel('no')
    .hitTestBehavior(HitTestMode.None)
    .onAreaChange((_: Area, area: Area) => {
      const ui = this.getUIContext();
      this.commands = tornEdgeMaskCommands(this.seed, ui.vp2px(Number(area.width)), ui.vp2px(8), ui.vp2px(2.4), ui.vp2px(7));
    })
  }
}

/** 折叠信纸的折痕与折角：放在卡片内容之下的 Stack 里 */
@Component
export struct FoldMarks {
  @ObjectLink theme: ThemeState;

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Row().width('100%').height(0.75).backgroundColor(cardShadowColor(this.theme))
        Row().width('100%').height(0.75).backgroundColor(this.theme.themeSurface).opacity(0.8)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      Polygon({ width: 22, height: 22 })
        .points([[0, 0], [22, 22], [0, 22]])
        .fill(parchmentColor(this.theme))
    }
    .width('100%')
    .height('100%')
    .accessibilityLevel('no')
    .hitTestBehavior(HitTestMode.None)
  }
}

/** 便签底页：身后错开一张羊皮纸。放在 Stack 底层 */
@Component
export struct StickyUnderSheet {
  @ObjectLink theme: ThemeState;
  seed: string = 'sticky';
  radius: number = RADIUS_ROW;
  private angle: number = 1;
  private dx: number = 0;

  aboutToAppear(): void {
    const offset = stickyOffset(this.seed);
    this.angle = offset[0];
    this.dx = offset[1];
  }

  build() {
    Row()
      .width('100%')
      .height('100%')
      .borderRadius(this.radius)
      .backgroundColor(parchmentColor(this.theme))
      .opacity(0.7)
      .rotate({ angle: this.angle })
      .translate({ x: this.dx, y: 4 })
      .accessibilityLevel('no')
  }
}

/** 通用纸卡阴影参数集中在这里，页面只调 cardShadow */
export function paperShadow(theme: ThemeState): ShadowOptions {
  return { radius: CARD_SHADOW_RADIUS, color: cardShadowColor(theme), offsetX: 0, offsetY: CARD_SHADOW_Y };
}
