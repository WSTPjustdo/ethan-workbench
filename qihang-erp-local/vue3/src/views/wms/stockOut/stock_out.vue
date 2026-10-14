<template>
  <div class="outbound-work">
    <el-card class="work-card" shadow="never">
      <template #header>
        <span>出库作业 - {{ outboundOrder.outNum || outboundOrder.id }}</span>
        <el-button size="small" style="float:right" @click="goBack">
          <el-icon><Back /></el-icon>返回
        </el-button>
      </template>

      <el-form :model="outboundOrder" label-width="100px" size="small" disabled inline>
        <el-form-item label="源单号">{{ outboundOrder.sourceNo }}</el-form-item>
        <el-form-item label="仓库">{{ outboundOrder.warehouseName }}</el-form-item>
        <el-form-item label="出库类型">
          <el-tag v-if="outboundOrder.type === 1" size="small">订单发货出库</el-tag>
          <el-tag v-else-if="outboundOrder.type === 2" size="small">采购退货出库</el-tag>
          <el-tag v-else-if="outboundOrder.type === 3" size="small">盘亏出库</el-tag>
          <el-tag v-else-if="outboundOrder.type === 4" size="small">报损出库</el-tag>
        </el-form-item>
        <el-form-item label="创建时间">{{ parseTime(outboundOrder.createTime) }}</el-form-item>
      </el-form>

      <!-- 出库模式切换 -->
      <el-tabs v-model="outMode" type="border-card" style="margin-top:15px">
        <!-- 管理员出库 Tab -->
        <el-tab-pane label="管理员出库" name="admin">
          <el-table :data="outboundItems" border stripe>
            <el-table-column prop="skuCode" label="SKU编码" width="120" />
            <el-table-column prop="goodsName" label="商品名称" min-width="150" show-overflow-tooltip />
            <el-table-column prop="skuName" label="规格" width="120" show-overflow-tooltip />
            <el-table-column prop="originalQuantity" label="应出数量" width="100" align="center" />
            <el-table-column prop="outQuantity" label="已出数量" width="100" align="center" />
            <el-table-column label="本次出库" width="160" align="center">
              <template #default="scope">
                <div v-if="scope.row.remainingQuantity === 0" style="color:#909399">已完成</div>
                <el-input-number v-else
                  v-model="scope.row.thisQuantity"
                  :min="0"
                  :max="scope.row.remainingQuantity"
                  size="small"
                  controls-position="right"
                  style="width:100px"
                />
              </template>
            </el-table-column>
            <el-table-column label="可用库存" width="90" align="center">
              <template #default="scope">
                <span v-if="scope.row.availableStock !== undefined"
                  :class="{ 'text-danger': scope.row.availableStock <= 0 }">
                  {{ scope.row.availableStock }}
                </span>
                <span v-else style="color:#909399">-</span>
              </template>
            </el-table-column>
            <el-table-column label="出库批次" min-width="160">
              <template #default="scope">
                <el-tag v-if="scope.row.batchNum" size="small" type="info">
                  {{ scope.row.batchNum }} (余{{ scope.row.batchCurrentQty }})
                </el-tag>
                <span v-else-if="scope.row.remainingQuantity > 0" style="color:#909399">待分配</span>
                <span v-else style="color:#909399">-</span>
              </template>
            </el-table-column>
            <el-table-column prop="remainingQuantity" label="剩余可出" width="100" align="center">
              <template #default="scope">
                <span :class="{ 'text-danger': scope.row.remainingQuantity === 0 }">{{ scope.row.remainingQuantity }}</span>
              </template>
            </el-table-column>
          </el-table>

          <div class="submit-bar" style="margin-top:20px;text-align:center">
            <el-button type="primary" size="large" @click="submitOutbound" :loading="submitting" :disabled="!canSubmit">
              确认出库
            </el-button>
          </div>
        </el-tab-pane>

        <!-- 扫码出库 Tab -->
        <el-tab-pane label="扫码出库" name="scan">
          <el-form :inline="true" size="small" @submit.prevent="handleScan">
            <el-form-item label="扫码/输SKU编码">
              <el-input
                ref="scanInputRef"
                v-model="scanInput"
                placeholder="扫描条码或输入SKU编码"
                style="width:280px"
                clearable
                @keyup.enter="handleScan"
              />
            </el-form-item>
            <el-form-item label="出库数量">
              <el-input-number
                v-model="scanQty"
                :min="1"
                :max="9999"
                size="small"
                controls-position="right"
                style="width:100px"
              />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" @click="handleScan" :loading="scanning">确认扫码</el-button>
            </el-form-item>
          </el-form>
          <el-alert v-if="scanResult" :type="scanResult.success ? 'success' : 'error'" show-icon style="margin-bottom:10px" :closable="true">
            {{ scanResult.message }}
          </el-alert>

          <el-table :data="outboundItems" border stripe>
            <el-table-column prop="skuCode" label="SKU编码" width="120" />
            <el-table-column prop="goodsName" label="商品名称" min-width="150" show-overflow-tooltip />
            <el-table-column prop="skuName" label="规格" width="120" show-overflow-tooltip />
            <el-table-column prop="originalQuantity" label="应出" width="60" align="center" />
            <el-table-column prop="outQuantity" label="已出" width="60" align="center" />
            <el-table-column prop="remainingQuantity" label="剩余" width="60" align="center">
              <template #default="scope">
                <span :class="{ 'text-danger': scope.row.remainingQuantity === 0 }">{{ scope.row.remainingQuantity }}</span>
              </template>
            </el-table-column>
            <el-table-column label="出库批次" min-width="150">
              <template #default="scope">
                <el-tag v-if="scope.row.batchNum" size="small" type="info">
                  {{ scope.row.batchNum }} (余{{ scope.row.batchCurrentQty }})
                </el-tag>
                <span v-else style="color:#909399">-</span>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
      </el-tabs>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, nextTick, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Back } from '@element-plus/icons-vue'
import { getStockOutEntry, stockOut, getInventoryBatches, searchBatches } from '@/api/wms/stockOut'
import { parseTime } from '@/utils/zhijian'

const route = useRoute()
const router = useRouter()

const outboundOrder = reactive<Record<string, any>>({})
const outboundItems = ref<any[]>([])
const submitting = ref(false)
const outMode = ref('admin')

const scanInput = ref('')
const scanQty = ref(1)
const scanInputRef = ref<any>(null)
const scanning = ref(false)
const scanResult = ref<{ success: boolean; message: string } | null>(null)

const canSubmit = computed(() => {
  return outboundItems.value.some((item: any) => (item.thisQuantity || 0) > 0)
})

watch(outMode, (val) => {
  if (val === 'scan') {
    nextTick(() => { scanInputRef.value?.focus() })
  }
})

function loadData(id: number) {
  getStockOutEntry(id).then((res: any) => {
    const data = res.data || {}
    Object.assign(outboundOrder, data)
    const items = (data.itemList || data.items || []).map((item: any) => ({
      ...item,
      thisQuantity: (item.originalQuantity || 0) - (item.outQuantity || 0),
      remainingQuantity: (item.originalQuantity || 0) - (item.outQuantity || 0),
    }))
    outboundItems.value = items
    items.forEach((item: any, index: number) => {
      if (item.remainingQuantity > 0 && !item.batchId) {
        getInventoryBatches(item.skuId, outboundOrder.warehouseId).then((res: any) => {
          const batches = (res.data || []) as any[]
          const totalAvailable = batches.reduce((sum: number, b: any) => sum + (b.currentQty || 0), 0)
          outboundItems.value[index].availableStock = totalAvailable
          if (totalAvailable < item.thisQuantity) {
            outboundItems.value[index].thisQuantity = totalAvailable
          }
        })
      } else {
        outboundItems.value[index].availableStock = '-'
      }
    })
  })
}

function handleScan() {
  if (!scanInput.value || !outboundOrder.id) return
  if (scanQty.value <= 0) {
    ElMessage.warning('出库数量必须大于0')
    return
  }

  scanning.value = true
  scanResult.value = null

  searchBatches(scanInput.value, outboundOrder.warehouseId).then((res: any) => {
    const batches = (res.data || []) as any[]
    if (batches.length === 0) {
      scanResult.value = { success: false, message: '未找到匹配的库存批次' }
      scanning.value = false
      return
    }

    const batch = batches[0]
    if (batch.currentQty < scanQty.value) {
      scanResult.value = { success: false, message: `批次库存不足，当前库存: ${batch.currentQty}，请求出库: ${scanQty.value}` }
      scanning.value = false
      return
    }

    const itemIndex = outboundItems.value.findIndex((item: any) =>
      String(item.skuId) === String(batch.skuId) && item.remainingQuantity > 0
    )
    if (itemIndex === -1) {
      scanResult.value = { success: false, message: `出库单中没有该商品(SKU:${batch.skuCode})的待出库明细` }
      scanning.value = false
      return
    }

    const item = outboundItems.value[itemIndex]
    stockOut({
      entryItemId: item.id,
      entryId: outboundOrder.id,
      skuId: item.skuId,
      outQty: scanQty.value,
      originalQuantity: item.originalQuantity,
      outQuantity: item.outQuantity,
      batchId: batch.id,
    }).then((result: any) => {
      scanning.value = false
      if (result.code === 200 || result.code === 0) {
        scanResult.value = { success: true, message: `扫码出库成功: ${batch.skuCode} x ${scanQty.value}` }
        scanInput.value = ''
        loadData(outboundOrder.id)
      } else {
        scanResult.value = { success: false, message: result.msg || '出库失败' }
      }
    }).catch(() => {
      scanning.value = false
      scanResult.value = { success: false, message: '出库请求失败' }
    })
  }).catch(() => {
    scanning.value = false
    scanResult.value = { success: false, message: '查询库存批次失败' }
  })
}

function submitOutbound() {
  const items = outboundItems.value
    .filter((item: any) => (item.thisQuantity || 0) > 0)
    .map((item: any) => ({
      entryItemId: item.id,
      entryId: item.entryId || outboundOrder.id,
      skuId: item.skuId,
      outQty: item.thisQuantity,
      originalQuantity: item.originalQuantity,
      outQuantity: item.outQuantity,
    }))

  if (items.length === 0) {
    ElMessage.warning('请填写出库数量')
    return
  }

  submitting.value = true
  let completed = 0
  let failed = false
  items.forEach((item: any) => {
    stockOut(item).then((res: any) => {
      if (failed) return
      if (res.code === 200 || res.code === 0) {
        completed++
        if (completed === items.length) {
          ElMessage.success('出库成功')
          submitting.value = false
          loadData(outboundOrder.id)
        }
      } else {
        failed = true
        ElMessage.error(res.msg || '出库失败')
        submitting.value = false
      }
    }).catch(() => {
      if (!failed) {
        failed = true
        submitting.value = false
        ElMessage.error('出库请求失败')
      }
    })
  })
}

function goBack() {
  router.back()
}

onMounted(() => {
  const id = route.query.id || route.params.id
  if (id) loadData(Number(id))
  nextTick(() => { scanInputRef.value?.focus() })
})
</script>

<style scoped>
.text-danger { color: #f56c6c; font-weight: bold; }
</style>
