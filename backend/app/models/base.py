"""
CozyClean 数据库模型定义（SQLAlchemy ORM）
严格对照 PostgreSQL 终极 Schema 设计，使用 ORM 声明式映射，杜绝原生 SQL 拼接。

表清单：
  1. users              - 用户核心资产表
  2. sync_session_logs  - 会话总览表
  3. sync_photo_actions - 单张照片操作同步表
  4. app_config         - 全局动态配置表
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    Column,
    String,
    Text,
    Boolean,
    Integer,
    BigInteger,
    SmallInteger,
    DateTime,
    ForeignKey,
    Index,
)
from sqlalchemy.dialects.postgresql import UUID, JSONB, CHAR
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.core.database import Base


# ============================================
# 1. 用户核心资产表 (users)
# ============================================
class Users(Base):
    """
    用户主表，存储账户信息与核心资产统计。
    phone_number 使用 VARCHAR(255) 而非常规手机号长度：
      预留 AES-256 加密后的密文存储空间（加密后 Base64 约为原文 3 倍长度）。
    """
    __tablename__ = "users"

    uid = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        comment="用户唯一标识",
    )
    phone_number = Column(
        String(255),
        unique=True,
        nullable=False,
        comment="手机号（AES-256 加密存储，预留密文长度）",
    )
    nickname = Column(
        String(50),
        nullable=True,
        comment="用户昵称",
    )
    avatar_url = Column(
        Text,
        nullable=True,
        comment="头像 URL",
    )
    is_pro = Column(
        Boolean,
        default=False,
        nullable=False,
        comment="是否为 Pro 会员",
    )
    pro_expire_at = Column(
        DateTime,
        nullable=True,
        comment="Pro 会员过期时间",
    )
    current_energy = Column(
        Integer,
        default=50,
        nullable=False,
        comment="当前能量值（免费用户每日配额）",
    )
    total_saved_bytes = Column(
        BigInteger,
        default=0,
        nullable=False,
        comment="累计节省的存储空间（字节）",
    )
    total_deleted_count = Column(
        Integer,
        default=0,
        nullable=False,
        comment="累计删除照片数",
    )
    last_login_at = Column(
        DateTime,
        nullable=True,
        comment="最后登录时间",
    )
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=func.now(),
        comment="账户创建时间",
    )

    # ORM 关系：一个用户可有多条会话日志和照片操作记录
    session_logs = relationship("SyncSessionLogs", back_populates="user", lazy="dynamic")
    photo_actions = relationship("SyncPhotoActions", back_populates="user", lazy="dynamic")


# ============================================
# 2. 会话总览表 (sync_session_logs)
# ============================================
class SyncSessionLogs(Base):
    """
    记录每次同步会话的汇总数据。
    mode 使用 SMALLINT 而非枚举字符串：
      节省存储空间，前端用常量映射显示文字，便于后续扩展新模式。
    """
    __tablename__ = "sync_session_logs"

    session_id = Column(
        String(64),
        primary_key=True,
        comment="会话唯一 ID（客户端生成）",
    )
    uid = Column(
        UUID(as_uuid=True),
        ForeignKey("users.uid", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="关联用户",
    )
    mode = Column(
        SmallInteger,
        nullable=False,
        comment="整理模式（0=快速模式, 1=深度模式, 2=时光旅行 等）",
    )
    deleted_count = Column(
        Integer,
        default=0,
        nullable=False,
        comment="本次会话删除数量",
    )
    saved_bytes = Column(
        BigInteger,
        default=0,
        nullable=False,
        comment="本次会话节省空间（字节）",
    )
    start_time = Column(
        DateTime,
        nullable=True,
        comment="会话开始时间",
    )
    device_id = Column(
        String(64),
        nullable=True,
        comment="设备标识（用于多设备场景追踪）",
    )
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=func.now(),
        comment="记录创建时间",
    )

    # ORM 反向关系
    user = relationship("Users", back_populates="session_logs")


# ============================================
# 3. 单张照片操作同步表 (sync_photo_actions)
# ============================================
class SyncPhotoActions(Base):
    """
    逐条记录用户对每张照片的操作（保留/删除/标记等）。
    为什么用 BIGSERIAL 主键：照片操作量级大，INT 可能不够。
    联合索引 idx_photo_md5(uid, photo_md5)：加速"某用户是否已处理过某张照片"的查询。
    """
    __tablename__ = "sync_photo_actions"

    action_id = Column(
        BigInteger,
        primary_key=True,
        autoincrement=True,
        comment="操作记录自增 ID（BIGSERIAL）",
    )
    uid = Column(
        UUID(as_uuid=True),
        ForeignKey("users.uid", ondelete="CASCADE"),
        nullable=False,
        comment="关联用户",
    )
    photo_md5 = Column(
        CHAR(32),
        nullable=False,
        comment="照片 MD5 指纹（用于去重与同步校验）",
    )
    action_type = Column(
        SmallInteger,
        nullable=False,
        comment="操作类型（0=保留, 1=删除, 2=收藏 等）",
    )
    action_source = Column(
        String(10),
        default="ANDROID",
        nullable=False,
        comment="操作来源平台",
    )
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=func.now(),
        comment="记录创建时间",
    )

    # ORM 反向关系
    user = relationship("Users", back_populates="photo_actions")

    # 联合索引：加速按用户 + 照片哈希的查询
    __table_args__ = (
        Index("idx_photo_md5", "uid", "photo_md5"),
    )


# ============================================
# 4. 全局动态配置表 (app_config)
# ============================================
class AppConfig(Base):
    """
    全局动态配置表，支持运行时热更新。
    为什么用 JSONB 存 config_value：
      - 无需为每种配置新增列，灵活性强
      - PostgreSQL JSONB 支持索引和丰富的查询操作符
    """
    __tablename__ = "app_config"

    config_key = Column(
        String(50),
        primary_key=True,
        comment="配置键名",
    )
    config_value = Column(
        JSONB,
        nullable=True,
        comment="配置值（JSONB 格式，支持复杂结构）",
    )
    description = Column(
        Text,
        nullable=True,
        comment="配置项说明",
    )
