/**
 * SearchBar.ets
 * 搜索栏组件，替换导航栏区域显示。
 *
 * 高度 48px。左侧关闭按钮 → 输入框 → 匹配计数 → 上翻/下翻按钮。
 * 底部 1px 边框。
 */

@Component
export struct SearchBar {
  /** 搜索关键词（双向绑定） */
  @Prop keyword: string = ''
  /** 总匹配数 */
  @Prop matchCount: number = 0
  /** 当前匹配 index（从 1 开始） */
  @Prop currentIndex: number = 0

  /** 关键词变化回调 */
  onKeywordChange: (keyword: string) => void = () => {}
  /** 下一个匹配 */
  onNext: () => void = () => {}
  /** 上一个匹配 */
  onPrev: () => void = () => {}
  /** 关闭搜索栏 */
  onClose: () => void = () => {}

  /** 输入框焦点状态 */
  @State isFocused: boolean = false

  build() {
    Row({ space: 4 }) {
      /* ---- 关闭按钮 ---- */
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

      /* ---- 搜索输入框 ---- */
      TextInput({ text: this.keyword, placeholder: '搜索…' })
        .fontSize(14)
        .fontColor('#1A1A1A')
        .placeholderColor('#9CA3AF')
        .height(32)
        .layoutWeight(1)
        .backgroundColor('#F8F9FA')
        .borderRadius(8)
        .padding({ left: 8, right: 8 })
        .border({
          width: 1,
          color: this.isFocused ? '#2563EB' : '#E4E7EC'
        })
        .onChange((value: string) => {
          this.onKeywordChange(value)
        })
        .onFocus(() => {
          this.isFocused = true
        })
        .onBlur(() => {
          this.isFocused = false
        })

      /* ---- 匹配计数 ---- */
      Text(this.matchCount > 0
        ? `${this.currentIndex} / ${this.matchCount}`
        : '0 / 0')
        .fontSize(12)
        .fontColor('#6B7280')
        .textAlign(TextAlign.Center)
        .constraintSize({ minWidth: 48 })

      /* ---- 上翻按钮 ---- */
      Text('▲')
        .fontSize(14)
        .fontColor('#6B7280')
        .textAlign(TextAlign.Center)
        .width(32)
        .height(32)
        .borderRadius(8)
        .onClick(() => {
          this.onPrev()
        })

      /* ---- 下翻按钮 ---- */
      Text('▼')
        .fontSize(14)
        .fontColor('#6B7280')
        .textAlign(TextAlign.Center)
        .width(32)
        .height(32)
        .borderRadius(8)
        .onClick(() => {
          this.onNext()
        })
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
