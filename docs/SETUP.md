# 源码部署

这是源码仓库。原电脑使用的 MySQL / Redis 数据、便携安装包、账号和令牌密钥不随仓库分发。

## 通用本机部署

1. 安装 Java 17、Maven 3.9、Node.js（本机验证为 24）、MySQL 8.x 和 Redis。以下示例使用 MySQL `127.0.0.1:13306`、Redis `127.0.0.1:16379`；如使用其他端口请对应修改私有配置。
2. 在新建的空数据库环境执行 `qihang-erp-local/docs/qihang-erp.sql`。脚本会创建 `qihang-erp` 库并重建其中各表，**不要对已有业务数据库执行**。另外创建一个只能访问该库的本地数据库账号。
3. 在本机 PowerShell 会话提供数据库账号与密码，再生成私有配置。下面通过隐藏输入读取数据库密码，不在命令中写入实际密码：

   ```powershell
   $env:DB_USER = 'ethan'
   $localDbCredential = Get-Credential -UserName $env:DB_USER -Message '输入你创建的本地数据库账号密码'
   $env:DB_PASSWORD = $localDbCredential.GetNetworkCredential().Password
   Push-Location tools
   npm ci --ignore-scripts
   npm run configure
   Pop-Location
   Remove-Item Env:DB_PASSWORD
   ```

   生成器不覆盖已有配置，生成独立随机管理员密码和令牌密钥。生成文件位于被 Git 忽略的 `.local-runtime/config/`，不要将其提交。

4. 使用你的数据库客户端，在上述新库执行 `.local-runtime/config/initialize-admin.sql`，启用新管理员。未完成这一步时管理员停用，没有通用默认密码。
5. 构建后端，在仓库根目录运行：

   ```powershell
   Push-Location qihang-erp-local
   mvn -B -ntp package
   Pop-Location
   java -jar qihang-erp-local/erp-api/target/erp-api-4.1.0.jar --spring.profiles.active=local --spring.config.additional-location=file:./.local-runtime/config/
   ```

   保持后端终端运行，在另一个终端启动前端：

   ```powershell
   Set-Location qihang-erp-local/vue3
   npm ci --no-audit --no-fund
   npm run dev -- --host 127.0.0.1 --port 5188 --strictPort
   ```

6. 打开 `http://127.0.0.1:5188/`，用户名 `admin`。本地随机密码在 `.local-runtime/config/login.json`；Windows 也可双击根目录的 `查看登录账号.cmd` 查看并复制。

配置中的 AI 外部调用和定时任务默认关闭。真实店铺与罗盘对接需另外完成授权与验证。更改配置后重启后端。前端正式构建命令为 `npm run build`。

## 原 Windows 便携环境脚本

`打开工作台.cmd` / `停止工作台.cmd` 与 `local-deployment/` 下脚本是从原电脑保留的辅助文件，依赖 `.local-runtime/` 中既有的便携软件、数据目录、MySQL 配置及目录映射。它们**不会下载软件或初始化环境**，新克隆请使用上面的通用步骤。

不要让两个工作副本同时使用原脚本的同一个目录映射或端口。原电脑上的正在使用的部署目录独立于此公开发布副本。

## 已知限制

上游表之间的字段长度存在不一致：当前使用时仓库编码不超过 10 字符、仓库名不超过 20、商品编码不超过 20、SKU 编码不超过 25、出库单号不超过 20。相关事务及异常路径尚未完整修复验证。

仓库只包含脱敏后的基础表结构与菜单字典；没有真实订单、库存或平台授权。平台 API 地址和回调地址需部署者自行配置，不能仅凭存在平台条目认定已经接入。
