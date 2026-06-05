// ============================================================
// 公共类型定义 - MD Reader
// ============================================================

/**
 * 文件信息
 */
export class FileInfo {
  uri: string = ''
  fileName: string = ''
  fileType: 'markdown' | 'html' = 'markdown'
  fileSize: number = 0
  lastModified: number = 0
  source: string = ''
}

/**
 * AST 节点 - 解析后的文档节点
 */
export class ASTNode {
  type: string = ''
  content: string = ''
  level: number = 0
  language: string = ''
  href: string = ''
  src: string = ''
  alt: string = ''
  id: string = ''
  ordered: boolean = false
  children: ASTNode[] = []
}

/**
 * 目录条目
 */
export class TocEntry {
  id: string = ''
  title: string = ''
  level: number = 0
}

/**
 * 搜索匹配项
 */
export class SearchMatch {
  nodeIndex: number = 0
  textPosition: number = 0
  matchedText: string = ''
}
