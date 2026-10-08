import { Fmt, toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { KnowledgeItem, KnowledgePayload } from '../../model/Models'
import { Chip, EmptyView, OptionChips, PAGE_PAD_H, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, TechCard } from '../../components/Ui'

const PAGE_SIZE = 30

@Component
export struct NotesTab {
  @Consume('topInset') topInset: number
  @Consume('nav') nav: NavPathStack
  @StorageLink('dataVersion') @Watch('reload') version: number = 0
  @State items: KnowledgeItem[] = []
  @State total: number = 0
  @State refreshing: boolean = false
  @State keyword: string = ''
  @State typeIndex: number = 0
  @State sortIndex: number = 0
  @State tags: string[] = []
  @State tagFilter: string = ''
  @State showSheet: boolean = false
  @State formId: number = 0
  @State formTypeIndex: number = 0
  @State formTitle: string = ''
  @State formTags: string = ''
  @State formContent: string = ''
  @State formLearned: boolean = false
  @State saving: boolean = false

  aboutToAppear(): void {
    this.loadTags()
    this.reload()
  }

  loadTags(): void {
    Api.knowledgeTags().then((list) => {
      this.tags = list
    }).catch(() => {
    })
  }

  buildQuery(page: number): Record<string, string> {
    const query: Record<string, string> = {
      'page': page.toString(),
      'pageSize': PAGE_SIZE.toString(),
      'sortBy': ['updatedAt', 'createdAt', 'views'][this.sortIndex]
    }
    if (this.keyword.trim().length > 0) {
      query['keyword'] = this.keyword.trim()
    }
    if (this.typeIndex === 1) {
      query['type'] = 'note'
    } else if (this.typeIndex === 2) {
      query['type'] = 'qa'
    }
    if (this.tagFilter.length > 0) {
      query['tag'] = this.tagFilter
    }
    return query
  }

  reload(): void {
    Api.listKnowledge(this.buildQuery(1)).then((result) => {
      this.items = result.items
      this.total = result.total
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载失败')
    }).finally(() => {
      this.refreshing = false
    })
  }

  loadMore(): void {
    if (this.items.length >= this.total) {
      return
    }
    const nextPage = Math.floor(this.items.length / PAGE_SIZE) + 1
    Api.listKnowledge(this.buildQuery(nextPage)).then((result) => {
      const merged = this.items.concat(result.items)
      this.items = merged
      this.total = result.total
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载失败')
    })
  }

  typeBadge(type: string): string {
    return type === 'qa' ? '问答' : '笔记'
  }

  openDetail(item: KnowledgeItem): void {
    AppStorage.setOrCreate('knowledgeDetailId', item.id)
    this.nav.pushPathByName('knowledgeDetail', null)
  }

  openCreate(): void {
    this.formId = 0
    this.formTypeIndex = 0
    this.formTitle = ''
    this.formTags = ''
    this.formContent = ''
    this.formLearned = false
    this.showSheet = true
  }

  toggleLearned(item: KnowledgeItem): void {
    Api.updateKnowledge(item.id, { isLearned: !item.isLearned }).then(() => {
      toast(item.isLearned ? '已标记为未学习' : '已标记为已学习')
      this.reload()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '操作失败')
    })
  }

  removeItem(item: KnowledgeItem): void {
    Api.deleteKnowledge(item.id).then(() => {
      toast('已删除')
      this.showSheet = false
      this.reload()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '删除失败')
    })
  }

  saveForm(): void {
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
    const call = this.formId === 0
      ? Api.createKnowledge(payload)
      : Api.updateKnowledge(this.formId, payload)
    call.then(() => {
      toast('已保存')
      this.showSheet = false
      this.reload()
      this.loadTags()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '保存失败')
    }).finally(() => {
      this.saving = false
    })
  }

  build() {
    Stack() {
      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column() {
            Row() {
              Text('备忘 · 知识库')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT)
                .layoutWeight(1)
              Text('＋ 新建')
                .fontSize(13)
                .fontColor('#FFFFFF')
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .borderRadius(12)
                .linearGradient({ angle: 135, colors: Theme.BRAND_COLORS })
                .onClick(() => {
                  this.openCreate()
                })
            }
            .width('100%')
            .margin({ bottom: 12 })

            TextInput({ placeholder: '搜索标题或内容…', text: this.keyword })
              .placeholderColor(Theme.TEXT_FAINT)
              .fontColor(Theme.TEXT)
              .fontSize(13)
              .backgroundColor(Theme.INPUT_BG)
              .borderRadius(12)
              .border({ width: 1, color: Theme.BORDER })
              .height(42)
              .align(Alignment.Start)
              .onChange((value: string) => {
                this.keyword = value
              })
              .onSubmit(() => {
                this.reload()
              })

            Row({ space: 8 }) {
              OptionChips({
                options: ['全部', '笔记', '问答'],
                selected: this.typeIndex,
                onSelect: (index: number) => {
                  this.typeIndex = index
                  this.reload()
                }
              })
              OptionChips({
                options: ['最近更新', '创建时间', '浏览最多'],
                selected: this.sortIndex,
                onSelect: (index: number) => {
                  this.sortIndex = index
                  this.reload()
                }
              })
            }
            .width('100%')
            .margin({ top: 10 })

            if (this.tags.length > 0) {
              Row({ space: 8 }) {
                Chip({ text: '全部标签', color: Theme.MINT, selected: this.tagFilter.length === 0 })
                  .onClick(() => {
                    this.tagFilter = ''
                    this.reload()
                  })
                ForEach(this.tags, (tag: string) => {
                  Chip({
                    text: tag,
                    color: Theme.VIOLET,
                    selected: this.tagFilter === tag
                  })
                    .onClick(() => {
                      this.tagFilter = this.tagFilter === tag ? '' : tag
                      this.reload()
                    })
                }, (tag: string) => tag)
              }
              .width('100%')
              .margin({ top: 10 })
            }

            Text('共 ' + this.total + ' 条')
              .fontSize(11)
              .fontColor(Theme.TEXT_FAINT)
              .width('100%')
              .margin({ top: 12, bottom: 4 })

            if (this.items.length === 0) {
              EmptyView({ icon: '🗂️', text: '还没有备忘，点击右上角新建' })
            } else {
              ForEach(this.items, (item: KnowledgeItem) => {
                Column() {
                  TechCard({ onCard: (): void => {
                    this.openDetail(item)
                  } }) {
                    Column({ space: 8 }) {
                      Row({ space: 8 }) {
                        Chip({
                          text: this.typeBadge(item.type),
                          color: item.type === 'qa' ? Theme.VIOLET : Theme.CYAN,
                          small: true
                        })
                        Chip({
                          text: item.isLearned ? '已学' : '未学',
                          color: item.isLearned ? Theme.MINT : Theme.TEXT_FAINT,
                          small: true
                        })
                        Blank()
                        Text('👁 ' + item.views)
                          .fontSize(10)
                          .fontColor(Theme.TEXT_FAINT)
                      }
                      .width('100%')
                      Text(item.title)
                        .fontSize(15)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.TEXT)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                      Text(item.content)
                        .fontSize(12)
                        .fontColor(Theme.TEXT_SUB)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                      Row() {
                        Text(Fmt.joinTags(item.tags))
                          .fontSize(10)
                          .fontColor(Theme.VIOLET)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .layoutWeight(1)
                        Text('更新于 ' + Fmt.shortDate(item.updatedAt))
                          .fontSize(10)
                          .fontColor(Theme.TEXT_FAINT)
                      }
                      .width('100%')
                    }
                  }
                }
                .width('100%')
                .margin({ bottom: 10 })
              }, (item: KnowledgeItem) => item.id.toString() + '-' + item.updatedAt)
            }

            if (this.items.length < this.total) {
              Text('加载更多…')
                .fontSize(13)
                .fontColor(Theme.CYAN)
                .padding(14)
                .onClick(() => {
                  this.loadMore()
                })
            }
          }
          .padding({ left: 16, right: 16, top: this.topInset + 12, bottom: 20 })
          .constraintSize({ minHeight: '100%' })
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
    .bindSheet($$this.showSheet, this.formSheet(), {
      height: 640,
      dragBar: true,
      backgroundColor: Theme.CARD_SOLID
    })
  }

  @Builder
  formSheet() {
    Scroll() {
      Column() {
        SheetHeader({ title: this.formId === 0 ? '新建备忘' : '编辑备忘' })

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
          .height(180)
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
      .constraintSize({ minHeight: '100%' })
    }
    .scrollBar(BarState.Off)
    .height('100%')
  }
}
