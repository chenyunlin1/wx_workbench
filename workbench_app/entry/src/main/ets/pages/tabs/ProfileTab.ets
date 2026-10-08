import { toast, Fmt } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { Session } from '../../store/Session'
import { SectionTitle, TechCard } from '../../components/Ui'

@Component
export struct ProfileTab {
  @Consume('topInset') topInset: number
  @Consume('nav') nav: NavPathStack
  @State showServer: boolean = false
  @State serverInput: string = Session.serverUrl
  @State testing: boolean = false

  saveServer(): void {
    const url = this.serverInput.trim()
    if (url.length === 0) {
      toast('服务器地址不能为空')
      return
    }
    Session.setServerUrl(url)
    toast('服务器地址已保存')
  }

  testServer(): void {
    this.testing = true
    Api.getProfile().then(() => {
      toast('✅ 连接成功，登录状态有效')
    }).catch((err: Object) => {
      const msg = err instanceof Error ? err.message : '连接失败'
      toast('❌ ' + msg)
    }).finally(() => {
      this.testing = false
    })
  }

  logout(): void {
    Session.logout(false)
    toast('已退出登录')
  }

  @Builder
  menuItem(icon: string, label: string, detail: string, onTap: () => void) {
    Row({ space: 12 }) {
      Text(icon)
        .fontSize(18)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .borderRadius(12)
        .backgroundColor(Theme.INPUT_BG)
        .border({ width: 1, color: Theme.BORDER })
      Text(label)
        .fontSize(14)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)
      Text(detail)
        .fontSize(11)
        .fontColor(Theme.TEXT_FAINT)
        .maxLines(1)
      Text('›')
        .fontSize(16)
        .fontColor(Theme.TEXT_FAINT)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .onClick(() => {
      onTap()
    })
  }

  build() {
    Scroll() {
      Column() {
        // 用户卡片
        TechCard({ radius: 20, mb: 16 }) {
          Row({ space: 14 }) {
            Text(Session.username().substring(0, 1).toUpperCase())
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .width(58)
              .height(58)
              .textAlign(TextAlign.Center)
              .borderRadius(29)
              .linearGradient({ angle: 135, colors: Theme.BRAND_COLORS })
              .shadow({ radius: 14, color: '#553B82F6' })
            Column({ space: 5 }) {
              Text(Session.username())
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT)
              Row({ space: 8 }) {
                Text(Session.isAdmin() ? '管理员' : '成员')
                  .fontSize(10)
                  .fontColor(Session.isAdmin() ? Theme.WARN : Theme.MINT)
                  .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                  .borderRadius(999)
                  .border({ width: 1, color: Session.isAdmin() ? Theme.WARN : Theme.MINT })
                if (Session.user !== null && Session.user.createdAt !== undefined) {
                  Text('注册于 ' + Fmt.shortDate(Session.user.createdAt))
                    .fontSize(10)
                    .fontColor(Theme.TEXT_FAINT)
                }
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
        }

        // 通用设置
        TechCard({ mb: 16 }) {
          Column() {
            SectionTitle({ title: '通用' })
            this.menuItem('🌐', '服务器地址', Session.serverUrl, () => {
              this.serverInput = Session.serverUrl
              this.showServer = !this.showServer
            })
            if (this.showServer) {
              Column({ space: 8 }) {
                TextInput({ text: this.serverInput })
                  .fontColor(Theme.TEXT)
                  .fontSize(13)
                  .backgroundColor(Theme.INPUT_BG)
                  .borderRadius(10)
                  .border({ width: 1, color: Theme.BORDER })
                  .height(42)
                  .align(Alignment.Start)
                  .onChange((value: string) => {
                    this.serverInput = value
                  })
                Text('模拟器填 http://10.0.2.2:3000；真机填电脑局域网 IP，如 http://192.168.0.104:3000')
                  .fontSize(10)
                  .fontColor(Theme.TEXT_FAINT)
                  .width('100%')
                Row({ space: 10 }) {
                  Text('保存地址')
                    .fontSize(13)
                    .fontColor('#FFFFFF')
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                    .height(40)
                    .borderRadius(12)
                    .linearGradient({ angle: 135, colors: Theme.BRAND_COLORS })
                    .onClick(() => {
                      this.saveServer()
                    })
                  Text('测试连接')
                    .fontSize(13)
                    .fontColor(Theme.CYAN)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                    .height(40)
                    .borderRadius(12)
                    .border({ width: 1, color: Theme.CYAN })
                    .onClick(() => {
                      if (!this.testing) {
                        this.testServer()
                      }
                    })
                }
                .width('100%')
              }
              .width('100%')
              .padding({ bottom: 8 })
            }
            if (Session.isAdmin()) {
              Divider().color(Theme.BORDER).margin({ top: 4, bottom: 4 })
              this.menuItem('👥', '用户管理', '仅管理员', () => {
                this.nav.pushPathByName('users', null)
              })
            }
          }
          .width('100%')
        }

        // 关于
        TechCard({ mb: 24 }) {
          Column() {
            SectionTitle({ title: '关于' })
            this.menuItem('ℹ️', '版本', 'LifeOS 工作台 v1.0.0', () => {
              toast('LifeOS 工作台 · 鸿蒙客户端')
            })
            this.menuItem('🔗', '配套后端', 'NestJS + MySQL', () => {
              toast('请确保后端已启动且可达')
            })
          }
          .width('100%')
        }

        // 退出登录
        Text('退出登录')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.DANGER)
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(48)
          .borderRadius(16)
          .border({ width: 1, color: Theme.DANGER })
          .onClick(() => {
            this.logout()
          })
      }
      .padding({ left: 16, right: 16, top: this.topInset + 16, bottom: 30 })
      .constraintSize({ minHeight: '100%' })
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }
}
