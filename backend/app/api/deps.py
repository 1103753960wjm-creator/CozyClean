"""
CozyClean FastAPI 依赖注入模块
职责：提供可复用的请求级依赖，通过 Depends() 注入到路由函数中。

为什么集中管理依赖：
  - 统一鉴权逻辑，避免每个路由重复写 Token 解析代码
  - 方便单元测试时 Mock 替换
"""

from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.database import get_db as _get_db

settings = get_settings()

# OAuth2PasswordBearer 告诉 FastAPI：
# 1. 从 Authorization: Bearer <token> 头中提取 token
# 2. 在 Swagger UI 中自动显示「Authorize 🔒」按钮
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_db():
    """
    数据库 Session 依赖。
    直接复用 database.py 中已有的 generator，保持单一数据源。
    """
    yield from _get_db()


async def get_current_user(
    token: str = Depends(oauth2_scheme),
) -> UUID:
    """
    JWT 鉴权依赖：解析 Token 并返回当前用户的 uid。

    为什么返回 UUID 而不是完整的 User ORM 对象：
      - 减少每次请求的数据库查询开销
      - 大部分接口只需要 uid 即可关联写入
      - 如需完整用户信息，路由内再按需查询

    Raises:
        HTTPException 401: Token 缺失、过期或格式无效
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="无法验证身份凭证，请重新登录",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        # sub 字段存储的是用户 uid 字符串
        uid_str: str = payload.get("sub")
        if uid_str is None:
            raise credentials_exception

        uid = UUID(uid_str)
    except (JWTError, ValueError):
        # JWTError: token 解码失败（过期、篡改等）
        # ValueError: uid 字符串无法转为 UUID
        raise credentials_exception

    return uid
