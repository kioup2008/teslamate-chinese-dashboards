# 新手向导 — 从零开始使用 TeslaMate 中文 Dashboard

> 没用过 Docker？没关系。本文用最简单的方式带你完成安装。

---

## 第一步：搞清楚它是什么

### TeslaMate 是什么？
TeslaMate 是一个**开源**的特斯拉数据记录工具。它会自动收集你的车辆数据（每次行程、充电、电池状态等），保存在你自己的服务器上。数据完全属于你，不经过任何第三方。

### 本项目是什么？
TeslaMate 官方的 Grafana 图表是英文的。本项目提供了 **37 个简体中文汉化版图表**（含 6 个原创分析仪表盘），把所有界面翻译成中文，开箱即用。

### 整体架构（你不需要完全理解，但有个概念更好）

```
你的特斯拉
    ↓（通过 Tesla 官方 API）
TeslaMate（数据采集）─→ PostgreSQL（数据库存储）
    ↓（MQTT消息）
Mosquitto（消息中间件）
    ↓（数据读取）
Grafana（图表展示）← 你用浏览器打开这个看数据
```

运行这些服务需要一台**常开的机器**（家用 NAS、云服务器、甚至树莓派都行）。

---

## 第二步：检查前置条件

在开始之前，确认以下几项：

### ✅ 必要条件

| 条件 | 如何确认 |
|------|---------|
| **一台常开的机器** | NAS / 云服务器 / 家用电脑 |
| **已安装 Docker** | 终端运行 `docker --version`，有输出即可 |
| **已安装 Docker Compose** | 终端运行 `docker compose version`，有输出即可 |
| **2GB 以上内存** | 服务器基本都满足 |
| **10GB 以上磁盘空间** | 用于数据库和镜像 |
| **网络能访问 Tesla 服务器** | 国内需确认（或配置代理） |

### 安装 Docker（如果还没安装）

**Ubuntu / Debian：**
```bash
curl -fsSL https://get.docker.com | bash
sudo usermod -aG docker $USER
# 重新登录后生效
```

**macOS：**
下载安装 [Docker Desktop](https://www.docker.com/products/docker-desktop/)

**Windows：**
通过 WSL2 安装 Docker Desktop（需要 Windows 10 版本 2004+）

---

## 第三步：一键安装（最简单的方式）

### 方法 A：一键脚本（强烈推荐新手）

在你的服务器上运行以下命令：

```bash
wget https://raw.githubusercontent.com/wjsall/teslamate-chinese-dashboards/main/simple-deploy.sh
bash simple-deploy.sh
```

脚本会自动：
- 创建 `~/teslamate-chinese/` 工作目录
- 生成 docker-compose.yml 配置文件
- 生成随机加密密钥
- 启动所有服务

> **国内服务器 wget 下载慢？** 可以直接把脚本内容复制到服务器上执行。

### 方法 B：手动 Docker Compose（推荐已熟悉 Docker 的用户）

**1. 创建工作目录**
```bash
mkdir ~/teslamate && cd ~/teslamate
```

**2. 创建 docker-compose.yml**
```yaml
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
      - ENCRYPTION_KEY=你的随机密钥  # 重要！替换为随机字符串
      - DATABASE_USER=teslamate
      - DATABASE_PASS=你的数据库密码  # 替换为安全密码
      - DATABASE_NAME=teslamate
      - DATABASE_HOST=database
      - MQTT_HOST=mosquitto

  database:
    image: postgres:18-trixie
    restart: always
    volumes:
      - teslamate-db:/var/lib/postgresql
    environment:
      - POSTGRES_USER=teslamate
      - POSTGRES_PASSWORD=你的数据库密码  # 与上面保持一致
      - POSTGRES_DB=teslamate

  grafana:
    image: ghcr.io/wjsall/teslamate-chinese-dashboards:latest
    restart: always
    ports:
      - 3000:3000
    volumes:
      - teslamate-grafana-data:/var/lib/grafana
    environment:
      - DATABASE_USER=teslamate
      - DATABASE_PASS=你的数据库密码
      - DATABASE_NAME=teslamate
      - DATABASE_HOST=database
      - GF_DEFAULT_LANGUAGE=zh-Hans

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
```

**3. 生成随机加密密钥**
```bash
openssl rand -hex 32
# 把输出的字符串替换到 ENCRYPTION_KEY=
```

**4. 启动**
```bash
docker compose up -d
```

---

## 第四步：首次登录 TeslaMate

安装完成后，按照以下步骤完成车辆绑定：

### 1. 打开 TeslaMate
在浏览器中访问：`http://服务器IP:4000`

> 本机安装用 `http://localhost:4000`

### 2. 授权 Tesla 账号
TeslaMate 使用 **Tesla 官方 OAuth** 授权（不需要输入密码到 TeslaMate），点击登录按钮后会跳转到特斯拉官方页面完成授权。

### 3. 完成绑定
授权成功后，TeslaMate 会自动开始同步车辆数据。

> ⏱️ **首次同步需要几分钟**，之后会持续自动更新。

---

## 第五步：登录 Grafana 查看图表

### 打开 Grafana
浏览器访问：`http://服务器IP:3000`

### 默认登录信息
- 用户名：`admin`
- 密码：`admin`

> ⚠️ **强烈建议**：首次登录后立即修改密码！
> 点击右上角头像 → Profile → Change Password

### 界面说明

登录后你会看到左侧导航栏，点击 **Dashboards** 查看所有 37 个中文图表。

**推荐第一次看这几个：**
1. **概览** — 车辆当前整体状态
2. **当前车辆状态** — 实时电量、续航、位置
3. **充电记录** — 历史充电记录

---

## 第六步：安装后必做的 5 件事

**1. 修改 Grafana 默认密码**
```
Grafana → 右上角头像 → Profile → Change Password
```

**2. 收藏常用 Dashboard**
打开 Dashboard → 点击右上角 ☆ → 下次直接在"收藏"中找到

**3. 设置时区**
如果时间显示不对：Grafana 右上角时钟图标 → 选择 `Asia/Shanghai`

**4. 确认数据同步正常**
```bash
# 查看 TeslaMate 日志
docker compose logs -f teslamate
# 看到 "Fetching vehicle data" 说明正在同步
```

**5. 设置自动重启（防止断电后不能自启）**
docker-compose.yml 中已配置 `restart: always`，Docker 重启后服务会自动恢复。确认 Docker 服务本身开机自启：
```bash
sudo systemctl enable docker
```

---

## 常见新手问题 (FAQ)

**Q: 数据会上传到哪里？会被特斯拉或其他人看到吗？**
A: 所有数据都保存在你自己的机器上，不会上传到任何第三方服务器（除了从 Tesla 官方 API 获取数据这一步）。

**Q: 需要一直开着电脑吗？**
A: 是的，需要一台常开的机器。推荐使用 NAS（如群晖/威联通）、云服务器，或者树莓派等低功耗设备。如果机器关机，TeslaMate 就停止收集数据了，但已有数据不会丢失。

**Q: 能用手机看吗？**
A: 可以。只要你的手机和服务器在同一局域网，或者服务器有公网 IP，手机浏览器访问 `http://IP:3000` 即可。Grafana 界面对手机做了适配。

**Q: 会影响车辆续航或让车睡不着觉吗？**
A: TeslaMate 的设计会尊重车辆休眠。当车辆处于休眠状态时，TeslaMate 不会主动唤醒它。有时会有少量唤醒（用于数据获取），但对续航影响极小。

**Q: 我的车辆 Token 安全吗？**
A: Token 使用你自己设置的 `ENCRYPTION_KEY` 加密后存储在本地数据库中，不会外泄。**请务必设置一个强随机密钥，并妥善保存。**

**Q: 图表里没有数据是正常的吗？**
A: 刚安装后数据需要几分钟到几小时才会出现，取决于 Tesla API 的响应速度。如果超过 1 小时还没有数据，查看 `docker compose logs teslamate` 排查问题。

**Q: 如果 TeslaMate 容器重启会丢数据吗？**
A: 不会。所有数据都存在 PostgreSQL 数据库中，容器重启不影响数据。

**Q: 安装在国内服务器上会有问题吗？**
A: **国内用户需要额外配置 Tesla 中国区 API 地址**，否则无法获取车辆数据。在 `docker-compose.yml` 的 `teslamate` 服务中添加：
```yaml
environment:
  - TZ=Asia/Shanghai
  - TESLA_API_HOST=https://owner-api.vn.cloud.tesla.cn
  - TESLA_WSS_HOST=wss://streaming.vn.cloud.tesla.cn
```
此外，ghcr.io 镜像拉取可能需要代理，详见 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)。

**Q: 怎么更新到新版本？**
A: 一条命令搞定：
```bash
cd ~/teslamate-chinese  # 或你的安装目录
docker compose pull grafana
docker compose up -d grafana
```

**Q: 如何备份数据？**
A: 备份 PostgreSQL 数据库：
```bash
docker compose exec database pg_dump -U teslamate teslamate > backup_$(date +%Y%m%d).sql
```

**Q: 能同时监控多辆车吗？**
A: 可以。用同一个特斯拉账号下的多辆车，TeslaMate 会自动识别并分别记录。图表顶部有车辆选择下拉框。

**Q: Grafana 界面怎么还是英文？**
A: 确认 Grafana 服务的环境变量中有 `GF_DEFAULT_LANGUAGE=zh-Hans`，然后重启 Grafana：
```bash
docker compose restart grafana
```

---

## 下一步

安装完成后，建议阅读：

| 文档 | 内容 |
|------|------|
| [SCENE_GUIDE.md](SCENE_GUIDE.md) | 什么场景看什么 Dashboard |
| [DASHBOARD_MAP.md](DASHBOARD_MAP.md) | 37 个 Dashboard 导航地图 |
| [METRICS_GUIDE.md](METRICS_GUIDE.md) | 各项数据指标解释 |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | 遇到问题怎么解决 |

---

**遇到问题？** 提交 [GitHub Issue](https://github.com/wjsall/teslamate-chinese-dashboards/issues)
