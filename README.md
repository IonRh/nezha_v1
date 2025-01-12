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
