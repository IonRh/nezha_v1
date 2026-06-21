## Nezha v1 Dashboard (Container Edition)

[中文](README.md) | English

A containerized Nezha v1 dashboard with the following capabilities built in:

- Cloudflare Tunnel (token mode, optional)
- Self-monitoring agent (optional)
- Custom user theme (optional)
- TSDB historical metrics (optional)
- GitHub automatic backup / startup restore (optional)
- Fixed version or automatic updates

Community: https://t.me/IonMagic

> This image does not use `OAuth 2.0` login in order to avoid the authorization flow, so please change the default dashboard password immediately after the first deployment.

## Image

`kwxos/newzhav1:latest`

## Quick Start

It is strongly recommended to always persist `/app/data`.
If TSDB is enabled, you can also persist `/app/tsdb`.

### Minimal Example

This example starts only the dashboard, without Tunnel, TSDB, or backup.

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

After startup, access the dashboard through the mapped host port, for example: `http://YOUR_IP:8080`.

### Common Full Example

This example enables Tunnel, the self-monitoring agent, and GitHub backup.

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
      # Set to true to require login for visitors
      # Force_Auth: "false"

      # Optional: Cloudflare Tunnel + self-monitoring agent
      # ARGO_AUTH: "YOUR_CF_TUNNEL_TOKEN"
      # NZ_DOMAIN: "nezha.example.com"
      # IDU: "YOUR_AGENT_UUID"

      # Optional: pin dashboard version
      # DASHBOARD_VERSION: "v1.5.11"

      # Optional: custom user theme
      # NZ_EXTRA_USER_THEME: "https://github.com/fl0w1nd/Lotus/releases/latest/download/dist.zip"

      # Optional: enable TSDB
      # NZ_ENABLE_TSDB: "true"
      # NZ_TSDB_DATA_PATH: "/app/data/tsdb"
      # NZ_TSDB_RETENTION_DAYS: "7"

      # Optional: GitHub backup
      # GITHUB_USERNAME: "YOUR_GH_USER"
      # REPO_NAME: "YOUR_BACKUP_REPO"
      # GITHUB_TOKEN: "YOUR_GH_TOKEN"
      # ZIP_PASSWORD: "YOUR_ZIP_PASSWORD"
```

## Environment Variables

Environment variable names are case-sensitive. Use them exactly as shown.

### Core Variables

| Variable | Required | Purpose | Notes |
| --- | --- | --- | --- |
| `NZ_agentsecretkey` | Required | Agent secret key | Must match `agentsecretkey` in the dashboard config |
| `Force_Auth` | Optional | Whether visitors can view the dashboard | `true` = visitors can view it; `false` = login required; default is `false` |
| `DASHBOARD_VERSION` | Optional | Pin the dashboard version | Example: `v1.5.11`; when set, automatic updates are skipped |

### Access and Self-Monitoring

| Variable | Required | Purpose | Notes |
| --- | --- | --- | --- |
| `ARGO_AUTH` | Optional | Cloudflare Tunnel token | If omitted, `cloudflared` is not started and the dashboard is only accessible through the container port |
| `NZ_DOMAIN` | Optional | Dashboard domain / agent reporting domain | If either this or `IDU` is missing, the agent will not be installed |
| `IDU` | Optional | UUID of this dashboard node | Written into the agent config as `uuid`; if either this or `NZ_DOMAIN` is missing, the agent will not be installed |

### Custom Theme

| Variable | Required | Purpose | Notes |
| --- | --- | --- | --- |
| `NZ_EXTRA_USER_THEME` | Optional | Download URL of a custom user theme zip | When set, it overwrites `/app/user-dist`; when omitted, the existing `user-dist` is preserved |

### TSDB

| Variable | Required | Purpose | Notes |
| --- | --- | --- | --- |
| `NZ_ENABLE_TSDB` | Optional | Whether to enable TSDB historical metrics | `true` = write and enable; `false` = remove TSDB config; unset = keep the existing config |
| `NZ_TSDB_DATA_PATH` | Optional | TSDB data directory | Default: `/app/tsdb` |
| `NZ_TSDB_RETENTION_DAYS` | Optional | Historical retention in days | Default: `7` |
| `NZ_TSDB_MIN_FREE_DISK_SPACE_GB` | Optional | Minimum free disk space | Default: `0.3` |
| `NZ_TSDB_MAX_MEMORY_MB` | Optional | Maximum TSDB memory usage | Default: `64` |
| `NZ_TSDB_WRITE_BUFFER_SIZE` | Optional | Write buffer size | Default: `128` |
| `NZ_TSDB_WRITE_BUFFER_FLUSH_INTERVAL` | Optional | Write buffer flush interval in seconds | Default: `5` |

### GitHub Backup and Restore

| Variable | Required | Purpose | Notes |
| --- | --- | --- | --- |
| `GITHUB_USERNAME` | Required for backup | GitHub username used for backup | Backup is enabled only when all four backup variables are set |
| `REPO_NAME` | Required for backup | Backup repository name | `data-*.zip` files are stored in the repository root |
| `GITHUB_TOKEN` | Required for backup | GitHub token used for backup | A minimal-scope token and a dedicated repository are recommended |
| `ZIP_PASSWORD` | Required for backup | Password for the backup zip | Required for both backup and restore |

## Optional Features

### Custom Theme

When `NZ_EXTRA_USER_THEME` is set to a downloadable zip URL, the container will automatically:

1. Download the theme package
2. Extract it into a temporary directory
3. Detect the theme root automatically
4. Overwrite `/app/user-dist`

Example:

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

Notes:

- No manual `unzip` or `cp` steps are required
- Both flat zip layouts and one-level wrapper directory layouts are supported
- If `NZ_EXTRA_USER_THEME` is not set and `/app/user-dist` already exists, startup and automatic updates will try to preserve it
- If `NZ_EXTRA_USER_THEME` is set, the downloaded theme will overwrite the existing `/app/user-dist`

### TSDB

TSDB currently follows these rules:

- `NZ_ENABLE_TSDB=true`: generate TSDB config from environment variables and defaults
- `NZ_ENABLE_TSDB=false`: remove the `tsdb:` block from the config file
- `NZ_ENABLE_TSDB` unset and no `NZ_TSDB_*` variables set: keep the existing TSDB config in `config.yaml` unchanged
- Any `NZ_TSDB_*` variable set: rewrite the TSDB config using environment variables and defaults

The current defaults have been tuned down for low-spec machines:

- 7 days retention
- 64 MB max memory
- 0.3 GB minimum free disk space
- 128 write buffer size

Minimal example:

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

Custom retention example:

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

Notes:

- The default TSDB directory is `/app/tsdb`
- If you want TSDB data included in the existing GitHub backup, explicitly set the path to `/app/data/tsdb`
- If your restored `config.yaml` already contains a `tsdb:` block and you do not want to overwrite it, do not set `NZ_ENABLE_TSDB` or any `NZ_TSDB_*` variables
- After enabling TSDB, Nezha will switch to TSDB for historical metrics; old service monitor history is not migrated automatically

### GitHub Backup / Restore

When all four backup variables are provided, the container enables automatic backup and startup restore.

Backup behavior:

- Checked once per hour
- Automatically runs at 04:00 Asia/Shanghai if no backup has been created on that day yet
- You can trigger a manual backup by changing `README.md` in the backup repository to `backup`
- Only the latest 5 backups are kept

Backup contents:

- `/app/data`
- Generated `config.yml` inside the container

Notes:

- The backup repository history is force-pushed and rewritten; do not mix it with other important content
- `/app/tsdb` is not included by default; if you need TSDB backup, move it to `/app/data/tsdb`

### Fixed Version and Automatic Updates

- When `DASHBOARD_VERSION` is not set, the dashboard participates in automatic updates; if self-monitoring is enabled, the agent also participates in automatic updates
- When `DASHBOARD_VERSION` is set, automatic updates are skipped and neither dashboard nor agent update checks are executed

## Cloud Platform Deployment Examples (Docker Image)

This section is for platforms that can deploy directly from a Docker image. There are only three core points:

- Image: `kwxos/newzhav1:latest`
- Port: the container listens on `80`
- Persistence: mount `/app/data` whenever possible
- If you do not use persistent storage, GitHub backup should be enabled

> This project is usually exposed externally through Cloudflare Tunnel, but many platforms still require an internal listening port to be declared. That port is `80` here.

### Railway

1. Create a new project → New Service → Deploy from Docker Image.
2. Set the image to `kwxos/newzhav1:latest`.
3. Fill in the variables according to the Environment Variables section.
4. If persistence is needed, add a volume and mount it to `/app/data`.
5. If the platform requires a port or health check, set the internal port to `80` and the health check path to `/`.

### Render

1. Create a new Web Service → choose Deploy an existing image.
2. Set the image to `kwxos/newzhav1:latest`.
3. Fill in the Environment Variables.
4. Mount the disk to `/app/data` if your plan supports it.
5. Set the internal port to `80`.

## FAQ

- How should Cloudflare Tunnel point to the container?
  - In the Zero Trust Tunnel configuration, point Public Hostname / Ingress Service to the container HTTP service, usually `http://localhost:80`.
- What happens if `ARGO_AUTH` is not set?
  - `cloudflared` will not be downloaded or started, and the dashboard will only be accessible through the mapped container port.
- What happens if `IDU` or `NZ_DOMAIN` is not set?
  - `nezha-agent` will not be downloaded or started, and only the dashboard will run. If you want self-monitoring, set both variables.
- I do not want backup. Do I need to configure the GitHub backup variables?
  - No. If the four backup variables are not set, both backup and restore are skipped entirely.
- The agent is not reporting / connection failed?
  - First check whether `NZ_DOMAIN` is reachable from the public internet on port 443, and whether `NZ_agentsecretkey` matches the dashboard configuration.

## Reference for Variable Acquisition

For how to obtain a Cloudflare Tunnel token, you can refer to F Da's guide:

[How to get a Cloudflare Tunnel token](https://github.com/fscarmen2/Argo-Nezha-Service-Container/blob/main/README.md#%E6%96%B9%E5%BC%8F-2---token-%E9%80%9A%E8%BF%87-cloudflare-%E5%AE%98%E7%BD%91%E6%89%8B%E5%8A%A8%E7%94%9F%E6%88%90-argo-%E9%9A%A7%E9%81%93-token-%E4%BF%A1%E6%81%AF)

A short token-mode flow for generating `ARGO_AUTH` in the Cloudflare Zero Trust dashboard:

1. Log in to Cloudflare and enter Zero Trust at `one.dash.cloudflare.com`.
2. Open **Networks → Tunnels**, then create a tunnel and choose **Cloudflared**.
3. After creation, open the tunnel details page and find the **Token** section, or a similar area such as Run connector with a token.
4. Copy the token string, usually a long value that looks like `eyJhIjoi...`.
5. Put that token into the container environment variable `ARGO_AUTH`.

Then attach your `NZ_DOMAIN` to the tunnel:

- Add a rule under **Public Hostname / Ingress**:
  - **Hostname**: your dashboard domain, for example `nezha.example.com`
  - **Service**: the container HTTP service, usually `http://localhost:80`
- Make sure the domain is resolvable in Cloudflare DNS and proxied through Cloudflare

> Inside the container, a self-signed certificate is generated and port 443 is used for the agent (`server: $NZ_DOMAIN:443`). In most cases, you only need the tunnel to route external traffic to the container's port 80.

## Security Notes

- Change the dashboard password immediately after the first deployment
- `Force_Auth=false` is recommended to avoid exposing the dashboard to visitors
- Use a dedicated `GITHUB_TOKEN` and a dedicated repository whenever possible, with the minimum required permissions
- TSDB stores data on local disk, so reserve enough space for `/app/data` and try to keep at least 20% free space

## Acknowledgements

Thanks to [fscarmen2](https://github.com/fscarmen2) and the related Telegram community members for the ideas and script references.
