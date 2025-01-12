### V1版哪吒面板，自动备份,可选版本安装，可选择是否更新。

没用`OAuth 2.0` 登录要授权太麻烦，所以安装好第一件事，**必须进面板改密码**
Docker镜像地址
```
kwxos/newzhav1:latest
```
必须设置的变量

| 变量 | 值 | 备注 |
| --- | --- | --- |
ARGO_AUTH | 从[cloudflared Tunnels](https://one.dash.cloudflare.com/)获取的 Argo Token | 像eyJhIjoi.......类似 |
NZ_DOMAIN | 哪吒的访问域名 | 用于面板访问和探针上报使用 |
NZ_agentsecretkey | nezha dashboard 的.yaml文件设置的固定key | 文件中的agentsecretkey所对应的参数 |
DASHBOARD_VERSION | 需要部署的面板的等级,格式：`v1.5.11` | 若设置此变量，面板则不会自动更新，不设置则每晚4点自动更新 |
IDU | 面板当前所在的agent的uuid | 用于监测面板docker的状态 |
GITHUB_USERNAME | Github的用户名 | 用于哪吒配置文件备份 |
REPO_NAME | Github的备份仓库名 | 用于哪吒配置文件备份 |
GITHUB_TOKEN | Github的token | 用于哪吒配置文件备份 |

改的`TG \`大佬的代码，大佬的Github不晓得为啥关了
改动主要有代码改动，代码运行逻辑改动，以及版本号固定等...
