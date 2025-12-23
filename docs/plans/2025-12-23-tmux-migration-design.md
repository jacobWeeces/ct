# ct tmux Migration Design

**Date:** 2025-12-23
**Status:** Approved
**Backup:** `v1.0-dtach` tag on GitHub

## Problem

When using Claude Code through Termius via ct/dtach, Device Attributes (DA) responses (`[?6c`) cause:
1. Visual noise - sequences displayed as text
2. Terminal freeze - PTY becomes completely unresponsive, requiring session kill

The freeze is unpredictable and affects both Mac and Termius sides. Root cause: dtach's simple PTY pass-through can't handle the escape sequence volume from Claude Code's Ink/React terminal UI.

## Solution

Replace dtach with tmux as the session backend. tmux has its own internal terminal emulator that interprets escape sequences rather than passing them through raw.

## Architecture

```
Before (dtach):
Termius ──▶ dtach (pass-thru) ──▶ shell
                 ▲
            PTY corrupts here

After (tmux):
Termius ──▶ tmux (interprets & buffers) ──▶ shell
                 ▲
            Escape sequences handled properly
```

## User Experience

**No change to commands:**
- `ct work` - create/attach session
- `ct -l` - list sessions
- `ct -k work` - kill session

**No tmux learning required:**
- Scroll with finger/mouse (just works)
- Copy/paste works with system clipboard
- No Ctrl+B prefix commands
- `Ctrl+\` to detach (same as dtach)

## tmux Configuration

Embedded in ct, making tmux invisible:

```
set -g mouse on              # Scroll/click works
set -g history-limit 50000   # Large scrollback
set -g set-clipboard on      # System clipboard
set -g status off            # No status bar
set -g escape-time 0         # No Escape delay
set -g default-terminal "xterm-256color"
```

Detach key configured to `Ctrl+\` to match dtach behavior.

## Session Management

**Naming:** `ct work` creates tmux session `ct-work` (prefixed to avoid collision)

**Detection:** Query tmux directly (`tmux has-session -t ct-work`) instead of socket/PID files

**File structure:**
```
~/.ct/
└── tmux.conf    # Generated config
```

## Code Simplification

**Removing (no longer needed):**
- `is_process_alive()` - tmux handles this
- `is_process_healthy()` - no zombie detection needed
- `attach_with_filter()` - no reset hacks
- `reset_session()` - tmux handles escape sequences
- PID file tracking

**Keeping:**
- Same CLI interface
- Same `~/.ct/` directory
- Clean error messages

## Command Mapping

| ct command | tmux equivalent |
|------------|-----------------|
| `ct work` | `tmux new -A -s ct-work` |
| `ct -l` | `tmux list-sessions` (filtered) |
| `ct -k work` | `tmux kill-session -t ct-work` |

## Error Handling

- Check tmux installed on first run
- Don't touch existing dtach sessions
- Provide `ct --cleanup-legacy` for old files

## Rollback

If tmux doesn't solve the issue:
```bash
git checkout v1.0-dtach
./install.sh
```
