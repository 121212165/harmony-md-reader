/**
 * LinkPreview.ets
 * 链接预览浮层。
 *
 * 固定在底部，展示链接地址 + "复制地址" / "系统浏览器打开" 两个操作按钮。
 */

@Component
export struct LinkPreview {
  /** 是否可见 */
  @Prop isVisible: boolean = false
  /** 链接地址 */
  @Prop url: string = ''
  /** 复制链接回调 */
  onCopy: () => void = () => {}
  /** 系统浏览器打开回调 */
  onOpenExternal: () => void = () => {}
  /** 关闭回调 */
  onClose: () => void = () => {}

  build() {
    if (this.isVisible) {
      Column({ space: 16 }) {
        /* URL 文本 */
        Text(this.url)
          .fontSize(12)
          .fontColor('#2563EB')
          .width('100%')
          .wordBreak(WordBreak.BREAK_ALL)

        /* 操作按钮行 */
        Row({ space: 8 }) {
          /* 主按钮：复制地址 */
          Text('复制地址')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .height(32)
            .layoutWeight(1)
            .backgroundColor('#2563EB')
            .borderRadius(8)
            .onClick(() => {
              this.onCopy()
            })

          /* 次按钮：系统浏览器打开 */
          Text('系统浏览器打开')
            .fontSize(14)
            .fontColor('#6B7280')
            .textAlign(TextAlign.Center)
            .height(32)
            .layoutWeight(1)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .border({ width: 1, color: '#E4E7EC' })
            .onClick(() => {
              this.onOpenExternal()
            })
        }
        .width('100%')
      }
      .padding(16)
      .margin({ left: 16, right: 16, bottom: 16 })
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .border({ width: 1, color: '#E4E7EC' })
      .width('100%')
    }
  }
}
