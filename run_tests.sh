#!/bin/bash
# run_tests.sh <student_repo_path>
# Outputs a JSON result to stdout.

STUDENT_DIR="$1"
TEACHER_DIR="$(cd "$(dirname "$0")" && pwd)"
TESTS_DIR="$TEACHER_DIR/tests"
COMPILE_TIMEOUT=15   # seconds to validate syntax
TEST_TIMEOUT=5       # seconds per test

# ── Helpers ────────────────────────────────────────────────────────────────

results_json=""

add_result() {
    local name="$1" status="$2" message="$3" elapsed="$4"
    # Escape double quotes in message
    message="${message//\"/\\\"}"
    local entry="{\"name\":\"$name\",\"status\":\"$status\",\"message\":\"$message\",\"execution_time_ms\":$elapsed}"
    if [ -z "$results_json" ]; then
        results_json="$entry"
    else
        results_json="$results_json,$entry"
    fi
}

run_with_timeout() {
    local seconds="$1"
    shift

    if command -v timeout >/dev/null 2>&1; then
        timeout "$seconds" "$@"
        return $?
    fi

    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$seconds" "$@"
        return $?
    fi

    # Portable fallback when timeout/gtimeout is unavailable (e.g., macOS).
    python3 -c '
import subprocess
import sys

timeout_s = float(sys.argv[1])
cmd = sys.argv[2:]

try:
    completed = subprocess.run(
        cmd,
        stdin=sys.stdin.buffer,
        stdout=sys.stdout.buffer,
        stderr=sys.stderr.buffer,
        timeout=timeout_s,
        check=False,
    )
    sys.exit(completed.returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)
except FileNotFoundError:
    sys.exit(127)
' "$seconds" "$@"
}

emit() {
    local overall_status="$1" message="$2"
    printf '{"status":"%s","message":"%s","tests":[%s]}\n' \
        "$overall_status" "$message" "$results_json"
}

# ── 1. Validate student repo ───────────────────────────────────────────────

if [ -z "$STUDENT_DIR" ]; then
    emit "ERROR" "No student repo path provided"
    exit 0
fi

if [ ! -f "$STUDENT_DIR/main.py" ]; then
    emit "ERROR" "main.py not found in student repo"
    exit 0
fi

# ── 2. Validate Python syntax ──────────────────────────────────────────────

syntax_output=$(run_with_timeout $COMPILE_TIMEOUT python3 -m py_compile "$STUDENT_DIR/main.py" 2>&1)
syntax_exit=$?

if [ $syntax_exit -eq 124 ]; then
    emit "ERROR" "Python syntax check timed out after ${COMPILE_TIMEOUT}s"
    exit 0
fi

if [ $syntax_exit -ne 0 ]; then
    # Escape newlines in syntax output for JSON
    syntax_output="${syntax_output//$'\n'/ | }"
    syntax_output="${syntax_output//\"/\\\"}"
    emit "ERROR" "Python syntax check failed: $syntax_output"
    exit 0
fi

# ── 3. Run tests ───────────────────────────────────────────────────────────

passed=0
total=0

for test_dir in "$TESTS_DIR"/*/; do
    [ -d "$test_dir" ] || continue

    test_name="$(basename "$test_dir")"
    input_file="$test_dir/input.txt"
    expected_file="$test_dir/expected.txt"
    total=$((total + 1))

    # Measure time in ms
    start_ns=$(date +%s%N)

    actual=$(run_with_timeout $TEST_TIMEOUT python3 "$STUDENT_DIR/main.py" < "$input_file" 2>/dev/null)
    run_exit=$?

    end_ns=$(date +%s%N)
    elapsed=$(( (end_ns - start_ns) / 1000000 ))

    if [ $run_exit -eq 124 ]; then
        add_result "$test_name" "FAILED" "Timeout after ${TEST_TIMEOUT}s" "$elapsed"
        continue
    fi

    if [ $run_exit -ne 0 ]; then
        add_result "$test_name" "FAILED" "Runtime error (exit code $run_exit)" "$elapsed"
        continue
    fi

    expected="$(cat "$expected_file")"

    if [ "$actual" = "$expected" ]; then
        passed=$((passed + 1))
        add_result "$test_name" "PASSED" "" "$elapsed"
    else
        # Show first differing line as hint
        actual_line=$(echo "$actual"   | head -1)
        expect_line=$(echo "$expected" | head -1)
        msg="First line — expected: '$expect_line' got: '$actual_line'"
        add_result "$test_name" "FAILED" "$msg" "$elapsed"
    fi
done

# ── 4. Emit final result ───────────────────────────────────────────────────

if [ $passed -eq $total ]; then
    emit "SUCCESS" ""
else
    emit "FAILURE" "$passed/$total tests passed"
fi
