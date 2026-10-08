import { confirm, Fmt, toast } from '../../common/AppKit'
import { Api, UserPayload } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { Session } from '../../store/Session'
import { User } from '../../model/Models'
import { EmptyView, OptionChips, PAGE_PAD_H, PAGE_SCROLL_BOTTOM, PageHeader, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, TechCard } from '../../components/Ui'

@Component
export struct UsersPage {
  @Consume('nav') nav: NavPathStack
  @State users: User[] = []
  @State refreshing: boolean = false
  @State loading: boolean = true
  @State showForm: boolean = false
  @State formUsername: string = ''
  @State formPassword: string = ''
  @State formRoleIndex: number = 0
  @State saving: boolean = false

  aboutToAppear(): void {
    this.reload()
  }

  reload(): void {
    Api.listUsers().then((list) => {
      this.users = list
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载失败')
    }).finally(() => {
      this.loading = false
      this.refreshing = false
    })
  }

  openCreate(): void {
    this.formUsername = ''
    this.formPassword = ''
    this.formRoleIndex = 0
    this.showForm = true
  }

  saveForm(): void {
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

  removeUser(user: User): void {
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
    NavDestination() {
    Stack() {
      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column() {
            PageHeader({ title: '用户管理', actionLabel: '＋ 新用户', onAction: (): void => {
              this.openCreate()
            } })

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
                      Row({ space: 12 }) {
                        Text(user.username.substring(0, 1).toUpperCase())
                          .fontSize(16)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#FFFFFF')
                          .width(40)
                          .height(40)
                          .textAlign(TextAlign.Center)
                          .borderRadius(20)
                          .linearGradient({ angle: 135, colors: user.role === 'admin' ? Theme.VIOLET_COLORS : Theme.BRAND_COLORS })
                        Column({ space: 3 }) {
                          Row({ space: 8 }) {
                            Text(user.username)
                              .fontSize(15)
                              .fontWeight(FontWeight.Bold)
                              .fontColor(Theme.TEXT)
                            Text(user.role === 'admin' ? '管理员' : '成员')
                              .fontSize(9)
                              .fontColor(user.role === 'admin' ? Theme.WARN : Theme.MINT)
                              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                              .borderRadius(999)
                              .border({ width: 1, color: user.role === 'admin' ? Theme.WARN : Theme.MINT })
                          }
                          if (user.createdAt !== undefined) {
                            Text('注册于 ' + Fmt.shortDate(user.createdAt))
                              .fontSize(10)
                              .fontColor(Theme.TEXT_FAINT)
                          }
                        }
                        .alignItems(HorizontalAlign.Start)
                        .layoutWeight(1)
                        if (user.id !== (Session.user === null ? -1 : Session.user.id)) {
                          Text('删除')
                            .fontSize(12)
                            .fontColor(Theme.DANGER)
                            .onClick(() => {
                              this.removeUser(user)
                            })
                        } else {
                          Text('我')
                            .fontSize(11)
                            .fontColor(Theme.CYAN)
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
    .backgroundColor(Theme.BG)
    .bindSheet($$this.showForm, this.formBuilder(), {
      height: 440,
      dragBar: true,
      backgroundColor: Theme.CARD_SOLID
    })
    }
    .hideTitleBar(true)
    .backgroundColor(Theme.BG)
  }

  @Builder
  formBuilder() {
    Column() {
      SheetHeader({ title: '新建用户' })

      Text('用户名').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
      TextInput({ placeholder: '用户名', text: this.formUsername })
        .fontColor(Theme.TEXT)
        .fontSize(14)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .border({ width: 1, color: Theme.BORDER })
        .height(42)
        .align(Alignment.Start)
        .onChange((value: string) => {
          this.formUsername = value
        })

      Text('密码').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
      TextInput({ placeholder: '密码', text: this.formPassword })
        .fontColor(Theme.TEXT)
        .fontSize(14)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .border({ width: 1, color: Theme.BORDER })
        .height(42)
        .align(Alignment.Start)
        .type(InputType.Password)
        .onChange((value: string) => {
          this.formPassword = value
        })

      Text('角色').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 12, bottom: 6 })
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
