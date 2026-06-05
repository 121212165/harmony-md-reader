/**
 * MarkdownParser.ets
 *
 * Markdown 解析器。
 * 将 Markdown 源文本按行扫描，识别块级元素（标题、代码块、引用、列表、
 * 表格、水平线、任务列表等），再对块级内容递归解析内联元素（粗体、斜体、
 * 删除线、行内代码、链接、图片），最终输出 ASTNode[] 树。
 *
 * 覆盖 GFM 扩展：表格、任务列表、删除线、围栏代码块。
 * 重点保证日常写作的常见元素正确解析，不追求 CommonMark 100% 合规。
 */

import { ASTNode, ASTNodeType } from './ASTNode';

// ---------------------------------------------------------------------------
// 内联解析辅助类
// ---------------------------------------------------------------------------

/**
 * 内联元素解析器。
 * 在块级元素确定后，对行内文本做二次扫描，提取粗体、斜体、
 * 删除线、行内代码、链接、图片、换行等内联节点。
 */
class InlineParser {
  /**
   * 将一段文本解析为内联 ASTNode 列表。
   * 采用"扫描 + 正则匹配"的方式，逐段消费文本。
   */
  parse(text: string): ASTNode[] {
    const nodes: ASTNode[] = [];
    let pos = 0;
    const len = text.length;

    while (pos < len) {
      let matched = false;

      // 1. 图片: ![alt](url "title")  — 必须在链接前匹配，避免被链接规则吞掉
      const imgMatch = text.slice(pos).match(/^!\[([^\]]*)\]\(([^)\s]+)(?:\s+"([^"]*)")?\)/);
      if (imgMatch) {
        nodes.push({
          type: ASTNodeType.IMAGE,
          src: imgMatch[2],
          alt: imgMatch[1],
          title: imgMatch[3] || undefined,
        });
        pos += imgMatch[0].length;
        matched = true;
        continue;
      }

      // 2. 链接: [text](url "title")
      const linkMatch = text.slice(pos).match(/^\[([^\]]+)\]\(([^)\s]+)(?:\s+"([^"]*)")?\)/);
      if (linkMatch) {
        const linkChildren = this.parse(linkMatch[1]);
        nodes.push({
          type: ASTNodeType.LINK,
          href: linkMatch[2],
          title: linkMatch[3] || undefined,
          children: linkChildren,
        });
        pos += linkMatch[0].length;
        matched = true;
        continue;
      }

      // 3. 行内代码: `code`（支持多反引号 ``code``）
      const codeMatch = text.slice(pos).match(/^(`+)([\s\S]+?)\1/);
      if (codeMatch) {
        nodes.push({
          type: ASTNodeType.INLINE_CODE,
          content: codeMatch[2].trim(),
        });
        pos += codeMatch[0].length;
        matched = true;
        continue;
      }

      // 4. 粗体: **text** 或 __text__
      const boldMatch = text.slice(pos).match(/^\*\*([\s\S]+?)\*\*/) ||
        text.slice(pos).match(/^__([\s\S]+?)__/);
      if (boldMatch) {
        nodes.push({
          type: ASTNodeType.BOLD,
          children: this.parse(boldMatch[1]),
        });
        pos += boldMatch[0].length;
        matched = true;
        continue;
      }

      // 5. 删除线: ~~text~~
      const strikeMatch = text.slice(pos).match(/^~~([\s\S]+?)~~/);
      if (strikeMatch) {
        nodes.push({
          type: ASTNodeType.STRIKETHROUGH,
          children: this.parse(strikeMatch[1]),
        });
        pos += strikeMatch[0].length;
        matched = true;
        continue;
      }

      // 6. 斜体: *text* 或 _text_（注意不要和列表的 - / _ 混淆）
      const italicMatch = text.slice(pos).match(/^\*([^\s*][\s\S]*?)\*/) ||
        text.slice(pos).match(/^_([^\s_][\s\S]*?)_/);
      if (italicMatch) {
        nodes.push({
          type: ASTNodeType.ITALIC,
          children: this.parse(italicMatch[1]),
        });
        pos += italicMatch[0].length;
        matched = true;
        continue;
      }

      // 7. 硬换行: 行尾两个以上空格 + \n，或显式 <br> / <br/>
      const brMatch = text.slice(pos).match(/^ {2,}\n/) ||
        text.slice(pos).match(/^<br\s*\/?>/i);
      if (brMatch) {
        nodes.push({ type: ASTNodeType.LINE_BREAK });
        pos += brMatch[0].length;
        matched = true;
        continue;
      }

      // 8. 普通文本 —— 消费到下一个特殊字符之前
      if (!matched) {
        const nextSpecial = text.slice(pos + 1).search(/[!`*_~\[\n<]/);
        const end = nextSpecial === -1 ? len : pos + 1 + nextSpecial;
        const plainText = text.slice(pos, end);
        if (plainText.length > 0) {
          // 合并到前一个 TEXT 节点，减少节点数量
          const lastNode = nodes[nodes.length - 1];
          if (lastNode && lastNode.type === ASTNodeType.TEXT) {
            lastNode.content = (lastNode.content || '') + plainText;
          } else {
            nodes.push({
              type: ASTNodeType.TEXT,
              content: plainText,
            });
          }
        }
        pos = end;
      }
    }

    return nodes;
  }
}

// ---------------------------------------------------------------------------
// Markdown 主解析器
// ---------------------------------------------------------------------------

/**
 * Markdown 解析器。
 *
 * 使用方式：
 * ```typescript
 * const parser = new MarkdownParser();
 * const ast = parser.parse(markdownSource);
 * ```
 */
export class MarkdownParser {
  /** 内联解析器实例，在构造函数中创建，整个解析过程复用 */
  private inlineParser: InlineParser = new InlineParser();

  /** 当前正在处理的行数组 */
  private lines: string[] = [];

  /** 当前扫描到的行索引 */
  private pos: number = 0;

  /**
   * 主入口：将 Markdown 源文本解析为 ASTNode 数组。
   *
   * @param source - Markdown 源文本
   * @returns 块级 ASTNode 列表
   */
  parse(source: string): ASTNode[] {
    // 统一换行符，去除 BOM
    const cleaned = source.replace(/\r\n/g, '\n').replace(/\r/g, '\n').replace(/^\uFEFF/, '');
    this.lines = cleaned.split('\n');
    this.pos = 0;

    const nodes: ASTNode[] = [];

    while (this.pos < this.lines.length) {
      const line = this.lines[this.pos];

      // 空行 —— 跳过，作为块级分隔符
      if (line.trim() === '') {
        this.pos++;
        continue;
      }

      // 尝试按优先级匹配各种块级元素
      const node = this.tryParseBlock();
      if (node) {
        // node 可能是单个节点，也可能是数组（如列表解析返回多个节点时拍平）
        if (Array.isArray(node)) {
          for (const n of node) {
            nodes.push(n);
          }
        } else {
          nodes.push(node);
        }
      } else {
        // 都不匹配 → 普通段落，收集连续非空行
        const paraNode = this.parseParagraph();
        nodes.push(paraNode);
      }
    }

    return nodes;
  }

  // -------------------------------------------------------------------------
  // 块级元素尝试匹配
  // -------------------------------------------------------------------------

  /**
   * 尝试从当前行匹配一个块级元素。
   * 返回 null 表示当前行不属于任何已知块级模式（应作为段落处理）。
   */
  private tryParseBlock(): ASTNode | ASTNode[] | null {
    const line = this.lines[this.pos];

    // 围栏代码块 ``` 或 ~~~
    if (/^(`{3,}|~{3,})/.test(line)) {
      return this.parseCodeBlock();
    }

    // 标题 # 至 ######
    const headingMatch = line.match(/^(#{1,6})\s+(.*)$/);
    if (headingMatch) {
      return this.parseHeading(headingMatch);
    }

    // 水平线 ---、***、___ （至少 3 个字符，可含空格）
    if (/^(\s{0,3})([-*_])\s*\2\s*\2[\s\2]*$/.test(line)) {
      this.pos++;
      return { type: ASTNodeType.HORIZONTAL_RULE };
    }

    // 表格（当前行含 |，且下一行是分隔行）
    if (this.isTableStart()) {
      return this.parseTable();
    }

    // 引用块 >
    if (/^>\s?/.test(line)) {
      return this.parseBlockquote();
    }

    // 任务列表 - [ ] 或 - [x] / * [ ] / + [ ]
    if (/^\s*[-*+]\s+\[([ xX])\]\s/.test(line)) {
      return this.parseTaskList();
    }

    // 无序列表 - / * / +
    if (/^\s*[-*+]\s+/.test(line)) {
      return this.parseUnorderedList();
    }

    // 有序列表 1. / 1)
    if (/^\s*\d+[.)]\s+/.test(line)) {
      return this.parseOrderedList();
    }

    // 数学公式块 $$
    if (/^\$\$\s*$/.test(line.trim())) {
      return this.parseMathBlock();
    }

    return null;
  }

  // -------------------------------------------------------------------------
  // 各类块级元素解析
  // -------------------------------------------------------------------------

  /**
   * 解析标题（# ~ ######）。
   * ATX 风格标题：行首 1-6 个 # 号 + 空格 + 标题文本。
   */
  private parseHeading(match: RegExpMatchArray): ASTNode {
    const level = match[1].length;
    const rawText = match[2].replace(/\s+#+\s*$/, '').trim(); // 去除尾部闭合 #
    this.pos++;
    return {
      type: ASTNodeType.HEADING,
      level,
      children: this.inlineParser.parse(rawText),
    };
  }

  /**
   * 解析围栏代码块（```language ... ```）。
   * 代码块内容原样保留，不做内联解析。
   * 若语言标识为 mermaid，则输出 MERMAID 节点；
   * 若为 math / latex，则输出 MATH_BLOCK 节点。
   */
  private parseCodeBlock(): ASTNode {
    const openLine = this.lines[this.pos];
    const fenceMatch = openLine.match(/^(`{3,}|~{3,})(.*)$/);
    const fence = fenceMatch ? fenceMatch[1] : '```';
    const lang = (fenceMatch ? fenceMatch[2] : '').trim();
    this.pos++; // 跳过开围栏行

    const codeLines: string[] = [];
    while (this.pos < this.lines.length) {
      // 闭合围栏：至少和开头一样长的相同字符
      if (this.lines[this.pos].startsWith(fence) && this.lines[this.pos].trim().length <= fence.length + 1) {
        this.pos++; // 跳过闭围栏行
        break;
      }
      codeLines.push(this.lines[this.pos]);
      this.pos++;
    }

    const content = codeLines.join('\n');

    // Mermaid 图表块
    if (lang.toLowerCase() === 'mermaid') {
      return { type: ASTNodeType.MERMAID, content };
    }

    // 数学公式块
    if (lang.toLowerCase() === 'math' || lang.toLowerCase() === 'latex') {
      return { type: ASTNodeType.MATH_BLOCK, content };
    }

    return {
      type: ASTNodeType.CODE_BLOCK,
      language: lang || undefined,
      content,
    };
  }

  /**
   * 解析数学公式块（$$ ... $$）。
   * 与围栏代码块类似，内容原样保留。
   */
  private parseMathBlock(): ASTNode {
    this.pos++; // 跳过开头的 $$
    const mathLines: string[] = [];
    while (this.pos < this.lines.length) {
      if (/^\$\$\s*$/.test(this.lines[this.pos].trim())) {
        this.pos++; // 跳过结尾的 $$
        break;
      }
      mathLines.push(this.lines[this.pos]);
      this.pos++;
    }
    return {
      type: ASTNodeType.MATH_BLOCK,
      content: mathLines.join('\n'),
    };
  }

  /**
   * 检测当前行是否是表格起始。
   * 条件：当前行含 |，且下一行是表格分隔行（如 |---|---|）。
   */
  private isTableStart(): boolean {
    if (this.pos + 1 >= this.lines.length) return false;
    const current = this.lines[this.pos];
    const next = this.lines[this.pos + 1];
    // 当前行要含 |
    if (!current.includes('|')) return false;
    // 下一行是分隔行：只含 |、-、:、空格
    return /^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$/.test(next);
  }

  /**
   * 解析 GFM 表格。
   * 将 | 分隔的表格行解析为 headers 和 rows。
   */
  private parseTable(): ASTNode {
    // 解析表头行
    const headerCells = this.parseTableRow(this.lines[this.pos]);
    this.pos++;

    // 跳过分隔行
    this.pos++;

    // 解析数据行
    const dataRows: string[][][] = [];
    while (this.pos < this.lines.length) {
      const line = this.lines[this.pos];
      // 空行或非表格行结束
      if (line.trim() === '' || !line.includes('|')) break;
      const cells = this.parseTableRow(line);
      // 每个单元格包装为 string[] 兼容接口定义
      dataRows.push(cells.map((cell) => [cell]));
      this.pos++;
    }

    return {
      type: ASTNodeType.TABLE,
      headers: headerCells.map((h) => [h]),
      rows: dataRows,
    };
  }

  /**
   * 解析表格的一行，拆分为单元格文本数组。
   * 去除首尾空管道符，按 | 分割，trim 每个单元格。
   */
  private parseTableRow(line: string): string[] {
    let trimmed = line.trim();
    // 去除首尾的 |
    if (trimmed.startsWith('|')) trimmed = trimmed.slice(1);
    if (trimmed.endsWith('|')) trimmed = trimmed.slice(0, -1);
    return trimmed.split('|').map((cell) => cell.trim());
  }

  /**
   * 解析引用块（> ...）。
   * 支持多层嵌套：收集所有 > 前缀行，去掉一层 > 后递归解析。
   */
  private parseBlockquote(): ASTNode {
    const quoteLines: string[] = [];
    while (this.pos < this.lines.length) {
      const line = this.lines[this.pos];
      if (/^>\s?/.test(line)) {
        // 去掉一层 > 前缀
        quoteLines.push(line.replace(/^>\s?/, ''));
        this.pos++;
      } else if (line.trim() === '') {
        // 引用块中的空行可能属于引用内部，也可能结束引用
        // 如果下一行还是 > 开头，则继续
        if (this.pos + 1 < this.lines.length && /^>\s?/.test(this.lines[this.pos + 1])) {
          quoteLines.push('');
          this.pos++;
        } else {
          break;
        }
      } else {
        // 非 > 开头的行结束引用（lazy continuation 不实现以保持简单）
        break;
      }
    }

    // 递归解析引用内容（可能包含标题、列表、嵌套引用等）
    const innerSource = quoteLines.join('\n');
    const innerParser = new MarkdownParser();
    const children = innerParser.parse(innerSource);

    return {
      type: ASTNodeType.BLOCKQUOTE,
      children,
    };
  }

  /**
   * 解析任务列表（GFM 扩展）。
   * 格式：- [ ] 未完成项  /  - [x] 已完成项
   */
  private parseTaskList(): ASTNode {
    const items: ASTNode[] = [];
    while (this.pos < this.lines.length) {
      const line = this.lines[this.pos];
      const taskMatch = line.match(/^\s*[-*+]\s+\[([ xX])\]\s+(.*)$/);
      if (!taskMatch) break;

      items.push({
        type: ASTNodeType.TASK_ITEM,
        checked: taskMatch[1].toLowerCase() === 'x',
        content: taskMatch[2],
      });
      this.pos++;
    }

    return {
      type: ASTNodeType.TASK_LIST,
      children: items,
    };
  }

  /**
   * 解析无序列表（- / * / + 开头）。
   * 每个列表项的内容做内联解析。
   */
  private parseUnorderedList(): ASTNode {
    const items: ASTNode[] = [];
    while (this.pos < this.lines.length) {
      const line = this.lines[this.pos];
      const listMatch = line.match(/^(\s*)([-*+])\s+(.*)$/);
      if (!listMatch) break;

      // 检查是否是任务列表项（如果碰到则退出，让外层处理）
      if (/^\s*[-*+]\s+\[([ xX])\]\s/.test(line)) break;

      const itemText = listMatch[3];
      // 收集续行（缩进行属于当前列表项）
      const itemLines: string[] = [itemText];
      this.pos++;
      while (this.pos < this.lines.length) {
        const nextLine = this.lines[this.pos];
        // 空行或新的列表项或缩进行结束
        if (nextLine.trim() === '' || /^\s*[-*+]\s+/.test(nextLine) || /^\s*\d+[.)]\s+/.test(nextLine)) break;
        // 缩进行（至少 2 个空格开头）属于当前项
        if (/^\s{2,}/.test(nextLine)) {
          itemLines.push(nextLine.trim());
          this.pos++;
        } else {
          break;
        }
      }

      items.push({
        type: ASTNodeType.LIST_ITEM,
        children: this.inlineParser.parse(itemLines.join(' ')),
      });
    }

    return {
      type: ASTNodeType.UNORDERED_LIST,
      children: items,
    };
  }

  /**
   * 解析有序列表（1. / 1) 开头）。
   * 每个列表项的内容做内联解析。
   */
  private parseOrderedList(): ASTNode {
    const items: ASTNode[] = [];
    while (this.pos < this.lines.length) {
      const line = this.lines[this.pos];
      const listMatch = line.match(/^(\s*)\d+[.)]\s+(.*)$/);
      if (!listMatch) break;

      const itemText = listMatch[2];
      const itemLines: string[] = [itemText];
      this.pos++;
      while (this.pos < this.lines.length) {
        const nextLine = this.lines[this.pos];
        if (nextLine.trim() === '' || /^\s*\d+[.)]\s+/.test(nextLine) || /^\s*[-*+]\s+/.test(nextLine)) break;
        if (/^\s{2,}/.test(nextLine)) {
          itemLines.push(nextLine.trim());
          this.pos++;
        } else {
          break;
        }
      }

      items.push({
        type: ASTNodeType.LIST_ITEM,
        children: this.inlineParser.parse(itemLines.join(' ')),
      });
    }

    return {
      type: ASTNodeType.ORDERED_LIST,
      children: items,
    };
  }

  /**
   * 解析普通段落。
   * 收集连续非空行（直到遇到空行或新的块级元素起始），
   * 合并后做内联解析。
   */
  private parseParagraph(): ASTNode {
    const paraLines: string[] = [];
    while (this.pos < this.lines.length) {
      const line = this.lines[this.pos];
      // 空行结束段落
      if (line.trim() === '') break;
      // 块级元素起始行结束段落
      if (/^#{1,6}\s+/.test(line)) break;
      if (/^(`{3,}|~{3,})/.test(line)) break;
      if (/^>\s?/.test(line)) break;
      if (/^\s*[-*+]\s+/.test(line)) break;
      if (/^\s*\d+[.)]\s+/.test(line)) break;
      if (/^(\s{0,3})([-*_])\s*\2\s*\2[\s\2]*$/.test(line)) break;
      if (/^\$\$\s*$/.test(line.trim())) break;
      // 表格起始（含 | 且下一行是分隔行）也结束段落
      if (this.isTableStart()) break;

      paraLines.push(line);
      this.pos++;
    }

    const text = paraLines.join('\n');
    return {
      type: ASTNodeType.PARAGRAPH,
      children: this.inlineParser.parse(text),
    };
  }
}
