"""
CozyClean 同步相关的 Pydantic Schemas
职责：定义 Sync API 的请求/响应数据结构。
"""

from typing import List
from pydantic import BaseModel, Field


class PhotoActionSchema(BaseModel):
    """单张照片的操作记录"""
    md5: str = Field(..., min_length=32, max_length=32, description="照片 MD5 哈希")
    action_type: int = Field(..., description="操作类型（0=保留, 1=删除, 2=收藏）")
    action_source: str = Field(default="ANDROID", max_length=10, description="操作来源平台")


class SyncRequest(BaseModel):
    """同步上传请求体"""
    session_id: str = Field(..., max_length=64, description="客户端生成的会话 ID")
    mode: int = Field(..., description="整理模式（0=快速, 1=深度, 2=时光旅行）")
    actions: List[PhotoActionSchema] = Field(..., description="照片操作列表")


class SyncResponse(BaseModel):
    """同步上传响应"""
    status: str = Field(default="ok", description="操作结果状态")
    synced_count: int = Field(..., description="成功同步的操作数量")
