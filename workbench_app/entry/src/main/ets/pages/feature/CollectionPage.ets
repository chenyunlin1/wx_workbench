import { Options, toast } from '../../common/AppKit'
import { Api } from '../../api/Api'
import { Theme } from '../../common/Theme'
import { AppColor, AppFont, AppMaterial, AppRadius } from '../../theme/Theme'
import { Session } from '../../store/Session'
import { CollectionItem, CollectionListResult, CollectionPayload, CollectionStats } from '../../model/Models'
import { EmptyView, OptionChips, PAGE_PAD_H, PAGE_SCROLL_BOTTOM, PageHeader, SheetDelete, SHEET_PAD_BOTTOM, SHEET_PAD_TOP, SheetHeader, SheetSubmit, StarPicker, Stars, TechCard } from '../../components/Ui'

const TYPE_LABELS: string[] = ['全部', '书籍', '影视', '音乐']
const TYPE_KEYS: string[] = ['', 'book', 'movie', 'music']

function typeEmoji(type: string): string {
  if (type === 'book') {
    return '📚'
  }
  if (type === 'movie') {
    return '🎬'
  }
  return '🎵'
}

@ComponentV2
export struct CollectionPage {
  @Param nav: NavPathStack = new NavPathStack();
  @Local items: CollectionItem[] = [];
  @Local total: number = 0;
  @Local stats: CollectionStats | null = null;
  @Local typeIndex: number = 0;
  @Local statusFilter: string = '';
  @Local keyword: string = '';
  @Local sortIndex: number = 0;
  @Local refreshing: boolean = false;
  @Local loading: boolean = true;
  @Local showForm: boolean = false;
  @Local formId: number = 0;
  @Local formTypeIndex: number = 1;
  @Local formTitle: string = '';
  @Local formStatus: string = 'wish';
  @Local formRating: number = 0;
  @Local formYear: string = '';
  @Local formCover: string = '';
  @Local formComment: string = '';
  @Local saving: boolean = false;

  aboutToAppear(): void {
    this.reload()
  }

  private reload(): void {
    Api.collectionStats(new Date().getFullYear()).then((data: CollectionStats) => {
      this.stats = data
    }).catch(() => {
    })
    const query: Record<string, string> = {
      'page': '1',
      'pageSize': '100',
      'sortBy': ['createdAt', 'rating', 'year', 'title'][this.sortIndex]
    }
    const type = TYPE_KEYS[this.typeIndex]
    if (type.length > 0) {
      query['type'] = type
    }
    if (this.statusFilter.length > 0) {
      query['status'] = this.statusFilter
    }
    if (this.keyword.trim().length > 0) {
      query['keyword'] = this.keyword.trim()
    }
    Api.listCollection(query).then((result: CollectionListResult) => {
      this.items = result.items
      this.total = result.total
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '加载失败')
    }).finally(() => {
      this.loading = false
      this.refreshing = false
    })
  }

  private statusLabels(): string[] {
    const type = TYPE_KEYS[this.typeIndex].length === 0 ? 'book' : TYPE_KEYS[this.typeIndex]
    return ['wish', 'doing', 'done'].map((s: string) => Options.collectionStatusLabel(s, type))
  }

  private statusKeys(): string[] {
    return ['', 'wish', 'doing', 'done']
  }

  private statusIndex(): number {
    return this.statusKeys().indexOf(this.statusFilter)
  }

  private statusLabelOf(item: CollectionItem): string {
    return Options.collectionStatusLabel(item.status, item.type)
  }

  private cycleStatus(item: CollectionItem): void {
    const next = item.status === 'wish' ? 'doing' : item.status === 'doing' ? 'done' : 'wish'
    Api.updateCollectionStatus(item.id, next).then(() => {
      this.reload()
    }).catch((err: Object) => {
      toast(err instanceof Error ? err.message : '更新失败')
    })
  }

  private openCreate(): void {
    this.formId = 0
    this.formTypeIndex = this.typeIndex === 0 ? 1 : this.typeIndex
    this.formTitle = ''
    this.formStatus = 'wish'
    this.formRating = 0
    this.formYear = ''
    this.formCover = ''
    this.formComment = ''
    this.showForm = true
  }

  private openEdit(item: CollectionItem): void {
    this.formId = item.id
    this.formTypeIndex = item.type === 'book' ? 1 : item.type === 'movie' ? 2 : 3
    this.formTitle = item.title
    this.formStatus = item.status
    this.formRating = item.rating === null || item.rating === undefined ? 0 : item.rating
    this.formYear = item.year === null || item.year === undefined ? '' : item.year.toString()
    this.formCover = item.coverUrl === null || item.coverUrl === undefined ? '' : item.coverUrl
    this.formComment = item.comment === null || item.comment === undefined ? '' : item.comment
    this.showForm = true
  }

  private saveForm(): void {
    if (this.formTitle.trim().length === 0) {
      toast('请输入标题')
      return
    }
    const type = TYPE_KEYS[this.formTypeIndex]
    const payload: CollectionPayload = {
      type: type,
      title: this.formTitle.trim(),
      status: this.formStatus
    }
    payload.rating = this.formRating > 0 ? this.formRating : null
    if (this.formYear.trim().length > 0) {
      const year = parseInt(this.formYear)
      if (!isNaN(year)) {
        payload.year = year
      }
    } else {
      payload.year = null
    }
    payload.coverUrl = this.formCover.trim().length > 0 ? this.formCover.trim() : null
    payload.comment = this.formComment.trim().length > 0 ? this.formComment.trim() : null
    this.saving = true
    const call = this.formId === 0
      ? Api.createCollection(payload)
      : Api.updateCollection(this.formId, payload)
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

  private removeCollection(id: number): void {
    Api.deleteCollection(id).then(() => {
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
              title: '书影音收藏',
              actionLabel: '＋ 添加',
              onAction: (): void => {
                this.openCreate()
              }
            })

            // 年度统计
            Column() {
              TechCard() {
                Row() {
                  Column({ space: 4 }) {
                    Text('今年新增')
                      .fontSize(10)
                      .fontColor($r('sys.color.font_secondary'))
                    Text(this.stats === null ? '-' : this.stats.total.toString())
                      .fontSize(17)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppColor.Brand)
                  }
                  .layoutWeight(1)
                  Column({ space: 4 }) {
                    Text('完成')
                      .fontSize(10)
                      .fontColor($r('sys.color.font_secondary'))
                    Text(this.stats === null ? '-' : this.stats.finished.toString())
                      .fontSize(17)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppColor.Brand)
                  }
                  .layoutWeight(1)
                  Column({ space: 4 }) {
                    Text('平均评分')
                      .fontSize(10)
                      .fontColor($r('sys.color.font_secondary'))
                    Text(this.stats === null || this.stats.ratingAverage === null || this.stats.ratingAverage === undefined
                      ? '-' : this.stats.ratingAverage.toFixed(1))
                      .fontSize(17)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Theme.WARN)
                  }
                  .layoutWeight(1)
                }
                .width('100%')
                Row({ space: 10 }) {
                  Text(typeEmoji('book') + (this.stats === null ? '-' : this.stats.books.toString()))
                    .fontSize(11)
                    .fontColor($r('sys.color.font_secondary'))
                  Text(typeEmoji('movie') + (this.stats === null ? '-' : this.stats.movies.toString()))
                    .fontSize(11)
                    .fontColor($r('sys.color.font_secondary'))
                  Text(typeEmoji('music') + (this.stats === null ? '-' : this.stats.music.toString()))
                    .fontSize(11)
                    .fontColor($r('sys.color.font_secondary'))
                }
                .width('100%')
                .margin({ top: 8 })
              }
            }
            .width('100%')
            .margin({ top: 4 })

            // 筛选
            Column({ space: 8 }) {
              OptionChips({
                options: TYPE_LABELS,
                selected: this.typeIndex,
                onSelect: (index: number) => {
                  this.typeIndex = index
                  this.statusFilter = ''
                  this.reload()
                }
              })
              Row({ space: 8 }) {
                Text('全部状态')
                  .fontSize(11)
                  .fontColor(this.statusFilter.length === 0 ? AppColor.OnBrand : $r('sys.color.font_secondary'))
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .borderRadius(AppRadius.Pill)
                  .backgroundColor(this.statusFilter.length === 0 ? AppColor.Brand
                    : $r('sys.color.comp_background_tertiary'))
                  .border({ width: 1, color: this.statusFilter.length === 0 ? AppColor.Brand : AppColor.Divider })
                  .onClick(() => {
                    this.statusFilter = ''
                    this.reload()
                  })
                ForEach(['wish', 'doing', 'done'], (status: string, index: number) => {
                  Text(this.statusLabels()[index])
                    .fontSize(11)
                    .fontColor(this.statusFilter === status ? AppColor.OnBrand : $r('sys.color.font_secondary'))
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(AppRadius.Pill)
                    .backgroundColor(this.statusFilter === status ? AppColor.Brand
                      : $r('sys.color.comp_background_tertiary'))
                    .border({ width: 1, color: this.statusFilter === status ? AppColor.Brand : AppColor.Divider })
                    .onClick(() => {
                      this.statusFilter = this.statusFilter === status ? '' : status
                      this.reload()
                    })
                }, (status: string) => status + this.statusFilter)
                Blank()
                Text('排序')
                  .fontSize(11)
                  .fontColor($r('sys.color.font_tertiary'))
              }
              .width('100%')
              OptionChips({
                options: ['最近添加', '评分最高', '年份最新', '标题'],
                selected: this.sortIndex,
                onSelect: (index: number) => {
                  this.sortIndex = index
                  this.reload()
                }
              })
              TextInput({ placeholder: '搜索标题或短评…', text: this.keyword })
                .placeholderColor($r('sys.color.font_tertiary'))
                .fontColor($r('sys.color.font_primary'))
                .fontSize(13)
                .backgroundColor($r('sys.color.comp_background_tertiary'))
                .borderRadius(AppRadius.Md)
                .border({ width: 1, color: AppColor.Divider })
                .height(40)
                .align(Alignment.Start)
                .onChange((value: string) => {
                  this.keyword = value
                })
                .onSubmit(() => {
                  this.reload()
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 4 })

            if (this.loading) {
              EmptyView({ icon: '⏳', text: '加载中…' })
            } else if (this.items.length === 0) {
              EmptyView({ icon: '🎬', text: '暂无收藏' })
            } else {
              GridRow({ columns: 2, gutter: 10 }) {
                ForEach(this.items, (item: CollectionItem) => {
                  GridCol({ span: 1 }) {
                    TechCard({ paddingV: 0, radius: AppRadius.Lg }) {
                      Column({ space: 0 }) {
                        // 封面
                        Stack({ alignContent: Alignment.Center }) {
                          Column({ space: 6 }) {
                            Text(typeEmoji(item.type))
                              .fontSize(30)
                            Text(item.title.substring(0, 1))
                              .fontSize(AppFont.TitleL)
                              .fontWeight(FontWeight.Bold)
                              .fontColor($r('sys.color.font_primary'))
                          }
                          .width('100%')
                          .height(150)
                          .linearGradient({ angle: 150, colors: [[AppColor.BrandDark, 0.0], [AppColor.Brand, 1.0]] })
                          if (item.coverUrl !== null && item.coverUrl !== undefined && item.coverUrl.length > 0) {
                            Image(item.coverUrl)
                              .width('100%')
                              .height(150)
                              .objectFit(ImageFit.Cover)
                          }
                        }
                        .width('100%')

                        Column({ space: 6 }) {
                          Text(item.title)
                            .fontSize(13)
                            .fontWeight(FontWeight.Bold)
                            .fontColor($r('sys.color.font_primary'))
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .width('100%')
                          Row({ space: 6 }) {
                            Stars({ rating: item.rating === null || item.rating === undefined ? 0 : item.rating })
                            if (item.year !== null && item.year !== undefined) {
                              Text(item.year.toString())
                                .fontSize(10)
                                .fontColor($r('sys.color.font_tertiary'))
                            }
                          }
                          Row({ space: 6 }) {
                            Text(this.statusLabelOf(item))
                              .fontSize(10)
                              .fontColor(AppColor.Brand)
                              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                              .borderRadius(AppRadius.Pill)
                              .border({ width: 1, color: AppColor.Brand })
                              .onClick(() => {
                                this.cycleStatus(item)
                              })
                            Blank()
                            Text('✎')
                              .fontSize(AppFont.Caption)
                              .fontColor(AppColor.Brand)
                              .onClick(() => {
                                this.openEdit(item)
                              })
                          }
                          .width('100%')
                        }
                        .padding(10)
                      }
                    }
                  }
                  .margin({ bottom: 10 })
                }, (item: CollectionItem) => item.id.toString() + '-' + item.status + '-' + item.updatedAt)
              }
              .width('100%')
              .padding({ top: 10 })
            }
          }
          .padding({ left: PAGE_PAD_H, right: PAGE_PAD_H, bottom: PAGE_SCROLL_BOTTOM })
          .constraintSize({ minHeight: '100%' })
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
      .onRefreshing(() => {
        this.reload()
      })
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .bindSheet($$this.showForm, this.formBuilder(), {
      height: 660,
      dragBar: true,
      preferType: SheetType.BOTTOM,
      backgroundColor: AppMaterial.SheetBackground,
      blurStyle: AppMaterial.SheetBlur,
      systemMaterial: AppMaterial.Sheet
    })
  }

  @Builder
  formBuilder() {
    Scroll() {
      Column() {
        SheetHeader({ title: this.formId === 0 ? '添加收藏' : '编辑收藏' })

        Text('类型').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 14, bottom: 6 })
        OptionChips({
          options: ['书籍', '影视', '音乐'],
          selected: this.formTypeIndex - 1,
          onSelect: (index: number) => {
            this.formTypeIndex = index + 1
          }
        })

        Text('标题').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
        TextInput({ placeholder: '书名 / 片名 / 专辑名', text: this.formTitle })
          .placeholderColor($r('sys.color.font_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .fontSize(AppFont.Body)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(AppRadius.Md)
          .border({ width: 1, color: AppColor.Divider })
          .height(42)
          .align(Alignment.Start)
          .onChange((value: string) => {
            this.formTitle = value
          })

        Text('状态').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
        OptionChips({
          options: ['想' + Options.collectionStatusLabel('wish', TYPE_KEYS[this.formTypeIndex]).substring(1),
            Options.collectionStatusLabel('doing', TYPE_KEYS[this.formTypeIndex]),
            Options.collectionStatusLabel('done', TYPE_KEYS[this.formTypeIndex])],
          selected: this.formStatus === 'wish' ? 0 : this.formStatus === 'doing' ? 1 : 2,
          onSelect: (index: number) => {
            this.formStatus = ['wish', 'doing', 'done'][index]
          }
        })

        Text('评分').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
        StarPicker({
          value: this.formRating,
          onChange: (value: number) => {
            this.formRating = value
          }
        })

        Row({ space: 10 }) {
          Column() {
            Text('年份').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ bottom: 6 })
            TextInput({ placeholder: '2025', text: this.formYear })
              .placeholderColor($r('sys.color.font_tertiary'))
              .fontColor($r('sys.color.font_primary'))
              .fontSize(AppFont.Body)
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .borderRadius(AppRadius.Md)
              .border({ width: 1, color: AppColor.Divider })
              .height(42)
              .align(Alignment.Start)
              .type(InputType.Number)
              .onChange((value: string) => {
                this.formYear = value
              })
          }
          .layoutWeight(1)
          Column() {
            Text('封面链接（可选）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ bottom: 6 })
            TextInput({ placeholder: 'https://…', text: this.formCover })
              .placeholderColor($r('sys.color.font_tertiary'))
              .fontColor($r('sys.color.font_primary'))
              .fontSize(AppFont.Caption)
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .borderRadius(AppRadius.Md)
              .border({ width: 1, color: AppColor.Divider })
              .height(42)
              .align(Alignment.Start)
              .onChange((value: string) => {
                this.formCover = value
              })
          }
          .layoutWeight(2)
        }
        .width('100%')

        Text('短评（可选）').fontSize(AppFont.Caption).fontColor($r('sys.color.font_secondary')).margin({ top: 12, bottom: 6 })
        TextArea({ placeholder: '一句话感想…', text: this.formComment })
          .placeholderColor($r('sys.color.font_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .fontSize(13)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(AppRadius.Md)
          .border({ width: 1, color: AppColor.Divider })
          .height(76)
          .onChange((value: string) => {
            this.formComment = value
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
            label: '删除该收藏',
            onDelete: (): void => {
              this.removeCollection(this.formId)
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
      .constraintSize({ minHeight: '100%' })
    }
    .scrollBar(BarState.Off)
    .height('100%')
  }
}
