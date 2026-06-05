import { router } from '@kit.ArkUI'
import { FileViewModel } from '../viewmodel/FileViewModel'
import { ReaderViewModel } from '../viewmodel/ReaderViewModel'
import { TocEntry, ASTNode, ASTNodeType } from '../parser/ASTNode'

/**
 * 阅读主页面
 * 整合所有阅读组件：渲染器、目录、搜索、信息面板、链接预览
 *
 * 布局从上到下：
 * 1. 阅读进度条（2px，品牌色填充）
 * 2. 导航栏 / 搜索栏（条件渲染）
 * 3. 来源提示条（非本地文件时显示）
 * 4. 主体内容区（Stack 层叠：渲染器 + 抽屉 + 浮层）
 */
@Entry
@Component
struct ReaderPage {
  @State fileVM: FileViewModel = new FileViewModel()
  @State readerVM: ReaderViewModel = new ReaderViewModel()
  @State fileUri: string = ''
  @State source: string = ''
  @State scrollOffset: number = 0
  @State scrollExtent: number = 0

  aboutToAppear(): void {
    // 优先从路由参数获取文件信息
    const params = router.getParams() as Record<string, string> | undefined
    if (params) {
      this.fileUri = params['fileUri'] ?? ''
      this.source = params['source'] ?? ''
    }

    // 回退到 AppStorage（EntryAbility 冷启动场景）
    if (this.fileUri.length === 0) {
      this.fileUri = AppStorage.get<string>('pendingFileUri') ?? ''
      this.source = AppStorage.get<string>('pendingFileSource') ?? ''
      // 清除 AppStorage 中的临时数据
      AppStorage.setOrCreate<string>('pendingFileUri', '')
      AppStorage.setOrCreate<string>('pendingFileSource', '')
    }

    // 加载文件
    if (this.fileUri.length > 0) {
      this.loadFile()
    }
  }

  private async loadFile(): Promise<void> {
    await this.fileVM.loadFile(this.fileUri, this.source)
    if (this.fileVM.isLoaded) {
      this.readerVM.initSearch(this.fileVM.astNodes)
    }
  }

  // ── 搜索回调 ──

  private onSearchActivate(): void {
    this.readerVM.isSearching = true
  }

  private onSearchChange(keyword: string): void {
    this.readerVM.doSearch(keyword)
  }

  private onSearchNext(): void {
    this.readerVM.nextMatch()
  }

  private onSearchPrev(): void {
    this.readerVM.prevMatch()
  }

  private onSearchClose(): void {
    this.readerVM.closeSearch()
  }

  // ── 导航回调 ──

  private onNavBack(): void {
    router.back()
  }

  private onNavToc(): void {
    this.readerVM.openToc()
  }

  private onNavInfo(): void {
    this.readerVM.openInfoPanel()
  }

  // ── TOC 回调 ──

  private onTocClose(): void {
    this.readerVM.closeToc()
  }

  private onTocJump(anchor: string): void {
    this.readerVM.jumpToAnchor(anchor)
  }

  // ── 信息面板回调 ──

  private onInfoClose(): void {
    this.readerVM.closeInfoPanel()
  }

  // ── 链接预览回调 ──

  private onLinkPress(url: string): void {
    this.readerVM.showLinkPreview(url)
  }

  private onLinkPreviewClose(): void {
    this.readerVM.hideLinkPreview()
  }

  // ── 滚动进度 ──

  private onContentScroll(xOffset: number, yOffset: number, scrollState: number): void {
    this.scrollOffset = yOffset
    if (this.scrollExtent > 0) {
      const progress = yOffset / this.scrollExtent
      this.readerVM.updateProgress(progress)
    }
  }

  // ── 视图切换 ──

  private onViewModeChange(mode: 'render' | 'source'): void {
    this.readerVM.setViewMode(mode)
  }

  build() {
    Column() {
      // ── 1. 阅读进度条（2px） ──
      this.ProgressBar()

      // ── 2. 导航栏 / 搜索栏（条件渲染） ──
      if (this.readerVM.isSearching) {
        this.SearchBarArea()
      } else {
        this.NavBarArea()
      }

      // ── 3. 来源提示条 ──
      if (this.source.length > 0 && this.source !== '本地文件') {
        this.SourceToastBar()
      }

      // ── 4. 主体内容区（Stack 层叠） ──
      Stack() {
        // 底层：渲染内容（可滚动）
        Scroll() {
          this.ContentArea()
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .onDidScroll((xOffset: number, yOffset: number, scrollState: number) => {
          this.onContentScroll(xOffset, yOffset, scrollState)
        })
        .onAppear(() => {
          // 延迟获取滚动区域高度
        })

        // 上层：TOC 左侧抽屉
        if (this.readerVM.isTocVisible) {
          this.TocDrawerOverlay()
        }

        // 上层：信息面板右侧抽屉
        if (this.readerVM.isInfoPanelVisible) {
          this.InfoPanelOverlay()
        }

        // 上层：链接预览底部浮层
        if (this.readerVM.isLinkPreviewVisible) {
          this.LinkPreviewOverlay()
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  // ══════════════════════════════════════════
  // 进度条
  // ══════════════════════════════════════════

  @Builder
  ProgressBar() {
    Stack({ alignContent: Alignment.Start }) {
      // 背景轨道
      Column()
        .width('100%')
        .height(2)
        .backgroundColor('#E4E7EC')

      // 填充条
      Column()
        .width(`${this.readerVM.readingProgress * 100}%`)
        .height(2)
        .backgroundColor('#2563EB')
    }
    .width('100%')
    .height(2)
  }

  // ══════════════════════════════════════════
  // 导航栏
  // ══════════════════════════════════════════

  @Builder
  NavBarArea() {
    Row() {
      // 返回按钮
      Text('←')
        .fontSize(20)
        .fontColor('#1A1A1A')
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.onNavBack() })

      // 文件名
      Text(this.fileVM.fileInfo?.fileName ?? '加载中...')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1A1A1A')
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 8 })

      // 目录按钮
      Text('目录')
        .fontSize(14)
        .fontColor('#2563EB')
        .height(40)
        .textAlign(TextAlign.Center)
        .padding({ left: 12, right: 12 })
        .onClick(() => { this.onNavToc() })

      // 搜索按钮
      Text('搜索')
        .fontSize(14)
        .fontColor('#2563EB')
        .height(40)
        .textAlign(TextAlign.Center)
        .padding({ left: 12, right: 12 })
        .onClick(() => { this.onSearchActivate() })

      // 信息按钮
      Text('ⓘ')
        .fontSize(18)
        .fontColor('#6B7280')
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.onNavInfo() })
    }
    .width('100%')
    .height(48)
    .padding({ left: 8, right: 8 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 1 }, color: '#E4E7EC' })
  }

  // ══════════════════════════════════════════
  // 搜索栏
  // ══════════════════════════════════════════

  @Builder
  SearchBarArea() {
    Row() {
      // 搜索输入框
      TextInput({ placeholder: '搜索文档内容...', text: this.readerVM.searchKeyword })
        .layoutWeight(1)
        .height(36)
        .fontSize(14)
        .borderRadius(8)
        .border({ width: 1, color: '#2563EB' })
        .backgroundColor('#EFF6FF')
        .onChange((value: string) => { this.onSearchChange(value) })

      // 匹配计数
      Text(
        this.readerVM.searchMatchCount > 0
          ? `${this.readerVM.searchCurrentIndex}/${this.readerVM.searchMatchCount}`
          : '无结果'
      )
        .fontSize(12)
        .fontColor('#6B7280')
        .margin({ left: 8 })
        .constraintSize({ minWidth: 48 })
        .textAlign(TextAlign.Center)

      // 上一个
      Text('↑')
        .fontSize(16)
        .fontColor('#2563EB')
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.onSearchPrev() })

      // 下一个
      Text('↓')
        .fontSize(16)
        .fontColor('#2563EB')
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.onSearchNext() })

      // 关闭
      Text('✕')
        .fontSize(14)
        .fontColor('#6B7280')
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.onSearchClose() })
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 8 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 1 }, color: '#E4E7EC' })
  }

  // ══════════════════════════════════════════
  // 来源提示条
  // ══════════════════════════════════════════

  @Builder
  SourceToastBar() {
    Row() {
      Text(`来源：${this.source}`)
        .fontSize(12)
        .fontColor('#2563EB')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor('#EFF6FF')
    .border({ width: { bottom: 1 }, color: '#E4E7EC' })
  }

  // ══════════════════════════════════════════
  // 内容渲染区
  // ══════════════════════════════════════════

  @Builder
  ContentArea() {
    if (!this.fileVM.isLoaded && this.fileVM.errorMessage.length === 0) {
      // 加载状态
      Column() {
        LoadingProgress()
          .width(48)
          .height(48)
          .color('#2563EB')
        Text('正在加载文件...')
          .fontSize(14)
          .fontColor('#6B7280')
          .margin({ top: 16 })
      }
      .width('100%')
      .padding({ top: 64 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else if (this.fileVM.errorMessage.length > 0) {
      // 错误状态
      Column() {
        Text('加载失败')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .margin({ bottom: 8 })
        Text(this.fileVM.errorMessage)
          .fontSize(14)
          .fontColor('#6B7280')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 24 })
        Text('返回重试')
          .fontSize(14)
          .fontColor('#2563EB')
          .padding({ left: 24, right: 24, top: 8, bottom: 8 })
          .borderRadius(8)
          .border({ width: 1, color: '#2563EB' })
          .onClick(() => { this.loadFile() })
      }
      .width('100%')
      .padding({ top: 64, left: 24, right: 24 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else if (this.fileVM.fileInfo?.fileType === 'html' && this.readerVM.viewMode === 'source') {
      // HTML 源码视图（使用 Web 组件或 Text 展示原始源码）
      Column() {
        Text(this.fileVM.rawContent)
          .fontSize(13)
          .fontColor('#ABB2BF')
          .backgroundColor('#282C34')
          .width('100%')
          .padding(16)
          .borderRadius(8)
      }
      .width('100%')
      .padding(16)
    } else if (this.fileVM.fileInfo?.fileType === 'html') {
      // HTML 渲染视图（委托给 HtmlRenderer 组件）
      Column() {
        // TODO: 替换为 HtmlRenderer 组件
        // HtmlRenderer({ nodes: this.fileVM.astNodes, onLinkPress: (url) => this.onLinkPress(url) })
        ForEach(this.fileVM.astNodes, (node: ASTNode) => {
          this.RenderNode(node)
        }, (node: ASTNode, index: number) => `${index}`)
      }
      .width('100%')
      .padding(16)
    } else {
      // Markdown 渲染视图（委托给 MarkdownRenderer 组件）
      Column() {
        // TODO: 替换为 MarkdownRenderer 组件
        // MarkdownRenderer({ nodes: this.fileVM.astNodes, onLinkPress: (url) => this.onLinkPress(url) })
        ForEach(this.fileVM.astNodes, (node: ASTNode) => {
          this.RenderNode(node)
        }, (node: ASTNode, index: number) => `${index}`)
      }
      .width('100%')
      .padding(16)
    }
  }

  // ══════════════════════════════════════════
  // 临时节点渲染器（在 Renderer 组件就绪前使用）
  // ══════════════════════════════════════════

  @Builder
  RenderNode(node: ASTNode) {
    if (node.type === ASTNodeType.HEADING) {
      Text(this.extractText(node))
        .fontSize(24 - (node.level ?? 1) * 2)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .margin({ top: 24, bottom: 8 })
        .width('100%')
    } else if (node.type === ASTNodeType.PARAGRAPH) {
      Text(this.extractText(node))
        .fontSize(14)
        .fontColor('#1A1A1A')
        .margin({ bottom: 16 })
        .width('100%')
    } else if (node.type === ASTNodeType.CODE_BLOCK) {
      Column() {
        if (node.language && node.language.length > 0) {
          Text(node.language)
            .fontSize(12)
            .fontColor('#5C6370')
            .margin({ bottom: 8 })
        }
        Text(node.content ?? '')
          .fontSize(13)
          .fontColor('#ABB2BF')
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .borderRadius(8)
      .backgroundColor('#282C34')
      .margin({ bottom: 16 })
    } else if (node.type === ASTNodeType.BLOCKQUOTE) {
      Row() {
        Column()
          .width(3)
          .height('100%')
          .backgroundColor('#2563EB')
          .borderRadius(2)
          .margin({ right: 12 })

        Text(this.extractText(node))
          .fontSize(14)
          .fontColor('#6B7280')
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: 16 })
      .padding({ left: 4 })
    } else if (node.type === ASTNodeType.LIST_ITEM) {
      Row() {
        Text('•')
          .fontSize(14)
          .fontColor('#1A1A1A')
          .width(24)
          .textAlign(TextAlign.Center)
        Text(this.extractText(node))
          .fontSize(14)
          .fontColor('#1A1A1A')
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: 4 })
    } else if (node.type === ASTNodeType.LINK) {
      Text(this.extractText(node))
        .fontSize(14)
        .fontColor('#2563EB')
        .decoration({ type: TextDecorationType.Underline, color: '#2563EB' })
        .onClick(() => { this.onLinkPress(node.href ?? '') })
    } else if (node.type === ASTNodeType.IMAGE) {
      Column() {
        Image(node.src ?? '')
          .width('100%')
          .objectFit(ImageFit.Contain)
          .borderRadius(8)
        if (node.alt && node.alt.length > 0) {
          Text(node.alt)
            .fontSize(12)
            .fontColor('#9CA3AF')
            .margin({ top: 4 })
        }
      }
      .width('100%')
      .margin({ bottom: 16 })
    } else if (node.type === ASTNodeType.HORIZONTAL_RULE) {
      Divider()
        .color('#E4E7EC')
        .margin({ top: 16, bottom: 16 })
    } else if (node.type === ASTNodeType.TASK_ITEM) {
      Row() {
        Text(node.checked ? '☑' : '☐')
          .fontSize(14)
          .fontColor('#1A1A1A')
          .width(24)
          .textAlign(TextAlign.Center)
        Text(node.content ?? '')
          .fontSize(14)
          .fontColor(node.checked ? '#9CA3AF' : '#1A1A1A')
          .decoration({
            type: node.checked ? TextDecorationType.LineThrough : TextDecorationType.None,
            color: '#9CA3AF'
          })
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: 4 })
    } else if (node.content && node.content.length > 0) {
      Text(node.content)
        .fontSize(14)
        .fontColor('#1A1A1A')
        .margin({ bottom: 8 })
        .width('100%')
    }
  }

  /**
   * 从 ASTNode 递归提取纯文本
   */
  private extractText(node: ASTNode): string {
    if (node.content && node.content.length > 0) {
      return node.content
    }
    if (node.children && node.children.length > 0) {
      return node.children.map((child: ASTNode) => this.extractText(child)).join('')
    }
    return ''
  }

  // ══════════════════════════════════════════
  // TOC 左侧抽屉覆盖层
  // ══════════════════════════════════════════

  @Builder
  TocDrawerOverlay() {
    Row() {
      // 抽屉内容
      Column() {
        Row() {
          Text('目录')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .layoutWeight(1)
          Text('✕')
            .fontSize(14)
            .fontColor('#6B7280')
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .onClick(() => { this.onTocClose() })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 8 })
        .border({ width: { bottom: 1 }, color: '#E4E7EC' })

        // 目录条目列表
        Scroll() {
          Column() {
            if (this.fileVM.tocEntries.length === 0) {
              Text('暂无目录')
                .fontSize(14)
                .fontColor('#9CA3AF')
                .margin({ top: 32 })
            } else {
              ForEach(this.fileVM.tocEntries, (entry: TocEntry) => {
                Text(entry.text)
                  .fontSize(14)
                  .fontColor(entry.anchor === this.readerVM.currentAnchor ? '#2563EB' : '#1A1A1A')
                  .fontWeight(entry.anchor === this.readerVM.currentAnchor ? FontWeight.Medium : FontWeight.Normal)
                  .width('100%')
                  .padding({
                    left: 16 + (entry.level - 1) * 16,
                    right: 16,
                    top: 12,
                    bottom: 12
                  })
                  .backgroundColor(entry.anchor === this.readerVM.currentAnchor ? '#EFF6FF' : '#FFFFFF')
                  .onClick(() => { this.onTocJump(entry.anchor) })
              }, (entry: TocEntry, index: number) => `${entry.anchor}-${index}`)
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
      .width('75%')
      .height('100%')
      .backgroundColor('#FFFFFF')
      .border({ width: { right: 1 }, color: '#E4E7EC' })

      // 遮罩层
      Column()
        .layoutWeight(1)
        .height('100%')
        .backgroundColor('#00000033')
        .onClick(() => { this.onTocClose() })
    }
    .width('100%')
    .height('100%')
  }

  // ══════════════════════════════════════════
  // 信息面板右侧抽屉覆盖层
  // ══════════════════════════════════════════

  @Builder
  InfoPanelOverlay() {
    Row() {
      // 遮罩层
      Column()
        .layoutWeight(1)
        .height('100%')
        .backgroundColor('#00000033')
        .onClick(() => { this.onInfoClose() })

      // 面板内容
      Column() {
        Row() {
          Text('文件信息')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .layoutWeight(1)
          Text('✕')
            .fontSize(14)
            .fontColor('#6B7280')
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .onClick(() => { this.onInfoClose() })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 8 })
        .border({ width: { bottom: 1 }, color: '#E4E7EC' })

        // 信息条目
        Column({ space: 0 }) {
          this.InfoRow({ label: '文件名', value: this.fileVM.fileInfo?.fileName ?? '-' })
          this.InfoRow({ label: '文件类型', value: this.fileVM.fileInfo?.fileType === 'markdown' ? 'Markdown' : 'HTML' })
          this.InfoRow({ label: '文件大小', value: this.formatFileSize(this.fileVM.fileInfo?.fileSize ?? 0) })
          this.InfoRow({ label: '字数', value: `${this.fileVM.fileInfo?.wordCount ?? 0} 字` })
          this.InfoRow({ label: '预计阅读', value: `${this.fileVM.fileInfo?.readingTime ?? 0} 分钟` })
          this.InfoRow({ label: '来源', value: this.source.length > 0 ? this.source : '本地文件' })
          this.InfoRow({ label: '目录章节', value: `${this.fileVM.tocEntries.length} 个` })
        }
        .width('100%')
        .padding(16)
      }
      .width('75%')
      .height('100%')
      .backgroundColor('#FFFFFF')
      .border({ width: { left: 1 }, color: '#E4E7EC' })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  InfoRow(params: { label: string; value: string }) {
    Column() {
      Text(params.label)
        .fontSize(12)
        .fontColor('#9CA3AF')
        .margin({ bottom: 4 })
      Text(params.value)
        .fontSize(14)
        .fontColor('#1A1A1A')
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: '#E4E7EC' })
  }

  // ══════════════════════════════════════════
  // 链接预览底部浮层
  // ══════════════════════════════════════════

  @Builder
  LinkPreviewOverlay() {
    Column() {
      // 弹性占位（上部透明区域，点击关闭）
      Column()
        .width('100%')
        .layoutWeight(1)
        .onClick(() => { this.onLinkPreviewClose() })

      // 底部浮层卡片
      Column() {
        Text('链接预览')
          .fontSize(12)
          .fontColor('#9CA3AF')
          .margin({ bottom: 8 })

        Text(this.readerVM.previewUrl)
          .fontSize(14)
          .fontColor('#2563EB')
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ bottom: 16 })

        Row() {
          Text('复制链接')
            .fontSize(14)
            .fontColor('#2563EB')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .height(36)
            .borderRadius(8)
            .border({ width: 1, color: '#2563EB' })

          Blank().width(16)

          Text('关闭')
            .fontSize(14)
            .fontColor('#6B7280')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .height(36)
            .borderRadius(8)
            .border({ width: 1, color: '#E4E7EC' })
            .onClick(() => { this.onLinkPreviewClose() })
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 12, topRight: 12 })
      .border({ width: { top: 1 }, color: '#E4E7EC' })
    }
    .width('100%')
    .height('100%')
  }

  // ── 工具方法 ──

  private formatFileSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`
    } else if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`
    } else {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
    }
  }
}
