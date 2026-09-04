# MD Forge - 产品需求文档 (PRD)

> 合并自 `harmony-md-reader`（阅读器）与 `md-hongmengban`（编辑器）
> 目标：上架华为应用市场
> 日期：2026-06-19

---

## 1. 产品定义

### 1.1 产品名称

**MD Forge** — Markdown 编辑与渲染引擎

### 1.2 一句话描述

鸿蒙手机/平板上唯一支持 LaTeX 公式、Mermaid 图表、代码高亮的 Markdown 编辑阅读器。

### 1.3 核心卖点（为什么用户要装你）

系统自带预览只能显示纯文本 Markdown。MD Forge 能渲染：

| 能力 | 系统预览 | MD Forge |
|------|---------|----------|
| 基础 Markdown | 能 | 能 |
| LaTeX 数学公式 `$$E=mc^2$$` | 不能 | 能（KaTeX） |
| Mermaid 流程图/时序图 | 不能 | 能 |
| 代码语法高亮 | 不能 | 能（190+ 语言） |
| 任务列表 `- [x]` | 不能 | 能 |
| 编辑 Markdown | 不能 | 能 |
| 离线渲染 | 不确定 | 能（全本地库） |

### 1.4 目标用户

通用。不局限特定人群：
- 开发者：看技术文档、README、代码
- 学生：看带公式的课件/笔记
- 写作者：编辑和预览 Markdown 文章
- 普通用户：打开聊天中收到的 .md/.html 文件

---

## 2. 功能全景

### 2.1 阅读模式（来自 harmony-md-reader）

| 功能 | 状态 | 说明 |
|------|------|------|
| 系统文件关联 | 已实现 | .md/.markdown/.html/.htm 注册为 handler |
| 文件分享打开 | 已实现 | 从微信/飞书/邮件等分享到 MD Forge |
| Markdown 渲染 | 已实现 | GFM + 任务列表 + 表格 |
| 代码高亮 | 已实现 | highlight.js，190+ 语言，atom-one-dark 主题 |
| 数学公式 | 已实现 | KaTeX，行内 `$...$` + 块级 `$$...$$` |
| Mermaid 图表 | 已实现 | 流程图/时序图/甘特图/饼图 |
| HTML 渲染 | 已实现 | 直接 innerHTML |
| 最近文件 | 已实现 | 最多 20 条记录 |
| 文件信息 | 已实现 | 文件名/大小/字数 |
| 离线渲染 | 已实现 | 全部库本地化，无 CDN 依赖 |

### 2.2 编辑模式（来自 md-hongmengban + 增强）

| 功能 | 状态 | 说明 |
|------|------|------|
| 左右分栏 | 已实现 | 左边 TextInput 编辑，右边 WebView 实时预览 |
| 实时预览 | 已实现 | onChange → postMessage → marked.parse |
| 文件保存 | 已实现 | 保存回原文件 |
| 新建文档 | 已实现 | 从首页"新建文档"进入 |

### 2.3 首页

| 功能 | 状态 | 说明 |
|------|------|------|
| 最近文件列表 | 已实现 | 显示文件名/大小/时间 |
| 新建文档按钮 | 已实现 | 跳转编辑页 |
| 使用引导 | 已实现 | 三步引导用户打开文件 |
| 空状态 | 已实现 | 无文件时的友好提示 |

---

## 3. 技术架构

### 3.1 页面结构

```
HomePage ──(打开文件)──→ ReaderPage ──(编辑按钮)──→ EditorPage
    │                        │                          │
    └──(新建文档)────────────┘                          │
    └──(最近文件点击)──→ ReaderPage                      │
                                                       │
    EditorPage ──(返回)──→ ReaderPage ←─────────────────┘
```

### 3.2 文件结构

```
entry/src/main/
├── ets/
│   ├── entryability/EntryAbility.ets    (~65 行)  应用生命周期 + 文件 URI 提取
│   └── pages/
│       ├── HomePage.ets                 (~195 行) 首页：最近文件 + 快捷操作
│       ├── ReaderPage.ets               (~155 行) 阅读页：文件读取 + WebView 渲染
│       └── EditorPage.ets               (~110 行) 编辑页：TextInput + 实时预览
├── resources/
│   ├── base/element/{color,string}.json
│   ├── base/profile/main_pages.json
│   └── rawfile/
│       ├── web-template.html            (~155 行) 阅读渲染引擎
│       ├── editor-preview.html          (~100 行) 编辑预览引擎
│       └── lib/
│           ├── marked.min.js            (35 KB)   Markdown 解析
│           ├── highlight.min.js         (122 KB)  代码高亮
│           ├── katex.min.js             (277 KB)  数学公式
│           ├── mermaid.min.js           (3.3 MB)  图表绘制
│           ├── atom-one-dark.min.css              代码主题
│           ├── katex.min.css                      公式样式
│           └── fonts/                   (61 文件, ~1.2 MB) KaTeX 字体
└── module.json5                         文件关联 + 权限声明
```

### 3.3 渲染管线

**阅读模式：**
```
文件 URI → fs.readSync → TextDecoder → runJavaScript('_renderContent')
  → marked.parse → hljs.highlightElement → mermaid.render → katex.render
```

**编辑模式：**
```
TextInput.onChange → runJavaScript('postMessage')
  → marked.parse → hljs.highlightElement
```

### 3.4 依赖库（全部本地化）

| 库 | 版本 | 大小 | 用途 |
|----|------|------|------|
| marked.js | 12.x | 35 KB | Markdown → HTML |
| highlight.js | 11.x | 122 KB | 代码语法高亮 |
| KaTeX | 0.16.x | 277 KB + 1.2 MB 字体 | LaTeX 数学公式 |
| Mermaid | 10.x | 3.3 MB | 流程图/时序图等 |

**总 rawfile 大小：~5 MB**（全部本地，无需网络）

---

## 4. 合并策略

两个项目的代码已通过本地开发自然合并。合并关系：

| 来源 | 贡献 |
|------|------|
| harmony-md-reader | 文件关联、ReaderPage、HomePage、最近文件、web-template.html、全本地库 |
| md-hongmengban | EditorPage 概念、editor-preview.html、postMessage 通信模式 |
| 本地新增 | EditorPage 实现（基于 md-hongmengban 概念重写）、editor-preview.html（带代码高亮）、emitter 事件通信、文件保存能力 |

合并后保留 `harmony-md-reader` 作为主仓库，`md-hongmengban` 归档。

---

## 5. 上架准备清单

### 5.1 必须完成

| 项目 | 当前状态 | 行动 |
|------|---------|------|
| 应用名称 | "MD Reader" | 改为 "MD Forge" 或保持 |
| 应用图标 | 可能是占位符 | 需要确认/替换 |
| 隐私政策 | 无 | 需要编写（应用不收集任何数据） |
| 应用截图 | 无 | 需要在真机上截图（至少 4 张） |
| 应用描述 | 无 | 需要编写 |
| 签名配置 | debug 签名 | 需要正式签名 |
| 版本号 | 1.0.0 | 可保持 |

### 5.2 应用市场描述（草稿）

**应用名称：** MD Forge - Markdown 阅读编辑器

**一句话描述：** 支持数学公式、代码高亮、流程图的 Markdown 阅读与编辑

**详细描述：**
MD Forge 是一款鸿蒙原生 Markdown 工具，提供远超系统预览的渲染能力。

核心特性：
- LaTeX 数学公式渲染（行内和块级）
- 190+ 编程语言代码语法高亮
- Mermaid 流程图、时序图、甘特图
- 任务列表、表格、引用等完整 GFM 支持
- 左右分栏实时编辑预览
- 从文件管理器或聊天工具直接打开 .md/.html 文件
- 完全离线运行，无需网络连接
- 最近打开文件记录

### 5.3 截图清单（建议）

1. 首页（最近文件列表）
2. 阅读模式（含代码高亮的技术文档）
3. 阅读模式（含 LaTeX 公式的文档）
4. 阅读模式（含 Mermaid 流程图的文档）
5. 编辑模式（左右分栏）

### 5.4 隐私政策要点

- 不收集用户数据
- 不联网（所有渲染库本地化）
- 不使用 Cookie 或本地存储追踪
- 仅读取用户主动打开的文件
- 不上传任何文件内容

---

## 6. 已知问题与风险

| 问题 | 严重性 | 应对 |
|------|--------|------|
| app_icon 可能是占位符 | HIGH | 检查并替换为正式图标 |
| 编辑页 TextInput 不支持多行滚动 | MEDIUM | 真机测试确认 |
| debug 签名不能上架 | HIGH | 使用正式签名重新构建 |
| mermaid.min.js 3.3MB 占 APK 体积 | LOW | 可接受，用户不需要下载额外资源 |
| HTML innerHTML 无净化 | LOW | 阅读场景风险低 |

---

## 7. 后续迭代方向（不在 V1.0 范围）

| 方向 | 优先级 | 说明 |
|------|--------|------|
| 暗色模式 | HIGH | 阅读+编辑双主题 |
| 导出为 HTML/PDF | HIGH | 闭环体验 |
| 系统分享输出 | MEDIUM | 把渲染结果分享给其他应用 |
| 文件管理器集成 | MEDIUM | 应用内浏览本地 .md 文件 |
| 平板双栏布局 | MEDIUM | 利用大屏空间 |
| 编辑器工具栏 | MEDIUM | Markdown 快捷语法插入 |
| 自动保存 | MEDIUM | 定时保存编辑中的文件 |
| 搜索 | LOW | 文件内容全文搜索 |
| 分布式流转 | LOW | 手机→平板接力 |
