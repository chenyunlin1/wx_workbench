import { AppColor, AppFont, AppRadius, AppSpace } from '../theme/Theme'
import { WindowUtils } from '../utils/WindowUtils'

/**
 * 密码限时查看弹层：明文 + 倒计时，到时自动收起；
 * 展示期间开启系统防截屏（窗口隐私模式），文本禁复制。
 */
@ComponentV2
export struct PasswordRevealSheet {
  @Param password: string = ''
  @Param seconds: number = 60
  @Event onClosed: () => void = () => {
  }
  @Local remaining: number = 60
  private startedAt: number = 0
  private timerId: number = -1
  private closed: boolean = false

  aboutToAppear(): void {
    this.remaining = this.seconds
    this.startedAt = Date.now()
    this.setPrivacy(true)
    this.timerId = setInterval(() => {
      const passed = Math.floor((Date.now() - this.startedAt) / 1000)
      const left = this.seconds - passed
      this.remaining = left > 0 ? left : 0
      if (left <= 0) {
        this.finish()
      }
    }, 250)
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
    this.setPrivacy(false)
  }

  private finish(): void {
    if (this.closed) {
      return
    }
    this.closed = true
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
    this.setPrivacy(false)
    this.onClosed()
  }

  private setPrivacy(on: boolean): void {
    WindowUtils.setPrivacyMode(on)
  }

  build() {
    Column({ space: AppSpace.Sm }) {
      Text('查看密码（剩余 ' + this.remaining + ' 秒）')
        .fontSize(AppFont.Caption + 1)
        .fontColor($r('sys.color.font_secondary'))
      Text(this.password)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .copyOption(CopyOptions.None)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .width('100%')
      Text('不可复制。关闭后需再次完成专注才能查看，请立刻记住。')
        .fontSize(10)
        .fontColor($r('sys.color.font_tertiary'))
        .textAlign(TextAlign.Center)
        .width('100%')
      Text('收 起')
        .fontSize(AppFont.BodyL)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.OnBrand)
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(46)
        .borderRadius(AppRadius.Pill)
        .backgroundColor(AppColor.Brand)
        .margin({ top: 6 })
        .onClick(() => {
          this.finish()
        })
    }
    .width('100%')
    .height('100%')
    .padding(AppSpace.Md)
    .justifyContent(FlexAlign.Center)
  }
}
