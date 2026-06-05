/**
 * CodeBlock.ets
 *
 * 代码块渲染组件。
 * 顶部显示语言标签和复制按钮，主体区域渲染语法高亮后的代码文本。
 * 当没有高亮 token 数据时，以统一灰色渲染代码文本。
 */

import { HighlightToken } from '../../service/Highlighter';

/** 默认代码文本颜色（无高亮时使用） */
const DEFAULT_CODE_COLOR: string = '#ABB2BF';

@Component
export struct CodeBlock {
  /** 编程语言标签（显示在头部） */
  language: string = '';
  /** 代码原始文本 */
  code: string = '';
  /** 高亮后的 token 二维数组：第一维为行，第二维为该行内的 token */
  tokens: HighlightToken[][] = [];
  /** 点击复制按钮的回调 */
  onCopy: (code: string) => void = () => {};

  /** 按行拆分代码文本 */
  private getLines(): string[] {
    if (!this.code) {
      return [];
    }
    return this.code.split('\n');
  }

  /** 渲染单行代码（有高亮 token 时） */
  @Builder
  tokenLineBuilder(lineIndex: number) {
    Text() {
      ForEach(this.tokens[lineIndex], (token: HighlightToken, tokenIdx: number) => {
        Span(token.content)
          .fontColor(token.color && token.color.length > 0 ? token.color : DEFAULT_CODE_COLOR)
          .fontSize(12)
          .fontFamily('monospace')
      }, (token: HighlightToken, tokenIdx: number) => `t-${lineIndex}-${tokenIdx}`)
    }
    .width('100%')
  }

  /** 渲染单行代码（无高亮 token 时） */
  @Builder
  plainLineBuilder(line: string, lineIdx: number) {
    Text(line)
      .fontColor(DEFAULT_CODE_COLOR)
      .fontSize(12)
      .fontFamily('monospace')
      .width('100%')
  }

  build() {
    Column() {
      // ---- 头部：语言标签 + 复制按钮 ----
      Row() {
        Text(this.language.length > 0 ? this.language : 'code')
          .fontSize(12)
          .fontColor('#9CA3AF')

        Blank()

        Text('复制')
          .fontSize(12)
          .fontColor('#2563EB')
          .onClick(() => {
            this.onCopy(this.code);
          })
      }
      .width('100%')
      .padding({
        top: 8,
        bottom: 8,
        left: 16,
        right: 16,
      })
      .backgroundColor('#F8F9FA')
      .borderRadius({
        topLeft: 12,
        topRight: 12,
      })

      // ---- 代码区域 ----
      Column() {
        if (this.tokens.length > 0) {
          ForEach(this.tokens, (_lineTokens: HighlightToken[], lineIdx: number) => {
            this.tokenLineBuilder(lineIdx)
          }, (_lineTokens: HighlightToken[], lineIdx: number) => `tok-line-${lineIdx}`)
        } else {
          ForEach(this.getLines(), (line: string, lineIdx: number) => {
            this.plainLineBuilder(line, lineIdx)
          }, (line: string, lineIdx: number) => `plain-line-${lineIdx}`)
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F8F9FA')
      .borderRadius({
        bottomLeft: 12,
        bottomRight: 12,
      })
      .border({
        width: 1,
        color: '#E4E7EC',
      })
    }
    .width('100%')
    .margin({ bottom: 16 })
  }
}
