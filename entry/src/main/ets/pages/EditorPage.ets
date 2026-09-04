import { router } from '@kit.ArkUI'
import web_webview from '@ohos.web.webview'
import fs from '@ohos.file.fs'
import util from '@ohos.util'
import {
  COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_MUTED, COLOR_TEXT_DISABLED, COLOR_UNSAVED,
  COLOR_BORDER, COLOR_SURFACE, COLOR_SURFACE_ALT, COLOR_DIVIDER
} from '../common/Constants'
import { escapeForJs } from '../common/FileUtils'

@Entry
@Component
struct EditorPage {
  @State content: string = ''
  @State fileName: string = ''
  @State fileUri: string = ''
  @State saved: boolean = true
  @State statusText: string = '已保存'
  private controller: web_webview.WebviewController = new web_webview.WebviewController()

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string> | undefined
    if (params) {
      this.content = params['content'] ?? ''
      this.fileName = params['fileName'] ?? '未命名.md'
      this.fileUri = params['fileUri'] ?? ''
    }
    this.saved = this.content.length === 0
  }

  private sendPreview(): void {
    const escaped = escapeForJs(this.content)
    const script = `window.postMessage({ type: 'md', content: '${escaped}' }, '*');`
    try {
      this.controller.runJavaScript(script)
    } catch (e) {
      // WebView may not be ready yet
    }
  }

  private saveFile(): void {
    if (this.fileUri.length === 0) {
      this.statusText = '无法保存（新文件）'
      return
    }
    try {
      const file = fs.openSync(this.fileUri, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE)
      const encoder = new util.TextEncoder()
      const buf = encoder.encodeInto(this.content)
      fs.writeSync(file.fd, buf)
      fs.closeSync(file.fd)
      this.saved = true
      this.statusText = '已保存'
    } catch (e) {
      this.statusText = '保存失败'
    }
  }

  build() {
    Column() {
      // 顶部工具栏
      Row() {
        Text('←')
          .fontSize(20)
          .fontColor(COLOR_TEXT)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            if (!this.saved) this.saveFile()
            router.back()
          })

        Column() {
          Text(this.fileName)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.statusText)
            .fontSize(11)
            .fontColor(this.saved ? COLOR_TEXT_MUTED : COLOR_UNSAVED)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 4 })

        Text('保存')
          .fontSize(14)
          .fontColor(this.saved ? COLOR_TEXT_DISABLED : COLOR_PRIMARY)
          .fontWeight(FontWeight.Medium)
          .height(44)
          .padding({ left: 12, right: 12 })
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.saveFile()
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 4, right: 12 })
      .backgroundColor(COLOR_SURFACE)
      .border({ width: { bottom: 1 }, color: COLOR_BORDER })

      // 编辑区 + 预览区
      Row() {
        TextInput({ text: this.content, placeholder: '输入 Markdown...' })
          .layoutWeight(1)
          .height('100%')
          .fontSize(14)
          .fontFamily('monospace')
          .backgroundColor(COLOR_SURFACE_ALT)
          .padding(12)
          .onChange((value: string) => {
            this.content = value
            this.saved = false
            this.statusText = '未保存'
            this.sendPreview()
          })

        Divider()
          .width(1)
          .height('100%')
          .color(COLOR_DIVIDER)

        Web({ src: 'resource://rawfile/editor-preview.html', controller: this.controller })
          .layoutWeight(1)
          .height('100%')
          .javaScriptAccess(true)
          .domStorageAccess(false)
          .zoomAccess(true)
          .imageAccess(true)
          .onPageEnd(() => {
            this.sendPreview()
          })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_SURFACE)
  }
}
