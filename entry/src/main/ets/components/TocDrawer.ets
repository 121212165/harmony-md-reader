/**
 * TocDrawer.ets
 * 目录导航抽屉组件（左侧滑出）。
 *
 * 宽 280px，白色背景，右边框。
 * H1/H2/H3 不同缩进与样式，当前高亮条目有品牌色左边框 + 浅底。
 * 半透明遮罩，点击关闭。
 */

import { TocEntry } from '../parser/ASTNode'

@Component
export struct TocDrawer {
  /** 是否可见 */
  @Prop isVisible: boolean = false
  /** 目录条目数组 */
  @Prop tocEntries: TocEntry[] = []
  /** 当前高亮锚点 */
  @Prop currentAnchor: string = ''

  /** 条目点击回调 */
  onEntryClick: (anchor: string) => void = () => {}
  /** 关闭回调 */
  onClose: () => void = () => {}

  /** 根据标题层级返回左内边距 */
  private getPaddingLeft(level: number): number {
    if (level === 1) return 16
    if (level === 2) return 32
    return 48
  }

  /** 根据层级返回字号 */
  private getFontSize(level: number): number {
    if (level <= 2) return 14
    return 12
  }

  /** 根据层级返回字色 */
  private getFontColor(level: number, isActive: boolean): string {
    if (isActive) return '#2563EB'
    if (level === 1) return '#1A1A1A'
    return '#6B7280'
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
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

      /* ---- 抽屉主体 ---- */
      if (this.isVisible) {
        Column() {
          /* 顶部标题栏 */
          Row() {
            Text('目录')
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

          /* 目录列表 */
          Scroll() {
            Column() {
              ForEach(this.tocEntries, (entry: TocEntry) => {
                this.TocItem(entry)
              }, (entry: TocEntry) => entry.anchor)
            }
            .width('100%')
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
        .width(280)
        .height('100%')
        .backgroundColor('#FFFFFF')
        .border({
          width: { right: 1 },
          color: '#E4E7EC'
        })
        .transition(
          TransitionEffect.translate({ x: -280 })
            .animation({ duration: 250, curve: Curve.EaseOut })
        )
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 单个目录条目
   */
  @Builder
  TocItem(entry: TocEntry) {
    Row() {
      Text(entry.text)
        .fontSize(this.getFontSize(entry.level))
        .fontWeight(entry.anchor === this.currentAnchor ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.getFontColor(entry.level, entry.anchor === this.currentAnchor))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .padding({
      left: this.getPaddingLeft(entry.level),
      right: 16,
      top: 8,
      bottom: 8
    })
    .backgroundColor(entry.anchor === this.currentAnchor ? '#EFF6FF' : Color.Transparent)
    .border({
      width: { left: entry.anchor === this.currentAnchor ? 2 : 0 },
      color: entry.anchor === this.currentAnchor ? '#2563EB' : Color.Transparent
    })
    .onClick(() => {
      this.onEntryClick(entry.anchor)
    })
  }
}
