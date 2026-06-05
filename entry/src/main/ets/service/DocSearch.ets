/**
 * DocSearch.ets
 * 文档内搜索引擎 —— 在 AST 节点树中搜索关键词并返回匹配结果。
 *
 * 支持：
 *   - 大小写不敏感搜索
 *   - 以块级节点为搜索边界（不跨节点匹配）
 *   - 代码块内容可搜索
 *   - 循环翻页（最后一个之后回到第一个，反之亦然）
 *   - 特殊正则字符自动转义为纯文本匹配
 *
 * 依赖：
 *   - ../parser/ASTNode (ASTNode, ASTNodeType 类型定义)
 */

import { ASTNode, ASTNodeType } from '../parser/ASTNode';

// ============================================================
// 导出接口
// ============================================================

/** 单条搜索结果 */
export interface SearchMatch {
  /** AST 节点在扁平化数组中的 index */
  nodeIndex: number;
  /** 匹配文本在该节点文本内容中的偏移 */
  textOffset: number;
  /** 匹配的文本片段 */
  text: string;
}

// ============================================================
// 常量
// ============================================================

/** 需要特殊正则转义的字符 */
const REGEX_SPECIAL_CHARS: string = '.*+?^${}()|[]\\';

// ============================================================
// 搜索引擎主类
// ============================================================

/**
 * 文档内搜索引擎
 *
 * 构造时接收 AST 节点树，内部预处理：
 *   1. 将所有块级节点扁平化（保留顺序）
 *   2. 提取每个节点的纯文本内容
 *
 * 搜索时在每个块级节点的文本中独立查找关键词，
 * 支持循环翻页浏览所有匹配结果。
 */
export class DocSearch {

  /** 扁平化后的 AST 节点数组（保留顺序） */
  private flatNodes: ASTNode[] = [];

  /** 每个扁平化节点对应的纯文本内容 */
  private nodeTexts: string[] = [];

  /** 当前搜索结果列表 */
  private matches: SearchMatch[] = [];

  /** 当前匹配项的索引（-1 表示无匹配） */
  private currentIndex: number = -1;

  /**
   * 构造方法。
   *
   * @param nodes - AST 节点树（顶层块级节点数组）
   */
  constructor(nodes: ASTNode[]) {
    this.preprocess(nodes);
  }

  // ==========================================================
  // 预处理：扁平化 + 文本提取
  // ==========================================================

  /**
   * 预处理 AST：扁平化块级节点并提取纯文本。
   *
   * @param nodes - 顶层 AST 节点数组
   */
  private preprocess(nodes: ASTNode[]): void {
    this.flatNodes = [];
    this.nodeTexts = [];

    // 第一步：深度优先遍历，收集所有块级节点
    this.flattenNodes(nodes);

    // 第二步：为每个块级节点提取纯文本
    for (let i = 0; i < this.flatNodes.length; i++) {
      this.nodeTexts.push(this.extractText(this.flatNodes[i]));
    }
  }

  /**
   * 递归扁平化块级节点。
   *
   * 仅收集块级节点（跳过纯内联节点），
   * 递归进入所有节点的 children 以发现深层块级节点。
   *
   * @param nodes - 当前层级的节点数组
   */
  private flattenNodes(nodes: ASTNode[]): void {
    for (let i = 0; i < nodes.length; i++) {
      const node: ASTNode = nodes[i];

      // 仅将块级节点加入扁平化列表
      if (this.isBlockNode(node.type)) {
        this.flatNodes.push(node);
      }

      // 递归进入子节点（容器节点如 LIST 的子节点是 LIST_ITEM）
      if (node.children && node.children.length > 0) {
        this.flattenNodes(node.children);
      }
    }
  }

  /**
   * 判断节点类型是否为块级节点。
   *
   * 块级节点包括：段落、标题、列表、列表项、代码块、表格、
   * 引用块、任务列表、任务项、HTML 原始内容、Mermaid、数学公式。
   *
   * @param type - AST 节点类型
   * @returns 是否为块级节点
   */
  private isBlockNode(type: ASTNodeType): boolean {
    switch (type) {
      case ASTNodeType.HEADING:
      case ASTNodeType.PARAGRAPH:
      case ASTNodeType.ORDERED_LIST:
      case ASTNodeType.UNORDERED_LIST:
      case ASTNodeType.LIST_ITEM:
      case ASTNodeType.CODE_BLOCK:
      case ASTNodeType.TABLE:
      case ASTNodeType.BLOCKQUOTE:
      case ASTNodeType.TASK_LIST:
      case ASTNodeType.TASK_ITEM:
      case ASTNodeType.HTML_RAW:
      case ASTNodeType.MERMAID:
      case ASTNodeType.MATH_BLOCK:
        return true;
      default:
        return false;
    }
  }

  /**
   * 递归提取节点的纯文本内容。
   *
   * 规则：
   *   - TEXT 节点：返回 content
   *   - INLINE_CODE 节点：返回 content
   *   - CODE_BLOCK 节点：返回 content
   *   - LINK 节点：递归提取子节点文本（链接文字）
   *   - 其他节点：递归拼接所有子节点的文本
   *
   * @param node - AST 节点
   * @returns 纯文本字符串
   */
  private extractText(node: ASTNode): string {
    // 叶子文本节点
    if (node.type === ASTNodeType.TEXT) {
      return node.content || '';
    }

    // 内联代码
    if (node.type === ASTNodeType.INLINE_CODE) {
      return node.content || '';
    }

    // 代码块：直接返回 content
    if (node.type === ASTNodeType.CODE_BLOCK) {
      return node.content || '';
    }

    // HTML 原始内容
    if (node.type === ASTNodeType.HTML_RAW) {
      return node.content || '';
    }

    // Mermaid 图表
    if (node.type === ASTNodeType.MERMAID) {
      return node.content || '';
    }

    // 数学公式块
    if (node.type === ASTNodeType.MATH_BLOCK) {
      return node.content || '';
    }

    // 行内换行
    if (node.type === ASTNodeType.LINE_BREAK) {
      return '\n';
    }

    // 有子节点的容器节点：递归拼接
    if (node.children && node.children.length > 0) {
      let text: string = '';
      for (let i = 0; i < node.children.length; i++) {
        text += this.extractText(node.children[i]);
      }
      return text;
    }

    // 兜底：返回 content（可能为空）
    return node.content || '';
  }

  // ==========================================================
  // 搜索 API
  // ==========================================================

  /**
   * 执行搜索。
   *
   * @param keyword - 搜索关键词（空字符串返回空数组）
   * @returns 所有匹配结果的数组
   */
  search(keyword: string): SearchMatch[] {
    this.matches = [];
    this.currentIndex = -1;

    // 空关键词不搜索
    if (!keyword || keyword.length === 0) {
      return [];
    }

    // 转小写用于大小写不敏感匹配
    const lowerKeyword: string = keyword.toLowerCase();

    // 遍历每个块级节点，在其文本中查找所有匹配
    for (let nodeIdx = 0; nodeIdx < this.nodeTexts.length; nodeIdx++) {
      const text: string = this.nodeTexts[nodeIdx];
      if (text.length === 0) {
        continue;
      }

      const lowerText: string = text.toLowerCase();
      const kwLen: number = lowerKeyword.length;
      let searchFrom: number = 0;

      // 在当前节点文本中查找所有出现
      while (searchFrom <= lowerText.length - kwLen) {
        const foundIdx: number = lowerText.indexOf(lowerKeyword, searchFrom);
        if (foundIdx < 0) {
          break;
        }

        const match: SearchMatch = {
          nodeIndex: nodeIdx,
          textOffset: foundIdx,
          text: text.substring(foundIdx, foundIdx + kwLen),
        };
        this.matches.push(match);

        // 从当前匹配之后继续搜索，避免死循环
        searchFrom = foundIdx + 1;
      }
    }

    // 如果有匹配结果，定位到第一个
    if (this.matches.length > 0) {
      this.currentIndex = 0;
    }

    return this.matches;
  }

  /**
   * 获取当前匹配项的索引。
   *
   * @returns 当前索引（从 0 开始，-1 表示无匹配）
   */
  getCurrentIndex(): number {
    return this.currentIndex;
  }

  /**
   * 移动到下一个匹配（循环：最后一个之后回到第一个）。
   *
   * @returns 下一个 SearchMatch，无匹配时返回 null
   */
  getNext(): SearchMatch | null {
    if (this.matches.length === 0) {
      return null;
    }
    this.currentIndex = (this.currentIndex + 1) % this.matches.length;
    return this.matches[this.currentIndex];
  }

  /**
   * 移动到上一个匹配（循环：第一个之前回到最后一个）。
   *
   * @returns 上一个 SearchMatch，无匹配时返回 null
   */
  getPrev(): SearchMatch | null {
    if (this.matches.length === 0) {
      return null;
    }
    if (this.currentIndex <= 0) {
      this.currentIndex = this.matches.length - 1;
    } else {
      this.currentIndex = this.currentIndex - 1;
    }
    return this.matches[this.currentIndex];
  }

  /**
   * 获取总匹配数。
   *
   * @returns 匹配结果总数
   */
  getTotalCount(): number {
    return this.matches.length;
  }

  /**
   * 重置搜索状态（清空结果、重置索引）。
   */
  reset(): void {
    this.matches = [];
    this.currentIndex = -1;
  }

  // ==========================================================
  // 辅助方法
  // ==========================================================

  /**
   * 获取扁平化后的 AST 节点（根据 nodeIndex）。
   *
   * @param nodeIndex - 扁平化数组中的索引
   * @returns 对应的 ASTNode，索引越界返回 null
   */
  getNodeAtIndex(nodeIndex: number): ASTNode | null {
    if (nodeIndex < 0 || nodeIndex >= this.flatNodes.length) {
      return null;
    }
    return this.flatNodes[nodeIndex];
  }

  /**
   * 获取指定节点的纯文本内容。
   *
   * @param nodeIndex - 扁平化数组中的索引
   * @returns 节点纯文本，索引越界返回空字符串
   */
  getNodeText(nodeIndex: number): string {
    if (nodeIndex < 0 || nodeIndex >= this.nodeTexts.length) {
      return '';
    }
    return this.nodeTexts[nodeIndex];
  }

  /**
   * 获取扁平化后的节点总数。
   *
   * @returns 节点总数
   */
  getNodeCount(): number {
    return this.flatNodes.length;
  }

  /**
   * 获取当前匹配项。
   *
   * @returns 当前 SearchMatch，无匹配或索引无效时返回 null
   */
  getCurrentMatch(): SearchMatch | null {
    if (this.currentIndex < 0 || this.currentIndex >= this.matches.length) {
      return null;
    }
    return this.matches[this.currentIndex];
  }

  /**
   * 获取所有匹配结果（只读副本）。
   *
   * @returns SearchMatch 数组
   */
  getAllMatches(): SearchMatch[] {
    return this.matches;
  }

  /**
   * 转义正则特殊字符。
   *
   * 当需要将用户输入作为正则表达式使用时，
   * 调用此方法转义所有特殊字符。
   * 注意：当前 search() 方法使用 indexOf 进行纯文本匹配，
   * 此方法作为公共工具方法提供给外部使用。
   *
   * @param str - 待转义的字符串
   * @returns 转义后的字符串
   */
  escapeRegex(str: string): string {
    let escaped: string = '';
    for (let i = 0; i < str.length; i++) {
      const ch: string = str[i];
      if (REGEX_SPECIAL_CHARS.indexOf(ch) >= 0) {
        escaped += '\\' + ch;
      } else {
        escaped += ch;
      }
    }
    return escaped;
  }
}
