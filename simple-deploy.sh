#!/bin/bash
# TeslaMate 中文 Dashboard 一键安装脚本
# 5分钟完成 TeslaMate + 中文 Grafana Dashboard 部署

set -e
set -o pipefail

# 强制 docker compose project name = teslamate，
# 让容器名稳定为 teslamate-database-1 / teslamate-grafana-1 等，
# 与 README/QUICKSTART/TROUBLESHOOTING 文档里所有 docker exec 命令一致
export COMPOSE_PROJECT_NAME=teslamate

# SQL 文件拉取的 git ref（默认 main 跟 :latest 镜像同步）。
# 想锁固定版本：SQL_REF=v1.6.2 bash simple-deploy.sh（详见 README「SQL 远程拉取的信任模型」）
SQL_REF="${SQL_REF:-main}"
SQL_BASE="https://raw.githubusercontent.com/wjsall/teslamate-chinese-dashboards/${SQL_REF}/sql"

echo "=============================================="
echo "  TeslaMate 中文 Dashboard 一键安装脚本"
echo "=============================================="
echo ""
echo "📦 安装内容："
echo "  - TeslaMate 后端"
echo "  - PostgreSQL 数据库"
echo "  - Grafana + 中文 Dashboard（40个）"
echo "  - MQTT 消息服务"
echo "  - 🌏 地图源切换 + GCJ-02 自动纠偏（v1.4.2 中文版独有）"
echo ""
echo "⏱️  预计耗时：5-10 分钟"
echo ""
echo "📌 说明：TeslaMate 使用 Tesla Fleet API（OAuth）授权，"
echo "         安装完成后在 TeslaMate 界面中完成车辆绑定。"
echo ""

# 检查 Docker 和 Docker Compose
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装"
    echo ""
    echo "请先安装 Docker："
    echo "  Ubuntu: curl -fsSL https://get.docker.com | bash"
    echo "  CentOS: sudo yum install docker"
    echo "  群晖 NAS：套件中心安装「Container Manager」（DSM 7.2+）或「Docker」（旧版）"
    echo ""
    exit 1
fi

# 检查 docker daemon 实际可访问（不只是命令存在）—— 群晖 SSH 用户没 docker 组权限会卡这里
if ! docker info >/dev/null 2>&1; then
    echo "❌ docker 命令存在但跑不动（没有 daemon 访问权限）"
    echo ""
    echo "可能原因 + 修法："
    echo "  - 群晖 SSH 用户：先在 DSM 控制面板开启 root SSH，sudo -i 切 root 后重跑此脚本"
    echo "    或改用 Container Manager「项目」模式 GUI 部署（不用命令行）"
    echo "  - Linux 用户：sudo usermod -aG docker \$USER && newgrp docker"
    echo "  - 任何系统：用 sudo bash $(basename "$0")"
    echo ""
    exit 1
fi

# 检查 Docker Compose 是 v1 还是 v2，并把命令名存到 $DC（后续所有命令通过 $DC 调用）
if docker compose version >/dev/null 2>&1; then
    DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DC="docker-compose"
    echo "⚠️ 检测到 docker-compose v1（已过时），建议升级到 v2（docker compose）"
    echo "   v2 安装：sudo apt install docker-compose-plugin（或参考 docker.com 官方文档）"
    echo "   本脚本仍兼容 v1，但部分命令可能稍慢"
    echo ""
else
    echo "❌ Docker Compose 未安装（v1 / v2 都没找到）"
    echo ""
    echo "请先安装 Docker Compose v2（推荐）："
    echo "  sudo apt install docker-compose-plugin"
    exit 1
fi

# 创建工作目录
INSTALL_DIR="${HOME}/teslamate-chinese"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "📁 工作目录: $INSTALL_DIR"
echo ""

# ============================================================
# 已存在检测：如果 docker-compose.yml 已经存在，转升级模式
# 避免覆盖用户的 ENCRYPTION_KEY、Tesla CN API 配置等
# ============================================================
if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
    echo "🔄 检测到已有安装，进入升级模式（不会改你的配置）..."
    echo ""
    echo "  → 拉取最新镜像"
    $DC pull
    echo ""
    echo "  → 重启服务（应用新镜像）"
    $DC up -d
    echo ""
    echo "  → 等数据库就绪"
    DB_CONTAINER=$($DC ps -q database 2>/dev/null | head -1)
    [ -z "$DB_CONTAINER" ] && DB_CONTAINER=$(docker ps --format '{{.Names}}' | grep -iE 'teslamate.*database' | head -1)
    DB_READY=0
    for i in $(seq 1 30); do
        if docker exec "$DB_CONTAINER" psql -U teslamate -d teslamate -c "SELECT 1" >/dev/null 2>&1; then
            DB_READY=1
            break
        fi
        sleep 2
    done
    echo ""
    if [ "$DB_READY" -eq 1 ]; then
        echo "  → 安装/更新坐标转换函数"
        if curl -fsSL "$SQL_BASE/install-coord-functions.sql" | docker exec -i "$DB_CONTAINER" psql -U teslamate -d teslamate >/dev/null 2>&1; then
            echo "  ✓ 坐标函数已更新（地图源切换/纠偏）"
        else
            echo "  ⚠ 坐标函数更新失败"
        fi

        echo "  → 安装/更新分时电价表 + 函数（v1.5.0+）"
        if curl -fsSL "$SQL_BASE/install-tou.sql" | docker exec -i "$DB_CONTAINER" psql -U teslamate -d teslamate >/dev/null 2>&1; then
            echo "  ✓ 分时电价已就绪（首次装好后到「⚡ 分时电价配置」仪表盘填规则）"
        else
            echo "  ⚠ 分时电价更新失败，TOU 仪表盘可能不可用"
        fi

        echo "  → 安装/更新性能优化索引（v1.6.1+）"
        if curl -fsSL "$SQL_BASE/install-indexes.sql" | docker exec -i "$DB_CONTAINER" psql -U teslamate -d teslamate >/dev/null 2>&1; then
            echo "  ✓ 索引已就绪（电池健康/天气-能耗等查询提速）"
        else
            echo "  ⚠ 索引安装失败（不影响功能，仅性能略差）"
        fi
        echo ""
        echo "  → 重启 Grafana（让新仪表盘生效）"
        GRAFANA_CONTAINER=$($DC ps -q grafana 2>/dev/null | head -1)
        [ -z "$GRAFANA_CONTAINER" ] && GRAFANA_CONTAINER=$(docker ps --format '{{.Names}}' | grep -iE 'teslamate.*grafana' | head -1)
        [ -n "$GRAFANA_CONTAINER" ] && docker restart "$GRAFANA_CONTAINER" >/dev/null
    else
        echo ""
        echo "  ❌ 数据库 60 秒内未就绪，SQL 函数没装上"
        echo "     等服务起来后**重跑此脚本**（自动进入升级模式重试）："
        echo "     curl -fsSL https://raw.githubusercontent.com/wjsall/teslamate-chinese-dashboards/main/simple-deploy.sh | bash"
        exit 1
    fi
    echo ""
    echo "============================================="
    echo "✅ 升级完成"
    echo "============================================="
    echo ""
    echo "下一步: 浏览器 Ctrl+Shift+R 强刷，看「地图源」下拉框是否就绪"
    echo ""
    echo "📚 完整发版说明: https://github.com/wjsall/teslamate-chinese-dashboards/releases/latest"
    exit 0
fi

# ============================================================
# 全新安装流程
# ============================================================

# 生成 docker-compose.yml
echo "📝 生成配置文件..."

cat > docker-compose.yml << 'EOF'
services:
  teslamate:
    image: teslamate/teslamate:latest
    restart: always
    cap_drop:
      - all
    ports:
      - 4000:4000
    volumes:
      - ./import:/opt/app/import
    environment:
      - ENCRYPTION_KEY=INSERT_RANDOM_KEY_HERE
      - DATABASE_USER=teslamate
      - DATABASE_PASS=password
      - DATABASE_NAME=teslamate
      - DATABASE_HOST=database
      - MQTT_HOST=mosquitto
      # 中国大陆用户：请取消下方两行注释
      # - TESLA_API_HOST=https://owner-api.vn.cloud.tesla.cn
      # - TESLA_WSS_HOST=wss://streaming.vn.cloud.tesla.cn
      - TZ=Asia/Shanghai

  database:
    image: postgres:18-trixie
    restart: always
    volumes:
      - teslamate-db:/var/lib/postgresql
    environment:
      - POSTGRES_USER=teslamate
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=teslamate

  grafana:
    image: bswlhbhmt816/teslamate-chinese-dashboards:latest
    restart: always
    ports:
      - 3000:3000
    volumes:
      - teslamate-grafana-data:/var/lib/grafana
    environment:
      - DATABASE_USER=teslamate
      - DATABASE_PASS=password
      - DATABASE_NAME=teslamate
      - DATABASE_HOST=database
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_DEFAULT_LANGUAGE=zh-Hans

  mosquitto:
    image: eclipse-mosquitto:2
    restart: always
    command: mosquitto -c /mosquitto-no-auth.conf
    volumes:
      - mosquitto-conf:/mosquitto/config
      - mosquitto-data:/mosquitto/data

volumes:
  teslamate-db:
  teslamate-grafana-data:
  mosquitto-conf:
  mosquitto-data:
EOF

# 生成随机加密密钥 + 随机 DB 密码（兼容 Linux 和 macOS）
ENCRYPTION_KEY=$(openssl rand -hex 32)
DB_PASS=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)
if sed --version 2>/dev/null | grep -q GNU; then
  sed -i "s/INSERT_RANDOM_KEY_HERE/$ENCRYPTION_KEY/" docker-compose.yml
  sed -i "s/DATABASE_PASS=password/DATABASE_PASS=$DB_PASS/g" docker-compose.yml
  sed -i "s/POSTGRES_PASSWORD=password/POSTGRES_PASSWORD=$DB_PASS/" docker-compose.yml
else
  sed -i "" "s/INSERT_RANDOM_KEY_HERE/$ENCRYPTION_KEY/" docker-compose.yml
  sed -i "" "s/DATABASE_PASS=password/DATABASE_PASS=$DB_PASS/g" docker-compose.yml
  sed -i "" "s/POSTGRES_PASSWORD=password/POSTGRES_PASSWORD=$DB_PASS/" docker-compose.yml
fi

# 限制 docker-compose.yml 文件权限（含 ENCRYPTION_KEY + DB 密码 + 后续 Tesla token）
chmod 600 docker-compose.yml

echo ""
echo "✅ 配置文件已生成（含随机密钥 + 随机 DB 密码 + 文件权限 600）"
echo ""

# 启动服务
echo "🚀 启动服务（首次启动需要下载镜像，请耐心等待 2-5 分钟）..."
echo "   如果长时间卡在拉取镜像，请参考文末说明配置 Docker 镜像代理。"
$DC up -d

# 检查服务状态
echo ""
echo "📊 服务状态:"
$DC ps

# ============================================================
# 安装 SQL：坐标函数 + 分时电价表 + 性能索引
# ============================================================
echo ""
echo "📍 安装 SQL（坐标函数 / 分时电价 / 性能索引）..."

# 等数据库就绪（最多 60 秒）
DB_CONTAINER=$($DC ps -q database 2>/dev/null | head -1)
if [ -z "$DB_CONTAINER" ]; then
    DB_CONTAINER=$(docker ps --format '{{.Names}}' | grep -iE 'teslamate.*database' | head -1)
fi

DB_READY=0
for i in $(seq 1 30); do
    if docker exec "$DB_CONTAINER" psql -U teslamate -d teslamate -c "SELECT 1" >/dev/null 2>&1; then
        DB_READY=1
        break
    fi
    sleep 2
done

if [ "$DB_READY" -eq 1 ]; then
    SQL_OK=1

    if curl -fsSL "$SQL_BASE/install-coord-functions.sql" | docker exec -i "$DB_CONTAINER" psql -U teslamate -d teslamate >/dev/null 2>&1; then
        echo "  ✓ 坐标转换函数已装（地图源切换+GCJ-02 自动纠偏）"
    else
        echo "  ⚠ 坐标函数安装失败"
        SQL_OK=0
    fi

    if curl -fsSL "$SQL_BASE/install-tou.sql" | docker exec -i "$DB_CONTAINER" psql -U teslamate -d teslamate >/dev/null 2>&1; then
        echo "  ✓ 分时电价表+函数已装（v1.5.0+，首次装好后到「⚡ 分时电价配置」仪表盘填规则）"
    else
        echo "  ⚠ 分时电价安装失败，TOU 仪表盘可能不可用"
        SQL_OK=0
    fi

    if curl -fsSL "$SQL_BASE/install-indexes.sql" | docker exec -i "$DB_CONTAINER" psql -U teslamate -d teslamate >/dev/null 2>&1; then
        echo "  ✓ 性能索引已装（v1.6.1+，电池健康/天气-能耗等查询提速）"
    else
        echo "  ⚠ 索引安装失败（不影响功能，仅性能略差）"
        SQL_OK=0
    fi

    if [ "$SQL_OK" -eq 0 ]; then
        echo ""
        echo "    部分 SQL 安装失败，可手动重跑（按需选）："
        echo "    for f in install-coord-functions install-tou install-indexes; do"
        echo "      curl -fsSL $SQL_BASE/\$f.sql | docker exec -i $DB_CONTAINER psql -U teslamate -d teslamate"
        echo "    done"
    fi
else
    echo "  ⚠ 数据库 60 秒内未就绪，跳过 SQL 安装"
    echo "    服务起来后重跑此脚本（自动进入升级模式）即可装上 SQL"
fi

echo ""
echo "=============================================="
echo "✅ 安装完成！"
echo "=============================================="
echo ""
echo "🚨 立刻保存这两条信息（丢了再也找不回）："
echo ""
echo "  ENCRYPTION_KEY = $ENCRYPTION_KEY"
echo "  DATABASE_PASS  = $DB_PASS"
echo ""
echo "  原文件位置: $INSTALL_DIR/docker-compose.yml （已设 mode 600）"
echo "  抄到密码管理器（1Password / Keychain / Bitwarden）以备未来迁移用。"
echo "  KEY 丢失 = Tesla Token 永远解密不出来 = 必须重新授权。"
echo ""
echo "📱 访问地址："
echo "  - TeslaMate:  http://localhost:4000"
echo "  - Grafana:     http://localhost:3000"
echo ""
echo "🔐 Grafana 登录信息："
echo "  - 用户名: admin"
echo "  - 密码: admin"
echo "  ⚠️ 公网部署必须立即改 Grafana admin 密码"
echo "    Grafana 右上角头像 → Profile → Change password"
echo ""
echo "📝 下一步："
echo "  1. 访问 TeslaMate: http://localhost:4000"
echo "  2. 按照页面引导完成 Tesla 账号授权（OAuth）"
echo "  3. 车辆会自动开始同步数据"
echo "  4. 几分钟后访问 Grafana 查看中文 Dashboard"
echo "  5. 打开任一含地图仪表盘（足迹地图/驾驶记录追踪等），顶部「地图源」"
echo "     下拉框试试切换到「高德地图」/「谷歌卫星」"
echo ""
echo "📚 相关文档（在线）："
echo "  https://github.com/wjsall/teslamate-chinese-dashboards"
echo ""
echo "🆘 遇到问题？"
echo "  查看日志: $DC logs -f"
echo "  重启服务: $DC restart"
echo ""
echo "🍓 树莓派用户提示："
echo "  必须使用 64 位系统（64-bit Raspberry Pi OS），32 位系统不支持。"
echo "  树莓派 4 / 5 均可正常运行，树莓派 3 建议升级到 64 位系统后使用。"
echo ""
echo "⚠️  中国大陆用户提示："
echo "  1. 如果镜像拉取失败，在 /etc/docker/daemon.json 中添加镜像代理："
echo "     { \"registry-mirrors\": [\"https://dockerproxy.cn\"] }"
echo "     然后执行: sudo systemctl daemon-reload && sudo systemctl restart docker"
echo "  2. 如果车辆数据无法同步，需要取消 docker-compose.yml 中 TESLA_API_HOST"
echo "     和 TESLA_WSS_HOST 两行的注释（中国大陆专用 API 地址）"
echo "  3. 配置文件路径: $INSTALL_DIR/docker-compose.yml"
echo ""
