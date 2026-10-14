package cn.qihangerp.erp.controller.ai;

import cn.qihangerp.common.AjaxResult;
import cn.qihangerp.common.PageQuery;
import cn.qihangerp.common.PageResult;
import cn.qihangerp.erp.serviceImpl.ai.AiAnalysisService;
import cn.qihangerp.model.entity.AiAnalysisRecord;
import cn.qihangerp.security.common.BaseController;
import cn.qihangerp.service.IAiAnalysisRecordService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/**
 * AI智能分析控制器
 */
@RequiredArgsConstructor
@RestController
@RequestMapping("/api/ai/analysis")
public class AiAnalysisController extends BaseController {

    private final AiAnalysisService aiAnalysisService;
    private final IAiAnalysisRecordService analysisRecordService;

    /**
     * 触发智能分析（SSE流式返回）
     */
    @PostMapping(value = "/execute", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter executeAnalysis(@RequestBody AnalysisRequest request) {
        SseEmitter emitter = new SseEmitter(180000L);
        aiAnalysisService.executeAnalysis(
                request.getAnalysisType(),
                request.getContent(),
                emitter,
                getUserId()
        );
        return emitter;
    }

    /**
     * 分析记录分页列表
     */
    @GetMapping("/list")
    public AjaxResult list(PageQuery query) {
        PageResult<AiAnalysisRecord> page = analysisRecordService.queryPageList(query);
        return AjaxResult.success(page);
    }

    /**
     * 分析记录详情
     */
    @GetMapping("/{id}")
    public AjaxResult getById(@PathVariable Long id) {
        AiAnalysisRecord record = analysisRecordService.getById(id);
        if (record == null) {
            return AjaxResult.error("记录不存在");
        }
        return AjaxResult.success(record);
    }

    /**
     * 删除分析记录
     */
    @DeleteMapping("/{id}")
    public AjaxResult remove(@PathVariable Long id) {
        analysisRecordService.removeById(id);
        return AjaxResult.success();
    }

    public static class AnalysisRequest {
        private String analysisType;
        private String content;

        public String getAnalysisType() { return analysisType; }
        public void setAnalysisType(String analysisType) { this.analysisType = analysisType; }
        public String getContent() { return content; }
        public void setContent(String content) { this.content = content; }
    }
}
