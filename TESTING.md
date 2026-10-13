# Testing IntelliText

Run the core tests from the project directory:

```sh
swift test
```

Build and launch the floating app from the project directory:

```sh
./Scripts/build-and-run.sh
```

If IntelliText is already open, quit it with `⌘Q` before rebuilding and launching again. Resize it by dragging any edge or corner; use the green window button or `Control-⌘-F` for full screen.

The app opens a floating window with its own text editor. Daily conversation is selected by default. Type a sentence and pause briefly, or press Check (`⌘⇧R`). The app displays one native polished version and a short English teaching tip explaining the native phrase, word choice, and grammar. Text changes only when you click **Use polished version**. Try the style menu to compare the four writing styles.

The app needs `Models/Qwen3-8B-Q4_K_M.gguf` and `llama-server` from `brew install llama.cpp`. The model runs locally. There is no InputMethodKit bundle or system input-source installation step. This first version does not yet paste text back into the app you were using or provide a configurable system-wide shortcut.

Optional real-model integration test:

```sh
INTELLITEXT_LLM_INTEGRATION=1 swift test --filter LocalLLMIntegrationTests
```
