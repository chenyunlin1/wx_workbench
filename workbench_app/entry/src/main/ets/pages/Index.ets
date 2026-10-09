import { common } from '@kit.AbilityKit';
import { MainPage } from './MainPage';
import { LoginPage } from './LoginPage';
import { SettingsPage } from './SettingsPage';
import { AppIconPage } from './AppIconPage';
import { AboutPage } from './AboutPage';
import { GuidePage } from './GuidePage';
import { PrivacyPage } from './PrivacyPage';
import { CompliancePage } from './CompliancePage';
import { OpenSourcePage } from './OpenSourcePage';
import { SchedulesPage } from './feature/SchedulesPage';
import { HabitsPage } from './feature/HabitsPage';
import { WorkoutPage } from './feature/WorkoutPage';
import { FinancePage } from './feature/FinancePage';
import { CollectionPage } from './feature/CollectionPage';
import { InterviewsPage } from './feature/InterviewsPage';
import { PracticePage } from './feature/PracticePage';
import { ShoppingPage } from './feature/ShoppingPage';
import { UsersPage } from './feature/UsersPage';
import { KnowledgeDetailPage } from './feature/KnowledgeDetailPage';
import { ProfileMenuDestination } from '../components/ProfileMenuDestination';
import { WindowUtils } from '../utils/WindowUtils';
import { PlatformCompat } from '../utils/PlatformCompat';
import { Session, SessionStore } from '../store/Session';
import { Api } from '../api/Api';
import { User } from '../model/Models';

@Entry
@ComponentV2
struct Index {
  @Local navStack: NavPathStack = new NavPathStack();
  @Local session: SessionStore = Session;

  aboutToAppear(): void {
    // 先 push home 作为栈底，保证栈不空。
    if (this.navStack.size() === 0) {
      this.navStack.pushPathByName('home', null, false);
    }
    // 静默刷新用户资料：其他端改过的昵称/头像能在启动时同步过来
    if (Session.isLoggedIn()) {
      Api.getProfile().then((user: User) => {
        Session.updateUser(user);
      }).catch(() => {
        // 网络异常时保留本地缓存；401 由 Http 层统一提示过期
      });
    }
  }

  /** 登录/退出后重置路由栈，避免旧会话页面残留在新会话里。 */
  @Monitor('session.token')
  onLoginStateChange(): void {
    this.navStack.clear();
    this.navStack.pushPathByName('home', null, false);
  }

  @Builder
  routerMap(name: string, _param: object) {
    if (name === 'home') {
      NavDestination() {
        MainPage({ navStack: this.navStack })
      }
      .hideTitleBar(true)
      .backgroundColor($r('sys.color.background_primary'))
      .systemTransition(NavigationSystemTransitionType.NONE)
      .onBackPressed((): boolean => {
        if (PlatformCompat.desktopWindow) {
          WindowUtils.minimize();
          return true;
        }
        // 根页返回：移到后台而不是 pop，保证退出应用。
        try {
          const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
          ctx.moveAbilityToBackground();
          return true;
        } catch (e) {
          console.error(`[Index] moveAbilityToBackground error: ${e}`);
          return false;
        }
      })
    } else if (name === 'settings') {
      ProfileMenuDestination() {
        SettingsPage({ navStack: this.navStack })
      }
    } else if (name === 'appIcon') {
      ProfileMenuDestination() {
        AppIconPage({ navStack: this.navStack })
      }
    } else if (name === 'about') {
      ProfileMenuDestination() {
        AboutPage({ navStack: this.navStack })
      }
    } else if (name === 'guide') {
      ProfileMenuDestination() {
        GuidePage({ navStack: this.navStack })
      }
    } else if (name === 'privacy') {
      ProfileMenuDestination() {
        PrivacyPage({ navStack: this.navStack })
      }
    } else if (name === 'compliance') {
      ProfileMenuDestination() {
        CompliancePage({ navStack: this.navStack })
      }
    } else if (name === 'openSource') {
      ProfileMenuDestination() {
        OpenSourcePage({ navStack: this.navStack })
      }
    } else if (name === 'schedules') {
      ProfileMenuDestination() {
        SchedulesPage({ nav: this.navStack })
      }
    } else if (name === 'habits') {
      ProfileMenuDestination() {
        HabitsPage({ nav: this.navStack })
      }
    } else if (name === 'workout') {
      ProfileMenuDestination() {
        WorkoutPage({ nav: this.navStack })
      }
    } else if (name === 'finance') {
      ProfileMenuDestination() {
        FinancePage({ nav: this.navStack })
      }
    } else if (name === 'collection') {
      ProfileMenuDestination() {
        CollectionPage({ nav: this.navStack })
      }
    } else if (name === 'interviews') {
      ProfileMenuDestination() {
        InterviewsPage({ nav: this.navStack })
      }
    } else if (name === 'practice') {
      ProfileMenuDestination() {
        PracticePage({ nav: this.navStack })
      }
    } else if (name === 'shopping') {
      ProfileMenuDestination() {
        ShoppingPage({ nav: this.navStack })
      }
    } else if (name === 'users') {
      ProfileMenuDestination() {
        UsersPage({ nav: this.navStack })
      }
    } else if (name === 'knowledgeDetail') {
      ProfileMenuDestination() {
        KnowledgeDetailPage({ nav: this.navStack })
      }
    }
  }

  build() {
    if (this.session.token.length === 0) {
      LoginPage()
    } else {
      Navigation(this.navStack) {
        // home 已在 aboutToAppear 中 push，根内容留空
      }
      .backgroundColor($r('sys.color.background_primary'))
      .navDestination(this.routerMap)
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .width('100%')
      .height('100%')
    }
  }
}
