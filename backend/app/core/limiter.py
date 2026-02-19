"""
CozyClean 全局限流器
将 SlowAPI Limiter 实例抽取到独立模块，避免 main.py ↔ 路由文件 的循环导入。
"""

from slowapi import Limiter
from slowapi.util import get_remote_address

# key_func=get_remote_address: 按客户端 IP 限流
# 为什么全局单例：确保所有路由共享同一个限流状态
limiter = Limiter(key_func=get_remote_address)
