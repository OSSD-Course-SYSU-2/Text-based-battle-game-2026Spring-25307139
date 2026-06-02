import { router } from '@kit.ArkUI';
import { BreakpointUtils } from '../common/BreakpointUtils';

interface Bullet {
  id: number
  x: number
  y: number
  direction: number // 1=向右, -1=向左
  owner: number // 1=玩家1发射, 2=AI发射
  isSkill: boolean // true=技能弹幕@, false=普通弹幕！
  active: boolean
}

@Entry
@Component
struct BattlePage {
  private readonly GRID_COLS: number = 12
  private readonly GRID_ROWS: number = 8
  private readonly MAX_HP: number = 300
  private readonly ATTACK_DMG: number = 10
  private readonly FILL_PER_HIT: number = 0.2 // 每次命中+20%蓝色填充
  private readonly SKILL_COLORS: string[] = ['#FF0000', '#00CC00', '#FFCC00', '#9900CC'] // 红绿黄紫

  @State player1Char: string = '剑'
  @State player2Char: string = '盾'

  @State p1X: number = 3
  @State p1Y: number = 4
  @State p2X: number = 9
  @State p2Y: number = 4

  // 生命值
  @State p1Hp: number = 300
  @State p2Hp: number = 300

  // 蓝色填充进度 (0~1)
  @State p1Fill: number = 0
  @State p2Fill: number = 0

  // 格子颜色状态: ''=白色, 'blue'=蓝色填充中, 'red'/'green'/'yellow'/'purple'=技能色
  @State p1CellColor: string = ''
  @State p2CellColor: string = ''

  // 黄色护盾剩余次数
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

  // 定时器
  private aiMoveTimer: number = -1
  private aiAttackTimer: number = -1
  private aiSkillTimer: number = -1
  private bulletMoveTimer: number = -1
  private countdownTimer: number = -1

  // 网格显示
  @State gridDisplay: string[] = []

  @State isWide: boolean = false

  aboutToAppear() {
    BreakpointUtils.registerBreakpointCallback(this.getUIContext().getHostContext() as Context)
    this.isWide = BreakpointUtils.isWideScreen()

    const params = router.getParams() as Record<string, string>
    if (params) {
      this.player1Char = params['player1Char'] as string || '剑'
      this.player2Char = params['player2Char'] as string || '盾'
    }

    this.p1X = Math.floor(this.GRID_COLS / 4)
    this.p1Y = Math.floor(this.GRID_ROWS / 2)
    this.p2X = Math.floor(this.GRID_COLS * 3 / 4)
    this.p2Y = Math.floor(this.GRID_ROWS / 2)

    this.updateGridDisplay()
    this.startCountdown()
  }

  aboutToDisappear() {
    this.clearAllTimers()
  }

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
    this.bulletMoveTimer = setInterval(() => {
      this.moveBullets()
    }, 200) as number

    this.aiMoveTimer = setInterval(() => {
      this.aiMove()
    }, 800) as number

    this.aiAttackTimer = setInterval(() => {
      this.aiAttack()
    }, 600) as number

    // AI技能释放检测
    this.aiSkillTimer = setInterval(() => {
      this.aiTrySkill()
    }, 500) as number
  }

  private clearAllTimers() {
    if (this.countdownTimer !== -1) clearInterval(this.countdownTimer)
    if (this.bulletMoveTimer !== -1) clearInterval(this.bulletMoveTimer)
    if (this.aiMoveTimer !== -1) clearInterval(this.aiMoveTimer)
    if (this.aiAttackTimer !== -1) clearInterval(this.aiAttackTimer)
    if (this.aiSkillTimer !== -1) clearInterval(this.aiSkillTimer)
    if (this.p1InvisTimer !== -1) clearInterval(this.p1InvisTimer)
    if (this.p2InvisTimer !== -1) clearInterval(this.p2InvisTimer)
  }

  // ========== 移动 ==========

  private moveP1(dx: number, dy: number) {
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

  // ========== 攻击 ==========

  private attackP1() {
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

  private aiAttack() {
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

  // ========== AI移动 ==========

  private aiMove() {
    if (!this.gameStarted || this.gameOver) return
    let directions: number[][] = [[0, -1], [0, 1], [-1, 0], [1, 0]]
    let dx = this.p1X - this.p2X
    let dy = this.p1Y - this.p2Y

    let chosenDir: number[] = []
    let rand = Math.random()
    if (rand < 0.6) {
      if (Math.abs(dx) > Math.abs(dy)) {
        chosenDir = [dx > 0 ? 1 : -1, 0]
      } else {
        chosenDir = [0, dy > 0 ? 1 : -1]
      }
    } else {
      chosenDir = directions[Math.floor(Math.random() * 4)]
    }

    let newX = this.p2X + chosenDir[0]
    let newY = this.p2Y + chosenDir[1]
    if (newX >= 0 && newX < this.GRID_COLS && newY >= 0 && newY < this.GRID_ROWS) {
      if (newX !== this.p1X || newY !== this.p1Y) {
        this.p2X = newX
        this.p2Y = newY
        this.updateGridDisplay()
      }
    }
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

      newBullets.push({
        id: b.id,
        x: newX,
        y: b.y,
        direction: b.direction,
        owner: b.owner,
        isSkill: b.isSkill,
        active: true
      })
    }

    this.bullets = newBullets

    // 处理普通命中 - 对方
    if (hitP2Count > 0) {
      // 玩家1命中AI，AI扣血，玩家1格子填充蓝色
      for (let i = 0; i < hitP2Count; i++) {
        this.p2Hp = Math.max(0, this.p2Hp - this.ATTACK_DMG)
        // 玩家1格子填充蓝色（仅在未满且未变色时）
        if (this.p1CellColor === '' || this.p1CellColor === 'blue') {
          this.p1Fill = Math.min(1, this.p1Fill + this.FILL_PER_HIT)
          this.p1CellColor = 'blue'
          if (this.p1Fill >= 1) {
            // 满了，随机变色
            this.p1CellColor = this.randomSkillColor()
          }
        }
      }
      if (this.p2Hp <= 0) {
        this.endGame('玩家1 获胜！')
        return
      }
    }

    // 处理普通命中 - 玩家
    if (hitP1Count > 0) {
      for (let i = 0; i < hitP1Count; i++) {
        // AI命中玩家1，AI格子填充蓝色
        if (this.p2CellColor === '' || this.p2CellColor === 'blue') {
          this.p2Fill = Math.min(1, this.p2Fill + this.FILL_PER_HIT)
          this.p2CellColor = 'blue'
          if (this.p2Fill >= 1) {
            this.p2CellColor = this.randomSkillColor()
          }
        }
        // 玩家1扣血（考虑护盾）
        if (this.p1Shield > 0) {
          this.p1Shield--
        } else {
          this.p1Hp = Math.max(0, this.p1Hp - this.ATTACK_DMG)
        }
      }
      if (this.p1Hp <= 0) {
        this.endGame('AI 获胜！')
        return
      }
    }

    // 处理技能弹幕命中AI
    if (skillHitP2Count > 0) {
      let dmg = Math.min(skillHitP2Count * 25, 100)
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
        // 护盾对技能弹幕也生效，简化处理：直接扣血但跳过护盾次数
        this.p1Hp = Math.max(0, this.p1Hp - dmg)
      } else {
        this.p1Hp = Math.max(0, this.p1Hp - dmg)
      }
      if (this.p1Hp <= 0) {
        this.endGame('AI 获胜！')
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

  // 玩家1释放技能
  private useSkillP1() {
    if (!this.gameStarted || this.gameOver) return
    let skill = this.p1CellColor
    if (skill !== 'red' && skill !== 'green' && skill !== 'yellow' && skill !== 'purple') return

    this.executeSkill(1, skill)

    // 释放后恢复白色，重新累积
    this.p1Fill = 0
    this.p1CellColor = ''
    this.updateGridDisplay()
  }

  // AI尝试释放技能
  private aiTrySkill() {
    if (!this.gameStarted || this.gameOver) return
    let skill = this.p2CellColor
    if (skill !== 'red' && skill !== 'green' && skill !== 'yellow' && skill !== 'purple') return

    this.executeSkill(2, skill)

    this.p2Fill = 0
    this.p2CellColor = ''
    this.updateGridDisplay()
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

  // 红色技能：三行各5个@，向对方方向发射
  private skillRed(owner: number) {
    let fromX = owner === 1 ? this.p1X : this.p2X
    let fromY = owner === 1 ? this.p1Y : this.p2Y
    let dir = owner === 1 ? (this.p2X > this.p1X ? 1 : -1) : (this.p1X > this.p2X ? 1 : -1)

    // 三行：当前行、上一行、下一行
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

  // 绿色技能：生命值+50，上限300
  private skillGreen(owner: number) {
    if (owner === 1) {
      this.p1Hp = Math.min(this.MAX_HP, this.p1Hp + 50)
    } else {
      this.p2Hp = Math.min(this.MAX_HP, this.p2Hp + 50)
    }
  }

  // 黄色技能：接下来4次被命中不扣血
  private skillYellow(owner: number) {
    if (owner === 1) {
      this.p1Shield = 4
    } else {
      this.p2Shield = 4
    }
  }

  // 紫色技能：消失2.5秒，结束后若重叠则对方-50、自己+10、后退一格
  private skillPurple(owner: number) {
    if (owner === 1) {
      this.p1Invisible = true
      if (this.p1InvisTimer !== -1) clearInterval(this.p1InvisTimer)
      this.p1InvisTimer = setTimeout(() => {
        this.p1Invisible = false
        // 出现位置与对方重叠
        if (this.p1X === this.p2X && this.p1Y === this.p2Y) {
          this.p2Hp = Math.max(0, this.p2Hp - 50)
          this.p1Hp = Math.min(this.MAX_HP, this.p1Hp + 10)
          // 后退一格（远离对方）
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
            this.endGame('AI 获胜！')
          }
        }
        this.updateGridDisplay()
      }, 2500) as number
    }
  }

  // ========== 游戏结束 ==========

  private endGame(winner: string) {
    this.gameOver = true
    this.winnerText = winner
    this.bullets = []
    this.clearAllTimers()
    this.updateGridDisplay()
  }

  // ========== 网格显示 ==========

  private updateGridDisplay() {
    let grid: string[] = []
    for (let r = 0; r < this.GRID_ROWS; r++) {
      for (let c = 0; c < this.GRID_COLS; c++) {
        grid.push('')
      }
    }

    // 放置角色（隐身时不显示）
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

    // 放置弹幕
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

  // 获取角色格子背景色
  private getP1CellBg(): string {
    if (this.p1CellColor === 'blue') {
      return '#0066CC' // 蓝色填充中
    } else if (this.p1CellColor === 'red') {
      return '#FF0000'
    } else if (this.p1CellColor === 'green') {
      return '#00CC00'
    } else if (this.p1CellColor === 'yellow') {
      return '#FFCC00'
    } else if (this.p1CellColor === 'purple') {
      return '#9900CC'
    }
    return '#2A2A3E' // 默认
  }

  private getP2CellBg(): string {
    if (this.p2CellColor === 'blue') {
      return '#0066CC'
    } else if (this.p2CellColor === 'red') {
      return '#FF0000'
    } else if (this.p2CellColor === 'green') {
      return '#00CC00'
    } else if (this.p2CellColor === 'yellow') {
      return '#FFCC00'
    } else if (this.p2CellColor === 'purple') {
      return '#9900CC'
    }
    return '#2A2A3E'
  }

  // 技能按钮是否可用
  private canUseSkill(): boolean {
    let c = this.p1CellColor
    return c === 'red' || c === 'green' || c === 'yellow' || c === 'purple'
  }

  private getSkillLabel(): string {
    if (this.p1CellColor === 'red') return '技能:红'
    if (this.p1CellColor === 'green') return '技能:绿'
    if (this.p1CellColor === 'yellow') return '技能:黄'
    if (this.p1CellColor === 'purple') return '技能:紫'
    return '技能'
  }

  private getSkillBtnColor(): string {
    if (this.p1CellColor === 'red') return '#FF0000'
    if (this.p1CellColor === 'green') return '#00CC00'
    if (this.p1CellColor === 'yellow') return '#FFCC00'
    if (this.p1CellColor === 'purple') return '#9900CC'
    return '#555555'
  }

  build() {
    Stack() {
    Column() {
      Row() {
        Column() {
          Text(this.player1Char + '(你)')
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

        Column() {
          Text(this.player2Char + '(AI)')
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
              .onClick(() => this.moveP1(0, -1))

            Row() {
              Button('◀')
                .width(BreakpointUtils.getSideControlBtnSize())
                .height(BreakpointUtils.getSideControlBtnSize())
                .fontSize(BreakpointUtils.getSideControlBtnFontSize())
                .backgroundColor('#3A3A5E')
                .fontColor('#FFFFFF')
                .borderRadius(8)
                .onClick(() => this.moveP1(-1, 0))

              Blank().width(6)

              Button('▶')
                .width(BreakpointUtils.getSideControlBtnSize())
                .height(BreakpointUtils.getSideControlBtnSize())
                .fontSize(BreakpointUtils.getSideControlBtnFontSize())
                .backgroundColor('#3A3A5E')
                .fontColor('#FFFFFF')
                .borderRadius(8)
                .onClick(() => this.moveP1(1, 0))
            }

            Button('▼')
              .width(BreakpointUtils.getSideControlBtnSize())
              .height(BreakpointUtils.getSideControlBtnSize())
              .fontSize(BreakpointUtils.getSideControlBtnFontSize())
              .backgroundColor('#3A3A5E')
              .fontColor('#FFFFFF')
              .borderRadius(8)
              .onClick(() => this.moveP1(0, 1))
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
              .onClick(() => this.attackP1())

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
              .onClick(() => this.useSkillP1())
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
                .onClick(() => this.moveP1(0, -1))
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
                .onClick(() => this.moveP1(-1, 0))

              Blank().width(8)

              Button('攻击')
                .width(BreakpointUtils.getActionBtnWidth())
                .height(BreakpointUtils.getControlBtnSize())
                .fontSize(BreakpointUtils.getControlBtnFontSize() - 2)
                .fontWeight(FontWeight.Bold)
                .backgroundColor('#CC3300')
                .fontColor('#FFFFFF')
                .borderRadius(8)
                .onClick(() => this.attackP1())

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
                .onClick(() => this.useSkillP1())

              Blank().width(8)

              Button('▶')
                .width(BreakpointUtils.getControlBtnSize())
                .height(BreakpointUtils.getControlBtnSize())
                .fontSize(BreakpointUtils.getControlBtnFontSize())
                .backgroundColor('#3A3A5E')
                .fontColor('#FFFFFF')
                .borderRadius(8)
                .onClick(() => this.moveP1(1, 0))
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
                .onClick(() => this.moveP1(0, 1))
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
          }
          .margin({ top: 10 })
        }
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

        Button('重新开始')
          .width(BreakpointUtils.getButtonWidth() - 20)
          .height(BreakpointUtils.getButtonHeight() - 10)
          .fontSize(BreakpointUtils.getSubTitleFontSize())
          .backgroundColor('#FF6600')
          .fontColor('#FFFFFF')
          .borderRadius(10)
          .onClick(() => {
            router.pushUrl({ url: 'pages/SelectPage' })
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
