import { router } from '@kit.ArkUI';

// 大厅跳转参数
interface LobbyParams {
  mode: string
}

@Entry
@Component
struct OnlineLobbyPage {
  build() {
    Column() {
      Text('局域网联机')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ top: 60, bottom: 20 })

      Text('请确保两台手机在同一局域网内')
        .fontSize(14)
        .fontColor('#AAAAAA')
        .margin({ bottom: 40 })

      Button('创建房间')
        .width(180)
        .height(60)
        .fontSize(24)
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
        .width(180)
        .height(60)
        .fontSize(24)
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

      // 说明
      Column() {
        Text('游戏说明')
          .fontSize(16)
          .fontColor('#FFCC00')
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 8 })

        Text('1. 一方点击「创建房间」，获取房间号和IP')
          .fontSize(13)
          .fontColor('#AAAAAA')
          .margin({ bottom: 4 })

        Text('2. 另一方点击「加入房间」，输入房间号和IP')
          .fontSize(13)
          .fontColor('#AAAAAA')
          .margin({ bottom: 4 })

        Text('3. 双方各自选择角色后进入对战')
          .fontSize(13)
          .fontColor('#AAAAAA')
          .margin({ bottom: 4 })

        Text('4. 房主控制左侧角色，加入者控制右侧角色')
          .fontSize(13)
          .fontColor('#AAAAAA')
          .margin({ bottom: 4 })

        Text('5. 双方屏幕操作实时同步，界面完全一致')
          .fontSize(13)
          .fontColor('#AAAAAA')
      }
      .margin({ top: 20 })

      // 返回按钮
      Button('返回')
        .width(120)
        .height(44)
        .fontSize(18)
        .backgroundColor('#555555')
        .fontColor('#FFFFFF')
        .borderRadius(8)
        .margin({ top: 30 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/Index' })
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1A1A2E')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }
}
