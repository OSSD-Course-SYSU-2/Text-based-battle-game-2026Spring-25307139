import { router } from '@kit.ArkUI';
import { BreakpointUtils } from '../common/BreakpointUtils';

interface LobbyParams {
  mode: string
}

@Entry
@Component
struct OnlineLobbyPage {
  aboutToAppear() {
    BreakpointUtils.registerBreakpointCallback(this.getUIContext().getHostContext() as Context)
  }

  build() {
    Column() {
      Text('局域网联机')
        .fontSize(BreakpointUtils.getTitleFontSize() - 8)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ top: 60, bottom: 20 })

      Text('请确保两台设备在同一局域网内')
        .fontSize(BreakpointUtils.getSubTitleFontSize() - 6)
        .fontColor('#AAAAAA')
        .margin({ bottom: 40 })

      Button('创建房间')
        .width(BreakpointUtils.getButtonWidth() + 20)
        .height(BreakpointUtils.getButtonHeight())
        .fontSize(BreakpointUtils.getButtonFontSize())
        .fontWeight(FontWeight.Bold)
        .backgroundColor('#0066CC')
        .fontColor('#FFFFFF')
        .borderRadius(12)
        .margin({ bottom: 20 })
        .onClick(() => {
          let params: LobbyParams = { mode: 'create' }
          router.pushUrl({
            url: 'pages/RoomPage',
            params: params
          })
        })

      Button('加入房间')
        .width(BreakpointUtils.getButtonWidth() + 20)
        .height(BreakpointUtils.getButtonHeight())
        .fontSize(BreakpointUtils.getButtonFontSize())
        .fontWeight(FontWeight.Bold)
        .backgroundColor('#336699')
        .fontColor('#FFFFFF')
        .borderRadius(12)
        .margin({ bottom: 40 })
        .onClick(() => {
          let params: LobbyParams = { mode: 'join' }
          router.pushUrl({
            url: 'pages/RoomPage',
            params: params
          })
        })

      Column() {
        Text('游戏说明')
          .fontSize(BreakpointUtils.getSubTitleFontSize() - 4)
          .fontColor('#FFCC00')
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 8 })

        Text('1. 一方点击「创建房间」，获取房间号和IP')
          .fontSize(BreakpointUtils.getSubTitleFontSize() - 7)
          .fontColor('#AAAAAA')
          .margin({ bottom: 4 })

        Text('2. 另一方点击「加入房间」，输入房间号和IP')
          .fontSize(BreakpointUtils.getSubTitleFontSize() - 7)
          .fontColor('#AAAAAA')
          .margin({ bottom: 4 })

        Text('3. 双方各自选择角色后进入对战')
          .fontSize(BreakpointUtils.getSubTitleFontSize() - 7)
          .fontColor('#AAAAAA')
          .margin({ bottom: 4 })

        Text('4. 房主控制左侧角色，加入者控制右侧角色')
          .fontSize(BreakpointUtils.getSubTitleFontSize() - 7)
          .fontColor('#AAAAAA')
          .margin({ bottom: 4 })

        Text('5. 双方屏幕操作实时同步，界面完全一致')
          .fontSize(BreakpointUtils.getSubTitleFontSize() - 7)
          .fontColor('#AAAAAA')
      }
      .margin({ top: 20 })

      Button('返回')
        .width(BreakpointUtils.getButtonWidth() - 40)
        .height(BreakpointUtils.getButtonHeight() - 16)
        .fontSize(BreakpointUtils.getSubTitleFontSize() - 2)
        .backgroundColor('#555555')
        .fontColor('#FFFFFF')
        .borderRadius(8)
        .margin({ top: 30 })
        .onClick(() => {
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
