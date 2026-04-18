## Nezha v1 面板（容器版）

V1 版哪吒面板容器：集成 Cloudflare Tunnel（token 模式）、自动备份、可选固定版本/自动更新。

交流群：https://t.me/IonMagic

> 未使用 `OAuth 2.0` 登录（避免授权流程），因此首次部署后请务必进入面板修改默认密码。

## 镜像

`kwxos/newzhav1:latest`

## 快速开始

下面示例仅演示最小可跑配置；建议挂载 `/app/data` 做持久化。

### docker run

```bash
docker run -d \
  --name nezha-v1 \
  --restart unless-stopped \
  -p 8080:80 \
  -v $(pwd)/data:/app/data \
  -e ARGO_AUTH='YOUR_CF_TUNNEL_TOKEN' \
  -e NZ_DOMAIN='nezha.example.com' \
  -e NZ_agentsecretkey='YOUR_AGENT_SECRET_KEY' \
  -e Force_Auth='false' \
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
      ARGO_AUTH: "YOUR_CF_TUNNEL_TOKEN"
      NZ_DOMAIN: "nezha.example.com"
      NZ_agentsecretkey: "YOUR_AGENT_SECRET_KEY"
      Force_Auth: "false"
      IDU: "YOUR_AGENT_UUID"
      GITHUB_USERNAME: "YOUR_GH_USER"
      REPO_NAME: "YOUR_BACKUP_REPO"
      GITHUB_TOKEN: "YOUR_GH_TOKEN"
      ZIP_PASSWORD: "YOUR_ZIP_PASSWORD"
      # DASHBOARD_VERSION: "v1.5.11"  # 可选：固定版本，见下文
```

## 云平台部署示例（Docker 镜像）

下面示例适用于“支持直接部署 Docker 镜像”的平台。核心要点只有三个：

- 镜像：`kwxos/newzhav1:latest`
- 端口：容器内部监听 `80`（大多数平台会要求你填写/识别一个内部端口）
- 持久化：尽量挂载 `/app/data`；如果平台不支持持久化卷，建议务必配置 GitHub 备份（否则重启/迁移可能丢数据）

> 说明：本项目通过 Cloudflare Tunnel 对外提供访问，通常不需要你在云平台额外购买公网端口；但云平台依然可能要求容器“有一个对内监听端口”，这里就是 `80`。

### Railway

1. 新建 Project → New Service → Deploy from Docker Image。
2. Image 填：`kwxos/newzhav1:latest`。
3. Variables 里按“环境变量说明”设置必填项（至少：`ARGO_AUTH`、`NZ_DOMAIN`、`NZ_agentsecretkey`）。
4. 如需持久化：添加 Volume，挂载点填 `/app/data`。
5. 如平台需要填写监听端口/Health Check：内部端口填 `80`，健康检查路径可用 `/`。

### Render

1. 新建 Web Service → 选择 “Deploy an existing image”。
2. Image 填：`kwxos/newzhav1:latest`。
3. Environment Variables 填好必填变量。
4. Disk（持久化盘）挂载到 `/app/data`（如果你的套餐/服务类型支持）。
5. Internal Port 设为 `80`（或让 Render 自动检测到 80）。


## 环境变量说明

环境变量名大小写敏感，请按表格原样填写。

### 变量汇总

| 变量 | 是否必填 | 用途 | 备注 |
| --- | --- | --- | --- |
| `ARGO_AUTH` | 必填 | Cloudflare Tunnel Token | 在 Zero Trust 的 Tunnels 里获取；通常为一长串 token |
| `NZ_DOMAIN` | 必填 | 面板访问域名 / agent 上报域名 | agent 连接使用 `$NZ_DOMAIN:443` |
| `NZ_agentsecretkey` | 必填 | agent 密钥 | 需与 dashboard 配置中的 `agentsecretkey` 一致 |
| `Force_Auth` | 建议 | 是否允许访客可见 | `true`=访客可见；`false`=需要登录（建议 `false`） |
| `DASHBOARD_VERSION` | 可选 | 固定面板版本 | 例如 `v1.5.11`；设置后不自动更新 |
| `IDU` | 可选 | agent 的 UUID | 写入 agent 配置 `uuid` 字段，用于识别该容器对应的 agent |
| `GITHUB_USERNAME` | 备份必填 | 备份用 GitHub 用户名 | 仅在启用自动备份时需要 |
| `REPO_NAME` | 备份必填 | 备份仓库名 | 仓库根目录保存 `data-*.zip` |
| `GITHUB_TOKEN` | 备份必填 | 备份用 GitHub Token | 建议最小权限 + 专用仓库 |
| `ZIP_PASSWORD` | 备份必填 | 备份 zip 密码 | 备份与恢复都需要该密码 |


### 运行状态（可选）

| 变量 | 说明 | 备注 |
| --- | --- | --- |
| `IDU` | 当前面板所在探针的 UUID | 写入 agent 配置中的 `uuid` 字段；用于识别/监测该容器对应的 agent |

## 备份 / 恢复机制

- 自动备份：容器启动后会每小时检查一次；在上海时区凌晨 4 点且“当天还没备份过”时执行备份。
- 手动触发备份：将备份仓库的 `README.md` 内容改成 `backup`，下一次检查时会执行备份。
- 备份内容：`/app/data` 目录 + 容器内生成的 `config.yml`。
- 备份格式：生成 `data-YYYY-MM-DD-HH-MM-SS.zip`（使用 `ZIP_PASSWORD` 加密）。
- 保留策略：仅保留最新 5 个备份文件。
- 推送方式：使用强制推送重写 `main` 分支历史（备份仓库不要存放其它重要内容）。
- 恢复：容器启动时会尝试从备份仓库拉取最近一次备份并解压覆盖本地数据（同样需要 `ZIP_PASSWORD`）。

## 安全提示

- 首次部署后立刻修改面板密码。
- 建议 `Force_Auth=false`，避免面板对访客可见。
- `GITHUB_TOKEN` 建议使用专用 token + 专用仓库，并尽量收敛权限。

## 常见问题

- Cloudflare Tunnel 要怎么指向容器？
  - 在 Zero Trust 后台的 Tunnel 配置里，将 Public Hostname/Ingress 的 Service 指向容器实际提供的 HTTP 服务（通常是 `http://localhost:80`）。
- 我不想用备份，需要配置 GitHub 相关变量吗？
  - 不配置也能运行面板，但到凌晨 4 点会尝试触发备份流程并在日志里提示缺少变量；如果你也不希望自动更新，建议设置 `DASHBOARD_VERSION` 固定版本。
- 探针不上报/连接失败？
  - 优先检查 `NZ_DOMAIN` 是否可从公网 443 访问、以及 `NZ_agentsecretkey` 是否与面板配置一致。

## 变量获取参考

Cloudflare Tunnel Token 的获取方式可参考 `F 大`的文档：
[Cloudflare Tunnel Token 的获取方式](https://github.com/fscarmen2/Argo-Nezha-Service-Container/blob/main/README.md#%E6%96%B9%E5%BC%8F-2---token-%E9%80%9A%E8%BF%87-cloudflare-%E5%AE%98%E7%BD%91%E6%89%8B%E5%8A%A8%E7%94%9F%E6%88%90-argo-%E9%9A%A7%E9%81%93-token-%E4%BF%A1%E6%81%AF)

下面是按 token 模式在 Cloudflare Zero Trust 后台生成 `ARGO_AUTH` 的简要步骤（摘要版，便于快速对照操作）：

1. 登录 Cloudflare → 进入 Zero Trust（one.dash.cloudflare.com）。
2. 打开 **Networks → Tunnels**，创建一个 tunnel（选择 **Cloudflared**）。
3. 创建完成后进入该 tunnel 的详情页，找到 **Token**（或类似“Run connector with a token”的区域）。
4. 复制 token 字符串（通常是很长的一段、看起来像 `eyJhIjoi...` 这种）。
5. 将 token 填到容器环境变量 `ARGO_AUTH`。

然后把域名（`NZ_DOMAIN`）接到 tunnel：

- 在 tunnel 的 **Public Hostname / Ingress** 里新增一条规则：
  - **Hostname**：填写你的面板域名（与 `NZ_DOMAIN` 一致，例如 `nezha.example.com`）
  - **Service**：指向容器的 HTTP 服务（常见是 `http://localhost:80`）
- 确保该域名在 Cloudflare DNS 中可解析且已代理（橙云）。

> 提示：本容器内部会自签证书并监听 443 给 agent 使用（`server: $NZ_DOMAIN:443`），你通常只需要让 tunnel 把外部访问转到容器的 80 端口即可。

## 致谢

感谢 [fscarmen2](https://github.com/fscarmen2)（F 大）与相关 TG 大佬的思路与脚本参考。
