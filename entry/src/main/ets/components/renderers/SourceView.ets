/**
 * SourceView.ets
 *
 * HTML 源码视图组件。
 * 显示带行号的 HTML 源代码，内置简单的 HTML 行级语法高亮：
 *   - 标签名 → #C678DD
 *   - 属性名 → #D19A66
 *   - 属性值（引号内）→ #98C379
 *   - 注释 → #5C6370 斜体
 *   - 其他 → #ABB2BF
 * 支持指定高亮行（黄色底 #FEF3C7）。
 */

import { HighlightToken } from '../../service/Highlighter';

/** HTML 语法高亮 token 类型 */
type HtmlTokenType = 'tag' | 'attrName' | 'attrValue' | 'comment' | 'text';

/** 默认代码颜色 */
const COLOR_TEXT: string = '#ABB2BF';
/** 标签名颜色 */
const COLOR_TAG: string = '#C678DD';
/** 属性名颜色 */
const COLOR_ATTR_NAME: string = '#D19A66';
/** 属性值颜色 */
const COLOR_ATTR_VALUE: string = '#98C379';
/** 注释颜色 */
const COLOR_COMMENT: string = '#5C6370';

/**
 * 对单行 HTML 进行语法高亮，返回 token 数组。
 *
 * @param line - 单行 HTML 文本
 * @returns 高亮 token 数组
 */
function highlightHtmlLine(line: string): HighlightToken[] {
  const tokens: HighlightToken[] = [];
  let i: number = 0;
  const len: number = line.length;

  while (i < len) {
    // ---- HTML 注释 <!-- ... --> ----
    if (line.substring(i, i + 4) === '<!--') {
      const end: number = line.indexOf('-->', i + 4);
      const closeIdx: number = end !== -1 ? end + 3 : len;
      tokens.push({
        type: 'comment',
        content: line.substring(i, closeIdx),
        color: COLOR_COMMENT,
      });
      i = closeIdx;
      continue;
    }

    // ---- 开始标签 / 结束标签 / 自闭合标签 ----
    if (line[i] === '<') {
      // 读取整个标签内容直到 >
      let tagEnd: number = i;
      let inQuote: string = '';
      while (tagEnd < len) {
        const ch: string = line[tagEnd];
        if (inQuote.length > 0) {
          if (ch === inQuote) {
            inQuote = '';
          }
        } else if (ch === '"' || ch === "'") {
          inQuote = ch;
        } else if (ch === '>') {
          tagEnd++;
          break;
        }
        tagEnd++;
      }

      // 如果未找到 >，将剩余内容作为 text
      if (tagEnd >= len && inQuote.length > 0) {
        tokens.push({
          type: 'text',
          content: line.substring(i),
          color: COLOR_TEXT,
        });
        i = len;
        continue;
      }

      const tagStr: string = line.substring(i, tagEnd);
      // 解析标签内部结构
      const tagTokens: HighlightToken[] = parseTag(tagStr);
      tokens.push(...tagTokens);
      i = tagEnd;
      continue;
    }

    // ---- 普通文本 ----
    const nextTag: number = line.indexOf('<', i);
    const nextComment: number = line.indexOf('<!--', i);
    let textEnd: number = len;
    if (nextTag !== -1 && nextTag < textEnd) {
      textEnd = nextTag;
    }
    if (nextComment !== -1 && nextComment < textEnd) {
      textEnd = nextComment;
    }
    if (textEnd > i) {
      tokens.push({
        type: 'text',
        content: line.substring(i, textEnd),
        color: COLOR_TEXT,
      });
      i = textEnd;
    } else {
      // 避免死循环
      tokens.push({
        type: 'text',
        content: line[i],
        color: COLOR_TEXT,
      });
      i++;
    }
  }

  return tokens;
}

/**
 * 解析单个 HTML 标签字符串为 token 数组。
 * 例如 '<div class="foo">' 解析为:
 *   [ '<' text, 'div' tag, ' ' text, 'class' attrName, '=' text, '"foo"' attrValue, '>' text ]
 */
function parseTag(tagStr: string): HighlightToken[] {
  const tokens: HighlightToken[] = [];
  let i: number = 0;
  const len: number = tagStr.length;

  // '<' 或 '</'
  if (tagStr[0] === '<') {
    let prefix: string = '<';
    i = 1;
    if (len > 1 && tagStr[1] === '/') {
      prefix = '</';
      i = 2;
    } else if (len > 1 && tagStr[1] === '!') {
      // 可能是 <!DOCTYPE> 等
      tokens.push({
        type: 'tag',
        content: tagStr,
        color: COLOR_TAG,
      });
      return tokens;
    }
    tokens.push({
      type: 'text',
      content: prefix,
      color: COLOR_TEXT,
    });
  }

  // 读取标签名
  let tagName: string = '';
  while (i < len && tagStr[i] !== ' ' && tagStr[i] !== '>' && tagStr[i] !== '/' && tagStr[i] !== '\t' && tagStr[i] !== '\n') {
    tagName += tagStr[i];
    i++;
  }
  if (tagName.length > 0) {
    tokens.push({
      type: 'tag',
      content: tagName,
      color: COLOR_TAG,
    });
  }

  // 解析属性和值
  while (i < len) {
    // 跳过空白
    let ws: string = '';
    while (i < len && (tagStr[i] === ' ' || tagStr[i] === '\t' || tagStr[i] === '\n')) {
      ws += tagStr[i];
      i++;
    }
    if (ws.length > 0) {
      tokens.push({
        type: 'text',
        content: ws,
        color: COLOR_TEXT,
      });
    }

    // 结束
    if (i >= len) {
      break;
    }

    // '>' 或 '/>'
    if (tagStr[i] === '>') {
      tokens.push({
        type: 'text',
        content: '>',
        color: COLOR_TEXT,
      });
      i++;
      break;
    }
    if (tagStr[i] === '/' && i + 1 < len && tagStr[i + 1] === '>') {
      tokens.push({
        type: 'text',
        content: '/>',
        color: COLOR_TEXT,
      });
      i += 2;
      break;
    }

    // 读取属性名
    let attrName: string = '';
    while (i < len && tagStr[i] !== '=' && tagStr[i] !== ' ' && tagStr[i] !== '>' && tagStr[i] !== '/' && tagStr[i] !== '\t') {
      attrName += tagStr[i];
      i++;
    }
    if (attrName.length > 0) {
      tokens.push({
        type: 'attrName',
        content: attrName,
        color: COLOR_ATTR_NAME,
      });
    }

    // '=' 号
    if (i < len && tagStr[i] === '=') {
      tokens.push({
        type: 'text',
        content: '=',
        color: COLOR_TEXT,
      });
      i++;

      // 读取属性值
      if (i < len && (tagStr[i] === '"' || tagStr[i] === "'")) {
        const quote: string = tagStr[i];
        let value: string = quote;
        i++;
        while (i < len && tagStr[i] !== quote) {
          value += tagStr[i];
          i++;
        }
        if (i < len) {
          value += tagStr[i]; // 闭合引号
          i++;
        }
        tokens.push({
          type: 'attrValue',
          content: value,
          color: COLOR_ATTR_VALUE,
        });
      } else {
        // 无引号属性值
        let value: string = '';
        while (i < len && tagStr[i] !== ' ' && tagStr[i] !== '>' && tagStr[i] !== '/') {
          value += tagStr[i];
          i++;
        }
        if (value.length > 0) {
          tokens.push({
            type: 'attrValue',
            content: value,
            color: COLOR_ATTR_VALUE,
          });
        }
      }
    }
  }

  return tokens;
}

@Component
export struct SourceView {
  /** 原始 HTML 源代码 */
  source: string = '';
  /** 需要高亮的行号列表（从 1 开始） */
  highlightLines: number[] = [];

  /** 按行拆分源代码 */
  private getLines(): string[] {
    if (!this.source) {
      return [];
    }
    return this.source.split('\n');
  }

  /** 判断指定行号是否需要高亮 */
  private isHighlightLine(lineNum: number): boolean {
    if (!this.highlightLines || this.highlightLines.length === 0) {
      return false;
    }
    for (const hl of this.highlightLines) {
      if (hl === lineNum) {
        return true;
      }
    }
    return false;
  }

  build() {
    Scroll() {
      Column() {
        ForEach(this.getLines(), (line: string, idx: number) => {
          Row() {
            // ---- 行号列 ----
            Text(`${idx + 1}`)
              .fontSize(12)
              .fontFamily('monospace')
              .fontColor('#9CA3AF')
              .width(40)
              .textAlign(TextAlign.End)
              .padding({ right: 8 })
              .border({
                right: {
                  width: 1,
                  color: '#E4E7EC',
                },
              })

            // ---- 代码区域 ----
            Text() {
              ForEach(highlightHtmlLine(line), (token: HighlightToken, tokenIdx: number) => {
                Span(token.content)
                  .fontColor(token.color && token.color.length > 0 ? token.color : COLOR_TEXT)
                  .fontSize(12)
                  .fontFamily('monospace')
                  .fontStyle(token.type === 'comment' ? FontStyle.Italic : FontStyle.Normal)
              }, (token: HighlightToken, tokenIdx: number) => `sv-tok-${idx}-${tokenIdx}`)
            }
            .padding({ left: 16 })
            .layoutWeight(1)
          }
          .width('100%')
          .height(22)
          .alignItems(VerticalAlign.Center)
          .backgroundColor(this.isHighlightLine(idx + 1) ? '#FEF3C7' : '#F8F9FA')
        }, (line: string, idx: number) => `sv-line-${idx}`)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor('#F8F9FA')
  }
}
