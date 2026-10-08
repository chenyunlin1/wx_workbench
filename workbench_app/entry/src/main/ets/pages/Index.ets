import { Theme } from '../common/Theme'
import { LoginPage } from './LoginPage'
import { MainPage } from './MainPage'

/**
 * 应用入口：根据登录状态切换登录页 / 主页面。
 * Session.init 在 EntryAbility.onCreate 中完成。
 * 根容器不做任何避让 padding（保持状态栏透明、内容可滚动到其下），
 * 各页面通过 @Consume 的 topInset / bottomInset 自行预留空间。
 */
@Entry
@Component
struct Index {
  @StorageLink('hasToken') hasToken: boolean = false
  @StorageLink('statusBarHeight') @Watch('applyInsets') statusBarHeight: number = 0
  @StorageLink('navBarHeight') @Watch('applyInsets') navBarHeight: number = 0
  @StorageLink('colorMode') @Watch('onModeChange') colorMode: string = 'dark'
  @Provide('topInset') topInset: number = 0
  @Provide('bottomInset') bottomInset: number = 0
  @State ready: boolean = false

  aboutToAppear(): void {
    this.applyInsets()
    setTimeout(() => {
      this.ready = true
    }, 500)
  }

  applyInsets(): void {
    this.topInset = this.statusBarHeight
    this.bottomInset = this.navBarHeight
  }

  /** 系统深浅色切换：重建整棵组件树，让所有页面按新主题取色 */
  onModeChange(): void {
    this.ready = false
    setTimeout(() => {
      this.ready = true
    }, 50)
  }

  @Builder
  splash() {
    Column({ space: 14 }) {
      Text('◈')
        .fontSize(52)
        .fontColor(Theme.CYAN)
        .shadow({ radius: 24, color: '#8822D3EE' })
      Text('LifeOS 工作台')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .letterSpacing(3)
      Text('LOADING…')
        .fontSize(10)
        .fontColor(Theme.TEXT_FAINT)
        .letterSpacing(4)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack() {
      if (!this.ready) {
        this.splash()
      } else if (this.hasToken) {
        MainPage()
      } else {
        LoginPage()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
