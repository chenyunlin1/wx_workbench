import { confirm, toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { AppColor, AppFont, AppMaterial, AppRadius, AppSpace } from '../../theme/Theme'
import { Session } from '../../store/Session'
import { ShoppingItem } from '../../model/Models'
import { EmptyView, OptionChips, PAGE_PAD_H, PAGE_SCROLL_BOTTOM, PageHeader, SheetDelete, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, TechCard } from '../../components/Ui'

@ComponentV2
export struct ShoppingPage {
  @Param nav: NavPathStack = new NavPathStack();
  @Local items: ShoppingItem[] = []
  @Local filterIndex: number = 0
  @Local sortIndex: number = 0
  @Local quickName: string = ''
  @Local refreshing: boolean = false
  @Local loading: boolean = true
  @Local showForm: boolean = false
  @Local formId: number = 0
  @Local formName: string = ''
  @Local formPrice: string = ''
  @Local saving: boolean = false

  aboutToAppear(): void {
    this.reload()
  }

  private reload(): void {
    Api.listShopping().then((list: ShoppingItem[]) => {
      this.items = list
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载失败')
    }).finally(() => {
      this.loading = false
      this.refreshing = false
    })
  }

  private filtered(): ShoppingItem[] {
    let list = this.items
    if (this.filterIndex === 1) {
      list = list.filter((s: ShoppingItem) => s.status === 'pending')
    } else if (this.filterIndex === 2) {
      list = list.filter((s: ShoppingItem) => s.status === 'bought')
    }
    if (this.sortIndex === 1) {
      list = list.slice().sort((a: ShoppingItem, b: ShoppingItem) => b.price - a.price)
    }
    return list
  }

  private pendingItems(): ShoppingItem[] {
    return this.items.filter((s: ShoppingItem) => s.status === 'pending')
  }

  private sumOf(list: ShoppingItem[]): number {
    let sum = 0
    for (const item of list) {
      sum += item.price
    }
    return sum
  }

  /** 名称末尾若带价格则解析，例如 "机械键盘 399" */
  private parseQuickAdd(): ShoppingNamePrice {
    const text = this.quickName.trim()
    const match = text.match(/^(.*?)[\s ]+([0-9]+(?:\.[0-9]+)?)$/)
    const parsed = new ShoppingNamePrice()
    if (match !== null && match[1].trim().length > 0) {
      parsed.name = match[1].trim()
      parsed.price = parseFloat(match[2])
      return parsed
    }
    parsed.name = text
    parsed.price = 0
    return parsed
  }

  private quickAdd(): void {
    const parsed = this.parseQuickAdd()
    if (parsed.name.length === 0) {
      toast('请输入商品名称')
      return
    }
    Api.createShopping(parsed.name, parsed.price).then(() => {
      this.quickName = ''
      this.reload()
      Session.bumpDataVersion()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '添加失败')
    })
  }

  private toggleStatus(item: ShoppingItem): void {
    const next = item.status === 'pending' ? 'bought' : 'pending'
    Api.updateShopping(item.id, next).then(() => {
      this.reload()
      Session.bumpDataVersion()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '操作失败')
    })
  }

  private openEdit(item: ShoppingItem): void {
    this.formId = item.id
    this.formName = item.name
    this.formPrice = item.price > 0 ? item.price.toString() : ''
    this.showForm = true
  }

  private saveForm(): void {
    if (this.formName.trim().length === 0) {
      toast('请输入商品名称')
      return
    }
    const price = parseFloat(this.formPrice.length === 0 ? '0' : this.formPrice)
    Api.updateShoppingItem(this.formId, this.formName.trim(), isNaN(price) ? 0 : price).then(() => {
      toast('已保存')
      this.showForm = false
      this.reload()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '保存失败')
    })
  }

  private removeItem(item: ShoppingItem): void {
    Api.deleteShopping(item.id).then(() => {
      toast('已删除')
      this.showForm = false
      this.reload()
      Session.bumpDataVersion()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '删除失败')
    })
  }

  private clearBought(): void {
    const bought = this.items.filter((s: ShoppingItem) => s.status === 'bought')
    if (bought.length === 0) {
      toast('没有已买项')
      return
    }
    confirm('清理全部已买项（' + bought.length + ' 件）？', () => {
      let done = 0
      for (const item of bought) {
        Api.deleteShopping(item.id).then(() => {
          done++
          if (done >= bought.length) {
            this.reload()
          }
        }).catch(() => {
          done++
        })
      }
      toast('正在清理…')
    })
  }

  build() {
    Stack() {
      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column() {
            PageHeader({
              navStack: this.nav,
              title: '待买清单',
              actionLabel: '清理已买',
              onAction: (): void => {
                this.clearBought()
              }
            })

            // 快速添加
            Row({ space: 10 }) {
              TextInput({ placeholder: '想买什么？可带价格，如"机械键盘 399"', text: this.quickName })
                .placeholderColor($r('sys.color.font_tertiary'))
                .fontColor($r('sys.color.font_primary'))
                .fontSize(AppFont.Body)
                .backgroundColor($r('sys.color.comp_background_tertiary'))
                .borderRadius(AppRadius.Md)
                .height(44)
                .align(Alignment.Start)
                .layoutWeight(1)
                .onChange((value: string) => {
                  this.quickName = value
                })
                .onSubmit(() => {
                  this.quickAdd()
                })
              Text('添加')
                .fontSize(AppFont.Body)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColor.OnBrand)
                .width(64)
                .height(44)
                .textAlign(TextAlign.Center)
                .borderRadius(AppRadius.Pill)
                .backgroundColor(AppColor.Brand)
                .onClick(() => {
                  this.quickAdd()
                })
            }
            .width('100%')

            // 概览
            Column() {
              TechCard() {
                Row() {
                  Column({ space: 4 }) {
                    Text('待买')
                      .fontSize(10)
                      .fontColor($r('sys.color.font_secondary'))
                    Text(this.pendingItems().length + ' 件')
                      .fontSize(17)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Theme.WARN)
                  }
                  .layoutWeight(1)
                  Column({ space: 4 }) {
                    Text('待买合计')
                      .fontSize(10)
                      .fontColor($r('sys.color.font_secondary'))
                    Text('¥' + this.sumOf(this.pendingItems()).toFixed(2))
                      .fontSize(17)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppColor.Brand)
                  }
                  .layoutWeight(1)
                  Column({ space: 4 }) {
                    Text('已买合计')
                      .fontSize(10)
                      .fontColor($r('sys.color.font_secondary'))
                    Text('¥' + this.sumOf(this.items.filter((s: ShoppingItem) => s.status === 'bought')).toFixed(2))
                      .fontSize(17)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppColor.Brand)
                  }
                  .layoutWeight(1)
                }
                .width('100%')
              }
            }
            .width('100%')
            .margin({ top: 12 })

            Row({ space: 8 }) {
              Column() {
                OptionChips({
                  options: ['全部', '待买', '已买'],
                  selected: this.filterIndex,
                  onSelect: (index: number) => {
                    this.filterIndex = index
                  }
                })
              }
              .layoutWeight(1)
              Column() {
                OptionChips({
                  options: ['默认', '价格'],
                  selected: this.sortIndex,
                  onSelect: (index: number) => {
                    this.sortIndex = index
                  }
                })
              }
            }
            .width('100%')
            .padding({ top: 12, bottom: 6 })

            if (this.loading) {
              EmptyView({ icon: '⏳', text: '加载中…' })
            } else if (this.filtered().length === 0) {
              EmptyView({ icon: '🛒', text: '清单空空，先把想买的记下来' })
            } else {
              List() {
                ForEach(this.filtered(), (item: ShoppingItem) => {
                  ListItem() {
                    Column() {
                      TechCard() {
                        Row({ space: AppSpace.Sm }) {
                          // 已买圆点
                          Text(item.status === 'bought' ? '✔' : '')
                            .fontSize(13)
                            .fontColor(AppColor.OnBrand)
                            .width(22)
                            .height(22)
                            .textAlign(TextAlign.Center)
                            .borderRadius(11)
                            .backgroundColor(item.status === 'bought' ? AppColor.Brand : Color.Transparent)
                            .border({ width: 2, color: item.status === 'bought' ? AppColor.Brand : AppColor.Divider })
                            .onClick(() => {
                              this.toggleStatus(item)
                            })
                          Column({ space: 3 }) {
                            Text(item.name)
                              .fontSize(AppFont.Body)
                              .fontWeight(FontWeight.Bold)
                              .fontColor(item.status === 'bought' ? $r('sys.color.font_tertiary') : $r('sys.color.font_primary'))
                              .decoration({ type: item.status === 'bought' ? TextDecorationType.LineThrough : TextDecorationType.None })
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                            Text(item.status === 'bought' ? '已买' : '待买')
                              .fontSize(10)
                              .fontColor(item.status === 'bought' ? AppColor.Brand : Theme.WARN)
                          }
                          .alignItems(HorizontalAlign.Start)
                          .layoutWeight(1)
                          Text(item.price > 0 ? '¥' + item.price.toFixed(2) : '-')
                            .fontSize(AppFont.Body)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(AppColor.Brand)
                          Text('✎')
                            .fontSize(13)
                            .fontColor($r('sys.color.font_tertiary'))
                            .onClick(() => {
                              this.openEdit(item)
                            })
                        }
                        .width('100%')
                      }
                    }
                    .width('100%')
                    .margin({ bottom: 10 })
                  }
                }, (item: ShoppingItem) => item.id.toString() + '-' + item.status)
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
      height: 380,
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
      SheetHeader({ title: '编辑商品' })

      Text('名称').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
      TextInput({ placeholder: '商品名称', text: this.formName })
        .placeholderColor($r('sys.color.font_tertiary'))
        .fontColor($r('sys.color.font_primary'))
        .fontSize(AppFont.Body)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(AppRadius.Md)
        .height(42)
        .align(Alignment.Start)
        .onChange((value: string) => {
          this.formName = value
        })

      Text('价格（可选）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
      TextInput({ placeholder: '0.00', text: this.formPrice })
        .placeholderColor($r('sys.color.font_tertiary'))
        .fontColor($r('sys.color.font_primary'))
        .fontSize(AppFont.Body)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(AppRadius.Md)
        .height(42)
        .align(Alignment.Start)
        .type(InputType.NUMBER_DECIMAL)
        .onChange((value: string) => {
          this.formPrice = value
        })

      SheetSubmit({
        label: '保 存',
        onSubmit: (): void => {
          this.saveForm()
        }
      })

      SheetDelete({
        label: '删除该商品',
        onDelete: (): void => {
          const target = this.items.find((s: ShoppingItem) => s.id === this.formId)
          if (target !== undefined) {
            this.removeItem(target)
          }
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

/** 快速添加解析结果：名称 + 可选价格 */
class ShoppingNamePrice {
  name: string = ''
  price: number = 0
}
