<template>
  <div class="app-container">
    <header class="stock-header"><div><h2>库存查询</h2><p>按商品或 SKU 查库存，点击「查看批次」追溯入库记录。</p></div><el-button @click="$router.push('/index')">返回工作台</el-button></header>
    <el-form v-show="showSearch" ref="queryFormRef" :model="queryParams" size="default" :inline="true" label-width="80px" @submit.prevent="handleQuery">
      <el-form-item label="仓库" prop="warehouseId">
        <el-select v-model="queryParams.warehouseId" filterable clearable placeholder="全部仓库" @change="handleQuery" style="width:200px">
          <el-option v-for="item in warehouseList" :key="item.id" :label="item.warehouseName" :value="item.id">
            <span style="float:left">{{ item.warehouseName }}</span>
            <span style="float:right;color:#8492a6;font-size:13px">{{ warehouseTypeLabel(item.warehouseType) }}</span>
          </el-option>
        </el-select>
      </el-form-item>
      <el-form-item label="商品编码" prop="goodsNum">
        <el-input v-model="queryParams.goodsNum" placeholder="请输入商品编码" clearable @keyup.enter="handleQuery" />
      </el-form-item>
      <el-form-item label="SKU编码" prop="skuCode">
        <el-input v-model="queryParams.skuCode" placeholder="请输入SKU编码" clearable @keyup.enter="handleQuery" />
      </el-form-item>
      <el-form-item label="商品名称" prop="goodsName">
        <el-input v-model="queryParams.goodsName" placeholder="请输入商品名称" clearable @keyup.enter="handleQuery" />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" size="small" @click="handleQuery"><el-icon><Search /></el-icon>搜索</el-button>
        <el-button size="small" @click="resetQuery"><el-icon><Refresh /></el-icon>重置</el-button>
      </el-form-item>
    </el-form>

    <div class="stock-toolbar">
      <div><el-button :disabled="loading || !goodsInventoryList.length" :icon="Download" @click="handleExport">导出本页 CSV</el-button><span class="export-note">本页 {{ goodsInventoryList.length }} 条 / 共 {{ total }} 条</span></div>
      <RightToolbar v-model:showSearch="showSearch" @queryTable="getList" />
    </div>
    <el-alert v-if="loadError" :title="loadError" type="error" :closable="false" show-icon style="margin-bottom:12px" />

    <el-table v-loading="loading" :data="goodsInventoryList" border stripe empty-text="没有符合条件的库存，可重置筛选或先完成入库">
      <el-table-column label="商品名称" align="left" prop="goodsName" min-width="190" show-overflow-tooltip />
      <el-table-column label="SKU / 规格" align="left" prop="skuName" min-width="100" show-overflow-tooltip />
      <el-table-column label="SKU 编码" align="left" prop="skuCode" min-width="210" show-overflow-tooltip />
      <el-table-column label="商品编码" align="left" prop="goodsNum" min-width="175" show-overflow-tooltip />
      <el-table-column label="总库存" align="center" prop="quantity" width="70">
        <template #default="scope">
          <el-tag :type="(scope.row.quantity||0)>0?'success':'danger'" size="small">{{ scope.row.quantity??0 }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="锁定库存" align="center" prop="lockedQuantity" width="86" />
      <el-table-column label="可用库存" align="center" prop="availableQuantity" width="86" />
      <el-table-column label="仓库" align="center" prop="warehouseName" min-width="120" show-overflow-tooltip>
        <template #default="scope">
          <el-tag size="small" :type="getWarehouseType(scope.row.warehouseId)==='LOCAL'?'primary':(getWarehouseType(scope.row.warehouseId)==='CLOUD'?'warning':'info')">
            {{ getWarehouseName(scope.row.warehouseId) }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="操作" align="center" width="100" fixed="right">
        <template #default="scope">
          <el-button size="small" link type="primary" @click="handleViewBatch(scope.row)">查看批次</el-button>
        </template>
      </el-table-column>
    </el-table>

    <pagination v-show="total>0" :total="total" v-model:page="queryParams.pageNum" v-model:limit="queryParams.pageSize" @pagination="getList" />

    <el-dialog :title="batchTitle" v-model="batchOpen" width="min(1000px, 94vw)" append-to-body>
      <el-table :data="batchList" border empty-text="暂无批次记录">
        <el-table-column label="批次号" align="center" prop="batchNum" min-width="170" show-overflow-tooltip />
        <el-table-column label="SKU编码" align="center" prop="skuCode" min-width="210" show-overflow-tooltip />
        <el-table-column label="入库时间" align="center" prop="createTime" width="160">
          <template #default="scope">{{ parseTime(scope.row.createTime) }}</template>
        </el-table-column>
        <el-table-column label="入库数量" align="center" prop="originQty" width="80" />
        <el-table-column label="剩余数量" align="center" prop="currentQty" width="80" />
        <el-table-column label="仓位" align="center" prop="positionNum" />
        <el-table-column label="采购单价" align="center" prop="purPrice" width="100">
          <template #default="scope">{{ amountFormatter(scope.row.purPrice) }}</template>
        </el-table-column>
      </el-table>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Search, Refresh, Download } from '@element-plus/icons-vue'
import { getWarehouseGoodsStockList, getGoodsStockBatch } from '@/api/order/order'
import { listWarehouse } from '@/api/wms/warehouse'
import { downloadCsv } from '@/utils/csv'
import { parseTime, amountFormatter } from '@/utils/zhijian'
import Pagination from '@/components/Pagination/index.vue'
import RightToolbar from '@/components/RightToolbar/index.vue'

const loading=ref(true);const showSearch=ref(true);const total=ref(0)
const goodsInventoryList=ref<any[]>([]);const warehouseList=ref<any[]>([])
const batchOpen=ref(false);const batchList=ref<any[]>([]);const batchTitle=ref('批次库存明细');const loadError=ref('')
let requestId = 0

const queryParams=reactive({pageNum:1,pageSize:10,warehouseId:null as number|null,goodsNum:null as string|null,skuCode:null as string|null,goodsName:null as string|null})

function warehouseTypeLabel(t:string){const m:Record<string,string>={LOCAL:'本地仓',CLOUD:'系统云仓',JDYC:'京东云仓'};return m[t]||t||'未知'}
function getWarehouseType(warehouseId:any){const w=warehouseList.value.find((x:any)=>String(x.id)===String(warehouseId));return w?.warehouseType||''}
function getWarehouseName(warehouseId:any){const w=warehouseList.value.find((x:any)=>String(x.id)===String(warehouseId));return w?.warehouseName||`仓库 #${warehouseId}`}
async function getList(){
  const id = ++requestId
  loading.value=true;loadError.value=''
  try {
    const res:any=await getWarehouseGoodsStockList({...queryParams})
    if(id!==requestId)return
    goodsInventoryList.value=res.rows||[];total.value=res.total||0
  } catch {
    if(id!==requestId)return
    goodsInventoryList.value=[];total.value=0;loadError.value='库存加载失败，请点击右侧刷新按钮重试。'
  } finally {if(id===requestId)loading.value=false}
}
function handleQuery(){queryParams.pageNum=1;getList()}
function resetQuery(){queryParams.warehouseId=null;queryParams.goodsNum=null;queryParams.skuCode=null;queryParams.goodsName=null;handleQuery()}
function handleExport(){
  if(loading.value || !goodsInventoryList.value.length)return
  const rows=goodsInventoryList.value.map(row=>[row.goodsName,row.skuName,row.skuCode,row.goodsNum,row.quantity??0,row.lockedQuantity??0,row.availableQuantity??0,getWarehouseName(row.warehouseId)])
  downloadCsv(`库存查询-本页-${new Date().toLocaleDateString('sv-SE')}.csv`,['商品名称','SKU规格','SKU编码','商品编码','总库存','锁定库存','可用库存','仓库'],rows)
  ElMessage.success(`已导出本页 ${rows.length} 条库存记录`)
}
function handleViewBatch(row:any){
  getGoodsStockBatch(row.id).then((res:any)=>{
    batchList.value=res.data||[]
    batchTitle.value=`批次库存 · ${row.skuCode}`
    batchOpen.value=true
  }).catch(()=>{ElMessage.error('加载批次明细失败')})
}

onMounted(async()=>{
  await Promise.allSettled([
    getList(),
    listWarehouse({pageSize:100}).then((res:any)=>{warehouseList.value=res.rows||[]}).catch(()=>{ElMessage.warning('仓库名称加载失败，暂显示仓库编号。刷新页面可重试。')})
  ])
})
</script>

<style scoped>
.stock-header,.stock-toolbar { display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap;margin-bottom:20px; }
.stock-header h2 { margin:0;font-size:22px; }
.stock-header p { margin:8px 0 0;color:var(--el-text-color-regular);font-size:13px; }
.export-note { margin-left:14px;color:var(--el-text-color-secondary);font-size:13px; }
</style>
