import { router } from '@kit.ArkUI';
import { BreakpointUtils } from '../common/BreakpointUtils';

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
  private lastClickTime: number = 0
  private lastClickIndex: number = -1

  aboutToAppear() {
    BreakpointUtils.registerBreakpointCallback(this.getUIContext().getHostContext() as Context)
  }

  build() {
    Column() {
      Text('选择你的角色')
        .fontSize(BreakpointUtils.getTitleFontSize() - 8)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ top: 60, bottom: 30 })

      Column() {
        ForEach(this.rowIndices, (row: number) => {
          Row() {
            ForEach(this.colIndices, (col: number) => {
              Column() {
                Text(this.chars[row * 3 + col])
                  .fontSize(BreakpointUtils.getCharFontSize())
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.selectedIndex === (row * 3 + col) ? '#000000' : '#FFFFFF')
              }
              .width(BreakpointUtils.getCharCellSize())
              .height(BreakpointUtils.getCharCellSize())
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .backgroundColor(this.selectedIndex === (row * 3 + col) ? '#FFFFFF' : '#333333')
              .border({ width: 2, color: '#666666' })
              .margin(4)
              .onClick(() => {
                let index = row * 3 + col
                if (BreakpointUtils.isWideScreen()) {
                  let now = Date.now()
                  if (this.lastClickIndex === index && now - this.lastClickTime < 300) {
                    this.confirmSelection()
                    this.lastClickTime = 0
                    this.lastClickIndex = -1
                  } else {
                    this.selectedIndex = index
                    this.lastClickTime = now
                    this.lastClickIndex = index
                  }
                } else {
                  this.selectedIndex = index
                }
              })
            }, (col: number) => col.toString())
          }
          .margin({ bottom: 4 })
        }, (row: number) => row.toString())
      }
      .margin({ top: 20, bottom: 40 })

      if (!BreakpointUtils.isWideScreen()) {
        Column() {
          Row() {
            Button('▲')
              .width(BreakpointUtils.getControlBtnSize())
              .height(BreakpointUtils.getControlBtnSize())
              .fontSize(BreakpointUtils.getControlBtnFontSize())
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
              .width(BreakpointUtils.getControlBtnSize())
              .height(BreakpointUtils.getControlBtnSize())
              .fontSize(BreakpointUtils.getControlBtnFontSize())
              .backgroundColor('#555555')
              .fontColor('#FFFFFF')
              .onClick(() => {
                if (this.selectedIndex % 3 !== 0) {
                  this.selectedIndex -= 1
                }
              })

            Blank().width(20)

            Button('确认')
              .width(BreakpointUtils.getButtonWidth() - 60)
              .height(BreakpointUtils.getControlBtnSize())
              .fontSize(BreakpointUtils.getControlBtnFontSize())
              .fontWeight(FontWeight.Bold)
              .backgroundColor('#FF6600')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.confirmSelection()
              })

            Blank().width(20)

            Button('▶')
              .width(BreakpointUtils.getControlBtnSize())
              .height(BreakpointUtils.getControlBtnSize())
              .fontSize(BreakpointUtils.getControlBtnFontSize())
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
              .width(BreakpointUtils.getControlBtnSize())
              .height(BreakpointUtils.getControlBtnSize())
              .fontSize(BreakpointUtils.getControlBtnFontSize())
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
      }

      Text('当前选中: ' + this.chars[this.selectedIndex])
        .fontSize(BreakpointUtils.getSubTitleFontSize())
        .fontColor('#FFCC00')
        .margin({ top: 30 })
    }
    .padding({ bottom: 40 })
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
