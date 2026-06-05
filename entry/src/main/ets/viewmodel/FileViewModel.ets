import { FileInfo, ASTNode, TocEntry } from '../parser/ASTNode'
import { FileService } from '../service/FileService'
import { MarkdownParser } from '../parser/MarkdownParser'
import { HtmlParser } from '../parser/HtmlParser'
import { TocExtractor } from '../parser/TocExtractor'

/**
 * 文件状态管理 ViewModel
 * 管理当前打开文件的完整生命周期状态
 */
@Observed
export class FileViewModel {
  /** 当前文件信息 */
  fileInfo: FileInfo | null = null
  /** 原始文件内容 */
  rawContent: string = ''
  /** 解析后的 AST 节点树 */
  astNodes: ASTNode[] = []
  /** 目录条目 */
  tocEntries: TocEntry[] = []
  /** 是否已完成加载 */
  isLoaded: boolean = false
  /** 错误信息 */
  errorMessage: string = ''

  /** 服务实例 */
  private fileService: FileService = new FileService()
  private markdownParser: MarkdownParser = new MarkdownParser()
  private htmlParser: HtmlParser = new HtmlParser()
  private tocExtractor: TocExtractor = new TocExtractor()

  /**
   * 加载并解析文件
   * 完整流程：读取 → 检测类型 → 解析 → 提取目录 → 更新状态
   * @param uri 文件 URI（file:// 或 content://）
   * @param source 文件来源描述
   */
  async loadFile(uri: string, source: string): Promise<void> {
    this.reset()

    try {
      // 1. 用 FileService 读取文件原始内容
      const content: string = await this.fileService.readFile(uri)

      // 2. 提取文件名并检测文件类型（基于扩展名）
      const fileName: string = this.fileService.extractFileName(uri)
      const rawFileType: string = this.fileService.detectFileType(fileName)
      const fileType: 'markdown' | 'html' = rawFileType === 'html' ? 'html' : 'markdown'

      // 3. 根据类型选择对应解析器，生成 AST 节点树
      let nodes: ASTNode[]
      if (fileType === 'markdown') {
        nodes = this.markdownParser.parse(content)
      } else {
        nodes = this.htmlParser.parse(content)
      }

      // 4. 从 AST 中提取目录结构
      const toc: TocEntry[] = this.tocExtractor.extract(nodes)

      // 5. 用 FileService 构建 FileInfo 元数据（含字数统计和阅读时间）
      const info: FileInfo = this.fileService.buildFileInfo(fileName, content, source)

      // 6. 原子更新所有状态字段
      this.rawContent = content
      this.astNodes = nodes
      this.tocEntries = toc
      this.fileInfo = info
      this.isLoaded = true
      this.errorMessage = ''
    } catch (e) {
      this.isLoaded = false
      if (e instanceof Error) {
        this.errorMessage = e.message
      } else {
        this.errorMessage = '文件加载失败，请检查文件格式或权限'
      }
      this.astNodes = []
      this.tocEntries = []
      this.fileInfo = null
      this.rawContent = ''
    }
  }

  /**
   * 重置所有状态到初始值
   */
  reset(): void {
    this.fileInfo = null
    this.rawContent = ''
    this.astNodes = []
    this.tocEntries = []
    this.isLoaded = false
    this.errorMessage = ''
  }
}
