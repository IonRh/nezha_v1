V1版哪吒面板，自动备份,可选版本安装，可选择是否更新。

Docker镜像地址
```
kwxos/newzhav1:latest
```
必须设置的变量
```
ARGO_AUTH           #cloudflared token
NZ_agentsecretkey   #nezha dashboard secret key
GITHUB_USERNAME     #github user name
REPO_NAME           #backup repo name
GITHUB_TOKEN        #github token
NZ_DOMAIN           #nezha domain
idu                 #nezha UUID
```
| 变量 | 值 | 解释 |
| --- | --- | --- |
ARGO_AUTH | 从[cloudflared Tunnels](https://one.dash.cloudflare.com/)获取的 Argo Token | 像eyJhIjoi.......类似 |
NZ_agentsecretkey | nezha dashboard 的.yaml文件设置的固定key | 文件中的agentsecretkey所对应的参数 |
GITHUB_USERNAME | Github的用户名 | 用于哪吒配置文件备份 |
REPO_NAME | Github的备份仓库名 | 用于哪吒配置文件备份 |
GITHUB_TOKEN | Github的token | 用于哪吒配置文件备份 |
NZ_DOMAIN | 哪吒的访问域名 | 用于面板访问和探针 |
idu | 面板当前所在的agent的uuid | 用于监测面板docker的状态 |
DASHBOARD_VERSION | 需要部署的面板的等级 | 格式：`v1.5.11` |
