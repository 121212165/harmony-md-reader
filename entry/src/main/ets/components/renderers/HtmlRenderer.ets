/**
 * HtmlRenderer.ets
 *
 * HTML 渲染组件。
 * 由于 HTML 解析器已将 HTML 文档转换为统一的 AST 节点树（与 Markdown 共享 ASTNode 结构），
 * 本组件直接委托 MarkdownRenderer 完成渲染。
 *
 * 对于 HTML 特有的 HTML_RAW 节点类型（无法映射到语义节点的原始 HTML 片段），
 * 在本组件中单独处理：以等宽字体灰色背景展示原始 HTML 代码。
 */

import { ASTNode, ASTNodeType } from '../../parser/ASTNode';
import { MarkdownRenderer } from './MarkdownRenderer';

@Component
export struct HtmlRenderer {
  /** AST 节点树（由 HtmlParser 生成） */
  nodes: ASTNode[] = [];
  /** 搜索关键词，用于文本高亮 */
  searchKeyword: string = '';

  /** 提取 HTML_RAW 节点，用于单独展示 */
  private getHtmlRawNodes(): ASTNode[] {
    return this.nodes.filter((n: ASTNode) => n.type === ASTNodeType.HTML_RAW);
  }

  /** 过滤掉 HTML_RAW 节点后的语义节点列表 */
  private getSemanticNodes(): ASTNode[] {
    return this.nodes.filter((n: ASTNode) => n.type !== ASTNodeType.HTML_RAW);
  }

  build() {
    Column() {
      // ---- 语义节点：委托 MarkdownRenderer 渲染 ----
      if (this.getSemanticNodes().length > 0) {
        MarkdownRenderer({
          nodes: this.getSemanticNodes(),
          searchKeyword: this.searchKeyword,
        })
        .width('100%')
        .layoutWeight(1)
      }

      // ---- HTML_RAW 节点：以源码形式展示 ----
      if (this.getHtmlRawNodes().length > 0) {
        Column() {
          Text('原始 HTML')
            .fontSize(12)
            .fontColor('#9CA3AF')
            .margin({ bottom: 8 })

          ForEach(
            this.getHtmlRawNodes(),
            (rawNode: ASTNode, idx: number) => {
              Text(rawNode.content || '')
                .fontSize(12)
                .fontColor('#ABB2BF')
                .fontFamily('monospace')
                .width('100%')
                .padding(16)
                .backgroundColor('#F8F9FA')
                .borderRadius(8)
                .border({
                  width: 1,
                  color: '#E4E7EC',
                })
            },
            (rawNode: ASTNode, idx: number) => `html-raw-${idx}`,
          )
        }
        .width('100%')
        .padding(16)
      }
    }
    .width('100%')
    .height('100%')
  }
}
