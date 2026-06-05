/**
 * MathBlock.ets
 *
 * 数学公式渲染组件（WebView 降级方案）。
 * 使用 ArkUI Web 组件加载本地 rawfile/katex-render.html 页面，
 * 通过 runJavaScript 将 LaTeX 内容注入到页面中进行渲染。
 * 如果 WebView 加载失败，显示降级文本。
 */

import web_webview from '@ohos.web.webview';

@Component
export struct MathBlock {
  /** LaTeX 文本 */
  content: string = '';

  /** WebView 控制器 */
  private controller: web_webview.WebviewController = new web_webview.WebviewController();
  /** WebView 是否加载完成 */
  @State private isLoaded: boolean = false;
  /** WebView 是否加载失败 */
  @State private loadFailed: boolean = false;

  aboutToAppear(): void {
    web_webview.WebviewController.initializeWebEngine();
  }

  /** 将 LaTeX 内容注入到 WebView 页面中 */
  private injectContent(): void {
    if (!this.content) {
      return;
    }
    const escaped: string = this.content
      .replace(/\\/g, '\\\\')
      .replace(/'/g, "\\'")
      .replace(/\n/g, '\\n')
      .replace(/\r/g, '\\r');
    const script: string = `renderLatex('${escaped}');`;
    try {
      this.controller.runJavaScript(script, false);
    } catch (e) {
      console.error('[MathBlock] Failed to inject content:', JSON.stringify(e));
    }
  }

  /** 获取降级显示文本 */
  private getFallbackText(): string {
    if (!this.content) {
      return '数学公式';
    }
    const preview: string = this.content.length > 50
      ? this.content.substring(0, 50) + '...'
      : this.content;
    return `数学公式：${preview}`;
  }

  build() {
    Column() {
      if (this.loadFailed) {
        // 降级显示
        Text(this.getFallbackText())
          .fontSize(14)
          .fontColor('#6B7280')
          .fontFamily('monospace')
          .width('100%')
          .padding(16)
          .backgroundColor('#F8F9FA')
          .borderRadius(8)
      } else {
        Web({ src: 'resource://rawfile/katex-render.html', controller: this.controller })
          .width('100%')
          .height(200)
          .javaScriptAccess(true)
          .domStorageAccess(false)
          .zoomAccess(false)
          .imageAccess(true)
          .mixedMode(MixedMode.Compatible)
          .onPageEnd(() => {
            this.isLoaded = true;
            this.injectContent();
          })
          .onErrorReceive(() => {
            this.loadFailed = true;
          })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F8F9FA')
    .borderRadius(12)
    .border({
      width: 1,
      color: '#E4E7EC',
    })
    .margin({ bottom: 16 })
  }
}
