# 语言输入法 · LanguageInput

一个用 **Swift / SwiftUI / AppKit / InputMethodKit** 写的 macOS 拼音输入法，思路参考开源项目
[青简 Qingjian](https://github.com/qingjian-team/qingjian)：**照常打字，候选词旁多一条正在学的语言的译词**，
把日常打字变成顺带的语言学习。译词永远只是辅助信息，不会替换你要输入的文字。

> 这是独立的 Swift 实现，没有使用原项目的源代码，与原项目及其作者无隶属关系。
> 原项目的名称与标志不在其代码许可之内，本项目也没有使用它们。

## 功能

| 功能 | 说明 |
| --- | --- |
| 拼音输入 | 全拼、简拼（`nh` → 你好）、整句输入（`jintiantianqihenhao`）、隔音符（`xi'an`） |
| 整句解码 | 一元模型 + 维特比，停顿前就给出整句候选；`gn`/`ng` 笔误自动修正 |
| 双拼 | 小鹤双拼 |
| 候选译词 | 每个候选后面跟一条小号译词；英文离线可用，日/西/越/德可接入你自己的 AI 服务 |
| 输入习惯学习 | 你选过的词会逐渐靠前，数据只存本机 |
| 本地统计 | 今天 / 最近 7 天 / 累计字数，7 天柱状图（SwiftUI Charts） |
| 词汇本 | 自动记录出现过译词的词，可标记"已掌握"、搜索、导出 CSV（可导入 Anki） |
| 中英切换 | 单击 Shift；输入法菜单里也可切换 |
| 隐私 | 全部本机处理；输入记录默认关闭且独立于统计；AI 译词默认关闭 |

### 按键

- 空格：上屏高亮候选　·　`1`–`9`：选词　·　`↑↓←→`：移动高亮
- `-` `=` 或 `,` `.`、PageUp/PageDown、Tab：翻页
- Return：把已输入的字母原样上屏　·　Esc：取消　·　Delete：退格
- 选中一个较短的候选后，剩余拼音会继续留在输入框里接着选

## 安装

需要 macOS 13 或更高版本，以及 Xcode 或 Command Line Tools（`xcode-select --install`）。

```bash
unzip LanguageInput.zip && cd LanguageInput
./build.sh        # 编译、打包 LanguageInput.app（会尝试联网生成完整词库）
./install.sh      # 安装到 ~/Library/Input Methods 并登记
```

然后：**系统设置 ▸ 键盘 ▸ 文字输入 ▸ 输入法 ▸ 编辑… ▸ ＋ ▸ 简体中文 ▸ 语言输入法**。
第一次安装后如果列表里没出现，注销并重新登录一次即可（这是 macOS 对新输入法的通用要求）。

设置窗口：切到语言输入法 后点菜单栏的输入法图标 ▸「语言输入法 设置…」，或运行
`open ~/Library/Input\ Methods/LanguageInput.app`。

卸载：`./uninstall.sh`（加 `--purge` 同时删除统计、词汇本、输入习惯与保存的密钥）。

### build.sh 的环境变量

| 变量 | 作用 |
| --- | --- |
| `ARCHS="arm64 x86_64"` | 构建通用二进制（默认只构建本机架构） |
| `SIGN_ID="Developer ID Application: …"` | 用指定证书签名（默认临时签名） |
| `FULL_LEXICON=0` | 不联网，直接使用随包的小词库 |

## 词库

随包附带一份**手写的小词库**（约 1500 条，`Resources/lexicon.tsv`），只用来开箱即用和测试，
词量有限，不够日常使用。**请务必生成完整词库**：

```bash
python3 tools/build_lexicon.py          # 仅需 Python 3 标准库与网络
./build.sh                              # build.sh 检测到 data/ 下的完整词库会自动使用
```

生成脚本会下载并合并：

- [jieba](https://github.com/fxsjy/jieba) 的词频表（MIT）→ 词与词频
- [CC-CEDICT](https://www.mdbg.net/chinese/dictionary?page=cedict) 汉英词典（CC BY-SA 4.0）→ 拼音读音与英文译词

输出 `data/lexicon.full.tsv`（约 10 万词）与 `data/gloss_en.full.tsv`。
若 `build.sh` 联网失败会自动退回小词库；你也可以离线使用本地文件：
`python3 tools/build_lexicon.py --jieba dict.txt --cedict cedict_1_0_ts_utf-8_mdbg.u8`。

### 自定义词

把文件放进 `~/Library/Application Support/LanguageInput/`：

- `lexicon.user.tsv`：追加自定义词，每行 `拼音<Tab>词<Tab>频次`，例如 `qing jian<Tab>青简<Tab>5000`
- `lexicon.tsv` / `gloss_en.tsv`：整体覆盖随包词库与译词（无需重新编译）

修改后重新切换输入法（或注销重登）生效。

## 其它语言的译词

设置 ▸ 学习 里选择正在学的语言。英文译词完全离线；日语、西班牙语、越南语、德语需要你启用
「AI 译词」并填写自己的 OpenAI 兼容接口、模型与 API Key（保存在系统钥匙串）。
启用后只会把**当前页的候选词本身**（不含上下文）发给你配置的服务，结果缓存在本机。默认关闭。

## 数据与隐私

所有数据都在 `~/Library/Application Support/LanguageInput/`：

| 文件 | 内容 |
| --- | --- |
| `stats.json` | 每日字数、累计字数、词汇本 |
| `user-model.json` | 你选过的词的次数（用于排序） |
| `gloss-cache.json` | AI 译词缓存 |
| `input-log.jsonl` | 输入记录（仅在你主动开启时才写入） |

设置 ▸ 隐私与关于 里可以逐项清除。程序不需要账号，不会自动联网，没有任何遥测。

## 项目结构

```
Sources/
  main.swift                 入口，创建 IMKServer
  AppDelegate.swift          启动预热、设置窗口
  InputController.swift      IMKInputController：按键、预编辑、上屏、Shift 切换
  Engine.swift               维特比整句解码、简拼、候选排序
  InputConversion.swift      原始按键 → 拼音字母（全拼 / 小鹤双拼）
  Lexicon.swift              词库加载与索引
  GlossService.swift         译词（离线英文 + 可选 AI）
  UserModel.swift            本机输入习惯
  StatsStore.swift           统计、词汇本、输入记录
  CandidatePanel.swift       SwiftUI 候选窗（NSPanel 承载）
  SettingsView.swift         SwiftUI 设置：通用 / 学习 / 统计 / 词汇本 / 隐私
  Preferences.swift          偏好键与默认值
  Storage.swift              本地存储与钥匙串
  InputSourceRegistration.swift  --register：登记并启用输入源
Resources/                   Info.plist、本地化、小词库
tools/                       词库生成、图标生成
build.sh / install.sh / uninstall.sh
```

## 排错

- **列表里找不到输入法**：注销并重新登录；确认 `~/Library/Input Methods/LanguageInput.app` 存在。
- **按键没反应 / 想看日志**：终端里 `pkill LanguageInput` 后重新切换输入法；
  或直接运行 `~/Library/Input\ Methods/LanguageInput.app/Contents/MacOS/LanguageInput` 观察输出。
- **候选窗位置不准**：个别应用不提供光标矩形，此时会退回到鼠标位置附近。
- **某些应用里没有候选译词**：译词只在候选窗里显示，与目标应用无关；检查 设置 ▸ 学习 是否开启。
- **安全输入**（密码框）下 macOS 会自动切回系统键盘，这是系统行为。

## 从旧名称升级

项目早期名为 QingjianSwift。`./install.sh` 会自动移除旧的 `QingjianSwift.app`，首次运行时会把
`~/Library/Application Support/QingjianSwift/` 里的统计与词汇本迁移到新目录。
旧版保存在钥匙串里的 AI 密钥不会迁移，请在 设置 ▸ 学习 里重新填写；
系统设置的输入法列表里旧条目需要手动删除，再添加「语言输入法」。

## 已知限制

- 还没有 Windows / Linux / Android 版，也没有云端整句预测、五笔、自动纠错之外的拼写纠正。
- 小词库很小；整句质量取决于你生成的完整词库（一元模型，没有上下文 n-gram）。
- 默认使用临时（ad-hoc）签名，仅限本机使用；分发给他人需要 Developer ID 签名与公证。

## 许可

MIT，见 `LICENSE`。生成词库时使用的 jieba（MIT）与 CC-CEDICT（CC BY-SA 4.0）各有其许可，
如果你分发生成后的词库，请保留相应署名。
