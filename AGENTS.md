# tuidotapp

Native macOS host for installed terminal applications.

## Product invariants

- Never copy or embed a user's TUI executable. Resolve and launch the installed command at runtime.
- Start the user's login shell before injecting the configured command so Homebrew, mise, asdf, aliases, and shell startup files work normally.
- Render terminals with Ghostty. Do not replace the terminal with a text console or pipe-based process view.
- SSH uses the user's OpenSSH binary, agent, and `~/.ssh/config`.
- Ghostty configuration is passthrough. Unknown config keys must not be discarded.
- Never silently sandbox a launched command. Sandboxing may only be explicit and visible.

## Development

```bash
swift test
swift run tuidotapp
./scripts/build-app.sh
```

Use Swift 6 concurrency checks. Keep command construction pure and covered by tests.
