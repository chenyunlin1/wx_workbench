import { createRouter, createWebHistory } from 'vue-router'
import { getToken } from '@/api'
import Layout from '@/layouts/Layout.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/Login.vue'),
      meta: { public: true, title: '登录' },
    },
    {
      path: '/',
      component: Layout,
      redirect: '/dashboard',
      children: [
        {
          path: 'dashboard',
          name: 'dashboard',
          component: () => import('@/views/Dashboard.vue'),
          meta: { title: '今日概览' },
        },
        { path: 'finance', name: 'finance', component: () => import('@/views/finance/FinanceView.vue'), meta: { title: '记账理财' } },
        { path: 'habits', name: 'habits', component: () => import('@/views/habits/HabitsView.vue'), meta: { title: '习惯健康' } },
        { path: 'fitness', name: 'fitness', component: () => import('@/views/fitness/FitnessView.vue'), meta: { title: '减脂健身' } },
        { path: 'running', name: 'running', component: () => import('@/views/running/RunningView.vue'), meta: { title: '跑步专项' } },
        { path: 'schedule', name: 'schedule', component: () => import('@/views/schedule/ScheduleView.vue'), meta: { title: '日程统筹' } },
        { path: 'shopping', name: 'shopping', component: () => import('@/views/shopping/ShoppingView.vue'), meta: { title: '待买清单' } },
        { path: 'collection', name: 'collection', component: () => import('@/views/collection/CollectionView.vue'), meta: { title: '书影音收藏' } },
        { path: 'learning', name: 'learning', component: () => import('@/views/knowledge/KnowledgeView.vue'), meta: { title: '学习知识库' } },
        { path: 'practice', name: 'practice', component: () => import('@/views/practice/PracticeConfig.vue'), meta: { title: '知识练习' } },
        { path: 'practice/session', name: 'practice-session', component: () => import('@/views/practice/PracticeSession.vue'), meta: { title: '练习答题' } },
        { path: 'practice/result', name: 'practice-result', component: () => import('@/views/practice/PracticeResult.vue'), meta: { title: '练习结果' } },
        { path: 'ops', name: 'ops', component: () => import('@/views/ops/OpsView.vue'), meta: { title: '运维速查' } },
        { path: 'ai', name: 'ai', component: () => import('@/views/ai/AiChatView.vue'), meta: { title: 'AI 助手' } },
        { path: 'users', name: 'users', component: () => import('@/views/Users.vue'), meta: { title: '用户管理' } },
      ],
    },
    { path: '/:pathMatch(.*)*', redirect: '/dashboard' },
  ],
})

router.beforeEach((to) => {
  const token = getToken()
  if (!to.meta.public && !token) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  if (to.name === 'login' && token) {
    return { name: 'dashboard' }
  }
  document.title = `${String(to.meta.title || '工作台')} · 个人生活工作台`
  return true
})

export default router