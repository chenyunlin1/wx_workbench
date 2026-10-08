import { Theme } from '../common/Theme'
import { HomeTab } from './tabs/HomeTab'
import { NotesTab } from './tabs/NotesTab'
import { LearningTab } from './tabs/LearningTab'
import { AiTab } from './tabs/AiTab'
import { ProfileTab } from './tabs/ProfileTab'
import { SchedulesPage } from './feature/SchedulesPage'
import { HabitsPage } from './feature/HabitsPage'
import { WorkoutPage } from './feature/WorkoutPage'
import { FinancePage } from './feature/FinancePage'
import { CollectionPage } from './feature/CollectionPage'
import { InterviewsPage } from './feature/InterviewsPage'
import { PracticePage } from './feature/PracticePage'
import { ShoppingPage } from './feature/ShoppingPage'
import { UsersPage } from './feature/UsersPage'
import { KnowledgeDetailPage } from './feature/KnowledgeDetailPage'

/**
 * tabBar 的自定义构建参数。
 * 必须以对象字面量按引用传入：@Builder 按值传参时状态变量变化不会刷新子树，
 * 选中态就会永远停在初始值上。
 */
interface TabBarItemParam {
  index: number
  icon: string
  label: string
  activeIndex: number
}

@Component
export struct MainPage {
  @Provide('nav') nav: NavPathStack = new NavPathStack()
  @StorageLink('navBarHeight') navBarHeight: number = 0
  @State currentTab: number = 0

  @Builder
  tabBarItem(item: TabBarItemParam) {
    Column() {
      Column({ space: 3 }) {
        Text(item.icon)
          .fontSize(20)
          .opacity(item.activeIndex === item.index ? 1 : 0.45)
        Text(item.label)
          .fontSize(10)
          .fontWeight(item.activeIndex === item.index ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(item.activeIndex === item.index ? Theme.CYAN : Theme.TEXT_FAINT)
      }
      .width('100%')
      .height(58)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  PageMap(name: string, param: object) {
    if (name === 'schedules') {
      SchedulesPage()
    } else if (name === 'habits') {
      HabitsPage()
    } else if (name === 'workout') {
      WorkoutPage()
    } else if (name === 'finance') {
      FinancePage()
    } else if (name === 'collection') {
      CollectionPage()
    } else if (name === 'interviews') {
      InterviewsPage()
    } else if (name === 'practice') {
      PracticePage()
    } else if (name === 'shopping') {
      ShoppingPage()
    } else if (name === 'users') {
      UsersPage()
    } else if (name === 'knowledgeDetail') {
      KnowledgeDetailPage()
    }
  }

  build() {
    Navigation(this.nav) {
      Tabs({ barPosition: BarPosition.End, index: $$this.currentTab }) {
        TabContent() {
          HomeTab()
        }
        .tabBar(this.tabBarItem({ index: 0, icon: '🏠', label: '首页', activeIndex: this.currentTab }))

        TabContent() {
          NotesTab()
        }
        .tabBar(this.tabBarItem({ index: 1, icon: '📝', label: '备忘', activeIndex: this.currentTab }))

        TabContent() {
          LearningTab()
        }
        .tabBar(this.tabBarItem({ index: 2, icon: '📚', label: '学习', activeIndex: this.currentTab }))

        TabContent() {
          AiTab()
        }
        .tabBar(this.tabBarItem({ index: 3, icon: '🤖', label: 'AI', activeIndex: this.currentTab }))

        TabContent() {
          ProfileTab()
        }
        .tabBar(this.tabBarItem({ index: 4, icon: '👤', label: '我的', activeIndex: this.currentTab }))
      }
      .scrollable(true)
      // 栏高加上手势条避让高度：Tab 栏底色一直铺到屏幕底，底部整块一个颜色
      .barHeight(58 + this.navBarHeight)
      .barBackgroundColor(Theme.TAB_BAR)
      .width('100%')
      .height('100%')
    }
    .navDestination(this.PageMap)
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
