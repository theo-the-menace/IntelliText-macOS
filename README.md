# IntelliText macOS

IntelliText is a local English writing assistant for macOS. The project is moving toward a separate floating input box that stays above other apps, reads only the text placed in that box, and shows short English suggestions without acting as a system input method.

The reusable correction engine and local Qwen integration remain in this repository. The former macOS InputMethodKit implementation has been removed. No input source is registered, installed, or able to intercept system keyboard events.

## Local model

Place `Qwen3-8B-Q4_K_M.gguf` in `Models/`. The model is ignored by Git because it is several gigabytes. The future floating app will use a local `llama-server` OpenAI-compatible endpoint.

## Development

```sh
swift test
```

The next milestone is a standalone macOS app with a small floating text box, a configurable shortcut, English-only sentence context, short advice-only hints, and an explicit action to apply a suggestion. It will never rewrite text automatically while the user is typing.
