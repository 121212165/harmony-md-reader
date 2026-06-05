/**
 * ViewToggle.ets
 * 渲染 / 源码视图切换按钮组。
 *
 * 两个小按钮横排，共享 8px 圆角外框 + 1px 边框。
 * 激活态灰底 + 主文字 + 加粗；非激活态透明 + 弱文字。
 */

@Component
export struct ViewToggle {
  /** 当前视图模式 */
  @Prop currentMode: string = 'render'
  /** 模式切换回调 */
  onModeChange: (mode: string) => void = () => {}

  build() {
    Row() {
      /* ---- 渲染按钮 ---- */
      Text('渲染')
        .fontSize(12)
        .fontWeight(this.currentMode === 'render' ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentMode === 'render' ? '#1A1A1A' : '#9CA3AF')
        .textAlign(TextAlign.Center)
        .height(28)
        .padding({ left: 8, right: 8 })
        .backgroundColor(this.currentMode === 'render' ? '#F8F9FA' : Color.Transparent)
        .borderRadius({
          topLeft: 8,
          bottomLeft: 8,
          topRight: 0,
          bottomRight: 0
        })
        .onClick(() => {
          this.onModeChange('render')
        })

      /* ---- 中间分隔线 ---- */
      Divider()
        .vertical(true)
        .height(28)
        .strokeWidth(1)
        .color('#E4E7EC')

      /* ---- 源码按钮 ---- */
      Text('源码')
        .fontSize(12)
        .fontWeight(this.currentMode === 'source' ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentMode === 'source' ? '#1A1A1A' : '#9CA3AF')
        .textAlign(TextAlign.Center)
        .height(28)
        .padding({ left: 8, right: 8 })
        .backgroundColor(this.currentMode === 'source' ? '#F8F9FA' : Color.Transparent)
        .borderRadius({
          topLeft: 0,
          bottomLeft: 0,
          topRight: 8,
          bottomRight: 8
        })
        .onClick(() => {
          this.onModeChange('source')
        })
    }
    .borderRadius(8)
    .border({ width: 1, color: '#E4E7EC' })
    .clip(true)
  }
}
