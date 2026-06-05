/**
 * ASTNode.ets
 *
 * 统一 AST 节点定义。
 * 本文件是 MarkdownParser、HtmlParser 和 Renderer 层的共享数据结构，
 * 所有解析结果都归一化为 ASTNode 树，方便渲染层统一消费。
 */

// ---------------------------------------------------------------------------
// AST 节点类型枚举
// ---------------------------------------------------------------------------

/**
 * AST 节点类型枚举，涵盖块级元素与内联元素两大类。
 *
 * 块级元素在文档中独占一个垂直区域（段落、标题、列表等）；
 * 内联元素嵌套在块级元素内部，用于描述文本样式和链接等。
 */
export enum ASTNodeType {
  // ---- 块级元素 ----

  /** 标题，props: level(1-6), children(内联节点) */
  HEADING = 'HEADING',

  /** 段落，props: children(内联节点) */
  PARAGRAPH = 'PARAGRAPH',

  /** 有序列表，props: children(LIST_ITEM[]) */
  ORDERED_LIST = 'ORDERED_LIST',

  /** 无序列表，props: children(LIST_ITEM[]) */
  UNORDERED_LIST = 'UNORDERED_LIST',

  /** 列表项，props: children(块级或内联节点) */
  LIST_ITEM = 'LIST_ITEM',

  /** 围栏代码块，props: language(编程语言), content(代码原文) */
  CODE_BLOCK = 'CODE_BLOCK',

  /** 表格，props: headers(string[][]), rows(string[][][]) */
  TABLE = 'TABLE',

  /** 引用块，props: children(块级节点) */
  BLOCKQUOTE = 'BLOCKQUOTE',

  /** 图片（块级展示），props: src, alt, title */
  IMAGE = 'IMAGE',

  /** 水平分割线 */
  HORIZONTAL_RULE = 'HORIZONTAL_RULE',

  /** 任务列表（GFM），props: children(TASK_ITEM[]) */
  TASK_LIST = 'TASK_LIST',

  /** 任务条目（GFM），props: checked(boolean), text(string) */
  TASK_ITEM = 'TASK_ITEM',

  /** 原始 HTML 片段（无法映射到语义节点时保留），props: content */
  HTML_RAW = 'HTML_RAW',

  /** Mermaid 图表代码块，props: content(mermaid DSL 文本) */
  MERMAID = 'MERMAID',

  /** 数学公式块（LaTeX），props: content(LaTeX 文本) */
  MATH_BLOCK = 'MATH_BLOCK',

  // ---- 内联元素 ----

  /** 纯文本，props: content(string) */
  TEXT = 'TEXT',

  /** 粗体，props: children(内联节点) */
  BOLD = 'BOLD',

  /** 斜体，props: children(内联节点) */
  ITALIC = 'ITALIC',

  /** 删除线（GFM），props: children(内联节点) */
  STRIKETHROUGH = 'STRIKETHROUGH',

  /** 行内代码，props: content(string) */
  INLINE_CODE = 'INLINE_CODE',

  /** 超链接，props: href, title, children(内联节点) */
  LINK = 'LINK',

  /** 换行（硬换行 <br> 或行尾双空格） */
  LINE_BREAK = 'LINE_BREAK',
}

// ---------------------------------------------------------------------------
// AST 节点接口
// ---------------------------------------------------------------------------

/**
 * 统一 AST 节点。
 *
 * 采用"宽接口"设计——所有可能出现的字段都平铺在同一接口上，
 * 具体使用哪些字段由 `type` 决定。这样做的好处是在 ArkTS 中
 * 无需联合类型即可在各层之间传递节点数据。
 */
export interface ASTNode {
  /** 节点类型，决定后续字段含义 */
  type: ASTNodeType;

  /** 子节点列表（块级容器 / 内联容器使用） */
  children?: ASTNode[];

  // ---- 块级属性 ----

  /** HEADING 层级，取值 1-6 */
  level?: number;

  /** CODE_BLOCK 的编程语言标识（如 'typescript'、'python'） */
  language?: string;

  /** 纯文本内容：CODE_BLOCK / MERMAID / MATH_BLOCK / TEXT / INLINE_CODE / HTML_RAW / TASK_ITEM */
  content?: string;

  /** IMAGE 的图片地址 */
  src?: string;

  /** IMAGE 的替代文本 */
  alt?: string;

  /** IMAGE 或 LINK 的标题 */
  title?: string;

  /** LINK 的链接地址 */
  href?: string;

  /** TASK_ITEM 的勾选状态 */
  checked?: boolean;

  /** TABLE 表头：每个元素是一列的文本 */
  headers?: string[][];

  /** TABLE 数据行：第一维是行，第二维是列，第三维是单元格内的富文本片段 */
  rows?: string[][][];
}

// ---------------------------------------------------------------------------
// 辅助数据结构
// ---------------------------------------------------------------------------

/**
 * 目录条目，用于侧边栏目录展示。
 */
export interface TocEntry {
  /** 标题层级 1-3（仅 h1-h3 进入目录） */
  level: number;

  /** 标题的纯文本内容（去除内联格式） */
  text: string;

  /**
   * 锚点 ID，用于页面内跳转定位。
   * 基于标题文本生成，重复标题会追加 -1、-2 等后缀保证唯一。
   */
  anchor: string;
}

/**
 * HTML 文件 <head> 元数据。
 * 解析 HTML 文件时额外提取，供信息面板展示。
 */
export interface HtmlMeta {
  /** <title> 标签内容 */
  title?: string;

  /** <meta charset="..."> */
  charset?: string;

  /** <html lang="..."> */
  lang?: string;

  /** <meta name="viewport" content="..."> */
  viewport?: string;
}

/**
 * 文件基础信息，在打开文件时由 Service 层构建，
 * 随 AST 一起传递给 ViewModel / Renderer。
 */
export interface FileInfo {
  /** 文件名（含扩展名） */
  fileName: string;

  /** 文件类型：markdown / html / unknown */
  fileType: 'markdown' | 'html' | 'unknown';

  /** 文件大小，单位字节 */
  fileSize: number;

  /** 统计字数（中文字符 + 英文单词） */
  wordCount: number;

  /** 预计阅读时长，单位分钟 */
  readingTime: number;

  /** 文件来源描述（'本地文件' / '微信' / '邮件' 等） */
  source: string;

  /** 仅 HTML 文件携带的元数据 */
  htmlMeta?: HtmlMeta;
}
