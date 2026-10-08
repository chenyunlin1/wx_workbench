import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { User } from '../model/Models'
import { toast } from '../common/AppKit'

const KEY_TOKEN = 'auth_token'
const KEY_USER = 'auth_user'
const KEY_SERVER = 'server_url'
const PREF_NAME = 'workbench_prefs'

/**
 * 全局会话：Token / 用户 / 服务器地址。
 * EntryAbility.onCreate 时调用 Session.init()。
 */
export class Session {
  static token: string = ''
  static user: User | null = null
  static serverUrl: string = 'http://10.0.2.2:3000'
  private static prefs: preferences.Preferences | null = null

  static init(context: common.Context): void {
    Session.prefs = preferences.getPreferencesSync(context, { name: PREF_NAME })
    Session.token = Session.prefs.getSync(KEY_TOKEN, '') as string
    Session.serverUrl = Session.prefs.getSync(KEY_SERVER, 'http://10.0.2.2:3000') as string
    const userJson = Session.prefs.getSync(KEY_USER, '') as string
    if (userJson.length > 0) {
      try {
        Session.user = JSON.parse(userJson) as User
      } catch (err) {
        Session.user = null
      }
    }
    AppStorage.setOrCreate('hasToken', Session.token.length > 0)
    AppStorage.setOrCreate('dataVersion', 0)
  }

  static isLoggedIn(): boolean {
    return Session.token.length > 0
  }

  static username(): string {
    return Session.user === null ? '' : Session.user.username
  }

  static isAdmin(): boolean {
    return Session.user !== null && Session.user.role === 'admin'
  }

  static login(token: string, user: User): void {
    Session.token = token
    Session.user = user
    Session.writeString(KEY_TOKEN, token)
    Session.writeString(KEY_USER, JSON.stringify(user))
    AppStorage.setOrCreate('hasToken', true)
  }

  /** 登录过期 / 主动退出 */
  static logout(expired: boolean): void {
    Session.token = ''
    Session.user = null
    Session.writeString(KEY_TOKEN, '')
    Session.writeString(KEY_USER, '')
    AppStorage.setOrCreate('hasToken', false)
    if (expired) {
      toast('登录已过期，请重新登录')
    }
  }

  static setServerUrl(url: string): void {
    const trimmed = url.replace(/\/+$/, '')
    Session.serverUrl = trimmed
    Session.writeString(KEY_SERVER, trimmed)
  }

  /** 触发首页等监听方刷新 */
  static bumpDataVersion(): void {
    const current = AppStorage.get<number>('dataVersion')
    AppStorage.setOrCreate('dataVersion', (current === undefined ? 0 : current) + 1)
  }

  private static writeString(key: string, value: string): void {
    if (Session.prefs === null) {
      return
    }
    Session.prefs.putSync(key, value)
    Session.prefs.flush()
  }
}
