# Testing IntelliText

Run the core tests from the project directory:

```sh
swift test
```

Build and launch the floating app from the project directory:

```sh
./Scripts/build-and-run.sh
```

The app opens a floating window with its own text editor. Type a sentence and pause briefly, or press Check (`⌘⇧R`). Advice is shown in English and does not change the text unless you click **Apply suggestion**. Try the style menu to compare Professional, Daily conversation, Business email, and Academic suggestions.

The app needs `Models/Qwen3-8B-Q4_K_M.gguf` and `llama-server` from `brew install llama.cpp`. The model runs locally. There is no InputMethodKit bundle or system input-source installation step. This first version does not yet paste text back into the app you were using or provide a configurable system-wide shortcut.

Optional real-model integration test:

```sh
INTELLITEXT_LLM_INTEGRATION=1 swift test --filter LocalLLMIntegrationTests
```
