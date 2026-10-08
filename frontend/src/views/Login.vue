<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import type { FormInstance, FormRules } from 'element-plus'
import { Lock, Moon, Sunny, User } from '@element-plus/icons-vue'
import { useUserStore } from '@/stores/user'
import { useThemeStore } from '@/stores/theme'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()
const themeStore = useThemeStore()
const formRef = ref<FormInstance>()
const submitting = ref(false)

const form = reactive({
  username: 'admin',
  password: 'admin123',
})

const rules: FormRules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码至少 6 位', trigger: 'blur' },
  ],
}

const submit = async () => {
  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return

  submitting.value = true
  try {
    await userStore.login(form)
    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : '/dashboard'
    await router.replace(redirect)
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <main class="login-page">
    <button class="theme-toggle" aria-label="切换主题" @click="themeStore.toggle">
      <el-icon><Moon v-if="!themeStore.isDark" /><Sunny v-else /></el-icon>
    </button>

    <section class="login-showcase">
      <div class="showcase-content">
        <div class="logo">
          <span class="logo-grid"><i /><i /><i /></span>
          <div>
            <strong>LifeOS</strong>
            <small>PERSONAL WORKSPACE</small>
          </div>
        </div>
        <p class="eyebrow">让每一天，都有迹可循</p>
        <h1>把生活与工作<br /><em>整理成想要的样子。</em></h1>
        <p class="description">
          日程、习惯、财务、健康与学习，一处记录，持续看见改变。
        </p>
        <div class="feature-pills">
          <span>数据聚合</span>
          <span>习惯追踪</span>
          <span>成长复盘</span>
        </div>
      </div>

      <div class="showcase-visual" aria-hidden="true">
        <div class="visual-card card-one">
          <span>本周专注</span>
          <strong>12.5h</strong>
          <div class="mini-bars"><i /><i /><i /><i /><i /><i /><i /></div>
        </div>
        <div class="visual-card card-two">
          <span>连续打卡</span>
          <strong>8 天</strong>
          <small>↑ 14%</small>
        </div>
        <div class="orbit orbit-one" />
        <div class="orbit orbit-two" />
      </div>
    </section>

    <section class="login-form-side">
      <div class="form-wrap">
        <div class="mobile-logo">
          <span class="logo-grid"><i /><i /><i /></span>
          <strong>LifeOS</strong>
        </div>
        <p class="form-eyebrow">WELCOME BACK</p>
        <h2>登录工作台</h2>
        <p class="form-subtitle">继续记录你的生活与成长</p>

        <el-form ref="formRef" :model="form" :rules="rules" label-position="top" @keyup.enter="submit">
          <el-form-item label="用户名" prop="username">
            <el-input v-model="form.username" size="large" placeholder="请输入用户名">
              <template #prefix><el-icon><User /></el-icon></template>
            </el-input>
          </el-form-item>
          <el-form-item label="密码" prop="password">
            <el-input v-model="form.password" type="password" show-password size="large" placeholder="请输入密码">
              <template #prefix><el-icon><Lock /></el-icon></template>
            </el-input>
          </el-form-item>
          <div class="form-options">
            <el-checkbox checked>记住登录状态</el-checkbox>
            <span>演示账号：admin / admin123</span>
          </div>
          <el-button type="primary" size="large" :loading="submitting" class="submit-button" @click="submit">
            进入工作台
          </el-button>
        </el-form>

        <p class="security-tip">
          <i />
          使用 JWT 安全认证，登录状态将在本地保持 7 天
        </p>
      </div>
    </section>
  </main>
</template>

<style scoped lang="scss">
.login-page {
  position: relative;
  display: grid;
  grid-template-columns: minmax(0, 1.08fr) minmax(420px, 0.92fr);
  min-height: 100vh;
  overflow: hidden;
  background: var(--app-bg);
}

.theme-toggle {
  position: fixed;
  top: 23px;
  right: 25px;
  z-index: 5;
  display: grid;
  width: 42px;
  height: 42px;
  place-items: center;
  border: 1px solid var(--border-color);
  border-radius: 50%;
  color: var(--text-primary);
  background: var(--surface-raised);
  box-shadow: var(--shadow-sm);
  cursor: pointer;
}

.login-showcase {
  position: relative;
  display: flex;
  min-height: 100vh;
  align-items: center;
  overflow: hidden;
  color: #fff;
  background:
    radial-gradient(circle at 15% 18%, rgba(96, 165, 250, 0.35), transparent 24rem),
    radial-gradient(circle at 80% 80%, rgba(16, 185, 129, 0.25), transparent 26rem),
    linear-gradient(145deg, #0d1b3a 0%, #122b60 52%, #0f4c61 100%);
}

.login-showcase::before {
  position: absolute;
  inset: 0;
  opacity: 0.14;
  background-image: linear-gradient(rgba(255, 255, 255, 0.28) 1px, transparent 1px), linear-gradient(90deg, rgba(255, 255, 255, 0.28) 1px, transparent 1px);
  background-size: 42px 42px;
  mask-image: linear-gradient(to bottom right, black, transparent 72%);
  content: '';
}

.showcase-content {
  position: relative;
  z-index: 2;
  width: min(580px, 78%);
  margin-left: clamp(45px, 8vw, 130px);
}

.logo {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 74px;
}

.logo-grid,
.mobile-logo .logo-grid {
  display: grid;
  grid-template-columns: repeat(2, 9px);
  gap: 3px;
  width: 34px;
  height: 34px;
  padding: 6px;
  border-radius: 11px;
  background: var(--primary);
  box-shadow: 0 12px 30px rgba(59, 130, 246, 0.28);
}

.logo-grid i {
  border-radius: 3px;
  background: #fff;
}

.logo-grid i:last-child {
  grid-column: span 2;
  height: 5px;
}

.logo strong,
.logo small {
  display: block;
}

.logo strong {
  font-size: 18px;
  letter-spacing: -0.02em;
}

.logo small {
  margin-top: 2px;
  color: rgba(255, 255, 255, 0.58);
  font-size: 12px;
  letter-spacing: 0.14em;
}

.eyebrow,
.form-eyebrow {
  color: #7dd3fc;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.2em;
}

.showcase-content h1 {
  margin: 16px 0 20px;
  font-size: clamp(38px, 4.2vw, 64px);
  line-height: 1.16;
  letter-spacing: -0.055em;
}

.showcase-content h1 em {
  color: #a7f3d0;
  font-style: normal;
}

.description {
  max-width: 430px;
  margin: 0;
  color: rgba(255, 255, 255, 0.64);
  font-size: 15px;
  line-height: 1.9;
}

.feature-pills {
  display: flex;
  gap: 8px;
  margin-top: 28px;
}

.feature-pills span {
  padding: 7px 11px;
  border: 1px solid rgba(255, 255, 255, 0.16);
  border-radius: 99px;
  color: rgba(255, 255, 255, 0.78);
  background: rgba(255, 255, 255, 0.06);
  backdrop-filter: blur(8px);
  font-size: 12px;
}

.showcase-visual {
  position: absolute;
  right: 2%;
  bottom: 4%;
  width: 46%;
  height: 53%;
}

.visual-card {
  position: absolute;
  padding: 17px;
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: 17px;
  background: rgba(255, 255, 255, 0.09);
  box-shadow: 0 25px 70px rgba(0, 0, 0, 0.2);
  backdrop-filter: blur(18px);
}

.visual-card span,
.visual-card small {
  display: block;
  color: rgba(255, 255, 255, 0.6);
  font-size: 12px;
}

.visual-card strong {
  display: block;
  margin: 7px 0;
  font-size: 29px;
}

.card-one {
  right: 12%;
  bottom: 14%;
  width: 210px;
  transform: rotate(-4deg);
}

.mini-bars {
  display: flex;
  height: 40px;
  align-items: flex-end;
  gap: 5px;
  margin-top: 12px;
}

.mini-bars i {
  width: 9px;
  border-radius: 99px;
  background: #3b82f6;
}

.mini-bars i:nth-child(1) { height: 35%; }
.mini-bars i:nth-child(2) { height: 58%; }
.mini-bars i:nth-child(3) { height: 42%; }
.mini-bars i:nth-child(4) { height: 78%; }
.mini-bars i:nth-child(5) { height: 62%; }
.mini-bars i:nth-child(6) { height: 94%; }
.mini-bars i:nth-child(7) { height: 72%; }

.card-two {
  top: 8%;
  right: 0;
  width: 150px;
  transform: rotate(6deg);
}

.card-two small {
  color: #6ee7b7;
}

.orbit {
  position: absolute;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 50%;
}

.orbit-one {
  inset: 12% 5% 0 10%;
}

.orbit-two {
  inset: 28% 20% 17% -2%;
  border-style: dashed;
}

.login-form-side {
  display: grid;
  min-height: 100vh;
  place-items: center;
  padding: 50px;
  background: var(--surface);
}

.form-wrap {
  width: min(390px, 100%);
}

.mobile-logo {
  display: none;
}

.form-eyebrow {
  margin: 0;
  color: var(--primary);
}

.form-wrap h2 {
  margin: 10px 0 8px;
  color: var(--text-primary);
  font-size: 31px;
  letter-spacing: -0.04em;
}

.form-subtitle {
  margin: 0 0 30px;
  color: var(--text-secondary);
  font-size: 13px;
}

:deep(.el-form-item__label) {
  color: var(--text-regular);
  font-size: 13px;
  font-weight: 700;
}

:deep(.el-input__wrapper) {
  min-height: 46px;
  border-radius: 11px;
  background: var(--surface-muted);
  box-shadow: 0 0 0 1px var(--border-color) inset;
}

:deep(.el-input__wrapper.is-focus) {
  box-shadow: 0 0 0 1px var(--primary) inset, 0 0 0 4px var(--primary-soft);
}

.form-options {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin: -2px 0 20px;
}

.form-options span {
  color: var(--text-secondary);
  font-size: 12px;
}

:deep(.form-options .el-checkbox__label) {
  color: var(--text-secondary);
  font-size: 12px;
}

.submit-button {
  width: 100%;
  height: 47px;
  border: 0;
  border-radius: 11px;
  background: linear-gradient(135deg, var(--primary), var(--primary-strong));
  box-shadow: 0 11px 26px color-mix(in srgb, var(--primary) 28%, transparent);
  font-weight: 700;
  letter-spacing: 0.06em;
}

.security-tip {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin: 22px 0 0;
  color: var(--text-secondary);
  font-size: 12px;
}

.security-tip i {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--secondary);
  box-shadow: 0 0 0 3px var(--secondary-soft);
}

@media (max-width: 900px) {
  .login-page {
    grid-template-columns: 1fr;
  }

  .login-showcase {
    display: none;
  }

  .login-form-side {
    padding: 32px 22px;
  }

  .mobile-logo {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 46px;
    color: var(--text-primary);
  }

  .theme-toggle {
    top: 22px;
    right: 20px;
  }
}
</style>