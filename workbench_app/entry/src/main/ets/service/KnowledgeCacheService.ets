import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { KnowledgeItem } from '../model/Models';
import { Api } from '../api/Api';
import { Session } from '../store/Session';

const DOMAIN = 0x0000;
const TAG = 'KnowledgeCache';
const SYNC_PAGE_SIZE = 100;
const MAX_SYNC_PAGES = 50;

/**
 * 知识库本地缓存：按用户把全量条目存成 filesDir 下的 JSON 文件。
 * 页面默认读缓存；下拉刷新调 syncFromServer() 逐页拉全量覆盖本地。
 */
export class KnowledgeCacheService {
  private static baseDir: string = '';

  /** EntryAbility 启动时调用，仅记录缓存目录 */
  static init(context: common.Context): void {
    KnowledgeCacheService.baseDir = context.filesDir;
  }

  static load(): KnowledgeItem[] {
    const path = KnowledgeCacheService.filePath();
    if (path.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(fileIo.readTextSync(path)) as KnowledgeItem[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (err) {
      // 首次使用文件不存在或缓存损坏，均视为空
      return [];
    }
  }

  static save(items: KnowledgeItem[]): void {
    const path = KnowledgeCacheService.filePath();
    if (path.length === 0) {
      return;
    }
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, JSON.stringify(items));
      } finally {
        fileIo.closeSync(file);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'save failed: %{public}s', err instanceof Error ? err.message : JSON.stringify(err));
    }
  }

  static findById(id: number): KnowledgeItem | undefined {
    for (const item of KnowledgeCacheService.load()) {
      if (item.id === id) {
        return item;
      }
    }
    return undefined;
  }

  static upsert(item: KnowledgeItem): void {
    const items = KnowledgeCacheService.load();
    const next: KnowledgeItem[] = [];
    let replaced = false;
    for (const existing of items) {
      if (existing.id === item.id) {
        next.push(item);
        replaced = true;
      } else {
        next.push(existing);
      }
    }
    if (!replaced) {
      next.push(item);
    }
    KnowledgeCacheService.save(next);
  }

  static remove(id: number): void {
    const items = KnowledgeCacheService.load();
    const next = items.filter((item: KnowledgeItem) => item.id !== id);
    if (next.length !== items.length) {
      KnowledgeCacheService.save(next);
    }
  }

  /** 汇总缓存内全部标签，规则与服务端 /knowledge/tags 一致（去重、trim、zh-CN 排序） */
  static tagsOf(items: KnowledgeItem[]): string[] {
    const seen = new Set<string>();
    for (const item of items) {
      for (const tag of item.tags) {
        const trimmed = tag.trim();
        if (trimmed.length > 0) {
          seen.add(trimmed);
        }
      }
    }
    const result: string[] = [];
    seen.forEach((tag: string) => {
      result.push(tag);
    });
    return result.sort((a: string, b: string): number => a.localeCompare(b, 'zh-CN'));
  }

  /** 逐页拉取线上全量知识库并覆盖本地缓存，返回最新列表 */
  static async syncFromServer(): Promise<KnowledgeItem[]> {
    let collected: KnowledgeItem[] = [];
    let page = 1;
    while (page <= MAX_SYNC_PAGES) {
      const query: Record<string, string> = {
        'page': page.toString(),
        'pageSize': SYNC_PAGE_SIZE.toString(),
        'sortBy': 'updatedAt'
      };
      const result = await Api.listKnowledge(query);
      collected = collected.concat(result.items);
      if (result.items.length === 0 || collected.length >= result.total) {
        break;
      }
      page += 1;
    }
    KnowledgeCacheService.save(collected);
    return collected;
  }

  private static filePath(): string {
    if (KnowledgeCacheService.baseDir.length === 0) {
      return '';
    }
    const user = Session.user;
    if (user === null || user.id <= 0) {
      return '';
    }
    return KnowledgeCacheService.baseDir + '/knowledge_cache_u' + user.id.toString() + '.json';
  }
}
