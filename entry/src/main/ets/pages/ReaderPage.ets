import { router } from '@kit.ArkUI'
import web_webview from '@ohos.web.webview'
import fs from '@ohos.file.fs'
import util from '@ohos.util'
import { RecentFile } from '../common/Types'
import {
  RECENT_FILES_KEY, PENDING_FILE_URI_KEY, PENDING_FILE_SOURCE_KEY, MAX_RECENT_FILES,
  COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_MUTED, COLOR_TEXT_SECONDARY,
  COLOR_BORDER, COLOR_SURFACE, COLOR_SURFACE_ALT
} from '../common/Constants'
import { formatSize, escapeForJs, getFileExtension, isMarkdownFile, isHtmlFile } from '../common/FileUtils'

@Entry
@Component
struct ReaderPage {
  @State fileUri: string = ''
  @State source: string = ''
  @State fileName: string = ''
  @State isLoading: boolean = true
  @State errorMessage: string = ''
  @State fileContent: string = ''
  @State fileSize: string = ''
  @State charCount: number = 0
  private controller: web_webview.WebviewController = new web_webview.WebviewController()

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string> | undefined
    if (params) {
      this.fileUri = params['fileUri'] ?? ''
      this.source = params['source'] ?? ''
    }
    if (this.fileUri.length === 0) {
      this.fileUri = AppStorage.get<string>(PENDING_FILE_URI_KEY) ?? ''
      this.source = AppStorage.get<string>(PENDING_FILE_SOURCE_KEY) ?? ''
      AppStorage.setOrCreate<string>(PENDING_FILE_URI_KEY, '')
      AppStorage.setOrCreate<string>(PENDING_FILE_SOURCE_KEY, '')
    }
    if (this.fileUri.length > 0) {
      this.fileName = this.fileUri.substring(this.fileUri.lastIndexOf('/') + 1)
    }
  }

  private saveToRecent(): void {
    const html = isHtmlFile(this.fileName)
    const record: RecentFile = {
      name: this.fileName,
      uri: this.fileUri,
      size: this.fileSize,
      time: '刚刚',
      isHtml: html
    }
    let list: RecentFile[] = []
    try {
      list = JSON.parse(AppStorage.get<string>(RECENT_FILES_KEY) ?? '[]') as RecentFile[]
    } catch (e) {
      list = []
    }
    list = list.filter((f: RecentFile) => f.uri !== this.fileUri)
    list.unshift(record)
    if (list.length > MAX_RECENT_FILES) list = list.slice(0, MAX_RECENT_FILES)
    AppStorage.setOrCreate<string>(RECENT_FILES_KEY, JSON.stringify(list))
  }

  private async loadFileContent(): Promise<void> {
    try {
      const stat = fs.statSync(this.fileUri)
      this.fileSize = formatSize(stat.size)
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
      const content = decoder.decodeToString(new Uint8Array(buf))
      this.fileContent = content
      this.charCount = content.length
      this.sendToWebView(content, isHtmlFile(this.fileName))
      this.isLoading = false
      this.saveToRecent()
    } catch (e) {
      this.errorMessage = e instanceof Error ? e.message : '文件加载失败'
      this.isLoading = false
    }
  }

  private sendToWebView(content: string, isHtml: boolean): void {
    const escaped = escapeForJs(content)
    const script = `window._renderContent('${escaped}', ${isHtml ? 'true' : 'false'});`
    try {
      this.controller.runJavaScript(script)
    } catch (e) {
      this.errorMessage = '渲染失败'
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
          .onClick(() => router.back())

        Column() {
          Text(this.fileName)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.fileSize.length > 0) {
            Text(`${this.fileSize} · ${this.charCount} 字`)
              .fontSize(11)
              .fontColor(COLOR_TEXT_MUTED)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 4 })

        if (isMarkdownFile(this.fileName)) {
          Text('编辑')
            .fontSize(14)
            .fontColor(COLOR_PRIMARY)
            .fontWeight(FontWeight.Medium)
            .height(44)
            .padding({ left: 12, right: 12 })
            .textAlign(TextAlign.Center)
            .onClick(() => {
              router.pushUrl({
                url: 'pages/EditorPage',
                params: { content: this.fileContent, fileName: this.fileName, fileUri: this.fileUri }
              })
            })
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 4, right: 12 })
      .backgroundColor(COLOR_SURFACE)
      .border({ width: { bottom: 1 }, color: COLOR_BORDER })

      // 内容区
      if (this.errorMessage.length > 0) {
        Column() {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor(COLOR_TEXT_MUTED)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(COLOR_SURFACE_ALT)
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
    .backgroundColor(COLOR_SURFACE)
  }
}
