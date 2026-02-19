"""
CozyClean 认证路由
POST /api/v1/auth/login — 手机号 + 验证码登录

业务流程：
  1. 校验验证码（当前 Mock 固定为 "1234"）
  2. 加密手机号 → 查询/创建用户
  3. 签发 JWT Token
  4. 返回 LoginResponse
"""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.core.security import create_access_token, encrypt_phone
from app.models.base import Users
from app.schemas.auth import LoginRequest, LoginResponse, UserResponse
from app.core.limiter import limiter

router = APIRouter(prefix="/auth", tags=["认证"])


@router.post("/login", response_model=LoginResponse)
@limiter.limit("3/minute")
async def login(
    request: Request,
    body: LoginRequest,
    db: Session = Depends(get_db),
):
    """
    手机号验证码登录（Mock 版本）。

    限流策略：3次/分钟，防止验证码接口被暴力刷取。
    为什么用 @limiter.limit 而不是全局限流：
      登录接口是安全敏感点，需要比普通接口更严格的频率控制。
    """

    # ---- 1. 验证码校验（Mock：固定 "1234"） ----
    if body.code != "1234":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="验证码错误，请重新输入",
        )

    # ---- 2. 加密手机号，防止明文存储 PII ----
    encrypted_phone = encrypt_phone(body.phone)

    # ---- 3. 查询或创建用户（ORM 操作，杜绝 SQL 拼接） ----
    user = db.query(Users).filter(
        Users.phone_number == encrypted_phone
    ).first()

    if user is None:
        # 新用户注册：自动创建账户
        user = Users(
            phone_number=encrypted_phone,
            last_login_at=datetime.now(timezone.utc),
        )
        db.add(user)
        db.commit()
        db.refresh(user)  # 刷新以获取数据库生成的 uid 和 created_at
    else:
        # 老用户登录：更新最后登录时间
        user.last_login_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(user)

    # ---- 4. 签发 JWT Token ----
    access_token = create_access_token(data={"sub": str(user.uid)})

    # ---- 5. 构造响应 ----
    return LoginResponse(
        token=access_token,
        user=UserResponse(
            uid=user.uid,
            is_pro=user.is_pro,
        ),
    )
