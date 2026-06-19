import { router } from '@kit.ArkUI'

@Entry
@Component
struct HomePage {
  aboutToAppear(): void {
    const fileUri = AppStorage.get<string>('pendingFileUri') ?? ''
    if (fileUri.length > 0) this.navigateToReader()
    router.events.on('navigateToReader', () => this.navigateToReader())
  }

  aboutToDisappear(): void {
    router.events.off('navigateToReader')
  }

  private navigateToReader(): void {
    router.pushUrl({ url: 'pages/ReaderPage' })
  }

  build() {
    Column() {
      Text('MD Reader')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .width('100%')
        .height(56)
        .padding({ left: 16 })
        .textAlign(TextAlign.Start)
        .backgroundColor('#FFFFFF')
        .border({ width: { bottom: 1 }, color: '#E4E7EC' })

      Column() {
        Text('打开一个文件')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .margin({ bottom: 8 })

        Text('将 .md 或 .html 文件发送到 MD Reader 打开')
          .fontSize(14)
          .fontColor('#6B7280')
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
