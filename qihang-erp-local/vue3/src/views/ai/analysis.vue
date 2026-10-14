<template>
  <div class="app-container">
    <el-alert v-if="!aiConfigured" title="请先在 AI 智能 > 模型配置 中添加并启用默认模型" type="warning" show-icon :closable="false" style="margin-bottom: 16px" />

    <!-- 顶部：分析类型选择卡片 -->
    <div class="analysis-types">
      <div
        v-for="tpl in templates"
        :key="tpl.type"
        class="type-card"
        :class="{ active: currentType === tpl.type }"
        @click="selectTemplate(tpl.type)"
      >
        <div class="type-icon" :style="{ background: tpl.color }">{{ tpl.icon }}</div>
        <div class="type-info">
          <div class="type-name">{{ tpl.label }}</div>
          <div class="type-desc">{{ tpl.desc }}</div>
        </div>
      </div>
    </div>

    <!-- 中间：输入区 -->
    <el-card class="input-card" v-if="currentType">
      <div class="input-header">
        <span class="input-label">{{ currentTemplate?.icon }} {{ currentTemplate?.label }}</span>
        <el-tag v-if="currentTemplate" type="info" size="small" effect="plain">{{ currentTemplate.scope }}</el-tag>
      </div>
      <el-input
        v-model="userInput"
        type="textarea"
        :rows="8"
        placeholder="请输入分析需求..."
        :disabled="isAnalyzing"
      />
      <div class="input-actions">
        <el-button
          type="primary"
          size="large"
          :loading="isAnalyzing"
          :disabled="!currentType || !aiConfigured"
          @click="startAnalysis"
        >
          <el-icon v-if="!isAnalyzing"><VideoPlay /></el-icon>
          {{ isAnalyzing ? 'AI 分析中...' : '开始分析' }}
        </el-button>
        <el-button v-if="isAnalyzing" @click="stopAnalysis">停止</el-button>
      </div>
    </el-card>

    <!-- 分析结果 -->
    <el-card v-if="currentResult || isAnalyzing || errorMessage" class="result-card">
      <template #header>
        <div class="result-header">
          <span>分析结果</span>
          <div v-if="isAnalyzing" class="analyzing-badge">
            <el-icon class="is-loading"><Loading /></el-icon>
            AI 正在分析中，请稍候...
          </div>
          <el-button v-if="currentResult && !isAnalyzing" text size="small" @click="resetAll">
            <el-icon><RefreshLeft /></el-icon> 重新分析
          </el-button>
        </div>
      </template>

      <div v-if="errorMessage" style="margin-bottom: 16px">
        <el-alert :title="errorMessage" type="error" show-icon :closable="false" />
      </div>

      <div v-if="isAnalyzing && !currentResult" class="analyzing-placeholder">
        <el-icon class="is-loading" :size="32"><Loading /></el-icon>
        <p>AI 正在调用工具获取业务数据，请稍候...</p>
      </div>

      <div v-if="currentResult" class="result-markdown" v-html="renderMarkdown(currentResult)"></div>
    </el-card>

    <!-- 历史记录 -->
    <el-card v-if="!currentResult && !isAnalyzing" class="history-card">
      <template #header>
        <div class="result-header">
          <span>历史分析记录</span>
          <el-button text size="small" @click="loadHistory" :loading="historyLoading">
            <el-icon><Refresh /></el-icon>
          </el-button>
        </div>
      </template>
      <el-table :data="historyList" v-loading="historyLoading" style="width: 100%" empty-text="暂无分析记录" size="small">
        <el-table-column label="类型" width="100">
          <template #default="{ row }">
            <el-tag :type="getTagType(row.analysisType)" size="small" effect="plain">
              {{ getTypeLabel(row.analysisType) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="分析内容" prop="analysisContent" min-width="200" show-overflow-tooltip />
        <el-table-column label="状态" width="80" align="center">
          <template #default="{ row }">
            <el-tag v-if="row.status === 0" type="warning" size="small">分析中</el-tag>
            <el-tag v-else-if="row.status === 1" type="success" size="small">完成</el-tag>
            <el-tag v-else type="danger" size="small">失败</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="时间" width="160">
          <template #default="{ row }">{{ formatTime(row.createdTime) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="80" align="center">
          <template #default="{ row }">
            <el-button text size="small" type="primary" @click="viewHistory(row)">查看</el-button>
            <el-button text size="small" type="danger" @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { VideoPlay, Loading, Refresh, RefreshLeft } from '@element-plus/icons-vue'
import { marked } from 'marked'
import { getToken } from '@/utils/auth'
import { getAnalysisList, deleteAnalysis } from '@/api/ai/analysis'
import type { AiAnalysisRecord } from '@/api/ai/analysis'

interface Template {
  type: string
  label: string
  icon: string
  desc: string
  color: string
  scope: string
  defaultPrompt: string
}

const templates: Template[] = [
  {
    type: 'sales',
    label: '销售分析',
    icon: '📊',
    desc: '销售趋势、热销排名、平台对比、订单状态分布',
    color: '#409eff',
    scope: '最近7天',
    defaultPrompt: '请对最近7天的销售数据进行深度分析，分析维度包括：\n1. 销售趋势分析 - 整体销售走势，环比变化\n2. 热销商品排名 - 按销量/金额排序Top10\n3. 平台销售对比 - 各平台（淘宝/京东/拼多多/抖店等）销售占比\n4. 订单状态分析 - 各状态订单分布，异常订单识别\n5. 运营建议 - 基于数据给出3-5条可执行建议\n\n请调用工具获取订单数据和店铺数据后进行分析。'
  },
  {
    type: 'inventory',
    label: '库存优化',
    icon: '📦',
    desc: '库存预警、周转分析、滞销识别、补货建议',
    color: '#67c23a',
    scope: '当前库存',
    defaultPrompt: '请对当前库存数据进行深度分析，分析维度包括：\n1. 库存总览 - SKU数量、总库存量、库存总值\n2. 库存预警 - 低库存商品（可售数量<=5）清单\n3. 库存周转分析 - 结合近期出入库数据分析周转率\n4. 滞销商品识别 - 长期无动销的库存\n5. 补货建议 - 基于销售速度和库存水平给出补货建议\n\n请调用工具获取库存数据、出入库记录和商品数据后进行分析。'
  },
  {
    type: 'customer',
    label: '客户洞察',
    icon: '👥',
    desc: '客户画像、复购分析、售后统计、高价值客户',
    color: '#e6a23c',
    scope: '客户数据',
    defaultPrompt: '请对客户数据进行深度分析，分析维度包括：\n1. 客户概况 - 总客户数、新增趋势\n2. 订单行为分析 - 客户下单频次、客单价分布\n3. 售后分析 - 退款率、退款原因分布\n4. 高价值客户识别 - 高频次/高金额客户特征\n5. 客户运营建议 - 拉新、留存、复购策略\n\n请调用工具获取客户数据、订单数据和退款数据后进行分析。'
  },
  {
    type: 'operation',
    label: '运营效率',
    icon: '⚡',
    desc: '订单处理时效、物流效率、售后处理、人效分析',
    color: '#f56c6c',
    scope: '运营数据',
    defaultPrompt: '请对运营效率进行深度分析，分析维度包括：\n1. 订单处理效率 - 各环节（下单→发货→签收）耗时分析\n2. 物流效率 - 发货及时率、物流签收时效\n3. 售后处理效率 - 退款处理时长、成功率\n4. 人效分析 - 订单/人、处理速度等\n5. 效率提升建议 - 识别瓶颈，给出优化方案\n\n请调用工具获取订单数据、物流数据和退款数据后进行分析。'
  },
  {
    type: 'purchase',
    label: '采购分析',
    icon: '🏭',
    desc: '采购周期、供应商评估、库存匹配、采购优化',
    color: '#909399',
    scope: '采购数据',
    defaultPrompt: '请对采购数据进行深度分析，分析维度包括：\n1. 采购概况 - 采购订单数量、金额、供应商分布\n2. 采购周期分析 - 从下单到入库的平均时长\n3. 供应商评估 - 各供应商的交付及时率、质量情况\n4. 库存与采购匹配度 - 采购量与销售量的匹配分析\n5. 采购优化建议 - 供应商选择、采购时机、批量优化\n\n请调用工具获取采购数据、供应商数据和库存数据后进行分析。'
  }
]

const currentType = ref('')
const userInput = ref('')
const isAnalyzing = ref(false)
const currentResult = ref('')
const errorMessage = ref('')
const historyList = ref<AiAnalysisRecord[]>([])
const historyLoading = ref(false)
const abortRef = ref<AbortController | null>(null)

const aiConfigured = ref(true)
const currentTemplate = computed(() => templates.find(t => t.type === currentType.value))

function selectTemplate(type: string) {
  if (isAnalyzing.value) return
  currentType.value = type
  currentResult.value = ''
  errorMessage.value = ''
  const tpl = templates.find(t => t.type === type)
  userInput.value = tpl?.defaultPrompt || ''
}

function resetAll() {
  currentType.value = ''
  userInput.value = ''
  currentResult.value = ''
  errorMessage.value = ''
}

async function startAnalysis() {
  if (!currentType.value || isAnalyzing.value) return

  isAnalyzing.value = true
  currentResult.value = ''
  errorMessage.value = ''

  try {
    const token = getToken()
    abortRef.value = new AbortController()

    const response = await fetch('/api/ai/analysis/execute', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`
      },
      body: JSON.stringify({
        analysisType: currentType.value,
        content: userInput.value || undefined
      }),
      signal: abortRef.value.signal
    })

    if (!response.ok) {
      const errText = await response.text().catch(() => '')
      errorMessage.value = `请求失败 (${response.status}): ${errText}`
      isAnalyzing.value = false
      return
    }

    const reader = response.body!.getReader()
    const decoder = new TextDecoder()
    let buffer = ''
    let fullContent = ''

    while (true) {
      const { done, value } = await reader.read()
      if (done) break

      buffer += decoder.decode(value, { stream: true })
      const lines = buffer.split('\n')
      buffer = lines.pop() || ''

      for (const line of lines) {
        const t = line.trim()
        if (!t || !t.startsWith('data:')) continue

        const jsonStr = t.slice(5).trim()
        if (!jsonStr) continue

        try {
          const event = JSON.parse(jsonStr)
          const type = event.type
          const content = event.content || ''

          if (type === 'message') {
            fullContent += content
            currentResult.value = fullContent
          } else if (type === 'error') {
            errorMessage.value = content
          }
        } catch {
          // ignore
        }
      }
    }

    if (fullContent) {
      currentResult.value = fullContent
    }

    loadHistory()
  } catch (e: any) {
    if (e.name === 'AbortError') return
    errorMessage.value = '网络错误: ' + (e.message || '请检查网络连接')
  } finally {
    isAnalyzing.value = false
    abortRef.value = null
  }
}

function stopAnalysis() {
  abortRef.value?.abort()
  isAnalyzing.value = false
}

async function loadHistory() {
  historyLoading.value = true
  try {
    const res = await getAnalysisList({ pageNum: 1, pageSize: 20 })
    if (res.data?.records) {
      historyList.value = res.data.records
    } else if (Array.isArray(res.data)) {
      historyList.value = res.data
    }
  } catch {
    // silent
  } finally {
    historyLoading.value = false
  }
}

function viewHistory(record: AiAnalysisRecord) {
  currentType.value = record.analysisType
  currentResult.value = record.analysisResult || ''
  errorMessage.value = record.status === 2 ? (record.errorMessage || '分析失败') : ''
  userInput.value = record.analysisContent || ''
}

function handleDelete(row: AiAnalysisRecord) {
  ElMessageBox.confirm(`确定删除这条分析记录吗？`, '提示', { type: 'warning' }).then(() => {
    deleteAnalysis(row.id!).then(() => {
      ElMessage.success('删除成功')
      loadHistory()
    })
  })
}

function getTagType(type: string): string {
  const map: Record<string, string> = {
    sales: '', inventory: 'success', customer: 'warning', operation: 'danger', purchase: 'info'
  }
  return map[type] || ''
}

function getTypeLabel(type: string): string {
  return templates.find(t => t.type === type)?.label || type
}

function formatTime(time?: string): string {
  if (!time) return ''
  const d = new Date(time)
  const now = new Date()
  const diff = now.getTime() - d.getTime()
  if (diff < 60000) return '刚刚'
  if (diff < 3600000) return Math.floor(diff / 60000) + '分钟前'
  if (diff < 86400000) return Math.floor(diff / 3600000) + '小时前'
  return time.slice(0, 16).replace('T', ' ')
}

function renderMarkdown(text: string): string {
  if (!text) return ''
  return marked.parse(text) as string
}

onMounted(() => {
  loadHistory()
})
</script>

<style lang="scss" scoped>
.analysis-types {
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}

.type-card {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 16px;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
  border: 2px solid #ebeef5;
  background: #fff;
  flex: 1;
  min-width: 180px;

  &:hover {
    border-color: #c0c4cc;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  }

  &.active {
    border-color: #409eff;
    background: #ecf5ff;
    box-shadow: 0 2px 8px rgba(64, 158, 255, 0.2);
  }
}

.type-icon {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  color: #fff;
  flex-shrink: 0;
}

.type-info {
  flex: 1;
  min-width: 0;
}

.type-name {
  font-size: 14px;
  font-weight: 600;
  color: #303133;
}

.type-desc {
  font-size: 12px;
  color: #909399;
  margin-top: 2px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.input-card {
  margin-bottom: 16px;
}

.input-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.input-label {
  font-size: 15px;
  font-weight: 600;
  color: #303133;
}

.input-actions {
  display: flex;
  gap: 8px;
  margin-top: 12px;
}

.result-card {
  margin-bottom: 16px;
}

.result-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-weight: 600;
}

.analyzing-badge {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: #e6a23c;
  font-weight: normal;
}

.analyzing-placeholder {
  text-align: center;
  padding: 40px 0;
  color: #909399;

  p {
    margin-top: 12px;
    font-size: 14px;
  }
}

.result-markdown {
  line-height: 1.8;
  font-size: 14px;
  color: #303133;

  :deep(h1) {
    font-size: 22px;
    margin: 24px 0 12px;
    padding-bottom: 8px;
    border-bottom: 1px solid #ebeef5;
  }

  :deep(h2) {
    font-size: 18px;
    margin: 20px 0 10px;
    color: #303133;
  }

  :deep(h3) {
    font-size: 16px;
    margin: 16px 0 8px;
  }

  :deep(p) {
    margin: 8px 0;
  }

  :deep(ul), :deep(ol) {
    padding-left: 20px;
    margin: 8px 0;
  }

  :deep(table) {
    width: 100%;
    border-collapse: collapse;
    margin: 12px 0;
    font-size: 13px;
  }

  :deep(th), :deep(td) {
    border: 1px solid #ebeef5;
    padding: 8px 12px;
    text-align: left;
  }

  :deep(th) {
    background: #f5f7fa;
    font-weight: 600;
  }

  :deep(tr:hover) {
    background: #f5f7fa;
  }

  :deep(strong) {
    font-weight: 600;
  }

  :deep(code) {
    background: rgba(0, 0, 0, 0.06);
    padding: 1px 5px;
    border-radius: 3px;
    font-size: 13px;
  }

  :deep(pre) {
    background: #f5f7fa;
    padding: 12px 16px;
    border-radius: 6px;
    overflow-x: auto;
    margin: 12px 0;

    code { background: none; padding: 0; }
  }

  :deep(blockquote) {
    border-left: 4px solid #409eff;
    padding: 8px 16px;
    margin: 12px 0;
    background: #ecf5ff;
    color: #606266;
  }
}

.history-card {
  margin-bottom: 16px;
}
</style>
