# IntelliText 初版测试

## 首次安装

模型已放在项目 `Models/Qwen3-8B-Q4_K_M.gguf`（约 5GB）。先安装本地运行时并重建输入法：

```bash
brew install llama.cpp
./Scripts/build-and-install-input-method.sh
```

然后打开「系统设置 → 键盘 → 文本输入 → 编辑」，添加 **IntelliText**。如果之前已添加过，先移除再重新添加。

## 测试纠错

1. 打开 TextEdit，新建文稿。
2. 从菜单栏输入法菜单切换到 **IntelliText**。
3. 直接输入：

   ```text
   She go to the office yesterday.
   ```

4. 停止输入约 1–2 秒，预期句子自动变为：

   ```text
   She went to the office yesterday.
   ```

5. 如需撤销，打开输入法菜单，选择 **Undo IntelliText Correction**。

当前自动检查是防抖触发：暂停输入约 1.2 秒后才调用本地模型，不会每个字符都调用模型。
也可以从输入法菜单手动选择 **Polish Current Sentence** 立即重试。

## 不会某个英文词时

当前版本的自动纠错不会擅自翻译中文词。目标交互是按 Assist 后显示最多 3 个英文候选，用户选择后才插入；候选窗口尚在开发中。

## 测试场景风格

在 IntelliText 菜单的 **Writing Style** 中切换 **Daily Conversation** 或 **Business Email**，再用 Polish Current Sentence 处理一句话，对比语气。快捷键撤销为 `⌥⇧⌘Z`。

## 如果没有反应

- 确认 `llama.cpp` 已安装：`brew list --versions llama.cpp`
- 确认模型文件在 `Models/Qwen3-8B-Q4_K_M.gguf`
- 重启 IntelliText 输入法，等待模型启动（首次加载可能需要一会儿）
- 查看服务状态：`curl http://127.0.0.1:11439/health`，正常应返回 `{"status":"ok"}`
- 当前只对支持 macOS 文本输入上下文的应用有效；先用 TextEdit 验收。
