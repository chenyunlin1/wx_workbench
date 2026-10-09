import { Fmt, toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { AppColor, AppFont, AppMaterial, AppRadius, AppSpace } from '../../theme/Theme'
import { Session } from '../../store/Session'
import { Finance, FinanceListResult, FinancePayload, FinanceSummary } from '../../model/Models'
import { EmptyView, OptionChips, PAGE_PAD_H, PAGE_SCROLL_BOTTOM, PageHeader, SheetDelete, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, TechCard } from '../../components/Ui'

@ComponentV2
export struct FinancePage {
  @Param nav: NavPathStack = new NavPathStack();
  @Local month: string = Fmt.month(new Date());
  @Local summary: FinanceSummary | null = null;
  @Local items: Finance[] = [];
  @Local total: number = 0;
  @Local typeIndex: number = 0;
  @Local categoryFilter: string = '';
  @Local categories: string[] = ['餐饮', '交通', '薪资', '购物', '娱乐', '住房'];
  @Local refreshing: boolean = false;
  @Local loading: boolean = true;
  @Local showForm: boolean = false;
  @Local formId: number = 0;
  @Local formTypeIndex: number = 1;
  @Local formAmount: string = '';
  @Local formCategoryIndex: number = 0;
  @Local formDate: string = Fmt.today();
  @Local formRemark: string = '';
  @Local saving: boolean = false;

  aboutToAppear(): void {
    this.reload()
    Api.financeCategories().then((list: string[]) => {
      if (list.length > 0) {
        this.categories = list
      }
    }).catch(() => {
    })
  }

  private reload(): void {
    Api.financeSummary(this.month).then((data: FinanceSummary) => {
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
    Api.listFinance(query).then((result: FinanceListResult) => {
      this.items = result.items
      this.total = result.total
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载失败')
    }).finally(() => {
      this.loading = false
      this.refreshing = false
    })
  }

  private shiftMonth(delta: number): void {
    this.month = Fmt.addMonths(this.month, delta)
    this.reload()
  }

  private openCreate(): void {
    this.formId = 0
    this.formTypeIndex = 1
    this.formAmount = ''
    this.formCategoryIndex = 0
    this.formDate = Fmt.today()
    this.formRemark = ''
    this.showForm = true
  }

  private openEdit(item: Finance): void {
    this.formId = item.id
    this.formTypeIndex = item.type === 'income' ? 0 : 1
    this.formAmount = item.amount.toString()
    this.formCategoryIndex = Math.max(0, this.categories.indexOf(item.category))
    this.formDate = Fmt.dateOnly(item.recordDate)
    this.formRemark = item.remark === null || item.remark === undefined ? '' : item.remark
    this.showForm = true
  }

  private saveForm(): void {
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

  private removeFinance(id: number): void {
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
    Stack() {
      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column() {
            PageHeader({
              navStack: this.nav,
              title: '财务记账',
              actionLabel: '＋ 记一笔',
              onAction: (): void => {
                this.openCreate()
              }
            })

            // 月份切换
            Row({ space: 12 }) {
              Text('‹')
                .fontSize(AppFont.TitleL)
                .fontColor(AppColor.Brand)
                .width(40)
                .height(36)
                .textAlign(TextAlign.Center)
                .onClick(() => {
                  this.shiftMonth(-1)
                })
              Text(this.month)
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
              Text('›')
                .fontSize(AppFont.TitleL)
                .fontColor(AppColor.Brand)
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
                      .fontColor($r('sys.color.font_secondary'))
                    Text('+' + (this.summary === null ? '-' : Fmt.money(this.summary.income)))
                      .fontSize(AppFont.Title)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Theme.SUCCESS)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  Column({ space: 4 }) {
                    Text('支出')
                      .fontSize(11)
                      .fontColor($r('sys.color.font_secondary'))
                    Text('-' + (this.summary === null ? '-' : Fmt.money(this.summary.expense)))
                      .fontSize(AppFont.Title)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Theme.DANGER)
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  Column({ space: 4 }) {
                    Text('结余')
                      .fontSize(11)
                      .fontColor($r('sys.color.font_secondary'))
                    Text(this.summary === null ? '-' : Fmt.money(this.summary.balance))
                      .fontSize(AppFont.Title)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppColor.Brand)
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
                    .fontSize(AppFont.Caption)
                    .fontColor($r('sys.color.font_tertiary'))
                  Text(this.categoryFilter.length === 0 ? '全部' : this.categoryFilter)
                    .fontSize(AppFont.Caption)
                    .fontColor(AppColor.Brand)
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(AppRadius.Pill)
                    .border({ width: 1, color: AppColor.Brand })
                    .onClick(() => {
                      this.categoryFilter = ''
                      this.reload()
                    })
                  ForEach(this.categories, (category: string) => {
                    Text(category)
                      .fontSize(AppFont.Caption)
                      .fontColor(this.categoryFilter === category ? AppColor.OnBrand : $r('sys.color.font_secondary'))
                      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                      .borderRadius(AppRadius.Pill)
                      .backgroundColor(this.categoryFilter === category ? AppColor.Brand
                        : $r('sys.color.comp_background_tertiary'))
                      .border({ width: 1, color: this.categoryFilter === category ? AppColor.Brand : AppColor.Divider })
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
                        Row({ space: AppSpace.Sm }) {
                          Column({ space: 4 }) {
                            Text(item.category)
                              .fontSize(15)
                              .fontWeight(FontWeight.Bold)
                              .fontColor($r('sys.color.font_primary'))
                            Text(Fmt.dateOnly(item.recordDate) +
                              (item.remark !== null && item.remark !== undefined && item.remark.length > 0
                                ? ' · ' + item.remark : ''))
                              .fontSize(11)
                              .fontColor($r('sys.color.font_secondary'))
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                          }
                          .alignItems(HorizontalAlign.Start)
                          .layoutWeight(1)
                          Text((item.type === 'income' ? '+' : '-') + Fmt.money(item.amount))
                            .fontSize(AppFont.BodyL)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(item.type === 'income' ? Theme.SUCCESS : Theme.DANGER)
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
    .backgroundColor($r('sys.color.background_primary'))
    .bindSheet($$this.showForm, this.formBuilder(), {
      height: 560,
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
      SheetHeader({ title: this.formId === 0 ? '记一笔' : '编辑账单' })

      Text('类型').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
      OptionChips({
        options: ['收入', '支出'],
        selected: this.formTypeIndex,
        onSelect: (index: number) => {
          this.formTypeIndex = index
        }
      })

      Text('金额').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
      TextInput({ placeholder: '0.00', text: this.formAmount })
        .placeholderColor($r('sys.color.font_tertiary'))
        .fontColor($r('sys.color.font_primary'))
        .fontSize(AppFont.BodyL)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(AppRadius.Md)
        .border({ width: 1, color: AppColor.Divider })
        .height(46)
        .align(Alignment.Start)
        .type(InputType.NUMBER_DECIMAL)
        .onChange((value: string) => {
          this.formAmount = value
        })

      Text('分类').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.categories, (category: string, index: number) => {
          Text(category)
            .fontSize(AppFont.Caption)
            .fontColor(this.formCategoryIndex === index ? AppColor.OnBrand : $r('sys.color.font_secondary'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(AppRadius.Md)
            .backgroundColor(this.formCategoryIndex === index ? AppColor.Brand
              : $r('sys.color.comp_background_tertiary'))
            .border({ width: 1, color: this.formCategoryIndex === index ? AppColor.Brand : AppColor.Divider })
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.formCategoryIndex = index
            })
        }, (category: string) => category + this.formCategoryIndex)
      }
      .width('100%')

      Text('日期').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
      Text(this.formDate)
        .fontSize(AppFont.Body)
        .fontColor(AppColor.Brand)
        .width('100%')
        .height(42)
        .padding({ left: 12 })
        .borderRadius(AppRadius.Md)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .border({ width: 1, color: AppColor.Divider })
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

      Text('备注（可选）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
      TextInput({ placeholder: '备注', text: this.formRemark })
        .placeholderColor($r('sys.color.font_tertiary'))
        .fontColor($r('sys.color.font_primary'))
        .fontSize(13)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(AppRadius.Md)
        .border({ width: 1, color: AppColor.Divider })
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
