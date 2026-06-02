import { router } from '@kit.ArkUI';
import { NetManager, MsgType, ConnState, NetMessage, BulletData, GameStateSnapshot } from '../network/NetManager';
import { BreakpointUtils } from '../common/BreakpointUtils';

interface Bullet {
  id: number
  x: number
  y: number
  direction: number
  owner: number
  isSkill: boolean
  active: boolean
}

// 移动数据
interface MoveData {
  dx: number
  dy: number
}

// 游戏结束数据
interface GameOverData {
  winner: string
}

@Entry
@Component
struct OnlineBattlePage {
  private readonly GRID_COLS: number = 12
  private readonly GRID_ROWS: number = 8
  private readonly MAX_HP: number = 300
  private readonly ATTACK_DMG: number = 10
  private readonly FILL_PER_HIT: number = 0.2
  private readonly SKILL_COLORS: string[] = ['#FF0000', '#00CC00', '#FFCC00', '#9900CC']

  // 我方信息
  @State myPlayerIndex: number = 1 // 1=玩家1(左), 2=玩家2(右)
  @State isHost: boolean = true

  // 角色名
  @State player1Char: string = '剑'
  @State player2Char: string = '盾'

  // 位置
  @State p1X: number = 3
  @State p1Y: number = 4
  @State p2X: number = 9
  @State p2Y: number = 4

  // 生命值
  @State p1Hp: number = 300
  @State p2Hp: number = 300

  // 蓝色填充进度
  @State p1Fill: number = 0
  @State p2Fill: number = 0

  // 格子颜色状态
  @State p1CellColor: string = ''
  @State p2CellColor: string = ''

  // 黄色护盾
  @State p1Shield: number = 0
  @State p2Shield: number = 0

  // 紫色隐身
  @State p1Invisible: boolean = false
  @State p2Invisible: boolean = false
  private p1InvisTimer: number = -1
  private p2InvisTimer: number = -1

  // 弹幕
  @State bullets: Bullet[] = []
  private bulletIdCounter: number = 0

  // 游戏状态
  @State countdown: number = 3
  @State gameStarted: boolean = false
  @State gameOver: boolean = false
  @State winnerText: string = ''

  // 网络状态
  @State connError: string = ''
  @State syncDelay: number = 0

  // 定时器
  private bulletMoveTimer: number = -1
  private countdownTimer: number = -1
  private stateSyncTimer: number = -1

  // 网格显示
  @State gridDisplay: string[] = []

  // 网络管理器
  private netManager: NetManager = NetManager.getInstance()

  // 上次同步的序列号
  private lastRecvSeq: number = 0

  @State isWide: boolean = false

  aboutToAppear() {
    BreakpointUtils.registerBreakpointCallback(this.getUIContext().getHostContext() as Context)
    this.isWide = BreakpointUtils.isWideScreen()

    const params = router.getParams() as Record<string, string>
    if (params) {
      this.player1Char = params['player1Char'] as string || '剑'
      this.player2Char = params['player2Char'] as string || '盾'
      this.myPlayerIndex = parseInt(params['myPlayerIndex'] as string || '1')
      this.isHost = (params['isHost'] as string) === 'true'
    }

    this.p1X = Math.floor(this.GRID_COLS / 4)
    this.p1Y = Math.floor(this.GRID_ROWS / 2)
    this.p2X = Math.floor(this.GRID_COLS * 3 / 4)
    this.p2Y = Math.floor(this.GRID_ROWS / 2)

    // 设置网络消息回调
    this.netManager.onMessage((msg) => {
      this.handleNetMessage(msg)
    })

    this.netManager.onStateChange((state: ConnState) => {
      if (state === ConnState.DISCONNECTED) {
        this.connError = '连接已断开'
        if (this.gameStarted && !this.gameOver) {
          this.endGame('对方断开连接，你获胜！')
        }
      }
    })

    this.netManager.onError((err: string) => {
      this.connError = err
    })

    this.updateGridDisplay()
    this.startCountdown()
  }

  aboutToDisappear() {
    this.clearAllTimers()
    this.netManager.stopHeartbeat()
  }

  // ========== 网络消息处理 ==========

  private handleNetMessage(msg: NetMessage): void {
    let type = msg.type
    let data = msg.data as Record<string, Object>
    let seq = msg.seq

    // 序列号去重（忽略旧消息）
    if (seq > 0 && seq <= this.lastRecvSeq) {
      return
    }
    if (seq > 0) {
      this.lastRecvSeq = seq
    }

    switch (type) {
      case MsgType.GAME_MOVE: {
        // 对方移动
        let dx = data['dx'] as number
        let dy = data['dy'] as number
        if (this.myPlayerIndex === 1) {
          // 我是玩家1，对方是玩家2
          this.moveP2(dx, dy)
        } else {
          // 我是玩家2，对方是玩家1
          this.moveP1Local(dx, dy)
        }
        break
      }
      case MsgType.GAME_ATTACK: {
        // 对方攻击
        if (this.myPlayerIndex === 1) {
          // 我是玩家1，对方是玩家2，执行玩家2攻击
          this.attackP2Local()
        } else {
          // 我是玩家2，对方是玩家1，执行玩家1攻击
          this.attackP1Action()
        }
        break
      }
      case MsgType.GAME_SKILL: {
        // 对方释放技能
        if (this.myPlayerIndex === 1) {
          // 我是玩家1，对方是玩家2
          this.useSkillP2Local()
        } else {
          // 我是玩家2，对方是玩家1
          this.useSkillP1Action()
        }
        break
      }
      case MsgType.GAME_STATE_SYNC: {
        // 完整状态同步
        this.applyStateSync(data)
        break
      }
      case MsgType.GAME_OVER: {
        let winner = data['winner'] as string
        if (!this.gameOver) {
          this.endGame(winner)
        }
        break
      }
      case MsgType.DISCONNECT: {
        this.connError = '对方已断开连接'
        if (!this.gameOver) {
          this.endGame('对方断开连接，你获胜！')
        }
        break
      }
    }
  }

  // ========== 倒计时 ==========

  private startCountdown() {
    this.countdown = 3
    this.countdownTimer = setInterval(() => {
      if (this.countdown > 1) {
        this.countdown--
      } else {
        clearInterval(this.countdownTimer)
        this.countdown = 0
        this.gameStarted = true
        this.startGameLoop()
      }
    }, 1000) as number
  }

  private startGameLoop() {
    // 弹幕移动定时器（双方各自运行，通过状态同步保持一致）
    this.bulletMoveTimer = setInterval(() => {
      this.moveBullets()
    }, 200) as number

    // 定期状态同步（房主负责发送完整状态同步）
    if (this.isHost) {
      this.stateSyncTimer = setInterval(() => {
        this.sendStateSync()
      }, 500) as number
    }
  }

  private clearAllTimers() {
    if (this.countdownTimer !== -1) clearInterval(this.countdownTimer)
    if (this.bulletMoveTimer !== -1) clearInterval(this.bulletMoveTimer)
    if (this.stateSyncTimer !== -1) clearInterval(this.stateSyncTimer)
    if (this.p1InvisTimer !== -1) clearInterval(this.p1InvisTimer)
    if (this.p2InvisTimer !== -1) clearInterval(this.p2InvisTimer)
  }

  // ========== 移动 ==========

  // 我方移动（玩家1或玩家2，取决于myPlayerIndex）
  private moveMy(dx: number, dy: number) {
    if (!this.gameStarted || this.gameOver) return

    if (this.myPlayerIndex === 1) {
      this.moveP1Local(dx, dy)
    } else {
      this.moveP2Local(dx, dy)
    }

    // 通知对方
    let moveData: MoveData = { dx: dx, dy: dy }
    this.netManager.sendMessage(MsgType.GAME_MOVE, moveData)
  }

  private moveP1Local(dx: number, dy: number) {
    if (!this.gameStarted || this.gameOver) return
    let newX = this.p1X + dx
    let newY = this.p1Y + dy
    if (newX >= 0 && newX < this.GRID_COLS && newY >= 0 && newY < this.GRID_ROWS) {
      if (newX !== this.p2X || newY !== this.p2Y) {
        this.p1X = newX
        this.p1Y = newY
        this.updateGridDisplay()
      }
    }
  }

  private moveP2Local(dx: number, dy: number) {
    if (!this.gameStarted || this.gameOver) return
    let newX = this.p2X + dx
    let newY = this.p2Y + dy
    if (newX >= 0 && newX < this.GRID_COLS && newY >= 0 && newY < this.GRID_ROWS) {
      if (newX !== this.p1X || newY !== this.p1Y) {
        this.p2X = newX
        this.p2Y = newY
        this.updateGridDisplay()
      }
    }
  }

  // 对方移动玩家2（我是玩家1时收到对方移动）
  private moveP2(dx: number, dy: number) {
    this.moveP2Local(dx, dy)
  }

  // ========== 攻击 ==========

  // 我方攻击
  private attackMy() {
    if (!this.gameStarted || this.gameOver) return

    if (this.myPlayerIndex === 1) {
      this.attackP1Local()
    } else {
      this.attackP2Local()
    }

    // 通知对方
    let emptyData: Record<string, Object> = {}
    this.netManager.sendMessage(MsgType.GAME_ATTACK, emptyData)
  }

  private attackP1Local() {
    if (!this.gameStarted || this.gameOver) return
    let dir = this.p2X > this.p1X ? 1 : -1
    this.bulletIdCounter++
    let newBullet: Bullet = {
      id: this.bulletIdCounter,
      x: this.p1X + dir,
      y: this.p1Y,
      direction: dir,
      owner: 1,
      isSkill: false,
      active: true
    }
    this.bullets = [...this.bullets, newBullet]
    this.updateGridDisplay()
  }

  private attackP2Local() {
    if (!this.gameStarted || this.gameOver) return
    let dir = this.p1X > this.p2X ? 1 : -1
    this.bulletIdCounter++
    let newBullet: Bullet = {
      id: this.bulletIdCounter,
      x: this.p2X + dir,
      y: this.p2Y,
      direction: dir,
      owner: 2,
      isSkill: false,
      active: true
    }
    this.bullets = [...this.bullets, newBullet]
    this.updateGridDisplay()
  }

  // 对方攻击：玩家1发射弹幕（当我是玩家2时收到对方攻击）
  private attackP1Action() {
    if (!this.gameStarted || this.gameOver) return
    let dir = this.p2X > this.p1X ? 1 : -1
    this.bulletIdCounter++
    let newBullet: Bullet = {
      id: this.bulletIdCounter,
      x: this.p1X + dir,
      y: this.p1Y,
      direction: dir,
      owner: 1,
      isSkill: false,
      active: true
    }
    this.bullets = [...this.bullets, newBullet]
    this.updateGridDisplay()
  }

  // ========== 技能 ==========

  // 我方释放技能
  private useSkillMy() {
    if (!this.gameStarted || this.gameOver) return

    if (this.myPlayerIndex === 1) {
      this.useSkillP1Local()
    } else {
      this.useSkillP2Local()
    }

    // 通知对方
    let emptyData: Record<string, Object> = {}
    this.netManager.sendMessage(MsgType.GAME_SKILL, emptyData)
  }

  private useSkillP1Local() {
    if (!this.gameStarted || this.gameOver) return
    let skill = this.p1CellColor
    if (skill !== 'red' && skill !== 'green' && skill !== 'yellow' && skill !== 'purple') return

    this.executeSkill(1, skill)
    this.p1Fill = 0
    this.p1CellColor = ''
    this.updateGridDisplay()
  }

  private useSkillP2Local() {
    if (!this.gameStarted || this.gameOver) return
    let skill = this.p2CellColor
    if (skill !== 'red' && skill !== 'green' && skill !== 'yellow' && skill !== 'purple') return

    this.executeSkill(2, skill)
    this.p2Fill = 0
    this.p2CellColor = ''
    this.updateGridDisplay()
  }

  // 对方释放技能：玩家1释放技能（当我是玩家2时收到对方技能）
  private useSkillP1Action() {
    if (!this.gameStarted || this.gameOver) return
    let skill = this.p1CellColor
    if (skill !== 'red' && skill !== 'green' && skill !== 'yellow' && skill !== 'purple') return

    this.executeSkill(1, skill)
    this.p1Fill = 0
    this.p1CellColor = ''
    this.updateGridDisplay()
  }

  // ========== 弹幕移动与命中 ==========

  private moveBullets() {
    if (this.gameOver) return

    let hitP1Count: number = 0
    let hitP2Count: number = 0
    let skillHitP2Count: number = 0
    let skillHitP1Count: number = 0
    let newBullets: Bullet[] = []

    for (let i = 0; i < this.bullets.length; i++) {
      let b = this.bullets[i]
      if (!b.active) continue

      let newX = b.x + b.direction

      if (newX < 0 || newX >= this.GRID_COLS) {
        continue
      }

      // 命中判定
      if (b.owner === 1 && newX === this.p2X && b.y === this.p2Y && !this.p2Invisible) {
        if (b.isSkill) {
          skillHitP2Count++
        } else {
          hitP2Count++
        }
        continue
      } else if (b.owner === 2 && newX === this.p1X && b.y === this.p1Y && !this.p1Invisible) {
        if (b.isSkill) {
          skillHitP1Count++
        } else {
          hitP1Count++
        }
        continue
      }

      let movedBullet: Bullet = {
        id: b.id,
        x: newX,
        y: b.y,
        direction: b.direction,
        owner: b.owner,
        isSkill: b.isSkill,
        active: true
      }
      newBullets.push(movedBullet)
    }

    this.bullets = newBullets

    // 处理普通命中 - 玩家2
    if (hitP2Count > 0) {
      for (let i = 0; i < hitP2Count; i++) {
        if (this.p2Shield > 0) {
          this.p2Shield--
        } else {
          this.p2Hp = Math.max(0, this.p2Hp - this.ATTACK_DMG)
        }
        // 玩家1格子填充蓝色
        if (this.p1CellColor === '' || this.p1CellColor === 'blue') {
          this.p1Fill = Math.min(1, this.p1Fill + this.FILL_PER_HIT)
          this.p1CellColor = 'blue'
          if (this.p1Fill >= 1) {
            this.p1CellColor = this.randomSkillColor()
          }
        }
      }
      if (this.p2Hp <= 0) {
        this.endGame('玩家1 获胜！')
        return
      }
    }

    // 处理普通命中 - 玩家1
    if (hitP1Count > 0) {
      for (let i = 0; i < hitP1Count; i++) {
        if (this.p1Shield > 0) {
          this.p1Shield--
        } else {
          this.p1Hp = Math.max(0, this.p1Hp - this.ATTACK_DMG)
        }
        // 玩家2格子填充蓝色
        if (this.p2CellColor === '' || this.p2CellColor === 'blue') {
          this.p2Fill = Math.min(1, this.p2Fill + this.FILL_PER_HIT)
          this.p2CellColor = 'blue'
          if (this.p2Fill >= 1) {
            this.p2CellColor = this.randomSkillColor()
          }
        }
      }
      if (this.p1Hp <= 0) {
        this.endGame('玩家2 获胜！')
        return
      }
    }

    // 处理技能弹幕命中玩家2
    if (skillHitP2Count > 0) {
      let dmg = Math.min(skillHitP2Count * 25, 100)
      if (this.p2Shield > 0) {
        this.p2Shield--
        dmg = Math.floor(dmg / 2)
      }
      this.p2Hp = Math.max(0, this.p2Hp - dmg)
      if (this.p2Hp <= 0) {
        this.endGame('玩家1 获胜！')
        return
      }
    }

    // 处理技能弹幕命中玩家1
    if (skillHitP1Count > 0) {
      let dmg = Math.min(skillHitP1Count * 25, 100)
      if (this.p1Shield > 0) {
        this.p1Shield--
        dmg = Math.floor(dmg / 2)
      }
      this.p1Hp = Math.max(0, this.p1Hp - dmg)
      if (this.p1Hp <= 0) {
        this.endGame('玩家2 获胜！')
        return
      }
    }

    this.updateGridDisplay()
  }

  // ========== 技能系统 ==========

  private randomSkillColor(): string {
    let colors = ['red', 'green', 'yellow', 'purple']
    return colors[Math.floor(Math.random() * colors.length)]
  }

  private getSkillColorHex(colorName: string): string {
    if (colorName === 'red') return '#FF0000'
    if (colorName === 'green') return '#00CC00'
    if (colorName === 'yellow') return '#FFCC00'
    if (colorName === 'purple') return '#9900CC'
    return '#FFFFFF'
  }

  private executeSkill(owner: number, skill: string) {
    if (skill === 'red') {
      this.skillRed(owner)
    } else if (skill === 'green') {
      this.skillGreen(owner)
    } else if (skill === 'yellow') {
      this.skillYellow(owner)
    } else if (skill === 'purple') {
      this.skillPurple(owner)
    }
  }

  private skillRed(owner: number) {
    let fromX = owner === 1 ? this.p1X : this.p2X
    let fromY = owner === 1 ? this.p1Y : this.p2Y
    let dir = owner === 1 ? (this.p2X > this.p1X ? 1 : -1) : (this.p1X > this.p2X ? 1 : -1)

    let rows = [fromY]
    if (fromY - 1 >= 0) rows.push(fromY - 1)
    if (fromY + 1 < this.GRID_ROWS) rows.push(fromY + 1)

    for (let row of rows) {
      for (let i = 1; i <= 5; i++) {
        let startX = fromX + dir * i
        if (startX >= 0 && startX < this.GRID_COLS) {
          this.bulletIdCounter++
          let newBullet: Bullet = {
            id: this.bulletIdCounter,
            x: startX,
            y: row,
            direction: dir,
            owner: owner,
            isSkill: true,
            active: true
          }
          this.bullets = [...this.bullets, newBullet]
        }
      }
    }
  }

  private skillGreen(owner: number) {
    if (owner === 1) {
      this.p1Hp = Math.min(this.MAX_HP, this.p1Hp + 50)
    } else {
      this.p2Hp = Math.min(this.MAX_HP, this.p2Hp + 50)
    }
  }

  private skillYellow(owner: number) {
    if (owner === 1) {
      this.p1Shield = 4
    } else {
      this.p2Shield = 4
    }
  }

  private skillPurple(owner: number) {
    if (owner === 1) {
      this.p1Invisible = true
      if (this.p1InvisTimer !== -1) clearInterval(this.p1InvisTimer)
      this.p1InvisTimer = setTimeout(() => {
        this.p1Invisible = false
        if (this.p1X === this.p2X && this.p1Y === this.p2Y) {
          this.p2Hp = Math.max(0, this.p2Hp - 50)
          this.p1Hp = Math.min(this.MAX_HP, this.p1Hp + 10)
          let backDir = this.p2X > this.p1X ? -1 : 1
          let newX = this.p1X + backDir
          if (newX >= 0 && newX < this.GRID_COLS) {
            this.p1X = newX
          }
          if (this.p2Hp <= 0) {
            this.endGame('玩家1 获胜！')
          }
        }
        this.updateGridDisplay()
      }, 2500) as number
    } else {
      this.p2Invisible = true
      if (this.p2InvisTimer !== -1) clearInterval(this.p2InvisTimer)
      this.p2InvisTimer = setTimeout(() => {
        this.p2Invisible = false
        if (this.p1X === this.p2X && this.p1Y === this.p2Y) {
          this.p1Hp = Math.max(0, this.p1Hp - 50)
          this.p2Hp = Math.min(this.MAX_HP, this.p2Hp + 10)
          let backDir = this.p1X > this.p2X ? -1 : 1
          let newX = this.p2X + backDir
          if (newX >= 0 && newX < this.GRID_COLS) {
            this.p2X = newX
          }
          if (this.p1Hp <= 0) {
            this.endGame('玩家2 获胜！')
          }
        }
        this.updateGridDisplay()
      }, 2500) as number
    }
  }

  // ========== 状态同步 ==========

  private sendStateSync() {
    let bulletData: BulletData[] = []
    for (let b of this.bullets) {
      let bd: BulletData = {
        id: b.id,
        x: b.x,
        y: b.y,
        direction: b.direction,
        owner: b.owner,
        isSkill: b.isSkill,
        active: b.active
      }
      bulletData.push(bd)
    }

    let snapshot: GameStateSnapshot = {
      p1X: this.p1X,
      p1Y: this.p1Y,
      p2X: this.p2X,
      p2Y: this.p2Y,
      p1Hp: this.p1Hp,
      p2Hp: this.p2Hp,
      p1Fill: this.p1Fill,
      p2Fill: this.p2Fill,
      p1CellColor: this.p1CellColor,
      p2CellColor: this.p2CellColor,
      p1Shield: this.p1Shield,
      p2Shield: this.p2Shield,
      p1Invisible: this.p1Invisible,
      p2Invisible: this.p2Invisible,
      bullets: bulletData,
      gameOver: this.gameOver,
      winnerText: this.winnerText
    }

    this.netManager.sendMessage(MsgType.GAME_STATE_SYNC, snapshot)
  }

  private applyStateSync(data: Record<string, Object>) {
    // 非房主接收房主的状态同步，校正本地状态
    if (this.isHost) return // 房主不接收状态同步

    this.p1X = data['p1X'] as number
    this.p1Y = data['p1Y'] as number
    this.p2X = data['p2X'] as number
    this.p2Y = data['p2Y'] as number
    this.p1Hp = data['p1Hp'] as number
    this.p2Hp = data['p2Hp'] as number
    this.p1Fill = data['p1Fill'] as number
    this.p2Fill = data['p2Fill'] as number
    this.p1CellColor = data['p1CellColor'] as string
    this.p2CellColor = data['p2CellColor'] as string
    this.p1Shield = data['p1Shield'] as number
    this.p2Shield = data['p2Shield'] as number
    this.p1Invisible = data['p1Invisible'] as boolean
    this.p2Invisible = data['p2Invisible'] as boolean

    let bulletDataArr = data['bullets'] as BulletData[]
    if (bulletDataArr) {
      let newBullets: Bullet[] = []
      for (let bd of bulletDataArr) {
        let nb: Bullet = {
          id: bd.id,
          x: bd.x,
          y: bd.y,
          direction: bd.direction,
          owner: bd.owner,
          isSkill: bd.isSkill,
          active: bd.active
        }
        newBullets.push(nb)
      }
      this.bullets = newBullets
    }

    let remoteGameOver = data['gameOver'] as boolean
    if (remoteGameOver && !this.gameOver) {
      this.endGame(data['winnerText'] as string)
    }

    this.updateGridDisplay()
  }

  // ========== 游戏结束 ==========

  private endGame(winner: string) {
    this.gameOver = true
    this.winnerText = winner
    this.bullets = []
    this.clearAllTimers()
    this.updateGridDisplay()

    // 通知对方游戏结束
    let overData: GameOverData = { winner: winner }
    this.netManager.sendMessage(MsgType.GAME_OVER, overData)
  }

  // ========== 网格显示 ==========

  private updateGridDisplay() {
    let grid: string[] = []
    for (let r = 0; r < this.GRID_ROWS; r++) {
      for (let c = 0; c < this.GRID_COLS; c++) {
        grid.push('')
      }
    }

    if (!this.p1Invisible) {
      let p1Idx = this.p1Y * this.GRID_COLS + this.p1X
      if (p1Idx >= 0 && p1Idx < grid.length) {
        grid[p1Idx] = this.player1Char
      }
    }
    if (!this.p2Invisible) {
      let p2Idx = this.p2Y * this.GRID_COLS + this.p2X
      if (p2Idx >= 0 && p2Idx < grid.length) {
        grid[p2Idx] = this.player2Char
      }
    }

    for (let b of this.bullets) {
      if (b.active) {
        let bIdx = b.y * this.GRID_COLS + b.x
        if (bIdx >= 0 && bIdx < grid.length && grid[bIdx] === '') {
          grid[bIdx] = b.isSkill ? '@' : '！'
        }
      }
    }

    this.gridDisplay = grid
  }

  private getCellContent(idx: number): string {
    if (idx >= 0 && idx < this.gridDisplay.length) {
      return this.gridDisplay[idx]
    }
    return ''
  }

  private isP1Cell(row: number, col: number): boolean {
    return !this.p1Invisible && row === this.p1Y && col === this.p1X
  }

  private isP2Cell(row: number, col: number): boolean {
    return !this.p2Invisible && row === this.p2Y && col === this.p2X
  }

  private isBulletCell(idx: number): boolean {
    let c = this.getCellContent(idx)
    return c === '！' || c === '@'
  }

  private isSkillBulletCell(idx: number): boolean {
    return this.getCellContent(idx) === '@'
  }

  private getP1CellBg(): string {
    if (this.p1CellColor === 'blue') return '#0066CC'
    if (this.p1CellColor === 'red') return '#FF0000'
    if (this.p1CellColor === 'green') return '#00CC00'
    if (this.p1CellColor === 'yellow') return '#FFCC00'
    if (this.p1CellColor === 'purple') return '#9900CC'
    return '#2A2A3E'
  }

  private getP2CellBg(): string {
    if (this.p2CellColor === 'blue') return '#0066CC'
    if (this.p2CellColor === 'red') return '#FF0000'
    if (this.p2CellColor === 'green') return '#00CC00'
    if (this.p2CellColor === 'yellow') return '#FFCC00'
    if (this.p2CellColor === 'purple') return '#9900CC'
    return '#2A2A3E'
  }

  // 技能按钮是否可用（根据我方角色格子颜色）
  private canUseSkill(): boolean {
    let c = this.myPlayerIndex === 1 ? this.p1CellColor : this.p2CellColor
    return c === 'red' || c === 'green' || c === 'yellow' || c === 'purple'
  }

  private getSkillLabel(): string {
    let c = this.myPlayerIndex === 1 ? this.p1CellColor : this.p2CellColor
    if (c === 'red') return '技能:红'
    if (c === 'green') return '技能:绿'
    if (c === 'yellow') return '技能:黄'
    if (c === 'purple') return '技能:紫'
    return '技能'
  }

  private getSkillBtnColor(): string {
    let c = this.myPlayerIndex === 1 ? this.p1CellColor : this.p2CellColor
    if (c === 'red') return '#FF0000'
    if (c === 'green') return '#00CC00'
    if (c === 'yellow') return '#FFCC00'
    if (c === 'purple') return '#9900CC'
    return '#555555'
  }

  // 获取我方角色标签
  private getMyLabel(): string {
    if (this.myPlayerIndex === 1) {
      return this.player1Char + '(你)'
    }
    return this.player2Char + '(你)'
  }

  // 获取对方角色标签
  private getOpponentLabel(): string {
    if (this.myPlayerIndex === 1) {
      return this.player2Char + '(对方)'
    }
    return this.player1Char + '(对方)'
  }

  build() {
    Stack() {
    Column() {
      Row() {
        Column() {
          Text(this.player1Char + (this.myPlayerIndex === 1 ? '(你)' : '(对方)'))
            .fontSize(BreakpointUtils.getTopInfoFontSize())
            .fontColor('#00CCFF')
            .fontWeight(FontWeight.Bold)
          if (this.p1Shield > 0) {
            Text('护盾x' + this.p1Shield)
              .fontSize(BreakpointUtils.getTopInfoFontSize() - 4)
              .fontColor('#FFCC00')
          }
          if (this.p1Invisible) {
            Text('隐身中')
              .fontSize(BreakpointUtils.getTopInfoFontSize() - 4)
              .fontColor('#9900CC')
          }
        }

        Blank()

        if (this.connError.length > 0) {
          Text('!')
            .fontSize(BreakpointUtils.getTopInfoFontSize() - 2)
            .fontColor('#FF4444')
            .fontWeight(FontWeight.Bold)
        } else {
          Text('●')
            .fontSize(BreakpointUtils.getTopInfoFontSize() - 6)
            .fontColor('#00CC00')
        }

        Blank()

        Column() {
          Text(this.player2Char + (this.myPlayerIndex === 2 ? '(你)' : '(对方)'))
            .fontSize(BreakpointUtils.getTopInfoFontSize())
            .fontColor('#FF8800')
            .fontWeight(FontWeight.Bold)
          if (this.p2Shield > 0) {
            Text('护盾x' + this.p2Shield)
              .fontSize(BreakpointUtils.getTopInfoFontSize() - 4)
              .fontColor('#FFCC00')
          }
          if (this.p2Invisible) {
            Text('隐身中')
              .fontSize(BreakpointUtils.getTopInfoFontSize() - 4)
              .fontColor('#9900CC')
          }
        }
      }
      .width('90%')
      .margin({ top: 10, bottom: 5 })

      if (this.isWide && this.gameStarted && !this.gameOver) {
        Row() {
          Column() {
            Button('▲')
              .width(BreakpointUtils.getSideControlBtnSize())
              .height(BreakpointUtils.getSideControlBtnSize())
              .fontSize(BreakpointUtils.getSideControlBtnFontSize())
              .backgroundColor('#3A3A5E')
              .fontColor('#FFFFFF')
              .borderRadius(8)
              .onClick(() => this.moveMy(0, -1))

            Row() {
              Button('◀')
                .width(BreakpointUtils.getSideControlBtnSize())
                .height(BreakpointUtils.getSideControlBtnSize())
                .fontSize(BreakpointUtils.getSideControlBtnFontSize())
                .backgroundColor('#3A3A5E')
                .fontColor('#FFFFFF')
                .borderRadius(8)
                .onClick(() => this.moveMy(-1, 0))

              Blank().width(6)

              Button('▶')
                .width(BreakpointUtils.getSideControlBtnSize())
                .height(BreakpointUtils.getSideControlBtnSize())
                .fontSize(BreakpointUtils.getSideControlBtnFontSize())
                .backgroundColor('#3A3A5E')
                .fontColor('#FFFFFF')
                .borderRadius(8)
                .onClick(() => this.moveMy(1, 0))
            }

            Button('▼')
              .width(BreakpointUtils.getSideControlBtnSize())
              .height(BreakpointUtils.getSideControlBtnSize())
              .fontSize(BreakpointUtils.getSideControlBtnFontSize())
              .backgroundColor('#3A3A5E')
              .fontColor('#FFFFFF')
              .borderRadius(8)
              .onClick(() => this.moveMy(0, 1))
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          this.GameGrid()

          Column() {
            Button('攻击')
              .width(BreakpointUtils.getSideActionBtnWidth())
              .height(BreakpointUtils.getSideControlBtnSize())
              .fontSize(BreakpointUtils.getSideControlBtnFontSize() - 2)
              .fontWeight(FontWeight.Bold)
              .backgroundColor('#CC3300')
              .fontColor('#FFFFFF')
              .borderRadius(8)
              .onClick(() => this.attackMy())

            Blank().height(8)

            Button(this.getSkillLabel())
              .width(BreakpointUtils.getSideActionBtnWidth())
              .height(BreakpointUtils.getSideControlBtnSize())
              .fontSize(BreakpointUtils.getSideControlBtnFontSize() - 6)
              .fontWeight(FontWeight.Bold)
              .backgroundColor(this.canUseSkill() ? this.getSkillBtnColor() : '#555555')
              .fontColor(this.canUseSkill() ? '#FFFFFF' : '#888888')
              .borderRadius(8)
              .enabled(this.canUseSkill())
              .onClick(() => this.useSkillMy())
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      } else {
        this.GameGrid()

        if (this.gameStarted && !this.gameOver) {
          Column() {
            Row() {
              Button('▲')
                .width(BreakpointUtils.getControlBtnSize())
                .height(BreakpointUtils.getControlBtnSize())
                .fontSize(BreakpointUtils.getControlBtnFontSize())
                .backgroundColor('#3A3A5E')
                .fontColor('#FFFFFF')
                .borderRadius(8)
                .onClick(() => this.moveMy(0, -1))
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .margin({ bottom: 4 })

            Row() {
              Button('◀')
                .width(BreakpointUtils.getControlBtnSize())
                .height(BreakpointUtils.getControlBtnSize())
                .fontSize(BreakpointUtils.getControlBtnFontSize())
                .backgroundColor('#3A3A5E')
                .fontColor('#FFFFFF')
                .borderRadius(8)
                .onClick(() => this.moveMy(-1, 0))

              Blank().width(8)

              Button('攻击')
                .width(BreakpointUtils.getActionBtnWidth())
                .height(BreakpointUtils.getControlBtnSize())
                .fontSize(BreakpointUtils.getControlBtnFontSize() - 2)
                .fontWeight(FontWeight.Bold)
                .backgroundColor('#CC3300')
                .fontColor('#FFFFFF')
                .borderRadius(8)
                .onClick(() => this.attackMy())

              Blank().width(8)

              Button(this.getSkillLabel())
                .width(BreakpointUtils.getActionBtnWidth())
                .height(BreakpointUtils.getControlBtnSize())
                .fontSize(BreakpointUtils.getControlBtnFontSize() - 6)
                .fontWeight(FontWeight.Bold)
                .backgroundColor(this.canUseSkill() ? this.getSkillBtnColor() : '#555555')
                .fontColor(this.canUseSkill() ? '#FFFFFF' : '#888888')
                .borderRadius(8)
                .enabled(this.canUseSkill())
                .onClick(() => this.useSkillMy())

              Blank().width(8)

              Button('▶')
                .width(BreakpointUtils.getControlBtnSize())
                .height(BreakpointUtils.getControlBtnSize())
                .fontSize(BreakpointUtils.getControlBtnFontSize())
                .backgroundColor('#3A3A5E')
                .fontColor('#FFFFFF')
                .borderRadius(8)
                .onClick(() => this.moveMy(1, 0))
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .margin({ bottom: 4 })

            Row() {
              Button('▼')
                .width(BreakpointUtils.getControlBtnSize())
                .height(BreakpointUtils.getControlBtnSize())
                .fontSize(BreakpointUtils.getControlBtnFontSize())
                .backgroundColor('#3A3A5E')
                .fontColor('#FFFFFF')
                .borderRadius(8)
                .onClick(() => this.moveMy(0, 1))
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
          }
          .margin({ top: 10 })
        }
      }

      if (this.connError.length > 0) {
        Text(this.connError)
          .fontSize(BreakpointUtils.getTopInfoFontSize() - 4)
          .fontColor('#FF4444')
          .margin({ top: 4 })
      }
    }
    .padding({ bottom: 40 })
    .width('100%')
    .height('100%')
    .backgroundColor('#1A1A2E')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)

    if (!this.gameStarted && !this.gameOver) {
      Text(this.countdown.toString())
        .fontSize(BreakpointUtils.getGameCountdownFontSize())
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFCC00')
    }

    if (this.gameOver) {
      Column() {
        Text('GAME OVER！')
          .fontSize(BreakpointUtils.getGameOverFontSize())
          .fontWeight(FontWeight.Bold)
          .fontColor('#FF0000')
          .margin({ bottom: 16 })

        Text(this.winnerText)
          .fontSize(BreakpointUtils.getSubTitleFontSize() + 4)
          .fontColor('#FFCC00')
          .margin({ bottom: 30 })

        Button('返回主界面')
          .width(BreakpointUtils.getButtonWidth())
          .height(BreakpointUtils.getButtonHeight() - 10)
          .fontSize(BreakpointUtils.getSubTitleFontSize())
          .backgroundColor('#FF6600')
          .fontColor('#FFFFFF')
          .borderRadius(10)
          .onClick(() => {
            this.netManager.disconnect()
            router.pushUrl({ url: 'pages/Index' })
          })
      }
    }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  GameGrid() {
    Column() {
      ForEach([0, 1, 2, 3, 4, 5, 6, 7], (row: number) => {
        Row() {
          ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (col: number) => {
            Stack() {
              Column()
                .width(BreakpointUtils.getCellSize())
                .height(BreakpointUtils.getCellSize())
                .backgroundColor('#2A2A3E')
                .border({ width: 0.5, color: '#444466' })

              if (this.isP1Cell(row, col)) {
                Stack() {
                  Column()
                    .width(BreakpointUtils.getCellSize())
                    .height(BreakpointUtils.getCellSize())
                    .backgroundColor(this.getP1CellBg())

                  if (this.p1CellColor === 'blue') {
                    Column() {
                      Column()
                        .width(BreakpointUtils.getCellSize())
                        .height(BreakpointUtils.getCellSize() * (1 - this.p1Fill))
                        .backgroundColor('#2A2A3E')
                    }
                    .width(BreakpointUtils.getCellSize())
                    .height(BreakpointUtils.getCellSize())
                    .alignItems(HorizontalAlign.Center)
                  }

                  Column() {
                    Stack() {
                      Row()
                        .width(BreakpointUtils.getCellSize() - 4)
                        .height(BreakpointUtils.getHpBarHeight())
                        .backgroundColor('#555555')
                        .borderRadius(1)
                      Row()
                        .width((BreakpointUtils.getCellSize() - 4) * (this.p1Hp / this.MAX_HP))
                        .height(BreakpointUtils.getHpBarHeight())
                        .backgroundColor('#00CCFF')
                        .borderRadius(1)
                    }
                    .width(BreakpointUtils.getCellSize() - 4)
                    .height(BreakpointUtils.getHpBarHeight())
                    .alignContent(Alignment.Start)

                    Text(this.player1Char)
                      .fontSize(BreakpointUtils.getGridCharFontSize())
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#FFFFFF')
                  }
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                }
                .width(BreakpointUtils.getCellSize())
                .height(BreakpointUtils.getCellSize())
              } else if (this.isP2Cell(row, col)) {
                Stack() {
                  Column()
                    .width(BreakpointUtils.getCellSize())
                    .height(BreakpointUtils.getCellSize())
                    .backgroundColor(this.getP2CellBg())

                  if (this.p2CellColor === 'blue') {
                    Column() {
                      Column()
                        .width(BreakpointUtils.getCellSize())
                        .height(BreakpointUtils.getCellSize() * (1 - this.p2Fill))
                        .backgroundColor('#2A2A3E')
                    }
                    .width(BreakpointUtils.getCellSize())
                    .height(BreakpointUtils.getCellSize())
                    .alignItems(HorizontalAlign.Center)
                  }

                  Column() {
                    Stack() {
                      Row()
                        .width(BreakpointUtils.getCellSize() - 4)
                        .height(BreakpointUtils.getHpBarHeight())
                        .backgroundColor('#555555')
                        .borderRadius(1)
                      Row()
                        .width((BreakpointUtils.getCellSize() - 4) * (this.p2Hp / this.MAX_HP))
                        .height(BreakpointUtils.getHpBarHeight())
                        .backgroundColor('#FF8800')
                        .borderRadius(1)
                    }
                    .width(BreakpointUtils.getCellSize() - 4)
                    .height(BreakpointUtils.getHpBarHeight())
                    .alignContent(Alignment.Start)

                    Text(this.player2Char)
                      .fontSize(BreakpointUtils.getGridCharFontSize())
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#FFFFFF')
                  }
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                }
                .width(BreakpointUtils.getCellSize())
                .height(BreakpointUtils.getCellSize())
              } else if (this.isSkillBulletCell(row * this.GRID_COLS + col)) {
                Text('@')
                  .fontSize(BreakpointUtils.getGridBulletFontSize())
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FF6600')
              } else if (this.isBulletCell(row * this.GRID_COLS + col)) {
                Text('！')
                  .fontSize(BreakpointUtils.getGridCharFontSize())
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFF00')
              }
            }
            .width(BreakpointUtils.getCellSize())
            .height(BreakpointUtils.getCellSize())
          }, (col: number) => `${row}-${col}`)
        }
      }, (row: number) => row.toString())
    }
    .margin({ top: 5 })
  }
}
