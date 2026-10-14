<template>
  <div class="dashboard">
    <header class="page-header">
      <div><h2>Ethan工作台 <el-tag effect="plain">本地版</el-tag></h2><p>从商品到出库，把每天的操作放在一起。</p></div>
      <div class="header-actions">
        <span class="updated" aria-live="polite">{{ loading ? '正在更新…' : updatedAt ? `更新于 ${updatedAt}` : '尚未加载' }}</span>
        <el-button :icon="Refresh" :loading="loading" @click="loadStats">刷新数据</el-button>
      </div>
    </header>
    <el-alert class="scope-note" title="当前显示本地 ERP 数据，包含先前的测试记录。抖店、罗盘尚未完成接入，不代表直播间实时经营数据。" type="info" :closable="false" show-icon />
    <section aria-labelledby="daily-heading">
      <div class="section-heading"><h3 id="daily-heading">今日概览</h3><span>按本机日期统计 · {{ today }}</span></div>
      <el-alert v-if="loadError" :title="loadError" type="error" :closable="false" show-icon class="scope-note" />
      <div class="stats-grid" v-loading="loading">
        <article class="stat-card"><span>今日订单金额</span><strong>{{ money }}</strong><p>本地订单总金额，未扣退款及成本</p></article>
        <article class="stat-card"><span>今日订单数</span><strong>{{ stats?.orderCount ?? '—' }}<small v-if="stats">笔</small></strong><p>按订单创建日期统计</p></article>
        <article class="stat-card"><span>待发货订单</span><strong>{{ stats?.waitShip ?? '—' }}<small v-if="stats">笔</small></strong><p>累计待发货，进入订单管理处理</p></article>
      </div>
    </section>
    <section aria-labelledby="actions-heading">
      <div class="section-heading"><h3 id="actions-heading">常用操作</h3><router-link to="/help">查看操作帮助</router-link></div>
      <div class="action-grid">
        <router-link v-for="action in availableActions" :key="action.to" :to="action.to" class="action-card">
          <el-icon class="action-icon" :size="23"><component :is="action.icon" /></el-icon>
          <div><h4>{{ action.title }}</h4><p>{{ action.description }}</p></div>
          <el-icon class="arrow"><ArrowRight /></el-icon>
        </router-link>
      </div>
    </section>
    <section class="status-panel" aria-labelledby="status-heading">
      <div class="section-heading"><h3 id="status-heading">经营数据与接入进度</h3><el-tag type="info" effect="plain">待完善</el-tag></div>
      <div class="readiness-grid">
        <div><h4>退款率 <el-tag size="small" type="info">待接入</el-tag></h4><p>需要真实订单与退款记录，并统一统计周期。</p></div>
        <div><h4>净利润 / 可支配现金 <el-tag size="small" type="info">待核算</el-tag></h4><p>需要结算、退款、货品成本、佣金、投流及其他费用。</p></div>
        <div><h4>照片识别 SKU <el-tag size="small" type="info">待开发</el-tag></h4><p>目前可手动查找 SKU；照片识别与自动出库尚未实现。</p></div>
      </div>
      <el-collapse class="getting-started">
        <el-collapse-item title="初次使用：从哪里开始？" name="start">
          <ol><li>在「商品与 SKU」建立商品档案和规格编码。</li><li>在仓库管理中设置仓库，使用「入库管理」记录收到的商品。</li><li>在「库存查询」按 SKU 查找库存、查看批次或导出本页。</li><li>在「出库管理」处理出库单；真实店铺接入后再核对订单与经营数据。</li></ol>
          <p>AI 助手为可选功能，不影响以上操作。罗盘接入需要另行完成权限申请与数据对接。</p>
        </el-collapse-item>
      </el-collapse>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ArrowRight, Box, Goods, Refresh, Sell, Shop, Tickets, Van } from '@element-plus/icons-vue'
import request from '@/utils/request'

interface DailyStats { salesVolume: number | null; orderCount: number; waitShip: number }
const router = useRouter()
const stats = ref<DailyStats | null>(null)
const loading = ref(false)
const loadError = ref('')
const updatedAt = ref('')
const today = ref('')
const money = computed(() => stats.value ? new Intl.NumberFormat('zh-CN', { style: 'currency', currency: 'CNY' }).format(stats.value.salesVolume ?? 0) : '—')
const actions = [
  { title: '商品与 SKU', description: '管理商品档案、规格和编码', to: '/goods/goods_list', icon: Goods },
  { title: '库存查询', description: '查可用库存、批次与导出', to: '/wms/goods_stock', icon: Box },
  { title: '入库管理', description: '新建入库单，记录收货', to: '/wms/stock_in_list', icon: Van },
  { title: '出库管理', description: '新建出库单，查看出库进度', to: '/wms/stock_out_list', icon: Sell },
  { title: '订单管理', description: '查看订单和发货状态', to: '/sale/order_list', icon: Tickets },
  { title: '店铺管理', description: '维护店铺与平台配置', to: '/channel/shop_list', icon: Shop },
]
const availableActions = computed(() => actions.filter(action => router.resolve(action.to).matched.some(record => record.path === action.to)))
async function loadStats() {
  if (loading.value) return
  loading.value = true
  loadError.value = ''
  today.value = new Date().toLocaleDateString('zh-CN')
  try {
    const res: any = await request.get('/api/erp-api/report/todayDaily')
    const data = res.data
    if (!data || !Number.isFinite(data.orderCount) || !Number.isFinite(data.waitShip) || (data.salesVolume !== null && !Number.isFinite(data.salesVolume))) throw new Error('Invalid report')
    stats.value = data
    updatedAt.value = new Date().toLocaleTimeString('zh-CN', { hour12: false })
  } catch {
    stats.value = null
    updatedAt.value = ''
    loadError.value = '概览加载失败，请检查本地服务后点击「刷新数据」。'
  } finally { loading.value = false }
}
onMounted(loadStats)
</script>

<style scoped lang="scss">
.dashboard { padding: 16px; max-width: 1600px; margin: 0 auto; color: var(--el-text-color-primary); }
.page-header, .header-actions, .section-heading { display: flex; align-items: center; justify-content: space-between; gap: 16px; }
.page-header { margin-bottom: 20px; flex-wrap: wrap; }
h2 { margin: 0; font-size: 23px; display: flex; align-items: center; gap: 12px; }
.page-header p, .stat-card p, .action-card p, .readiness-grid p { color: var(--el-text-color-regular); font-size: 13px; line-height: 1.7; margin: 8px 0 0; }
.updated, .section-heading > span { color: var(--el-text-color-secondary); font-size: 12px; }
.scope-note { margin-bottom: 16px; }
.section-heading { margin: 24px 0 14px; }
h3 { font-size: 16px; margin: 0; }
.section-heading a { color: var(--el-color-primary); font-size: 13px; }
.stats-grid, .action-grid, .readiness-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; }
.stat-card, .action-card, .status-panel { border: 1px solid var(--el-border-color-lighter); border-radius: 8px; background: var(--el-bg-color); }
.stat-card { padding: 20px; }
.stat-card > span { font-size: 14px; color: var(--el-text-color-regular); }
.stat-card strong { display: block; font-size: 29px; margin-top: 12px; font-variant-numeric: tabular-nums; }
.stat-card small { font-size: 13px; font-weight: 400; margin-left: 8px; }
.action-card { display: flex; align-items: center; padding: 20px; gap: 14px; text-decoration: none; color: inherit; transition: border-color .15s, background .15s; }
.action-card:hover, .action-card:focus-visible { border-color: var(--el-color-primary); background: var(--el-color-primary-light-9); }
.action-card:focus-visible { outline: 2px solid var(--el-color-primary); outline-offset: 3px; }
.action-icon { color: var(--el-color-primary); background: var(--el-color-primary-light-9); padding: 12px; border-radius: 8px; box-sizing: content-box; flex-shrink: 0; }
h4 { margin: 0; font-size: 15px; }
.action-card p { margin-top: 5px; }
.arrow { margin-left: auto; color: var(--el-text-color-secondary); flex-shrink: 0; }
.status-panel { margin-top: 24px; padding: 0 20px; }
.status-panel .section-heading { margin-top: 18px; }
.readiness-grid { padding-bottom: 18px; }
.readiness-grid h4 { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; font-size: 14px; }
.getting-started { border-bottom: none; }
.getting-started ol { padding-left: 20px; margin: 0; line-height: 2; }
.getting-started p { margin: 8px 0 0; color: var(--el-text-color-regular); }
@media (max-width: 1150px) { .action-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (max-width: 700px) { .stats-grid, .action-grid, .readiness-grid { grid-template-columns: 1fr; } .updated { display: none; } h2 { font-size: 20px; } .dashboard { padding: 8px; } }
</style>
