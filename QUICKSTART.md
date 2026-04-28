# 新手向导 — 从零开始使用 TeslaMate 中文 Dashboard

> 没用过 Docker？没关系。本文用最简单的方式带你完成安装。

---

## 第一步：搞清楚它是什么

### TeslaMate 是什么？
TeslaMate 是一个**开源**的特斯拉数据记录工具。它会自动收集你的车辆数据（每次行程、充电、电池状态等），保存在你自己的服务器上。数据完全属于你，不经过任何第三方。

### 本项目是什么？
TeslaMate 官方的 Grafana 图表是英文的。本项目提供了 **40 个简体中文汉化版图表**（含 9 个原创分析仪表盘），把所有界面翻译成中文，开箱即用。

### 🌟 中文版独有亮点

- 🌏 **地图源一键切换 + 自动 GCJ-02 坐标纠偏（v1.4.2+ 独家）** —— 仪表盘顶部下拉框秒切 OSM / 高德 / 高德卫星 / 谷歌 / 谷歌卫星 / Carto，国内用户车辆轨迹精准贴合道路（不再偏移 100~700m）。**这是 TeslaMate 原版没有的，全中文社区独有。**
- 🆕 **9 个原创分析仪表盘** —— 年度驾驶报告、省钱分析、充电健康管理、停车掉电分析、出行规律、动能回收、驾驶评分、续航退化、多车对比
- 🇨🇳 **国内网络优化** —— 默认使用 Docker Hub 镜像（国内加载更稳），可一键切换高德地图（直连国内 CDN），可配置 Tesla 中国区 API 地址

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

## 第二步：准备机器和工具

### 你需要怎样一台机器？

TeslaMate 需要 **一台一直开机的机器**（关机就停止记录数据，但已存的数据不会丢）。三种常见选择，挑一个适合你的：

| 场景 | 适合谁 | 上手难度 |
|------|--------|----------|
| **A. 家里的 NAS**（群晖/威联通等） | 已有 NAS 的家庭用户 | ⭐⭐⭐ |
| **B. 云服务器**（阿里云/腾讯云/AWS Lightsail 等，2GB 起） | 想用公网 IP 远程访问的用户 | ⭐⭐ |
| **C. 你自己的电脑**（Mac / Windows / Linux） | 只想试试看，**电脑要一直开着** | ⭐ |

> 📌 **拿不准？直接选 C** —— 在自己电脑上跑个把月再决定要不要换 NAS / 云服务器。本文剩下的步骤都通用。

### ✅ 配置最低要求

| 条件 | 说明 |
|------|------|
| **2GB 以上内存** | 大多数机器都满足 |
| **10GB 以上磁盘空间** | 用于数据库和镜像 |
| **网络能访问 Tesla 服务器** | 国内需配置中国区 API（第四步会讲） |

### 第一关：打开「终端」/ 命令行

后面的所有命令都要在「终端」里运行。不同系统打开方式不一样：

**macOS：**
- 按 <kbd>⌘</kbd> + <kbd>空格</kbd> 打开聚焦搜索 → 输入 `终端` → 回车
- 或在「应用程序 → 实用工具」里找「终端」

**Windows：**
- 按 <kbd>Win</kbd> 键 → 输入 `PowerShell` → 回车
- 或安装 [Git for Windows](https://git-scm.com/download/win)，用里面的「Git Bash」（更接近 Linux 体验，推荐）

**Linux：**
- 按 <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>T</kbd>，或菜单里找「Terminal」

> 终端打开后，是个黑色或白色窗口，光标在闪。后面的命令都是**复制粘贴 → 回车** 就行。

### 第二关：连到你的「服务器」（如果是 NAS / 云服务器）

如果你选了 **场景 A（NAS）** 或 **场景 B（云服务器）**，需要 SSH 远程连进去再操作。**场景 C（自己电脑）跳过这一步。**

```bash
# 在你的本机终端里跑（替换成你的服务器 IP 和用户名）
ssh 用户名@服务器IP

# 例：阿里云 Ubuntu 服务器
ssh root@1.2.3.4

# 例：群晖 NAS
ssh admin@192.168.1.100
```

第一次 SSH 会问 `Are you sure you want to continue connecting?` 输入 `yes` 回车；然后输入服务器密码（输入时不会显示，正常）。

> 🆘 不知道服务器 IP？阿里云/腾讯云在控制台「实例详情」找；群晖在「控制面板 → 网络」看 LAN IP。

### 第三关：装 Docker（如果还没装）

在终端（本机或 SSH 连接里）跑：

**Ubuntu / Debian / 大部分云服务器：**
```bash
curl -fsSL https://get.docker.com | bash
sudo usermod -aG docker $USER
# 退出重新 SSH 登录后生效（场景 A/B），或重启电脑（场景 C）
```

**macOS（场景 C）：**
下载安装 [Docker Desktop](https://www.docker.com/products/docker-desktop/)，装完打开应用，等顶部菜单栏 Docker 图标变绿。

**Windows（场景 C）：**
通过 WSL2 安装 [Docker Desktop](https://www.docker.com/products/docker-desktop/)（需要 Windows 10 版本 2004+）。装完启动 WSL2 + Docker Desktop。

**群晖 NAS（场景 A）：**
在套件中心搜索「Container Manager」（DSM 7.2+）或「Docker」（旧版），安装即可。

### 第四关：验证 Docker 装好了

终端里跑：
```bash
docker --version
docker compose version
```

两条都有输出（例如 `Docker version 28.5.1` / `Docker Compose version v2.40.1`）就表示装好了。

> ❌ 报 `command not found`？
> - 装完没重新登录终端 → 关掉终端窗口，再开一个
> - 装完没启动 Docker Desktop（macOS/Windows）→ 启动它
> - Linux 上 `docker compose version` 报错而 `docker --version` OK → 你装的是老版 docker-compose-plugin，跑 `docker-compose version`（中间有横线）也行

---

## 第三步：一键安装

> 🎯 **小白直接看「方法 A」就行，方法 B 看不懂跳过没事**。
> 方法 A 是脚本帮你做完所有配置；方法 B 给已经熟 Docker、想改 ports/volumes/路径的人用。

### ⭐ 方法 A：一键脚本（强烈推荐）

在终端里运行以下两条命令（复制粘贴 → 回车 → 等 5 分钟）：

```bash
wget https://raw.githubusercontent.com/wjsall/teslamate-chinese-dashboards/main/simple-deploy.sh
bash simple-deploy.sh
```

脚本会自动：
- 创建 `~/teslamate-chinese/` 工作目录
- 生成 `docker-compose.yml` 配置文件
- **生成随机的 ENCRYPTION_KEY**（用来加密 Tesla Token 的密钥）
- 启动所有服务（TeslaMate / PostgreSQL / Grafana / MQTT，共 4 个容器）
- **自动安装地图坐标转换函数**（v1.4.2 新功能，不再需要手动操作）

### ⚠️ 装完立即做：备份你的 ENCRYPTION_KEY

脚本自动生成的密钥写在 `~/teslamate-chinese/docker-compose.yml` 里。**这个密钥用来加密你的特斯拉 Token，一旦丢了或被改，TeslaMate 就解不开 Token 永远卡死，必须重新授权。**

立刻执行（找出来 → 备份）：

```bash
grep ENCRYPTION_KEY ~/teslamate-chinese/docker-compose.yml
```

输出大概长这样：
```
- ENCRYPTION_KEY=a3f5b8c9d2e1f4...（一串 64 位十六进制字符）
```

**把这一整串复制到密码管理器或安全的笔记里。** 万一以后哪天 docker-compose.yml 被不小心动了，还能照着原样恢复。

> **🇨🇳 中国大陆用户镜像加速（如果脚本卡在 "Pulling image..."）：**
> 脚本默认用 Docker Hub 镜像（`bswlhbhmt816/teslamate-chinese-dashboards`），国内多数能直连。如果还是慢/失败：
> ```bash
> # 配置 Docker 镜像代理（需要 root 权限）
> sudo tee /etc/docker/daemon.json <<EOF
> {"registry-mirrors": ["https://dockerproxy.cn"]}
> EOF
> sudo systemctl daemon-reload && sudo systemctl restart docker
> # 然后回到 ~/teslamate-chinese/，重新跑：docker compose pull && docker compose up -d
> ```

---

### 方法 B：手动 Docker Compose（已熟 Docker 的可以来看）

> ⚠️ 不建议小白用此方法 —— 方法 A 已经完整够用，方法 B 是给想改 ports / volumes / 自定义路径的人。

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

#### 「服务器 IP」是什么？怎么查？

| 你装在哪里 | 浏览器输入 | 怎么查 IP |
|-----------|-----------|-----------|
| **本机**（场景 C：自己电脑） | `http://localhost:4000` | 不用查，写 `localhost` 就行 |
| **同一局域网的 NAS / 树莓派**（场景 A） | `http://192.168.x.x:4000` | NAS 控制面板「网络」看 LAN IP；或在 NAS 终端跑 `hostname -I` |
| **云服务器**（场景 B） | `http://公网IP:4000` | 阿里云/腾讯云控制台「实例详情」找「公网 IP」；或在服务器上跑 `curl ifconfig.me` |

> ⚠️ **云服务器还得在控制台开放 4000 和 3000 端口安全组**，否则浏览器连不上。阿里云：实例 → 安全组 → 配置规则 → 入方向 → 添加 4000 和 3000。

### 2. 授权 Tesla 账号

TeslaMate 使用 **Tesla 官方 OAuth** 授权，**不需要把密码输入到 TeslaMate**，全程在特斯拉官网完成。

具体步骤：
1. 点击 TeslaMate 页面上的 **「Sign in with Tesla」** 按钮
2. 页面会跳转到 `auth.tesla.com`（特斯拉官方登录页）
3. 输入你的**特斯拉账号和密码**
4. 如果开启了两步验证，还需要输入验证码
5. 授权完成后，页面自动跳回 TeslaMate

> **🇨🇳 中国大陆用户必看：**
> 登录页面默认跳转到 Tesla 国际区（`auth.tesla.com`），中国账号必须切到 `auth.tesla.cn` 才能登入。
>
> **具体操作（方法 A 一键脚本用户）：**
>
> ```bash
> cd ~/teslamate-chinese
> nano docker-compose.yml          # 没装 nano 用 vim 也行
> ```
>
> 找到 `teslamate:` 服务下面这两行（已被注释掉）：
> ```yaml
>       # - TESLA_API_HOST=https://owner-api.vn.cloud.tesla.cn
>       # - TESLA_WSS_HOST=wss://streaming.vn.cloud.tesla.cn
> ```
>
> **去掉每行前面的 `#` 和一个空格**，变成：
> ```yaml
>       - TESLA_API_HOST=https://owner-api.vn.cloud.tesla.cn
>       - TESLA_WSS_HOST=wss://streaming.vn.cloud.tesla.cn
> ```
>
> 保存退出（nano: <kbd>Ctrl</kbd>+<kbd>O</kbd> 回车 → <kbd>Ctrl</kbd>+<kbd>X</kbd>），然后重启：
>
> ```bash
> docker compose up -d
> ```
>
> 重新打开 TeslaMate 页面，登录会跳转到 `auth.tesla.cn`，中国账号就能正常登录了。

> **授权失败常见原因：**
> - 账号密码错误 → 确认在特斯拉 App 能正常登录
> - 两步验证超时 → 尽快输入验证码，不要等待太久
> - 网络不通 → 检查服务器能否访问 Tesla 服务器

### 🆘 备用方案：用「Auth for Tesla」第三方 App 拿 Token

如果上面的 `Sign in with Tesla` 按钮**反复登不上**（页面跳转后空白、报 `unauthorized_client`、中国账号怎么试都进不去、两步验证一直超时等），可以用第三方工具 **Auth for Tesla** 在手机上拿到 Token 后再灌进 TeslaMate。这是国内 Tesla 圈的常用救场方法。

**工作原理：** Auth for Tesla 在你手机上完成 OAuth 登录（成功率比 TeslaMate 服务器代登高，因为手机已经是登录状态），把生成的 access / refresh token 给你 → 你把这两段字符串塞进 TeslaMate 即可绕过登录页。

#### 步骤

**1. 下载 Auth for Tesla**

- iOS：[App Store 搜「Auth for Tesla」](https://apps.apple.com/us/app/auth-for-tesla/id1552058613)
- Android：Google Play / 国内 Tesla 论坛搜安装包

**2. 在 App 里登录你的 Tesla 账号**

输入账号密码，完成两步验证。App 会显示 `access_token` 和 `refresh_token` 两段字符串（很长）。**把这两段都复制保存到密码管理器**。

**3. 在 TeslaMate 登录页选「使用 Token」**

打开 `http://服务器IP:4000`，登录页除了 `Sign in with Tesla` 按钮，还会有一个 `使用现有 Token 登录` / `Use existing tokens` 折叠选项（不同版本位置略有差异，仔细看页面）。展开后两个输入框：
- `Access Token` ← 粘贴 App 给你的 access_token
- `Refresh Token` ← 粘贴 App 给你的 refresh_token

点提交，完成绑定。

#### 注意事项

- Auth for Tesla 是开源/经审计的成熟工具，国内 Tesla 群、TeslaFi 用户群都在用，但仍**只在你信任的设备上用**
- 用 Token 绑定的账号，TeslaMate 会**自动续期**（用 refresh_token 拿新的 access_token），你不用每天手动换
- 如果 Token 过期或失效（极少发生），重复一遍上述流程即可
- 详细参考：[TeslaMate 官方文档 - Tokens](https://docs.teslamate.org/docs/configuration/tokens)

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

## 第六步：✅ 装完了？跑这个清单确认

如果以下 6 项都打勾，说明装得没问题：

```bash
cd ~/teslamate-chinese     # 方法 A 用户；方法 B 改成你的目录
docker compose ps
```

- [ ] **4 个容器都在跑** —— 输出里能看到 `teslamate`、`database`、`grafana`、`mosquitto`，状态都是 `Up` 或 `running (healthy)`
- [ ] **TeslaMate 网页能开** —— 浏览器打开 `http://服务器IP:4000`，看到登录页
- [ ] **Grafana 网页能开** —— 浏览器打开 `http://服务器IP:3000`，看到登录页
- [ ] **TeslaMate 已绑定车辆** —— 登录 TeslaMate 后能看到你的车，状态是 `online` / `asleep` / `driving` 等（不是 `unauthenticated`）
- [ ] **Grafana 有 40 个仪表盘** —— 登录 Grafana 后左侧 `Dashboards` 菜单，能看到「TeslaMate」文件夹下 40 个图
- [ ] **数据开始同步** —— 跑 `docker compose logs -f teslamate` 能看到类似 `Fetching vehicle data` 的日志（按 <kbd>Ctrl</kbd>+<kbd>C</kbd> 退出查看）

> 任何一项不通过 → 看 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)，或直接到本节末尾的「卸载/重置」部分清空重装。

---

## 第七步：安装后必做的 5 件事

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

#### 🆕 v1.4.2+ 新装用户 —— 跳过本节

如果你刚才用「一键脚本」装的（v1.4.2+ 的脚本），**坐标转换函数已经自动装好了**。直接跳到「二步：在仪表盘上切换地图源」即可。

#### ⬆️ 老版本升级 / 手动验证安装

按你之前的安装方式选一条：

##### A. 一键脚本用户（之前用 simple-deploy.sh 装的）

直接重跑一键脚本，**它会自动检测你的现有安装并转升级模式**（不会改 ENCRYPTION_KEY 也不会丢数据）：

```bash
wget -qO- https://raw.githubusercontent.com/wjsall/teslamate-chinese-dashboards/main/simple-deploy.sh | bash
```

##### B. git clone 用户（之前 `git clone` 仓库装的）

```bash
cd ~/teslamate-chinese-dashboards     # 你的克隆目录
bash scripts/upgrade.sh
```

脚本会做：① git pull 拉新代码 → ② 检测 PG 容器 → ③ 装函数 → ④ 重启 Grafana。

##### C. 手动派（不想用脚本）

```bash
# 1. 拉最新镜像 / 仓库代码
docker compose pull && docker compose up -d     # 一键脚本用户
# 或
git pull                                         # git clone 用户

# 2. 装坐标转换函数
# git clone 用户（仓库本地有 sql/ 目录）：
docker exec -i teslamate-database-1 psql -U teslamate teslamate < sql/install-coord-functions.sql

# 一键脚本用户（没有本地 sql/，用 curl 拉远程）：
curl -fsSL https://raw.githubusercontent.com/wjsall/teslamate-chinese-dashboards/main/sql/install-coord-functions.sql | \
  docker exec -i teslamate-database-1 psql -U teslamate -d teslamate

# 3. 重启 Grafana
docker compose restart grafana
```

#### 容器名不一定叫 `teslamate-database-1`

⚠️ 上面命令里的 `teslamate-database-1` 是默认容器名（v1.4.2+ 一键脚本和目录叫 `teslamate-chinese-dashboards` 的 docker-compose.yml 都会生成这个名字）。如果你改过项目目录名或在更早版本装的，先确认：

```bash
docker ps --format '{{.Names}}' | grep -i database
```

把输出的真实容器名替换到命令里。

#### 装成功的标志

执行成功会看到 `坐标转换函数安装成功 (天安门测试通过): (39.91522, 116.40407)` 自检通过提示。这是一次性安装，后续所有仪表盘自动生效。

> 卸载（如需）：函数文件顶部注释里有 DROP 语句。
> 装失败排查：见 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 「装 PostgreSQL 坐标转换函数报错」章节。

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

## 想推倒重来？卸载 / 重置

### 仅停止服务（保留数据）

```bash
cd ~/teslamate-chinese
docker compose down
```

下次想再开：`docker compose up -d`，数据完整保留。

### 完全卸载（删除所有数据，无法恢复！⚠️）

> **🔴 警告：这会删掉所有行程历史、充电记录、电池数据，且不可逆。先想清楚要不要备份再做。**

**第 1 步：备份（可选但强烈推荐）**

```bash
cd ~/teslamate-chinese
docker compose exec database pg_dump -U teslamate teslamate > backup_$(date +%Y%m%d).sql
# 备份文件保存在当前目录，万一以后想还原就有
```

**第 2 步：停服务并删容器+数据卷**

```bash
cd ~/teslamate-chinese
docker compose down -v        # -v 表示一并删除数据卷（最关键的一步）
```

**第 3 步：删工作目录**

```bash
rm -rf ~/teslamate-chinese
```

**第 4 步：可选 —— 删镜像（释放磁盘）**

```bash
docker rmi bswlhbhmt816/teslamate-chinese-dashboards
docker rmi teslamate/teslamate
docker rmi postgres:18-trixie
docker rmi eclipse-mosquitto:2
```

**清空之后，可以从「第三步：一键安装」重头来过。** 你的 `ENCRYPTION_KEY` 可以重新生成（不影响新装），但如果有备份的 `backup_xxx.sql` 想还原就需要用同一个旧 KEY。

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
