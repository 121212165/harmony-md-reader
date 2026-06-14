import { router } from '@kit.ArkUI'
import web_webview from '@ohos.web.webview'
import fs from '@ohos.file.fs'
import util from '@ohos.util'

@Entry
@Component
struct ReaderPage {
  @State fileUri: string = ''
  @State source: string = ''
  @State fileName: string = ''
  @State isLoading: boolean = true
  @State errorMessage: string = ''
  private controller: web_webview.WebviewController = new web_webview.WebviewController()

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string> | undefined
    if (params) {
      this.fileUri = params['fileUri'] ?? ''
      this.source = params['source'] ?? ''
    }
    if (this.fileUri.length === 0) {
      this.fileUri = AppStorage.get<string>('pendingFileUri') ?? ''
      this.source = AppStorage.get<string>('pendingFileSource') ?? ''
      AppStorage.setOrCreate<string>('pendingFileUri', '')
      AppStorage.setOrCreate<string>('pendingFileSource', '')
    }
    if (this.fileUri.length > 0) {
      this.fileName = this.fileUri.substring(this.fileUri.lastIndexOf('/') + 1)
    }
  }

  private async loadFileContent(): Promise<void> {
    try {
      const stat = fs.statSync(this.fileUri)
      if (stat.size === 0) {
        this.errorMessage = '文件为空'
        this.isLoading = false
        return
      }
      const file = fs.openSync(this.fileUri, fs.OpenMode.READ_ONLY)
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buf)
      fs.closeSync(file.fd)
      const decoder = util.TextDecoder.create('utf-8')
      const content = decoder.decodeWithStream(new Uint8Array(buf))
      const ext = this.fileName.substring(this.fileName.lastIndexOf('.')).toLowerCase()
      const isHtml = ext === '.html' || ext === '.htm'
      this.sendToWebView(content, isHtml)
      this.isLoading = false
    } catch (e) {
      this.errorMessage = e instanceof Error ? e.message : '文件加载失败'
      this.isLoading = false
    }
  }

  private sendToWebView(content: string, isHtml: boolean): void {
    const escaped = content.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\n/g, '\\n').replace(/\r/g, '\\r')
    const script = `window._renderContent('${escaped}', ${isHtml ? 'true' : 'false'});`
    try {
      this.controller.runJavaScript(script, false)
    } catch (e) {
      this.errorMessage = '渲染失败'
    }
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(20)
          .fontColor('#1A1A1A')
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick(() => router.back())

        Text(this.fileName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 8 })
      }
      .width('100%')
      .height(48)
      .padding({ left: 8, right: 8 })
      .backgroundColor('#FFFFFF')
      .border({ width: { bottom: 1 }, color: '#E4E7EC' })

      if (this.errorMessage.length > 0) {
        Column() {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor('#6B7280')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Web({ src: 'resource://rawfile/web-template.html', controller: this.controller })
          .width('100%')
          .layoutWeight(1)
          .javaScriptAccess(true)
          .domStorageAccess(false)
          .zoomAccess(true)
          .imageAccess(true)
          .mixedMode(MixedMode.Compatible)
          .onPageEnd(() => {
            if (this.fileUri.length > 0) {
              this.loadFileContent()
            }
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
