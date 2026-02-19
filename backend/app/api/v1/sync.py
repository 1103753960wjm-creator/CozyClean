"""
CozyClean 同步路由
POST /api/v1/sync/upload — 上传照片操作记录

业务流程：
  1. JWT 鉴权（通过 get_current_user 依赖注入）
  2. 创建 sync_session_logs 记录
  3. 批量插入 sync_photo_actions 记录
  4. 事务提交，返回同步数量
"""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user
from app.models.base import SyncSessionLogs, SyncPhotoActions
from app.schemas.sync import SyncRequest, SyncResponse

router = APIRouter(prefix="/sync", tags=["同步"])


@router.post("/upload", response_model=SyncResponse)
async def sync_upload(
    body: SyncRequest,
    uid: UUID = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    上传照片整理操作记录。

    为什么用数据库事务包裹整个操作：
      session_log 和 photo_actions 是一个原子操作，
      如果批量插入中途失败，应该全部回滚，避免数据不一致。
    """

    try:
        # ---- 1. 创建会话日志 ----
        session_log = SyncSessionLogs(
            session_id=body.session_id,
            uid=uid,
            mode=body.mode,
            deleted_count=sum(
                1 for a in body.actions if a.action_type == 1
            ),
        )
        db.add(session_log)

        # ---- 2. 批量插入照片操作记录 ----
        # 为什么不用 bulk_insert_mappings：
        #   ORM 对象方式可自动填充 server_default 字段，且代码可读性更好。
        #   在操作量级不超过数千条时，性能差异可忽略。
        photo_actions = [
            SyncPhotoActions(
                uid=uid,
                photo_md5=action.md5,
                action_type=action.action_type,
                action_source=action.action_source,
            )
            for action in body.actions
        ]
        db.add_all(photo_actions)

        # ---- 3. 事务提交 ----
        db.commit()

        return SyncResponse(
            status="ok",
            synced_count=len(body.actions),
        )

    except Exception as e:
        # 任何异常都回滚事务，保证数据一致性
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"同步失败，请稍后重试: {str(e)}",
        )
