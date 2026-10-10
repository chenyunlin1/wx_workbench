import { Fmt, toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { AppColor, AppFont, AppMaterial, AppRadius, AppSpace } from '../../theme/Theme'
import { WindowUtils } from '../../utils/WindowUtils'
import { Session, SessionStore } from '../../store/Session'
import { KnowledgeCacheService } from '../../service/KnowledgeCacheService'
import { KnowledgeItem, KnowledgePayload } from '../../model/Models'
import { Chip, EmptyView, OptionChips, PAGE_PAD_H, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, TechCard } from '../../components/Ui'

const PAGE_SIZE = 30

@ComponentV2
export struct NotesTab {
  @Param nav: NavPathStack = new NavPathStack();
  @Event onScrollerReady: (scroller: Scroller) => void = () => {};
  @Local session: SessionStore = Session;
  @Local items: KnowledgeItem[] = [];
  @Local total: number = 0;
  @Local refreshing: boolean = false;
  @Local keyword: string = '';
  @Local typeIndex: number = 0;
  @Local sortIndex: number = 0;
  @Local tags: string[] = [];
  @Local tagFilter: string = '';
  @Local showSheet: boolean = false;
  @Local formId: number = 0;
  @Local formTypeIndex: number = 0;
  @Local formTitle: string = '';
  @Local formTags: string = '';
  @Local formContent: string = '';
  @Local formLearned: boolean = false;
  @Local saving: boolean = false;

  private scroller: Scroller = new Scroller();
  private all: KnowledgeItem[] = []
  private filtered: KnowledgeItem[] = []
  private visible: number = PAGE_SIZE

  aboutToAppear(): void {
    this.onScrollerReady(this.scroller);
    this.reloadFromCache()
    // 首次安装或无缓存时自动同步一次，避免空列表
    if (this.all.length === 0) {
      this.refreshing = true
      this.syncFromServer()
    }
  }

  @Monitor('session.dataVersion')
  onDataVersionChange(): void {
    this.reloadFromCache()
  }

  private reloadFromCache(): void {
    this.all = KnowledgeCacheService.load()
    this.tags = KnowledgeCacheService.tagsOf(this.all)
    this.applyFilters()
  }

  private applyFilters(): void {
    const keyword = this.keyword.trim().toLowerCase()
    this.filtered = this.all.filter((item: KnowledgeItem) => {
      if (this.typeIndex === 1 && item.type !== 'note') {
        return false
      }
      if (this.typeIndex === 2 && item.type !== 'qa') {
        return false
      }
      if (this.tagFilter.length > 0 && !item.tags.includes(this.tagFilter)) {
        return false
      }
      if (keyword.length > 0) {
        const title = item.title.toLowerCase()
        const content = item.content.toLowerCase()
        if (!title.includes(keyword) && !content.includes(keyword)) {
          return false
        }
      }
      return true
    })
    this.filtered.sort((a: KnowledgeItem, b: KnowledgeItem): number => this.compareItems(a, b))
    this.total = this.filtered.length
    this.items = this.filtered.slice(0, this.visible)
  }

  /** 与服务端排序一致：按当前字段降序，同值按 id 降序保证稳定 */
  private compareItems(a: KnowledgeItem, b: KnowledgeItem): number {
    let diff = 0
    if (this.sortIndex === 2) {
      diff = b.views - a.views
    } else {
      const left = this.sortIndex === 1 ? a.createdAt : a.updatedAt
      const right = this.sortIndex === 1 ? b.createdAt : b.updatedAt
      diff = left === right ? 0 : (left < right ? 1 : -1)
    }
    return diff !== 0 ? diff : b.id - a.id
  }

  /** 筛选条件变化时回到第一页 */
  private resetViewport(): void {
    this.visible = PAGE_SIZE
    this.applyFilters()
  }

  private loadMore(): void {
    if (this.items.length >= this.total) {
      return
    }
    this.visible += PAGE_SIZE
    this.applyFilters()
  }

  /** 下拉刷新：逐页拉取线上全量覆盖本地缓存 */
  private syncFromServer(): void {
    KnowledgeCacheService.syncFromServer().then((list: KnowledgeItem[]) => {
      this.all = list
      this.tags = KnowledgeCacheService.tagsOf(list)
      this.applyFilters()
      toast('已同步 ' + list.length + ' 条')
    }).catch((err: Object) => {
      toast('同步失败：' + (err instanceof Error ? err.message : '请稍后重试'))
      this.reloadFromCache()
    }).finally(() => {
      this.refreshing = false
    })
  }

  private typeBadge(type: string): string {
    return type === 'qa' ? '问答' : '笔记'
  }

  private openDetail(item: KnowledgeItem): void {
    AppStorage.setOrCreate('knowledgeDetailId', item.id)
    this.nav.pushPathByName('knowledgeDetail', null)
  }

  private openCreate(): void {
    this.formId = 0
    this.formTypeIndex = 0
    this.formTitle = ''
    this.formTags = ''
    this.formContent = ''
    this.formLearned = false
    this.showSheet = true
  }

  private toggleLearned(item: KnowledgeItem): void {
    Api.updateKnowledge(item.id, { isLearned: !item.isLearned }).then((updated: KnowledgeItem) => {
      KnowledgeCacheService.upsert(updated)
      toast(item.isLearned ? '已标记为未学习' : '已标记为已学习')
      this.reloadFromCache()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '操作失败')
    })
  }

  private removeItem(item: KnowledgeItem): void {
    Api.deleteKnowledge(item.id).then(() => {
      KnowledgeCacheService.remove(item.id)
      toast('已删除')
      this.showSheet = false
      this.reloadFromCache()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '删除失败')
    })
  }

  private saveForm(): void {
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
    call.then((saved: KnowledgeItem) => {
      KnowledgeCacheService.upsert(saved)
      toast('已保存')
      this.showSheet = false
      this.reloadFromCache()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '保存失败')
    }).finally(() => {
      this.saving = false
    })
  }

  build() {
    Stack() {
      Refresh({ refreshing: $$this.refreshing }) {
        Scroll(this.scroller) {
          Column() {
            Row() {
              Text('备忘 · 知识库')
                .fontSize(AppFont.TitleL)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
                .layoutWeight(1)
              Text('＋ 新建')
                .fontSize(AppFont.Caption + 1)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColor.OnBrand)
                .padding({ left: 14, right: 14, top: AppSpace.Xs, bottom: AppSpace.Xs })
                .borderRadius(AppRadius.Pill)
                .backgroundColor(AppColor.Brand)
                .onClick(() => {
                  this.openCreate()
                })
            }
            .width('100%')
            .margin({ bottom: AppSpace.Sm })

            TextInput({ placeholder: '搜索标题或内容…', text: this.keyword })
              .placeholderColor($r('sys.color.font_tertiary'))
              .fontColor($r('sys.color.font_primary'))
              .fontSize(AppFont.Body)
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .borderRadius(AppRadius.Md)
              .height(42)
              .align(Alignment.Start)
              .onChange((value: string) => {
                this.keyword = value
              })
              .onSubmit(() => {
                this.resetViewport()
              })

            Row({ space: AppSpace.Xs }) {
              OptionChips({
                options: ['全部', '笔记', '问答'],
                selected: this.typeIndex,
                onSelect: (index: number) => {
                  this.typeIndex = index
                  this.resetViewport()
                }
              })
              OptionChips({
                options: ['最近更新', '创建时间', '浏览最多'],
                selected: this.sortIndex,
                onSelect: (index: number) => {
                  this.sortIndex = index
                  this.resetViewport()
                }
              })
            }
            .width('100%')
            .margin({ top: AppSpace.Sm })

            if (this.tags.length > 0) {
              Scroll() {
                Row({ space: AppSpace.Xs }) {
                  Chip({ text: '全部标签', color: AppColor.Brand, selected: this.tagFilter.length === 0 })
                    .onClick(() => {
                      this.tagFilter = ''
                      this.resetViewport()
                    })
                  ForEach(this.tags, (tag: string) => {
                    Chip({
                      text: tag,
                      color: AppColor.BrandDark,
                      selected: this.tagFilter === tag
                    })
                      .onClick(() => {
                        this.tagFilter = this.tagFilter === tag ? '' : tag
                        this.resetViewport()
                      })
                  }, (tag: string) => tag)
                }
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
              .margin({ top: AppSpace.Sm })
            }

            Text('共 ' + this.total + ' 条')
              .fontSize(11)
              .fontColor($r('sys.color.font_tertiary'))
              .width('100%')
              .margin({ top: AppSpace.Sm, bottom: AppSpace.Xxs })

            if (this.items.length === 0) {
              EmptyView({ icon: '🗂️', text: '还没有备忘，点击右上角新建' })
            } else {
              ForEach(this.items, (item: KnowledgeItem) => {
                Column() {
                  TechCard({ onCard: (): void => {
                    this.openDetail(item)
                  } }) {
                    Column({ space: AppSpace.Xs }) {
                      Row({ space: AppSpace.Xs }) {
                        Chip({
                          text: this.typeBadge(item.type),
                          color: item.type === 'qa' ? AppColor.BrandDark : AppColor.Brand,
                          small: true
                        })
                        Chip({
                          text: item.isLearned ? '已学' : '未学',
                          color: item.isLearned ? AppColor.Brand : $r('sys.color.font_tertiary'),
                          small: true
                        })
                        Blank()
                        Text('👁 ' + item.views)
                          .fontSize(10)
                          .fontColor($r('sys.color.font_tertiary'))
                      }
                      .width('100%')
                      Text(item.title)
                        .fontSize(AppFont.BodyL)
                        .fontWeight(FontWeight.Bold)
                        .fontColor($r('sys.color.font_primary'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                      Text(item.content)
                        .fontSize(AppFont.Caption)
                        .fontColor($r('sys.color.font_secondary'))
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                      Row() {
                        Text(Fmt.joinTags(item.tags))
                          .fontSize(10)
                          .fontColor(AppColor.BrandDark)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .layoutWeight(1)
                        Text('更新于 ' + Fmt.shortDate(item.updatedAt))
                          .fontSize(10)
                          .fontColor($r('sys.color.font_tertiary'))
                      }
                      .width('100%')
                    }
                  }
                }
                .width('100%')
                .margin({ bottom: AppSpace.Xs })
              }, (item: KnowledgeItem) => item.id.toString() + '-' + item.updatedAt)
            }

            if (this.items.length < this.total) {
              Text('加载更多…')
                .fontSize(AppFont.Body)
                .fontColor(AppColor.Brand)
                .padding(14)
                .onClick(() => {
                  this.loadMore()
                })
            }
          }
          .padding({
            left: AppSpace.Md,
            right: AppSpace.Md,
            top: WindowUtils.getStatusBarHeightVp() + 12,
            bottom: WindowUtils.getFloatingTabBottomVp()
          })
          .constraintSize({ minHeight: '100%' })
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
      .onRefreshing(() => {
        this.syncFromServer()
      })
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showSheet, this.formSheet(), {
      height: 640,
      dragBar: true,
      preferType: SheetType.BOTTOM,
      backgroundColor: AppMaterial.SheetBackground,
      blurStyle: AppMaterial.SheetBlur,
      systemMaterial: AppMaterial.Sheet
    })
  }

  @Builder
  formSheet() {
    Scroll() {
      Column() {
        SheetHeader({ title: this.formId === 0 ? '新建备忘' : '编辑备忘' })

        Text('类型').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        OptionChips({
          options: ['笔记', '问答'],
          selected: this.formTypeIndex,
          onSelect: (index: number) => {
            this.formTypeIndex = index
          }
        })

        Text('标题').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        TextInput({ placeholder: '备忘标题', text: this.formTitle })
          .placeholderColor($r('sys.color.font_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .fontSize(AppFont.Body)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(AppRadius.Md)
          .height(42)
          .align(Alignment.Start)
          .onChange((value: string) => {
            this.formTitle = value
          })

        Text('标签（逗号分隔）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        TextInput({ placeholder: '例如：HarmonyOS, 面试', text: this.formTags })
          .placeholderColor($r('sys.color.font_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .fontSize(AppFont.Body)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(AppRadius.Md)
          .height(42)
          .align(Alignment.Start)
          .onChange((value: string) => {
            this.formTags = value
          })

        Text('内容').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        TextArea({ placeholder: '记录知识点…', text: this.formContent })
          .placeholderColor($r('sys.color.font_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .fontSize(AppFont.Body)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(AppRadius.Md)
          .height(180)
          .onChange((value: string) => {
            this.formContent = value
          })

        Row({ space: 10 }) {
          Text('标记为已学习')
            .fontSize(AppFont.Body)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.formLearned })
            .selectedColor(AppColor.Brand)
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
