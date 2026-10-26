import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Session } from '../store/Session';

const DOMAIN = 0x0000;
const TAG = 'BrowserHistory';
/** 最近访问保留条数 */
const MAX_HISTORY = 30;

export interface BrowserHistoryEntry {
  url: string;
  title: string;
  ts: number;
}

interface BrowserHistoryStore {
  items: BrowserHistoryEntry[];
}

/**
 * 浏览器最近访问：按账号存 filesDir JSON，全本地离线，不上传服务器。
 * 只记 http/https 主文档地址，同地址重复访问时置顶并更新时间。
 */
export class BrowserHistoryService {
  private static baseDir: string = '';
  private static items: BrowserHistoryEntry[] | null = null;
  private static loadedUser: number = -1;

  /** EntryAbility 启动时调用，仅记录数据目录 */
  static init(context: common.Context): void {
    BrowserHistoryService.baseDir = context.filesDir;
  }

  static list(): BrowserHistoryEntry[] {
    return BrowserHistoryService.ensure();
  }

  static push(url: string, title: string): void {
    if (url.length === 0 || !BrowserHistoryService.isWebUrl(url)) {
      return;
    }
    const current: BrowserHistoryEntry[] = BrowserHistoryService.ensure();
    const entry: BrowserHistoryEntry = {
      url: url,
      title: title.length > 0 ? title : BrowserHistoryService.hostOf(url),
      ts: Date.now()
    };
    const next: BrowserHistoryEntry[] = [entry];
    for (const item of current) {
      if (item.url !== url && next.length < MAX_HISTORY) {
        next.push(item);
      }
    }
    BrowserHistoryService.items = next;
    BrowserHistoryService.save();
  }

  static clear(): void {
    BrowserHistoryService.items = [];
    BrowserHistoryService.save();
  }

  static hostOf(url: string): string {
    const withoutScheme: string = url.replace(/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//, '');
    const host: string = withoutScheme.split('/')[0].split('?')[0];
    return host.length > 0 ? host : url;
  }

  static isWebUrl(url: string): boolean {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /** 地址栏输入转换：网址直连，其余走必应搜索 */
  static toTargetUrl(raw: string): string {
    const text: string = raw.trim();
    if (text.length === 0) {
      return '';
    }
    if (/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//.test(text)) {
      return text;
    }
    const hasSpace: boolean = /\s/.test(text);
    const looksDomain: boolean = /^[^\s]+\.[^\s]{2,}(:\d+)?([/?#].*)?$/.test(text);
    if (!hasSpace && looksDomain) {
      return 'https://' + text;
    }
    return 'https://cn.bing.com/search?q=' + encodeURIComponent(text);
  }

  private static currentUserId(): number {
    const user = Session.user;
    return user === null ? 0 : user.id;
  }

  private static ensure(): BrowserHistoryEntry[] {
    const userId: number = BrowserHistoryService.currentUserId();
    if (BrowserHistoryService.items !== null && BrowserHistoryService.loadedUser === userId) {
      return BrowserHistoryService.items;
    }
    BrowserHistoryService.loadedUser = userId;
    BrowserHistoryService.items = BrowserHistoryService.load(userId);
    return BrowserHistoryService.items;
  }

  private static load(userId: number): BrowserHistoryEntry[] {
    const path = BrowserHistoryService.filePath(userId);
    if (path.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(fileIo.readTextSync(path)) as BrowserHistoryStore;
      if (parsed === null || !Array.isArray(parsed.items)) {
        return [];
      }
      return parsed.items;
    } catch (err) {
      // 首次使用文件不存在或缓存损坏，均视为空
      return [];
    }
  }

  private static save(): void {
    const userId: number = BrowserHistoryService.currentUserId();
    const path = BrowserHistoryService.filePath(userId);
    if (path.length === 0) {
      return;
    }
    const items: BrowserHistoryEntry[] = BrowserHistoryService.items === null ? [] : BrowserHistoryService.items;
    const store: BrowserHistoryStore = { items: items };
    try {
      const file = fileIo.openSync(path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, JSON.stringify(store));
      } finally {
        fileIo.closeSync(file);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'save failed: %{public}s',
        err instanceof Error ? err.message : JSON.stringify(err));
    }
  }

  private static filePath(userId: number): string {
    if (BrowserHistoryService.baseDir.length === 0 || userId <= 0) {
      return '';
    }
    return BrowserHistoryService.baseDir + '/browser_history_u' + userId.toString() + '.json';
  }
}
