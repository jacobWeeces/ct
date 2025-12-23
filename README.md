# ConnectTerm (ct)

A reliable terminal session manager that wraps `dtach` to prevent zombie processes and provide seamless reconnection from mobile terminals like Termius.

## The Problem This Solves

> **Note:** This behavior has been observed specifically on **macOS with Apple Silicon** when using `dtach` with mobile terminal apps like Termius. I haven't tested dtach on other platforms, and this issue may be specific to this environment. dtach is a great tool - this wrapper just adds some extra safeguards for my particular use case.

When using `dtach` directly on my setup, closing a terminal window (especially from mobile apps like Termius) sometimes leaves behind **zombie processes** that:
- Spin at 100% CPU indefinitely
- Corrupt socket state
- Cause new sessions to show blank screens with just a cursor
- Require manual cleanup (`pkill`, removing socket files)

**ConnectTerm fixes this** by:
1. Properly handling terminal close signals (HUP, TERM)
2. Automatically detecting and cleaning up zombie/dead sessions
3. Tracking session health via PID files
4. Providing a simple, reliable interface

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
| `ct -x` or `ct --killall` | Kill all ct-managed sessions (safe for ~/.dtach/) |
| `ct -h` or `ct --help` | Show help |

---

## Session States

When you run `ct --list`, sessions can have these states:

| State | Symbol | Meaning |
|-------|--------|---------|
| ALIVE | ✓ | Session is running and healthy |
| DEAD | ✗ | Socket exists but process is gone (will auto-clean on next attach) |
| ZOMBIE | ⚠ | Process exists but is spinning at 100% CPU (will auto-clean) |
| ORPHAN | ✗ | PID file exists but socket is missing |

**Auto-cleanup**: When you run `ct <name>` on a DEAD or ZOMBIE session, it automatically cleans up before creating a fresh session.

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
│  │  - Signal handling (HUP, TERM → clean exit)         │    │
│  │  - Zombie detection before attach                    │    │
│  │  - PID tracking in ~/.ct/<name>.pid                 │    │
│  └─────────────────────────────────────────────────────┘    │
│                              │                               │
│                              ▼                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                  dtach (master)                      │    │
│  │  - Manages PTY                                       │    │
│  │  - Socket at ~/.ct/<name>.sock                      │    │
│  │  - Survives terminal close                          │    │
│  └─────────────────────────────────────────────────────┘    │
│                              │                               │
│                              ▼                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                     Shell (zsh)                      │    │
│  │  - Your actual terminal session                     │    │
│  │  - Scrollback, history, etc.                        │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### File Structure

```
~/.ct/                          # ct session directory (separate from ~/.dtach/)
├── example.sock              # Unix domain socket for dtach
├── example.pid               # PID of dtach master process
├── work.sock
├── work.pid
└── ...
```

### Key Difference from Raw dtach

| Behavior | Raw dtach | ct |
|----------|-----------|-----|
| Terminal close | Often creates zombie | Clean exit, session survives |
| Dead session | Manual cleanup required | Auto-detects and cleans |
| Session tracking | Socket files only | Socket + PID files |
| Zombie detection | None | CPU% + process state monitoring |
| Your ~/.dtach/ | - | Never touched |

---

## Under the Hood

### Signal Handling

When you close your terminal (Termius disconnect, window close, etc.), the system sends a `SIGHUP` signal. Without proper handling, this can leave dtach in a bad state.

**ct handles this by:**
```bash
trap 'exit 0' HUP   # Terminal hangup → clean exit
trap 'exit 0' TERM  # Termination request → clean exit
```

The key insight: the `ct` wrapper exits cleanly, but the **dtach master process** (which manages the actual shell) continues running independently.

### Zombie Detection

A "zombie" in this context is a dtach process that's:
1. **Alive** (process exists, not in Z state)
2. **Unhealthy** (spinning at >90% CPU for >10 minutes)

The detection logic:

```bash
# Check if process is alive (not actually a Unix zombie)
is_process_alive() {
    ps -p "$pid" -o state= | grep -qv "Z"  # Not in Zombie state
}

# Check if process is healthy (not spinning)
is_process_healthy() {
    cpu=$(ps -p "$pid" -o %cpu=)
    cputime=$(ps -p "$pid" -o cputime=)
    # If >90% CPU for >10 minutes of CPU time → unhealthy
}
```

### Attach-or-Create Flow

```
ct <session>
    │
    ├─► Get session status
    │       │
    │       ├─► ALIVE → Attach to existing session
    │       │
    │       ├─► DEAD/ZOMBIE → Clean up, then create new
    │       │
    │       └─► MISSING → Create new session
    │
    └─► Setup signal handlers
        │
        └─► exec dtach (replaces ct process)
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
| **ct** | Simple, reliable, zombie-proof | Depends on dtach |

---

## Troubleshooting

### "Blank screen with just a cursor"

This was the original problem. With ct, this shouldn't happen. But if it does:

```bash
# Check what's running
ct -l

# If session shows ZOMBIE or DEAD, kill it
ct -k <session-name>

# Start fresh
ct <session-name>
```

### "ct: command not found"

Add to your PATH:
```bash
export PATH="${HOME}/.local/bin:${PATH}"
```

Add this line to `~/.zshrc` to make it permanent.

### Session shows DEAD but I just created it

The PID capture might have failed. This is rare but can happen on heavily loaded systems. The session still works - just the tracking is affected. Kill and recreate:

```bash
ct -k <name>
ct <name>
```

### I want to use a different shell

Edit the ct script and change:
```bash
DEFAULT_SHELL="${SHELL:-/bin/zsh}"
```

Or set the SHELL environment variable.

### Claude Code displays `[?6c` characters or screen corruption

When using Claude Code through Termius via ct, you may see repeated `[?6c` characters appearing, or the terminal display may become corrupted with garbage characters.

**What's happening:**
Claude Code's terminal UI (built on React/Ink) queries terminal capabilities by sending Device Attributes requests (`ESC[c`). Termius responds with `ESC[?6c` (indicating VT102 compatibility). These responses are sometimes echoed back as visible text instead of being silently consumed, and can accumulate causing display corruption.

**Solutions:**

1. **Use the `-f` flag** (recommended):
   ```bash
   ct -f <session>   # Sends terminal reset before attaching
   ```

2. **Reset without detaching** (from another terminal):
   ```bash
   ct -r <session>   # Sends reset to running session
   ```

3. **Manual reset inside the session:**
   - Press `Ctrl+L` to redraw the screen
   - Or type `reset` and press Enter for a full terminal reset

4. **Environment variable for permanent fix:**
   ```bash
   export CT_FILTER_DA=1   # Add to ~/.zshrc
   ```
   This makes ct always send a reset before attaching.

**Note:** This is a known issue with terminal capability queries through layered terminal emulators. The resets help recover from corruption but don't prevent the `[?6c` sequences entirely. If you find a better solution, please contribute!

---

## Technical Details

### Files

| File | Purpose |
|------|---------|
| `~/.local/bin/ct` | The installed script |
| `~/.ct/*.sock` | Unix domain sockets for dtach communication |
| `~/.ct/*.pid` | PID files for session tracking |

### Dependencies

- **dtach** - The underlying terminal detachment tool
  - Location: `/opt/homebrew/bin/dtach` (Apple Silicon) or `/usr/local/bin/dtach` (Intel)
  - Install: `brew install dtach`

### Key dtach Options Used

| Option | Meaning |
|--------|---------|
| `-n <socket>` | Create new session in background (no attach) |
| `-a <socket>` | Attach to existing session |
| `-A <socket>` | Attach or create (ct doesn't use this directly) |
| `-r winch` | Redraw method: send SIGWINCH on attach |

### Signal Reference

| Signal | When Sent | ct Behavior |
|--------|-----------|-------------|
| SIGHUP | Terminal closed | Exit cleanly (session survives) |
| SIGTERM | Kill request | Exit cleanly (session survives) |
| SIGINT (Ctrl+C) | User interrupt | Passed through to shell |
| Ctrl+\ | Detach key | dtach handles this |

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
├── ct                 # Main script (295 lines)
├── test_ct.sh         # Test suite
├── install.sh         # Installation script
├── README.md          # This file
└── docs/
    └── plans/
        ├── 2024-12-19-connectterm-wrapper-design.md
        └── 2024-12-19-connectterm-implementation.md
```

### Contributing

The code is well-documented. Key functions:

| Function | Purpose |
|----------|---------|
| `is_process_alive()` | Check if PID exists and isn't a zombie |
| `is_process_healthy()` | Check if process isn't spinning at 100% CPU |
| `get_session_status()` | Return ALIVE/DEAD/ZOMBIE/MISSING |
| `cleanup_session()` | Kill process and remove files for one session |
| `cleanup_all()` | Clean all ct sessions (never touches ~/.dtach/) |
| `list_sessions()` | Display all sessions with status |
| `setup_signal_handlers()` | Set up HUP/TERM traps |
| `start_session()` | The main attach-or-create logic |

---

## License

Personal use. Created to solve the dtach zombie problem for Termius access.

---

## Acknowledgments

Built with the help of Claude (Anthropic) using the Superpowers workflow:
- Brainstorming → Design → Plan → Execute → Review

The implementation follows test-driven development principles with code review after each task.
