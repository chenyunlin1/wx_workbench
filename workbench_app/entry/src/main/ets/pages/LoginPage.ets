import { promptAction } from '@kit.ArkUI'
import { Api } from '../api/Api'
import { toast } from '../common/AppKit'
import { Session } from '../store/Session'
import { AppColor, AppFont, AppRadius, AppSpace } from '../theme/Theme'
import { WindowUtils } from '../utils/WindowUtils'
import { TechBackground } from '../components/Ui'

/** 应用入口：登录成功后由 Session.token 驱动 Index 切换到主页面。 */
@ComponentV2
export struct LoginPage {
  @Local username: string = 'admin'
  @Local password: string = ''
  @Local serverUrl: string = Session.serverUrl
  @Local loading: boolean = false
  @Local showServer: boolean = false

  private async doLogin(): Promise<void> {
    if (this.username.length === 0 || this.password.length === 0) {
      toast('请输入账号和密码')
      return
    }
    this.loading = true
    try {
      const result = await Api.login(this.username, this.password)
      Session.login(result.accessToken, result.user)
      toast('欢迎回来，' + result.user.username)
    } catch (err) {
      const msg = err instanceof Error ? err.message : '登录失败'
      promptAction.showToast({ message: msg, duration: 2600 })
    } finally {
      this.loading = false
    }
  }

  private saveServer(): void {
    const url = this.serverUrl.trim()
    if (url.length === 0) {
      toast('服务器地址不能为空')
      return
    }
    Session.setServerUrl(url)
    toast('服务器地址已保存')
  }

  build() {
    Stack() {
      TechBackground()

      Column({ space: 0 }) {
        // Logo 与标题
        Column({ space: AppSpace.Xs }) {
          SymbolGlyph($r('sys.symbol.square_grid_2x2'))
            .fontSize(44)
            .fontColor([AppColor.Brand])
          Text($r('app.string.app_brand_name'))
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .letterSpacing(2)
          Text('LIFE · WORK · DATA · SYNC')
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
            .letterSpacing(4)
        }
        .margin({ bottom: 36 })

        // 登录卡片
        Column() {
          Text('账号登录')
            .fontSize(AppFont.BodyL)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .margin({ bottom: AppSpace.Md })

          TextInput({ placeholder: '用户名', text: this.username })
            .placeholderColor($r('sys.color.font_tertiary'))
            .fontColor($r('sys.color.font_primary'))
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(AppRadius.Md)
            .height(46)
            .align(Alignment.Start)
            .margin({ bottom: AppSpace.Sm })
            .onChange((value: string) => {
              this.username = value
            })

          TextInput({ placeholder: '密码', text: this.password })
            .placeholderColor($r('sys.color.font_tertiary'))
            .fontColor($r('sys.color.font_primary'))
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(AppRadius.Md)
            .height(46)
            .align(Alignment.Start)
            .type(InputType.Password)
            .margin({ bottom: AppSpace.Xs })
            .onChange((value: string) => {
              this.password = value
            })
            .onSubmit(() => {
              this.doLogin()
            })

          Row() {
            Text('服务器：' + this.serverUrl)
              .fontSize(11)
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text('修改')
              .fontSize(11)
              .fontColor(AppColor.Brand)
              .onClick(() => {
                this.showServer = !this.showServer
              })
          }
          .width('100%')
          .margin({ top: 6, bottom: AppSpace.Xxs })

          if (this.showServer) {
            Row({ space: AppSpace.Xs }) {
              TextInput({ text: this.serverUrl })
                .placeholderColor($r('sys.color.font_tertiary'))
                .fontColor($r('sys.color.font_primary'))
                .fontSize(AppFont.Caption)
                .backgroundColor($r('sys.color.comp_background_tertiary'))
                .borderRadius(AppRadius.Sm)
                .height(38)
                .align(Alignment.Start)
                .layoutWeight(1)
                .onChange((value: string) => {
                  this.serverUrl = value
                })
              Text('保存')
                .fontSize(AppFont.Caption)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColor.OnBrand)
                .padding({ left: AppSpace.Sm, right: AppSpace.Sm, top: AppSpace.Xs, bottom: AppSpace.Xs })
                .borderRadius(AppRadius.Pill)
                .backgroundColor(AppColor.Brand)
                .onClick(() => {
                  this.saveServer()
                })
            }
            .width('100%')
            .margin({ bottom: AppSpace.Xxs })

            Text('模拟器用 http://10.0.2.2:3000，真机请填电脑局域网 IP')
              .fontSize(10)
              .fontColor($r('sys.color.font_tertiary'))
              .margin({ bottom: AppSpace.Xxs })
          }

          // 登录按钮
          Text(this.loading ? '登录中…' : '进 入 工 作 台')
            .fontSize(AppFont.BodyL)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.OnBrand)
            .textAlign(TextAlign.Center)
            .width('100%')
            .height(46)
            .borderRadius(AppRadius.Pill)
            .backgroundColor(AppColor.Brand)
            .opacity(this.loading ? 0.6 : 1)
            .margin({ top: AppSpace.Sm })
            .onClick(() => {
              if (!this.loading) {
                this.doLogin()
              }
            })

          Text('演示账号 admin / admin123')
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
            .margin({ top: AppSpace.Sm })
        }
        .width('100%')
        .padding(AppSpace.Lg)
        .borderRadius(AppRadius.Xl)
        .backgroundColor($r('sys.color.comp_background_primary'))
      }
      .padding({
        left: 28,
        right: 28,
        top: WindowUtils.getStatusBarHeightVp(),
        bottom: WindowUtils.getBottomSafeVp()
      })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}
