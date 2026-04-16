import { router } from '@kit.ArkUI';

@Entry
@Component
struct SelectPage {
  @State selectedIndex: number = 0
  @State confirmed: boolean = false
  @State player1Char: string = ''
  @State player2Char: string = ''

  private chars: string[] = ['剑', '盾', '弓', '法', '枪', '骑']
  private rowIndices: number[] = [0, 1]
  private colIndices: number[] = [0, 1, 2]

  build() {
    Column() {
      Text('选择你的角色')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ top: 60, bottom: 30 })

      // 3x2网格面板
      Column() {
        ForEach(this.rowIndices, (row: number) => {
          Row() {
            ForEach(this.colIndices, (col: number) => {
              Column() {
                Text(this.chars[row * 3 + col])
                  .fontSize(32)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.selectedIndex === (row * 3 + col) ? '#000000' : '#FFFFFF')
              }
              .width(80)
              .height(80)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .backgroundColor(this.selectedIndex === (row * 3 + col) ? '#FFFFFF' : '#333333')
              .border({ width: 2, color: '#666666' })
              .margin(4)
              .onClick(() => {
                this.selectedIndex = row * 3 + col
              })
            }, (col: number) => col.toString())
          }
          .margin({ bottom: 4 })
        }, (row: number) => row.toString())
      }
      .margin({ top: 20, bottom: 40 })

      // 方向按钮 + 确认按钮
      Column() {
        Row() {
          Button('▲')
            .width(60)
            .height(60)
            .fontSize(24)
            .backgroundColor('#555555')
            .fontColor('#FFFFFF')
            .onClick(() => {
              if (this.selectedIndex >= 3) {
                this.selectedIndex -= 3
              }
            })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .margin({ bottom: 8 })

        Row() {
          Button('◀')
            .width(60)
            .height(60)
            .fontSize(24)
            .backgroundColor('#555555')
            .fontColor('#FFFFFF')
            .onClick(() => {
              if (this.selectedIndex % 3 !== 0) {
                this.selectedIndex -= 1
              }
            })

          Blank().width(20)

          Button('确认')
            .width(100)
            .height(60)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#FF6600')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.confirmSelection()
            })

          Blank().width(20)

          Button('▶')
            .width(60)
            .height(60)
            .fontSize(24)
            .backgroundColor('#555555')
            .fontColor('#FFFFFF')
            .onClick(() => {
              if (this.selectedIndex % 3 !== 2) {
                this.selectedIndex += 1
              }
            })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .margin({ bottom: 8 })

        Row() {
          Button('▼')
            .width(60)
            .height(60)
            .fontSize(24)
            .backgroundColor('#555555')
            .fontColor('#FFFFFF')
            .onClick(() => {
              if (this.selectedIndex < 3) {
                this.selectedIndex += 3
              }
            })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }
      .margin({ top: 20 })

      Text('当前选中: ' + this.chars[this.selectedIndex])
        .fontSize(20)
        .fontColor('#FFCC00')
        .margin({ top: 30 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1A1A2E')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }

  private confirmSelection() {
    if (this.confirmed) {
      return
    }
    this.confirmed = true
    this.player1Char = this.chars[this.selectedIndex]

    let availableIndices: number[] = []
    for (let i = 0; i < this.chars.length; i++) {
      if (i !== this.selectedIndex) {
        availableIndices.push(i)
      }
    }
    let aiIndex = availableIndices[Math.floor(Math.random() * availableIndices.length)]
    this.player2Char = this.chars[aiIndex]

    router.pushUrl({
      url: 'pages/BattlePage',
      params: {
        player1Char: this.player1Char,
        player2Char: this.player2Char
      }
    })
  }
}
