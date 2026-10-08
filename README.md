# IntelliText macOS

一个面向 macOS 的英文智能输入法：在本地运行轻量 LLM，在用户打字时提供语法纠错、当前句改写和短提示，同时尽量保持低延迟、低内存和隐私优先。

> 当前版本是产品与技术大纲（v0.1），用于确定边界和分块开发顺序。第一阶段先实现“纠错 + 简短提醒”，再逐步加入更像 Copilot 的辅助能力。

## 目标

- 只处理英文，默认不上传任何输入内容。
- 纠错应该是可控的：用户决定何时开启、何时应用，不自动吞掉原文。
- 在 M4 Pro / 16 GB MacBook 上长期运行，目标额外常驻内存约 1.5-3 GB（取决于模型），空闲时释放推理资源。
- 把输入法作为主入口，但将模型服务、编辑上下文和 UI 解耦，便于替换模型和测试。

## 核心交互设计

### 1. 三种工作模式

| 模式 | 触发方式 | 行为 | 是否修改原文 |
| --- | --- | --- | --- |
| **Auto Correct** | 开关打开后，输入标点、空格或短暂停顿时 | 只修正高置信度的拼写、标点和明显语法错误 | 默认不直接替换；显示可接受的 inline 建议 |
| **Current Sentence** | `⌥⌘Enter`（可配置） | 读取光标所在句子，只给这一句一个修正版和简短原因 | 用户按 `Tab`/按钮应用 |
| **Assist** | `⌥⌘Space`（可配置）或停顿后出现 | 给出一句很短的续写/措辞提示，类似 Copilot 的候选，不主动完成长段落 | 用户明确选择才插入 |

所有快捷键都可在设置中修改；全局总开关关闭后不监听文本内容。

### 2. “只改当前句子”的边界

应用层维护光标位置、当前输入框的文本快照和句子边界。调用模型时只发送：

1. 当前句子；
2. 少量前文（默认最多 1 句，仅用于代词和时态判断）；
3. 光标所在位置和语言约束。

模型返回结构化结果：`original`、`replacement`、`change_type`、`confidence`、`short_note`。应用时通过输入法候选提交或 Accessibility API 精确替换当前句，避免改动前面的内容。

### 3. 长时间停顿

停顿不是立即弹窗的理由。默认等待 1.5 秒，并且只在句子长度达到最小阈值后显示一个很小的提示标记：

- “Need a phrase?”：只在用户主动按 Assist 快捷键后请求生成；
- “Polish sentence”：点击或按 `⌥⌘Enter` 后请求当前句改写；
- 用户继续输入时，提示自动消失。

这样可以区分“我在思考”与“请帮我写”，减少干扰。

### 4. 不会某个中文词时怎么办

输入法保持英文主模式，但支持轻量的中英混输标记。例如：

```text
is it possible to write a 输入法 app on mac that can automatically correct my grammatical mistakes automatically while inputing?
```

当检测到非英文片段时，第一阶段只做两件事：

- 将它标记为待确认 token，不擅自猜测；
- 用户按 Assist 后，给出最多 3 个英文候选（这里可能是 `input method`），并显示一句完整英文修正版。

用户选中候选才插入。后续可以增加“解释/翻译”动作，但不把翻译能力混入自动纠错路径。

## 技术方案

### 模型选择（MVP）

默认模型选用 **Qwen3-4B-Instruct-2507，Q4 量化**，通过 `llama.cpp` 或 MLX 运行。Qwen 官方模型卡将它定位为 4B 参数的指令模型，支持较长上下文，并强调多语言理解与偏好对齐；对本项目的英文纠错、商务邮件润色和中英混输候选比较合适。[模型卡](https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507)

16 GB Mac 不应在输入法进程内加载大模型。量化后的 4B 模型作为独立推理服务按需加载，目标常驻内存约 2.5-4 GB；空闲自动卸载。若设备温度、延迟或内存压力不理想，fallback 为 Qwen3-1.7B/1.5B 级别模型，牺牲一部分措辞质量换取更低资源占用。

Gemma 3 4B IT 是第二候选：官方资料显示它面向受限资源设备并支持多语言，但 Gemma 许可和分发条款需要在打包前单独审查。[Gemma 模型卡](https://huggingface.co/google/gemma-3-4b-pt)

模型不会单独“保证”地道和优雅。质量控制由四层共同完成：

1. 场景 preset：`casual`、`business_email`、`professional`、`academic`；用户可手动切换。
2. 明确要求“保持原意、只返回 JSON、禁止添加事实”，并校验 `replacement` 和 `confidence`。
3. 高置信度才显示 Auto Correct；低置信度只给候选，不自动替换。
4. 用真实英文回放集评估语法、语气、过度改写率、延迟和内存，而不是只看模型排行榜。

开发顺序是 **InputMethodKit 闭环优先，模型第二**：先用 mock 推理器完成输入、当前句边界、候选、应用和撤销；之后替换 `InferenceProvider` 实现接入 Q4 模型。这样模型质量问题不会掩盖输入法层的光标和文本替换问题。

### 输入法层

- Swift + SwiftUI 设置界面。
- macOS `InputMethodKit` 实现真正的输入法扩展与候选提交。
- 使用 `NSTextInputClient` 能力读取选区、提交候选和维护 marked text。
- 对无法完整配合 InputMethodKit 的第三方 App，提供经过用户授权的 Accessibility fallback；只在快捷键触发时读取必要文本。
- 全局快捷键使用 Carbon/HID 级注册方案，并提供冲突检测。

### 本地模型层

- 首选 `llama.cpp`/MLX Swift 封装，使用 Metal 加速和 4-bit GGUF 或 MLX 量化模型。
- MVP 选择 1.5B-3B 指令模型，限制上下文长度（约 1-2K tokens），避免为纠错加载大模型。
- 推理服务为独立进程/actor：串行请求、超时取消、闲置卸载、模型版本可替换。
- 纠错任务使用严格 JSON schema；解析失败时不修改用户文本。
- 将“规则检查”（双空格、常见拼写、标点）放在模型之前，能规则解决的请求不启动 LLM。

### 隐私与安全

- 默认完全离线；不记录原文和模型请求。
- 日志只保留耗时、错误码和内存指标，明确排除文本内容。
- Accessibility 权限、输入法权限和模型目录权限在首次运行时逐项解释。
- 设置中提供“一键暂停”和“删除本地模型/缓存”。

## 分块开发计划

### Phase 0：骨架与可观测性

- 建立 Xcode 工程、InputMethodKit target、设置窗口和状态栏菜单。
- 定义 `TextContext`、`CorrectionRequest`、`CorrectionResponse` 数据结构。
- 加入内存、延迟、取消率指标（不采集文本）。

### Phase 1：纠错 + 简短提醒（首个可用版本）

- 英文句子切分、当前句定位和高置信度规则纠错。
- 接入一个量化 1.5B-3B 本地模型。
- 实现 Auto Correct、Current Sentence 两个模式。
- 候选预览、应用/撤销、快捷键配置。

### Phase 2：停顿辅助与 Assist

- 1.5 秒停顿检测和非打扰提示。
- `⌥⌘Space` 触发短语候选，限制为 3 个、每个不超过一句。
- 用户选择后再提交，不自动生成长文本。

### Phase 3：混输与质量迭代

- 非英文 token 检测、英文候选和上下文一致性检查。
- 个人词典、忽略规则和按 App 的开关。
- 基于匿名本地统计的延迟/采纳率调优（默认不启用内容上传）。

## MVP 验收标准

- 在 TextEdit、Safari 文本框、邮件编辑器中能启用/停用输入法。
- 当前句纠错不会改变前一句或光标前无关文本。
- 从触发到候选出现的 P95 延迟目标低于 800 ms（规则路径低于 50 ms）。
- 量化模型加载后常驻内存目标低于 3 GB，空闲自动卸载。
- 所有修改都可预览、应用、撤销；模型异常时原文保持不变。
- 全程离线运行，断网不影响核心功能。

## 当前初版验收路径

已实现并验证：

- 规则路径自动修正常见英文拼写、重复空格和句首大小写；
- `business_email` 场景会展开 `can't` / `don't` 等缩写；
- 从光标所在位置计算当前句，只对该句做 document-relative 替换；
- 输入法菜单提供 `Polish Current Sentence`，快捷键为 `⌥⌘` 加菜单指定按键；
- 最近一次 IntelliText 修改可用 `⌥⇧⌘Z` 撤销；
- 4 个 Swift 单元测试通过，input method bundle 构建、签名和当前用户安装均通过。

验收步骤：

1. 运行 `./Scripts/build-and-install-input-method.sh`，在系统设置中加入 IntelliText。
2. 打开 TextEdit，输入 `this is inputing  text.`，从输入法菜单选择 **Polish Current Sentence**。
3. 预期结果是 `This is inputting text.`；选择 **Undo IntelliText Correction** 应恢复原句。

当前初版已包含真实本地 LLM；流式候选窗口、停顿触发和 Assist 续写仍在后续迭代。

## 目录规划（初版）

```text
IntelliText macOS/
├── App/                    # 菜单栏应用、设置、权限引导
├── InputMethod/            # InputMethodKit extension、候选 UI
├── Core/                   # TextContext、句子边界、编辑事务
├── Inference/              # 本地模型适配器、队列、JSON schema
├── Rules/                  # 低成本拼写/标点/格式规则
├── Tests/                  # 单元测试、录制文本回放、性能测试
└── README.md
```

## 关键设计决策

1. **先建议后替换**：自动纠错只处理高置信度问题，任何不确定结果都变成候选。
2. **当前句优先**：默认上下文很小，避免误改前文，也控制模型内存和延迟。
3. **规则与模型分层**：常见问题不必调用 LLM；模型用于语法、措辞和上下文。
4. **本地优先且可降级**：模型不可用时仍可使用规则纠错和普通输入法。
5. **短输出**：Assist 只提供短候选，不默认替用户写整段内容。

## 下一步

1. 完成 Assist 候选窗口，用于不会表达的中文词或短语。
2. 建立 100 条英文纠错回放集和内存/延迟基线。
3. 根据真实使用数据调整停顿阈值、置信度阈值和候选文案。

## 构建与安装 InputMethodKit

先运行测试，再构建 input source bundle：

```bash
swift test
./Scripts/build-and-install-input-method.sh
```

脚本会构建并安装 `.build/input-method/IntelliText.app` 到当前用户的 `~/Library/Input Methods/IntelliText.app`。然后在「系统设置 → 键盘 → 文本输入 → 编辑」中加入 IntelliText；删除该目录即可卸载。当前 bundle 使用 ad-hoc signing，正式分发前需要 Developer ID 签名和 notarization。

## 本地 LLM（M4 Pro / 24 GB）

初版主模型为 **Qwen3-8B Q4_K_M**（GGUF，约 5.03 GB），运行时使用 `llama.cpp` Metal backend，context 限制为 4096 tokens，并只监听 `127.0.0.1:11439`。输入法启动时会尝试自动启动 `llama-server`；必须先安装 `llama.cpp` 并把模型放到项目的：

```text
Models/Qwen3-8B-Q4_K_M.gguf
```

安装依赖：

```bash
brew install llama.cpp
```

模型权重不进入 Git（`.gitignore` 已排除 `Models/*.gguf`）。初版使用 Qwen3-8B 普通指令模型的 Q4_K_M 量化，提示中禁用 thinking 模式，并要求返回受校验的 JSON；未启动本地服务时不发送到任何云端，文本保持原样。写作场景可在 IntelliText 输入法菜单的 **Writing Style** 下选择 Daily Conversation、Business Email、Professional 或 Academic。

## 不会说某个词时的方案

例如你输入：

```text
Is it possible to write a 输入法 app on Mac?
```

不要让 Auto Correct 猜测并直接改写。正确的交互是：

1. 用户按 **Assist** 快捷键（规划为 `⌥⌘Space`），或从菜单选择 **Find English Phrase**。
2. 输入法只读取当前句，识别 `输入法` 这个非英文 token，并保留原文位置。
3. 本地模型返回最多 3 个候选，例如 `input method`、`keyboard input method`、`text input app`，同时给出一条完整句修正版。
4. 候选窗口显示“原词 → 英文候选”和简短解释；用户按数字键/方向键选择后才替换，按 `Esc` 保持原文。

这样“不会表达”与“语法错误”是两个动作：自动纠错不会擅自翻译，Assist 也不会生成整段内容。当前仓库已经有本地 LLM provider 和场景 preset；候选窗口与 Assist 提交动作是下一项开发内容。

可选的本地模型集成测试（需先安装模型并确保输入法已启动本地 server）：

```bash
INTELLITEXT_LLM_INTEGRATION=1 swift test --filter LocalLLMIntegrationTests
```

## License

License will be selected before the first distributable release.
