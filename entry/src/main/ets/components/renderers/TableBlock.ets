/**
 * TableBlock.ets
 *
 * 表格渲染组件。
 * 使用 Column + Row + Text 组合实现表格布局（ArkUI 无原生 table 组件）。
 * 表头行灰色背景，数据行白色背景，所有单元格等宽分布。
 */

@Component
export struct TableBlock {
  /** 表头：每个元素是一列的文本片段数组 */
  headers: string[][] = [];
  /** 数据行：第一维是行，第二维是列，第三维是单元格内的文本片段 */
  rows: string[][][] = [];

  /** 将文本片段数组合并为单个字符串 */
  private joinFragments(fragments: string[]): string {
    if (!fragments || fragments.length === 0) {
      return '';
    }
    return fragments.join('');
  }

  build() {
    Column() {
      // ---- 表头行 ----
      if (this.headers.length > 0) {
        Row() {
          ForEach(this.headers, (headerFragments: string[], colIdx: number) => {
            Text(this.joinFragments(headerFragments))
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#6B7280')
              .padding({
                top: 8,
                bottom: 8,
                left: 16,
                right: 16,
              })
              .backgroundColor('#F8F9FA')
              .border({
                width: 1,
                color: '#E4E7EC',
              })
              .layoutWeight(1)
              .textAlign(TextAlign.Start)
          }, (headerFragments: string[], colIdx: number) => `header-${colIdx}`)
        }
        .width('100%')
      }

      // ---- 数据行 ----
      ForEach(this.rows, (row: string[][], rowIdx: number) => {
        Row() {
          ForEach(row, (cellFragments: string[], colIdx: number) => {
            Text(this.joinFragments(cellFragments))
              .fontSize(14)
              .fontColor('#1A1A1A')
              .padding({
                top: 8,
                bottom: 8,
                left: 16,
                right: 16,
              })
              .border({
                width: 1,
                color: '#E4E7EC',
              })
              .layoutWeight(1)
              .textAlign(TextAlign.Start)
          }, (cellFragments: string[], colIdx: number) => `cell-${rowIdx}-${colIdx}`)
        }
        .width('100%')
      }, (row: string[][], rowIdx: number) => `row-${rowIdx}`)
    }
    .width('100%')
    .margin({ bottom: 16 })
  }
}
