/**
 * HtmlParser.ets
 *
 * HTML 解析器。
 * 由于 ArkTS 没有内置 DOM Parser，本解析器使用正则 + 状态机方式
 * 对 HTML 源文本做轻量解析，将 HTML 标签映射到统一的 ASTNodeType。
 *
 * 安全策略：
 * - 丢弃 <script>、<iframe>、<object>、<embed> 标签及其内容
 * - 过滤外部 stylesheet（<link rel="stylesheet">）
 * - 过滤外部 script（<script src="...">）
 * - div、span 等无语义标签透传，直接处理其子元素
 */

import { ASTNode, ASTNodeType, HtmlMeta } from './ASTNode';

// ---------------------------------------------------------------------------
// 内部辅助：简易 HTML Token
// ---------------------------------------------------------------------------

/** Token 类型 */
const enum TokenType {
  /** 开始标签 <tag attr="val"> */
  OPEN_TAG,
  /** 结束标签 </tag> */
  CLOSE_TAG,
  /** 自闭合标签 <img ... /> */
  SELF_CLOSE,
  /** 文本内容 */
  TEXT,
}

/** 解析过程中的内部 Token */
interface HtmlToken {
  type: TokenType;
  /** 标签名（小写）或文本内容 */
  value: string;
  /** 标签属性键值对（仅 OPEN_TAG / SELF_CLOSE 有效） */
  attrs?: Map<string, string>;
}

// ---------------------------------------------------------------------------
// 需要丢弃的危险标签
// ---------------------------------------------------------------------------

const DANGEROUS_TAGS = new Set<string>(['script', 'iframe', 'object', 'embed']);

// ---------------------------------------------------------------------------
// 属性解析辅助
// ---------------------------------------------------------------------------

/**
 * 从标签字符串中提取属性键值对。
 * 支持双引号、单引号、无引号三种形式。
 *
 * @param tagStr - 标签内容（不含 < >），如 'a href="url" class="link"'
 * @returns 属性 Map
 */
function parseAttributes(tagStr: string): Map<string, string> {
  const attrs = new Map<string, string>();
  // 匹配属性：name="value" | name='value' | name=value | name（布尔属性）
  const attrRegex = /([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*(?:=\s*(?:"([^"]*)"|'([^']*)'|(\S+)))?/g;
  let match: RegExpExecArray | null;
  while ((match = attrRegex.exec(tagStr)) !== null) {
    const name = match[1].toLowerCase();
    const value = match[2] ?? match[3] ?? match[4] ?? '';
    attrs.set(name, value);
  }
  return attrs;
}

// ---------------------------------------------------------------------------
// HTML 主解析器
// ---------------------------------------------------------------------------

/**
 * HTML 解析器。
 *
 * 使用方式：
 * ```typescript
 * const parser = new HtmlParser();
 * const ast = parser.parse(htmlSource);
 * const meta = parser.extractMeta(htmlSource);
 * ```
 */
export class HtmlParser {

  // -----------------------------------------------------------------------
  // 公开 API
  // -----------------------------------------------------------------------

  /**
   * 将 HTML 源文本解析为 ASTNode 数组。
   *
   * @param source - HTML 源文本
   * @returns 块级 ASTNode 列表
   */
  parse(source: string): ASTNode[] {
    // 预处理：去除 BOM、统一换行
    const cleaned = source.replace(/\r\n/g, '\n').replace(/\r/g, '\n').replace(/^\uFEFF/, '');

    // 提取 <body> 内容，如果有的话
    const bodyMatch = cleaned.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
    const htmlContent = bodyMatch ? bodyMatch[1] : cleaned;

    // 移除 <head> 区域（如果 body 提取失败，手动去掉 head）
    const content = bodyMatch ? htmlContent : cleaned.replace(/<head[^>]*>[\s\S]*?<\/head>/i, '');

    // 分词
    const tokens = this.tokenize(content);

    // 构建树
    return this.buildTree(tokens);
  }

  /**
   * 从 HTML 源文本中提取 <head> 元数据。
   *
   * @param source - HTML 源文本
   * @returns HtmlMeta 对象
   */
  extractMeta(source: string): HtmlMeta {
    const meta: HtmlMeta = {};

    // <title>
    const titleMatch = source.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
    if (titleMatch) {
      meta.title = this.decodeEntities(titleMatch[1].trim());
    }

    // <meta charset="...">
    const charsetMatch = source.match(/<meta[^>]*charset\s*=\s*["']?([^"'\s>]+)/i);
    if (charsetMatch) {
      meta.charset = charsetMatch[1];
    }

    // <html lang="...">
    const langMatch = source.match(/<html[^>]*\slang\s*=\s*["']?([^"'\s>]+)/i);
    if (langMatch) {
      meta.lang = langMatch[1];
    }

    // <meta name="viewport" content="...">
    const viewportMatch = source.match(/<meta[^>]*name\s*=\s*["']?viewport["']?[^>]*content\s*=\s*"([^"]*)"/i) ||
      source.match(/<meta[^>]*content\s*=\s*"([^"]*)"[^>]*name\s*=\s*["']?viewport["']?/i);
    if (viewportMatch) {
      meta.viewport = viewportMatch[1];
    }

    return meta;
  }

  // -----------------------------------------------------------------------
  // 分词器（Tokenizer）
  // -----------------------------------------------------------------------

  /**
   * 将 HTML 文本分割为 Token 序列。
   * 使用正则匹配标签，标签之间的文本作为 TEXT Token。
   */
  private tokenize(html: string): HtmlToken[] {
    const tokens: HtmlToken[] = [];
    // 匹配 HTML 标签（开始、结束、自闭合）和注释
    const tagRegex = /<!--[\s\S]*?-->|<\/?([a-zA-Z][a-zA-Z0-9]*)\b([^>]*?)(\/?)>/g;
    let lastIndex = 0;
    let match: RegExpExecArray | null;

    while ((match = tagRegex.exec(html)) !== null) {
      // 标签前的文本
      if (match.index > lastIndex) {
        const text = html.slice(lastIndex, match.index);
        if (text.length > 0) {
          tokens.push({ type: TokenType.TEXT, value: text });
        }
      }

      const fullMatch = match[0];

      // 跳过注释
      if (fullMatch.startsWith('<!--')) {
        lastIndex = match.index + fullMatch.length;
        continue;
      }

      const tagName = match[1].toLowerCase();
      const attrString = match[2] || '';
      const selfCloseSlash = match[3] || '';

      // 判断 Token 类型
      if (fullMatch.startsWith('</')) {
        // 闭合标签
        tokens.push({ type: TokenType.CLOSE_TAG, value: tagName });
      } else if (selfCloseSlash === '/' || this.isVoidElement(tagName)) {
        // 自闭合标签
        tokens.push({
          type: TokenType.SELF_CLOSE,
          value: tagName,
          attrs: parseAttributes(attrString),
        });
      } else {
        // 开始标签
        tokens.push({
          type: TokenType.OPEN_TAG,
          value: tagName,
          attrs: parseAttributes(attrString),
        });
      }

      lastIndex = match.index + fullMatch.length;
    }

    // 尾部文本
    if (lastIndex < html.length) {
      const text = html.slice(lastIndex);
      if (text.length > 0) {
        tokens.push({ type: TokenType.TEXT, value: text });
      }
    }

    return tokens;
  }

  /**
   * 判断是否是 HTML void 元素（不需要闭合标签）。
   */
  private isVoidElement(tag: string): boolean {
    const voidTags = new Set<string>([
      'area', 'base', 'br', 'col', 'embed', 'hr', 'img',
      'input', 'link', 'meta', 'param', 'source', 'track', 'wbr'
    ]);
    return voidTags.has(tag);
  }

  // -----------------------------------------------------------------------
  // 树构建器（Tree Builder）
  // -----------------------------------------------------------------------

  /**
   * 将 Token 序列构建为 ASTNode 树。
   * 使用栈模拟递归下降，遇到 OPEN_TAG 入栈，遇到 CLOSE_TAG 出栈。
   */
  private buildTree(tokens: HtmlToken[]): ASTNode[] {
    const result: ASTNode[] = [];
    let pos = 0;

    while (pos < tokens.length) {
      const consumed = this.parseNodes(tokens, pos, result, null);
      pos = consumed;
    }

    return result;
  }

  /**
   * 从 tokens[pos] 开始解析节点，直到遇到 stopTag 的闭合标签或 token 耗尽。
   *
   * @param tokens - Token 数组
   * @param pos - 起始位置
   * @param output - 输出节点数组
   * @param stopTag - 遇到此标签的闭合标签时停止（null 表示直到末尾）
   * @returns 消费后的新 pos
   */
  private parseNodes(tokens: HtmlToken[], pos: number, output: ASTNode[], stopTag: string | null): number {
    while (pos < tokens.length) {
      const token = tokens[pos];

      // 遇到停止标签
      if (token.type === TokenType.CLOSE_TAG && token.value === stopTag) {
        return pos + 1; // 消费掉闭合标签
      }

      // ---- 文本节点 ----
      if (token.type === TokenType.TEXT) {
        const text = this.decodeEntities(token.value.trim());
        if (text.length > 0) {
          // 如果文本中含换行，拆分为多段（简化处理：每段作为独立段落）
          // 但此处作为内联文本处理更合理
          output.push({ type: ASTNodeType.TEXT, content: text });
        }
        pos++;
        continue;
      }

      // ---- 自闭合标签 ----
      if (token.type === TokenType.SELF_CLOSE) {
        const node = this.handleSelfClose(token);
        if (node) {
          output.push(node);
        }
        pos++;
        continue;
      }

      // ---- 开始标签 ----
      if (token.type === TokenType.OPEN_TAG) {
        const tagName = token.value;
        const attrs = token.attrs || new Map<string, string>();

        // 安全过滤：危险标签 —— 跳过整个标签及其内容
        if (DANGEROUS_TAGS.has(tagName)) {
          pos = this.skipTag(tokens, pos, tagName);
          continue;
        }

        // 过滤外部 stylesheet
        if (tagName === 'link' && (attrs.get('rel') || '').toLowerCase() === 'stylesheet') {
          pos++;
          continue;
        }

        // ---- 语义标签映射 ----
        const mapping = this.getTagMapping(tagName);
        if (mapping) {
          pos = this.handleMappedTag(tokens, pos, tagName, attrs, mapping, output);
        } else {
          // 无语义标签（div, span, section, article 等）—— 透传，直接处理子内容
          pos++;
          pos = this.parseNodes(tokens, pos, output, tagName);
        }
        continue;
      }

      // 未预期的闭合标签 —— 跳过
      pos++;
    }

    return pos;
  }

  /**
   * 跳过指定标签及其所有内容（用于危险标签过滤）。
   * 正确处理嵌套同名标签。
   */
  private skipTag(tokens: HtmlToken[], pos: number, tagName: string): number {
    let depth = 1;
    pos++; // 跳过开始标签
    while (pos < tokens.length && depth > 0) {
      if (tokens[pos].type === TokenType.OPEN_TAG && tokens[pos].value === tagName) {
        depth++;
      } else if (tokens[pos].type === TokenType.CLOSE_TAG && tokens[pos].value === tagName) {
        depth--;
      }
      pos++;
    }
    return pos;
  }

  /**
   * 获取标签到 ASTNodeType 的映射信息。
   * 返回 null 表示该标签无语义映射（透传处理）。
   */
  private getTagMapping(tagName: string): TagMapping | null {
    switch (tagName) {
      case 'h1': return { nodeType: ASTNodeType.HEADING, level: 1, block: true };
      case 'h2': return { nodeType: ASTNodeType.HEADING, level: 2, block: true };
      case 'h3': return { nodeType: ASTNodeType.HEADING, level: 3, block: true };
      case 'h4': return { nodeType: ASTNodeType.HEADING, level: 4, block: true };
      case 'h5': return { nodeType: ASTNodeType.HEADING, level: 5, block: true };
      case 'h6': return { nodeType: ASTNodeType.HEADING, level: 6, block: true };
      case 'p': return { nodeType: ASTNodeType.PARAGRAPH, block: true };
      case 'blockquote': return { nodeType: ASTNodeType.BLOCKQUOTE, block: true };
      case 'ul': return { nodeType: ASTNodeType.UNORDERED_LIST, block: true };
      case 'ol': return { nodeType: ASTNodeType.ORDERED_LIST, block: true };
      case 'li': return { nodeType: ASTNodeType.LIST_ITEM, block: false };
      case 'strong':
      case 'b': return { nodeType: ASTNodeType.BOLD, block: false };
      case 'em':
      case 'i': return { nodeType: ASTNodeType.ITALIC, block: false };
      case 'del':
      case 's': return { nodeType: ASTNodeType.STRIKETHROUGH, block: false };
      case 'code': return { nodeType: ASTNodeType.INLINE_CODE, block: false };
      case 'a': return { nodeType: ASTNodeType.LINK, block: false };
      case 'pre': return { nodeType: ASTNodeType.CODE_BLOCK, block: true };
      case 'table': return { nodeType: ASTNodeType.TABLE, block: true };
      default: return null;
    }
  }

  /**
   * 处理有语义映射的标签。
   * 根据映射信息构建对应的 ASTNode，递归解析子内容。
   */
  private handleMappedTag(
    tokens: HtmlToken[],
    pos: number,
    tagName: string,
    attrs: Map<string, string>,
    mapping: TagMapping,
    output: ASTNode[]
  ): number {
    pos++; // 消费开始标签

    // ---- 特殊处理：pre+code → CODE_BLOCK ----
    if (tagName === 'pre') {
      return this.handlePreBlock(tokens, pos, output);
    }

    // ---- 特殊处理：table ----
    if (tagName === 'table') {
      return this.handleTable(tokens, pos, output);
    }

    // ---- 收集子内容 ----
    const children: ASTNode[] = [];
    pos = this.parseNodes(tokens, pos, children, tagName);

    // ---- 构建节点 ----
    const node: ASTNode = { type: mapping.nodeType };

    if (mapping.level !== undefined) {
      node.level = mapping.level;
    }

    // 链接特殊处理
    if (tagName === 'a') {
      node.href = attrs.get('href') || '';
      node.title = attrs.get('title') || undefined;
    }

    if (children.length > 0) {
      node.children = children;
    }

    output.push(node);
    return pos;
  }

  /**
   * 处理 <pre> 代码块。
   * 提取内部 <code> 的文本内容，不做内联解析。
   */
  private handlePreBlock(tokens: HtmlToken[], pos: number, output: ASTNode[]): number {
    // 收集 pre 标签内的所有文本
    const codeParts: string[] = [];
    let language: string | undefined;

    while (pos < tokens.length) {
      const token = tokens[pos];
      if (token.type === TokenType.CLOSE_TAG && token.value === 'pre') {
        pos++; // 消费 </pre>
        break;
      }
      if (token.type === TokenType.OPEN_TAG && token.value === 'code') {
        // 尝试从 class 中提取语言（如 class="language-javascript"）
        const codeAttrs = token.attrs || new Map<string, string>();
        const cls = codeAttrs.get('class') || '';
        const langMatch = cls.match(/language-(\S+)/);
        if (langMatch) {
          language = langMatch[1];
        }
        pos++;
        continue;
      }
      if (token.type === TokenType.CLOSE_TAG && token.value === 'code') {
        pos++;
        continue;
      }
      if (token.type === TokenType.TEXT) {
        codeParts.push(token.value);
      }
      pos++;
    }

    const content = this.decodeEntities(codeParts.join(''));

    // 判断是否是 mermaid 或 math
    if (language === 'mermaid') {
      output.push({ type: ASTNodeType.MERMAID, content });
    } else if (language === 'math' || language === 'latex') {
      output.push({ type: ASTNodeType.MATH_BLOCK, content });
    } else {
      output.push({
        type: ASTNodeType.CODE_BLOCK,
        language: language || undefined,
        content,
      });
    }

    return pos;
  }

  /**
   * 处理 <table> 标签。
   * 提取 thead/tbody/tr/th/td，构建 TABLE 节点。
   */
  private handleTable(tokens: HtmlToken[], pos: number, output: ASTNode[]): number {
    const headers: string[][] = [];
    const rows: string[][][] = [];
    let currentRow: string[] = [];
    let isInHeader = false;

    while (pos < tokens.length) {
      const token = tokens[pos];

      // 表格结束
      if (token.type === TokenType.CLOSE_TAG && token.value === 'table') {
        pos++;
        break;
      }

      // thead 开始
      if (token.type === TokenType.OPEN_TAG && token.value === 'thead') {
        isInHeader = true;
        pos++;
        continue;
      }
      if (token.type === TokenType.CLOSE_TAG && token.value === 'thead') {
        isInHeader = false;
        pos++;
        continue;
      }

      // tbody 开始/结束
      if (token.type === TokenType.OPEN_TAG && token.value === 'tbody') {
        isInHeader = false;
        pos++;
        continue;
      }
      if (token.type === TokenType.CLOSE_TAG && token.value === 'tbody') {
        pos++;
        continue;
      }

      // tr 行
      if (token.type === TokenType.OPEN_TAG && token.value === 'tr') {
        currentRow = [];
        pos++;
        continue;
      }
      if (token.type === TokenType.CLOSE_TAG && token.value === 'tr') {
        if (isInHeader) {
          headers.push(currentRow.map((h) => h));
        } else {
          rows.push(currentRow.map((cell) => [cell]));
        }
        pos++;
        continue;
      }

      // th / td 单元格
      if (token.type === TokenType.OPEN_TAG && (token.value === 'th' || token.value === 'td')) {
        // th 默认在 header 中
        if (token.value === 'th') isInHeader = true;
        pos++;
        // 收集单元格文本
        const cellParts: string[] = [];
        while (pos < tokens.length) {
          const cellToken = tokens[pos];
          if (cellToken.type === TokenType.CLOSE_TAG &&
            (cellToken.value === 'th' || cellToken.value === 'td')) {
            pos++;
            break;
          }
          if (cellToken.type === TokenType.TEXT) {
            const text = this.decodeEntities(cellToken.value.trim());
            if (text.length > 0) cellParts.push(text);
          }
          pos++;
        }
        currentRow.push(cellParts.join(' '));
        continue;
      }

      pos++;
    }

    output.push({
      type: ASTNodeType.TABLE,
      headers: headers.map((h) => [h.join(' ')]),
      rows,
    });

    return pos;
  }

  /**
   * 处理自闭合标签（img, br, hr 等）。
   * 返回对应的 ASTNode，或 null 表示忽略。
   */
  private handleSelfClose(token: HtmlToken): ASTNode | null {
    const attrs = token.attrs || new Map<string, string>();

    switch (token.value) {
      case 'img':
        return {
          type: ASTNodeType.IMAGE,
          src: attrs.get('src') || '',
          alt: attrs.get('alt') || undefined,
          title: attrs.get('title') || undefined,
        };
      case 'br':
        return { type: ASTNodeType.LINE_BREAK };
      case 'hr':
        return { type: ASTNodeType.HORIZONTAL_RULE };
      default:
        // 其他自闭合标签忽略
        return null;
    }
  }

  // -----------------------------------------------------------------------
  // 工具方法
  // -----------------------------------------------------------------------

  /**
   * 解码常见 HTML 实体字符。
   * 覆盖最常用的实体，不做完整 HTML5 实体表解码。
   */
  private decodeEntities(text: string): string {
    let result = text;
    result = result.replace(/&amp;/g, '&');
    result = result.replace(/&lt;/g, '<');
    result = result.replace(/&gt;/g, '>');
    result = result.replace(/&quot;/g, '"');
    result = result.replace(/&#39;/g, "'");
    result = result.replace(/&apos;/g, "'");
    result = result.replace(/&nbsp;/g, ' ');
    result = result.replace(/&#(\d+);/g, (_match: string, code: string) => {
      return String.fromCharCode(parseInt(code, 10));
    });
    result = result.replace(/&#x([0-9a-fA-F]+);/g, (_match: string, hex: string) => {
      return String.fromCharCode(parseInt(hex, 16));
    });
    return result;
  }
}

// ---------------------------------------------------------------------------
// 内部接口：标签映射信息
// ---------------------------------------------------------------------------

/**
 * 标签到 ASTNodeType 的映射描述。
 * 由 getTagMapping 返回，handleMappedTag 消费。
 */
interface TagMapping {
  /** 目标 AST 节点类型 */
  nodeType: ASTNodeType;
  /** 标题层级（仅 HEADING 使用） */
  level?: number;
  /** 是否是块级元素（影响换行处理） */
  block: boolean;
}
