import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { router } from '@kit.ArkUI'

const TAG: string = 'EntryAbility'
const DOMAIN: number = 0xFF00

/**
 * 应用入口 UIAbility
 * 职责：
 * 1. 处理文件关联打开（冷启动：onCreate + want 中携带文件 URI）
 * 2. 处理 Share Kit 分享接收（热启动：onNewWant）
 * 3. 初始化窗口并加载首页
 * 4. 通过 AppStorage 在 Ability 和 Page 之间传递文件信息
 */
export default class EntryAbility extends UIAbility {
  /**
   * Ability 创建时调用
   * 检查 want 中是否有文件 URI（文件关联打开场景）
   */
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onCreate')

    // 初始化 AppStorage 默认值
    AppStorage.setOrCreate<string>('pendingFileUri', '')
    AppStorage.setOrCreate<string>('pendingFileSource', '')

    // 从 want 中提取文件信息（文件关联打开场景）
    this.extractFileInfoFromWant(want, '本地文件')
  }

  /**
   * 应用已运行时收到新 Want 时调用
   * 处理 Share Kit 分享接收场景
   */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onNewWant')

    // 从 want.parameters 提取分享的文件信息
    this.extractFileInfoFromWant(want, '分享')

    // 通知已加载的页面导航到 ReaderPage
    try {
      router.events.emit({
        url: 'pages/ReaderPage',
        name: 'navigateToReader'
      })
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to emit navigation event: %{public}s', JSON.stringify(e))
    }
  }

  /**
   * 窗口阶段创建时调用
   * 加载基础页面，并根据是否有文件信息决定后续导航
   */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate')

    // 始终加载 HomePage 作为基础页面
    windowStage.loadContent('pages/HomePage', (err) => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'Failed to load HomePage: %{public}s', JSON.stringify(err))
        return
      }
      hilog.info(DOMAIN, TAG, 'HomePage loaded successfully')

      // 如果 AppStorage 中有文件信息，设置路由监听并推入 ReaderPage
      const pendingUri = AppStorage.get<string>('pendingFileUri') ?? ''
      if (pendingUri.length > 0) {
        try {
          // 注册一次性路由事件监听，HomePage 也会注册但不会冲突
          router.events.on('navigateToReader', () => {
            router.pushUrl({ url: 'pages/ReaderPage' })
          })

          // 直接推入 ReaderPage（冷启动场景）
          router.pushUrl({ url: 'pages/ReaderPage' })
          hilog.info(DOMAIN, TAG, 'Navigated to ReaderPage with file: %{public}s', pendingUri)
        } catch (e) {
          hilog.error(DOMAIN, TAG, 'Failed to navigate to ReaderPage: %{public}s', JSON.stringify(e))
        }
      }
    })
  }

  /**
   * 窗口阶段销毁时调用
   */
  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy')
  }

  /**
   * Ability 销毁时调用
   */
  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy')
  }

  /**
   * Ability 进入前台时调用
   */
  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'onForeground')
  }

  /**
   * Ability 进入后台时调用
   */
  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'onBackground')
  }

  // ──────────────────────────────────────────
  // 私有方法
  // ──────────────────────────────────────────

  /**
   * 从 Want 中提取文件 URI 并保存到 AppStorage
   *
   * 支持两种来源：
   * 1. want.uri — 文件关联打开时系统传入的文件 URI
   * 2. want.parameters['fileUri'] — Share Kit 分享时传入的文件路径
   *
   * @param want 系统传入的 Want 对象
   * @param defaultSource 默认来源描述
   */
  private extractFileInfoFromWant(want: Want, defaultSource: string): void {
    let fileUri: string = ''
    let source: string = defaultSource

    // 场景 1：文件关联打开 — want.uri 包含文件 URI
    if (want.uri && want.uri.length > 0) {
      fileUri = want.uri
      hilog.info(DOMAIN, TAG, 'File from want.uri: %{public}s', fileUri)
    }

    // 场景 2：Share Kit 分享 — want.parameters 中包含 fileUri
    if (fileUri.length === 0 && want.parameters) {
      const params = want.parameters as Record<string, string>
      if (params['fileUri'] && params['fileUri'].length > 0) {
        fileUri = params['fileUri']
        source = params['source'] ?? '分享'
        hilog.info(DOMAIN, TAG, 'File from share: %{public}s', fileUri)
      }
    }

    // 保存到 AppStorage 供 Page 层读取
    AppStorage.setOrCreate<string>('pendingFileUri', fileUri)
    AppStorage.setOrCreate<string>('pendingFileSource', source)
  }
}
