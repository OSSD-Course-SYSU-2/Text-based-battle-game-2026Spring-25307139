import { display } from '@kit.ArkUI';

export enum BreakpointType {
  SM = 'sm',
  MD = 'md',
  LG = 'lg'
}

export class BreakpointUtils {
  static readonly SM_BREAKPOINT: number = 600
  static readonly MD_BREAKPOINT: number = 840

  static currentBreakpoint: BreakpointType = BreakpointType.SM
  static context: Context | null = null

  static registerBreakpointCallback(context: Context): void {
    BreakpointUtils.context = context
    try {
      let disp: display.Display = display.getDefaultDisplaySync()
      let widthVp: number = disp.width / (disp.densityDPI / 160)
      BreakpointUtils.updateBreakpoint(widthVp)
    } catch (e) {
      BreakpointUtils.currentBreakpoint = BreakpointType.SM
    }

    display.on('change', (displayId: number) => {
      try {
        let disp: display.Display = display.getDefaultDisplaySync()
        let widthVp: number = disp.width / (disp.densityDPI / 160)
        BreakpointUtils.updateBreakpoint(widthVp)
      } catch (e) {
      }
    })
  }

  static updateBreakpoint(widthVp: number): void {
    if (widthVp < BreakpointUtils.SM_BREAKPOINT) {
      BreakpointUtils.currentBreakpoint = BreakpointType.SM
    } else if (widthVp < BreakpointUtils.MD_BREAKPOINT) {
      BreakpointUtils.currentBreakpoint = BreakpointType.MD
    } else {
      BreakpointUtils.currentBreakpoint = BreakpointType.LG
    }
  }

  static getCellSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 40
      case BreakpointType.MD:
        return 52
      case BreakpointType.LG:
        return 64
      default:
        return 40
    }
  }

  static getTitleFontSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 36
      case BreakpointType.MD:
        return 48
      case BreakpointType.LG:
        return 56
      default:
        return 36
    }
  }

  static getSubTitleFontSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 20
      case BreakpointType.MD:
        return 24
      case BreakpointType.LG:
        return 28
      default:
        return 20
    }
  }

  static getButtonWidth(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 160
      case BreakpointType.MD:
        return 200
      case BreakpointType.LG:
        return 240
      default:
        return 160
    }
  }

  static getButtonHeight(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 60
      case BreakpointType.MD:
        return 68
      case BreakpointType.LG:
        return 76
      default:
        return 60
    }
  }

  static getButtonFontSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 24
      case BreakpointType.MD:
        return 28
      case BreakpointType.LG:
        return 32
      default:
        return 24
    }
  }

  static getCharCellSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 80
      case BreakpointType.MD:
        return 100
      case BreakpointType.LG:
        return 120
      default:
        return 80
    }
  }

  static getCharFontSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 32
      case BreakpointType.MD:
        return 40
      case BreakpointType.LG:
        return 48
      default:
        return 32
    }
  }

  static getControlBtnSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 52
      case BreakpointType.MD:
        return 64
      case BreakpointType.LG:
        return 76
      default:
        return 52
    }
  }

  static getControlBtnFontSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 20
      case BreakpointType.MD:
        return 24
      case BreakpointType.LG:
        return 28
      default:
        return 20
    }
  }

  static getActionBtnWidth(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 68
      case BreakpointType.MD:
        return 84
      case BreakpointType.LG:
        return 100
      default:
        return 68
    }
  }

  static getTopInfoFontSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 16
      case BreakpointType.MD:
        return 20
      case BreakpointType.LG:
        return 24
      default:
        return 16
    }
  }

  static getGridCharFontSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 20
      case BreakpointType.MD:
        return 26
      case BreakpointType.LG:
        return 32
      default:
        return 20
    }
  }

  static getGridBulletFontSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 18
      case BreakpointType.MD:
        return 24
      case BreakpointType.LG:
        return 28
      default:
        return 18
    }
  }

  static getGameCountdownFontSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 80
      case BreakpointType.MD:
        return 120
      case BreakpointType.LG:
        return 160
      default:
        return 80
    }
  }

  static getGameOverFontSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 40
      case BreakpointType.MD:
        return 56
      case BreakpointType.LG:
        return 72
      default:
        return 40
    }
  }

  static getMaxContentWidth(): string {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return '100%'
      case BreakpointType.MD:
        return '80%'
      case BreakpointType.LG:
        return '70%'
      default:
        return '100%'
    }
  }

  static getHpBarHeight(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.SM:
        return 3
      case BreakpointType.MD:
        return 4
      case BreakpointType.LG:
        return 5
      default:
        return 3
    }
  }

  static isWideScreen(): boolean {
    return BreakpointUtils.currentBreakpoint === BreakpointType.MD ||
      BreakpointUtils.currentBreakpoint === BreakpointType.LG
  }

  static getSideControlBtnSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.MD:
        return 60
      case BreakpointType.LG:
        return 72
      default:
        return 52
    }
  }

  static getSideControlBtnFontSize(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.MD:
        return 22
      case BreakpointType.LG:
        return 26
      default:
        return 20
    }
  }

  static getSideActionBtnWidth(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.MD:
        return 76
      case BreakpointType.LG:
        return 92
      default:
        return 68
    }
  }

  static getSideControlPanelWidth(): number {
    switch (BreakpointUtils.currentBreakpoint) {
      case BreakpointType.MD:
        return 90
      case BreakpointType.LG:
        return 110
      default:
        return 70
    }
  }
}
