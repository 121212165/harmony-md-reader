/**
 * InfoPanel.ets
 * 文件信息面板（右侧抽屉）。
 *
 * 宽 280px，白色背景，左边框。
 * 四个分组：基本信息、HTML 属性（仅 HTML）、内容统计、资源状态。
 */

import { FileInfo } from '../parser/ASTNode'

/** 资源状态 */
export interface ResourceStatus {
  stylesheet: string
  scripts: string
  images: string
}

@Component
export struct InfoPanel {
  /** 是否可见 */
  @Prop isVisible: boolean = false
  /** 文件基本信息 */
  @Prop fileInfo: FileInfo = {
    fileName: '',
    fileType: '',
    fileSize: '',
    source: '',
    htmlTitle: '',
    encoding: '',
    language: '',
    viewport: '',
    wordCount: 0,
    readingTime: '',
    sectionCount: 0,
    imageCount: 0,
    linkCount: 0
  }
  /** 资源加载状态 */
  @Prop resourceStatus: ResourceStatus = {
    stylesheet: '正常',
    scripts: '正常',
    images: '正常'
  }

  /** 关闭回调 */
  onClose: () => void = () => {}

  /** 是否为 HTML 文件 */
  private get isHtml(): boolean {
    return this.fileInfo.fileType.toUpperCase() === 'HTML'
  }

  /** 根据资源状态文本返回颜色 */
  private getStatusColor(status: string): string {
    if (status === '正常' || status === '已加载') return '#059669'
    if (status === '缺失' || status === '失败') return '#D97706'
    return '#6B7280'
  }

  build() {
    Stack({ alignContent: Alignment.End }) {
      /* ---- 半透明遮罩 ---- */
      if (this.isVisible) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.08)')
          .onClick(() => {
            this.onClose()
          })
      }

      /* ---- 面板主体 ---- */
      if (this.isVisible) {
        Column() {
          /* 顶部标题栏 */
          Row() {
            Text('文件信息')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
              .layoutWeight(1)
              .textAlign(TextAlign.Start)

            Text('✕')
              .fontSize(16)
              .fontColor('#6B7280')
              .textAlign(TextAlign.Center)
              .width(32)
              .height(32)
              .borderRadius(8)
              .onClick(() => {
                this.onClose()
              })
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 8 })

          /* 信息列表（可滚动） */
          Scroll() {
            Column() {
              /* ---- 分组 1：基本信息 ---- */
              this.SectionHeader('基本信息')
              this.InfoRow('文件名', this.fileInfo.fileName)
              this.DividerLine()
              this.InfoRow('类型', this.fileInfo.fileType)
              this.DividerLine()
              this.InfoRow('大小', this.fileInfo.fileSize)
              this.DividerLine()
              this.InfoRow('来源', this.fileInfo.source)

              /* ---- 分组 2：HTML 属性（仅 HTML） ---- */
              if (this.isHtml) {
                Column().height(24)
                this.SectionHeader('HTML 属性')
                this.InfoRow('标题', this.fileInfo.htmlTitle)
                this.DividerLine()
                this.InfoRow('编码', this.fileInfo.encoding)
                this.DividerLine()
                this.InfoRow('语言', this.fileInfo.language)
                this.DividerLine()
                this.InfoRow('视口', this.fileInfo.viewport)
              }

              /* ---- 分组 3：内容统计 ---- */
              Column().height(24)
              this.SectionHeader('内容统计')
              this.InfoRow('字数', this.fileInfo.wordCount.toString())
              this.DividerLine()
              this.InfoRow('预计阅读', this.fileInfo.readingTime)
              this.DividerLine()
              this.InfoRow('章节数', this.fileInfo.sectionCount.toString())
              this.DividerLine()
              this.InfoRow('图片', this.fileInfo.imageCount.toString())
              this.DividerLine()
              this.InfoRow('外链', this.fileInfo.linkCount.toString())

              /* ---- 分组 4：资源状态 ---- */
              Column().height(24)
              this.SectionHeader('资源状态')
              this.StatusRow('样式表', this.resourceStatus.stylesheet)
              this.DividerLine()
              this.StatusRow('脚本', this.resourceStatus.scripts)
              this.DividerLine()
              this.StatusRow('图片', this.resourceStatus.images)

              /* 底部留白 */
              Column().height(32)
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
        .width(280)
        .height('100%')
        .backgroundColor('#FFFFFF')
        .border({
          width: { left: 1 },
          color: '#E4E7EC'
        })
        .transition(
          TransitionEffect.translate({ x: 280 })
            .animation({ duration: 250, curve: Curve.EaseOut })
        )
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 分组标题
   */
  @Builder
  SectionHeader(title: string) {
    Text(title)
      .fontSize(12)
      .fontColor('#9CA3AF')
      .fontWeight(FontWeight.Medium)
      .width('100%')
      .padding({ bottom: 8 })
      .textAlign(TextAlign.Start)
  }

  /**
   * 普通信息行：左侧 label，右侧 value
   */
  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#6B7280')
        .layoutWeight(1)
        .textAlign(TextAlign.Start)

      Text(value)
        .fontSize(14)
        .fontColor('#1A1A1A')
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '50%' })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  /**
   * 资源状态行：value 带颜色标识
   */
  @Builder
  StatusRow(label: string, status: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#6B7280')
        .layoutWeight(1)
        .textAlign(TextAlign.Start)

      Text(status)
        .fontSize(14)
        .fontColor(this.getStatusColor(status))
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  /**
   * 行间分隔线
   */
  @Builder
  DividerLine() {
    Divider()
      .strokeWidth(1)
      .color('#E4E7EC')
      .width('100%')
  }
}
