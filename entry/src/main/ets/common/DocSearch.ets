import { ASTNode } from '../parser/ASTNode'

/**
 * 搜索匹配项
 */
export class SearchMatch {
  /** 匹配所在的节点索引 */
  nodeIndex: number = 0
  /** 匹配在节点文本中的起始位置 */
  textPosition: number = 0
  /** 匹配到的文本内容 */
  matchedText: string = ''
}

/**
 * 文档搜索工具
 * 在 AST 节点树中搜索文本匹配
 */
export class DocSearch {
  private nodes: ASTNode[] = []
  private matches: SearchMatch[] = []
  private currentIndex: number = -1

  /**
   * 初始化搜索实例
   * @param nodes AST 节点数组
   */
  init(nodes: ASTNode[]): void {
    this.nodes = nodes
    this.matches = []
    this.currentIndex = -1
  }

  /**
   * 执行搜索
   * @param keyword 搜索关键词
   * @returns 匹配数量
   */
  search(keyword: string): number {
    this.matches = []
    this.currentIndex = -1

    if (!keyword || keyword.trim().length === 0) {
      return 0
    }

    const lowerKeyword = keyword.toLowerCase()
    this.collectMatches(this.nodes, lowerKeyword)
    return this.matches.length
  }

  /**
   * 递归收集匹配项
   */
  private collectMatches(nodes: ASTNode[], keyword: string): void {
    for (let i = 0; i < nodes.length; i++) {
      const node = nodes[i]
      if (node.content && node.content.length > 0) {
        const lowerContent = node.content.toLowerCase()
        let pos = lowerContent.indexOf(keyword)
        while (pos !== -1) {
          const match = new SearchMatch()
          match.nodeIndex = i
          match.textPosition = pos
          match.matchedText = node.content.substring(pos, pos + keyword.length)
          this.matches.push(match)
          pos = lowerContent.indexOf(keyword, pos + 1)
        }
      }
      if (node.children && node.children.length > 0) {
        this.collectMatches(node.children, keyword)
      }
    }
  }

  /**
   * 跳到下一个匹配
   * @returns 当前匹配索引，-1 表示无匹配
   */
  next(): number {
    if (this.matches.length === 0) {
      return -1
    }
    this.currentIndex = (this.currentIndex + 1) % this.matches.length
    return this.currentIndex
  }

  /**
   * 跳到上一个匹配
   * @returns 当前匹配索引，-1 表示无匹配
   */
  prev(): number {
    if (this.matches.length === 0) {
      return -1
    }
    if (this.currentIndex <= 0) {
      this.currentIndex = this.matches.length - 1
    } else {
      this.currentIndex -= 1
    }
    return this.currentIndex
  }

  /**
   * 获取当前匹配
   */
  getCurrentMatch(): SearchMatch | null {
    if (this.currentIndex < 0 || this.currentIndex >= this.matches.length) {
      return null
    }
    return this.matches[this.currentIndex]
  }

  /**
   * 获取所有匹配
   */
  getMatches(): SearchMatch[] {
    return this.matches
  }

  /**
   * 获取匹配总数
   */
  getMatchCount(): number {
    return this.matches.length
  }

  /**
   * 获取当前索引
   */
  getCurrentIndex(): number {
    return this.currentIndex
  }

  /**
   * 重置搜索状态
   */
  reset(): void {
    this.matches = []
    this.currentIndex = -1
  }
}
