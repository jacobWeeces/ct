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

# Run tests
test_help
test_no_args
test_status_missing

echo ""
if [[ $FAILURES -eq 0 ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "$FAILURES test(s) failed"
    exit 1
fi
