# 云同步

词悦可以通过远程文件存储合并你的单词本、标签、抽认卡和复习历史。首次连接时会显示只读预览，在你确认之前不会写入任何内容。词典单独列出，只有当你选中时才会传输。

凭据保存在平台的安全存储中，而不是应用偏好设置里。词悦不提供自建的同步服务。WebDAV、SFTP 和 S3 兼容存储使用的都是开放协议，不需要注册词悦账号。

## WebDAV

输入服务器 URL、远程文件夹，以及可选的用户名/密码。只要服务器不在本机，就请使用 HTTPS。WebDAV 适用于 Nextcloud、ownCloud 以及提供 WebDAV 的 NAS 等服务。

## SFTP

输入 `sftp://` 格式的 URL，例如 `sftp://nas.example.net:22/backups`。URL 中的路径是基准目录；省略时使用 SFTP 账号的主目录。输入用户名，以及密码、SSH 私钥文件或两者都填。加密的私钥可以用 passphrase 解锁。

词悦要求固定 SSH 主机密钥指纹，缺失或不符的指纹会被拒绝。请通过可信渠道从服务器管理员处获取 SHA-256 指纹。对于 OpenSSH 服务器，可以用下面的命令打印指纹，再与管理员给的值比对：

```sh
ssh-keyscan -t ed25519 nas.example.net | ssh-keygen -lf -
```

把 `SHA256:...` 的值填进词悦。`ssh-keyscan` 本身不验证服务器身份，所以它的输出必须经过独立核实才能信任。如果服务器用的是其他主机密钥算法，请指定对应的算法。主机密钥变更后（比如更换服务器），需要更新保存的指纹。

## S3 兼容存储

输入 HTTPS endpoint、bucket、region、access key ID 和 secret access key。远程文件夹会作为 bucket 内的前缀使用，词悦只列出该前缀下的对象，不会扫描无关内容。例如：

- MinIO：使用服务器的 endpoint 和 region，通常启用 path-style addressing。
- Cloudflare R2：使用账号的 endpoint，region 填 `auto`，通常关闭 path-style addressing。
- AWS S3：使用 `https://s3.<region>.amazonaws.com`、对应的 region，关闭 path-style addressing。

寻址模式取决于服务商；如果连接测试失败，请检查服务商的 endpoint 和 bucket 寻址要求。明文 HTTP 只接受回环开发地址，如 `http://127.0.0.1:9000`。请使用仅限该 bucket、最小权限（列出、读取、写入、复制、删除词悦同步对象）的凭据。

## 同步行为

词悦保存带版本的同步记录，合并各设备的变更。并发的编辑和删除会被保留为冲突，而不是悄悄覆盖。预览不会创建目录、上传数据，也不会修改远程存储。确认预览后才开始同步。

词典文件默认不包含在内。请在预览中逐个选中需要同步的词典。下载的文件会先校验再加入本地词典库，不会自动启用。

## 哪些文件会随词典一起同步

MDX 词典会带上它的 `.mdd` 资源、同目录下的 `.css` 和 `.js`，以及为该词典设置的自定义字体。

StarDict 词典会带上 `.ifo`、索引与正文（`.idx` 或 `.idx.gz`、`.dict` 或 `.dict.dz`）、可选的同义词索引（`.syn`、`.syn.gz` 或 `.syn.dz`），以及下列任一位置上的资源归档：`res.zip`、`<name>.res.zip`、`res/res.zip`。

`res/` 目录也会同步，但仅限文件数不超过 100 个、总大小不超过 20 MB 的情况。超出该范围时会跳过整个目录，词典的其余文件仍照常同步。资源是逐个文件上传的，所以上千个文件会让传输很慢，并让整本词典超出词悦允许的包内文件数。如果你的词典把大量图片或音频散放在 `res/` 里，请把它们打包成 `res.zip`：词悦会直接读取归档，一个文件就替代了成千上万个。
