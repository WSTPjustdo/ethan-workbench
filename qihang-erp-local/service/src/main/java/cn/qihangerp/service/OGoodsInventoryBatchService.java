package cn.qihangerp.service;

import cn.qihangerp.model.entity.OGoodsInventoryBatch;
import com.baomidou.mybatisplus.extension.service.IService;

/**
 * 主系统商品库存批次 Service 接口
 *
 * @author qihang
 */
public interface OGoodsInventoryBatchService extends IService<OGoodsInventoryBatch> {

    /**
     * 根据库存记录ID查询批次列表
     */
    java.util.List<OGoodsInventoryBatch> listByInventoryId(Long inventoryId);

    /**
     * 扣减批次库存
     *
     * @param batchId  批次ID
     * @param quantity 扣减数量
     * @return 是否成功
     */
    boolean deductBatchStock(Long batchId, Integer quantity);

    /**
     * 根据条码或SKU编码查询可用批次（currentQty > 0）
     *
     * @param keyword 条码或SKU编码
     * @param warehouseId 仓库ID（可选，为null时查所有仓库）
     * @return 匹配的批次列表
     */
    java.util.List<OGoodsInventoryBatch> searchByKeyword(String keyword, Long warehouseId);
}