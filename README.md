### V1版哪吒面板，自动备份,可选版本安装，可选择是否更新。

没用`OAuth 2.0` 登录要授权太麻烦，所以安装好第一件事，**必须进面板改密码**
Docker镜像地址
```
kwxos/newzhav1:latest
```
必须设置的变量

| 变量 | 值 | 备注 |
| --- | --- | --- |
ARGO_AUTH | 从[cloudflared Tunnels](https://one.dash.cloudflare.com/)获取的 Argo Token | 像eyJhIjoi.......类似,映射端口，只需要80端口就行了 |
NZ_DOMAIN | 哪吒的访问域名 | 用于面板访问和探针上报使用 |
NZ_agentsecretkey | nezha dashboard 的.yaml文件设置的固定key | 文件中的agentsecretkey所对应的参数 |
DASHBOARD_VERSION | 需要部署的面板的等级,格式：`v1.5.11` | 若设置此变量，面板则不会自动更新，不设置则每晚4点自动更新 |
IDU | 面板当前所在的agent的uuid | 用于监测面板docker的状态 |
GITHUB_USERNAME | Github的用户名 | 用于哪吒配置文件备份 |
REPO_NAME | Github的备份仓库名 | 用于哪吒配置文件备份 |
GITHUB_TOKEN | Github的token | 用于哪吒配置文件备份 |
Force_Auth | 面板是否访客可见 | 可见为true，需输入密码为false |
ZIP_PASSWORD | 备份的压缩包密码 | 用于哪吒配置文件备份压缩包 |

变量获取方法参考:
`F大`的[nezha_v0](https://github.com/fscarmen2/Argo-Nezha-Service-Container/blob/main/README.md#%E6%96%B9%E5%BC%8F-2---token-%E9%80%9A%E8%BF%87-cloudflare-%E5%AE%98%E7%BD%91%E6%89%8B%E5%8A%A8%E7%94%9F%E6%88%90-argo-%E9%9A%A7%E9%81%93-token-%E4%BF%A1%E6%81%AF)

感谢[F大](https://github.com/fscarmen2)和`TG \`大佬
改的`TG \`大佬的代码，大佬的Github不晓得为啥关了
改动主要有代码改动，代码运行逻辑改动，以及版本号固定等...
