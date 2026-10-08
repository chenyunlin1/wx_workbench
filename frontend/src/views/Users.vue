<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, User } from '@element-plus/icons-vue'
import { createUser, getUsers, removeUser } from '@/api/users'
import type { User as UserType } from '@/types'

const users = ref<UserType[]>([])
const loading = ref(false)
const dialogVisible = ref(false)
const form = ref({ username: '', password: '', role: 'user' as 'admin' | 'user' })

const loadUsers = async () => {
  loading.value = true
  try {
    users.value = await getUsers()
  } finally {
    loading.value = false
  }
}

const submit = async () => {
  if (!form.value.username || form.value.password.length < 6) {
    ElMessage.warning('用户名不能为空，密码至少 6 位')
    return
  }
  await createUser(form.value)
  ElMessage.success('用户创建成功')
  dialogVisible.value = false
  form.value = { username: '', password: '', role: 'user' }
  await loadUsers()
}

const remove = async (user: UserType) => {
  await ElMessageBox.confirm(`确定删除用户「${user.username}」吗？`, '删除确认', { type: 'warning' })
  await removeUser(user.id)
  ElMessage.success('用户已删除')
  await loadUsers()
}

onMounted(loadUsers)
</script>

<template>
  <section class="users-page">
    <div class="page-heading">
      <div>
        <p>ACCESS CONTROL</p>
        <h2>用户管理</h2>
        <span>维护工作台账号与角色权限。</span>
      </div>
      <el-button type="primary" @click="dialogVisible = true">
        <el-icon><Plus /></el-icon>
        新增用户
      </el-button>
    </div>

    <el-card class="users-card" shadow="never">
      <el-table v-loading="loading" :data="users" style="width: 100%">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column label="用户" min-width="190">
          <template #default="{ row }">
            <div class="user-cell">
              <el-avatar :size="32" :src="row.avatar || undefined">{{ row.username.slice(0, 1) }}</el-avatar>
              <strong>{{ row.username }}</strong>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="role" label="角色" width="120">
          <template #default="{ row }">
            <el-tag :type="row.role === 'admin' ? 'primary' : 'success'" effect="light">
              {{ row.role === 'admin' ? '超级管理员' : '普通用户' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="创建时间" min-width="180" />
        <el-table-column label="操作" width="100" align="right">
          <template #default="{ row }">
            <el-button link type="danger" @click="remove(row)">删除</el-button>
          </template>
        </el-table-column>
        <template #empty>
          <div class="empty-users">
            <el-icon><User /></el-icon>
            <span>暂无用户</span>
          </div>
        </template>
      </el-table>
    </el-card>

    <el-dialog v-model="dialogVisible" title="新增用户" width="min(92vw, 460px)">
      <el-form label-position="top">
        <el-form-item label="用户名">
          <el-input v-model="form.username" placeholder="请输入用户名" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="form.password" type="password" show-password placeholder="至少 6 位" />
        </el-form-item>
        <el-form-item label="角色">
          <el-select v-model="form.role" style="width: 100%">
            <el-option label="普通用户" value="user" />
            <el-option label="超级管理员" value="admin" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="submit">创建</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<style scoped lang="scss">
.page-heading {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 20px;
  margin-bottom: 20px;
}

.page-heading p {
  margin: 0 0 5px;
  color: var(--primary);
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.16em;
}

.page-heading h2 {
  margin: 0;
  color: var(--text-primary);
  font-size: 26px;
  letter-spacing: -0.035em;
}

.page-heading span {
  display: block;
  margin-top: 6px;
  color: var(--text-secondary);
  font-size: 13px;
}

.users-card {
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-md);
  background: var(--surface-raised);
  box-shadow: var(--shadow-sm);
}

.user-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}

.user-cell strong {
  color: var(--text-primary);
  font-size: 13px;
}

.empty-users {
  display: grid;
  gap: 7px;
  place-items: center;
  color: var(--text-secondary);
  font-size: 13px;
}

.empty-users .el-icon {
  font-size: 26px;
}
</style>