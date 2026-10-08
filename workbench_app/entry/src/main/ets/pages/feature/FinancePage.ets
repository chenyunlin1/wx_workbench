import { Fmt, toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { Session } from '../../store/Session'
import { Finance, FinancePayload, FinanceSummary } from '../../model/Models'
import { EmptyView, OptionChips, PAGE_PAD_H, PAGE_SCROLL_BOTTOM, PageHeader, SheetDelete, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, TechCard } from '../../components/Ui'

@Component
export struct FinancePage {
  @Consume('nav') nav: NavPathStack
  @State month: string = Fmt.month(new Date())
  @State summary: FinanceSummary | null = null
  @State items: Finance[] = []
  @State total: number = 0
  @State typeIndex: number = 0
  @State categoryFilter: string = ''
  @State categories: string[] = ['餐饮', '交通', '薪资', '购物', '娱乐', '住房']
  @State refreshing: boolean = false
  @State loading: boolean = true
  @State showForm: boolean = false
  @State formId: number = 0
  @State formTypeIndex: number = 1
  @State formAmount: string = ''
  @State formCategoryIndex: number = 0
  @State formDate: string = Fmt.today()
  @State formRemark: string = ''
  @State saving: boolean = false

  aboutToAppear(): void {
    this.reload()
    Api.financeCategories().then((list) => {
      if (list.length > 0) {
        this.categories = list
      }
    }).catch(() => {
    })
  }

  reload(): void {
    Api.financeSummary(this.month).then((data) => {
      this.summary = data
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载统计失败')
    })
    const query: Record<string, string> = {
      'page': '1',
      'pageSize': '100',
      'month': this.month,
      'type': this.typeIndex === 1 ? 'income' : this.typeIndex === 2 ? 'expense' : ''
    }
    if (this.categoryFilter.length > 0) {
      query['category'] = this.categoryFilter
    }
    Api.listFinance(query).then((result) => {
      this.items = result.items
      this.total = result.total
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载失败')
    }).finally(() => {
      this.loading = false
      this.refreshing = false
    })
  }

  shiftMonth(delta: number): void {
    this.month = Fmt.addMonths(this.month, delta)
    this.reload()
  }

  openCreate(): void {
    this.formId = 0
    this.formTypeIndex = 1
    this.formAmount = ''
    this.formCategoryIndex = 0
    this.formDate = Fmt.today()
    this.formRemark = ''
    this.showForm = true
  }

  openEdit(item: Finance): void {
    this.formId = item.id
    this.formTypeIndex = item.type === 'income' ? 0 : 1
    this.formAmount = item.amount.toString()
    this.formCategoryIndex = Math.max(0, this.categories.indexOf(item.category))
    this.formDate = Fmt.dateOnly(item.recordDate)
    this.formRemark = item.remark === null || item.remark === undefined ? '' : item.remark
    this.showForm = true
  }

  saveForm(): void {
    const amount = parseFloat(this.formAmount)
    if (isNaN(amount) || amount <= 0) {
      toast('请输入有效金额')
      return
    }
    const payload: FinancePayload = {
      type: this.formTypeIndex === 0 ? 'income' : 'expense',
      amount: amount,
      category: this.categories[this.formCategoryIndex] === undefined ? '其他' : this.categories[this.formCategoryIndex],
      recordDate: this.formDate
    }
    if (this.formRemark.trim().length > 0) {
      payload.remark = this.formRemark.trim()
    }
    this.saving = true
    const call = this.formId === 0
      ? Api.createFinance(payload)
      : Api.updateFinance(this.formId, payload)
    call.then(() => {
      toast('已保存')
      this.showForm = false
      this.reload()
      Session.bumpDataVersion()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '保存失败')
    }).finally(() => {
      this.saving = false
    })
  }

  removeFinance(id: number): void {
    Api.deleteFinance(id).then(() => {
      toast('已删除')
      this.showForm = false
      this.reload()
      Session.bumpDataVersion()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '删除失败')
    })
  }

  build() {
    NavDestination() {
    Stack() {
      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column() {
            PageHeader({ title: '财务记账', actionLabel: '＋ 记一笔', onAction: (): void => {
              this.openCreate()
            } })

            // 月份切换
            Row({ space: 12 }) {
              Text('‹')
                .fontSize(22)
                .fontColor(Theme.CYAN)
                .width(40)
                .height(36)
                .textAlign(TextAlign.Center)
                .onClick(() => {
                  this.shiftMonth(-1)
                })
              Text(this.month)
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
              Text('›')
                .fontSize(22)
                .fontColor(Theme.CYAN)
                .width(40)
                .height(36)
                .textAlign(TextAlign.Center)
                .onClick(() => {
                  this.shiftMonth(1)
                })
            }
            .width('100%')

            // 汇总
            Column() {
            TechCard() {
              Row() {
                Column({ space: 4 }) {
                  Text('收入')
                    .fontSize(11)
                    .fontColor(Theme.TEXT_SUB)
                  Text('+' + (this.summary === null ? '-' : Fmt.money(this.summary.income)))
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.SUCCESS)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Column({ space: 4 }) {
                  Text('支出')
                    .fontSize(11)
                    .fontColor(Theme.TEXT_SUB)
                  Text('-' + (this.summary === null ? '-' : Fmt.money(this.summary.expense)))
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.DANGER)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Column({ space: 4 }) {
                  Text('结余')
                    .fontSize(11)
                    .fontColor(Theme.TEXT_SUB)
                  Text(this.summary === null ? '-' : Fmt.money(this.summary.balance))
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.CYAN)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
            }
            }
              .width('100%')
            .margin({ top: 10 })

            // 筛选
            Column({ space: 8 }) {
              OptionChips({
                options: ['全部', '收入', '支出'],
                selected: this.typeIndex,
                onSelect: (index: number) => {
                  this.typeIndex = index
                  this.reload()
                }
              })
              Scroll() {
                Row({ space: 8 }) {
                  Text('分类')
                    .fontSize(12)
                    .fontColor(Theme.TEXT_FAINT)
                  Text(this.categoryFilter.length === 0 ? '全部' : this.categoryFilter)
                    .fontSize(12)
                    .fontColor(Theme.CYAN)
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(999)
                    .border({ width: 1, color: Theme.CYAN })
                    .onClick(() => {
                      this.categoryFilter = ''
                      this.reload()
                    })
                  ForEach(this.categories, (category: string) => {
                    Text(category)
                      .fontSize(12)
                      .fontColor(this.categoryFilter === category ? '#FFFFFF' : Theme.TEXT_SUB)
                      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                      .borderRadius(999)
                      .backgroundColor(this.categoryFilter === category ? Theme.PRIMARY : Theme.INPUT_BG)
                      .border({ width: 1, color: this.categoryFilter === category ? Theme.PRIMARY : Theme.BORDER })
                      .onClick(() => {
                        this.categoryFilter = this.categoryFilter === category ? '' : category
                        this.reload()
                      })
                  }, (category: string) => category + this.categoryFilter)
                }
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
            }
            .width('100%')
            .padding({ top: 12, bottom: 6 })

            if (this.loading) {
              EmptyView({ icon: '⏳', text: '加载中…' })
            } else if (this.items.length === 0) {
              EmptyView({ icon: '💰', text: '本月暂无账单' })
            } else {
              List() {
                ForEach(this.items, (item: Finance) => {
                  ListItem() {
                    Column() {
                    TechCard() {
                      Row({ space: 12 }) {
                        Column({ space: 4 }) {
                          Text(item.category)
                            .fontSize(15)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(Theme.TEXT)
                          Text(Fmt.dateOnly(item.recordDate) +
                            (item.remark !== null && item.remark !== undefined && item.remark.length > 0
                              ? ' · ' + item.remark : ''))
                            .fontSize(11)
                            .fontColor(Theme.TEXT_SUB)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                        }
                        .alignItems(HorizontalAlign.Start)
                        .layoutWeight(1)
                        Text((item.type === 'income' ? '+' : '-') + Fmt.money(item.amount))
                          .fontSize(16)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(item.type === 'income' ? Theme.SUCCESS : Theme.DANGER)
                        Text('✎')
                          .fontSize(13)
                          .fontColor(Theme.TEXT_FAINT)
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
                }, (item: Finance) => item.id.toString() + '-' + item.amount.toString())
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
      height: 560,
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
      SheetHeader({ title: this.formId === 0 ? '记一笔' : '编辑账单' })

      Text('类型').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
      OptionChips({
        options: ['收入', '支出'],
        selected: this.formTypeIndex,
        onSelect: (index: number) => {
          this.formTypeIndex = index
        }
      })

      Text('金额').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
      TextInput({ placeholder: '0.00', text: this.formAmount })
        .fontColor(Theme.TEXT)
        .fontSize(16)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .border({ width: 1, color: Theme.BORDER })
        .height(46)
        .align(Alignment.Start)
        .type(InputType.NUMBER_DECIMAL)
        .onChange((value: string) => {
          this.formAmount = value
        })

      Text('分类').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.categories, (category: string, index: number) => {
          Text(category)
            .fontSize(12)
            .fontColor(this.formCategoryIndex === index ? '#FFFFFF' : Theme.TEXT_SUB)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(10)
            .backgroundColor(this.formCategoryIndex === index ? Theme.PRIMARY : Theme.INPUT_BG)
            .border({ width: 1, color: this.formCategoryIndex === index ? Theme.PRIMARY : Theme.BORDER })
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.formCategoryIndex = index
            })
        }, (category: string) => category + this.formCategoryIndex)
      }
      .width('100%')

      Text('日期').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
      Text(this.formDate)
        .fontSize(14)
        .fontColor(Theme.CYAN)
        .width('100%')
        .height(42)
        .padding({ left: 12 })
        .borderRadius(10)
        .backgroundColor(Theme.INPUT_BG)
        .border({ width: 1, color: Theme.BORDER })
        .onClick(() => {
          DatePickerDialog.show({
            start: new Date(2020, 0, 1),
            end: new Date(2035, 11, 31),
            selected: Fmt.parse(this.formDate + ' 09:00:00'),
            onDateAccept: (value: Date) => {
              this.formDate = Fmt.date(value)
            }
          })
        })

      Text('备注（可选）').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
      TextInput({ placeholder: '备注', text: this.formRemark })
        .fontColor(Theme.TEXT)
        .fontSize(13)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .border({ width: 1, color: Theme.BORDER })
        .height(40)
        .align(Alignment.Start)
        .onChange((value: string) => {
          this.formRemark = value
        })

      SheetSubmit({
        label: this.saving ? '保存中…' : '保 存',
        busy: this.saving,
        onSubmit: (): void => {
          this.saveForm()
        }
      })

      if (this.formId > 0) {
        SheetDelete({
          label: '删除该账单',
          onDelete: (): void => {
            this.removeFinance(this.formId)
          }
        })
      }
    }
    .padding({
      left: PAGE_PAD_H,
      right: PAGE_PAD_H,
      top: SHEET_PAD_TOP,
      bottom: SHEET_PAD_BOTTOM
    })
  }
}
