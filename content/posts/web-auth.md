+++
date = '2025-04-25T17:15:34+08:00'
lastmod = '2025-04-25T17:15:34+08:00'
draft = false
title = 'Web 身份鉴权技术方案'
tags = ['Web', 'Authentication', 'Authorization']
categories = ['Engineering']
series = []
+++

Web 身份鉴权是 Web 应用安全的第一道防线，也是所有需要验证用户身份、管理权限、保障数据完整性系统的必备能力

这个领域有两个术语易混淆

- Authentication
- Authorization

分别对应中文「认证」和「授权」。前者是对用户身份的鉴别，一般用于登录；后者是在明确用户身份的情况下，对该用户权限范围的管控

## 主流 Web 鉴权方案

### HTTP Basic Authentication

流程：

1. 客户端传递用户的账号、密码给服务端
2. 服务端校验后返回资源

这种方案的优点是简单开发成本低。但缺点也非常明显，明文传输不安全（需依赖 HTTPS）、无防重放机制、用户体验差。在一般需要实现简单、但能满足基本权限校验需求的场景下，比如快速原型开发、内部低安全性要求 API 场景下，这种方案比较适用

需要注意，即便是使用这种方案的情况下，密码也不能明文存在数据库中。一般是在服务端对密码进行一次加盐的 hash 计算，生成一个摘要值进行存储，后续用户登录时判断密码匹配也需要进行同样的计算，然后将结果同数据库中的值进行比较

### Cookie/Session 机制

流程：

1. 首次访问系统时，输入账号密码进行登录
2. 服务端校验账号密码匹配后，生成 Session ID 存储用户状态，并通过 Cookie 将 Session ID 返回给客户端
3. 后续每次 HTTP 通信需客户端携带 Cookie 与服务端交互
4. 服务端校验 Session ID 对应的用户状态确认登录状态

这种方案在业界过去使用非常普遍，但同时随着用户数量增长，服务架构分布式演进，缺点也逐渐显现：

- Session 需要进行存储和管理，存储成本高，维护复杂
- 维护分布式 Session 一致性有挑战

从安全性角度来看，将 Session 信息存储在 Cookie 中也有相当的风险，遇到 CSRF、XSS 攻击且没有做好防护，会导致身份权限信息泄露，可能造成巨大损失

这里又会引出两个如何经典问题：如何防范 CSRF 攻击？如何防范 XSS 攻击？

**CSRF 攻击的防范措施**

1. Anti CSRF Token。**示例**：在 HTML 表单中添加隐藏字段：

    在表单或请求中添加随机生成的Token，服务器验证Token的有效性。Token需满足随机性、保密性，并存储在Session或Cookie中，每次请求进行比对

    ```html
    <input type="hidden" name="csrf_token" value="随机生成的Token">
    ```

2. 验证请求来源

    检查HTTP头的 `Referer` 或 `Origin` 字段是否属于合法域名。但需注意，某些浏览器可能不发送 `Referer` ，且攻击者可伪造该字段，因此需与其他方法结合使用

3. SameSite Cookie 属性

    设置 Cookie 的 `SameSite=Strict` 或 `Lax` ，阻止跨站请求携带 Cookie。现代浏览器默认对敏感 Cookie 启用此设置

4. 限制 HTTP 方法

    敏感操作（如修改数据）仅允许使用 POST 等非幂等方法，避免 GET 请求被恶意构造（如通过 `<img>` 标签触发）

5. 双重认证

    对关键操作（如转账）要求用户二次验证（如短信验证码），增加攻击难度


**XSS 攻击的防范措施**

1. 输入验证与过滤

    对用户输入内容进行严格过滤，移除或转义特殊字符（如 `<`、`>`、`&` ），防止脚本注入。正则表达式可用于检测危险模式（如 `script` 标签）

2. 输出编码

    在将数据输出到页面时，根据上下文（HTML、JavaScript、URL）进行编码。例如，HTML 实体编码（ `&lt;` 代替 `<` ）

3. 内容安全策略（CSP）

    通过 HTTP 头 `Content-Security-Policy`  限制页面只能加载指定来源的脚本、样式等资源，阻止外部恶意脚本执行

4. HttpOnly Cookie

    设置 Cookie 的 `HttpOnly` 属性，防止 JavaScript 读取敏感 Cookie（如会话 ID）

5. 避免内联脚本与危险 API

    减少使用 `eval()`、`innerHTML` 等动态执行代码的方法，改用安全的DOM操作方法

6. 框架安全机制

    使用现代框架（如React、Vue）的自动转义功能，或后端框架（如Django）的XSS防护模块


### Token 鉴权

Token 鉴权的本质思想是将鉴权信息编码到一个字符串中，每次网络交互时服务端将 Token 中的信息进行动态解码校验，直接从这些信息判断是否鉴权通过。因为这种方法不需要进行存储，所以**特别适用于分布式系统和微服务架构**

#### JWT

JWT（JSON Web Token）是一种用于在网络应用间安全传递信息的开放标准

1. 结构：JWT 由三部分组成，每部分用点（.）分隔：
    - 头部（Header）
    - 载荷（Payload）
    - 签名（Signature）
2. 头部：包含令牌类型和使用的哈希算法
3. 载荷：包含声明（Claims）。这是存储用户信息或其他数据的地方
4. 签名：用于验证消息在传输过程中没有被更改
5. 工作流程：
    - 用户登录后，服务器创建 JWT
    - 服务器将 JWT 返回给客户端
    - 客户端在后续请求中携带 JWT
    - 服务器验证 JWT 的签名和有效期
6. 无状态：服务器不需要存储会话信息，因为所有必要的数据都包含在 Token 中
7. 安全性：虽然 JWT 的前两部分是 Base64 编码的，可以被解码，但签名确保了数据不被篡改。敏感信息不应该放在 Payload 中

**JWT 的实例**

这是一个 JWT Token 的示例

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

这个 Token 由三部分组成，每部分用点 `.` 分隔。如果我们解码每一部分，会得到以下信息：

第一部分 Header:

```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

第二部分 Payload:

```json
{
  "sub": "1234567890",
  "name": "John Doe",
  "iat": 1516239022
}
```

第三部分 Signature，用于验证 Token 的完整性

Tips：

1. 在实际应用中，Payload 可能包含更多信息，如用户 ID、角色、权限等
2. Header 和 Payload 部分是经过 Base64URL 编码的，可以被轻易解码。因此，不应在 Payload 中包含敏感信息
3. Signature 部分是使用 Header 中指定的算法（在这个例子中是 HS256），结合一个秘密密钥生成的，这确保了 Token 不被篡改

#### OAuth 2.0

[OAuth 2.0](https://oauth.net/2/) 是用于授权的行业标准协议，本质也是基于 Token 来实现的

主要思想：第三方应用通过授权码获取访问令牌（Access Token），代表用户访问资源

{{< image src="https://webp.slightsnow.com/2025/04/35b48f2b9fd8f2287fe79bb944e8d751.png" caption="20250425171712664"  height="1000" width="500" >}}

主要使用场景是第三方登录（如 Google 登录、微信登录）、API 开放平台等

#### **安全性**

**如果 Token 泄露，攻击者可能会利用它来伪造用户身份**

因此，需要针对这个问题从架构层面仔细设计，避免造成灾难。大体上有几个方面的问题需要我们解决：

1. Token 如何存储
2. Token 如何传输
3. Token 过期、续期机制
4. 服务端 Token 主动管理能力
5. 多因素验证机制：2FA、MFA 等

## 未来趋势

- 无密码化演进：FIDO2 标准（WebAuthn）逐步替代动态码，通过生物识别或硬件密钥实现无密码登录
- AI 动态风控：结合行为分析，实时调整令牌权限（如异常登录触发二次验证）