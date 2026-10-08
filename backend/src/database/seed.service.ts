import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import * as bcrypt from 'bcryptjs'
import { DataSource } from 'typeorm'
import { Collection, CollectionStatus, CollectionType } from '../collection/collection.entity'
import {
  Finance,
  FinanceType,
  Habit,
  HabitRecord,
  Health,
  Interview,
  InterviewStatus,
  LearningStatus,
  LearningTask,
  Schedule,
  ShoppingItem,
  ShoppingStatus,
  User,
  UserRole,
} from '../entities'
import { Knowledge, KnowledgeType } from '../knowledge/knowledge.entity'
import { OpsCommand } from '../ops/ops-command.entity'
import {
  Workout,
  WorkoutIntensity,
  WorkoutType,
} from '../workout/workout.entity'

const formatDate = (date: Date) => {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

@Injectable()
export class SeedService implements OnApplicationBootstrap {
  private readonly logger = new Logger(SeedService.name)

  constructor(
    private readonly dataSource: DataSource,
    private readonly configService: ConfigService,
  ) {}

  async onApplicationBootstrap() {
    const enabled = this.configService.get<string>('SEED_DEMO_DATA', 'true') === 'true'
    if (!enabled) return

    const userRepository = this.dataSource.getRepository(User)
    let admin = await userRepository.findOne({ where: { username: 'admin' } })

    if (!admin) {
      admin = await userRepository.save(
        userRepository.create({
          username: 'admin',
          password: await bcrypt.hash('admin123', 10),
          avatar: null,
          role: UserRole.ADMIN,
        }),
      )
      this.logger.log('已创建演示管理员账号：admin / admin123')
    }

    const scheduleRepository = this.dataSource.getRepository(Schedule)
    const existingCount = await scheduleRepository.count({ where: { userId: admin.id } })
    if (existingCount === 0) {
      await this.seedUserData(admin.id)
      this.logger.log('基础演示数据初始化完成')
    }

    await this.seedKnowledgeData(admin.id)
    this.logger.log('学习知识库演示数据已就绪')

    await this.seedCollectionData(admin.id)
    this.logger.log('书影音收藏演示数据已就绪')

    await this.seedHabitHistoryData(admin.id)
    await this.seedWorkoutData(admin.id)
    this.logger.log('习惯打卡历史与健身训练演示数据已就绪')

    await this.seedOpsCommandData(admin.id)
    this.logger.log('运维速查常用命令已就绪')
  }

  private async seedUserData(userId: number) {
    const now = new Date()
    const today = formatDate(now)

    const at = (dayOffset: number, hour: number, minute = 0) =>
      new Date(now.getFullYear(), now.getMonth(), now.getDate() + dayOffset, hour, minute)

    const scheduleRepository = this.dataSource.getRepository(Schedule)
    await scheduleRepository.save([
      scheduleRepository.create({
        title: '项目进度同步',
        description: '梳理本周里程碑与风险项',
        startTime: at(0, 9, 30),
        endTime: at(0, 10, 15),
        userId,
      }),
      scheduleRepository.create({
        title: '后端接口联调',
        description: '完成 Dashboard 聚合接口联调',
        startTime: at(0, 14),
        endTime: at(0, 15, 30),
        userId,
      }),
      scheduleRepository.create({
        title: '晚间复盘',
        description: '记录今天的三点收获',
        startTime: at(0, 21),
        endTime: at(0, 21, 30),
        userId,
      }),
    ])

    const habitRepository = this.dataSource.getRepository(Habit)
    const habits = await habitRepository.save([
      habitRepository.create({ name: '早起', icon: '🌅', streakDays: 12, userId }),
      habitRepository.create({ name: '阅读 30 分钟', icon: '📖', streakDays: 8, userId }),
      habitRepository.create({ name: '运动', icon: '🏃', streakDays: 5, userId }),
    ])
    const recordRepository = this.dataSource.getRepository(HabitRecord)
    await recordRepository.save(
      recordRepository.create({ habitId: habits[0].id, checkInDate: today }),
    )

    const learningRepository = this.dataSource.getRepository(LearningTask)
    await learningRepository.save([
      learningRepository.create({
        title: '报表异常排查与修复',
        duration: 45,
        status: LearningStatus.DOING,
        userId,
      }),
      learningRepository.create({
        title: 'JVM 调优，String 基础问题',
        duration: 60,
        status: LearningStatus.DONE,
        userId,
      }),
      learningRepository.create({
        title: 'TypeScript 类型体操练习',
        duration: 30,
        status: LearningStatus.TODO,
        userId,
      }),
    ])

    const interviewRepository = this.dataSource.getRepository(Interview)
    await interviewRepository.save([
      interviewRepository.create({
        company: '星河科技',
        position: '高级前端工程师',
        interviewTime: at(3, 14),
        status: InterviewStatus.PENDING,
        userId,
      }),
      interviewRepository.create({
        company: '云启网络',
        position: '全栈开发工程师',
        interviewTime: at(6, 10, 30),
        status: InterviewStatus.PENDING,
        userId,
      }),
    ])

    const financeRepository = this.dataSource.getRepository(Finance)
    const monthDay = (day: number) =>
      new Date(now.getFullYear(), now.getMonth(), day, 12, 0, 0)
    await financeRepository.save([
      financeRepository.create({
        type: FinanceType.INCOME,
        amount: 18000,
        category: '薪资',
        remark: '本月工资',
        recordDate: monthDay(5),
        userId,
      }),
      financeRepository.create({
        type: FinanceType.EXPENSE,
        amount: 3200,
        category: '住房',
        remark: '房租',
        recordDate: monthDay(3),
        userId,
      }),
      financeRepository.create({
        type: FinanceType.EXPENSE,
        amount: 680,
        category: '餐饮',
        remark: '和朋友吃饭',
        recordDate: now,
        userId,
      }),
    ])

    const healthRepository = this.dataSource.getRepository(Health)
    const weights = [74.8, 74.6, 74.5, 74.2, 74.1, 73.9, 73.8]
    await healthRepository.save(
      weights.map((weight, index) =>
        healthRepository.create({
          weight,
          recordDate: formatDate(
            new Date(now.getFullYear(), now.getMonth(), now.getDate() - (6 - index)),
          ),
          userId,
        }),
      ),
    )

    const shoppingRepository = this.dataSource.getRepository(ShoppingItem)
    await shoppingRepository.save([
      shoppingRepository.create({
        name: '机械键盘',
        price: 399,
        status: ShoppingStatus.PENDING,
        userId,
      }),
      shoppingRepository.create({
        name: '运动耳机',
        price: 259,
        status: ShoppingStatus.PENDING,
        userId,
      }),
      shoppingRepository.create({
        name: '桌面收纳架',
        price: 89,
        status: ShoppingStatus.PENDING,
        userId,
      }),
    ])
  }
  private async seedKnowledgeData(userId: number) {
    const repository = this.dataSource.getRepository(Knowledge)
    const existingCount = await repository.count({ where: { userId } })
    if (existingCount > 0) return

    const seedDate = new Date('2026-09-05T10:00:00+08:00')
    await repository.save([
      repository.create({
        type: KnowledgeType.NOTE,
        title: 'Vue3 响应式原理 | ref 与 reactive 的区别',
        content:
          'ref 用于定义基本类型，reactive 用于定义对象类型。ref 返回 RefImpl 对象，reactive 返回 Proxy 对象，reactive 解构会丢失响应式……',
        tags: ['Vue3', 'TypeScript'],
        isLearned: false,
        views: 18,
        createdAt: seedDate,
        updatedAt: seedDate,
        userId,
      }),
      repository.create({
        type: KnowledgeType.QA,
        title: 'JavaScript 中 var、let、const 的区别是什么？',
        content:
          '- var 存在变量提升，let/const 不存在；- let/const 存在暂时性死区；- const 声明必须初始化且不能重新赋值……',
        tags: ['JavaScript', '前端基础'],
        isLearned: false,
        views: 12,
        createdAt: seedDate,
        updatedAt: seedDate,
        userId,
      }),
      repository.create({
        type: KnowledgeType.QA,
        title: 'NestJS 中 Module、Controller、Service 的职责是什么？',
        content:
          'Module 负责组织代码，Controller 处理 HTTP 请求与参数校验，Service 负责业务逻辑。NestJS 使用依赖注入 (DI) 解耦这些组件……',
        tags: ['NestJS', 'Node.js'],
        isLearned: false,
        views: 9,
        createdAt: seedDate,
        updatedAt: seedDate,
        userId,
      }),
      repository.create({
        type: KnowledgeType.QA,
        title: 'TypeORM 中 Entity 和 Repository 的关系是什么？',
        content:
          'Entity 是数据库表的映射类，Repository 是操作 Entity 的仓库，提供 find / save / delete 等方法，通过 @InjectRepository 注入到 Service……',
        tags: ['TypeORM', 'MySQL'],
        isLearned: false,
        views: 7,
        createdAt: seedDate,
        updatedAt: seedDate,
        userId,
      }),
    ])
  }

  private async seedCollectionData(userId: number) {
    const repository = this.dataSource.getRepository(Collection)
    const existingCount = await repository.count({ where: { userId } })
    if (existingCount > 0) return

    const now = new Date()
    // 分散在本年度内，让年度统计有数据
    const at = (monthsAgo: number, day: number) =>
      new Date(now.getFullYear(), Math.max(0, now.getMonth() - monthsAgo), day, 20, 0, 0)

    const items: Array<Partial<Collection>> = [
      {
        type: CollectionType.BOOK,
        title: '置身事内：中国政府与经济发展',
        status: CollectionStatus.DONE,
        rating: 5,
        year: 2021,
        comment: '把地方财政讲得通俗易懂，读完对很多新闻有了新的理解。',
      },
      {
        type: CollectionType.BOOK,
        title: '人类简史',
        status: CollectionStatus.DONE,
        rating: 4,
        year: 2014,
        comment: '视角宏大，后半段稍显仓促。',
      },
      {
        type: CollectionType.BOOK,
        title: '代码整洁之道',
        status: CollectionStatus.DOING,
        rating: null,
        year: 2008,
        comment: '正在读第 6 章，配合重构练习效果更好。',
      },
      {
        type: CollectionType.MOVIE,
        title: '星际穿越',
        status: CollectionStatus.DONE,
        rating: 5,
        year: 2014,
        comment: '五维空间那段依然震撼，配乐满分。',
      },
      {
        type: CollectionType.MOVIE,
        title: '沙丘 2',
        status: CollectionStatus.WISH,
        rating: null,
        year: 2024,
        comment: '等周末去影院补上。',
      },
      {
        type: CollectionType.MUSIC,
        title: '范特西',
        status: CollectionStatus.DONE,
        rating: 5,
        year: 2001,
        comment: '二十多年后再听依然不过时。',
      },
      {
        type: CollectionType.MUSIC,
        title: 'Random Access Memories',
        status: CollectionStatus.DONE,
        rating: 4,
        year: 2013,
        comment: '写代码时的循环专辑。',
      },
    ]

    await repository.save(
      items.map((item, index) =>
        repository.create({
          ...item,
          createdAt: at(Math.min(index, Math.max(0, now.getMonth())), 6 + index),
          userId,
        }),
      ),
    )
  }

  /** 为已有习惯补最近两周的打卡历史，让热力图与完成率有数据 */
  private async seedHabitHistoryData(userId: number) {
    const habitRepository = this.dataSource.getRepository(Habit)
    const habits = await habitRepository.find({ where: { userId } })
    if (!habits.length) return

    const recordRepository = this.dataSource.getRepository(HabitRecord)
    const now = new Date()
    const today = formatDate(now)

    const pastCount = await recordRepository
      .createQueryBuilder('record')
      .where('record.habitId IN (:...ids)', { ids: habits.map((habit) => habit.id) })
      .andWhere('record.checkInDate < :today', { today })
      .getCount()
    if (pastCount > 0) return

    const rows: HabitRecord[] = []
    habits.forEach((habit, habitIndex) => {
      for (let offset = 1; offset <= 14; offset += 1) {
        // 留出一些空缺，热力图看起来更真实
        if ((offset + habitIndex * 2) % 5 === 0) continue
        rows.push(
          recordRepository.create({
            habitId: habit.id,
            checkInDate: formatDate(
              new Date(now.getFullYear(), now.getMonth(), now.getDate() - offset),
            ),
          }),
        )
      }
    })

    if (rows.length) await recordRepository.save(rows)
  }

  /** 最近一段时间的健身训练记录 */
  private async seedWorkoutData(userId: number) {
    const repository = this.dataSource.getRepository(Workout)
    const existingCount = await repository.count({ where: { userId } })
    if (existingCount > 0) return

    const now = new Date()
    const at = (dayOffset: number, hour: number, minute = 0) =>
      new Date(now.getFullYear(), now.getMonth(), now.getDate() - dayOffset, hour, minute)

    const items: Array<Partial<Workout>> = [
      {
        type: WorkoutType.RUNNING,
        title: '晨跑 5 公里',
        duration: 32,
        calories: 320,
        distance: 5.2,
        intensity: WorkoutIntensity.MEDIUM,
        workoutDate: at(0, 7, 10),
        note: '配速 6:10，最后 1 公里加速。',
      },
      {
        type: WorkoutType.STRENGTH,
        title: '上肢力量',
        duration: 50,
        calories: 280,
        intensity: WorkoutIntensity.HIGH,
        workoutDate: at(1, 20, 0),
        note: '卧推 4 组，引体向上 3 组。',
      },
      {
        type: WorkoutType.CYCLING,
        title: '动感单车',
        duration: 45,
        calories: 430,
        distance: 18.5,
        intensity: WorkoutIntensity.HIGH,
        workoutDate: at(2, 19, 30),
        note: null,
      },
      {
        type: WorkoutType.RUNNING,
        title: '轻松跑',
        duration: 28,
        calories: 260,
        distance: 4.3,
        intensity: WorkoutIntensity.LOW,
        workoutDate: at(4, 7, 20),
        note: '腿有点沉，放慢节奏。',
      },
      {
        type: WorkoutType.YOGA,
        title: '拉伸与放松',
        duration: 25,
        calories: 90,
        intensity: WorkoutIntensity.LOW,
        workoutDate: at(5, 21, 0),
        note: '重点开髋与腘绳肌。',
      },
      {
        type: WorkoutType.STRENGTH,
        title: '下肢力量',
        duration: 55,
        calories: 340,
        intensity: WorkoutIntensity.HIGH,
        workoutDate: at(6, 20, 10),
        note: '深蹲、硬拉、保加利亚分腿蹲。',
      },
      {
        type: WorkoutType.RUNNING,
        title: '间歇跑',
        duration: 35,
        calories: 380,
        distance: 5.8,
        intensity: WorkoutIntensity.HIGH,
        workoutDate: at(8, 7, 0),
        note: '400 米 × 8 组。',
      },
      {
        type: WorkoutType.SWIMMING,
        title: '自由泳',
        duration: 40,
        calories: 360,
        distance: 1.2,
        intensity: WorkoutIntensity.MEDIUM,
        workoutDate: at(10, 18, 30),
        note: null,
      },
    ]

    await repository.save(
      items.map((item) => repository.create({ ...item, userId })),
    )
  }

  private async seedOpsCommandData(userId: number) {
    const repository = this.dataSource.getRepository(OpsCommand)
    const existingCount = await repository.count({ where: { userId } })
    if (existingCount > 0) return

    const items: Array<Partial<OpsCommand>> = [
      {
        category: 'Linux',
        title: '查看磁盘分区占用',
        command: 'df -h',
        description: '各分区已用与剩余空间，磁盘告警时先看这个',
      },
      {
        category: 'Linux',
        title: '找出占用最大的目录',
        command: 'du -sh /opt/* 2>/dev/null | sort -rh | head -20',
        description: '排查磁盘被谁吃掉了，换成 /var、/root 可以看别处',
      },
      {
        category: 'Linux',
        title: '查看内存与交换分区',
        command: 'free -h',
        description: 'used 看内存占用，swap 一行看交换分区有没有开始吃',
      },
      {
        category: 'Linux',
        title: '实时看资源占用最高的进程',
        command: 'top -o %MEM',
        description: '默认按内存排序，按 CPU 排序换成 top -o %CPU，q 退出',
      },
      {
        category: 'Linux',
        title: '清理 systemd 日志占用',
        command: 'journalctl --vacuum-size=200M',
        description: '日志积久了很占磁盘，只保留最近 200M',
      },
      {
        category: 'systemd',
        title: '查看服务运行状态',
        command: 'systemctl status lifeos-api',
        description: '看 Active 一行是不是 running，以及最近的日志',
      },
      {
        category: 'systemd',
        title: '重启后端服务',
        command: 'systemctl restart lifeos-api',
        description: '改完后端代码或 .env 后重启生效',
      },
      {
        category: 'systemd',
        title: '实时跟随服务日志',
        command: 'journalctl -u lifeos-api -f -n 100',
        description: '先看最近 100 行再持续输出，Ctrl+C 退出',
      },
      {
        category: 'systemd',
        title: '确认服务开机自启',
        command: 'systemctl is-enabled lifeos-api mysql nginx',
        description: '都应该是 enabled，服务器重启后才会自动起来',
      },
      {
        category: 'MySQL',
        title: '进入数据库命令行',
        command: 'mysql -u lifeos -p life_workbench',
        description: '密码在 /opt/lifeos/backend/.env 的 DB_PASSWORD',
      },
      {
        category: 'MySQL',
        title: '备份数据库到文件',
        command: 'mysqldump -u lifeos -p life_workbench > ~/backup_$(date +%F).sql',
        description: '导出前先确认磁盘空间，恢复用 mysql ... < 备份文件',
      },
      {
        category: 'MySQL',
        title: '查看各表数据量',
        command:
          "SELECT table_name, table_rows FROM information_schema.tables WHERE table_schema = 'life_workbench' ORDER BY table_rows DESC;",
        description: '在数据库命令行里执行，快速看哪张表数据在涨',
      },
      {
        category: 'Nginx',
        title: '检查并重载配置',
        command: 'nginx -t && systemctl reload nginx',
        description: '改完站点配置先过语法检查再重载，不要直接 restart',
      },
      {
        category: 'Nginx',
        title: '实时看访问日志',
        command: 'tail -f /var/log/nginx/access.log',
        description: '确认请求有没有到 nginx，返回了什么状态码',
      },
      {
        category: 'Nginx',
        title: '查看错误日志',
        command: 'tail -n 100 /var/log/nginx/error.log',
        description: '502 / 504 一般在这里能找到原因',
      },
      {
        category: '部署',
        title: '重新构建前端产物',
        command: 'cd /opt/lifeos && npm run build -w frontend',
        description: '改完前端重新打包，产物输出到 frontend/dist',
      },
      {
        category: '部署',
        title: '修改生产环境变量',
        command: 'vim /opt/lifeos/backend/.env',
        description: '改完执行 systemctl restart lifeos-api 生效',
      },
      {
        category: '网络',
        title: '查看端口监听情况',
        command: 'ss -tlnp',
        description: '3000 是后端、80 是 nginx，端口没起来先查这里',
      },
      {
        category: '网络',
        title: '检查网站响应状态码',
        command: 'curl -I http://127.0.0.1',
        description: '看 HTTP 状态码与响应头，加 -k 可跳过 https 证书检查',
      },
    ]

    await repository.save(items.map((item) => repository.create({ ...item, userId })))
  }
}