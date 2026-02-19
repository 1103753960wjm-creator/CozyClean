"""
CozyClean 全局配置模块
使用 pydantic-settings 从 .env 文件加载配置，提供类型安全的环境变量访问。
为什么用 pydantic-settings 而不是 os.getenv：
  - 自动类型转换与校验，启动时即暴露配置错误
  - IDE 自动补全友好，减少拼写错误
"""

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """应用全局配置，字段值优先从环境变量 / .env 文件读取"""

    # 数据库连接
    DATABASE_URL: str = "postgresql://postgres:your_password@localhost:5432/cozyclean"

    # 运行环境
    APP_ENV: str = "development"
    APP_DEBUG: bool = True

    # 限流配置
    RATE_LIMIT_PER_MINUTE: int = 60

    # JWT 鉴权配置
    SECRET_KEY: str = "change-me-to-a-random-secret-key"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 默认 24 小时

    model_config = {
        "env_file": ".env",       # 自动从项目根目录的 .env 加载
        "env_file_encoding": "utf-8",
        "case_sensitive": True,   # 环境变量名大小写敏感
    }


@lru_cache()
def get_settings() -> Settings:
    """
    单例模式获取配置实例。
    为什么用 lru_cache：避免每次请求都重新解析 .env，提升性能。
    """
    return Settings()
