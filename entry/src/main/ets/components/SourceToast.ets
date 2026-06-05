/**
 * SourceToast.ets
 * 文件来源提示条。
 *
 * 在文档顶部展示来源渠道（如微信）与文件名。
 * 灰色底 + 圆角 + 左侧彩色小方块。
 */

@Component
export struct SourceToast {
  /** 来源文字，如 "微信" */
  @Prop source: string = ''
  /** 文件名 */
  @Prop fileName: string = ''
  /** 来源图标颜色，如 "#07C160" */
  @Prop iconColor: string = '#07C160'

  build() {
    Row({ space: 8 }) {
      /* 来源图标占位：16x16 彩色小方块 */
      Column()
        .width(16)
        .height(16)
        .backgroundColor(this.iconColor)
        .borderRadius(4)

      /* 来源描述文本 */
      Text(`来自${this.source} · ${this.fileName}`)
        .fontSize(12)
        .fontColor('#6B7280')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({
      top: 8,
      bottom: 8,
      left: 16,
      right: 16
    })
    .margin({ left: 8, right: 8 })
    .backgroundColor('#F8F9FA')
    .borderRadius(8)
    .border({ width: 1, color: '#E4E7EC' })
  }
}
