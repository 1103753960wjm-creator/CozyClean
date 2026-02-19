"""
CozyClean 认证相关的 Pydantic Schemas
职责：定义 Auth API 的请求/响应数据结构，由 FastAPI 自动校验。
"""

from uuid import UUID
from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    """登录请求体：手机号 + 验证码"""
    phone: str = Field(..., min_length=1, description="用户手机号")
    code: str = Field(..., min_length=1, description="短信验证码")


class UserResponse(BaseModel):
    """用户基础信息（嵌套在登录响应中）"""
    uid: UUID
    is_pro: bool

    model_config = {"from_attributes": True}  # 支持从 ORM 对象直接转换


class LoginResponse(BaseModel):
    """登录成功响应：JWT 令牌 + 用户信息"""
    token: str
    user: UserResponse
