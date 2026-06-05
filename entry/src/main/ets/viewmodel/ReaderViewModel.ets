import { ASTNode } from '../parser/ASTNode'
import { DocSearch } from '../common/DocSearch'

/**
 * 阅读状态管理 ViewModel
 * 管理阅读过程中的所有交互状态：搜索、目录、面板、进度等
 */
@Observed
export class ReaderViewModel {
  /** 当前视图模式（仅 HTML 文件可在渲染/源码间切换） */
  viewMode: 'render' | 'source' = 'render'

  /** 是否处于搜索模式 */
  isSearching: boolean = false
  /** 搜索关键词 */
  searchKeyword: string = ''
  /** 搜索匹配总数 */
  searchMatchCount: number = 0
  /** 当前匹配索引（从 0 开始） */
  searchCurrentIndex: number = 0

  /** TOC 侧边栏是否可见 */
  isTocVisible: boolean = false
  /** 当前定位的锚点 ID */
  currentAnchor: string = ''

  /** 文件信息面板是否可见 */
  isInfoPanelVisible: boolean = false

  /** 链接预览浮层是否可见 */
  isLinkPreviewVisible: boolean = false
  /** 预览链接地址 */
  previewUrl: string = ''

  /** 阅读进度（0.0 ~ 1.0） */
  readingProgress: number = 0

  /** 文档搜索实例 */
  private docSearch: DocSearch | null = null

  // ──────────────────────────────────────────
  // 搜索相关
  // ──────────────────────────────────────────

  /**
   * 初始化搜索引擎
   * @param nodes 文档 AST 节点树
   */
  initSearch(nodes: ASTNode[]): void {
    this.docSearch = new DocSearch()
    this.docSearch.init(nodes)
  }

  /**
   * 执行搜索并定位到第一个匹配
   * @param keyword 搜索关键词
   */
  doSearch(keyword: string): void {
    this.searchKeyword = keyword
    if (!this.docSearch || keyword.length === 0) {
      this.searchMatchCount = 0
      this.searchCurrentIndex = 0
      return
    }
    const count = this.docSearch.search(keyword)
    this.searchMatchCount = count
    if (count > 0) {
      const idx = this.docSearch.next()
      this.searchCurrentIndex = idx + 1
    } else {
      this.searchCurrentIndex = 0
    }
  }

  /**
   * 跳到下一个搜索匹配
   */
  nextMatch(): void {
    if (!this.docSearch || this.searchMatchCount === 0) {
      return
    }
    const idx = this.docSearch.next()
    this.searchCurrentIndex = idx + 1
  }

  /**
   * 跳到上一个搜索匹配
   */
  prevMatch(): void {
    if (!this.docSearch || this.searchMatchCount === 0) {
      return
    }
    const idx = this.docSearch.prev()
    this.searchCurrentIndex = idx + 1
  }

  /**
   * 关闭搜索模式，清除所有搜索状态
   */
  closeSearch(): void {
    this.isSearching = false
    this.searchKeyword = ''
    this.searchMatchCount = 0
    this.searchCurrentIndex = 0
    if (this.docSearch) {
      this.docSearch.reset()
    }
  }

  // ──────────────────────────────────────────
  // 视图模式（仅 HTML 文件）
  // ──────────────────────────────────────────

  /**
   * 切换视图模式
   * @param mode 'render' 渲染视图 | 'source' 源码视图
   */
  setViewMode(mode: 'render' | 'source'): void {
    this.viewMode = mode
  }

  // ──────────────────────────────────────────
  // 目录 (TOC)
  // ──────────────────────────────────────────

  /**
   * 打开目录侧边栏
   */
  openToc(): void {
    this.isTocVisible = true
  }

  /**
   * 关闭目录侧边栏
   */
  closeToc(): void {
    this.isTocVisible = false
  }

  /**
   * 跳转到指定锚点
   * @param anchor 目标锚点 ID
   */
  jumpToAnchor(anchor: string): void {
    this.currentAnchor = anchor
    this.isTocVisible = false
  }

  // ──────────────────────────────────────────
  // 信息面板
  // ──────────────────────────────────────────

  /**
   * 打开文件信息面板
   */
  openInfoPanel(): void {
    this.isInfoPanelVisible = true
  }

  /**
   * 关闭文件信息面板
   */
  closeInfoPanel(): void {
    this.isInfoPanelVisible = false
  }

  // ──────────────────────────────────────────
  // 链接预览
  // ──────────────────────────────────────────

  /**
   * 显示链接预览浮层
   * @param url 要预览的链接地址
   */
  showLinkPreview(url: string): void {
    this.previewUrl = url
    this.isLinkPreviewVisible = true
  }

  /**
   * 隐藏链接预览浮层
   */
  hideLinkPreview(): void {
    this.isLinkPreviewVisible = false
    this.previewUrl = ''
  }

  // ──────────────────────────────────────────
  // 阅读进度
  // ──────────────────────────────────────────

  /**
   * 更新阅读进度
   * @param progress 进度值，范围 0.0 ~ 1.0
   */
  updateProgress(progress: number): void {
    if (progress < 0) {
      this.readingProgress = 0
    } else if (progress > 1) {
      this.readingProgress = 1
    } else {
      this.readingProgress = progress
    }
  }
}
