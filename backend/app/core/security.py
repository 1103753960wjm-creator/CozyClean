"""
CozyClean 安全工具模块
职责：
  1. JWT 令牌的签发与验证
  2. 手机号加密/解密占位函数（Mock AES-256）

安全说明：
  - JWT 使用 HS256 对称签名，SECRET_KEY 必须保密
  - 手机号加密当前为 Base64 Mock 实现
"""

import base64
from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import jwt, JWTError

from app.core.config import get_settings

settings = get_settings()


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    生成 JWT 访问令牌。
    为什么在 payload 中嵌入 exp：让令牌自带过期时间，无需服务端维护 session 状态。

    Args:
        data: 要编码的数据（通常包含 sub=uid）
        expires_delta: 自定义过期时长，默认从配置读取

    Returns:
        编码后的 JWT 字符串
    """
    to_encode = data.copy()

    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        )

    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(
        to_encode,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )
    return encoded_jwt


def encrypt_phone(phone: str) -> str:
    """
    手机号加密 — Mock 实现（Base64 编码）。

    ⚠️ 安全规范提醒：
    根据安全规范，此处未来需接入真实的 AES-256-GCM 算法保护 PII（个人身份信息）。
    当前使用 Base64 仅作为开发阶段的占位实现，不具备任何加密安全性。
    正式上线前必须替换为：
      - AES-256-GCM 加密
      - 密钥通过 KMS 管理
      - 每条记录使用独立 IV/Nonce
    """
    return base64.b64encode(phone.encode("utf-8")).decode("utf-8")


def decrypt_phone(encrypted_phone: str) -> str:
    """
    手机号解密 — Mock 实现（Base64 解码）。

    ⚠️ 安全规范提醒：
    根据安全规范，此处未来需接入真实的 AES-256-GCM 算法保护 PII。
    """
    return base64.b64decode(encrypted_phone.encode("utf-8")).decode("utf-8")
