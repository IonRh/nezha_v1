## Nezha v1 面板（容器版）

V1 版哪吒面板容器，集成了以下能力：

- Cloudflare Tunnel（token 模式，可选）
- 自监控 agent（可选）
- 自定义用户主题（可选）
- TSDB 历史指标（可选）
- GitHub 自动备份 / 启动恢复（可选）
- 固定版本或自动更新

交流群：https://t.me/IonMagic

> 未使用 `OAuth 2.0` 登录（避免授权流程），因此首次部署后请务必进入面板修改默认密码。

## 镜像

`kwxos/newzhav1:latest`

## 快速开始

建议始终挂载 `/app/data` 做持久化。
开启TSDB时，可将`/app/tsdb`做持久化

### 最小可跑示例

下面这个示例只启动 dashboard，不启用 Tunnel、不启用 TSDB、不启用备份。

```bash
docker run -d \
  --name nezha-v1 \
  --restart unless-stopped \
  -p 8080:80 \
  -v $(pwd)/data:/app/data \
  -e NZ_agentsecretkey='YOUR_AGENT_SECRET_KEY' \
  -e Force_Auth='false' \
  kwxos/newzhav1:latest
```

启动后直接通过宿主机端口访问面板，例如 `http://你的IP:8080`。

### 常用完整示例

下面这个示例启用 Tunnel、自监控 agent 和 GitHub 备份：

```bash
docker run -d \
  --name nezha-v1 \
  --restart unless-stopped \
  -p 8080:80 \
  -v $(pwd)/data:/app/data \
  -e ARGO_AUTH='YOUR_CF_TUNNEL_TOKEN' \
  -e NZ_DOMAIN='nezha.example.com' \
  -e NZ_agentsecretkey='YOUR_AGENT_SECRET_KEY' \
  -e IDU='YOUR_AGENT_UUID' \
  -e GITHUB_USERNAME='YOUR_GH_USER' \
  -e REPO_NAME='YOUR_BACKUP_REPO' \
  -e GITHUB_TOKEN='YOUR_GH_TOKEN' \
  -e ZIP_PASSWORD='YOUR_ZIP_PASSWORD' \
  kwxos/newzhav1:latest
```

### docker-compose

```yaml
services:
  nezha-v1:
    image: kwxos/newzhav1:latest
    container_name: nezha-v1
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - ./data:/app/data
    environment:
      NZ_agentsecretkey: "YOUR_AGENT_SECRET_KEY"
      # 设为true后，访客不可见
      # Force_Auth: "false"

      # 可选：Cloudflare Tunnel + 自监控 agent
      # ARGO_AUTH: "YOUR_CF_TUNNEL_TOKEN"
      # NZ_DOMAIN: "nezha.example.com"
      # IDU: "YOUR_AGENT_UUID"

      # 可选：固定 dashboard 版本
      # DASHBOARD_VERSION: "v1.5.11"

      # 可选：自定义用户主题
      # NZ_EXTRA_USER_THEME: "https://github.com/fl0w1nd/Lotus/releases/latest/download/dist.zip"

      # 可选：启用 TSDB
      # NZ_ENABLE_TSDB: "true"
      # NZ_TSDB_DATA_PATH: "/app/data/tsdb"
      # NZ_TSDB_RETENTION_DAYS: "7"

      # 可选：GitHub 备份
      # GITHUB_USERNAME: "YOUR_GH_USER"
      # REPO_NAME: "YOUR_BACKUP_REPO"
      # GITHUB_TOKEN: "YOUR_GH_TOKEN"
      # ZIP_PASSWORD: "YOUR_ZIP_PASSWORD"
```

## 环境变量说明

环境变量名大小写敏感，请按原样填写。

### 核心变量

| 变量 | 是否必填 | 用途 | 备注 |
| --- | --- | --- | --- |
| `NZ_agentsecretkey` | 必填 | agent 密钥 | 需与 dashboard 配置中的 `agentsecretkey` 一致 |
| `Force_Auth` | 可选 | 是否允许访客可见 | `true`=访客可见；`false`=需要登录，默认 `false` |
| `DASHBOARD_VERSION` | 可选 | 固定面板版本 | 例如 `v1.5.11`；设置后仅固定 dashboard 版本，不影响已启用 agent 的自动更新 |

### 访问与自监控

| 变量 | 是否必填 | 用途 | 备注 |
| --- | --- | --- | --- |
| `ARGO_AUTH` | 可选 | Cloudflare Tunnel Token | 不填则不启动 cloudflared，面板仅通过容器端口访问 |
| `NZ_DOMAIN` | 可选 | 面板访问域名 / agent 上报域名 | 与 `IDU` 任一未填则不安装 agent |
| `IDU` | 可选 | 当前面板所在探针的 UUID | 写入 agent 配置中的 `uuid`；与 `NZ_DOMAIN` 任一未填则不安装 agent |

### 自定义主题

| 变量 | 是否必填 | 用途 | 备注 |
| --- | --- | --- | --- |
| `NZ_EXTRA_USER_THEME` | 可选 | 自定义用户主题 zip 链接 | 填写后覆盖 `/app/user-dist`；不填则保留现有 `user-dist` |

### TSDB

| 变量 | 是否必填 | 用途 | 备注 |
| --- | --- | --- | --- |
| `NZ_ENABLE_TSDB` | 可选 | 是否启用 TSDB 历史指标 | `true`=写入并启用；`false`=移除 TSDB 配置；不设置=保留原配置 |
| `NZ_TSDB_DATA_PATH` | 可选 | TSDB 数据目录 | 默认 `/app/tsdb` |
| `NZ_TSDB_RETENTION_DAYS` | 可选 | 历史数据保留天数 | 默认 `7` |
| `NZ_TSDB_MIN_FREE_DISK_SPACE_GB` | 可选 | 最小剩余磁盘空间 | 默认 `0.3` |
| `NZ_TSDB_MAX_MEMORY_MB` | 可选 | TSDB 最大内存使用量 | 默认 `64` |
| `NZ_TSDB_WRITE_BUFFER_SIZE` | 可选 | 写入缓冲区大小 | 默认 `128` |
| `NZ_TSDB_WRITE_BUFFER_FLUSH_INTERVAL` | 可选 | 写缓冲刷新间隔（秒） | 默认 `5` |

### GitHub 备份与恢复

| 变量 | 是否必填 | 用途 | 备注 |
| --- | --- | --- | --- |
| `GITHUB_USERNAME` | 备份必填 | 备份用 GitHub 用户名 | 四个备份变量全部填写才启用 |
| `REPO_NAME` | 备份必填 | 备份仓库名 | 仓库根目录保存 `data-*.zip` |
| `GITHUB_TOKEN` | 备份必填 | 备份用 GitHub Token | 建议最小权限 + 专用仓库 |
| `ZIP_PASSWORD` | 备份必填 | 备份 zip 密码 | 备份与恢复都需要该密码 |

## 可选功能

### 自定义主题

通过 `NZ_EXTRA_USER_THEME` 传入 zip 下载地址后，容器会在启动时自动：

1. 下载主题包
2. 解压到临时目录
3. 自动识别主题根目录
4. 覆盖 `/app/user-dist`

示例：

```bash
docker run -d \
  --name nezha-v1 \
  --restart unless-stopped \
  -p 8080:80 \
  -v $(pwd)/data:/app/data \
  -e NZ_agentsecretkey='YOUR_AGENT_SECRET_KEY' \
  -e NZ_EXTRA_USER_THEME='https://github.com/fl0w1nd/Lotus/releases/latest/download/dist.zip' \
  kwxos/newzhav1:latest
```

说明：

- 不需要手工执行 `unzip` 和 `cp`
- 支持 zip 根目录直接是前端文件，也支持多一层外层目录的发布结构
- 不设置 `NZ_EXTRA_USER_THEME` 时，如果容器内已经有 `/app/user-dist`，启动和自动更新都会尽量保留它
- 设置了 `NZ_EXTRA_USER_THEME` 时，会以下载到的主题覆盖现有 `/app/user-dist`

### TSDB

TSDB 现在按下面的规则工作：

- `NZ_ENABLE_TSDB=true`：按环境变量和默认值生成 TSDB 配置
- `NZ_ENABLE_TSDB=false`：移除配置文件中的 `tsdb:` 配置块
- 不设置 `NZ_ENABLE_TSDB` 且不设置任何 `NZ_TSDB_*`：保留 `config.yaml` 里原有的 TSDB 配置，不改动
- 设置了任意 `NZ_TSDB_*`：会按环境变量和默认值重写一份 TSDB 配置

当前默认值已经按低配机器做了下调：

- 保留 7 天
- 最大内存 64MB
- 最小剩余磁盘 0.3GB
- 写缓冲区 128

最小示例：

```bash
docker run -d \
  --name nezha-v1 \
  --restart unless-stopped \
  -p 8080:80 \
  -v $(pwd)/data:/app/data \
  -e NZ_agentsecretkey='YOUR_AGENT_SECRET_KEY' \
  -e NZ_ENABLE_TSDB='true' \
  kwxos/newzhav1:latest
```

自定义保留天数示例：

```bash
docker run -d \
  --name nezha-v1 \
  --restart unless-stopped \
  -p 8080:80 \
  -v $(pwd)/data:/app/data \
  -e NZ_agentsecretkey='YOUR_AGENT_SECRET_KEY' \
  -e NZ_ENABLE_TSDB='true' \
  -e NZ_TSDB_RETENTION_DAYS='90' \
  -e NZ_TSDB_MAX_MEMORY_MB='512' \
  kwxos/newzhav1:latest
```

说明：

- 默认 TSDB 目录为 `/app/tsdb`
- 如果希望 TSDB 数据进入现有 GitHub 备份，请显式设置为 `/app/data/tsdb`
- 如果你的备份恢复回来的 `config.yaml` 里已经有 `tsdb:` 配置，而你又不想覆盖它，请不要设置 `NZ_ENABLE_TSDB` 和 `NZ_TSDB_*`
- 启用后，哪吒会切换到 TSDB 保存历史指标；旧的服务监控历史不会自动迁移

### GitHub 备份 / 恢复

四个备份变量全部填写后，容器会启用自动备份和启动恢复。

备份行为：

- 每小时检查一次
- 上海时区凌晨 4 点且当天未备份过时执行自动备份
- 将备份仓库的 `README.md` 改成 `backup` 可触发手动备份
- 仅保留最新 5 个备份

备份内容：

- `/app/data`
- 容器内生成的 `config.yml`

注意：

- 备份仓库会被强制推送重写历史，请不要与其它重要内容混用
- 默认 `/app/tsdb` 不在备份范围内；如需备份 TSDB，请改到 `/app/data/tsdb`

### 固定版本与自动更新

- 不设置 `DASHBOARD_VERSION` 时，dashboard 会参与自动更新；如果已启用自监控，agent 也会参与自动更新
- 设置 `DASHBOARD_VERSION` 后，会固定 dashboard 版本；如果已启用自监控，agent 仍可继续自动更新

## 云平台部署示例（Docker 镜像）

适用于支持直接部署 Docker 镜像的平台。核心要点只有三个：

- 镜像：`kwxos/newzhav1:latest`
- 端口：容器内部监听 `80`
- 持久化：尽量挂载 `/app/data`
- 非持久化时，需要开启github备份才行

> 本项目通常通过 Cloudflare Tunnel 对外提供访问，但很多平台依然要求你声明一个内部监听端口，这里就是 `80`。

### Railway

1. 新建 Project → New Service → Deploy from Docker Image。
2. Image 填：`kwxos/newzhav1:latest`。
3. Variables 里按“环境变量说明”填写变量。
4. 如需持久化：添加 Volume，挂载到 `/app/data`。
5. 如果平台要求端口或健康检查：内部端口填 `80`，健康检查路径可用 `/`。

### Render

1. 新建 Web Service → 选择 “Deploy an existing image”。
2. Image 填：`kwxos/newzhav1:latest`。
3. Environment Variables 填好变量。
4. Disk 挂载到 `/app/data`（若套餐支持）。
5. Internal Port 设为 `80`。

## 常见问题

- Cloudflare Tunnel 要怎么指向容器？
  - 在 Zero Trust 后台的 Tunnel 配置里，将 Public Hostname / Ingress 的 Service 指向容器 HTTP 服务，通常是 `http://localhost:80`。
- 不填 `ARGO_AUTH` 会怎样？
  - 不会下载和启动 cloudflared，面板仅通过容器映射端口访问。
- 不填 `IDU` 或 `NZ_DOMAIN` 会怎样？
  - 不会下载和启动 nezha-agent，仅运行 dashboard；如需自监控请同时填写这两个变量。
- 我不想用备份，需要配置 GitHub 相关变量吗？
  - 不需要。四个备份变量不填则完全跳过备份和恢复流程。
- 探针不上报 / 连接失败？
  - 优先检查 `NZ_DOMAIN` 是否可从公网 443 访问，以及 `NZ_agentsecretkey` 是否与面板配置一致。

## 变量获取参考

Cloudflare Tunnel Token 的获取方式可参考 `F 大`的文档：

[Cloudflare Tunnel Token 的获取方式](https://github.com/fscarmen2/Argo-Nezha-Service-Container/blob/main/README.md#%E6%96%B9%E5%BC%8F-2---token-%E9%80%9A%E8%BF%87-cloudflare-%E5%AE%98%E7%BD%91%E6%89%8B%E5%8A%A8%E7%94%9F%E6%88%90-argo-%E9%9A%A7%E9%81%93-token-%E4%BF%A1%E6%81%AF)

按 token 模式在 Cloudflare Zero Trust 后台生成 `ARGO_AUTH` 的简要步骤：

1. 登录 Cloudflare → 进入 Zero Trust（one.dash.cloudflare.com）。
2. 打开 **Networks → Tunnels**，创建一个 tunnel（选择 **Cloudflared**）。
3. 创建完成后进入该 tunnel 的详情页，找到 **Token**（或类似“Run connector with a token”的区域）。
4. 复制 token 字符串（通常是很长的一段、看起来像 `eyJhIjoi...` 这种）。
5. 将 token 填到容器环境变量 `ARGO_AUTH`。

然后把域名 `NZ_DOMAIN` 接到 tunnel：

- 在 tunnel 的 **Public Hostname / Ingress** 里新增一条规则：
  - **Hostname**：填写面板域名，例如 `nezha.example.com`
  - **Service**：指向容器 HTTP 服务，通常是 `http://localhost:80`
- 确保该域名在 Cloudflare DNS 中可解析且已代理（橙云）

> 本容器内部会自签证书并监听 443 给 agent 使用（`server: $NZ_DOMAIN:443`），通常只需要让 tunnel 把外部访问转到容器的 80 端口即可。

## 安全提示

- 首次部署后立刻修改面板密码
- 建议 `Force_Auth=false`，避免面板对访客可见
- `GITHUB_TOKEN` 建议使用专用 token + 专用仓库，并尽量收敛权限
- TSDB 使用本地磁盘存储，建议为 `/app/data` 预留足够空间，并保持至少 20% 空闲空间

## 致谢

感谢 [fscarmen2](https://github.com/fscarmen2)（F 大）与相关 TG 大佬的思路与脚本参考。
