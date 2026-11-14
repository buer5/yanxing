# 言行 (Yanxing) CLI

轻量级 Windows 终端英文打字与听写 TUI 工具。纯 PowerShell 进程内运行（不派生外部子进程），支持离线词库/句库、SAPI 语音朗读、响应式双栏/单栏工作区、CJK 精确增量渲染、鼠标点击交互、错题本、本地文本导入与 AI 词库生成。

## 特性

- **零外部进程依赖**：纯 PowerShell + Windows `SAPI.SpVoice` 语音 + 系统内置 `winsqlite3.dll` 本地 SQLite 持久化。
- **14 套内置离线词库与句库**：
  - 单词：`xiaoxue6`（小学）、`zhongkao`（中考）、`ket2021`、`pet2024`、`gaokao3500`、`cet4`、`cet6`、`ielts`
  - 句子：`nce1`–`nce4`（新概念 1-4）、`ielts900`（雅思口语 900 句）、`s4000`（4000 核心例句）
- **跟打 / 听写双模式**：听写模式下隐藏英文拼写，仅在拼错时自动收录至错题本（不泄露答案）。
- **增量行级渲染 & 鼠标交互**：自适应终端宽高，支持顶栏/底栏/队列鼠标点击。

## 快速开始

```powershell
# 直接运行
.\yanxing.ps1

# 查看帮助或内置词库列表
.\yanxing.ps1 -Help
.\yanxing.ps1 -List

# 指定词库、分组与听写模式
.\yanxing.ps1 -b ket2021 -g 1 -d

# 导入本地文本（支持纯英文文章或 "英文|中文" 每行一条）
.\yanxing.ps1 -f .\article.txt
```

如需在任意终端直接输入 `yanxing` 启动，可将仓库目录加入用户 `Path` 环境变量。

## 快捷键

| 按键 | 功能 |
| --- | --- |
| `F1` / `Ctrl+B` | 切换词库 / 句库 |
| `F2` / `Ctrl+G` | 切换分组 |
| `F3` / `Ctrl+M` | 切换跟打 / 听写模式 |
| `F4` / `Ctrl+V` | 语音开关 |
| `F5` | 错题本练习 |
| `F6` | 乱序当前组 |
| `Ctrl+L` | 导入本地 `.txt` 文本 |
| `Ctrl+A` | AI 生成自定义词库 |
| `Enter` | 重听当前发音 |
| `Tab` | 显隐拼写提示 |
| `PgUp` / `PgDn` | 上一条 / 下一条 |
| `Esc` / `Ctrl+C` | 退出 |
