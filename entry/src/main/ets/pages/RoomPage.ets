import { router } from '@kit.ArkUI';
import { NetManager, ConnState, MsgType, NetMessage } from '../network/NetManager';

// 房间参数
interface RoomParams {
  isHost: string
  roomCode: string
}

@Entry
@Component
struct RoomPage {
  @State mode: string = '' // 'create' 或 'join'
  @State roomCode: string = ''
  @State inputRoomCode: string = ''
  @State inputHostIp: string = ''
  @State statusText: string = ''
  @State isConnecting: boolean = false
  @State connState: ConnState = ConnState.DISCONNECTED
  @State localIp: string = ''
  @State errorMsg: string = ''

  private netManager: NetManager = NetManager.getInstance()

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>
    if (params) {
      this.mode = params['mode'] as string || 'create'
    }

    // 获取本机IP
    this.netManager.getLocalIp().then((ip: string) => {
      this.localIp = ip
    })

    // 设置回调
    this.netManager.onStateChange((state: ConnState) => {
      this.connState = state
      this.updateStatusText()

      // 连接成功后跳转到角色选择页
      if (state === ConnState.HOST_CONNECTED || state === ConnState.CONNECTED) {
        this.netManager.startHeartbeat()
        setTimeout(() => {
          let roomParams: RoomParams = {
            isHost: this.netManager.isHost ? 'true' : 'false',
            roomCode: this.netManager.roomCode
          }
          router.pushUrl({
            url: 'pages/OnlineSelectPage',
            params: roomParams
          })
        }, 500)
      }
    })

    this.netManager.onError((err: string) => {
      this.errorMsg = err
      this.isConnecting = false
    })

    this.netManager.onMessage((msg: NetMessage) => {
      // 房间页面只处理房间相关消息
      if (msg.type === MsgType.ROOM_REJECT) {
        this.errorMsg = '加入被拒绝：房间已满'
        this.isConnecting = false
        this.netManager.disconnect()
      }
    })

    // 自动创建房间
    if (this.mode === 'create') {
      this.createRoom()
    }
  }

  aboutToDisappear() {
    // 注意：不在这里断开连接，因为跳转后仍需要连接
  }

  private updateStatusText() {
    switch (this.connState) {
      case ConnState.DISCONNECTED:
        this.statusText = '未连接'
        break
      case ConnState.CONNECTING:
        this.statusText = '正在连接...'
        break
      case ConnState.CONNECTED:
        this.statusText = '已连接'
        break
      case ConnState.HOST_WAITING:
        this.statusText = '等待对方加入...'
        break
      case ConnState.HOST_CONNECTED:
        this.statusText = '对方已加入！'
        break
    }
  }

  private async createRoom() {
    this.isConnecting = true
    this.errorMsg = ''
    try {
      let code = await this.netManager.createRoom()
      this.roomCode = code
      this.isConnecting = false
    } catch (e) {
      this.errorMsg = `创建房间失败: ${e}`
      this.isConnecting = false
    }
  }

  private async joinRoom() {
    if (this.inputRoomCode.length !== 4) {
      this.errorMsg = '请输入4位房间号'
      return
    }
    if (this.inputHostIp.length === 0) {
      this.errorMsg = '请输入房主IP地址'
      return
    }

    this.isConnecting = true
    this.errorMsg = ''
    try {
      await this.netManager.joinRoom(this.inputRoomCode, this.inputHostIp)
      this.isConnecting = false
    } catch (e) {
      this.errorMsg = `加入房间失败: ${e}`
      this.isConnecting = false
    }
  }

  build() {
    Column() {
      Text('局域网联机')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ top: 40, bottom: 20 })

      if (this.mode === 'create') {
        // ===== 创建房间模式 =====
        Text('创建房间')
          .fontSize(22)
          .fontColor('#00CCFF')
          .margin({ bottom: 20 })

        if (this.roomCode) {
          Text('房间号')
            .fontSize(16)
            .fontColor('#AAAAAA')
            .margin({ bottom: 8 })

          Text(this.roomCode)
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFCC00')
            .margin({ bottom: 16 })

          Text('本机IP: ' + this.localIp)
            .fontSize(14)
            .fontColor('#AAAAAA')
            .margin({ bottom: 8 })

          Text('请将房间号和IP告诉对方')
            .fontSize(14)
            .fontColor('#888888')
            .margin({ bottom: 20 })
        }

        Text(this.statusText)
          .fontSize(18)
          .fontColor(this.connState === ConnState.HOST_CONNECTED ? '#00CC00' : '#FFCC00')
          .margin({ bottom: 20 })

        // 等待动画
        if (this.connState === ConnState.HOST_WAITING) {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#FFCC00')
            .margin({ bottom: 20 })
        }
      } else {
        // ===== 加入房间模式 =====
        Text('加入房间')
          .fontSize(22)
          .fontColor('#FF8800')
          .margin({ bottom: 20 })

        Text('房间号')
          .fontSize(16)
          .fontColor('#AAAAAA')
          .margin({ bottom: 8 })

        TextInput({ placeholder: '请输入4位房间号' })
          .width(200)
          .height(50)
          .fontSize(24)
          .fontColor('#FFFFFF')
          .backgroundColor('#333333')
          .textAlign(TextAlign.Center)
          .type(InputType.Number)
          .maxLength(4)
          .onChange((value: string) => {
            this.inputRoomCode = value
          })
          .margin({ bottom: 16 })

        Text('房主IP地址')
          .fontSize(16)
          .fontColor('#AAAAAA')
          .margin({ bottom: 8 })

        TextInput({ placeholder: '如 192.168.1.100' })
          .width(240)
          .height(50)
          .fontSize(18)
          .fontColor('#FFFFFF')
          .backgroundColor('#333333')
          .textAlign(TextAlign.Center)
          .onChange((value: string) => {
            this.inputHostIp = value
          })
          .margin({ bottom: 20 })

        Button('加入')
          .width(160)
          .height(50)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#FF6600')
          .fontColor('#FFFFFF')
          .borderRadius(10)
          .enabled(!this.isConnecting)
          .onClick(() => {
            this.joinRoom()
          })
          .margin({ bottom: 16 })

        if (this.isConnecting) {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#FFCC00')
            .margin({ bottom: 16 })
        }

        Text(this.statusText)
          .fontSize(18)
          .fontColor(this.connState === ConnState.CONNECTED ? '#00CC00' : '#FFCC00')
          .margin({ bottom: 16 })
      }

      // 错误信息
      if (this.errorMsg) {
        Text(this.errorMsg)
          .fontSize(14)
          .fontColor('#FF4444')
          .margin({ bottom: 16 })
      }

      // 返回按钮
      Button('返回')
        .width(120)
        .height(44)
        .fontSize(18)
        .backgroundColor('#555555')
        .fontColor('#FFFFFF')
        .borderRadius(8)
        .margin({ top: 20 })
        .onClick(() => {
          this.netManager.disconnect()
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
