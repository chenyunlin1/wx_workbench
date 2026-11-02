import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { User } from '../model/Models'
import { toast } from '../common/AppKit'

const KEY_TOKEN = 'auth_token'
const KEY_REFRESH_TOKEN = 'auth_refresh_token'
const KEY_USER = 'auth_user'
const KEY_SERVER = 'server_url'
const PREF_NAME = 'workbench_prefs'

/**
 * 全局会话：Token / 用户 / 服务器地址。
 * EntryAbility.onCreate 时调用 Session.init()。
 * @ObservedV2 + @Trace：页面在 build 中读取 Session.token 等属性即自动订阅变更；
 * dataVersion 用于增删改后通知页签重载（@Monitor('session.dataVersion')）。
 */
@ObservedV2
export class SessionStore {
  @Trace token: string = ''
  /** 续期令牌：accessToken 过期时用它换一套新令牌，用户不会被打回登录页 */
  @Trace refreshToken: string = ''
  @Trace user: User | null = null
  @Trace serverUrl: string = 'http://10.0.2.2:3000'
  @Trace dataVersion: number = 0
  private prefs: preferences.Preferences | null = null

  init(context: common.Context): void {
    this.prefs = preferences.getPreferencesSync(context, { name: PREF_NAME })
    this.token = this.prefs.getSync(KEY_TOKEN, '') as string
    this.refreshToken = this.prefs.getSync(KEY_REFRESH_TOKEN, '') as string
    this.serverUrl = this.prefs.getSync(KEY_SERVER, 'http://10.0.2.2:3000') as string
    const userJson = this.prefs.getSync(KEY_USER, '') as string
    if (userJson.length > 0) {
      try {
        this.user = JSON.parse(userJson) as User
      } catch (err) {
        this.user = null
      }
    }
  }

  isLoggedIn(): boolean {
    return this.token.length > 0
  }

  username(): string {
    return this.user === null ? '' : this.user.username
  }

  /** 显示名：昵称优先，未设置时回退用户名 */
  displayName(): string {
    if (this.user === null) {
      return ''
    }
    const nickname = this.user.nickname
    if (nickname !== undefined && nickname !== null && nickname.length > 0) {
      return nickname
    }
    return this.user.username
  }

  /** 资料修改成功后刷新本地用户缓存 */
  updateUser(user: User): void {
    this.user = user
    this.writeString(KEY_USER, JSON.stringify(user))
  }

  isAdmin(): boolean {
    return this.user !== null && this.user.role === 'admin'
  }

  login(token: string, refreshToken: string, user: User): void {
    this.token = token
    this.refreshToken = refreshToken
    this.user = user
    this.writeString(KEY_TOKEN, token)
    this.writeString(KEY_REFRESH_TOKEN, refreshToken)
    this.writeString(KEY_USER, JSON.stringify(user))
  }

  /** 续期成功：换新 accessToken，服务端发了新 refreshToken 才一起换 */
  setTokens(accessToken: string, refreshToken: string): void {
    this.token = accessToken
    this.writeString(KEY_TOKEN, accessToken)
    if (refreshToken.length > 0) {
      this.refreshToken = refreshToken
      this.writeString(KEY_REFRESH_TOKEN, refreshToken)
    }
  }

  /** 登录过期 / 主动退出 */
  logout(expired: boolean): void {
    this.token = ''
    this.refreshToken = ''
    this.user = null
    this.writeString(KEY_TOKEN, '')
    this.writeString(KEY_REFRESH_TOKEN, '')
    this.writeString(KEY_USER, '')
    if (expired) {
      toast('登录已过期，请重新登录')
    }
  }

  setServerUrl(url: string): void {
    const trimmed = url.replace(/\/+$/, '')
    this.serverUrl = trimmed
    this.writeString(KEY_SERVER, trimmed)
  }

  /** 触发页签数据重载 */
  bumpDataVersion(): void {
    this.dataVersion += 1
  }

  private writeString(key: string, value: string): void {
    if (this.prefs === null) {
      return
    }
    this.prefs.putSync(key, value)
    this.prefs.flush()
  }
}

export const Session: SessionStore = new SessionStore()
