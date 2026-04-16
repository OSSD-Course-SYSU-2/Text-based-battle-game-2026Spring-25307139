import { socket } from '@kit.NetworkKit';
import { wifiManager } from '@kit.ConnectivityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';

const TAG = 'NetManager';
const DOMAIN = 0x0001;

// 网络消息类型
export enum MsgType {
  ROOM_JOIN = 'room_join',
  ROOM_READY = 'room_ready',
  ROOM_REJECT = 'room_reject',
  CHAR_SELECT = 'char_select',
  CHAR_CONFIRM = 'char_confirm',
  CHAR_START = 'char_start',
  GAME_MOVE = 'game_move',
  GAME_ATTACK = 'game_attack',
  GAME_SKILL = 'game_skill',
  GAME_STATE_SYNC = 'game_state_sync',
  GAME_OVER = 'game_over',
  HEARTBEAT = 'heartbeat',
  DISCONNECT = 'disconnect'
}

// 网络消息结构
export interface NetMessage {
  type: string
  data: Object
  seq: number
  timestamp: number
}

// 拒绝原因数据
interface RejectData {
  reason: string
}

// 房间加入数据
interface JoinData {
  roomCode: string
}

// 游戏状态快照（用于同步）
export interface GameStateSnapshot {
  p1X: number
  p1Y: number
  p2X: number
  p2Y: number
  p1Hp: number
  p2Hp: number
  p1Fill: number
  p2Fill: number
  p1CellColor: string
  p2CellColor: string
  p1Shield: number
  p2Shield: number
  p1Invisible: boolean
  p2Invisible: boolean
  bullets: BulletData[]
  gameOver: boolean
  winnerText: string
}

// 弹幕数据（可序列化）
export interface BulletData {
  id: number
  x: number
  y: number
  direction: number
  owner: number
  isSkill: boolean
  active: boolean
}

// 消息回调
export type MessageCallback = (msg: NetMessage) => void

// 连接状态
export enum ConnState {
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  CONNECTED = 'connected',
  HOST_WAITING = 'host_waiting',
  HOST_CONNECTED = 'host_connected'
}

// 单例网络管理器
export class NetManager {
  private static instance: NetManager | null = null

  private serverSocket: socket.TCPSocketServer | null = null
  private clientSocket: socket.TCPSocket | null = null
  private acceptedConn: socket.TCPSocketConnection | null = null

  private _connState: ConnState = ConnState.DISCONNECTED
  private _isHost: boolean = false
  private _roomCode: string = ''
  private _localIp: string = ''
  private _port: number = 0

  private msgCallback: MessageCallback | null = null
  private stateCallback: ((state: ConnState) => void) | null = null
  private errorCallback: ((err: string) => void) | null = null

  private seqCounter: number = 0
  private recvBuffer: string = ''
  private heartbeatTimer: number = -1
  private intentionalDisconnect: boolean = false

  private readonly BASE_PORT: number = 18000

  private textEncoder: util.TextEncoder = new util.TextEncoder()
  private textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8')

  private constructor() {}

  public static getInstance(): NetManager {
    if (!NetManager.instance) {
      NetManager.instance = new NetManager()
    }
    return NetManager.instance
  }

  get connState(): ConnState {
    return this._connState
  }

  get isHost(): boolean {
    return this._isHost
  }

  get roomCode(): string {
    return this._roomCode
  }

  get localIp(): string {
    return this._localIp
  }

  public onMessage(cb: MessageCallback): void {
    this.msgCallback = cb
  }

  public onStateChange(cb: (state: ConnState) => void): void {
    this.stateCallback = cb
  }

  public onError(cb: (err: string) => void): void {
    this.errorCallback = cb
  }

  // ========== 获取本机IP ==========

  public async getLocalIp(): Promise<string> {
    try {
      let linkedInfo = await wifiManager.getLinkedInfo()
      if (linkedInfo && linkedInfo.ipAddress !== 0) {
        let ip = this.intToIp(linkedInfo.ipAddress)
        this._localIp = ip
        hilog.info(DOMAIN, TAG, `Local IP from WiFi: ${ip}`)
        return ip
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `Failed to get WiFi info`)
    }

    this._localIp = '192.168.1.1'
    return this._localIp
  }

  private intToIp(ipInt: number): string {
    return `${(ipInt >>> 0) & 0xFF}.${(ipInt >>> 8) & 0xFF}.${(ipInt >>> 16) & 0xFF}.${(ipInt >>> 24) & 0xFF}`
  }

  // ========== 编码/解码工具 ==========

  private encodeString(str: string): ArrayBuffer {
    let encoded: Uint8Array = this.textEncoder.encodeInto(str)
    return encoded.buffer as ArrayBuffer
  }

  private decodeBuffer(data: ArrayBuffer): string {
    let uint8Arr = new Uint8Array(data)
    return this.textDecoder.decodeToString(uint8Arr)
  }

  // ========== 创建房间（房主） ==========

  public async createRoom(): Promise<string> {
    if (this._connState !== ConnState.DISCONNECTED) {
      throw new Error('当前已有连接，请先断开')
    }

    this._isHost = true
    this.intentionalDisconnect = false

    let roomNum = Math.floor(Math.random() * 9000) + 1000
    this._roomCode = roomNum.toString()
    this._port = this.BASE_PORT + roomNum

    try {
      await this.getLocalIp()

      this.serverSocket = socket.constructTCPSocketServerInstance()

      // 监听连接事件
      this.serverSocket.on('connect', (client: socket.TCPSocketConnection) => {
        hilog.info(DOMAIN, TAG, 'Client connected to server')

        if (this.acceptedConn !== null) {
          hilog.warn(DOMAIN, TAG, 'Already have a connection, rejecting new one')
          try {
            let rejectData: RejectData = { reason: '房间已满' }
            let rejectMsg: NetMessage = {
              type: MsgType.ROOM_REJECT,
              data: rejectData,
              seq: 0,
              timestamp: Date.now()
            }
            let jsonStr = JSON.stringify(rejectMsg)
            let buffer = this.encodeString(jsonStr + '\n')
            client.send({ data: buffer })
          } catch (e) {
            hilog.warn(DOMAIN, TAG, `Failed to send reject`)
          }
          client.close()
          return
        }

        this.acceptedConn = client
        this._connState = ConnState.HOST_CONNECTED
        this.notifyStateChange()

        // 监听数据 - TCPSocketConnection 使用 'message' 事件
        client.on('message', (msg: socket.SocketMessageInfo) => {
          this.onRecvData(msg.message)
        })

        client.on('close', () => {
          hilog.info(DOMAIN, TAG, 'Client connection closed')
          if (!this.intentionalDisconnect) {
            this.handleUnexpectedDisconnect()
          }
        })

        client.on('error', (err: Object) => {
          hilog.error(DOMAIN, TAG, `Client connection error`)
          this.notifyError(`连接错误`)
        })

        // 通知对方加入成功
        try {
          let joinData: JoinData = { roomCode: this._roomCode }
          let joinMsg: NetMessage = {
            type: MsgType.ROOM_JOIN,
            data: joinData,
            seq: 0,
            timestamp: Date.now()
          }
          let jsonStr = JSON.stringify(joinMsg)
          let buffer = this.encodeString(jsonStr + '\n')
          client.send({ data: buffer })
        } catch (e) {
          hilog.error(DOMAIN, TAG, `Failed to send join ack`)
        }
      })

      let bindAddr: socket.NetAddress = {
        address: '0.0.0.0',
        port: this._port,
        family: 1
      }
      await this.serverSocket.listen(bindAddr)

      this._connState = ConnState.HOST_WAITING
      this.notifyStateChange()

      hilog.info(DOMAIN, TAG, `Room created, code: ${this._roomCode}, port: ${this._port}`)
      return this._roomCode
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Failed to create room`)
      this._connState = ConnState.DISCONNECTED
      this.notifyStateChange()
      throw new Error(`创建房间失败`)
    }
  }

  // ========== 加入房间（客户端） ==========

  public async joinRoom(roomCode: string, hostIp: string): Promise<void> {
    if (this._connState !== ConnState.DISCONNECTED) {
      throw new Error('当前已有连接，请先断开')
    }

    this._isHost = false
    this._roomCode = roomCode
    this._port = this.BASE_PORT + parseInt(roomCode)
    this.intentionalDisconnect = false

    try {
      this.clientSocket = socket.constructTCPSocketInstance()

      this.clientSocket.on('message', (msg: socket.SocketMessageInfo) => {
        this.onRecvData(msg.message)
      })

      this.clientSocket.on('close', () => {
        hilog.info(DOMAIN, TAG, 'Client socket closed')
        if (!this.intentionalDisconnect) {
          this.handleUnexpectedDisconnect()
        }
      })

      this.clientSocket.on('error', (err: Object) => {
        hilog.error(DOMAIN, TAG, `Client socket error`)
        this.notifyError(`连接错误`)
      })

      let netAddr: socket.NetAddress = {
        address: hostIp,
        port: this._port,
        family: 1
      }
      let connectAddr: socket.TCPConnectOptions = {
        address: netAddr,
        timeout: 10000
      }

      this._connState = ConnState.CONNECTING
      this.notifyStateChange()

      await this.clientSocket.connect(connectAddr)

      this._connState = ConnState.CONNECTED
      this.notifyStateChange()

      hilog.info(DOMAIN, TAG, `Connected to room ${roomCode} at ${hostIp}:${this._port}`)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Failed to join room`)
      this._connState = ConnState.DISCONNECTED
      this.notifyStateChange()
      throw new Error(`加入房间失败`)
    }
  }

  // ========== 发送消息 ==========

  public sendMessage(type: string, data: Object): void {
    let msg: NetMessage = {
      type: type,
      data: data,
      seq: ++this.seqCounter,
      timestamp: Date.now()
    }

    let jsonStr = JSON.stringify(msg)
    let buffer = this.encodeString(jsonStr + '\n')

    try {
      if (this._isHost && this.acceptedConn) {
        this.acceptedConn.send({ data: buffer })
      } else if (!this._isHost && this.clientSocket) {
        this.clientSocket.send({ data: buffer })
      } else {
        hilog.warn(DOMAIN, TAG, 'No connection to send message')
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Send error`)
      this.notifyError(`发送失败`)
    }
  }

  // ========== 接收数据 ==========

  private onRecvData(data: ArrayBuffer): void {
    try {
      let text = this.decodeBuffer(data)
      this.recvBuffer += text

      let lines: string[] = this.recvBuffer.split('\n')
      this.recvBuffer = lines[lines.length - 1]

      for (let i = 0; i < lines.length - 1; i++) {
        let line: string = lines[i].trim()
        if (line.length === 0) continue

        try {
          let msg: NetMessage = JSON.parse(line) as NetMessage
          this.handleMessage(msg)
        } catch (parseErr) {
          hilog.warn(DOMAIN, TAG, `Failed to parse message`)
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Recv data error`)
    }
  }

  // ========== 处理消息 ==========

  private handleMessage(msg: NetMessage): void {
    hilog.info(DOMAIN, TAG, `Recv msg: type=${msg.type}, seq=${msg.seq}`)

    if (msg.type === MsgType.HEARTBEAT) {
      return
    }

    if (msg.type === MsgType.DISCONNECT) {
      this.intentionalDisconnect = true
      this._connState = ConnState.DISCONNECTED
      this.notifyStateChange()
      return
    }

    if (this.msgCallback) {
      this.msgCallback(msg)
    }
  }

  // ========== 心跳 ==========

  public startHeartbeat(): void {
    this.stopHeartbeat()
    this.heartbeatTimer = setInterval(() => {
      let emptyData: Record<string, Object> = {}
      this.sendMessage(MsgType.HEARTBEAT, emptyData)
    }, 5000) as number
  }

  public stopHeartbeat(): void {
    if (this.heartbeatTimer !== -1) {
      clearInterval(this.heartbeatTimer)
      this.heartbeatTimer = -1
    }
  }

  // ========== 断开连接 ==========

  public async disconnect(): Promise<void> {
    this.intentionalDisconnect = true
    this.stopHeartbeat()

    try {
      let emptyData2: Record<string, Object> = {}
      this.sendMessage(MsgType.DISCONNECT, emptyData2)
    } catch (e) {
      // 忽略
    }

    await this.sleep(100)

    try {
      if (this.acceptedConn) {
        this.acceptedConn.off('message')
        this.acceptedConn.off('close')
        this.acceptedConn.off('error')
        this.acceptedConn.close()
        this.acceptedConn = null
      }

      if (this.clientSocket) {
        this.clientSocket.off('message')
        this.clientSocket.off('close')
        this.clientSocket.off('error')
        this.clientSocket.close()
        this.clientSocket = null
      }

      if (this.serverSocket) {
        this.serverSocket.off('connect')
        this.serverSocket.close()
        this.serverSocket = null
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Disconnect error`)
    }

    this._connState = ConnState.DISCONNECTED
    this._isHost = false
    this._roomCode = ''
    this._port = 0
    this.recvBuffer = ''
    this.seqCounter = 0
    this.notifyStateChange()
  }

  // ========== 异常断开处理 ==========

  private handleUnexpectedDisconnect(): void {
    hilog.warn(DOMAIN, TAG, 'Unexpected disconnect!')
    this._connState = ConnState.DISCONNECTED
    this.notifyStateChange()
    this.notifyError('对方已断开连接')
  }

  private notifyStateChange(): void {
    if (this.stateCallback) {
      this.stateCallback(this._connState)
    }
  }

  private notifyError(err: string): void {
    if (this.errorCallback) {
      this.errorCallback(err)
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: (value: void) => void) => {
      setTimeout(() => {
        resolve()
      }, ms)
    })
  }

  public static resetInstance(): void {
    NetManager.instance = null
  }
}
