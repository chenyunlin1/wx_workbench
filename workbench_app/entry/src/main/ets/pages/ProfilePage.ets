import { HdsCompat } from '../utils/HdsCompat';
import { AppColor, AppFont, AppRadius, AppSpace, HomeTheme } from '../theme/Theme';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { WindowUtils } from '../utils/WindowUtils';
import { Session, SessionStore } from '../store/Session';
import { Api } from '../api/Api';
import { Fmt, toast } from '../common/AppKit';

class ProfileItem {
  icon: Resource;
  label: ResourceStr;
  id: string;
  iconBg: ResourceColor;
  adminOnly: boolean;

  constructor(icon: Resource, label: ResourceStr, id: string, iconBg: ResourceColor, adminOnly: boolean = false) {
    this.icon = icon;
    this.label = label;
    this.id = id;
    this.iconBg = iconBg;
    this.adminOnly = adminOnly;
  }
}

const SYSTEM_ITEMS: ProfileItem[] = [
  new ProfileItem($r('sys.symbol.gearshape'), $r('app.string.settings_title'), 'settings', '#8E8E93'),
  new ProfileItem($r('sys.symbol.person_2'), '用户管理', 'users', '#0A59F7', true),
  new ProfileItem($r('sys.symbol.wifi_router'), '服务器地址', 'server', '#34C759')
];

const SUPPORT_ITEMS: ProfileItem[] = [
  new ProfileItem($r('sys.symbol.info_circle'), $r('app.string.about_title'), 'about', '#0A59F7'),
  new ProfileItem($r('sys.symbol.square_grid_2x2'), $r('app.string.app_icon_title'), 'appIcon', AppColor.Brand)
];
const ROW_INDENT: number = AppSpace.Md;
const MINI_TITLE_BAR_HEIGHT: number = 56;
const ICON_SIZE: number = 28;

@ComponentV2
export struct ProfilePage {
  @Param navStack: NavPathStack = new NavPathStack();
  @Event onScrollerReady: (scroller: Scroller) => void = () => {};
  @Local session: SessionStore = Session;
  @Local showServer: boolean = false;
  @Local serverInput: string = Session.serverUrl;
  @Local testing: boolean = false;

  private scrollScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.onScrollerReady(this.scrollScroller);
  }

  private onItemTap(id: string): void {
    if (id === 'settings') {
      this.navStack.pushPathByName('settings', '');
    } else if (id === 'appIcon') {
      this.navStack.pushPathByName('appIcon', '');
    } else if (id === 'about') {
      this.navStack.pushPathByName('about', '');
    } else if (id === 'users') {
      this.navStack.pushPathByName('users', null);
    } else if (id === 'server') {
      this.serverInput = Session.serverUrl;
      this.showServer = !this.showServer;
    }
  }

  private saveServer(): void {
    const url = this.serverInput.trim();
    if (url.length === 0) {
      toast('服务器地址不能为空');
      return;
    }
    Session.setServerUrl(url);
    toast('服务器地址已保存');
  }

  private testServer(): void {
    this.testing = true;
    Api.getProfile().then(() => {
      toast('✅ 连接成功，登录状态有效');
    }).catch((err: Object) => {
      const msg = err instanceof Error ? err.message : '连接失败';
      toast('❌ ' + msg);
    }).finally(() => {
      this.testing = false;
    });
  }

  private logout(): void {
    Session.logout(false);
    toast('已退出登录');
  }

  private visibleItems(items: ProfileItem[]): ProfileItem[] {
    if (Session.isAdmin()) {
      return items;
    }
    return items.filter((item: ProfileItem): boolean => !item.adminOnly);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            [HomeTheme.BgWarmTop, 0.0],
            [HomeTheme.BgWarmMid, 0.35],
            [HomeTheme.BgNeutral, 1.0]
          ]
        })

      HdsNavigation() {
        Scroll(this.scrollScroller) {
          Column({ space: AppSpace.Lg }) {
            this.buildUserCard()
            this.buildGroup(this.visibleItems(SYSTEM_ITEMS))
            this.buildGroup(this.visibleItems(SUPPORT_ITEMS))
            this.buildLogoutRow()
          }
          .width('100%')
          .padding({
            left: AppSpace.Md,
            right: AppSpace.Md,
            top: WindowUtils.getStatusBarHeightVp() + MINI_TITLE_BAR_HEIGHT + AppSpace.Sm,
            bottom: WindowUtils.getFloatingTabBottomVp()
          })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .backgroundColor(Color.Transparent)
        .align(Alignment.Top)
      }
      .mode(NavigationMode.Stack)
      .titleBar({
        avoidLayoutSafeArea: true,
        content: {
          title: {
            mainTitle: $r('app.string.tab_profile')
          }
        },
        style: {
          scrollEffectOpts: {
            scrollEffectType: HdsCompat.scrollEffect
          },
          originalStyle: {
            backgroundStyle: {
              backgroundColor: Color.Transparent
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: $r('sys.color.font_primary')
              }
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: Color.Transparent
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: $r('sys.color.font_primary')
              }
            }
          },
          systemMaterialEffect: HdsCompat.material
        }
      })
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .bindToScrollable([this.scrollScroller])
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  buildUserCard() {
    Row({ space: AppSpace.Sm }) {
      Text(Session.username().length > 0 ? Session.username().substring(0, 1).toUpperCase() : '?')
        .fontSize(AppFont.TitleL)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.OnBrand)
        .width(48)
        .height(48)
        .textAlign(TextAlign.Center)
        .borderRadius(24)
        .backgroundColor(AppColor.Brand)
      Column({ space: AppSpace.Xxs }) {
        Text(Session.username())
          .fontSize(AppFont.Title)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Row({ space: AppSpace.Xs }) {
          Text(Session.isAdmin() ? '管理员' : '成员')
            .fontSize(10)
            .fontColor(Session.isAdmin() ? AppColor.BrandDark : $r('sys.color.font_secondary'))
            .padding({ left: AppSpace.Xs, right: AppSpace.Xs, top: 2, bottom: 2 })
            .borderRadius(AppRadius.Pill)
            .border({
              width: 1,
              color: Session.isAdmin() ? AppColor.BrandDark : $r('sys.color.font_tertiary')
            })
          if (Session.user !== null && Session.user.createdAt !== undefined) {
            Text('注册于 ' + Fmt.shortDate(Session.user.createdAt))
              .fontSize(10)
              .fontColor($r('sys.color.font_tertiary'))
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(ROW_INDENT)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(AppRadius.Lg)
  }

  @Builder
  buildGroup(items: ProfileItem[]) {
    Column() {
      ForEach(items, (item: ProfileItem, index: number) => {
        this.buildRow(item)
        if (index < items.length - 1) {
          Divider()
            .strokeWidth(0.5)
            .color($r('sys.color.comp_divider'))
            .margin({ left: ROW_INDENT + ICON_SIZE + AppSpace.Sm })
        }
      }, (item: ProfileItem) => item.id)
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(AppRadius.Lg)
  }

  @Builder
  buildRow(item: ProfileItem) {
    Column() {
      Row({ space: AppSpace.Sm }) {
        Stack() {
          SymbolGlyph(item.icon)
            .fontSize(18)
            .fontColor([Color.White])
        }
        .width(ICON_SIZE)
        .height(ICON_SIZE)
        .backgroundColor(item.iconBg)
        .borderRadius(7)

        Text(item.label)
          .fontSize(AppFont.BodyL)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)

        if (item.id === 'server') {
          Text(Session.serverUrl)
            .fontSize(AppFont.Caption)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: '45%' })
        }

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(24)
          .width(24)
          .height(24)
          .fontColor([$r('sys.color.font_tertiary')])
      }
      .width('100%')
      .padding({
        left: ROW_INDENT,
        right: ROW_INDENT,
        top: AppSpace.Sm,
        bottom: AppSpace.Sm
      })
      .constraintSize({ minHeight: 56 })
      .onClick(() => this.onItemTap(item.id))

      if (item.id === 'server' && this.showServer) {
        Column({ space: AppSpace.Xs }) {
          TextInput({ text: this.serverInput })
            .fontColor($r('sys.color.font_primary'))
            .fontSize(AppFont.Body)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(AppRadius.Md)
            .height(42)
            .align(Alignment.Start)
            .onChange((value: string) => {
              this.serverInput = value
            })
          Text('模拟器填 http://10.0.2.2:3000；真机填电脑局域网 IP')
            .fontSize(10)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
          Row({ space: AppSpace.Xs }) {
            Text('保存地址')
              .fontSize(AppFont.Body)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.OnBrand)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .height(40)
              .borderRadius(AppRadius.Pill)
              .backgroundColor(AppColor.Brand)
              .onClick(() => {
                this.saveServer()
              })
            Text('测试连接')
              .fontSize(AppFont.Body)
              .fontColor(AppColor.Brand)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .height(40)
              .borderRadius(AppRadius.Pill)
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .onClick(() => {
                if (!this.testing) {
                  this.testServer()
                }
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: ROW_INDENT, right: ROW_INDENT, bottom: AppSpace.Sm })
      }
    }
    .width('100%')
  }

  @Builder
  buildLogoutRow() {
    Row({ space: AppSpace.Sm }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.power'))
          .fontSize(18)
          .fontColor([Color.White])
      }
      .width(ICON_SIZE)
      .height(ICON_SIZE)
      .backgroundColor('#FF3B30')
      .borderRadius(7)

      Text('退出登录')
        .fontSize(AppFont.BodyL)
        .fontColor(AppColor.Danger)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({
      left: ROW_INDENT,
      right: ROW_INDENT,
      top: AppSpace.Sm,
      bottom: AppSpace.Sm
    })
    .constraintSize({ minHeight: 56 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(AppRadius.Lg)
    .onClick(() => this.logout())
  }
}
