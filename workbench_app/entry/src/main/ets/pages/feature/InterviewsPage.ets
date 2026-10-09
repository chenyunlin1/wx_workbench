import { Fmt, Options, toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { AppColor, AppFont, AppMaterial, AppRadius, AppSpace } from '../../theme/Theme'
import { Session } from '../../store/Session'
import { Interview, InterviewPayload } from '../../model/Models'
import { EmptyView, OptionChips, PAGE_PAD_H, PAGE_SCROLL_BOTTOM, PageHeader, SheetDelete, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, TechCard } from '../../components/Ui'

function statusColor(status: string): ResourceColor {
  if (status === 'passed') {
    return Theme.SUCCESS
  }
  if (status === 'rejected') {
    return Theme.DANGER
  }
  if (status === 'cancelled') {
    return $r('sys.color.font_tertiary')
  }
  return Theme.WARN
}

@ComponentV2
export struct InterviewsPage {
  @Param nav: NavPathStack = new NavPathStack();
  @Local interviews: Interview[] = [];
  @Local statusIndex: number = 0;
  @Local refreshing: boolean = false;
  @Local loading: boolean = true;
  @Local showForm: boolean = false;
  @Local formId: number = 0;
  @Local formCompany: string = '';
  @Local formPosition: string = '';
  @Local formTime: string = Fmt.dateTime(new Date());
  @Local formStatusIndex: number = 0;
  @Local saving: boolean = false;

  aboutToAppear(): void {
    this.reload()
  }

  private reload(): void {
    Api.listInterviews().then((list: Interview[]) => {
      this.interviews = list.sort((a: Interview, b: Interview) => b.interviewTime.localeCompare(a.interviewTime))
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载失败')
    }).finally(() => {
      this.loading = false
      this.refreshing = false
    })
  }

  private filtered(): Interview[] {
    if (this.statusIndex === 0) {
      return this.interviews
    }
    const target = ['all', 'pending', 'passed', 'rejected', 'cancelled'][this.statusIndex]
    return this.interviews.filter((i: Interview) => i.status === target)
  }

  private openCreate(): void {
    this.formId = 0
    this.formCompany = ''
    this.formPosition = ''
    this.formTime = Fmt.dateTime(new Date())
    this.formStatusIndex = 0
    this.showForm = true
  }

  private openEdit(item: Interview): void {
    this.formId = item.id
    this.formCompany = item.company
    this.formPosition = item.position
    this.formTime = item.interviewTime
    this.formStatusIndex = item.status === 'pending' ? 0 : item.status === 'passed' ? 1 : item.status === 'rejected' ? 2 : 3
    this.showForm = true
  }

  private pickTime(): void {
    const base = this.formTime.length >= 16 ? Fmt.parse(this.formTime) : new Date()
    DatePickerDialog.show({
      start: new Date(2020, 0, 1),
      end: new Date(2035, 11, 31),
      selected: base,
      onDateAccept: (value: Date) => {
        TimePickerDialog.show({
          selected: base,
          useMilitaryTime: true,
          onAccept: (t: TimePickerResult) => {
            const d = new Date(value.getFullYear(), value.getMonth(), value.getDate(), t.hour, t.minute)
            this.formTime = Fmt.dateTime(d)
          }
        })
      }
    })
  }

  private saveForm(): void {
    if (this.formCompany.trim().length === 0) {
      toast('请输入公司名称')
      return
    }
    const payload: InterviewPayload = {
      company: this.formCompany.trim(),
      position: this.formPosition.trim(),
      interviewTime: this.formTime,
      status: ['pending', 'passed', 'rejected', 'cancelled'][this.formStatusIndex]
    }
    this.saving = true
    const call = this.formId === 0
      ? Api.createInterview(payload)
      : Api.updateInterview(this.formId, payload)
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

  private removeInterview(id: number): void {
    Api.deleteInterview(id).then(() => {
      toast('已删除')
      this.showForm = false
      this.reload()
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
              title: '面试准备',
              actionLabel: '＋ 添加',
              onAction: (): void => {
                this.openCreate()
              }
            })

            Row() {
              OptionChips({
                options: ['全部', '待进行', '通过', '未通过', '已取消'],
                selected: this.statusIndex,
                onSelect: (index: number) => {
                  this.statusIndex = index
                }
              })
            }
            .width('100%')
            .padding({ bottom: 8 })

            if (this.loading) {
              EmptyView({ icon: '⏳', text: '加载中…' })
            } else if (this.filtered().length === 0) {
              EmptyView({ icon: '💼', text: '暂无面试记录' })
            } else {
              List() {
                ForEach(this.filtered(), (item: Interview) => {
                  ListItem() {
                    Column() {
                      TechCard() {
                        Row({ space: AppSpace.Sm }) {
                          Column({ space: 5 }) {
                            Text(item.company)
                              .fontSize(AppFont.BodyL)
                              .fontWeight(FontWeight.Bold)
                              .fontColor($r('sys.color.font_primary'))
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                            Text(item.position)
                              .fontSize(AppFont.Caption)
                              .fontColor($r('sys.color.font_secondary'))
                            Text(Fmt.dateTime(Fmt.parse(item.interviewTime)).replace(':00', ''))
                              .fontSize(11)
                              .fontColor(AppColor.Brand)
                          }
                          .alignItems(HorizontalAlign.Start)
                          .layoutWeight(1)

                          Column({ space: 6 }) {
                            Text(Options.interviewStatusLabel(item.status))
                              .fontSize(10)
                              .fontColor(statusColor(item.status))
                              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                              .borderRadius(AppRadius.Pill)
                              .border({ width: 1, color: statusColor(item.status) })
                            Text('✎')
                              .fontSize(13)
                              .fontColor($r('sys.color.font_tertiary'))
                              .onClick(() => {
                                this.openEdit(item)
                              })
                          }
                        }
                        .width('100%')
                      }
                    }
                    .width('100%')
                    .margin({ bottom: 10 })
                  }
                }, (item: Interview) => item.id.toString() + '-' + item.status)
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
      height: 540,
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
      SheetHeader({ title: this.formId === 0 ? '添加面试' : '编辑面试' })

      Text('公司').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
      TextInput({ placeholder: '公司名称', text: this.formCompany })
        .placeholderColor($r('sys.color.font_tertiary'))
        .fontColor($r('sys.color.font_primary'))
        .fontSize(AppFont.Body)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(AppRadius.Md)
        .border({ width: 1, color: AppColor.Divider })
        .height(42)
        .align(Alignment.Start)
        .onChange((value: string) => {
          this.formCompany = value
        })

      Text('职位').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
      TextInput({ placeholder: '应聘职位', text: this.formPosition })
        .placeholderColor($r('sys.color.font_tertiary'))
        .fontColor($r('sys.color.font_primary'))
        .fontSize(AppFont.Body)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(AppRadius.Md)
        .border({ width: 1, color: AppColor.Divider })
        .height(42)
        .align(Alignment.Start)
        .onChange((value: string) => {
          this.formPosition = value
        })

      Text('面试时间').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
      Text(this.formTime)
        .fontSize(AppFont.Body)
        .fontColor(AppColor.Brand)
        .width('100%')
        .height(42)
        .padding({ left: 12 })
        .borderRadius(AppRadius.Md)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .border({ width: 1, color: AppColor.Divider })
        .onClick(() => {
          this.pickTime()
        })

      Text('状态').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
      OptionChips({
        options: ['待进行', '通过', '未通过', '已取消'],
        selected: this.formStatusIndex,
        onSelect: (index: number) => {
          this.formStatusIndex = index
        }
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
          label: '删除该面试',
          onDelete: (): void => {
            this.removeInterview(this.formId)
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
