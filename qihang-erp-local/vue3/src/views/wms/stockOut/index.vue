<template>
  <div class="app-container">
    <el-form v-show="showSearch" ref="queryFormRef" :model="queryParams" size="small" :inline="true" label-width="68px">
      <el-form-item label="出库单号" prop="outNum">
        <el-input v-model="queryParams.outNum" placeholder="请输入出库单号" clearable @keyup.enter="handleQuery" />
      </el-form-item>
      <el-form-item label="源单号" prop="sourceNum">
        <el-input v-model="queryParams.sourceNum" placeholder="请输入源单号" clearable @keyup.enter="handleQuery" />
      </el-form-item>
      <el-form-item label="仓库" prop="warehouseId">
        <el-select v-model="queryParams.warehouseId" placeholder="请选择仓库" clearable @change="handleQuery">
          <el-option v-for="item in warehouseList" :key="item.id" :label="item.warehouseName" :value="item.id" />
        </el-select>
      </el-form-item>
      <el-form-item label="出库类型" prop="type">
        <el-select v-model="queryParams.type" placeholder="出库类型" clearable @change="handleQuery">
          <el-option label="订单发货出库" value="1" />
          <el-option label="采购退货出库" value="2" />
          <el-option label="盘亏出库" value="3" />
          <el-option label="报损出库" value="4" />
        </el-select>
      </el-form-item>
      <el-form-item label="创建日期" prop="createTime">
        <el-date-picker v-model="queryParams.createTime" type="date" value-format="YYYY-MM-DD" placeholder="请选择创建日期" clearable />
      </el-form-item>
      <el-form-item>
        <el-button type="primary" size="small" @click="handleQuery"><el-icon><Search /></el-icon>搜索</el-button>
        <el-button size="small" @click="resetQuery"><el-icon><Refresh /></el-icon>重置</el-button>
      </el-form-item>
    </el-form>

    <el-row :gutter="10" class="mb8">
      <el-col :span="1.5">
        <el-button type="primary" plain size="small" @click="handleAdd">
          <el-icon><Plus /></el-icon>新建商品出库单
        </el-button>
      </el-col>
      <RightToolbar :showSearch="showSearch" @queryTable="getList" />
    </el-row>

    <el-table v-loading="loading" :data="stockOutEntryList" @selection-change="handleSelectionChange">
      <el-table-column type="selection" width="55" align="center" />
      <el-table-column label="ID" align="center" prop="id" width="60" />
      <el-table-column label="出库单号" align="center" prop="outNum" width="180" />
      <el-table-column label="源单号" align="center" prop="sourceNum" width="180" />
      <el-table-column label="出库类型" align="center" prop="type" width="130">
        <template #default="scope">
          <el-tag v-if="scope.row.type === 1" size="small">订单发货出库</el-tag>
          <el-tag v-else-if="scope.row.type === 2" size="small">采购退货出库</el-tag>
          <el-tag v-else-if="scope.row.type === 3" size="small">盘亏出库</el-tag>
          <el-tag v-else-if="scope.row.type === 4" size="small">报损出库</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="出库仓库" align="center" prop="warehouseName" width="200">
        <template #default="scope"><el-tag type="info" v-if="scope.row.warehouseName">{{ scope.row.warehouseName }}</el-tag></template>
      </el-table-column>
      <el-table-column label="状态" align="center" prop="status" width="100">
        <template #default="scope">
          <el-tag v-if="scope.row.status === 0" size="small">待出库</el-tag>
          <el-tag v-else-if="scope.row.status === 1" size="small" type="warning">部分出库</el-tag>
          <el-tag v-else-if="scope.row.status === 2" size="small" type="success">全部出库</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="创建日期" align="center" prop="createTime" width="160">
        <template #default="scope">{{ parseTime(scope.row.createTime) }}</template>
      </el-table-column>
      <el-table-column label="更新时间" align="center" prop="updateTime" width="160">
        <template #default="scope">{{ parseTime(scope.row.updateTime) }}</template>
      </el-table-column>
      <el-table-column label="完成时间" align="center" prop="completeTime" width="160">
        <template #default="scope">{{ parseTime(scope.row.completeTime) }}</template>
      </el-table-column>
      <el-table-column label="操作人" align="center" prop="operatorName" />
      <el-table-column label="备注" align="center" prop="remark" />
      <el-table-column label="商品数" align="center" prop="goodsUnit" width="70" />
      <el-table-column label="规格数" align="center" prop="specUnit" width="70" />
      <el-table-column label="总件数" align="center" prop="specUnitTotal" width="70" />
      <el-table-column label="操作" align="center" class-name="small-padding fixed-width" width="120">
        <template #default="scope">
          <el-button v-if="scope.row.status !== 2" type="primary" plain size="small" @click="handleStockOut(scope.row)">出库</el-button>
          <el-button v-if="scope.row.status === 2" type="primary" link size="small" @click="handleStockOut(scope.row)">详情</el-button>
        </template>
      </el-table-column>
    </el-table>

    <pagination v-show="total>0" :total="total" v-model:page="queryParams.pageNum" v-model:limit="queryParams.pageSize" @pagination="getList" />
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Refresh, Plus } from '@element-plus/icons-vue'
import { listStockOut } from '@/api/wms/stockOut'
import { listWarehouse } from '@/api/wms/warehouse'
import { getUserProfile } from '@/api/system/user'
import { parseTime } from '@/utils/zhijian'
import Pagination from '@/components/Pagination/index.vue'
import RightToolbar from '@/components/RightToolbar/index.vue'

const router = useRouter()
const loading=ref(true);const showSearch=ref(true);const total=ref(0)
const stockOutEntryList=ref<any[]>([]);const warehouseList=ref<any[]>([]);const ids:any[]=[]

const queryParams=reactive({pageNum:1,pageSize:10,outNum:null as string|null,sourceNum:null as string|null,warehouseId:null as number|null,type:null as string|null,createTime:null as string|null})

function getList(){loading.value=true;listStockOut(queryParams).then((res:any)=>{stockOutEntryList.value=res.rows||[];total.value=res.total||0;loading.value=false}).catch(()=>{loading.value=false})}
function handleQuery(){queryParams.pageNum=1;getList()}
function resetQuery(){queryParams.outNum=null;queryParams.sourceNum=null;queryParams.warehouseId=null;queryParams.type=null;queryParams.createTime=null;handleQuery()}
function handleSelectionChange(selection:any[]){ids.length=0;ids.push(...selection.map((item:any)=>item.id))}
function handleAdd(){router.push({path:'/wms/stock_out/create'})}
function handleStockOut(row:any){
  router.push({path:'stock_out', query:{id:row.id}})
}

onMounted(()=>{
  getUserProfile().then((res:any)=>{
    const user=res.data||res.user
    if(user?.userType===0){listWarehouse({pageSize:50,warehouseType:'LOCAL'}).then((res:any)=>{warehouseList.value=res.rows||[];getList()})}
    else{
      listWarehouse({pageSize:50,warehouseType:'LOCAL'}).then((res:any)=>{warehouseList.value=res.rows||[];getList()})
    }
  })
})
</script>
