# 部署到 Cloudflare

这个目录已经是 AstroPaper v6（Astro 7 + Tailwind 4）的可运行状态，并且已经配置好 Cloudflare Workers 静态资源部署。

- 本地构建：`pnpm build` → 产物在 `dist/`
- 本地预览构建结果：`pnpm preview`
- 本地模拟 Cloudflare 环境：`pnpm cf:preview`（= `wrangler dev`）
- 一键构建 + 部署：`pnpm deploy`（= `pnpm build && wrangler deploy`）

## 版本固定

pnpm 版本固定在 `package.json` 的 `packageManager` 字段（当前 `pnpm@11.25.0`），`engines.pnpm` 约束 `>=11.25.0 <12`。CI（`pnpm/action-setup`）和 `Dockerfile` 都直接读取这个字段，不再各自硬编码版本；升级时只需改这一处，然后跑一次 `pnpm install` 更新 lockfile。

Node 版本要求仍然是 `>=22.12.0`（见 `engines.node`，Cloudflare 上用 `NODE_VERSION=24`）。

## 0. 先改这几处占位信息

`astro-paper.config.ts`：

| 位置                  | 说明                                                   |
| --------------------- | ------------------------------------------------------ |
| `site.url`            | 正式域名，带协议和结尾斜杠，如 `https://blog.foo.com/` |
| `site.title`          | 博客名（当前 `Lab Blog`）                              |
| `site.description`    | 站点描述，用于 SEO / RSS                               |
| `site.author`         | 默认作者名                                             |
| `site.profile`        | 作者主页（结构化数据用）                               |
| `site.timezone`       | 时区，当前 `Asia/Shanghai`                             |
| `features.editPost`   | “编辑此页”链接，改成你的仓库地址或 `{ enabled: false }` |
| `socials`             | 社交链接，图标名见 `src/assets/icons/socials/`         |

`wrangler.jsonc` 里的 `name: "lab-blog"` 是 Worker 名称，也会决定 `*.workers.dev` 子域名，可以按需改。

> `site.url` 一定要在第一次正式部署前填对，它会写进 canonical、sitemap、RSS 和 OG 图。

## 1. 本地跑起来

```bash
pnpm dev        # http://localhost:4321
pnpm build      # 构建 + Pagefind 搜索索引
pnpm preview    # 预览 dist
```

## 2. 推到 GitHub

当前仓库已经重新初始化过，只有一次初始提交，远端的 `satnaing/astro-paper` 已移除。

```bash
# 在 GitHub 上新建一个空仓库（不要勾选 README / .gitignore），然后：
git remote add origin git@github.com:<你的用户名>/lab-blog.git
git push -u origin main
```

## 3. 部署到 Cloudflare（推荐：Workers + 静态资源）

Cloudflare 现在推荐新项目用 Workers，而不是 Pages；本项目是纯静态站点，不需要任何 adapter。

### 方式 A：连接 Git 自动部署（推荐）

1. 打开 [Cloudflare Dashboard](https://dash.cloudflare.com/) → **Workers & Pages** → **Create application**
2. 选 **Workers** → **Import a repository**（连接 GitHub，授权 `lab-blog` 仓库）
3. 构建设置：
   - Build command：`pnpm build`
   - Deploy command：`npx wrangler deploy`
   - Root directory：`/`（默认）
4. 环境变量（Settings → Build → Variables）：
   - `NODE_VERSION` = `24`（Astro 7 要求 Node ≥ 22.12）
5. 保存并部署。之后每次 push 到 `main` 都会自动构建发布，PR 会有预览部署。

### 方式 B：本地命令行部署

```bash
npx wrangler login   # 浏览器授权一次
pnpm deploy          # 构建并上传
```

第一次部署后地址形如 `https://lab-blog.<你的-workers-子域>.workers.dev`。

### 方式 C：仍然想用 Cloudflare Pages

可以，纯静态站点 Pages 完全够用：连接 Git 后 Build command 填 `pnpm build`、Build output directory 填 `dist`，环境变量加 `NODE_VERSION=24` 即可。区别是 Pages 正在逐步并入 Workers，新项目官方更推荐 Workers。

## 4. 绑定自己的域名

Worker → **Settings** → **Domains & Routes** → **Add** → **Custom domain**，输入域名并按提示在 Cloudflare 托管 DNS 里加记录（域名需已托管在 Cloudflare，免费计划即可，自带 SSL）。

绑定后记得把 `astro-paper.config.ts` 的 `site.url` 改成这个域名，再 push 一次触发重新构建，否则 canonical / sitemap 仍然指向旧地址。

## 5. 写文章

在 `src/content/posts/` 下新建 `.md` 或 `.mdx`，frontmatter 必填 `title`、`pubDatetime`、`description`：

```md
---
title: "我的第一篇文章"
pubDatetime: 2026-10-20T10:00:00+08:00
description: "一句话摘要，会出现在列表和 SEO 描述里。"
tags: ["notes"]
draft: false
---

正文……
```

- 子目录会变成 URL 的一部分；以 `_` 开头的目录只用于整理、不影响 URL
- `draft: true` 的文章不会发布
- 文章里的图片放 `src/assets/images/`，用相对路径引用
- “关于”页在 `src/content/pages/about.md`

## 6. 上线前的清理

模板自带的示例文章已经删除，`src/content/posts/` 里只剩自己的文章。还需要把 `src/content/pages/about.md` 从模板默认文案改成自己的介绍。

写作规范和这套模板的完整功能，见站内文章《AstroPaper 模板速查手册》（`src/content/posts/astropaper-guide.md`）。

## 7. 可选增强

- **Google Search Console**：在 `astro-paper.config.ts` 的 `site.googleVerification` 填验证值
- **站点统计**：Cloudflare Web Analytics（免费、无 Cookie）在 Dashboard → Analytics 里开启
- **缓存 / 安全响应头**：`cf/_headers`，构建时由 `scripts/cf-headers.mjs` 复制到 `dist/_headers`
- **资源配额**：Workers 免费版静态资源上限约 25 MiB，当前构建产物约 8.4 MB，够用
