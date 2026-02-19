"""
CozyClean Backend 入口
职责：
  1. 初始化 FastAPI 应用实例
  2. 配置 CORS 中间件（本地开发全放行）
  3. 集成 SlowAPI 全局限流防刷骨架
  4. 注册 API 路由
  5. 提供健康检查端点
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.core.config import get_settings
from app.core.limiter import limiter
from app.api.v1 import auth as auth_router
from app.api.v1 import sync as sync_router

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    应用生命周期管理（FastAPI 推荐的 lifespan 模式）。
    startup: 可在此处初始化数据库连接池、缓存等资源
    shutdown: 可在此处优雅关闭连接
    """
    # --- Startup ---
    print("🧹 CozyClean Backend 启动中...")
    yield
    # --- Shutdown ---
    print("🧹 CozyClean Backend 正在关闭...")


# ============================================
# FastAPI 应用实例
# ============================================
app = FastAPI(
    title="CozyClean API",
    description="治愈系相册整理 App 后端服务",
    version="0.1.0",
    lifespan=lifespan,
)

# 将 limiter 挂载到 app state，SlowAPI 要求此步骤
app.state.limiter = limiter

# 注册限流超限的异常处理器，返回 429 状态码
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


# ============================================
# CORS 中间件配置
# 本地开发阶段：允许所有来源，方便 Flutter / Web 调试
# 生产环境应收窄 allow_origins 为具体域名
# ============================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # 开发环境全放行
    allow_credentials=True,
    allow_methods=["*"],          # 允许所有 HTTP 方法
    allow_headers=["*"],          # 允许所有请求头
)


# ============================================
# 路由注册
# 统一前缀 /api/v1，方便未来版本迭代（如 /api/v2）
# ============================================
app.include_router(auth_router.router, prefix="/api/v1")
app.include_router(sync_router.router, prefix="/api/v1")


# ============================================
# 健康检查端点
# 为什么需要：部署时 k8s/Docker 的 liveness probe 会用到
# ============================================
@app.get("/health", tags=["系统"])
@limiter.limit(f"{settings.RATE_LIMIT_PER_MINUTE}/minute")
async def health_check(request: Request):
    """服务健康检查，同时演示 SlowAPI 限流的用法"""
    return JSONResponse(
        status_code=200,
        content={
            "status": "healthy",
            "service": "CozyClean Backend",
            "version": "0.1.0",
        },
    )
