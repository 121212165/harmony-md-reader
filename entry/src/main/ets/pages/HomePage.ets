import { router } from '@kit.ArkUI'

/**
 * 首页 - 空态引导页
 * 当没有文件打开时显示，引导用户通过三种方式打开文件
 */
@Entry
@Component
struct HomePage {
  @State pendingFileUri: string = ''

  aboutToAppear(): void {
    // 检查是否有从 EntryAbility 传入的待打开文件
    const fileUri = AppStorage.get<string>('pendingFileUri') ?? ''
    if (fileUri.length > 0) {
      this.navigateToReader()
    }

    // 监听来自 EntryAbility 的导航事件（热启动场景：App 已运行时收到新文件）
    router.events.on('navigateToReader', () => {
      this.navigateToReader()
    })
  }

  aboutToDisappear(): void {
    router.events.off('navigateToReader')
  }

  private navigateToReader(): void {
    router.pushUrl({
      url: 'pages/ReaderPage'
    })
  }

  build() {
    Column() {
      // ── 顶部导航栏 ──
      this.NavBar()

      // ── 主体内容区（居中偏上） ──
      Column() {
        // 文档图标 64x64
        Stack() {
          // 图标底色
          Column()
            .width(64)
            .height(64)
            .borderRadius(12)
            .backgroundColor('#F8F9FA')
            .border({ width: 1, color: '#E4E7EC' })

          // 文档符号
          Text('MD')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2563EB')
        }
        .width(64)
        .height(64)
        .margin({ top: 48, bottom: 24 })

        // 主标题
        Text('打开一个文件')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .margin({ bottom: 8 })

        // 说明文字
        Text('选择以下方式，将 Markdown 或 HTML 文件发送到 MD Reader 打开')
          .fontSize(14)
          .fontColor('#6B7280')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 24 })
          .padding({ left: 16, right: 16 })

        // ── 引导卡片列表 ──
        Column({ space: 8 }) {
          this.GuideCard({
            num: '1',
            title: '文件管理器',
            desc: '点击 .md 或 .html 文件，选择 MD Reader 打开'
          })

          this.GuideCard({
            num: '2',
            title: '微信 / 邮件',
            desc: '长按收到的文件，选择「用其他应用打开」'
          })

          this.GuideCard({
            num: '3',
            title: '任意 App',
            desc: '通过系统分享将文件发送到 MD Reader'
          })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  // ── 导航栏组件 ──
  @Builder
  NavBar() {
    Row() {
      Text('MD Reader')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 1 }, color: '#E4E7EC' })
  }

  // ── 引导卡片组件 ──
  @Builder
  GuideCard(params: { num: string; title: string; desc: string }) {
    Row() {
      // 序号方块 32x32
      Stack() {
        Column()
          .width(32)
          .height(32)
          .borderRadius(8)
          .backgroundColor('#F8F9FA')

        Text(params.num)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2563EB')
          .textAlign(TextAlign.Center)
      }
      .width(32)
      .height(32)
      .margin({ right: 16 })

      // 文字说明
      Column() {
        Text(`${params.title} — ${params.desc}`)
          .fontSize(14)
          .fontColor('#1A1A1A')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor('#FFFFFF')
    .border({ width: 1, color: '#E4E7EC' })
  }
}
