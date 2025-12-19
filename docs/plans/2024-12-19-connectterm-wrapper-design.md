# ConnectTerm (ct) - Reliable Terminal Session Manager

## Problem Statement

dtach leaves zombie processes when terminals are closed on macOS. These zombies:
- Consume 100% CPU indefinitely
- Corrupt socket state
- Cause new sessions to show blank screens
- Require manual cleanup (`pkill`, `rm` sockets)

## Solution

A wrapper script `ct` that:
1. Automatically cleans up zombies before operations
2. Provides simple attach-or-create semantics
3. Handles signals properly to prevent zombie creation
4. Offers session management commands

## User Interface

```bash
ct <session>          # Attach or create session
ct -l, ct --list      # List all sessions with health status
ct -k, ct --kill <s>  # Kill specific session cleanly
ct -x, ct --killall   # Nuclear: kill all sessions and zombies
ct -h, ct --help      # Show help
```

## Implementation Details

### Session Management

- Sessions stored in `~/.ct/` (separate from ~/.dtach to avoid conflicts)
- Each session has: `<name>.sock` (socket), `<name>.pid` (master PID)
- PID file enables reliable zombie detection

### Zombie Detection & Cleanup

Before any operation:
1. Read PID from `<session>.pid` if exists
2. Check if process is alive AND responsive
3. Check if socket is valid (not stale)
4. If zombie detected: kill process tree, remove socket and PID file

### Signal Handling

Trap these signals in the wrapper:
- `SIGHUP` - Terminal hangup (closed window)
- `SIGTERM` - Termination request
- `SIGINT` - Ctrl+C (pass through to dtach)

On hangup/term: clean detach, don't kill session

### Health Check (`ct -l`)

For each session directory entry:
- Check PID file exists and process is alive
- Check socket exists and is connectable
- Report: `session_name: ALIVE | DEAD | ZOMBIE`

### Attach-or-Create Flow

```
ct <session>
    │
    ├─► Session exists and healthy?
    │       YES ──► dtach -a (attach)
    │       NO  ──► cleanup if needed, dtach -A (create)
    │
    └─► Register signal handlers
        └─► exec dtach with proper options
```

## Technical Decisions

- **Shell:** Bash (universally available, sufficient for this)
- **dtach options:** `-A` for create, `-a` for attach, `-r winch` for redraw
- **Default shell:** `$SHELL` or `/bin/zsh`
- **Detach key:** Keep default `^\` (Ctrl+\)

## File Structure

```
~/.ct/
├── voicebox.sock    # Unix domain socket
├── voicebox.pid     # Master dtach PID
├── work.sock
├── work.pid
└── ...
```

## Success Criteria

1. `ct voicebox` works reliably every time
2. Closing terminal window does NOT create zombies
3. Reconnecting from Termius works seamlessly
4. `ct -l` accurately shows session health
5. No manual cleanup ever needed
