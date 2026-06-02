import { router } from '@kit.ArkUI';
import { BreakpointUtils } from '../common/BreakpointUtils';

@Entry
@Component
struct Index {
  aboutToAppear() {
    BreakpointUtils.registerBreakpointCallback(this.getUIContext().getHostContext() as Context)
  }

  build() {
    Column() {
      Text('网格对战')
        .fontSize(BreakpointUtils.getTitleFontSize())
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ bottom: 20 })

      Text('玩家 vs AI')
        .fontSize(BreakpointUtils.getSubTitleFontSize())
        .fontColor('#AAAAAA')
        .margin({ bottom: 50 })

      Button('开始游戏')
        .width(BreakpointUtils.getButtonWidth())
        .height(BreakpointUtils.getButtonHeight())
        .fontSize(BreakpointUtils.getButtonFontSize())
        .fontWeight(FontWeight.Bold)
        .backgroundColor('#FF6600')
        .fontColor('#FFFFFF')
        .borderRadius(12)
        .onClick(() => {
          router.pushUrl({ url: 'pages/SelectPage' })
        })

      Blank().height(20)

      Button('局域网联机')
        .width(BreakpointUtils.getButtonWidth())
        .height(BreakpointUtils.getButtonHeight())
        .fontSize(BreakpointUtils.getButtonFontSize() - 2)
        .fontWeight(FontWeight.Bold)
        .backgroundColor('#0066CC')
        .fontColor('#FFFFFF')
        .borderRadius(12)
        .onClick(() => {
          router.pushUrl({ url: 'pages/OnlineLobbyPage' })
        })
    }
    .padding({ bottom: 40 })
    .width('100%')
    .height('100%')
    .backgroundColor('#1A1A2E')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
