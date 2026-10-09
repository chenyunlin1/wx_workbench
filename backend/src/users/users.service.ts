import { ConflictException, Injectable, NotFoundException } from '@nestjs/common'
import { InjectRepository } from '@nestjs/typeorm'
import * as bcrypt from 'bcryptjs'
import { Repository } from 'typeorm'
import { User } from '../entities'
import { CreateUserDto } from './dto/create-user.dto'
import { UpdateProfileDto } from './dto/update-profile.dto'
import { UpdateUserDto } from './dto/update-user.dto'

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async findAll() {
    return this.userRepository.find({ order: { createdAt: 'DESC' } })
  }

  async findById(id: number) {
    return this.userRepository.findOne({ where: { id } })
  }

  async findByUsername(username: string) {
    return this.userRepository.findOne({ where: { username } })
  }

  async findByUsernameWithPassword(username: string) {
    return this.userRepository
      .createQueryBuilder('user')
      .addSelect('user.password')
      .where('user.username = :username', { username })
      .getOne()
  }

  async create(dto: CreateUserDto) {
    const existing = await this.findByUsername(dto.username)
    if (existing) throw new ConflictException('用户名已存在')

    const user = this.userRepository.create({
      username: dto.username,
      password: await bcrypt.hash(dto.password, 10),
      role: dto.role,
      avatar: dto.avatar ?? null,
    })

    const saved = await this.userRepository.save(user)
    return this.removePassword(saved)
  }

  async update(id: number, dto: UpdateUserDto) {
    const user = await this.userRepository.findOne({ where: { id } })
    if (!user) throw new NotFoundException('用户不存在')

    if (dto.username && dto.username !== user.username) {
      const duplicate = await this.findByUsername(dto.username)
      if (duplicate) throw new ConflictException('用户名已存在')
    }

    Object.assign(user, {
      username: dto.username ?? user.username,
      role: dto.role ?? user.role,
      avatar: dto.avatar ?? user.avatar,
      ...(dto.password ? { password: await bcrypt.hash(dto.password, 10) } : {}),
    })

    await this.userRepository.save(user)
    return this.findById(id)
  }

  /** 本人修改资料：昵称 / 头像（空值即清除） */
  async updateProfile(id: number, dto: UpdateProfileDto) {
    const user = await this.userRepository.findOne({ where: { id } })
    if (!user) throw new NotFoundException('用户不存在')

    if (dto.nickname !== undefined) user.nickname = dto.nickname.trim() || null
    if (dto.avatar !== undefined) user.avatar = dto.avatar.trim() || null

    const saved = await this.userRepository.save(user)
    return this.removePassword(saved)
  }

  async remove(id: number) {
    const result = await this.userRepository.delete(id)
    if (!result.affected) throw new NotFoundException('用户不存在')
    return { success: true }
  }

  private removePassword(user: User) {
    const { password: _password, ...safeUser } = user
    return safeUser
  }
}