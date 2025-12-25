# ConnectTerm (ct)

A reliable terminal session manager that uses `tmux` as a backend to provide seamless reconnection from mobile terminals like Termius.

## The Problem This Solves

> **Note:** ct originally used `dtach` as its backend but has been migrated to `tmux` to fix terminal freezing issues with tools like Claude Code. If you have existing dtach-based ct sessions, they will not work with the new tmux backend. Use `ct -x` to clean up old sessions if needed.

When using terminal tools like Claude Code through mobile terminals (like Termius), raw `dtach` sessions experience:
- Terminal freezes requiring session kills
- Visual corruption from escape sequence handling
- Device Attributes responses (`[?6c`) causing PTY issues

**ConnectTerm solves this** by:
1. Using tmux's robust terminal emulator to handle escape sequences properly
2. Providing a simple interface without requiring tmux knowledge
3. Maintaining scrollback, mouse support, and system clipboard integration
4. Making detached sessions just work across disconnections

---

## Quick Start

```bash
# Install
git clone https://github.com/jacobWeeces/ct.git
cd ct
./install.sh

# Add to PATH (add this to ~/.zshrc for persistence)
export PATH="${HOME}/.local/bin:${PATH}"

# Use it
ct example          # Create or attach to 'example' session
# Press Ctrl+\ to detach (session keeps running)
ct example          # Reattach anytime
ct -l                # List all sessions
ct -k example       # Kill a session
```

---

## Commands Reference

| Command | Description |
|---------|-------------|
| `ct <name>` | Attach to session `<name>`, or create it if it doesn't exist |
| `ct -l` or `ct --list` | List all sessions with their status |
| `ct -k <name>` or `ct --kill <name>` | Kill a specific session |
| `ct -x` or `ct --killall` | Kill all ct-managed sessions |
| `ct -h` or `ct --help` | Show help |

---

## Session States

When you run `ct --list`, you'll see all active ct-managed tmux sessions. Sessions are either:

- **ALIVE**: Session is running and can be attached to
- **DEAD**: Session has terminated (will be cleaned up automatically)

tmux handles session lifecycle internally, so there's no manual cleanup needed for zombie or orphaned processes.

---

## How It Works

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Terminal (Termius)                    │
│                              │                               │
│                              ▼                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                    ct (wrapper)                      │    │
│  │  - Simple interface to tmux                          │    │
│  │  - Session name mapping (work → ct-work)             │    │
│  │  - Auto-generates tmux config                        │    │
│  └─────────────────────────────────────────────────────┘    │
│                              │                               │
│                              ▼                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                  tmux (server)                       │    │
│  │  - Terminal emulator & session manager               │    │
│  │  - Handles escape sequences properly                 │    │
│  │  - Mouse support, scrollback, clipboard              │    │
│  │  - Survives terminal close                           │    │
│  └─────────────────────────────────────────────────────┘    │
│                              │                               │
│                              ▼                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                     Shell (zsh)                      │    │
│  │  - Your actual terminal session                      │    │
│  │  - Scrollback, history, etc.                         │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### File Structure

```
~/.ct/                          # ct configuration directory
└── tmux.conf                 # Auto-generated tmux configuration
```

Sessions are managed entirely by tmux's internal server - no socket or PID files needed.

### Key Difference from Raw tmux

| Behavior | Raw tmux | ct |
|----------|----------|-----|
| Session creation | `tmux new -s name` | `ct name` |
| List sessions | `tmux ls` | `ct -l` |
| Kill session | `tmux kill-session -t name` | `ct -k name` |
| Configuration | Manual ~/.tmux.conf | Auto-generated in ~/.ct/ |
| Learning curve | Requires prefix key knowledge | No tmux knowledge needed |
| Detach key | Ctrl+B then D | Ctrl+\ (familiar to dtach users) |

---

## Under the Hood

### tmux Configuration

ct auto-generates a tmux configuration file at `~/.ct/tmux.conf` with settings optimized for simplicity:

```bash
set -g mouse on                    # Scroll/click works
set -g history-limit 50000         # Large scrollback
set -g set-clipboard on            # System clipboard integration
set -g status off                  # No status bar (clean interface)
set -g escape-time 0               # No Escape key delay
set -g default-terminal "xterm-256color"  # Full color support
```

The detach key is configured to `Ctrl+\` to match dtach behavior, so existing muscle memory works.

### Session Management

ct prefixes all session names with `ct-` to avoid collision with existing tmux sessions:
- `ct work` creates/attaches to `ct-work` tmux session
- `ct -l` shows only `ct-*` prefixed sessions
- `ct -k work` kills the `ct-work` session

This means you can use tmux directly for other purposes without interfering with ct-managed sessions.

### Attach-or-Create Flow

```
ct <session>
    │
    ├─► Check if tmux session "ct-<session>" exists
    │       │
    │       ├─► EXISTS → tmux attach -t ct-<session>
    │       │
    │       └─► MISSING → tmux new -s ct-<session>
    │
    └─► tmux handles all session lifecycle
```

---

## Usage with Termius

### Recommended Workflow

1. **SSH into your Mac** from Termius

2. **Start a session:**
   ```bash
   ct example
   ```

3. **Work in your terminal** - run commands, edit files, etc.

4. **When done**, either:
   - **Detach** with `Ctrl+\` (session keeps running, you can reconnect)
   - **Just close Termius** (session keeps running thanks to signal handling)

5. **Later, reconnect** from anywhere:
   ```bash
   ct example    # Right back where you left off
   ```

### Pro Tips

- **Named sessions**: Use descriptive names like `ct dev`, `ct logs`, `ct deploy`
- **Check status**: Run `ct -l` to see what's running before connecting
- **Fresh start**: If something's weird, `ct -k <name>` then `ct <name>` gives a clean slate

---

## Comparison with Alternatives

| Tool | Pros | Cons |
|------|------|------|
| **dtach** (raw) | Simple, lightweight | Zombie issues, no session management |
| **tmux** | Feature-rich, stable | Heavy, different UX, overkill for simple use |
| **screen** | Battle-tested | Old, complex commands |
| **abduco** | Modern dtach alternative | Same zombie issues on macOS |
| **ct** | Simple, reliable, tmux-powered without complexity | Requires tmux |

---

## Troubleshooting

### "ct: command not found"

Add to your PATH:
```bash
export PATH="${HOME}/.local/bin:${PATH}"
```

Add this line to `~/.zshrc` to make it permanent.

### I want to use a different shell

Edit the ct script and change:
```bash
DEFAULT_SHELL="${SHELL:-/bin/zsh}"
```

Or set the SHELL environment variable.

### tmux shows "sessions should be nested with care"

If you see this warning, you're trying to run tmux inside a tmux session. This is usually not what you want. Either:
- Detach from the current session with `Ctrl+\`
- Use a different session name

### Old dtach sessions not working

ct migrated from dtach to tmux. Old dtach-based sessions are incompatible. To clean them up:

```bash
ct -x   # Kill all ct-managed sessions
rm -rf ~/.ct/*.sock ~/.ct/*.pid   # Remove old dtach files
```

---

## Technical Details

### Files

| File | Purpose |
|------|---------|
| `~/.local/bin/ct` | The installed script |
| `~/.ct/tmux.conf` | Auto-generated tmux configuration |

### Dependencies

- **tmux** - Terminal multiplexer and session manager
  - Location: `/opt/homebrew/bin/tmux` (Apple Silicon) or `/usr/local/bin/tmux` (Intel)
  - Install: `brew install tmux`

### Key tmux Features Used

| Feature | Purpose |
|---------|---------|
| `new -A -s <name>` | Attach to session or create if missing |
| `has-session -t <name>` | Check if session exists |
| `list-sessions` | Show all active sessions |
| `kill-session -t <name>` | Terminate specific session |

### Key Bindings

| Key | Action |
|-----|--------|
| Ctrl+\ | Detach from session (customized) |
| Ctrl+C | Passed through to shell |
| Mouse scroll | Scroll through terminal history |
| Mouse select | Copy to system clipboard |

---

## Development

### Running Tests

```bash
cd /Users/jacobweeces/Documents/connectTerm
./test_ct.sh
```

### Project Structure

```
/Users/jacobweeces/Documents/connectTerm/
├── ct                 # Main script
├── test_ct.sh         # Test suite
├── install.sh         # Installation script
├── README.md          # This file
└── docs/
    └── plans/
        ├── 2024-12-19-connectterm-wrapper-design.md
        ├── 2024-12-19-connectterm-implementation.md
        └── 2025-12-23-tmux-migration-design.md
```

### Contributing

The code is well-documented. Key functions:

| Function | Purpose |
|----------|---------|
| `ensure_tmux_config()` | Generate tmux configuration if needed |
| `session_exists()` | Check if tmux session exists |
| `list_sessions()` | Display all ct-managed sessions |
| `kill_session()` | Terminate specific session |
| `kill_all_sessions()` | Clean all ct sessions |
| `attach_or_create()` | The main attach-or-create logic |

---

## License

Personal use. Created to provide reliable terminal sessions for Termius access.

---

## Acknowledgments

Built with the help of Claude (Anthropic) using the Superpowers workflow:
- Brainstorming → Design → Plan → Execute → Review

Originally implemented with dtach backend, migrated to tmux to fix terminal freezing issues with Claude Code and other terminal-intensive tools.

The implementation follows test-driven development principles with code review after each task.
