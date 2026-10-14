import request from '@/utils/request'
import { getToken } from '@/utils/auth'

export interface AiAnalysisRecord {
  id?: number
  analysisType: string
  analysisContent: string
  promptContent?: string
  analysisResult?: string
  status: number // 0-分析中, 1-已完成, 2-失败
  errorMessage?: string
  userId?: number
  createdTime?: string
  updatedTime?: string
}

export interface AnalysisRequest {
  analysisType: string
  content?: string
}

export function executeAnalysis(data: AnalysisRequest): Promise<Response> {
  const token = getToken()
  return fetch('/api/ai/analysis/execute', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`
    },
    body: JSON.stringify(data)
  })
}

export function getAnalysisList(params: { pageNum?: number; pageSize?: number }) {
  return request({
    url: '/api/ai/analysis/list',
    method: 'get',
    params
  })
}

export function getAnalysisDetail(id: number) {
  return request({
    url: `/api/ai/analysis/${id}`,
    method: 'get'
  })
}

export function deleteAnalysis(id: number) {
  return request({
    url: `/api/ai/analysis/${id}`,
    method: 'delete'
  })
}
