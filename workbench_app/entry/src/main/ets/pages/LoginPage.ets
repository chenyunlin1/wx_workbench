import { promptAction } from '@kit.ArkUI'
import { Api } from '../api/Api'
import { toast } from '../common/AppKit'
import { Theme } from '../common/Theme'
import { Session } from '../store/Session'
import { TechBackground } from '../components/Ui'

@Component
export struct LoginPage {
  @Consume('topInset') topInset: number
  @Consume('bottomInset') bottomInset: number
  @State username: string = 'admin'
  @State password: string = ''
  @State serverUrl: string = Session.serverUrl
  @State loading: boolean = false
  @State showServer: boolean = false

  async doLogin(): Promise<void> {
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

  saveServer(): void {
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

      // 装饰光晕
      Column()
        .width(260)
        .height(260)
        .borderRadius(130)
        .backgroundColor('#263B82F6')
        .blur(60)
        .position({ x: -60, y: 80 })
      Column()
        .width(220)
        .height(220)
        .borderRadius(110)
        .backgroundColor('#2634E1B5')
        .blur(60)
        .position({ x: 240, y: 480 })

      Column({ space: 0 }) {
        // Logo 与标题
        Column({ space: 10 }) {
          Text('◈')
            .fontSize(44)
            .fontColor(Theme.CYAN)
            .shadow({ radius: 20, color: '#8822D3EE' })
          Text('LifeOS 工作台')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .letterSpacing(2)
          Text('LIFE · WORK · DATA · SYNC')
            .fontSize(11)
            .fontColor(Theme.TEXT_FAINT)
            .letterSpacing(4)
        }
        .margin({ bottom: 36 })

        // 登录卡片
        Column() {
          Text('账号登录')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .margin({ bottom: 16 })

          TextInput({ placeholder: '用户名', text: this.username })
            .placeholderColor(Theme.TEXT_FAINT)
            .fontColor(Theme.TEXT)
            .backgroundColor(Theme.INPUT_BG)
            .borderRadius(12)
            .border({ width: 1, color: Theme.BORDER })
            .height(46)
            .align(Alignment.Start)
            .margin({ bottom: 12 })
            .onChange((value: string) => {
              this.username = value
            })

          TextInput({ placeholder: '密码', text: this.password })
            .placeholderColor(Theme.TEXT_FAINT)
            .fontColor(Theme.TEXT)
            .backgroundColor(Theme.INPUT_BG)
            .borderRadius(12)
            .border({ width: 1, color: Theme.BORDER })
            .height(46)
            .align(Alignment.Start)
            .type(InputType.Password)
            .margin({ bottom: 8 })
            .onChange((value: string) => {
              this.password = value
            })
            .onSubmit(() => {
              this.doLogin()
            })

          Row() {
            Text('服务器：' + this.serverUrl)
              .fontSize(11)
              .fontColor(Theme.TEXT_FAINT)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text('修改')
              .fontSize(11)
              .fontColor(Theme.CYAN)
              .onClick(() => {
                this.showServer = !this.showServer
              })
          }
          .width('100%')
          .margin({ top: 6, bottom: 4 })

          if (this.showServer) {
            Row({ space: 8 }) {
              TextInput({ text: this.serverUrl })
                .placeholderColor(Theme.TEXT_FAINT)
                .fontColor(Theme.TEXT)
                .fontSize(12)
                .backgroundColor(Theme.INPUT_BG)
                .borderRadius(10)
                .border({ width: 1, color: Theme.BORDER })
                .height(38)
                .align(Alignment.Start)
                .layoutWeight(1)
                .onChange((value: string) => {
                  this.serverUrl = value
                })
              Text('保存')
                .fontSize(12)
                .fontColor('#FFFFFF')
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .borderRadius(10)
                .backgroundColor(Theme.PRIMARY)
                .onClick(() => {
                  this.saveServer()
                })
            }
            .width('100%')
            .margin({ bottom: 4 })

            Text('模拟器用 http://10.0.2.2:3000，真机请填电脑局域网 IP')
              .fontSize(10)
              .fontColor(Theme.TEXT_FAINT)
              .margin({ bottom: 4 })
          }

          // 登录按钮
          Text(this.loading ? '登录中…' : '进 入 工 作 台')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .width('100%')
            .height(46)
            .borderRadius(12)
            .linearGradient({ angle: 135, colors: Theme.BRAND_COLORS })
            .shadow({ radius: 14, color: '#553B82F6', offsetY: 4 })
            .margin({ top: 12 })
            .onClick(() => {
              if (!this.loading) {
                this.doLogin()
              }
            })

          Text('演示账号 admin / admin123')
            .fontSize(11)
            .fontColor(Theme.TEXT_FAINT)
            .margin({ top: 14 })
        }
        .width('100%')
        .padding(20)
        .borderRadius(20)
        .linearGradient({ angle: 180, colors: Theme.CARD_COLORS })
        .border({ width: 1, color: Theme.BORDER })
        .shadow({ radius: 30, color: '#55000000', offsetY: 10 })
      }
      .padding({ left: 28, right: 28, top: this.topInset, bottom: this.bottomInset })
      .justifyContent(FlexAlign.Center)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
