/**
 * MermaidBlock.ets
 *
 * Mermaid 图表渲染组件（WebView 降级方案）。
 * 使用 ArkUI Web 组件加载本地 rawfile/mermaid-render.html 页面，
 * 通过 runJavaScript 将 Mermaid DSL 内容注入到页面中进行渲染。
 * 如果 WebView 加载失败，显示降级文本。
 */

import web_webview from '@ohos.web.webview';

@Component
export struct MermaidBlock {
  /** Mermaid DSL 文本 */
  content: string = '';

  /** WebView 控制器 */
  private controller: web_webview.WebviewController = new web_webview.WebviewController();
  /** WebView 是否加载完成 */
  @State private isLoaded: boolean = false;
  /** WebView 是否加载失败 */
  @State private loadFailed: boolean = false;

  aboutToAppear(): void {
    // 配置 WebView 设置
    web_webview.WebviewController.initializeWebEngine();
  }

  /** 将 Mermaid 内容注入到 WebView 页面中 */
  private injectContent(): void {
    if (!this.content) {
      return;
    }
    // 将内容转义后通过 JS 注入
    const escaped: string = this.content
      .replace(/\\/g, '\\\\')
      .replace(/'/g, "\\'")
      .replace(/\n/g, '\\n')
      .replace(/\r/g, '\\r');
    const script: string = `renderMermaid('${escaped}');`;
    try {
      this.controller.runJavaScript(script, false);
    } catch (e) {
      console.error('[MermaidBlock] Failed to inject content:', JSON.stringify(e));
    }
  }

  /** 获取降级显示文本 */
  private getFallbackText(): string {
    if (!this.content) {
      return 'Mermaid 图表';
    }
    const preview: string = this.content.length > 50
      ? this.content.substring(0, 50) + '...'
      : this.content;
    return `Mermaid 图表：${preview}`;
  }

  /** 从 Mermaid DSL 内容中提取图表类型 */
  private getMermaidType(): string {
    if (!this.content) {
      return 'flowchart';
    }
    const trimmed: string = this.content.trim();
    const firstLine: string = trimmed.split('\n')[0].trim();
    // Mermaid 图表类型通常是第一行的关键字
    const typeKeywords: string[] = [
      'flowchart', 'graph', 'sequenceDiagram', 'classDiagram',
      'stateDiagram', 'erDiagram', 'journey', 'gantt', 'pie',
      'gitGraph', 'mindmap', 'timeline',
    ];
    for (const keyword of typeKeywords) {
      if (firstLine.startsWith(keyword)) {
        return keyword;
      }
    }
    return 'flowchart';
  }

  build() {
    Column() {
      // ---- 顶部标签 ----
      Text(`MERMAID \u00B7 ${this.getMermaidType()}`)
        .fontSize(12)
        .fontColor('#9CA3AF')
        .width('100%')
        .margin({ bottom: 8 })

      // ---- 主体区域 ----
      if (this.loadFailed) {
        // 降级显示
        Text(this.getFallbackText())
          .fontSize(14)
          .fontColor('#6B7280')
          .width('100%')
          .padding(16)
          .backgroundColor('#F8F9FA')
          .borderRadius(8)
      } else {
        Web({ src: 'resource://rawfile/mermaid-render.html', controller: this.controller })
          .width('100%')
          .height(300)
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
    .padding(24)
    .backgroundColor('#F8F9FA')
    .borderRadius(12)
    .border({
      width: 1,
      color: '#E4E7EC',
    })
    .margin({ bottom: 16 })
  }
}
