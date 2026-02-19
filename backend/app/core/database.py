"""
CozyClean 数据库连接模块
职责：创建 SQLAlchemy 引擎、会话工厂，以及 FastAPI 依赖注入用的 get_db 生成器。
为什么用 sessionmaker + generator：
  - 每个请求独立事务，请求结束后自动关闭连接
  - 配合 FastAPI 的 Depends() 实现声明式依赖注入
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from app.core.config import get_settings

settings = get_settings()

# pool_pre_ping=True: 每次从连接池取连接前先 ping 一下，避免用到已断开的连接
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    echo=settings.APP_DEBUG,  # 开发环境打印 SQL，生产环境关闭
)

# autocommit=False: 手动控制事务提交，更安全
# autoflush=False:  避免意外的自动 flush 导致脏数据写入
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

# 所有 ORM 模型的基类
Base = declarative_base()


def get_db():
    """
    FastAPI 依赖注入：为每个请求提供独立的数据库会话。
    使用 try/finally 确保连接一定会被归还到连接池。
    用法：db: Session = Depends(get_db)
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
