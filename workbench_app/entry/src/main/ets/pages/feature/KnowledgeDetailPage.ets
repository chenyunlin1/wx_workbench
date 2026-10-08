import { Fmt, toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { Session } from '../../store/Session'
import { KnowledgeItem, KnowledgePayload } from '../../model/Models'
import { Chip, OptionChips, PAGE_PAD_H, PageHeader, SectionTitle, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, TechCard } from '../../components/Ui'

/**
 * 知识详情页：完整内容 + 已学切换 / 编辑 / 删除。
 * 由备忘 Tab 点击卡片推入，条目 id 通过 AppStorage 的 knowledgeDetailId 传递。
 */
@Component
export struct KnowledgeDetailPage {
  @Consume('nav') nav: NavPathStack
  @Consume('bottomInset') bottomInset: number
  @State item: KnowledgeItem | null = null
  @State loading: boolean = true
  @State showEdit: boolean = false
  @State formTypeIndex: number = 0
  @State formTitle: string = ''
  @State formTags: string = ''
  @State formContent: string = ''
  @State formLearned: boolean = false
  @State saving: boolean = false

  aboutToAppear(): void {
    const id = AppStorage.get<number>('knowledgeDetailId')
    if (id === undefined || id <= 0) {
      this.loading = false
      return
    }
    Api.knowledgeDetail(id).then((detail) => {
      this.item = detail
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载失败')
    }).finally(() => {
      this.loading = false
    })
  }

  typeBadge(type: string): string {
    return type === 'qa' ? '问答' : '笔记'
  }

  toggleLearned(): void {
    if (this.item === null) {
      return
    }
    Api.updateKnowledge(this.item.id, { isLearned: !this.item.isLearned }).then((updated) => {
      this.item = updated
      toast(updated.isLearned ? '已标记为已学习' : '已标记为未学习')
      Session.bumpDataVersion()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '操作失败')
    })
  }

  openEdit(): void {
    if (this.item === null) {
      return
    }
    this.formTypeIndex = this.item.type === 'qa' ? 1 : 0
    this.formTitle = this.item.title
    this.formTags = this.item.tags.join(',')
    this.formContent = this.item.content
    this.formLearned = this.item.isLearned
    this.showEdit = true
  }

  saveEdit(): void {
    if (this.item === null) {
      return
    }
    if (this.formTitle.trim().length === 0 || this.formContent.trim().length === 0) {
      toast('标题和内容不能为空')
      return
    }
    const tagList: string[] = []
    for (const piece of this.formTags.split(/[,,]/)) {
      const trimmed = piece.trim()
      if (trimmed.length > 0) {
        tagList.push(trimmed)
      }
    }
    const payload: KnowledgePayload = {
      type: this.formTypeIndex === 1 ? 'qa' : 'note',
      title: this.formTitle.trim(),
      content: this.formContent,
      tags: tagList,
      isLearned: this.formLearned
    }
    this.saving = true
    Api.updateKnowledge(this.item.id, payload).then((updated) => {
      this.item = updated
      toast('已保存')
      this.showEdit = false
      Session.bumpDataVersion()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '保存失败')
    }).finally(() => {
      this.saving = false
    })
  }

  removeCurrent(): void {
    if (this.item === null) {
      return
    }
    Api.deleteKnowledge(this.item.id).then(() => {
      toast('已删除')
      Session.bumpDataVersion()
      this.nav.pop()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '删除失败')
    })
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          PageHeader({ title: '知识详情', actionLabel: '编辑', onAction: (): void => {
            this.openEdit()
          } })

          if (this.loading) {
            Column({ space: 10 }) {
              Text('⏳').fontSize(36)
              Text('加载中…')
                .fontSize(13)
                .fontColor(Theme.TEXT_FAINT)
            }
            .width('100%')
            .padding({ top: 80 })
          } else if (this.item === null) {
            Column({ space: 10 }) {
              Text('🗂️').fontSize(36)
              Text('内容不存在或已被删除')
                .fontSize(13)
                .fontColor(Theme.TEXT_FAINT)
            }
            .width('100%')
            .padding({ top: 80 })
          } else {
            Scroll() {
              Column({ space: 12 }) {
                TechCard() {
                  Column({ space: 10 }) {
                    Row({ space: 8 }) {
                      Chip({
                        text: this.typeBadge(this.item.type),
                        color: this.item.type === 'qa' ? Theme.VIOLET : Theme.CYAN
                      })
                      Chip({
                        text: this.item.isLearned ? '已学习' : '未学习',
                        color: this.item.isLearned ? Theme.MINT : Theme.TEXT_FAINT
                      })
                      Blank()
                      Text('👁 ' + this.item.views)
                        .fontSize(10)
                        .fontColor(Theme.TEXT_FAINT)
                    }
                    .width('100%')
                    Text(this.item.title)
                      .fontSize(19)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Theme.TEXT)
                      .width('100%')
                    Row() {
                      Text('# ' + Fmt.joinTags(this.item.tags))
                        .fontSize(12)
                        .fontColor(Theme.VIOLET)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                      Text(Fmt.shortDate(this.item.updatedAt) + ' 更新')
                        .fontSize(10)
                        .fontColor(Theme.TEXT_FAINT)
                    }
                    .width('100%')
                  }
                  .width('100%')
                }

                TechCard() {
                  Column({ space: 8 }) {
                    SectionTitle({ title: '内容' })
                    Text(this.item.content)
                      .fontSize(14)
                      .fontColor(Theme.TEXT_SUB)
                      .lineHeight(23)
                      .width('100%')
                  }
                  .width('100%')
                }

                Row({ space: 10 }) {
                  Text(this.item.isLearned ? '标记未学' : '标记已学')
                    .fontSize(13)
                    .fontColor(Theme.MINT)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                    .height(42)
                    .borderRadius(12)
                    .border({ width: 1, color: Theme.MINT })
                    .onClick(() => {
                      this.toggleLearned()
                    })
                  Text('删除')
                    .fontSize(13)
                    .fontColor(Theme.DANGER)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                    .height(42)
                    .borderRadius(12)
                    .border({ width: 1, color: Theme.DANGER })
                    .onClick(() => {
                      this.removeCurrent()
                    })
                }
                .width('100%')
                .margin({ top: 4, bottom: 12 })
              }
              .padding({ bottom: this.bottomInset + 16 })
              .constraintSize({ minHeight: '100%' })
            }
            .scrollBar(BarState.Off)
            .width('100%')
            .height('100%')
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG)
      .bindSheet($$this.showEdit, this.editSheet(), {
        height: 640,
        dragBar: true,
        backgroundColor: Theme.CARD_SOLID
      })
    }
    .hideTitleBar(true)
    .backgroundColor(Theme.BG)
  }

  @Builder
  editSheet() {
    Scroll() {
      Column() {
        SheetHeader({ title: '编辑备忘' })

        Text('类型').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
        OptionChips({
          options: ['笔记', '问答'],
          selected: this.formTypeIndex,
          onSelect: (index: number) => {
            this.formTypeIndex = index
          }
        })

        Text('标题').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
        TextInput({ placeholder: '备忘标题', text: this.formTitle })
          .placeholderColor(Theme.TEXT_FAINT)
          .fontColor(Theme.TEXT)
          .fontSize(14)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(10)
          .border({ width: 1, color: Theme.BORDER })
          .height(42)
          .align(Alignment.Start)
          .onChange((value: string) => {
            this.formTitle = value
          })

        Text('标签（逗号分隔）').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
        TextInput({ placeholder: '例如：HarmonyOS, 面试', text: this.formTags })
          .placeholderColor(Theme.TEXT_FAINT)
          .fontColor(Theme.TEXT)
          .fontSize(14)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(10)
          .border({ width: 1, color: Theme.BORDER })
          .height(42)
          .align(Alignment.Start)
          .onChange((value: string) => {
            this.formTags = value
          })

        Text('内容').fontSize(12).fontColor(Theme.TEXT_SUB).margin({ top: 14, bottom: 6 })
        TextArea({ placeholder: '记录知识点…', text: this.formContent })
          .placeholderColor(Theme.TEXT_FAINT)
          .fontColor(Theme.TEXT)
          .fontSize(14)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(10)
          .border({ width: 1, color: Theme.BORDER })
          .height(170)
          .onChange((value: string) => {
            this.formContent = value
          })

        Row({ space: 10 }) {
          Text('标记为已学习')
            .fontSize(13)
            .fontColor(Theme.TEXT)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.formLearned })
            .selectedColor(Theme.MINT)
            .onChange((isOn: boolean) => {
              this.formLearned = isOn
            })
        }
        .width('100%')
        .margin({ top: 14 })

        SheetSubmit({
          label: this.saving ? '保存中…' : '保 存',
          busy: this.saving,
          onSubmit: (): void => {
            this.saveEdit()
          }
        })
      }
      .padding({
        left: PAGE_PAD_H,
        right: PAGE_PAD_H,
        top: SHEET_PAD_TOP,
        bottom: SHEET_PAD_BOTTOM
      })
      .constraintSize({ minHeight: '100%' })
    }
    .scrollBar(BarState.Off)
    .height('100%')
  }
}
