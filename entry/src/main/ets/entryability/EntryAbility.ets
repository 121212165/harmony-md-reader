import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { router } from '@kit.ArkUI'

const TAG: string = 'EntryAbility'
const DOMAIN: number = 0xFF00

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<string>('pendingFileUri', '')
    AppStorage.setOrCreate<string>('pendingFileSource', '')
    this.extractFileFromWant(want, '本地文件')
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.extractFileFromWant(want, '分享')
    try {
      router.events.emit({ url: 'pages/ReaderPage', name: 'navigateToReader' })
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'emit navigateToReader failed: %{public}s', JSON.stringify(e))
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/HomePage', (err) => {
      if (err) return
      const pendingUri = AppStorage.get<string>('pendingFileUri') ?? ''
      if (pendingUri.length > 0) {
        router.events.on('navigateToReader', () => {
          router.pushUrl({ url: 'pages/ReaderPage' })
        })
        router.pushUrl({ url: 'pages/ReaderPage' })
      }
    })
  }

  private extractFileFromWant(want: Want, defaultSource: string): void {
    let fileUri: string = ''
    let source: string = defaultSource
    if (want.uri && want.uri.length > 0) {
      fileUri = want.uri
    }
    if (fileUri.length === 0 && want.parameters) {
      const params = want.parameters as Record<string, string>
      if (params['fileUri'] && params['fileUri'].length > 0) {
        fileUri = params['fileUri']
        source = params['source'] ?? '分享'
      }
    }
    AppStorage.setOrCreate<string>('pendingFileUri', fileUri)
    AppStorage.setOrCreate<string>('pendingFileSource', source)
  }
}
