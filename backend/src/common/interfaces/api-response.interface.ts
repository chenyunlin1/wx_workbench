export interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

export interface JwtPayload {
  sub: number
  username: string
  role: string
}