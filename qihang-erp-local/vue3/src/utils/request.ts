import axios from 'axios'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getToken, removeToken } from './auth'

const service = axios.create({
  baseURL: import.meta.env.VITE_APP_BASE_API,
  timeout: 10000,
})

service.interceptors.request.use((config) => {
  const token = getToken()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

service.interceptors.response.use(
  (response) => {
    const res = response.data
    if (res.code !== 200) {
      ElMessage.error(res.msg || '请求失败')
      return Promise.reject(new Error(res.msg))
    }
    return res
  },
  (error) => {
    if (error.response?.status === 401) {
      ElMessageBox.confirm('登录已过期，请重新登录', '提示', {
        confirmButtonText: '重新登录',
        cancelButtonText: '取消',
        type: 'warning',
      }).then(() => {
        removeToken()
        window.location.href = '/login'
      })
    } else {
      const status = error.response?.status
      const message = error.code === 'ECONNABORTED' || error.code === 'ETIMEDOUT'
        ? '请求超时，请稍后重试。'
        : !error.response
          ? '无法连接本地服务，请确认工作台已启动。'
          : status >= 500
            ? '本地服务暂时不可用，请稍后重试。'
            : status === 403
              ? '当前账号没有此操作权限。'
              : status === 404
                ? '未找到此功能接口，请刷新页面后重试。'
                : '请求未完成，请检查输入后重试。'
      ElMessage.error(message)
    }
    return Promise.reject(error)
  },
)

export default service
