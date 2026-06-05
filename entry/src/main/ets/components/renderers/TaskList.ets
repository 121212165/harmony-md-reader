/**
 * TaskList.ets
 *
 * 任务列表渲染组件。
 * 每项显示为 checkbox + 文本，已勾选时 checkbox 为品牌色填充并显示白色勾号。
 */

/** 任务条目数据结构 */
export interface TaskItemData {
  /** 是否已勾选 */
  checked: boolean;
  /** 任务文本 */
  text: string;
}

@Component
export struct TaskList {
  /** 任务条目列表 */
  items: TaskItemData[] = [];

  /** 渲染单个 checkbox */
  @Builder
  checkboxBuilder(checked: boolean) {
    Stack() {
      if (checked) {
        Text('\u2713')
          .fontSize(10)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
      }
    }
    .width(16)
    .height(16)
    .borderRadius(4)
    .backgroundColor(checked ? '#2563EB' : '#FFFFFF')
    .border({
      width: checked ? 0 : 1,
      color: '#E4E7EC',
    })
    .justifyContent(FlexAlign.Center)
    .alignContent(Alignment.Center)
  }

  build() {
    Column() {
      ForEach(this.items, (item: TaskItemData, idx: number) => {
        Row() {
          this.checkboxBuilder(item.checked)

          Text(item.text)
            .fontSize(14)
            .fontColor('#1A1A1A')
            .margin({ left: 8 })
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 4 })
      }, (item: TaskItemData, idx: number) => `task-${idx}`)
    }
    .width('100%')
    .margin({ bottom: 16 })
  }
}
