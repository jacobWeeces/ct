#!/usr/bin/env bash
# test_ct.sh - Test suite for ct (tmux backend)

CT_BIN="./ct"
FAILURES=0
TEST_SESSION_NAME="ct-test-$$"

# Cleanup function to ensure test sessions are removed
cleanup() {
    tmux kill-session -t "ct-${TEST_SESSION_NAME}" 2>/dev/null || true
}

trap cleanup EXIT

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

test_list_format() {
    echo -n "Test: --list shows 'ct sessions:' format... "
    output=$($CT_BIN --list 2>&1)
    if echo "$output" | grep -q "ct sessions:"; then
        echo "PASS"
    else
        echo "FAIL (output: $output)"
        ((FAILURES++))
    fi
}

test_kill_nonexistent() {
    echo -n "Test: -k nonexistent returns error... "
    if ! $CT_BIN -k "nonexistent-session-$$" >/dev/null 2>&1; then
        echo "PASS"
    else
        echo "FAIL"
        ((FAILURES++))
    fi
}

test_session_lifecycle() {
    echo -n "Test: session creation, listing, and killing... "

    # Create a session (detached)
    if ! tmux -f "${HOME}/.ct/tmux.conf" new-session -d -s "ct-${TEST_SESSION_NAME}" 2>/dev/null; then
        echo "FAIL (could not create session)"
        ((FAILURES++))
        return
    fi

    # Check if it appears in ct -l
    if ! $CT_BIN -l 2>&1 | grep -q "$TEST_SESSION_NAME"; then
        echo "FAIL (session not listed)"
        ((FAILURES++))
        tmux kill-session -t "ct-${TEST_SESSION_NAME}" 2>/dev/null || true
        return
    fi

    # Kill the session using ct
    if ! $CT_BIN -k "$TEST_SESSION_NAME" >/dev/null 2>&1; then
        echo "FAIL (could not kill session)"
        ((FAILURES++))
        tmux kill-session -t "ct-${TEST_SESSION_NAME}" 2>/dev/null || true
        return
    fi

    # Verify it's gone
    if $CT_BIN -l 2>&1 | grep -q "$TEST_SESSION_NAME"; then
        echo "FAIL (session still listed after kill)"
        ((FAILURES++))
        tmux kill-session -t "ct-${TEST_SESSION_NAME}" 2>/dev/null || true
        return
    fi

    echo "PASS"
}

test_unknown_option() {
    echo -n "Test: unknown option returns error... "
    if ! $CT_BIN --invalid-option >/dev/null 2>&1; then
        echo "PASS"
    else
        echo "FAIL"
        ((FAILURES++))
    fi
}

# Run tests
echo "Running ct test suite..."
echo ""
test_help
test_no_args
test_list_format
test_kill_nonexistent
test_session_lifecycle
test_unknown_option

echo ""
if [[ $FAILURES -eq 0 ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "$FAILURES test(s) failed"
    exit 1
fi
