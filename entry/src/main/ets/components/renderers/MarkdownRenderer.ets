/**
 * MarkdownRenderer.ets
 *
 * Markdown 主渲染组件 —— 接收 AST 节点数组，递归渲染为 ArkUI 组件树。
 * 这是渲染层的核心组件，负责：
 *   1. 块级节点分发（标题、段落、列表、代码块、表格等）
 *   2. 内联节点递归收集（粗体、斜体、链接、行内代码等）
 *   3. 搜索关键词高亮（黄色底 #FEF3C7）
 *   4. 嵌套列表 / 引用块的递归渲染
 */

import { ASTNode, ASTNodeType } from '../../parser/ASTNode';
import { CodeBlock } from './CodeBlock';
import { TableBlock } from './TableBlock';
import { TaskList, TaskItemData } from './TaskList';
import { MermaidBlock } from './MermaidBlock';
import { MathBlock } from './MathBlock';

// ---------------------------------------------------------------------------
// 内联 Span 数据结构（用于在 Text 组件内混合样式）
// ---------------------------------------------------------------------------

/** 内联文本片段数据，用于在 Text 组件中构建 Span 子组件 */
interface SpanData {
  /** 文本内容 */
  text: string;
  /** 字号 */
  fontSize: number;
  /** 字重 */
  fontWeight: FontWeight;
  /** 字体样式（斜体） */
  fontStyle: FontStyle;
  /** 文字颜色 */
  fontColor: string;
  /** 文字装饰（下划线、删除线） */
  decoration: TextDecoration;
  /** 字体族（monospace 等） */
  fontFamily: string;
  /** 背景色（搜索高亮用） */
  backgroundColor: string;
}

// ---------------------------------------------------------------------------
// 颜色常量
// ---------------------------------------------------------------------------

const COLOR_PRIMARY: string = '#1A1A1A';
const COLOR_SECONDARY: string = '#6B7280';
const COLOR_WEAK: string = '#9CA3AF';
const COLOR_BRAND: string = '#2563EB';
const COLOR_BRAND_BG: string = '#EFF6FF';
const COLOR_BORDER: string = '#E4E7EC';
const COLOR_BG_GRAY: string = '#F8F9FA';
const COLOR_HIGHLIGHT: string = '#FEF3C7';
const COLOR_CODE_TEXT: string = '#ABB2BF';

// ---------------------------------------------------------------------------
// MarkdownRenderer 组件
// ---------------------------------------------------------------------------

@Component
export struct MarkdownRenderer {
  /** AST 节点树 */
  nodes: ASTNode[] = [];
  /** 搜索关键词，用于文本高亮 */
  searchKeyword: string = '';

  // -------------------------------------------------------------------------
  // 辅助方法
  // -------------------------------------------------------------------------

  /** 判断节点是否为内联节点 */
  private isInlineNode(node: ASTNode): boolean {
    return node.type === ASTNodeType.TEXT ||
      node.type === ASTNodeType.BOLD ||
      node.type === ASTNodeType.ITALIC ||
      node.type === ASTNodeType.STRIKETHROUGH ||
      node.type === ASTNodeType.INLINE_CODE ||
      node.type === ASTNodeType.LINK ||
      node.type === ASTNodeType.LINE_BREAK;
  }

  /** 创建一个默认样式的 SpanData */
  private makeSpan(
    text: string,
    fontSize: number,
    isBold: boolean,
    isItalic: boolean,
    isStrike: boolean,
    isHighlight: boolean,
    fontColor: string = COLOR_PRIMARY,
    decoration: TextDecoration = TextDecoration.None,
    fontFamily: string = '',
    backgroundColor: string = '',
  ): SpanData {
    const span: SpanData = {
      text: text,
      fontSize: fontSize,
      fontWeight: isBold ? FontWeight.Bold : FontWeight.Normal,
      fontStyle: isItalic ? FontStyle.Italic : FontStyle.Normal,
      fontColor: isHighlight ? COLOR_PRIMARY : fontColor,
      decoration: isStrike ? TextDecoration.LineThrough : decoration,
      fontFamily: fontFamily,
      backgroundColor: isHighlight ? COLOR_HIGHLIGHT : backgroundColor,
    };
    return span;
  }

  /**
   * 递归收集内联节点的 Span 数据。
   *
   * 遍历 AST 内联节点树，将样式信息（粗体、斜体、删除线等）层层叠加，
   * 最终生成扁平的 SpanData 数组，供 Text 组件渲染。
   */
  private collectInlineSpans(
    node: ASTNode,
    baseFontSize: number = 14,
    isBold: boolean = false,
    isItalic: boolean = false,
    isStrike: boolean = false,
    linkColor: boolean = false,
  ): SpanData[] {
    const spans: SpanData[] = [];

    if (!node) {
      return spans;
    }

    switch (node.type) {
      case ASTNodeType.TEXT: {
        const text: string = node.content || '';
        if (text.length === 0) {
          break;
        }
        // 搜索关键词高亮
        if (this.searchKeyword && this.searchKeyword.length > 0) {
          const lowerText: string = text.toLowerCase();
          const lowerKeyword: string = this.searchKeyword.toLowerCase();
          let start: number = 0;
          let matchIdx: number = lowerText.indexOf(lowerKeyword, start);
          while (matchIdx !== -1) {
            // 匹配前的文本
            if (matchIdx > start) {
              spans.push(this.makeSpan(
                text.substring(start, matchIdx),
                baseFontSize, isBold, isItalic, isStrike, false,
                linkColor ? COLOR_BRAND : COLOR_PRIMARY,
                linkColor ? TextDecoration.Underline : TextDecoration.None,
              ));
            }
            // 匹配的文本（高亮）
            spans.push(this.makeSpan(
              text.substring(matchIdx, matchIdx + this.searchKeyword.length),
              baseFontSize, isBold, isItalic, isStrike, true,
            ));
            start = matchIdx + this.searchKeyword.length;
            matchIdx = lowerText.indexOf(lowerKeyword, start);
          }
          // 匹配后的剩余文本
          if (start < text.length) {
            spans.push(this.makeSpan(
              text.substring(start),
              baseFontSize, isBold, isItalic, isStrike, false,
              linkColor ? COLOR_BRAND : COLOR_PRIMARY,
              linkColor ? TextDecoration.Underline : TextDecoration.None,
            ));
          }
        } else {
          spans.push(this.makeSpan(
            text,
            baseFontSize, isBold, isItalic, isStrike, false,
            linkColor ? COLOR_BRAND : COLOR_PRIMARY,
            linkColor ? TextDecoration.Underline : TextDecoration.None,
          ));
        }
        break;
      }

      case ASTNodeType.BOLD:
        if (node.children) {
          for (const child of node.children) {
            spans.push(...this.collectInlineSpans(child, baseFontSize, true, isItalic, isStrike, linkColor));
          }
        }
        break;

      case ASTNodeType.ITALIC:
        if (node.children) {
          for (const child of node.children) {
            spans.push(...this.collectInlineSpans(child, baseFontSize, isBold, true, isStrike, linkColor));
          }
        }
        break;

      case ASTNodeType.STRIKETHROUGH:
        if (node.children) {
          for (const child of node.children) {
            spans.push(...this.collectInlineSpans(child, baseFontSize, isBold, isItalic, true, linkColor));
          }
        }
        break;

      case ASTNodeType.INLINE_CODE: {
        const codeText: string = node.content || '';
        if (codeText.length === 0) {
          break;
        }
        // 搜索高亮也适用于行内代码
        if (this.searchKeyword && this.searchKeyword.length > 0) {
          const lowerCode: string = codeText.toLowerCase();
          const lowerKeyword: string = this.searchKeyword.toLowerCase();
          let start: number = 0;
          let matchIdx: number = lowerCode.indexOf(lowerKeyword, start);
          while (matchIdx !== -1) {
            if (matchIdx > start) {
              spans.push(this.makeSpan(
                codeText.substring(start, matchIdx),
                baseFontSize - 2, false, false, false, false,
                COLOR_PRIMARY, TextDecoration.None, 'monospace', COLOR_BG_GRAY,
              ));
            }
            spans.push(this.makeSpan(
              codeText.substring(matchIdx, matchIdx + this.searchKeyword.length),
              baseFontSize - 2, false, false, false, true,
              COLOR_PRIMARY, TextDecoration.None, 'monospace',
            ));
            start = matchIdx + this.searchKeyword.length;
            matchIdx = lowerCode.indexOf(lowerKeyword, start);
          }
          if (start < codeText.length) {
            spans.push(this.makeSpan(
              codeText.substring(start),
              baseFontSize - 2, false, false, false, false,
              COLOR_PRIMARY, TextDecoration.None, 'monospace', COLOR_BG_GRAY,
            ));
          }
        } else {
          spans.push(this.makeSpan(
            codeText,
            baseFontSize - 2, false, false, false, false,
            COLOR_PRIMARY, TextDecoration.None, 'monospace', COLOR_BG_GRAY,
          ));
        }
        break;
      }

      case ASTNodeType.LINK:
        if (node.children) {
          for (const child of node.children) {
            spans.push(...this.collectInlineSpans(child, baseFontSize, isBold, isItalic, isStrike, true));
          }
        } else if (node.href) {
          // 链接没有子节点时显示 href
          spans.push(this.makeSpan(
            node.href,
            baseFontSize, isBold, isItalic, isStrike, false,
            COLOR_BRAND, TextDecoration.Underline,
          ));
        }
        break;

      case ASTNodeType.LINE_BREAK:
        spans.push({
          text: '\n',
          fontSize: baseFontSize,
          fontWeight: FontWeight.Normal,
          fontStyle: FontStyle.Normal,
          fontColor: COLOR_PRIMARY,
          decoration: TextDecoration.None,
          fontFamily: '',
          backgroundColor: '',
        });
        break;

      case ASTNodeType.PARAGRAPH:
        // 段落节点可能嵌套在列表项等容器内，递归处理其子节点
        if (node.children) {
          for (const child of node.children) {
            spans.push(...this.collectInlineSpans(child, baseFontSize, isBold, isItalic, isStrike, linkColor));
          }
        }
        break;

      default:
        // 未知内联节点类型，尝试渲染子节点
        if (node.children) {
          for (const child of node.children) {
            spans.push(...this.collectInlineSpans(child, baseFontSize, isBold, isItalic, isStrike, linkColor));
          }
        }
        break;
    }

    return spans;
  }

  /** 从 LIST_ITEM 节点中提取内联 Span 数据 */
  private collectListItemSpans(node: ASTNode): SpanData[] {
    const spans: SpanData[] = [];
    if (!node.children) {
      return spans;
    }
    for (const child of node.children) {
      if (child.type === ASTNodeType.PARAGRAPH) {
        spans.push(...this.collectInlineSpans(child, 14));
      } else if (this.isInlineNode(child)) {
        spans.push(...this.collectInlineSpans(child, 14));
      }
    }
    return spans;
  }

  /** 从 LIST_ITEM 节点中提取块级子节点（嵌套列表等） */
  private getBlockChildren(node: ASTNode): ASTNode[] {
    if (!node.children) {
      return [];
    }
    return node.children.filter((c: ASTNode) => !this.isInlineNode(c) && c.type !== ASTNodeType.PARAGRAPH);
  }

  /** 从 TASK_LIST 节点构建 TaskItemData 数组 */
  private buildTaskItems(node: ASTNode): TaskItemData[] {
    const items: TaskItemData[] = [];
    if (!node.children) {
      return items;
    }
    for (const child of node.children) {
      if (child.type === ASTNodeType.TASK_ITEM) {
        items.push({
          checked: child.checked || false,
          text: child.content || '',
        });
      }
    }
    return items;
  }

  // -------------------------------------------------------------------------
  // @Builder：内联 Span 渲染器（在 Text 组件内生成 Span 子组件）
  // -------------------------------------------------------------------------

  @Builder
  spanBuilder(spanData: SpanData, idx: number) {
    Span(spanData.text)
      .fontSize(spanData.fontSize)
      .fontWeight(spanData.fontWeight)
      .fontStyle(spanData.fontStyle)
      .fontColor(spanData.fontColor)
      .decoration({
        type: spanData.decoration,
        color: spanData.decoration !== TextDecoration.None ? spanData.fontColor : undefined,
      })
      .fontFamily(spanData.fontFamily.length > 0 ? spanData.fontFamily : undefined)
      .backgroundColor(spanData.backgroundColor.length > 0 ? spanData.backgroundColor : undefined)
  }

  // -------------------------------------------------------------------------
  // @Builder：块级节点分发渲染
  // -------------------------------------------------------------------------

  @Builder
  renderBlockNode(node: ASTNode, index: number) {
    if (node.type === ASTNodeType.HEADING) {
      // ---- 标题 ----
      Text() {
        ForEach(
          this.collectInlineSpans(
            node,
            node.level === 1 ? 24 : (node.level === 2 ? 18 : 14),
            true, false, false, false,
          ),
          (s: SpanData, sIdx: number) => {
            this.spanBuilder(s, sIdx)
          },
          (s: SpanData, sIdx: number) => `h-span-${index}-${sIdx}`,
        )
      }
      .width('100%')
      .margin({
        top: node.level === 2 ? 24 : (node.level === 1 ? 0 : 16),
        bottom: 16,
      })
    } else if (node.type === ASTNodeType.PARAGRAPH) {
      // ---- 段落 ----
      Text() {
        ForEach(
          this.collectInlineSpans(node, 14),
          (s: SpanData, sIdx: number) => {
            this.spanBuilder(s, sIdx)
          },
          (s: SpanData, sIdx: number) => `p-span-${index}-${sIdx}`,
        )
      }
      .fontSize(14)
      .lineHeight(14 * 1.8)
      .width('100%')
      .margin({ bottom: 16 })
    } else if (node.type === ASTNodeType.ORDERED_LIST) {
      // ---- 有序列表 ----
      Column() {
        ForEach(
          node.children || [],
          (child: ASTNode, cIdx: number) => {
            this.renderListItem(child, cIdx, `${cIdx + 1}.`)
          },
          (child: ASTNode, cIdx: number) => `ol-item-${index}-${cIdx}`,
        )
      }
      .width('100%')
      .padding({ left: 24 })
      .margin({ bottom: 16 })
    } else if (node.type === ASTNodeType.UNORDERED_LIST) {
      // ---- 无序列表 ----
      Column() {
        ForEach(
          node.children || [],
          (child: ASTNode, cIdx: number) => {
            this.renderListItem(child, cIdx, '\u2022')
          },
          (child: ASTNode, cIdx: number) => `ul-item-${index}-${cIdx}`,
        )
      }
      .width('100%')
      .padding({ left: 24 })
      .margin({ bottom: 16 })
    } else if (node.type === ASTNodeType.CODE_BLOCK) {
      // ---- 代码块 ----
      CodeBlock({
        language: node.language || '',
        code: node.content || '',
        tokens: [],
        onCopy: (_code: string) => {},
      })
    } else if (node.type === ASTNodeType.TABLE) {
      // ---- 表格 ----
      TableBlock({
        headers: node.headers || [],
        rows: node.rows || [],
      })
    } else if (node.type === ASTNodeType.BLOCKQUOTE) {
      // ---- 引用块 ----
      Column() {
        ForEach(
          node.children || [],
          (child: ASTNode, cIdx: number) => {
            this.renderBlockNode(child, cIdx)
          },
          (child: ASTNode, cIdx: number) => `bq-child-${index}-${cIdx}`,
        )
      }
      .width('100%')
      .padding({ left: 16, top: 8, bottom: 8, right: 16 })
      .border({
        left: { width: 3, color: COLOR_BRAND },
      })
      .backgroundColor(COLOR_BRAND_BG)
      .borderRadius(8)
      .margin({ bottom: 16 })
    } else if (node.type === ASTNodeType.IMAGE) {
      // ---- 图片 ----
      Column() {
        Image(node.src || '')
          .width('100%')
          .objectFit(ImageFit.Contain)
          .borderRadius(12)
          .onError(() => {})

        if (node.alt && node.alt.length > 0) {
          Text(node.alt)
            .fontSize(12)
            .fontColor(COLOR_WEAK)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 4 })
        }
      }
      .width('100%')
      .margin({ bottom: 16 })
    } else if (node.type === ASTNodeType.HORIZONTAL_RULE) {
      // ---- 水平分割线 ----
      Divider()
        .color(COLOR_BORDER)
        .width('100%')
        .margin({ top: 24, bottom: 24 })
    } else if (node.type === ASTNodeType.TASK_LIST) {
      // ---- 任务列表 ----
      TaskList({
        items: this.buildTaskItems(node),
      })
    } else if (node.type === ASTNodeType.MERMAID) {
      // ---- Mermaid 图表 ----
      MermaidBlock({
        content: node.content || '',
      })
    } else if (node.type === ASTNodeType.MATH_BLOCK) {
      // ---- 数学公式 ----
      MathBlock({
        content: node.content || '',
      })
    } else if (node.type === ASTNodeType.HTML_RAW) {
      // ---- 原始 HTML（简单展示） ----
      Text(node.content || '')
        .fontSize(12)
        .fontColor(COLOR_SECONDARY)
        .fontFamily('monospace')
        .width('100%')
        .padding(16)
        .backgroundColor(COLOR_BG_GRAY)
        .borderRadius(8)
        .margin({ bottom: 16 })
    }
  }

  // -------------------------------------------------------------------------
  // @Builder：列表项渲染
  // -------------------------------------------------------------------------

  @Builder
  renderListItem(node: ASTNode, index: number, marker: string) {
    Column() {
      Row() {
        Text(marker)
          .fontSize(14)
          .fontColor(COLOR_PRIMARY)
          .margin({ right: 8 })
          .width(marker.length > 2 ? 24 : 16)
          .textAlign(TextAlign.Start)

        Text() {
          ForEach(
            this.collectListItemSpans(node),
            (s: SpanData, sIdx: number) => {
              this.spanBuilder(s, sIdx)
            },
            (s: SpanData, sIdx: number) => `li-span-${index}-${sIdx}`,
          )
        }
        .fontSize(14)
        .lineHeight(14 * 1.8)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      // 嵌套块级子节点（嵌套列表等）
      ForEach(
        this.getBlockChildren(node),
        (child: ASTNode, cIdx: number) => {
          this.renderBlockNode(child, cIdx)
        },
        (child: ASTNode, cIdx: number) => `li-block-${index}-${cIdx}`,
      )
    }
    .width('100%')
    .margin({ bottom: 4 })
  }

  // -------------------------------------------------------------------------
  // build
  // -------------------------------------------------------------------------

  build() {
    Scroll() {
      Column() {
        ForEach(
          this.nodes,
          (node: ASTNode, idx: number) => {
            this.renderBlockNode(node, idx)
          },
          (node: ASTNode, idx: number) => `root-${node.type}-${idx}`,
        )
      }
      .width('100%')
      .padding(24)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
  }
}
