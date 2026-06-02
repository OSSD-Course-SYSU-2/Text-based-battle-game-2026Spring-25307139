import { router } from '@kit.ArkUI';
import { NetManager, MsgType, ConnState, NetMessage } from '../network/NetManager';
import { BreakpointUtils } from '../common/BreakpointUtils';

interface CharSelectData {
  char: string
}

interface BattleParams {
  player1Char: string
  player2Char: string
  myPlayerIndex: string
  isHost: string
}

@Entry
@Component
struct OnlineSelectPage {
  @State isHost: boolean = true
  @State myPlayerIndex: number = 1
  @State selectedIndex: number = 0
  @State myChar: string = ''
  @State opponentChar: string = ''
  @State myConfirmed: boolean = false
  @State opponentConfirmed: boolean = false
  @State statusText: string = '选择你的角色'
  @State errorMsg: string = ''

  private chars: string[] = ['剑', '盾', '弓', '法', '枪', '骑']
  private rowIndices: number[] = [0, 1]
  private colIndices: number[] = [0, 1, 2]
  private netManager: NetManager = NetManager.getInstance()
  private lastClickTime: number = 0
  private lastClickIndex: number = -1

  aboutToAppear() {
    BreakpointUtils.registerBreakpointCallback(this.getUIContext().getHostContext() as Context)

    const params = router.getParams() as Record<string, string>
    if (params) {
      this.isHost = (params['isHost'] as string) === 'true'
    }

    this.myPlayerIndex = this.isHost ? 1 : 2

    this.netManager.onMessage((msg: NetMessage) => {
      this.handleMessage(msg)
    })

    this.netManager.onStateChange((state: ConnState) => {
      if (state === ConnState.DISCONNECTED) {
        this.errorMsg = '连接已断开'
      }
    })

    this.netManager.onError((err: string) => {
      this.errorMsg = err
    })
  }

  private handleMessage(msg: NetMessage): void {
    let type = msg.type
    let data = msg.data as Record<string, Object>

    if (type === MsgType.CHAR_SELECT) {
      let charVal = data['char'] as string
      this.opponentChar = charVal
      this.statusText = `对方选择了: ${this.opponentChar}`
    } else if (type === MsgType.CHAR_CONFIRM) {
      this.opponentConfirmed = true
      let charVal = data['char'] as string
      this.opponentChar = charVal
      this.checkBothReady()
    } else if (type === MsgType.CHAR_START) {
      this.enterBattle()
    } else if (type === MsgType.DISCONNECT) {
      this.errorMsg = '对方已断开连接'
    }
  }

  private selectChar(): void {
    if (this.myConfirmed) return
    this.myChar = this.chars[this.selectedIndex]

    let sendData: CharSelectData = { char: this.myChar }
    this.netManager.sendMessage(MsgType.CHAR_SELECT, sendData)
  }

  private confirmChar(): void {
    if (this.myConfirmed) return
    if (this.myChar.length === 0) {
      this.myChar = this.chars[this.selectedIndex]
    }
    this.myConfirmed = true

    let sendData: CharSelectData = { char: this.myChar }
    this.netManager.sendMessage(MsgType.CHAR_CONFIRM, sendData)

    this.statusText = '已确认，等待对方...'
    this.checkBothReady()
  }

  private checkBothReady(): void {
    if (this.myConfirmed && this.opponentConfirmed) {
      if (this.isHost) {
        let emptyData: Record<string, Object> = {}
        this.netManager.sendMessage(MsgType.CHAR_START, emptyData)
        setTimeout(() => {
          this.enterBattle()
        }, 300)
      }
    }
  }

  private enterBattle(): void {
    let p1Char = this.myPlayerIndex === 1 ? this.myChar : this.opponentChar
    let p2Char = this.myPlayerIndex === 2 ? this.myChar : this.opponentChar

    if (p1Char.length === 0) p1Char = '剑'
    if (p2Char.length === 0) p2Char = '盾'

    let battleParams: BattleParams = {
      player1Char: p1Char,
      player2Char: p2Char,
      myPlayerIndex: this.myPlayerIndex.toString(),
      isHost: this.isHost ? 'true' : 'false'
    }

    router.replaceUrl({
      url: 'pages/OnlineBattlePage',
      params: battleParams
    })
  }

  build() {
    Column() {
      Text('联机对战 - 选择角色')
        .fontSize(BreakpointUtils.getSubTitleFontSize() + 4)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ top: 30, bottom: 8 })

      Text(this.myPlayerIndex === 1 ? '你是玩家1（左侧）' : '你是玩家2（右侧）')
        .fontSize(BreakpointUtils.getSubTitleFontSize() - 4)
        .fontColor(this.myPlayerIndex === 1 ? '#00CCFF' : '#FF8800')
        .margin({ bottom: 20 })

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
              .enabled(!this.myConfirmed)
              .onClick(() => {
                if (!this.myConfirmed) {
                  let index = row * 3 + col
                  if (BreakpointUtils.isWideScreen()) {
                    let now = Date.now()
                    if (this.lastClickIndex === index && now - this.lastClickTime < 300) {
                      this.confirmChar()
                      this.lastClickTime = 0
                      this.lastClickIndex = -1
                    } else {
                      this.selectedIndex = index
                      this.selectChar()
                      this.lastClickTime = now
                      this.lastClickIndex = index
                    }
                  } else {
                    this.selectedIndex = index
                    this.selectChar()
                  }
                }
              })
            }, (col: number) => col.toString())
          }
          .margin({ bottom: 4 })
        }, (row: number) => row.toString())
      }
      .margin({ top: 10, bottom: 20 })

      if (!BreakpointUtils.isWideScreen()) {
        Column() {
          Row() {
            Button('▲')
              .width(BreakpointUtils.getControlBtnSize())
              .height(BreakpointUtils.getControlBtnSize())
              .fontSize(BreakpointUtils.getControlBtnFontSize())
              .backgroundColor('#555555')
              .fontColor('#FFFFFF')
              .enabled(!this.myConfirmed)
              .onClick(() => {
                if (!this.myConfirmed && this.selectedIndex >= 3) {
                  this.selectedIndex -= 3
                  this.selectChar()
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
              .enabled(!this.myConfirmed)
              .onClick(() => {
                if (!this.myConfirmed && this.selectedIndex % 3 !== 0) {
                  this.selectedIndex -= 1
                  this.selectChar()
                }
              })

            Blank().width(20)

            Button('确认')
              .width(BreakpointUtils.getButtonWidth() - 60)
              .height(BreakpointUtils.getControlBtnSize())
              .fontSize(BreakpointUtils.getControlBtnFontSize())
              .fontWeight(FontWeight.Bold)
              .backgroundColor(this.myConfirmed ? '#336633' : '#FF6600')
              .fontColor('#FFFFFF')
              .enabled(!this.myConfirmed)
              .onClick(() => {
                this.confirmChar()
              })

            Blank().width(20)

            Button('▶')
              .width(BreakpointUtils.getControlBtnSize())
              .height(BreakpointUtils.getControlBtnSize())
              .fontSize(BreakpointUtils.getControlBtnFontSize())
              .backgroundColor('#555555')
              .fontColor('#FFFFFF')
              .enabled(!this.myConfirmed)
              .onClick(() => {
                if (!this.myConfirmed && this.selectedIndex % 3 !== 2) {
                  this.selectedIndex += 1
                  this.selectChar()
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
              .enabled(!this.myConfirmed)
              .onClick(() => {
                if (!this.myConfirmed && this.selectedIndex < 3) {
                  this.selectedIndex += 3
                  this.selectChar()
                }
              })
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
        }
        .margin({ top: 10 })
      }

      Text('你的角色: ' + (this.myChar.length > 0 ? this.myChar : '未选择'))
        .fontSize(BreakpointUtils.getSubTitleFontSize() - 2)
        .fontColor('#00CCFF')
        .margin({ top: 16 })

      if (this.opponentChar.length > 0) {
        Text('对方角色: ' + this.opponentChar)
          .fontSize(BreakpointUtils.getSubTitleFontSize() - 2)
          .fontColor('#FF8800')
          .margin({ top: 8 })
      }

      Text(this.statusText)
        .fontSize(BreakpointUtils.getSubTitleFontSize() - 4)
        .fontColor('#FFCC00')
        .margin({ top: 16 })

      if (this.errorMsg.length > 0) {
        Text(this.errorMsg)
          .fontSize(BreakpointUtils.getSubTitleFontSize() - 6)
          .fontColor('#FF4444')
          .margin({ top: 8 })
      }

      Button('返回')
        .width(BreakpointUtils.getButtonWidth() - 40)
        .height(BreakpointUtils.getButtonHeight() - 16)
        .fontSize(BreakpointUtils.getSubTitleFontSize() - 2)
        .backgroundColor('#555555')
        .fontColor('#FFFFFF')
        .borderRadius(8)
        .margin({ top: 20 })
        .onClick(() => {
          this.netManager.disconnect()
          router.pushUrl({ url: 'pages/Index' })
        })
    }
    .padding({ bottom: 40 })
    .width('100%')
    .height('100%')
    .backgroundColor('#1A1A2E')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }
}
