/**
 * TocExtractor.ets
 *
 * 目录提取器。
 * 遍历 AST 节点树，收集所有 HEADING 节点（仅保留 h1-h3），
 * 提取纯文本标题并生成唯一锚点 ID，用于侧边栏目录展示和页面内跳转。
 */

import { ASTNode, ASTNodeType, TocEntry } from './ASTNode';

// ---------------------------------------------------------------------------
// 常量
// ---------------------------------------------------------------------------

/** 目录最大收录标题层级（h1-h3 进目录，h4-h6 忽略） */
const MAX_TOC_LEVEL = 3;

// ---------------------------------------------------------------------------
// TocExtractor 类
// ---------------------------------------------------------------------------

/**
 * 目录提取器。
 *
 * 使用方式：
 * ```typescript
 * const extractor = new TocExtractor();
 * const toc = extractor.extract(astNodes);
 * ```
 */
export class TocExtractor {
  /** 已使用的锚点计数表，用于保证重复标题的锚点唯一 */
  private anchorCounts: Map<string, number> = new Map();

  /**
   * 从 AST 节点树中提取目录条目。
   *
   * 遍历所有块级节点（包括嵌套在 BLOCKQUOTE、LIST_ITEM 等容器内的标题），
   * 收集 HEADING 类型且 level <= 3 的节点，生成 TocEntry 列表。
   *
   * @param nodes - 块级 ASTNode 数组（来自 MarkdownParser 或 HtmlParser 的输出）
   * @returns TocEntry 列表，按文档顺序排列
   */
  extract(nodes: ASTNode[]): TocEntry[] {
    // 每次提取前重置锚点计数
    this.anchorCounts = new Map();

    const entries: TocEntry[] = [];
    this.walk(nodes, entries);
    return entries;
  }

  // -----------------------------------------------------------------------
  // 内部方法
  // -----------------------------------------------------------------------

  /**
   * 递归遍历 AST 节点，收集符合条件的标题节点。
   *
   * @param nodes - 当前层级的节点列表
   * @param entries - 收集结果的输出数组
   */
  private walk(nodes: ASTNode[], entries: TocEntry[]): void {
    for (const node of nodes) {
      // 命中 HEADING 且层级在目录收录范围内
      if (node.type === ASTNodeType.HEADING && node.level !== undefined && node.level <= MAX_TOC_LEVEL) {
        const text = this.extractPlainText(node);
        if (text.length > 0) {
          const anchor = this.generateAnchor(text);
          entries.push({
            level: node.level,
            text,
            anchor,
          });
        }
      }

      // 递归进入子节点（BLOCKQUOTE、LIST_ITEM 等容器内也可能包含标题）
      if (node.children && node.children.length > 0) {
        this.walk(node.children, entries);
      }
    }
  }

  /**
   * 从节点树中提取纯文本内容。
   * 递归展开所有内联节点，只取 TEXT、INLINE_CODE 的 content 字段，
   * 忽略 BOLD、ITALIC、LINK 等样式节点本身，取它们的子节点文本。
   *
   * @param node - 目标节点
   * @returns 拼接后的纯文本字符串
   */
  private extractPlainText(node: ASTNode): string {
    const parts: string[] = [];
    this.collectText(node, parts);
    return parts.join('').trim();
  }

  /**
   * 递归收集节点的纯文本片段。
   *
   * @param node - 当前节点
   * @param parts - 文本片段收集数组
   */
  private collectText(node: ASTNode, parts: string[]): void {
    // 有 content 字段的叶子节点
    if (node.content !== undefined && node.content !== null) {
      parts.push(node.content);
    }

    // 递归子节点
    if (node.children) {
      for (const child of node.children) {
        this.collectText(child, parts);
      }
    }
  }

  /**
   * 基于标题文本生成唯一锚点 ID。
   *
   * 生成规则：
   * 1. 转小写
   * 2. 空格和连续空白替换为 -
   * 3. 去除非字母数字和非中文/日/韩字符（保留 - 和 _）
   * 4. 去除首尾 -
   * 5. 若为空则回退为 heading
   * 6. 重复标题追加 -1、-2 等后缀保证唯一
   *
   * @param text - 标题纯文本
   * @returns 唯一的锚点 ID 字符串
   */
  private generateAnchor(text: string): string {
    // 基础 slug 生成
    let slug = text
      .toLowerCase()
      .replace(/\s+/g, '-')                     // 空白 → -
      .replace(/[^\w\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff-]/g, '') // 保留字母数字、CJK、-、_
      .replace(/-+/g, '-')                       // 合并连续 -
      .replace(/^-|-$/g, '');                    // 去首尾 -

    // 回退：如果处理后为空
    if (slug.length === 0) {
      slug = 'heading';
    }

    // 唯一性保证：重复标题追加数字后缀
    const count = this.anchorCounts.get(slug) || 0;
    this.anchorCounts.set(slug, count + 1);

    if (count === 0) {
      return slug;
    }
    return `${slug}-${count}`;
  }
}
