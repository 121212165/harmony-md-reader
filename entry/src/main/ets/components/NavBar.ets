/**
 * NavBar.ets
 * 顶部导航栏组件。
 *
 * 高度 48px，水平排列。
 * 左侧目录按钮 → 中间文件名（截断）→ 可选徽章 → 可选视图切换 → 右侧搜索/信息按钮。
 * 底部 1px 边框分隔。
 */

import { ViewToggle } from './ViewToggle'

@Component
export struct NavBar {
  /** 文件名（超长截断） */
  @Prop title: string = ''
  /** 是否显示目录按钮 */
  @Prop showTocButton: boolean = true
  /** 是否显示搜索按钮 */
  @Prop showSearchButton: boolean = true
  /** 是否显示信息按钮 */
  @Prop showInfoButton: boolean = false
  /** 文件类型徽章文本，如 'HTML'；空字符串表示无徽章 */
  @Prop fileBadge: string = ''
  /** 是否显示渲染/源码切换 */
  @Prop showViewToggle: boolean = false
  /** 当前视图模式 */
  @Prop viewMode: string = 'render'

  /** 目录按钮点击 */
  onTocClick: () => void = () => {}
  /** 搜索按钮点击 */
  onSearchClick: () => void = () => {}
  /** 信息按钮点击 */
  onInfoClick: () => void = () => {}
  /** 视图模式切换 */
  onViewModeChange: (mode: string) => void = () => {}

  build() {
    Row({ space: 4 }) {
      /* ---- 左侧：目录按钮 ---- */
      if (this.showTocButton) {
        Text('≡')
          .fontSize(20)
          .fontColor('#6B7280')
          .textAlign(TextAlign.Center)
          .width(32)
          .height(32)
          .borderRadius(8)
          .onClick(() => {
            this.onTocClick()
          })
      }

      /* ---- 中间：文件名 ---- */
      Text(this.title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Start)

      /* ---- 文件类型徽章 ---- */
      if (this.fileBadge.length > 0) {
        Text(this.fileBadge)
          .fontSize(12)
          .fontColor('#92400E')
          .backgroundColor('#FEF3C7')
          .borderRadius(4)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      }

      /* ---- 渲染/源码切换 ---- */
      if (this.showViewToggle) {
        ViewToggle({
          currentMode: this.viewMode,
          onModeChange: (mode: string) => {
            this.onViewModeChange(mode)
          }
        })
      }

      /* ---- 右侧：搜索按钮 ---- */
      if (this.showSearchButton) {
        Text('⌕')
          .fontSize(20)
          .fontColor('#6B7280')
          .textAlign(TextAlign.Center)
          .width(32)
          .height(32)
          .borderRadius(8)
          .onClick(() => {
            this.onSearchClick()
          })
      }

      /* ---- 右侧：信息按钮 ---- */
      if (this.showInfoButton) {
        Text('ⓘ')
          .fontSize(20)
          .fontColor('#6B7280')
          .textAlign(TextAlign.Center)
          .width(32)
          .height(32)
          .borderRadius(8)
          .onClick(() => {
            this.onInfoClick()
          })
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 8, right: 8 })
    .backgroundColor('#FFFFFF')
    .border({
      width: { bottom: 1 },
      color: '#E4E7EC'
    })
  }
}
