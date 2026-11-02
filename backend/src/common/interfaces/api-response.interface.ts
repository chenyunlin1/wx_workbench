export interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

export interface JwtPayload {
  sub: number
  username: string
  role: string
  /** 仅刷新令牌带这个字段；访问令牌必须为空，否则不能用于业务接口 */
  type?: string
}