import { router } from '@kit.ArkUI'
import { emitter } from '@kit.BasicServicesKit'
import { RecentFile } from '../common/Types'
import {
  RECENT_FILES_KEY, PENDING_FILE_URI_KEY, PENDING_FILE_SOURCE_KEY,
  EVENT_NAVIGATE, APP_NAME,
  COLOR_PRIMARY, COLOR_PRIMARY_BG, COLOR_TEXT, COLOR_TEXT_SECONDARY,
  COLOR_TEXT_MUTED, COLOR_TEXT_DISABLED, COLOR_BORDER, COLOR_SURFACE, COLOR_SURFACE_ALT,
  COLOR_UNSAVED, COLOR_UNSAVED_BG
} from '../common/Constants'

@Entry
@Component
struct HomePage {
  @StorageProp(RECENT_FILES_KEY) recentFilesJson: string = '[]'
  private navigateListener: emitter.InnerEvent = { eventId: EVENT_NAVIGATE }

  aboutToAppear(): void {
    const fileUri = AppStorage.get<string>(PENDING_FILE_URI_KEY) ?? ''
    if (fileUri.length > 0) this.navigateToReader()
    emitter.on(this.navigateListener, () => this.navigateToReader())
  }

  aboutToDisappear(): void {
    emitter.off(EVENT_NAVIGATE)
  }

  private getRecentFiles(): RecentFile[] {
    try {
      return JSON.parse(this.recentFilesJson) as RecentFile[]
    } catch (e) {
      return []
    }
  }

  private navigateToReader(): void {
    router.pushUrl({ url: 'pages/ReaderPage' })
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text(APP_NAME)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
      }
      .width('100%')
      .height(56)
      .padding({ left: 20, right: 20 })
      .backgroundColor(COLOR_SURFACE)
      .border({ width: { bottom: 1 }, color: COLOR_BORDER })

      Scroll() {
        Column() {
          // 快捷操作
          Row() {
            Button() {
              Row() {
                Text('+')
                  .fontSize(18)
                  .fontColor(COLOR_PRIMARY)
                  .fontWeight(FontWeight.Bold)
                  .margin({ right: 6 })
                Text('新建文档')
                  .fontSize(14)
                  .fontColor(COLOR_PRIMARY)
              }
            }
            .type(ButtonType.Normal)
            .backgroundColor(COLOR_PRIMARY_BG)
            .borderRadius(12)
            .height(44)
            .layoutWeight(1)
            .margin({ right: 8 })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/EditorPage',
                params: { content: '', fileName: '未命名.md' }
              })
            })

            Button() {
              Row() {
                Text('打开')
                  .fontSize(14)
                  .fontColor(COLOR_SURFACE)
                  .fontWeight(FontWeight.Medium)
              }
            }
            .type(ButtonType.Normal)
            .backgroundColor(COLOR_PRIMARY)
            .borderRadius(12)
            .height(44)
            .layoutWeight(1)
            .onClick(() => {
              // 跳转到阅读页，由 EntryAbility 处理文件选择
            })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 8 })

          // 最近打开
          if (this.getRecentFiles().length > 0) {
            Text('最近打开')
              .fontSize(13)
              .fontColor(COLOR_TEXT_MUTED)
              .width('100%')
              .padding({ left: 20, top: 16, bottom: 8 })

            ForEach(this.getRecentFiles(), (file: RecentFile) => {
              Row() {
                // 文件图标
                Text(file.isHtml ? 'H' : 'M')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(file.isHtml ? COLOR_UNSAVED : COLOR_PRIMARY)
                  .textAlign(TextAlign.Center)
                  .width(36)
                  .height(36)
                  .backgroundColor(file.isHtml ? COLOR_UNSAVED_BG : COLOR_PRIMARY_BG)
                  .borderRadius(8)
                  .margin({ right: 12 })

                Column() {
                  Text(file.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(COLOR_TEXT)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(`${file.size} · ${file.time}`)
                    .fontSize(12)
                    .fontColor(COLOR_TEXT_MUTED)
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .height(64)
              .padding({ left: 20, right: 20 })
              .backgroundColor(COLOR_SURFACE)
              .borderRadius(12)
              .margin({ left: 20, right: 20, bottom: 4 })
              .onClick(() => {
                AppStorage.setOrCreate<string>(PENDING_FILE_URI_KEY, file.uri)
                AppStorage.setOrCreate<string>(PENDING_FILE_SOURCE_KEY, '最近打开')
                this.navigateToReader()
              })
            })
          }

          // 空状态
          if (this.getRecentFiles().length === 0) {
            Column() {
              Text('还没有打开过文件')
                .fontSize(16)
                .fontColor(COLOR_TEXT_MUTED)
                .margin({ bottom: 8 })

              Text('从文件管理器选择 .md 或 .html 文件\n用 MD Forge 打开')
                .fontSize(13)
                .fontColor(COLOR_TEXT_DISABLED)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ top: 80 })
            .alignItems(HorizontalAlign.Center)
          }

          // 使用提示
          Column() {
            Text('使用方式')
              .fontSize(13)
              .fontColor(COLOR_TEXT_MUTED)
              .width('100%')
              .padding({ left: 20, bottom: 8 })

            Row() {
              Text('1')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_PRIMARY)
                .textAlign(TextAlign.Center)
                .width(24)
                .height(24)
                .backgroundColor(COLOR_PRIMARY_BG)
                .borderRadius(12)
                .margin({ right: 10 })

              Text('在文件管理器中选择 .md 或 .html 文件')
                .fontSize(13)
                .fontColor(COLOR_TEXT_SECONDARY)
            }
            .width('100%')
            .padding({ left: 20, right: 20 })
            .margin({ bottom: 10 })

            Row() {
              Text('2')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_PRIMARY)
                .textAlign(TextAlign.Center)
                .width(24)
                .height(24)
                .backgroundColor(COLOR_PRIMARY_BG)
                .borderRadius(12)
                .margin({ right: 10 })

              Text('选择「用 MD Forge 打开」或「分享」')
                .fontSize(13)
                .fontColor(COLOR_TEXT_SECONDARY)
            }
            .width('100%')
            .padding({ left: 20, right: 20 })
            .margin({ bottom: 10 })

            Row() {
              Text('3')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_PRIMARY)
                .textAlign(TextAlign.Center)
                .width(24)
                .height(24)
                .backgroundColor(COLOR_PRIMARY_BG)
                .borderRadius(12)
                .margin({ right: 10 })

              Text('支持代码高亮、数学公式、Mermaid 图表')
                .fontSize(13)
                .fontColor(COLOR_TEXT_SECONDARY)
            }
            .width('100%')
            .padding({ left: 20, right: 20 })
          }
          .width('100%')
          .padding({ top: 32 })
        }
      }
      .layoutWeight(1)
      .backgroundColor(COLOR_SURFACE_ALT)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_SURFACE_ALT)
  }
}
