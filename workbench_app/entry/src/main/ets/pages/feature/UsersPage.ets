import { confirm, Fmt, toast } from '../../common/AppKit'
import { Api, UserPayload } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { AppColor, AppFont, AppMaterial, AppRadius, AppSpace } from '../../theme/Theme'
import { Session } from '../../store/Session'
import { User } from '../../model/Models'
import { EmptyView, OptionChips, PAGE_PAD_H, PAGE_SCROLL_BOTTOM, PageHeader, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, TechCard } from '../../components/Ui'

@ComponentV2
export struct UsersPage {
  @Param nav: NavPathStack = new NavPathStack();
  @Local users: User[] = []
  @Local refreshing: boolean = false
  @Local loading: boolean = true
  @Local showForm: boolean = false
  @Local formUsername: string = ''
  @Local formPassword: string = ''
  @Local formRoleIndex: number = 0
  @Local saving: boolean = false

  aboutToAppear(): void {
    this.reload()
  }

  private reload(): void {
    Api.listUsers().then((list: User[]) => {
      this.users = list
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载失败')
    }).finally(() => {
      this.loading = false
      this.refreshing = false
    })
  }

  private openCreate(): void {
    this.formUsername = ''
    this.formPassword = ''
    this.formRoleIndex = 0
    this.showForm = true
  }

  private saveForm(): void {
    if (this.formUsername.trim().length === 0 || this.formPassword.length === 0) {
      toast('请填写用户名和密码')
      return
    }
    const payload: UserPayload = {
      username: this.formUsername.trim(),
      password: this.formPassword,
      role: this.formRoleIndex === 0 ? 'user' : 'admin'
    }
    this.saving = true
    Api.createUser(payload).then(() => {
      toast('用户已创建')
      this.showForm = false
      this.reload()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '创建失败')
    }).finally(() => {
      this.saving = false
    })
  }

  private removeUser(user: User): void {
    if (user.id === (Session.user === null ? -1 : Session.user.id)) {
      toast('不能删除自己')
      return
    }
    confirm('确定删除用户 ' + user.username + ' ？', () => {
      Api.deleteUser(user.id).then(() => {
        toast('已删除')
        this.reload()
      }).catch((err: Object) => {
        toast(err instanceof Error ? err.message : '删除失败')
      })
    })
  }

  build() {
    Stack() {
      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column() {
            PageHeader({
              navStack: this.nav,
              title: '用户管理',
              actionLabel: '＋ 新用户',
              onAction: (): void => {
                this.openCreate()
              }
            })

            if (this.loading) {
              EmptyView({ icon: '⏳', text: '加载中…' })
            } else if (this.users.length === 0) {
              EmptyView({ icon: '👥', text: '暂无用户' })
            } else {
              List() {
                ForEach(this.users, (user: User) => {
                  ListItem() {
                    Column() {
                      TechCard() {
                        Row({ space: AppSpace.Sm }) {
                          // 头像圆标
                          Text(user.username.substring(0, 1).toUpperCase())
                            .fontSize(AppFont.BodyL)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(AppColor.OnBrand)
                            .width(40)
                            .height(40)
                            .textAlign(TextAlign.Center)
                            .borderRadius(20)
                            .backgroundColor(user.role === 'admin' ? AppColor.BrandDark : AppColor.Brand)
                          Column({ space: 3 }) {
                            Row({ space: 8 }) {
                              Text(user.username)
                                .fontSize(15)
                                .fontWeight(FontWeight.Bold)
                                .fontColor($r('sys.color.font_primary'))
                              Text(user.role === 'admin' ? '管理员' : '成员')
                                .fontSize(9)
                                .fontColor(user.role === 'admin' ? Theme.WARN : AppColor.Brand)
                                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                                .borderRadius(AppRadius.Pill)
                                .border({ width: 1, color: user.role === 'admin' ? Theme.WARN : AppColor.Brand })
                            }
                            if (user.createdAt !== undefined) {
                              Text('注册于 ' + Fmt.shortDate(user.createdAt))
                                .fontSize(10)
                                .fontColor($r('sys.color.font_tertiary'))
                            }
                          }
                          .alignItems(HorizontalAlign.Start)
                          .layoutWeight(1)
                          if (user.id !== (Session.user === null ? -1 : Session.user.id)) {
                            Text('删除')
                              .fontSize(AppFont.Caption)
                              .fontColor(Theme.DANGER)
                              .onClick(() => {
                                this.removeUser(user)
                              })
                          } else {
                            Text('我')
                              .fontSize(11)
                              .fontColor(AppColor.Brand)
                          }
                        }
                        .width('100%')
                      }
                    }
                    .width('100%')
                    .margin({ bottom: 10 })
                  }
                }, (user: User) => user.id.toString())
              }
              .width('100%')
              .layoutWeight(1)
              .padding({ bottom: 44 })
              .scrollBar(BarState.Off)
            }
          }
          .width('100%')
          .height('100%')
          .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H, bottom: PAGE_SCROLL_BOTTOM })
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
      .onRefreshing(() => {
        this.reload()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .bindSheet($$this.showForm, this.formBuilder(), {
      height: 440,
      dragBar: true,
      preferType: SheetType.BOTTOM,
      backgroundColor: AppMaterial.SheetBackground,
      blurStyle: AppMaterial.SheetBlur,
      systemMaterial: AppMaterial.Sheet
    })
  }

  @Builder
  formBuilder() {
    Column() {
      SheetHeader({ title: '新建用户' })

      Text('用户名').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
      TextInput({ placeholder: '用户名', text: this.formUsername })
        .placeholderColor($r('sys.color.font_tertiary'))
        .fontColor($r('sys.color.font_primary'))
        .fontSize(AppFont.Body)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(AppRadius.Md)
        .height(42)
        .align(Alignment.Start)
        .onChange((value: string) => {
          this.formUsername = value
        })

      Text('密码').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
      TextInput({ placeholder: '密码', text: this.formPassword })
        .placeholderColor($r('sys.color.font_tertiary'))
        .fontColor($r('sys.color.font_primary'))
        .fontSize(AppFont.Body)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(AppRadius.Md)
        .height(42)
        .align(Alignment.Start)
        .type(InputType.Password)
        .onChange((value: string) => {
          this.formPassword = value
        })

      Text('角色').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
      OptionChips({
        options: ['成员', '管理员'],
        selected: this.formRoleIndex,
        onSelect: (index: number) => {
          this.formRoleIndex = index
        }
      })

      SheetSubmit({
        label: this.saving ? '创建中…' : '创 建',
        busy: this.saving,
        onSubmit: (): void => {
          this.saveForm()
        }
      })
    }
    .padding({
      left: PAGE_PAD_H,
      right: PAGE_PAD_H,
      top: SHEET_PAD_TOP,
      bottom: SHEET_PAD_BOTTOM
    })
  }
}
