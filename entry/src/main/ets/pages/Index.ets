import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  build() {
    Column() {
      Text('网格对战')
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ bottom: 20 })

      Text('玩家 vs AI')
        .fontSize(20)
        .fontColor('#AAAAAA')
        .margin({ bottom: 50 })

      Button('开始游戏')
        .width(160)
        .height(60)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .backgroundColor('#FF6600')
        .fontColor('#FFFFFF')
        .borderRadius(12)
        .onClick(() => {
          router.pushUrl({ url: 'pages/SelectPage' })
        })

      Blank().height(20)

      Button('局域网联机')
        .width(160)
        .height(60)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .backgroundColor('#0066CC')
        .fontColor('#FFFFFF')
        .borderRadius(12)
        .onClick(() => {
          router.pushUrl({ url: 'pages/OnlineLobbyPage' })
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1A1A2E')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
