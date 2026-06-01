#!/bin/bash
# TeslaMate 中文仪表盘 — 数据库定期备份脚本
#
# 用法（在仓库根目录运行，或挂到 cron / 群晖任务计划）:
#   bash scripts/backup.sh
#   BACKUP_DIR=/volume1/backup KEEP=7 bash scripts/backup.sh
#
# 自动完成（幂等，安全）:
#   1. 自动检测运行中的 PostgreSQL 容器名（可用 DB_CONTAINER 覆盖）
#   2. pg_dump -Fc 导出到临时文件
#   3. 校验导出成功（退出码 + 文件非空 + pg_restore -l 可列出）
#   4. 仅校验通过后才原子改名为正式备份，并清理超出保留份数的旧备份
#   5. 全程写日志到 $BACKUP_DIR/backup.log，任何失败 exit 1（cron/任务计划可报警）
#
# 安全保证（这是本脚本存在的理由）:
#   - pg_dump 失败 → 立即中止，不产出文件、绝不删除任何旧备份
#   - 本轮备份未确认成功 → 保留清理一步不执行
#   - 只写备份、从不碰数据库，回滚天然安全
#
# ⚠️ 本脚本只备份数据库。ENCRYPTION_KEY（在 docker-compose.yml / .env）请另行留底，
#    否则即使数据库恢复成功，Tesla token 也永远解密不出来，必须重新授权。
#
# 本脚本产出 -Fc 格式，恢复要用 pg_restore（不是 psql < xxx.sql）。
# 恢复 + 演练流程见 TROUBLESHOOTING.md「定期自动备份数据库」(#db-backup) 与「整机迁移」恢复步骤。

set -euo pipefail

# ---- 可配置项（env 覆盖，均有默认值）----
BACKUP_DIR="${BACKUP_DIR:-./backups}"   # 备份输出目录；群晖建议 /volume1/backup
KEEP="${KEEP:-4}"                        # 保留最近几份（按时间，count-based，更稳）
DB_USER="${DB_USER:-teslamate}"
DB_NAME="${DB_NAME:-teslamate}"
DB_CONTAINER="${DB_CONTAINER:-}"         # 留空则自动探测

# 安全下限：至少保留 1 份（含本轮刚生成的），防止 KEEP=0 把新备份也删掉
case "$KEEP" in
    ''|*[!0-9]*) KEEP=4 ;;                # 非数字 → 回落默认
esac
[ "$KEEP" -lt 1 ] && KEEP=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- 日志（同时写 stdout 和 $BACKUP_DIR/backup.log）----
log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"; }
die() { log "❌ $1"; exit 1; }

# ---- 容器探测：复用 lib/detect-containers.sh（与 upgrade.sh 同源）----
if [ -z "$DB_CONTAINER" ]; then
    if [ -f "$SCRIPT_DIR/lib/detect-containers.sh" ]; then
        # shellcheck source=lib/detect-containers.sh
        source "$SCRIPT_DIR/lib/detect-containers.sh"
        DB_CONTAINER="$(detect_db_container || true)"
    fi
fi
[ -z "$DB_CONTAINER" ] && die "找不到 PostgreSQL 容器。请确认 TeslaMate 在运行，或用 DB_CONTAINER=容器名 显式指定。"

# ---- 准备目录 ----
mkdir -p "$BACKUP_DIR" || die "无法创建备份目录：$BACKUP_DIR"
LOGFILE="$BACKUP_DIR/backup.log"
# 把后续 stdout/stderr 追加进日志文件（同时仍打印到终端）
exec > >(tee -a "$LOGFILE") 2>&1

STAMP="$(date '+%Y%m%d_%H%M')"
FINAL="$BACKUP_DIR/teslamate-$STAMP.dump"
TMP="$BACKUP_DIR/.teslamate-$STAMP.dump.tmp"

log "===== 开始备份（容器：$DB_CONTAINER，目录：$BACKUP_DIR，保留：$KEEP 份）====="

# ---- 1. 导出（-Fc 自定义格式，压缩 + 可被 pg_restore 选择性恢复）----
rc=0
docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" -Fc "$DB_NAME" > "$TMP" || rc=$?
if [ "$rc" -ne 0 ]; then
    rm -f "$TMP"
    die "pg_dump 失败（退出码 $rc）。未产出备份，旧备份保持不动。"
fi

# ---- 2. 校验：文件非空 ----
SIZE=$(wc -c < "$TMP" 2>/dev/null || echo 0)
if [ "$SIZE" -lt 1000 ]; then
    rm -f "$TMP"
    die "导出文件异常小（$SIZE 字节），判定无效。旧备份保持不动。"
fi

# ---- 3. 校验：pg_restore -l 能列出归档（用容器内的 pg_restore，host 不一定装）----
if ! docker exec -i "$DB_CONTAINER" pg_restore -l > /dev/null 2>&1 < "$TMP"; then
    rm -f "$TMP"
    die "备份文件无法被 pg_restore 解析，判定损坏。旧备份保持不动。"
fi

# ---- 4. 原子改名为正式备份（此前都没动过任何已有备份）----
mv -f "$TMP" "$FINAL"
HUMAN_SIZE=$(du -h "$FINAL" 2>/dev/null | cut -f1)
log "✅ 备份成功：$FINAL（$HUMAN_SIZE）"

# ---- 5. 保留清理：仅本轮成功后执行，按时间保留最近 $KEEP 份 ----
# 文件名为受控零填充时间戳（teslamate-YYYYmmdd_HHMM.dump），字典序即时间序，
# 避免用 ls 解析（刚创建 $FINAL，数组至少含 1 个元素）。
shopt -s nullglob
all_backups=("$BACKUP_DIR"/teslamate-*.dump)
shopt -u nullglob

sorted=()   # 新→旧（不用 mapfile，兼容 bash 3.2）
if [ "${#all_backups[@]}" -gt 0 ]; then
    while IFS= read -r line; do
        sorted+=("$line")
    done < <(printf '%s\n' "${all_backups[@]}" | sort -r)
fi

REMAIN=${#sorted[@]}
DELETED=0
if [ "$REMAIN" -gt "$KEEP" ]; then
    for old in "${sorted[@]:$KEEP}"; do
        rm -f "$old" && { log "🧹 清理旧备份：$old"; DELETED=$((DELETED+1)); }
    done
    REMAIN=$KEEP
fi
log "===== 完成：现存 $REMAIN 份备份，本轮清理 $DELETED 份 ====="
log "提醒：ENCRYPTION_KEY（docker-compose.yml / .env）请单独留底，否则恢复后 token 解不开。"
