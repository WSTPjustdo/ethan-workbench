// Local output is deliberately excluded from Git. Never print generated secrets.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const bcrypt = require('bcryptjs');
const config = path.resolve(__dirname, '../.local-runtime/config');
const dbPassword = process.env.DB_PASSWORD;
if (!dbPassword) throw new Error('Set DB_PASSWORD in your local process environment first.');
const names = ['application-local.yml', 'login.json', 'initialize-admin.sql'];
for (const name of names) if (fs.existsSync(path.join(config, name))) throw new Error('Existing local configuration found; no files were changed.');
const password = 'ERP-' + crypto.randomBytes(6).toString('hex');
const tokenSecret = crypto.randomBytes(64).toString('hex');
const dbPort = Number(process.env.DB_PORT || 13306);
if (!Number.isInteger(dbPort) || dbPort < 1 || dbPort > 65535) throw new Error('Invalid DB_PORT');
const dbUsername = process.env.DB_USER || 'ethan';
const yml = `server:
  address: 127.0.0.1
  port: 6149
spring:
  datasource:
    url: jdbc:mysql://127.0.0.1:${dbPort}/qihang-erp?useUnicode=true&characterEncoding=utf8&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia%2FShanghai
    username: ${JSON.stringify(dbUsername)}
    password: ${JSON.stringify(dbPassword)}
  data:
    redis:
      host: 127.0.0.1
      port: 16379
      database: 0
  ai:
    deepseek:
      api-key: local-disabled-no-credentials
      base-url: http://127.0.0.1:9
    openai:
      api-key: local-disabled-no-credentials
      base-url: http://127.0.0.1:9
erp:
  scheduling:
    enabled: false
token:
  secret: ${JSON.stringify(tokenSecret)}
`;
const hash = bcrypt.hashSync(password, 12);
const sql = `-- Apply only after importing the sanitized schema into your new database.\nUPDATE sys_user SET password='${hash}',status='0' WHERE user_id=1 AND user_name='admin' AND password='!SET_PASSWORD_BEFORE_USE!' AND status='1';\n`;
fs.mkdirSync(config, { recursive: true });
fs.writeFileSync(path.join(config, names[0]), yml, { flag: 'wx', mode: 0o600 });
fs.writeFileSync(path.join(config, names[1]), JSON.stringify({ username: 'admin', password }, null, 2), { flag: 'wx', mode: 0o600 });
fs.writeFileSync(path.join(config, names[2]), sql, { flag: 'wx', mode: 0o600 });
console.log('Private configuration created in .local-runtime/config. Import initialize-admin.sql into your new database; read login.json locally.');
