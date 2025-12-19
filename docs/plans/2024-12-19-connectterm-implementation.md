# ConnectTerm (ct) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a reliable terminal session wrapper that prevents dtach zombie processes and provides simple session management.

**Architecture:** Single bash script with functions for cleanup, health checks, attach/create logic, and signal handling. Uses PID files alongside sockets to track session health. Traps signals to ensure clean detachment on terminal close.

**Tech Stack:** Bash, dtach, Unix signals, Unix domain sockets

---

## Task 1: Create Project Structure and Base Script

**Files:**
- Create: `/Users/jacobweeces/Documents/connectTerm/ct`
- Create: `/Users/jacobweeces/Documents/connectTerm/test_ct.sh`

**Step 1: Create the base script with help function**

```bash
#!/usr/bin/env bash
set -euo pipefail

CT_DIR="${HOME}/.ct"
DTACH_BIN="/opt/homebrew/bin/dtach"
DEFAULT_SHELL="${SHELL:-/bin/zsh}"

usage() {
    cat <<EOF
ct - ConnectTerm: Reliable terminal session manager

Usage:
    ct <session>            Attach or create session
    ct -l, --list           List all sessions with status
    ct -k, --kill <name>    Kill specific session
    ct -x, --killall        Kill all sessions and zombies
    ct -h, --help           Show this help

Examples:
    ct work                 Start or attach to 'work' session
    ct -l                   Show all sessions
    ct -k work              Kill 'work' session
EOF
}

# Ensure CT_DIR exists
mkdir -p "$CT_DIR"

# Main entry point (to be expanded)
main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Not yet implemented"
            exit 1
            ;;
    esac
}

main "$@"
```

**Step 2: Make script executable and verify help works**

Run:
```bash
chmod +x /Users/jacobweeces/Documents/connectTerm/ct
/Users/jacobweeces/Documents/connectTerm/ct --help
```

Expected: Help text displays correctly

**Step 3: Create basic test script**

```bash
#!/usr/bin/env bash
# test_ct.sh - Basic tests for ct

CT_BIN="./ct"
FAILURES=0

test_help() {
    echo -n "Test: --help shows usage... "
    if $CT_BIN --help 2>&1 | grep -q "ConnectTerm"; then
        echo "PASS"
    else
        echo "FAIL"
        ((FAILURES++))
    fi
}

test_no_args() {
    echo -n "Test: no args shows usage and exits 1... "
    if ! $CT_BIN >/dev/null 2>&1; then
        echo "PASS"
    else
        echo "FAIL"
        ((FAILURES++))
    fi
}

# Run tests
test_help
test_no_args

echo ""
if [[ $FAILURES -eq 0 ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "$FAILURES test(s) failed"
    exit 1
fi
```

**Step 4: Run tests to verify base works**

Run:
```bash
chmod +x /Users/jacobweeces/Documents/connectTerm/test_ct.sh
cd /Users/jacobweeces/Documents/connectTerm && ./test_ct.sh
```

Expected: "All tests passed!"

**Step 5: Commit**

```bash
cd /Users/jacobweeces/Documents/connectTerm
git init
git add ct test_ct.sh
git commit -m "feat: add base ct script with help"
```

---

## Task 2: Add Zombie Detection Functions

**Files:**
- Modify: `/Users/jacobweeces/Documents/connectTerm/ct`

**Step 1: Add is_process_alive function after DEFAULT_SHELL line**

```bash
# Check if a process is alive and not a zombie
is_process_alive() {
    local pid="$1"
    if [[ -z "$pid" ]]; then
        return 1
    fi
    # Check process exists and is not zombie (state Z)
    if ps -p "$pid" -o state= 2>/dev/null | grep -qv "Z"; then
        return 0
    fi
    return 1
}
```

**Step 2: Add is_process_healthy function (checks CPU isn't runaway)**

```bash
# Check if process is healthy (not spinning at 100% CPU for too long)
is_process_healthy() {
    local pid="$1"
    if ! is_process_alive "$pid"; then
        return 1
    fi
    # Get CPU percentage - if over 90% it's likely a zombie spinning
    local cpu
    cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' | cut -d. -f1)
    if [[ -n "$cpu" && "$cpu" -gt 90 ]]; then
        # Check if it's been running a long time (over 10 min of CPU time)
        local cputime
        cputime=$(ps -p "$pid" -o cputime= 2>/dev/null | tr -d ' ')
        if [[ -n "$cputime" ]]; then
            # Parse MM:SS or HH:MM:SS format
            local minutes
            minutes=$(echo "$cputime" | awk -F: '{if(NF==2) print $1; else print $1*60+$2}')
            if [[ "$minutes" -gt 10 ]]; then
                return 1  # Unhealthy - spinning too long
            fi
        fi
    fi
    return 0
}
```

**Step 3: Add get_session_status function**

```bash
# Get status of a session: ALIVE, DEAD, ZOMBIE, or MISSING
get_session_status() {
    local name="$1"
    local sock_file="${CT_DIR}/${name}.sock"
    local pid_file="${CT_DIR}/${name}.pid"

    if [[ ! -e "$sock_file" && ! -e "$pid_file" ]]; then
        echo "MISSING"
        return
    fi

    if [[ ! -e "$pid_file" ]]; then
        echo "DEAD"  # Socket exists but no PID file
        return
    fi

    local pid
    pid=$(cat "$pid_file" 2>/dev/null)

    if ! is_process_alive "$pid"; then
        echo "DEAD"
        return
    fi

    if ! is_process_healthy "$pid"; then
        echo "ZOMBIE"
        return
    fi

    echo "ALIVE"
}
```

**Step 4: Add test for status detection**

Add to test_ct.sh before "# Run tests":

```bash
test_status_missing() {
    echo -n "Test: missing session returns MISSING... "
    # Source the functions
    source ./ct --source-only 2>/dev/null || true
    CT_DIR="/tmp/ct_test_$$"
    mkdir -p "$CT_DIR"
    local status
    status=$(get_session_status "nonexistent")
    rm -rf "$CT_DIR"
    if [[ "$status" == "MISSING" ]]; then
        echo "PASS"
    else
        echo "FAIL (got: $status)"
        ((FAILURES++))
    fi
}
```

**Step 5: Add --source-only flag to ct for testing**

Add before `main "$@"`:

```bash
# Allow sourcing for tests
if [[ "${1:-}" == "--source-only" ]]; then
    return 0 2>/dev/null || exit 0
fi
```

**Step 6: Run tests**

Run:
```bash
cd /Users/jacobweeces/Documents/connectTerm && ./test_ct.sh
```

Expected: All tests pass

**Step 7: Commit**

```bash
git add ct test_ct.sh
git commit -m "feat: add zombie detection functions"
```

---

## Task 3: Add Session Cleanup Function

**Files:**
- Modify: `/Users/jacobweeces/Documents/connectTerm/ct`

**Step 1: Add cleanup_session function after get_session_status**

```bash
# Clean up a session (kill process, remove files)
cleanup_session() {
    local name="$1"
    local sock_file="${CT_DIR}/${name}.sock"
    local pid_file="${CT_DIR}/${name}.pid"

    if [[ -e "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null)
        if [[ -n "$pid" ]] && is_process_alive "$pid"; then
            # Kill the process tree
            pkill -TERM -P "$pid" 2>/dev/null || true
            kill -TERM "$pid" 2>/dev/null || true
            sleep 0.2
            # Force kill if still alive
            if is_process_alive "$pid"; then
                pkill -KILL -P "$pid" 2>/dev/null || true
                kill -KILL "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$pid_file"
    fi

    rm -f "$sock_file"
}
```

**Step 2: Add cleanup_all function**

```bash
# Clean up all ct-managed sessions ONLY (never touches ~/.dtach/)
cleanup_all() {
    echo "Cleaning up all ct sessions in ${CT_DIR}..."
    echo "(Your ~/.dtach/ sessions are untouched)"
    echo ""

    # ONLY clean up sessions WE manage (in ~/.ct/)
    local cleaned=0
    for pid_file in "${CT_DIR}"/*.pid; do
        [[ -e "$pid_file" ]] || continue
        local name
        name=$(basename "$pid_file" .pid)
        echo "  Cleaning: $name"
        cleanup_session "$name"
        ((cleaned++))
    done

    # Only kill dtach processes pointing to OUR directory, not ~/.dtach/
    pkill -9 -f "dtach.*\.ct/" 2>/dev/null || true

    # Clean up stale socket files in OUR directory only
    rm -f "${CT_DIR}"/*.sock 2>/dev/null || true

    if [[ $cleaned -eq 0 ]]; then
        echo "  (no ct sessions to clean)"
    fi
    echo ""
    echo "Done. Your ~/.dtach/ sessions were NOT touched."
}
```

**Step 3: Wire up --killall in main()**

Update the case statement in main():

```bash
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -x|--killall)
            cleanup_all
            exit 0
            ;;
        -k|--kill)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --kill requires a session name"
                exit 1
            fi
            cleanup_session "$2"
            echo "Session '$2' killed."
            exit 0
            ;;
        *)
            echo "Not yet implemented"
            exit 1
            ;;
    esac
```

**Step 4: Add test for cleanup**

Add to test_ct.sh:

```bash
test_killall() {
    echo -n "Test: --killall runs without error... "
    if $CT_BIN --killall >/dev/null 2>&1; then
        echo "PASS"
    else
        echo "FAIL"
        ((FAILURES++))
    fi
}
```

And add `test_killall` to the test run section.

**Step 5: Run tests**

Run:
```bash
cd /Users/jacobweeces/Documents/connectTerm && ./test_ct.sh
```

Expected: All tests pass

**Step 6: Commit**

```bash
git add ct test_ct.sh
git commit -m "feat: add session cleanup functions"
```

---

## Task 4: Add List Sessions Function

**Files:**
- Modify: `/Users/jacobweeces/Documents/connectTerm/ct`

**Step 1: Add list_sessions function after cleanup_all**

```bash
# List all sessions with their status
list_sessions() {
    echo "Sessions in ${CT_DIR}:"
    echo ""

    local found=0
    for sock_file in "${CT_DIR}"/*.sock; do
        [[ -e "$sock_file" ]] || continue
        found=1
        local name
        name=$(basename "$sock_file" .sock)
        local status
        status=$(get_session_status "$name")
        local pid=""
        if [[ -e "${CT_DIR}/${name}.pid" ]]; then
            pid=$(cat "${CT_DIR}/${name}.pid" 2>/dev/null)
        fi

        case "$status" in
            ALIVE)  printf "  %-20s %s (pid: %s)\n" "$name" "✓ ALIVE" "$pid" ;;
            DEAD)   printf "  %-20s %s\n" "$name" "✗ DEAD (needs cleanup)" ;;
            ZOMBIE) printf "  %-20s %s (pid: %s)\n" "$name" "⚠ ZOMBIE (will auto-clean)" "$pid" ;;
        esac
    done

    # Also check for PID files without sockets
    for pid_file in "${CT_DIR}"/*.pid; do
        [[ -e "$pid_file" ]] || continue
        local name
        name=$(basename "$pid_file" .pid)
        [[ -e "${CT_DIR}/${name}.sock" ]] && continue  # Already handled
        found=1
        printf "  %-20s %s\n" "$name" "✗ ORPHAN (no socket)"
    done

    if [[ $found -eq 0 ]]; then
        echo "  (no sessions)"
    fi
    echo ""
}
```

**Step 2: Wire up --list in main()**

Add to case statement after --killall:

```bash
        -l|--list)
            list_sessions
            exit 0
            ;;
```

**Step 3: Add test for list**

Add to test_ct.sh:

```bash
test_list() {
    echo -n "Test: --list runs without error... "
    if $CT_BIN --list 2>&1 | grep -q "Sessions in"; then
        echo "PASS"
    else
        echo "FAIL"
        ((FAILURES++))
    fi
}
```

Add `test_list` to test run section.

**Step 4: Run tests**

Run:
```bash
cd /Users/jacobweeces/Documents/connectTerm && ./test_ct.sh
```

Expected: All tests pass

**Step 5: Commit**

```bash
git add ct test_ct.sh
git commit -m "feat: add session listing with status"
```

---

## Task 5: Add Attach-or-Create Logic

**Files:**
- Modify: `/Users/jacobweeces/Documents/connectTerm/ct`

**Step 1: Add start_session function**

```bash
# Start or attach to a session
start_session() {
    local name="$1"
    local sock_file="${CT_DIR}/${name}.sock"
    local pid_file="${CT_DIR}/${name}.pid"

    # Check current status
    local status
    status=$(get_session_status "$name")

    case "$status" in
        ZOMBIE|DEAD)
            echo "Cleaning up stale session '$name'..."
            cleanup_session "$name"
            status="MISSING"
            ;;
    esac

    if [[ "$status" == "ALIVE" ]]; then
        echo "Attaching to existing session '$name'..."
        exec "$DTACH_BIN" -a "$sock_file" -r winch
    else
        echo "Creating new session '$name'..."
        # Start dtach and capture its PID
        "$DTACH_BIN" -n "$sock_file" -r winch "$DEFAULT_SHELL"

        # Find the dtach master process and save PID
        sleep 0.3
        local pid
        pid=$(pgrep -f "dtach -n ${sock_file}" | head -1)
        if [[ -n "$pid" ]]; then
            echo "$pid" > "$pid_file"
        fi

        # Now attach
        exec "$DTACH_BIN" -a "$sock_file" -r winch
    fi
}
```

**Step 2: Update main() to handle session name**

Replace the `*)` case in main():

```bash
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            start_session "$1"
            ;;
```

**Step 3: Manual test - create and attach to session**

Run:
```bash
cd /Users/jacobweeces/Documents/connectTerm
./ct testsession
# Should create and attach
# Press Ctrl+\ to detach
./ct --list
# Should show testsession as ALIVE
./ct testsession
# Should reattach
# Ctrl+\ to detach
./ct --kill testsession
./ct --list
# Should show no sessions
```

**Step 4: Commit**

```bash
git add ct
git commit -m "feat: add attach-or-create session logic"
```

---

## Task 6: Add Signal Handling for Clean Detach

**Files:**
- Modify: `/Users/jacobweeces/Documents/connectTerm/ct`

**Step 1: Add signal handler setup function before start_session**

```bash
# Setup signal handlers for clean detachment
setup_signal_handlers() {
    local name="$1"

    # On SIGHUP (terminal closed), just exit cleanly
    # The dtach master process keeps running
    trap 'exit 0' HUP

    # On SIGTERM, exit cleanly
    trap 'exit 0' TERM
}
```

**Step 2: Update start_session to use signal handlers**

Add after the `local status` line:

```bash
    # Setup handlers before attaching
    setup_signal_handlers "$name"
```

**Step 3: Manual test - verify terminal close doesn't create zombies**

Run:
```bash
# In Terminal, start a session
./ct signaltest

# Detach with Ctrl+\
# Close the terminal window completely
# Open new terminal
cd /Users/jacobweeces/Documents/connectTerm
./ct --list
# signaltest should show ALIVE, not ZOMBIE

# Clean up
./ct --kill signaltest
```

**Step 4: Commit**

```bash
git add ct
git commit -m "feat: add signal handling for clean detach"
```

---

## Task 7: Add Installation Script

**Files:**
- Create: `/Users/jacobweeces/Documents/connectTerm/install.sh`

**Step 1: Create install script**

```bash
#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing ct to ${INSTALL_DIR}..."

# Create install directory if needed
mkdir -p "$INSTALL_DIR"

# Copy script
cp "${SCRIPT_DIR}/ct" "${INSTALL_DIR}/ct"
chmod +x "${INSTALL_DIR}/ct"

# Create session directory
mkdir -p "${HOME}/.ct"

echo "Done!"
echo ""
echo "Make sure ${INSTALL_DIR} is in your PATH."
echo "Add to ~/.zshrc if needed:"
echo "    export PATH=\"\${HOME}/.local/bin:\${PATH}\""
echo ""
echo "Usage: ct <session-name>"
```

**Step 2: Make executable**

Run:
```bash
chmod +x /Users/jacobweeces/Documents/connectTerm/install.sh
```

**Step 3: Commit**

```bash
git add install.sh
git commit -m "feat: add installation script"
```

---

## Task 8: Clean Up YOUR Zombies (Surgically) and Test Full Flow

**Step 1: Identify and kill only the zombie processes (not your good ones)**

First, identify which processes are zombies (100% CPU, running for hours):
```bash
ps aux | grep -E 'dtach|abduco' | grep -v grep
```

Look for processes with very high CPU% and long runtimes. Kill ONLY those specific PIDs:
```bash
# Example - replace with YOUR zombie PIDs:
# kill -9 83638 6705 84657 7147 28018
```

Do NOT run `pkill -9 -f dtach` - that would kill your good sessions too.

**Step 2: Install ct**

Run:
```bash
cd /Users/jacobweeces/Documents/connectTerm
./install.sh
export PATH="${HOME}/.local/bin:${PATH}"
```

**Step 3: Full integration test**

Run:
```bash
# Create a session
ct voicebox

# Inside session, run a command to prove it works
echo "Hello from voicebox"

# Detach with Ctrl+\

# Check status
ct --list
# Should show: voicebox ✓ ALIVE

# Reattach
ct voicebox

# Detach again Ctrl+\

# Simulate terminal close by killing the attach process
# (this mimics what Termius does when you close the app)

# Check no zombies
ps aux | grep -E 'dtach|ct' | grep -v grep

# ct voicebox should still work
ct voicebox

# Clean up
ct --kill voicebox
ct --list
```

**Step 4: Commit final state**

```bash
git add -A
git commit -m "feat: complete ct implementation - ready for use"
```

---

## Summary

After completing all tasks, you will have:

1. `ct` - A reliable terminal session manager
2. Automatic zombie detection and cleanup
3. Simple `ct <name>` interface
4. Session status listing with `ct -l`
5. Clean signal handling to prevent zombie creation
6. Installation script for easy setup

**Usage from Termius:**
1. SSH into your Mac
2. Run `ct voicebox` (or any session name)
3. Work in your terminal
4. Close Termius whenever - session stays alive
5. Reconnect and run `ct voicebox` again - right back where you were
