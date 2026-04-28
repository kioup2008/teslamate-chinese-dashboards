# 新手向导 — 从零开始使用 TeslaMate 中文 Dashboard

> 没用过 Docker？没关系。本文用最简单的方式带你完成安装。

---

## 第一步：搞清楚它是什么

### TeslaMate 是什么？
TeslaMate 是一个**开源**的特斯拉数据记录工具。它会自动收集你的车辆数据（每次行程、充电、电池状态等），保存在你自己的服务器上。数据完全属于你，不经过任何第三方。

### 本项目是什么？
TeslaMate 官方的 Grafana 图表是英文的。本项目提供了 **40 个简体中文汉化版图表**（含 9 个原创分析仪表盘），把所有界面翻译成中文，开箱即用。

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

> **🇨🇳 中国大陆用户注意：**
> 脚本默认使用 Docker Hub 镜像（`bswlhbhmt816/teslamate-chinese-dashboards`），相比 ghcr.io 在国内访问更稳定。
> 如果拉取镜像仍然很慢或失败，请先配置 Docker 镜像代理：
> ```bash
> # 编辑 Docker 配置（需要 root 权限）
> sudo tee /etc/docker/daemon.json <<EOF
> {"registry-mirrors": ["https://dockerproxy.cn"]}
> EOF
> sudo systemctl daemon-reload && sudo systemctl restart docker
> # 然后重新运行脚本
> ```

### 方法 B：手动 Docker Compose（推荐已熟悉 Docker 的用户）

**1. 创建工作目录**
```bash
mkdir ~/teslamate && cd ~/teslamate
```

**2. 创建 docker-compose.yml**

> 🔴 **重要：关于 ENCRYPTION_KEY**
>
> `ENCRYPTION_KEY` 是用来加密你的 Tesla 账号 Token 的**系统级密钥**。
> - **必须设置为一个随机字符串**（不能用默认值或简单的密码）
> - **设置后绝对不能修改**，否则 Tesla Token 将无法解密，TeslaMate 会崩溃且无法恢复
> - **请把它保存到安全的地方**（记事本、密码管理器均可）
>
> 生成随机密钥的命令：
> ```bash
> openssl rand -hex 32
> ```

> 🔴 **重要：关于数据库密码**
>
> `DATABASE_PASS`（teslamate 服务）和 `POSTGRES_PASSWORD`（database 服务）**必须填写完全相同的密码**，否则 TeslaMate 将无法连接数据库。

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
      - ENCRYPTION_KEY=用 openssl rand -hex 32 生成的随机字符串  # 🔴 必填，设置后不能修改！
      - DATABASE_USER=teslamate
      - DATABASE_PASS=你的数据库密码  # 🔴 替换为安全密码，与下方 POSTGRES_PASSWORD 必须相同
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
      - POSTGRES_PASSWORD=你的数据库密码  # 🔴 必须与上方 DATABASE_PASS 完全相同
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

TeslaMate 使用 **Tesla 官方 OAuth** 授权，**不需要把密码输入到 TeslaMate**，全程在特斯拉官网完成。

具体步骤：
1. 点击 TeslaMate 页面上的 **「Sign in with Tesla」** 按钮
2. 页面会跳转到 `auth.tesla.com`（特斯拉官方登录页）
3. 输入你的**特斯拉账号和密码**
4. 如果开启了两步验证，还需要输入验证码
5. 授权完成后，页面自动跳回 TeslaMate

> **🇨🇳 中国大陆用户注意：**
> 登录页面会跳转到 Tesla 国际区（`auth.tesla.com`），中国账号可能需要使用 `auth.tesla.cn`。
> 如果跳转后一直加载失败，请确认 `docker-compose.yml` 中已添加以下两行并重启：
> ```yaml
> - TESLA_API_HOST=https://owner-api.vn.cloud.tesla.cn
> - TESLA_WSS_HOST=wss://streaming.vn.cloud.tesla.cn
> ```

> **授权失败常见原因：**
> - 账号密码错误 → 确认在特斯拉 App 能正常登录
> - 两步验证超时 → 尽快输入验证码，不要等待太久
> - 网络不通 → 检查服务器能否访问 Tesla 服务器

### 3. 完成绑定
授权成功后，TeslaMate 会自动开始同步车辆数据。

> ⏱️ **首次同步预计 5-30 分钟**（取决于历史行程数量），之后每次行程结束自动更新。
>
> 同步进行中时，可以通过以下命令确认：
> ```bash
> docker compose logs -f teslamate
> # 看到 "Fetching vehicle data" 或 "Importing drive" 说明正在同步
> ```

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

登录后你会看到左侧导航栏，点击 **Dashboards** 查看所有 40 个中文图表。

**推荐第一次看这几个：**
1. **概览** — 车辆当前整体状态
2. **最近车辆状态** — 实时电量、续航、位置
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
A: 确认 Grafana 服务的环境变量中有 `GF_USERS_DEFAULT_LANGUAGE=zh-Hans`，然后重启 Grafana：
```bash
docker compose restart grafana
```

---

## 🌏 地图源切换 + 自动 GCJ-02 坐标纠偏（v1.4.2+ 中文版独有）

> **国内 TeslaMate 用户痛点 3 年终结。**
>
> 原版只支持 OpenStreetMap，国内加载慢得像挤牙膏；想换高德要手动改 9 个面板的 XYZ URL，git pull 又被覆盖；切完高德车辆轨迹还偏离道路 100~700 米，因为高德是 GCJ-02 坐标系而 TeslaMate 存 WGS-84 —— 想纠偏就得手写一坨复杂三角函数 SQL。
>
> 本项目 v1.4.2 把这一切变成两步操作。**海外用户也别走开 —— 谷歌中文路网在中国大陆区域同样是 GCJ-02，本方案一并自动处理。**

### 一步：装一次 PostgreSQL 坐标转换函数

```bash
docker exec -i teslamate-database-1 psql -U teslamate teslamate \
  < sql/install-coord-functions.sql
```

执行后会看到 `坐标转换函数安装成功 (天安门测试通过): (39.91522, 116.40407)` 自检通过提示。一次性安装，后续所有仪表盘自动生效。

> 卸载（如需）：函数文件顶部注释里有 DROP 语句。

### 二步：在仪表盘上切换地图源

含地图的 9 个仪表盘顶部都有「**地图源**」下拉框：

| 选项 | 推荐场景 | 坐标系 | 网络要求 |
|------|---------|--------|---------|
| **OpenStreetMap** | 默认/全球通用 | WGS-84 | 国内访问慢（无 CDN） |
| **高德地图** | 中国大陆首选 | GCJ-02（自动纠偏） | 国内直连 |
| **高德卫星** | 中国大陆卫星俯瞰 | GCJ-02（自动纠偏） | 国内直连 |
| **谷歌地图** | 海外华人首选（中文路网） | GCJ-02 中国区域（自动纠偏） | 海外直连/国内需翻墙 |
| **谷歌卫星** | 海外卫星视图（高清） | WGS-84 | 海外直连/国内需翻墙 |
| **Carto 浅色** | 极简风格、深色主题底图 | WGS-84 | 全球可达 |

切换地图源后，PostgreSQL 函数会根据新 URL 自动判断是否要做 GCJ-02 转换：选高德/谷歌路网 → 转；选 OSM/Carto/谷歌卫星 → 不转。**车辆轨迹永远贴合道路。**

### 9 个含地图的仪表盘

| 仪表盘 | 路径 |
|--------|------|
| 当前充电状态 | `/d/CurrentChargeView` |
| 当前驾驶状态 | `/d/CurrentDriveView` |
| 最近车辆状态 | `/d/CurrentState` |
| 驾驶记录追踪 | `/d/TrackingDrives` |
| 充电统计（汇总） | `/d/charging-stats` |
| 行程统计（时间段） | `/d/trip` |
| 访问过的地点 | `/d/visited` |
| 充电详情（内部跳转） | `/d/charge-details` |
| 行程详情（内部跳转） | `/d/drive-details` |

### 长期固化某个地图源（避免 git pull 重置）

默认值是 OpenStreetMap。每次 git pull 后下拉框会回到默认值。要长期用某个特定源，把 URL 参数加进浏览器书签：

```
http://你的Grafana/d/CurrentDriveView?var-map_url=https%3A%2F%2Fwprd01.is.autonavi.com%2Fappmaptile%3Flang%3Dzh_cn%26size%3D1%26scale%3D1%26style%3D7%26x%3D%7Bx%7D%26y%3D%7By%7D%26z%3D%7Bz%7D
```

`var-map_url=` 后面接 URL 编码后的瓦片地址。书签每次打开自动套用。

### 工作原理（给好奇的同学）

#### GCJ-02 是啥

中国出于地理信息安全考虑，规定境内地图厂商必须用 **GCJ-02（火星坐标系）**，相对国际标准 WGS-84 在中国境内非线性偏移 100~700 米。所以高德/百度/腾讯/谷歌（中国区域）瓦片都是 GCJ-02；OSM/Carto/谷歌卫星是 WGS-84。

#### 怎么自动判断

`sql/install-coord-functions.sql` 装了 4 个函数：

```sql
wgs84_to_gcj02_lat(lat, lng) -- 算法实现
wgs84_to_gcj02_lng(lat, lng)
lat_for_map(map_url, lat, lng)  -- 包装：URL 含 autonavi 或 google.com 路网 → 转，否则原样返回
lng_for_map(map_url, lat, lng)
```

9 个 geomap 面板 SQL 把原本的 `latitude, longitude` 替换成 `lat_for_map('${map_url}', latitude, longitude) AS latitude` 这种调用。Grafana 把当前选中的 URL 注入 SQL，函数按 URL 决定要不要转。

中国境外坐标自动短路（不转换），海外用户切回 OSM 等 WGS-84 源时无副作用。NULL 输入返回 NULL，数据完整性安全。

#### 算法精度

基于 [eviltransform](https://github.com/googollee/eviltransform) 标准实现，中国境内误差 < 0.5 米。北京天安门 WGS-84 (39.913818, 116.397828) → GCJ-02 (39.91522, 116.40407)，自检通过即可放心使用。

---

## 下一步

安装完成后，建议阅读：

| 文档 | 内容 |
|------|------|
| [SCENE_GUIDE.md](SCENE_GUIDE.md) | 什么场景看什么 Dashboard |
| [DASHBOARD_MAP.md](DASHBOARD_MAP.md) | 40 个 Dashboard 导航地图 |
| [METRICS_GUIDE.md](METRICS_GUIDE.md) | 各项数据指标解释 |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | 遇到问题怎么解决 |

---

**遇到问题？** 提交 [GitHub Issue](https://github.com/wjsall/teslamate-chinese-dashboards/issues)
