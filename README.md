# yanxing（言行 CLI）

**中文** | [English](README_en.md)

一个轻量级、零外部进程依赖的 Windows 终端英文打字与听写 TUI 工具：

-   双栏 / 单栏响应式工作区（宽度 `>= 80` 列显示练习卡 + 队列，`< 80` 列自动折叠为单栏）；
-   跟打与听写双模式（听写模式隐藏英文拼写，仅听写错误才收录错题本且不泄露答案）；
-   CJK 精确列宽计算与行级增量 diff 渲染；
-   SGR 鼠标点击支持（顶栏、底栏、弹窗列表、右侧队列均可直接点击）；
-   内置 14 套离线单词/句子库、本地 `.txt` 导入与 AI 生成词库。

它以单个纯 PowerShell 脚本发行，不派生 `node.exe` / `python.exe` 等子进程，进程内调用 Windows `SAPI.SpVoice` 朗读与系统内置 `winsqlite3.dll` 持久化进度和错题本。

## Files

```
yanxing/
├── yanxing.ps1       主程序与全部 TUI 源码（纯 PowerShell，单文件零依赖）
├── install.ps1       一键安装 / 卸载脚本（自动注册用户 PATH）
├── dicts/            14 套离线词库与句库 JSON（小学/中考/KET/PET/高考/四六级/雅思/新概念1-4/900句/4000句）
├── README.md         中文文档
├── README_en.md      English documentation
└── LICENSE           MIT License
```

## Quick start

### 一键安装（推荐，自动注册 PATH）

在 PowerShell 中运行：

```powershell
irm https://raw.githubusercontent.com/buer5/yanxing/main/install.ps1 | iex
```

安装完成后即可在任意终端直接输入 `yanxing` 启动。如需卸载：

```powershell
& "$env:USERPROFILE\.yanxing\bin\yanxing.ps1" -Help
irm https://raw.githubusercontent.com/buer5/yanxing/main/install.ps1 -OutFile $env:TEMP\yx-uninst.ps1; & $env:TEMP\yx-uninst.ps1 -Uninstall
```

### 本地安装或直接运行

```powershell
git clone https://github.com/buer5/yanxing.git
cd yanxing

# 安装到 %USERPROFILE%\.yanxing\bin 并自动注册用户 PATH
.\install.ps1

# 或免安装直接运行源码
.\yanxing.ps1
```

### 常用命令行参数

```powershell
yanxing -List                  # 列出所有内置词库与句库
yanxing -b ket2021 -g 1        # 指定词库与分组
yanxing -b nce2 -d             # 以听写模式练习新概念 2 句子库
yanxing -f .\notes.txt         # 导入本地文本（支持纯英文文章或 "英文|中文" 每行一条）
yanxing -m                     # 静音模式启动
```

## Layout & Rendering

-   **`>= 80` 列（宽屏）**：左侧主练习卡片（进度条、目标词句、音标、中文释义、上一条/下一条中文预览）+ 右侧当前分组队列（支持鼠标点击跳词）。
-   **`< 80` 列（窄屏 / 分屏）**：自动隐藏右侧队列，顶栏与底栏按钮自动折行，确保小窗口下按钮与内容不被截断。
-   **增量行缓冲渲染**：每行按 CJK 显示列宽定宽填充，逐行对比 `PrevLines` 仅覆写变化行，避免全屏清屏闪烁。
-   **本地数据存储**：通过系统内置 `winsqlite3.dll` 写入 `%USERPROFILE%\.yanxing\yanxing.db`（`user_setting` 表）。

## Shortcuts

| 按键 | 鼠标操作 | 功能 |
| --- | --- | --- |
| `F1` / `Ctrl+B` | 点击顶栏 `[F1 词库:...]` | 切换词库 / 句库 |
| `F2` / `Ctrl+G` | 点击顶栏 `[F2 组:...]` | 切换分组 |
| `F3` / `Ctrl+M` | 点击顶栏 `[F3 跟打/听写]` | 切换跟打 / 听写模式 |
| `F4` / `Ctrl+V` | 点击顶栏 `[F4 音:...]` | 语音朗读开关 |
| `F5` | 点击顶栏 `[F5 错:...]` | 进入错题本练习 |
| `F6` | 点击底栏 `[F6 乱序]` | 随机打乱当前组顺序 |
| `Ctrl+L` | 点击底栏 `[Ctrl+L 导入]` | 导入本地 `.txt` 文本 |
| `Ctrl+A` | 点击底栏 `[Ctrl+A AI]` | 调用 OpenAI 兼容接口生成词库 |
| `Enter` | 点击底栏 `[Enter 朗读]` | 重听当前发音 |
| `Tab` | 点击底栏 `[Tab 提示]` | 听写模式下临时显隐拼写 |
| `PgUp` / `PgDn` | 点击底栏 `[PgUp 上词]` / `[PgDn 下词]` | 切换上一条 / 下一条 |
| `Esc` / `Ctrl+C` | 点击底栏 `[Esc 退出]` | 关闭弹窗或退出 |

## Built-in Decks

| ID | 类型 | 名称 |
| --- | --- | --- |
| `xiaoxue6` | 单词 | 小学英语 (PEP) |
| `zhongkao` | 单词 | 初中 / 中考核心 |
| `ket2021` | 单词 | 剑桥 KET (2021) |
| `pet2024` | 单词 | 剑桥 PET (2024) |
| `gaokao3500` | 单词 | 高考 3500 词 |
| `cet4` | 单词 | 大学四级 CET-4 |
| `cet6` | 单词 | 大学六级 CET-6 |
| `ielts` | 单词 | 雅思 IELTS |
| `nce1` – `nce4` | 句子 | 新概念 1–4 句子库 |
| `ielts900` | 句子 | 雅思口语 900 句 |
| `s4000` | 句子 | 4000 核心例句库 |

## License

MIT; see [LICENSE](LICENSE).
