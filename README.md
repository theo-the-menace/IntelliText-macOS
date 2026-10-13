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

To start IntelliText, open Terminal, change to this project folder, then run `./Scripts/build-and-run.sh`. The script builds the app and opens it. If it is already running, quit it first with `⌘Q` so the newly built version is launched. Drag any window edge or corner to resize; use the green window button or `Control-⌘-F` to enter or leave full screen.

The app provides a floating English writing box and style selection (Daily conversation by default, Professional, Business email, Academic). It gives one native polished version plus a short teaching explanation: why the original was unnatural, what phrase native speakers use, and why the word and grammar fit the context. The suggestion requires an explicit Apply action; text is never rewritten automatically. This first slice edits text in its own box; sending finished text into other apps and a configurable global shortcut are follow-up work.
