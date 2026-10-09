<script setup lang="ts">
import { ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { useUserStore } from '@/stores/user'

const visible = defineModel<boolean>({ required: true })
const userStore = useUserStore()

const nicknameInput = ref('')
const avatarData = ref('')
const saving = ref(false)
const fileInput = ref<HTMLInputElement>()

const fileToDataUrl = (file: File) =>
  new Promise<string>((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const img = new Image()
    img.onload = () => {
      URL.revokeObjectURL(url)
      const max = 256
      const scale = Math.min(1, max / Math.max(img.naturalWidth, img.naturalHeight))
      const width = Math.max(1, Math.round(img.naturalWidth * scale))
      const height = Math.max(1, Math.round(img.naturalHeight * scale))
      const canvas = document.createElement('canvas')
      canvas.width = width
      canvas.height = height
      const ctx = canvas.getContext('2d')
      if (!ctx) {
        reject(new Error('当前浏览器不支持图片处理'))
        return
      }
      ctx.drawImage(img, 0, 0, width, height)
      resolve(canvas.toDataURL('image/jpeg', 0.82))
    }
    img.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('图片读取失败'))
    }
    img.src = url
  })

watch(visible, (opened) => {
  if (!opened) return
  nicknameInput.value = userStore.user?.nickname ?? ''
  avatarData.value = userStore.user?.avatar ?? ''
})

const onPickFile = async (event: Event) => {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return
  if (!file.type.startsWith('image/')) {
    ElMessage.warning('请选择图片文件')
    return
  }
  try {
    const dataUrl = await fileToDataUrl(file)
    if (dataUrl.length > 60000) {
      ElMessage.warning('图片处理后仍过大，请换一张')
      return
    }
    avatarData.value = dataUrl
  } catch (error) {
    ElMessage.error(error instanceof Error ? error.message : '图片处理失败')
  }
}

const save = async () => {
  const nickname = nicknameInput.value.trim()
  if (nickname.length > 64) {
    ElMessage.warning('昵称不能超过 64 个字符')
    return
  }
  saving.value = true
  try {
    await userStore.updateProfile({ nickname, avatar: avatarData.value })
    ElMessage.success('个人资料已更新')
    visible.value = false
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <el-dialog v-model="visible" title="个人资料" width="min(92vw, 460px)" append-to-body>
    <div class="avatar-row">
      <el-avatar :size="72" :src="avatarData || undefined">
        {{ (userStore.displayName || '?').slice(0, 1) }}
      </el-avatar>
      <div class="avatar-actions">
        <div class="avatar-buttons">
          <el-button @click="fileInput?.click()">上传图片</el-button>
          <el-button v-if="avatarData" text type="danger" @click="avatarData = ''">移除头像</el-button>
        </div>
        <p>支持 JPG/PNG/WebP，自动压缩至 256px 内保存</p>
      </div>
      <input ref="fileInput" type="file" accept="image/*" class="hidden-input" @change="onPickFile" />
    </div>

    <el-form label-position="top" class="profile-form">
      <el-form-item label="昵称">
        <el-input v-model="nicknameInput" maxlength="64" show-word-limit placeholder="留空则显示用户名" />
      </el-form-item>
      <el-form-item label="登录用户名">
        <el-input :model-value="userStore.user?.username" disabled />
      </el-form-item>
    </el-form>

    <template #footer>
      <el-button @click="visible = false">取消</el-button>
      <el-button type="primary" :loading="saving" @click="save">保存</el-button>
    </template>
  </el-dialog>
</template>

<style scoped lang="scss">
.avatar-row {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 14px 16px;
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-muted);
}

.avatar-actions {
  min-width: 0;
  flex: 1;
}

.avatar-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.avatar-buttons :deep(.el-button + .el-button) {
  margin-left: 0;
}

.avatar-actions p {
  margin: 9px 0 0;
  color: var(--text-secondary);
  font-size: 12px;
}

.hidden-input {
  display: none;
}

.profile-form {
  margin-top: 16px;
}
</style>
