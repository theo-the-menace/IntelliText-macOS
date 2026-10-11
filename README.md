# IntelliText macOS

IntelliText is a local English writing assistant for macOS. It is a separate floating input box that stays above other apps, reads only the text placed in that box, and shows short English suggestions without acting as a system input method.

The reusable correction engine and local Qwen integration remain in this repository. The former macOS InputMethodKit implementation has been removed. No input source is registered, installed, or able to intercept system keyboard events.

## Local model

Place `Qwen3-8B-Q4_K_M.gguf` in `Models/`. The model is ignored by Git because it is several gigabytes. IntelliText uses a local `llama-server` OpenAI-compatible endpoint and starts it when needed (install `llama.cpp` with `brew install llama.cpp`).

## Development

```sh
swift test
./Scripts/build-and-run.sh
```

The app provides a floating English writing box, style selection (Professional, Daily conversation, Business email, Academic), short advice-only hints, and an explicit action to apply a suggestion. It checks after a brief pause or with Check / `⌘⇧R`; it never rewrites text automatically. This first slice edits text in its own box; sending the finished text into other apps and a configurable global shortcut are follow-up work.
