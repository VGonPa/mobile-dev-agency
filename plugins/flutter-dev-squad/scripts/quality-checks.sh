#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# quality-checks.sh — Quality gate for Flutter/Dart projects
# ═══════════════════════════════════════════════════════════════════════════════
#
# Part of: mobile-dev-agency / flutter-dev-squad plugin
#
# General-purpose quality tool for any Flutter project.
# Run from the project root or any subdirectory within a git repo.
# Supports local dev, git hooks, and CI/CD pipelines.
# Supports selective check execution and individual code metric analysis.
#
# Quick start:
#   ./scripts/quality-checks.sh                        # full pre-merge checks
#   ./scripts/quality-checks.sh pre-commit             # fast checks only
#   ./scripts/quality-checks.sh --only tests,metrics   # selective checks
#   ./scripts/quality-checks.sh --help                 # full documentation
#
# Exit codes:
#   0 - All critical checks passed (may have warnings)
#   1 - One or more critical checks failed
# ═══════════════════════════════════════════════════════════════════════════════

set -o pipefail

# ─── METRIC THRESHOLDS ────────────────────────────────────────────────────────
# Project "acceptable" limits. Anything above these = FAIL.
# Change these values to adjust strictness for your project.
THRESHOLD_CC=10          # Cyclomatic Complexity: grade B max (1-10 OK, 11+ fail)
THRESHOLD_NOP=4          # Number of Parameters (1-4 OK, 5+ fail)
THRESHOLD_NESTING=3      # Maximum Nesting Level (1-3 OK, 4+ fail)
# Weight of Class: informational only, no threshold
# ─── TIMEOUT SETTINGS ────────────────────────────────────────────────────────
TEST_TIMEOUT=300         # Max seconds for test suite (5 min default)
ANALYZE_TIMEOUT=120      # Max seconds for flutter analyze
METRICS_TIMEOUT=120      # Max seconds for dart_code_metrics

# ─── HELP ──────────────────────────────────────────────────────────────────────

show_help() {
    cat <<'HELP'
Usage: quality-checks.sh [MODE] [OPTIONS]

Quality gate for Flutter/Dart projects. Runs formatting, static analysis,
tests, coverage, and code metrics with configurable check selection.

MODES
  pre-commit    All checks except coverage (unit tests only, no coverage gen)
  pre-merge     Full checks: all checks including coverage
                (default when no mode is specified)

OPTIONS
  -h, --help                  Show this help message and exit
  --only CHECK[,CHECK,...]    Run only the specified checks (comma-separated)
  --skip CHECK[,CHECK,...]    Skip the specified checks (mutually exclusive with --only)
  --timeout SECONDS           Override test timeout (default: 300s)
  --paths "dir1/ dir2/"       Scope file-based checks to specific directories
  --total-shards N            Split test suite into N shards (for CI parallelism)
  --shard-index I             Run shard I of N (0-based, requires --total-shards)
  --output FORMAT             Output format: text (default) or json
  --test-dirs "dir1/ dir2/"   Run tests only in specified directories

AVAILABLE CHECKS
  format      Dart formatting (dart format --set-exit-if-changed)
  analyze     Static analysis (flutter analyze)
  tests       Run test suite (pre-commit: unit only, pre-merge: all tests)
  coverage    Test coverage from lcov.info (auto-generated when tests run)
  linecount   File length limit (max 200 lines per non-generated .dart file)
  secrets     Hardcoded secrets detection (detect-secrets or basic grep)
  deadcode    Unused imports and dead code (reuses analyze output)
  noprint     Ensure no print() calls in lib/ (use a proper logging framework)
  metrics     Code metrics via dart_code_metrics — reports 4 individual metrics:
                * Cyclomatic Complexity  (max: 10, grade B)
                * Number of Parameters   (max: 4)
                * Maximum Nesting Level  (max: 3)
                * Weight of Class        (informational, no threshold)

METRIC THRESHOLDS
  Metric                    Acceptable    Fail
  ──────────────────────────────────────────────
  Cyclomatic Complexity     <= 10 (B)     > 10 (C+)
  Number of Parameters      <= 4          > 4
  Maximum Nesting Level     <= 3          > 3
  Weight of Class           any           (info only)
  Test Coverage             >= 90%        < 80%
  File Length               <= 200 ln     > 200 (non-generated)

NOTES ON --only
  - When --only is set, only the listed checks run.
  - Mode still affects HOW each check runs (e.g. pre-commit tests = unit only).
  - "deadcode" reuses analyze output; if "analyze" is not in --only, it runs
    silently to provide the data deadcode needs.
  - "coverage" reads the existing lcov.info file. If you need fresh coverage
    data, include "tests" as well: --only tests,coverage

EXAMPLES
  # Full quality check (default: pre-merge mode)
  ./scripts/quality-checks.sh

  # Fast pre-commit checks
  ./scripts/quality-checks.sh pre-commit

  # Pre-commit scoped to BLE module
  ./scripts/quality-checks.sh pre-commit --paths "lib/core/ble/ test/src/core/ble/"

  # Run only tests
  ./scripts/quality-checks.sh --only tests

  # Run only code metrics
  ./scripts/quality-checks.sh --only metrics

  # Run format + analyze
  ./scripts/quality-checks.sh --only format,analyze

  # Run tests with coverage
  ./scripts/quality-checks.sh --only tests,coverage

  # Pre-merge but skip metrics
  ./scripts/quality-checks.sh --only format,analyze,tests,coverage,linecount,secrets,deadcode,noprint,architecture

  # Run everything except tests (fast iteration)
  ./scripts/quality-checks.sh --skip tests

  # Run with custom timeout
  ./scripts/quality-checks.sh --timeout 600

DEPENDENCIES
  dart_code_metrics:  dart pub global activate dart_code_metrics
  detect-secrets:     pip install detect-secrets
  python3:            Required for test timing and metrics parsing
HELP
    exit 0
}

# ─── ARGUMENT PARSING ──────────────────────────────────────────────────────────

MODE="pre-merge"
ONLY_CHECKS=""
SKIP_CHECKS=""
CHECK_PATHS=""
TOTAL_SHARDS=""
SHARD_INDEX=""
OUTPUT_FORMAT="text"
TEST_DIRS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        pre-commit|pre-merge)
            MODE="$1"; shift ;;
        -h|--help)
            show_help ;;
        --only)
            if [ -z "${2:-}" ] || [[ "${2:-}" == -* ]]; then
                echo "Error: --only requires a comma-separated list of checks."
                echo "Available: format, analyze, tests, coverage, linecount, secrets, deadcode, noprint, metrics"
                exit 1
            fi
            ONLY_CHECKS="$2"; shift 2 ;;
        --paths)
            if [ -z "${2:-}" ] || [[ "${2:-}" == -* ]]; then
                echo "Error: --paths requires a directory list."
                exit 1
            fi
            CHECK_PATHS="$2"; shift 2 ;;
        --skip)
            if [ -z "${2:-}" ] || [[ "${2:-}" == -* ]]; then
                echo "Error: --skip requires a comma-separated list of checks."
                echo "Available: format, analyze, tests, coverage, linecount, secrets, deadcode, noprint, architecture, metrics"
                exit 1
            fi
            SKIP_CHECKS="$2"; shift 2 ;;
        --timeout)
            if [ -z "${2:-}" ] || [[ "${2:-}" == -* ]]; then
                echo "Error: --timeout requires a value in seconds."
                exit 1
            fi
            TEST_TIMEOUT="$2"; shift 2 ;;
        --total-shards)
            if [ -z "${2:-}" ] || [[ "${2:-}" == -* ]]; then
                echo "Error: --total-shards requires a positive integer."
                exit 1
            fi
            TOTAL_SHARDS="$2"; shift 2 ;;
        --shard-index)
            if [ -z "${2:-}" ] || [[ "${2:-}" == -* ]]; then
                echo "Error: --shard-index requires a non-negative integer."
                exit 1
            fi
            SHARD_INDEX="$2"; shift 2 ;;
        --output)
            if [ -z "${2:-}" ] || [[ "${2:-}" == -* ]]; then
                echo "Error: --output requires a format: text or json."
                exit 1
            fi
            if [ "$2" != "text" ] && [ "$2" != "json" ]; then
                echo "Error: --output must be 'text' or 'json'."
                exit 1
            fi
            OUTPUT_FORMAT="$2"; shift 2 ;;
        --test-dirs)
            if [ -z "${2:-}" ] || [[ "${2:-}" == -* ]]; then
                echo "Error: --test-dirs requires a directory list."
                exit 1
            fi
            TEST_DIRS="$2"; shift 2 ;;
        *)
            echo "Error: unknown argument '$1'"
            echo "Run with --help for usage information."
            exit 1 ;;
    esac
done

# Validate --only check names
if [ -n "$ONLY_CHECKS" ]; then
    VALID_CHECKS="format,analyze,tests,coverage,linecount,secrets,deadcode,noprint,architecture,metrics"
    IFS=',' read -ra _checks <<< "$ONLY_CHECKS"
    for _check in "${_checks[@]}"; do
        if ! echo ",$VALID_CHECKS," | grep -q ",$_check,"; then
            echo "Error: unknown check '$_check'"
            echo "Available checks: $VALID_CHECKS"
            exit 1
        fi
    done
    unset _checks _check
fi

# Validate --skip check names
if [ -n "$SKIP_CHECKS" ]; then
    VALID_CHECKS="format,analyze,tests,coverage,linecount,secrets,deadcode,noprint,architecture,metrics"
    IFS=',' read -ra _checks <<< "$SKIP_CHECKS"
    for _check in "${_checks[@]}"; do
        if ! echo ",$VALID_CHECKS," | grep -q ",$_check,"; then
            echo "Error: unknown check '$_check'"
            echo "Available checks: $VALID_CHECKS"
            exit 1
        fi
    done
    unset _checks _check
fi

# --only and --skip are mutually exclusive
if [ -n "$ONLY_CHECKS" ] && [ -n "$SKIP_CHECKS" ]; then
    echo "Error: --only and --skip are mutually exclusive."
    exit 1
fi

# Validate sharding flags
if [ -n "$SHARD_INDEX" ] && [ -z "$TOTAL_SHARDS" ]; then
    echo "Error: --shard-index requires --total-shards."
    exit 1
fi
if [ -n "$TOTAL_SHARDS" ] && [ -z "$SHARD_INDEX" ]; then
    echo "Error: --total-shards requires --shard-index."
    exit 1
fi

# ─── CHECK GATING ─────────────────────────────────────────────────────────────
# Determines whether a check should run based on --only filter and mode.

should_run() {
    local check="$1"
    # --skip takes precedence over mode
    if [ -n "$SKIP_CHECKS" ]; then
        if echo ",$SKIP_CHECKS," | grep -q ",$check,"; then
            return 1
        fi
    fi
    if [ -n "$ONLY_CHECKS" ]; then
        echo ",$ONLY_CHECKS," | grep -q ",$check,"
        return $?
    fi
    case "$MODE" in
        pre-commit)
            case "$check" in
                # Coverage is too slow for pre-commit — skip it.
                # Everything else runs in both modes.
                coverage) return 1 ;;
                *) return 0 ;;
            esac ;;
        pre-merge) return 0 ;;
    esac
}

# ─── TIMING ────────────────────────────────────────────────────────────────────

SCRIPT_START=$SECONDS

# ─── REPO ROOT ─────────────────────────────────────────────────────────────────

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT" || exit 1

if [ ! -f "pubspec.yaml" ]; then
    echo "ERROR: No pubspec.yaml found in $REPO_ROOT. This script must run from a Flutter/Dart project root."
    exit 1
fi

# ─── ENVIRONMENT: Flutter & Dart paths ─────────────────────────────────────────

IS_CI="${GITHUB_ACTIONS:-false}"

if [ "$IS_CI" = "true" ]; then
    FLUTTER="flutter"
    DART="dart"
else
    FLUTTER=""
    DART=""
    # 1. fvm which flutter
    if command -v fvm &>/dev/null; then
        FVM_FLUTTER=$(fvm which flutter 2>/dev/null)
        if [ -n "$FVM_FLUTTER" ] && [ -x "$FVM_FLUTTER" ]; then
            FLUTTER="$FVM_FLUTTER"
            DART="${FVM_FLUTTER%flutter}dart"
        fi
    fi
    # 2. Project-local .fvm/flutter_sdk
    if [ -z "$FLUTTER" ] && [ -x "$REPO_ROOT/.fvm/flutter_sdk/bin/flutter" ]; then
        FLUTTER="$REPO_ROOT/.fvm/flutter_sdk/bin/flutter"
        DART="$REPO_ROOT/.fvm/flutter_sdk/bin/dart"
    fi
    # 3. FVM default version
    if [ -z "$FLUTTER" ]; then
        for fvm_default in "$HOME/fvm/default" "$HOME/.fvm/default"; do
            if [ -x "$fvm_default/bin/flutter" ]; then
                FLUTTER="$fvm_default/bin/flutter"
                DART="$fvm_default/bin/dart"
                break
            fi
        done
    fi
    # 4. Latest FVM cached version
    if [ -z "$FLUTTER" ] && [ -d "$HOME/fvm/versions" ]; then
        FVM_LATEST=$(ls -1d "$HOME/fvm/versions"/*/ 2>/dev/null | sort -V | tail -1)
        if [ -n "$FVM_LATEST" ] && [ -x "${FVM_LATEST}bin/flutter" ]; then
            FLUTTER="${FVM_LATEST}bin/flutter"
            DART="${FVM_LATEST}bin/dart"
        fi
    fi
    # 5. Fallback to PATH
    if [ -z "$FLUTTER" ]; then
        FLUTTER=$(command -v flutter 2>/dev/null)
        DART=$(command -v dart 2>/dev/null)
    fi
    if [ -z "$FLUTTER" ] || [ ! -x "$FLUTTER" ]; then
        echo "ERROR: Flutter not found. Install FVM or add Flutter to your PATH."
        exit 1
    fi
fi

# Ensure dart is on PATH for globally activated tools (e.g. metrics wrapper calls `dart`)
DART_DIR=$(dirname "$DART" 2>/dev/null)
if [ -n "$DART_DIR" ] && [[ ":$PATH:" != *":$DART_DIR:"* ]]; then
    export PATH="$DART_DIR:$PATH"
fi

# Dart pub-cache bin (for globally activated tools like dart_code_metrics)
DART_PUB_BIN="$HOME/.pub-cache/bin"

# Find timeout command (GNU coreutils: 'timeout' on Linux, 'gtimeout' on macOS via brew)
find_timeout_cmd() {
    if command -v timeout &>/dev/null; then
        echo "timeout"
    elif command -v gtimeout &>/dev/null; then
        echo "gtimeout"
    else
        echo ""
    fi
}
TIMEOUT_CMD=$(find_timeout_cmd)

# ─── COLORS ────────────────────────────────────────────────────────────────────

if [ "$IS_CI" = "true" ] || [ "$OUTPUT_FORMAT" = "json" ] || [ "${NO_COLOR:-}" != "" ] || [ "${TERM:-}" = "dumb" ] || [ ! -t 1 ]; then
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' DIM='' NC=''
else
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    NC=$'\033[0m'
fi

# ─── STATUS TRACKING ──────────────────────────────────────────────────────────

FORMAT_STATUS="pending"
ANALYZE_STATUS="pending"
ANALYZE_ISSUES=""
ANALYZE_OUTPUT=""
TESTS_STATUS="pending"
TESTS_COUNT=""
COVERAGE_STATUS="pending"
COVERAGE_PCT=""
LINECOUNT_STATUS="pending"
LINECOUNT_OVER=""
OVER_COUNT=0
SECRETS_STATUS="pending"
DEADCODE_STATUS="pending"
DEADCODE_COUNT=""
NOPRINT_STATUS="pending"
NOPRINT_FILES=""
NOPRINT_COUNT=0
ARCH_STATUS="pending"
ARCH_CORE_COUNT=0
ARCH_SHARED_COUNT=0

# Individual metric statuses
CC_STATUS="pending"
CC_MAX_VAL=0
CC_VIOLATIONS=0
CC_DETAILS=""
NOP_STATUS="pending"
NOP_MAX_VAL=0
NOP_VIOLATIONS=0
NOP_DETAILS=""
NEST_STATUS="pending"
NEST_MAX_VAL=0
NEST_VIOLATIONS=0
NEST_DETAILS=""
WOC_STATUS="pending"
WOC_RANGE=""

FAILED_CHECKS=""
TEST_DURATION_TABLE=""

# ─── HELPER FUNCTIONS ─────────────────────────────────────────────────────────

print_error()   { printf "${RED}  %s${NC}\n" "$1"; }
print_success() { printf "${GREEN}  %s${NC}\n" "$1"; }
print_warning() { printf "${YELLOW}  %s${NC}\n" "$1"; }
print_info()    { printf "  %s\n" "$1"; }
print_skip() {
    # When --only or --skip is active, don't print skip messages (noise reduction)
    [ -n "$ONLY_CHECKS" ] && return
    [ -n "$SKIP_CHECKS" ] && return
    printf "${DIM}  %s (skipped)${NC}\n" "$1"
}

mark_failed() {
    if [ -z "$FAILED_CHECKS" ]; then
        FAILED_CHECKS="$1"
    else
        FAILED_CHECKS="$FAILED_CHECKS, $1"
    fi
}

format_duration() {
    local secs=$1
    if [ "$secs" -ge 60 ]; then
        printf "%dm %ds" $((secs / 60)) $((secs % 60))
    else
        printf "%ds" "$secs"
    fi
}

# Limit output lines (disabled in JSON mode to include ALL violations)
head_limit() {
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        cat
    else
        head -"${1:-5}"
    fi
}

# ─── BANNER ────────────────────────────────────────────────────────────────────

MODE_UPPER=$(echo "$MODE" | tr '[:lower:]' '[:upper:]')
printf "\n"
printf "${BOLD}=======================================================================${NC}\n"
printf "${BOLD}  QUALITY CHECKS — %s${NC}\n" "$MODE_UPPER"
if [ -n "$ONLY_CHECKS" ]; then
    printf "${DIM}  Checks: %s${NC}\n" "$ONLY_CHECKS"
fi
if [ -n "$SKIP_CHECKS" ]; then
    printf "${DIM}  Skipping: %s${NC}\n" "$SKIP_CHECKS"
fi
printf "${BOLD}=======================================================================${NC}\n"
printf "\n"

# ═══════════════════════════════════════════════════════════════════════════════
# CHECKS 1+2 (parallel): dart format + flutter analyze
# Run concurrently, capture to temp files, print in deterministic order.
# ═══════════════════════════════════════════════════════════════════════════════

_FMT_OUT=$(mktemp /tmp/qc_fmt_XXXXXX)
_ANA_OUT=$(mktemp /tmp/qc_ana_XXXXXX)
_FMT_PID=""
_ANA_PID=""
RUN_FORMAT=false
NEED_ANALYZE=false

if should_run "format"; then
    RUN_FORMAT=true
fi
if should_run "analyze" || should_run "deadcode"; then
    NEED_ANALYZE=true
fi

# Launch format in background
if [ "$RUN_FORMAT" = true ]; then
    {
        if [ "$MODE" = "pre-commit" ] && [ -n "$CHECK_PATHS" ]; then
            $DART format --set-exit-if-changed --output=none $CHECK_PATHS
        else
            $DART format --set-exit-if-changed --output=none lib/ test/
        fi
    } > "$_FMT_OUT" 2>&1 &
    _FMT_PID=$!
fi

# Launch analyze in background
if [ "$NEED_ANALYZE" = true ]; then
    {
        if [ -n "$TIMEOUT_CMD" ]; then
            $TIMEOUT_CMD $ANALYZE_TIMEOUT $FLUTTER analyze --no-pub
        else
            $FLUTTER analyze --no-pub
        fi
    } > "$_ANA_OUT" 2>&1 &
    _ANA_PID=$!
fi

# Wait for both
FORMAT_EXIT=0
ANALYZE_EXIT=0
[ -n "$_FMT_PID" ] && { wait $_FMT_PID; FORMAT_EXIT=$?; }
[ -n "$_ANA_PID" ] && { wait $_ANA_PID; ANALYZE_EXIT=$?; }

# ── Process format results (printed first) ──
if [ "$RUN_FORMAT" = true ]; then
    FORMAT_OUTPUT=$(cat "$_FMT_OUT")
    if [ $FORMAT_EXIT -eq 0 ]; then
        print_success "Format: code correctly formatted"
        FORMAT_STATUS="pass"
    else
        UNFORMATTED=$(echo "$FORMAT_OUTPUT" | grep -c "Changed")
        print_error "Format: ${UNFORMATTED} files need formatting"
        echo "$FORMAT_OUTPUT" | grep "Changed" | head_limit 5
        FORMAT_STATUS="fail"
        mark_failed "Format"
    fi
else
    print_skip "Format"
    FORMAT_STATUS="skip"
fi

# ── Process analyze results (printed second) ──
if [ "$NEED_ANALYZE" = true ]; then
    ANALYZE_OUTPUT=$(cat "$_ANA_OUT")

    if [ $ANALYZE_EXIT -eq 124 ]; then
        print_error "Analyze: TIMEOUT after ${ANALYZE_TIMEOUT}s"
        ANALYZE_STATUS="fail"
        mark_failed "Analyze (timeout)"
    else
        # Strip ANSI codes and CR characters before parsing
        ANALYZE_CLEAN=$(echo "$ANALYZE_OUTPUT" | sed $'s/\033\[[0-9;]*[a-zA-Z]//g' | tr -d '\r')
        ANALYZE_ISSUES=$(echo "$ANALYZE_CLEAN" | grep -oE '[0-9]+ issue' | grep -oE '[0-9]+' | head -1)
        ANALYZE_ERRORS=$(echo "$ANALYZE_CLEAN" | grep -c " error " || true)
        ANALYZE_WARNINGS=$(echo "$ANALYZE_CLEAN" | grep -c " warning " || true)
        ANALYZE_INFOS=$(echo "$ANALYZE_CLEAN" | grep -c " info " || true)
        ANALYZE_ERRORS=$(echo "$ANALYZE_ERRORS" | tr -d '[:space:]')
        ANALYZE_WARNINGS=$(echo "$ANALYZE_WARNINGS" | tr -d '[:space:]')
        ANALYZE_INFOS=$(echo "$ANALYZE_INFOS" | tr -d '[:space:]')

        if should_run "analyze"; then
            if [ $ANALYZE_EXIT -eq 0 ]; then
                print_success "Analyze: 0 issues (${ANALYZE_ERRORS} errors, ${ANALYZE_WARNINGS} warnings, ${ANALYZE_INFOS} infos)"
                ANALYZE_STATUS="pass"
            else
                if [ "$ANALYZE_ERRORS" -gt 0 ]; then
                    print_error "Analyze: ${ANALYZE_ERRORS} errors, ${ANALYZE_WARNINGS} warnings, ${ANALYZE_INFOS} infos"
                    echo "$ANALYZE_OUTPUT" | grep " error " | head_limit 5
                    ANALYZE_STATUS="fail"
                    mark_failed "Analyze"
                elif [ "$ANALYZE_WARNINGS" -gt 0 ]; then
                    print_warning "Analyze: ${ANALYZE_WARNINGS} warnings, ${ANALYZE_INFOS} infos"
                    echo "$ANALYZE_OUTPUT" | grep " warning " | head_limit 5
                    ANALYZE_STATUS="warn"
                else
                    print_warning "Analyze: ${ANALYZE_INFOS} infos"
                    ANALYZE_STATUS="warn"
                fi
            fi
        else
            ANALYZE_STATUS="skip"
        fi
    fi
else
    if should_run "analyze"; then
        print_skip "Analyze"
    fi
    ANALYZE_STATUS="skip"
fi

rm -f "$_FMT_OUT" "$_ANA_OUT"

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 3+4: Tests (+ coverage)
# ═══════════════════════════════════════════════════════════════════════════════

# Determine if we need coverage data from this test run
NEED_COVERAGE_FLAG=false
if should_run "coverage"; then
    NEED_COVERAGE_FLAG=true
fi

# Build optional shard flags for flutter test
SHARD_FLAGS=""
if [ -n "$TOTAL_SHARDS" ] && [ -n "$SHARD_INDEX" ]; then
    SHARD_FLAGS="--total-shards=$TOTAL_SHARDS --shard-index=$SHARD_INDEX"
fi

TEST_JSON_FILE=$(mktemp /tmp/flutter_test_XXXXXX.jsonl)
METRICS_JSON_FILE=""

cleanup() {
    rm -f "$TEST_JSON_FILE" "${TEST_JSON_FILE}.err" "$METRICS_JSON_FILE" 2>/dev/null
}
trap cleanup EXIT

if should_run "tests"; then
    if [ -n "$TEST_DIRS" ]; then
        # --test-dirs: run tests only in specified directories
        COVERAGE_FLAG=""
        if [ "$NEED_COVERAGE_FLAG" = true ]; then
            COVERAGE_FLAG="--coverage"
        fi
        TEST_EXIT=0
        for _tdir in $TEST_DIRS; do
            print_info "Running tests in ${_tdir}..."
            _TDIR_JSON=$(mktemp /tmp/flutter_tdir_XXXXXX.jsonl)
            if [ -n "$TIMEOUT_CMD" ]; then
                $TIMEOUT_CMD $TEST_TIMEOUT $FLUTTER test "$_tdir" $COVERAGE_FLAG --no-pub --concurrency=8 --dart-define=TEST_MODE=true $SHARD_FLAGS --reporter json > "$_TDIR_JSON" 2>"${TEST_JSON_FILE}.err"
            else
                $FLUTTER test "$_tdir" $COVERAGE_FLAG --no-pub --concurrency=8 --dart-define=TEST_MODE=true $SHARD_FLAGS --reporter json > "$_TDIR_JSON" 2>"${TEST_JSON_FILE}.err"
            fi
            _TDIR_EXIT=$?
            cat "$_TDIR_JSON" >> "$TEST_JSON_FILE"
            rm -f "$_TDIR_JSON"
            if [ $_TDIR_EXIT -ne 0 ]; then
                TEST_EXIT=$_TDIR_EXIT
            fi
        done
        unset _tdir _TDIR_JSON _TDIR_EXIT COVERAGE_FLAG
    elif [ "$MODE" = "pre-commit" ] && [ "$NEED_COVERAGE_FLAG" = false ]; then
        # Pre-commit: unit tests only, no coverage
        print_info "Running unit tests (--tags unit)..."
        if [ -n "$TIMEOUT_CMD" ]; then
            $TIMEOUT_CMD $TEST_TIMEOUT $FLUTTER test --tags unit --no-pub --concurrency=8 --dart-define=TEST_MODE=true $SHARD_FLAGS --reporter json > "$TEST_JSON_FILE" 2>"${TEST_JSON_FILE}.err"
        else
            $FLUTTER test --tags unit --no-pub --concurrency=8 --dart-define=TEST_MODE=true $SHARD_FLAGS --reporter json > "$TEST_JSON_FILE" 2>"${TEST_JSON_FILE}.err"
        fi
        TEST_EXIT=$?

        # If --paths provided, also run tests in those directories
        PATH_TEST_EXIT=0
        if [ -n "$CHECK_PATHS" ] && [ $TEST_EXIT -eq 0 ]; then
            PATH_TEST_DIRS=""
            for p in $CHECK_PATHS; do
                if [[ "$p" == test/* ]]; then
                    PATH_TEST_DIRS="$PATH_TEST_DIRS $p"
                fi
            done
            if [ -n "$PATH_TEST_DIRS" ]; then
                print_info "Running tests in affected paths ($PATH_TEST_DIRS)..."
                PATH_TEST_JSON=$(mktemp /tmp/flutter_path_test_XXXXXX.jsonl)
                if [ -n "$TIMEOUT_CMD" ]; then
                    $TIMEOUT_CMD $TEST_TIMEOUT $FLUTTER test $PATH_TEST_DIRS --no-pub --concurrency=8 --dart-define=TEST_MODE=true $SHARD_FLAGS --reporter json > "$PATH_TEST_JSON" 2>"${TEST_JSON_FILE}.err"
                else
                    $FLUTTER test $PATH_TEST_DIRS --no-pub --concurrency=8 --dart-define=TEST_MODE=true $SHARD_FLAGS --reporter json > "$PATH_TEST_JSON" 2>"${TEST_JSON_FILE}.err"
                fi
                PATH_TEST_EXIT=$?
                cat "$PATH_TEST_JSON" >> "$TEST_JSON_FILE"
                rm -f "$PATH_TEST_JSON"
                if [ $PATH_TEST_EXIT -ne 0 ]; then
                    TEST_EXIT=$PATH_TEST_EXIT
                fi
            fi
        fi
    else
        # Pre-merge or coverage requested: all tests with coverage
        print_info "Running tests with coverage..."
        if [ -n "$TIMEOUT_CMD" ]; then
            $TIMEOUT_CMD $TEST_TIMEOUT $FLUTTER test --coverage --no-pub --concurrency=8 --dart-define=TEST_MODE=true $SHARD_FLAGS --reporter json > "$TEST_JSON_FILE" 2>"${TEST_JSON_FILE}.err"
        else
            $FLUTTER test --coverage --no-pub --concurrency=8 --dart-define=TEST_MODE=true $SHARD_FLAGS --reporter json > "$TEST_JSON_FILE" 2>"${TEST_JSON_FILE}.err"
        fi
        TEST_EXIT=$?
    fi

    # Detect timeout (exit 124 from timeout command)
    if [ $TEST_EXIT -eq 124 ]; then
        print_error "Tests: TIMEOUT despues de ${TEST_TIMEOUT}s — posible test colgado"
        if [ -s "${TEST_JSON_FILE}.err" ]; then
            print_error "Stderr output:"
            head -20 "${TEST_JSON_FILE}.err"
        fi
        TESTS_STATUS="fail"
        mark_failed "Tests (timeout)"
    fi

    # Skip parsing and reporting if timeout already handled
    if [ $TEST_EXIT -ne 124 ]; then

    # Parse JSON reporter output for test counts and per-test timing
    if [ -s "$TEST_JSON_FILE" ]; then
        PARSED_OUTPUT=$(python3 -c "
import json, sys, os
from collections import defaultdict

suites = {}
tests = {}
suite_stats = defaultdict(lambda: {'count': 0, 'duration_ms': 0})
total_tests = 0
total_passed = 0
total_failed = 0

for line in open('$TEST_JSON_FILE'):
    line = line.strip()
    if not line:
        continue
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        continue

    etype = event.get('type')

    if etype == 'suite':
        suite = event.get('suite', {})
        suites[suite.get('id')] = suite.get('path', '')

    elif etype == 'testStart':
        t = event.get('test', {})
        tid = t.get('id')
        if tid is not None:
            tests[tid] = {
                'suiteID': t.get('suiteID'),
                'name': t.get('name', ''),
                'startTime': event.get('time', 0),
            }

    elif etype == 'testDone':
        tid = event.get('testID')
        if tid in tests:
            t = tests[tid]
            if t['name'].startswith('loading '):
                continue
            end_time = event.get('time', 0)
            duration = max(0, end_time - t['startTime'])
            suite_path = suites.get(t['suiteID'], '')
            rel = suite_path.replace('\\\\', '/')
            test_idx = rel.find('/test/')
            if test_idx >= 0:
                rel = rel[test_idx + 6:]
            elif rel.startswith('test/'):
                rel = rel[5:]
            if rel.startswith('src/'):
                rel = rel[4:]
            parts = rel.split('/')
            if len(parts) >= 2:
                module = '/'.join(parts[:2]) + '/'
            else:
                module = rel
            suite_stats[module]['count'] += 1
            suite_stats[module]['duration_ms'] += duration
            total_tests += 1
            result = event.get('result', '')
            if result == 'success':
                total_passed += 1
            elif result in ('failure', 'error'):
                total_failed += 1

print(f'TESTS_TOTAL={total_tests}')
print(f'TESTS_PASSED={total_passed}')
print(f'TESTS_FAILED={total_failed}')

print('TABLE_START')
for module, stats in sorted(suite_stats.items(), key=lambda x: -x[1]['duration_ms']):
    secs = stats['duration_ms'] / 1000
    print(f\"{module}|{stats['count']}|{secs:.1f}s\")
print('TABLE_END')

total_secs = sum(s['duration_ms'] for s in suite_stats.values()) / 1000
print(f'TESTS_TOTAL_SECS={total_secs:.1f}')
" 2>/dev/null)

        TESTS_TOTAL=$(echo "$PARSED_OUTPUT" | grep '^TESTS_TOTAL=' | head -1 | cut -d= -f2)
        TESTS_PASSED=$(echo "$PARSED_OUTPUT" | grep '^TESTS_PASSED=' | cut -d= -f2)
        TESTS_FAILED=$(echo "$PARSED_OUTPUT" | grep '^TESTS_FAILED=' | cut -d= -f2)
        TESTS_COUNT="${TESTS_TOTAL:-0}"
        TESTS_TOTAL_SECS=$(echo "$PARSED_OUTPUT" | grep '^TESTS_TOTAL_SECS=' | cut -d= -f2)
        TEST_DURATION_TABLE=$(echo "$PARSED_OUTPUT" | sed -n '/^TABLE_START$/,/^TABLE_END$/p' | grep -v '^TABLE_')
    fi

    # Fallback count
    if [ -z "$TESTS_COUNT" ] || [ "$TESTS_COUNT" = "0" ]; then
        RAW_TEST_OUTPUT=$(cat "$TEST_JSON_FILE" 2>/dev/null)
        TESTS_COUNT=$(echo "$RAW_TEST_OUTPUT" | grep -oE 'All [0-9]+ tests passed' | grep -oE '[0-9]+' || \
                      echo "$RAW_TEST_OUTPUT" | grep -oE '[0-9]+ tests? passed' | grep -oE '[0-9]+' | head -1)
    fi

    # Report test results
    if [ $TEST_EXIT -eq 0 ]; then
        if [ "$MODE" = "pre-commit" ] && [ "$NEED_COVERAGE_FLAG" = false ]; then
            print_success "Tests (unit): todos pasaron — ${TESTS_COUNT:-?} tests"
        else
            print_success "Tests: todos pasaron — ${TESTS_COUNT:-?} tests"
        fi
        TESTS_STATUS="pass"
    else
        print_error "Tests: ${TESTS_FAILED:-algunos} tests fallaron"
        if [ -s "${TEST_JSON_FILE}.err" ]; then
            echo "  ${DIM}--- stderr ---${NC}"
            head -10 "${TEST_JSON_FILE}.err"
        fi
        TESTS_STATUS="fail"
        mark_failed "Tests"
    fi

    # Show per-module timing table
    if [ -n "$TEST_DURATION_TABLE" ]; then
        printf "\n"
        printf "  ${BOLD}Modulo                              Tests   Tiempo${NC}\n"
        printf "  ${DIM}──────────────────────────────────────────────────${NC}\n"
        echo "$TEST_DURATION_TABLE" | while IFS='|' read -r module count duration; do
            printf "  %-36s %5s   %s\n" "$module" "$count" "$duration"
        done
        printf "  ${DIM}──────────────────────────────────────────────────${NC}\n"
        printf "  ${BOLD}%-36s %5s   %ss${NC}\n" "TOTAL" "${TESTS_COUNT:-0}" "${TESTS_TOTAL_SECS:-0}"
        printf "\n"
    fi

    fi  # end of: if [ $TEST_EXIT -ne 124 ]
else
    print_skip "Tests"
    TESTS_STATUS="skip"
fi

# CHECK 4: Coverage
if should_run "coverage"; then
    if [ -f "coverage/lcov.info" ]; then
        TOTAL_LINES=0
        COVERED_LINES=0
        while IFS= read -r line; do
            case "$line" in
                LF:*) TOTAL_LINES=$((TOTAL_LINES + ${line#LF:})) ;;
                LH:*) COVERED_LINES=$((COVERED_LINES + ${line#LH:})) ;;
            esac
        done < coverage/lcov.info

        if [ "$TOTAL_LINES" -gt 0 ]; then
            COVERAGE_PCT=$((COVERED_LINES * 100 / TOTAL_LINES))
            if [ "$COVERAGE_PCT" -ge 90 ]; then
                print_success "Coverage: ${COVERAGE_PCT}% (${COVERED_LINES}/${TOTAL_LINES} líneas)"
                COVERAGE_STATUS="pass"
            elif [ "$COVERAGE_PCT" -ge 80 ]; then
                print_warning "Coverage: ${COVERAGE_PCT}% (objetivo: 90%)"
                COVERAGE_STATUS="warn"
            else
                print_error "Coverage: ${COVERAGE_PCT}% (mínimo: 80%)"
                COVERAGE_STATUS="fail"
                mark_failed "Coverage"
            fi
        else
            print_warning "Coverage: sin datos de cobertura"
            COVERAGE_STATUS="warn"
        fi
    else
        print_warning "Coverage: no se encontro lcov.info (ejecuta tests primero o usa --only tests,coverage)"
        COVERAGE_STATUS="warn"
    fi
else
    print_skip "Coverage"
    COVERAGE_STATUS="skip"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# CHECKS 5,6,8,9 (parallel): linecount, secrets, noprint, architecture
# Run grep-based checks concurrently, then process results in order.
# ═══════════════════════════════════════════════════════════════════════════════

_GREP_DIR=$(mktemp -d /tmp/qc_grep_XXXXXX)
_LC_PID=""
_SEC_PID=""
_NP_PID=""
_ARCH_PID=""

# ── Launch linecount in background ──
if should_run "linecount"; then
    (
        _df=$(mktemp)
        if [ "$MODE" = "pre-commit" ] && [ -n "$CHECK_PATHS" ]; then
            for p in $CHECK_PATHS; do
                find "$p" -name "*.dart" -type f ! -name "*.freezed.dart" ! -name "*.g.dart" 2>/dev/null >> "$_df"
            done
        else
            find lib -name "*.dart" -type f ! -name "*.freezed.dart" ! -name "*.g.dart" 2>/dev/null > "$_df"
        fi
        while IFS= read -r file; do
            LINES=$(wc -l < "$file" | tr -d ' ')
            if [ "$LINES" -gt 200 ]; then
                echo "${file}:${LINES}"
            fi
        done < "$_df"
        rm -f "$_df"
    ) > "$_GREP_DIR/linecount" 2>/dev/null &
    _LC_PID=$!
fi

# ── Launch secrets scan in background ──
if should_run "secrets"; then
    (
        if command -v detect-secrets &>/dev/null; then
            echo "TOOL=detect-secrets"
            detect-secrets scan --exclude-files '.*\.lock' --exclude-files 'coverage/.*' --exclude-files '\.fvm/.*' .
        else
            echo "TOOL=grep"
            grep -rn --include="*.dart" \
                -E '(api[_-]?key|secret|password|token)\s*[:=]\s*["\x27][A-Za-z0-9+/=]{16,}' \
                lib/ 2>/dev/null | grep -v '// ignore-secret' || true
        fi
    ) > "$_GREP_DIR/secrets" 2>/dev/null &
    _SEC_PID=$!
fi

# ── Launch noprint check in background ──
if should_run "noprint"; then
    (
        if [ "$MODE" = "pre-commit" ] && [ -n "$CHECK_PATHS" ]; then
            grep -rn --include="*.dart" -E '^\s*print\(' $CHECK_PATHS 2>/dev/null | grep -v '// allow-print' || true
        else
            grep -rn --include="*.dart" -E '^\s*print\(' lib/ 2>/dev/null | grep -v '// allow-print' || true
        fi
    ) > "$_GREP_DIR/noprint" 2>/dev/null &
    _NP_PID=$!
fi

# ── Launch architecture check in background ──
if should_run "architecture"; then
    if [ -d "lib/core" ] || [ -d "lib/shared" ]; then
        (
            echo "===CORE==="
            grep -rn --include="*.dart" -E "import\s+'.*/(features|composition)/" lib/core/ 2>/dev/null || true
            echo "===SHARED==="
            grep -rn --include="*.dart" -E "import\s+'.*(features|composition)/" lib/shared/ 2>/dev/null || true
        ) > "$_GREP_DIR/arch" 2>/dev/null &
        _ARCH_PID=$!
    fi
fi

# Wait for all parallel grep checks
[ -n "$_LC_PID" ] && wait $_LC_PID
[ -n "$_SEC_PID" ] && wait $_SEC_PID
[ -n "$_NP_PID" ] && wait $_NP_PID
[ -n "$_ARCH_PID" ] && wait $_ARCH_PID

# ── Process linecount results ──
if should_run "linecount"; then
    _LC_DATA=$(cat "$_GREP_DIR/linecount" 2>/dev/null)
    OVER_COUNT=0
    LINECOUNT_OVER=""
    if [ -n "$_LC_DATA" ]; then
        OVER_COUNT=$(echo "$_LC_DATA" | wc -l | tr -d ' ')
        LINECOUNT_OVER="$_LC_DATA"
    fi

    if [ "$OVER_COUNT" -eq 0 ]; then
        print_success "Line count: all files <= 200 lines"
        LINECOUNT_STATUS="pass"
    else
        print_error "Line count: ${OVER_COUNT} files exceed 200 lines"
        echo "$LINECOUNT_OVER" | sort -t: -k2 -rn | head_limit 5 | while IFS=: read -r f l; do
            echo "   ${f}: ${l} lines"
        done
        LINECOUNT_STATUS="fail"
        mark_failed "Line count"
    fi
else
    print_skip "Line count"
    LINECOUNT_STATUS="skip"
fi

# ── Process secrets results ──
if should_run "secrets"; then
    _SEC_DATA=$(cat "$_GREP_DIR/secrets" 2>/dev/null)
    _SEC_TOOL=$(echo "$_SEC_DATA" | head -1 | grep -oP '(?<=TOOL=).*' || echo "grep")
    _SEC_BODY=$(echo "$_SEC_DATA" | tail -n +2)

    if [ "$_SEC_TOOL" = "detect-secrets" ]; then
        SECRETS_COUNT=$(echo "$_SEC_BODY" | python3 -c "import sys, json; data=json.load(sys.stdin); print(sum(len(v) for v in data.get('results', {}).values()))" 2>/dev/null || echo "0")
        if [ "$SECRETS_COUNT" = "0" ]; then
            print_success "Detect-secrets: no secrets detected"
            SECRETS_STATUS="pass"
        else
            print_error "Detect-secrets: ${SECRETS_COUNT} potential secrets found"
            SECRETS_STATUS="fail"
            mark_failed "Secrets"
        fi
    else
        HARDCODED="$_SEC_BODY"
        if [ -z "$HARDCODED" ]; then
            print_success "Secrets (basic scan): no obvious secrets detected"
            SECRETS_STATUS="pass"
        else
            HARDCODED_COUNT=$(echo "$HARDCODED" | wc -l | tr -d ' ')
            print_warning "Secrets (basic scan): ${HARDCODED_COUNT} potential secrets"
            echo "$HARDCODED" | head_limit 5
            SECRETS_STATUS="warn"
        fi
    fi
else
    print_skip "Secrets scan"
    SECRETS_STATUS="skip"
fi

# ── CHECK 7: Dead code (sequential — depends on analyze output) ──
if should_run "deadcode"; then
    print_info "Detecting dead code (unused imports)..."
    DEADCODE_OUTPUT=$(echo "$ANALYZE_OUTPUT" | grep -E "unused_import|unused_element|dead_code" 2>/dev/null)
    DEADCODE_COUNT=$(echo "$DEADCODE_OUTPUT" | grep -c . 2>/dev/null || echo "0")
    [ -z "$DEADCODE_OUTPUT" ] && DEADCODE_COUNT=0

    if [ "$DEADCODE_COUNT" -eq 0 ]; then
        print_success "Dead code: no unused imports or elements"
        DEADCODE_STATUS="pass"
    else
        print_warning "Dead code: ${DEADCODE_COUNT} unused elements"
        echo "$DEADCODE_OUTPUT" | head_limit 5
        [ "$OUTPUT_FORMAT" != "json" ] && [ "$DEADCODE_COUNT" -gt 5 ] && echo "   ... and $((DEADCODE_COUNT - 5)) more"
        DEADCODE_STATUS="warn"
    fi
else
    print_skip "Dead code"
    DEADCODE_STATUS="skip"
fi

# ── Process noprint results ──
if should_run "noprint"; then
    PRINT_OUTPUT=$(cat "$_GREP_DIR/noprint" 2>/dev/null)
    NOPRINT_COUNT=$(echo "$PRINT_OUTPUT" | grep -c . 2>/dev/null || echo "0")
    [ -z "$PRINT_OUTPUT" ] && NOPRINT_COUNT=0

    if [ "$NOPRINT_COUNT" -eq 0 ]; then
        print_success "No print(): code uses logging framework correctly"
        NOPRINT_STATUS="pass"
    else
        NOPRINT_FILES=$(echo "$PRINT_OUTPUT" | cut -d: -f1 | sort -u | wc -l | tr -d ' ')
        print_warning "No print(): ${NOPRINT_COUNT} print() calls in ${NOPRINT_FILES} files"
        echo "$PRINT_OUTPUT" | head_limit 5
        [ "$OUTPUT_FORMAT" != "json" ] && [ "$NOPRINT_COUNT" -gt 5 ] && echo "   ... and $((NOPRINT_COUNT - 5)) more"
        NOPRINT_STATUS="warn"
    fi
else
    print_skip "No print()"
    NOPRINT_STATUS="skip"
fi

# ── Process architecture results ──
if should_run "architecture"; then
    if [ ! -d "lib/core" ] && [ ! -d "lib/shared" ]; then
        print_info "Architecture: skipped (no lib/core/ or lib/shared/ found)"
        ARCH_STATUS="skip"
    elif [ -f "$_GREP_DIR/arch" ]; then
        _ARCH_DATA=$(cat "$_GREP_DIR/arch")
        ARCH_CORE_OUTPUT=$(echo "$_ARCH_DATA" | sed -n '/^===CORE===/,/^===SHARED===/p' | grep -v '^===' || true)
        ARCH_SHARED_OUTPUT=$(echo "$_ARCH_DATA" | sed -n '/^===SHARED===/,$p' | grep -v '^===' || true)
        ARCH_CORE_COUNT=$(echo "$ARCH_CORE_OUTPUT" | grep -c . 2>/dev/null || echo "0")
        [ -z "$ARCH_CORE_OUTPUT" ] && ARCH_CORE_COUNT=0
        ARCH_SHARED_COUNT=$(echo "$ARCH_SHARED_OUTPUT" | grep -c . 2>/dev/null || echo "0")
        [ -z "$ARCH_SHARED_OUTPUT" ] && ARCH_SHARED_COUNT=0

        if [ "$ARCH_CORE_COUNT" -gt 0 ]; then
            print_error "Architecture: ${ARCH_CORE_COUNT} illegal imports in core/ (must not import features/ or composition/)"
            echo "$ARCH_CORE_OUTPUT" | head_limit 10
            [ "$OUTPUT_FORMAT" != "json" ] && [ "$ARCH_CORE_COUNT" -gt 10 ] && echo "   ... and $((ARCH_CORE_COUNT - 10)) more"
            mark_failed "architecture"
            ARCH_STATUS="fail"
        elif [ "$ARCH_SHARED_COUNT" -gt 0 ]; then
            ARCH_SHARED_FILES=$(echo "$ARCH_SHARED_OUTPUT" | cut -d: -f1 | sort -u | wc -l | tr -d ' ')
            print_warning "Architecture: ${ARCH_SHARED_COUNT} imports from features/ or composition/ in shared/ (${ARCH_SHARED_FILES} files — known debt)"
            echo "$ARCH_SHARED_OUTPUT" | head_limit 10
            [ "$OUTPUT_FORMAT" != "json" ] && [ "$ARCH_SHARED_COUNT" -gt 10 ] && echo "   ... and $((ARCH_SHARED_COUNT - 10)) more"
            ARCH_STATUS="warn"
        else
            print_success "Architecture: import direction rules OK"
            ARCH_STATUS="pass"
        fi
    else
        print_info "Architecture: skipped (no lib/core/ or lib/shared/ found)"
        ARCH_STATUS="skip"
    fi
else
    print_skip "Architecture"
    ARCH_STATUS="skip"
fi

rm -rf "$_GREP_DIR"

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 10: Code metrics — dart_code_metrics
# Reports 4 individual metrics: CC, NOP, Nesting, WOC
# Thresholds defined at top of script: CC<=10, NOP<=4, Nesting<=3, WOC=info
# ═══════════════════════════════════════════════════════════════════════════════
if should_run "metrics"; then
    # Locate the metrics binary
    METRICS_CMD=""
    if command -v metrics &>/dev/null; then
        METRICS_CMD="metrics"
    elif [ -x "$DART_PUB_BIN/metrics" ]; then
        METRICS_CMD="$DART_PUB_BIN/metrics"
    fi

    if [ -n "$METRICS_CMD" ]; then
        printf "\n"
        print_info "Analizando metricas de codigo (dart_code_metrics)..."
        printf "  ${DIM}Limites: CC <= %s | NOP <= %s | Nesting <= %s | WOC: info${NC}\n" "$THRESHOLD_CC" "$THRESHOLD_NOP" "$THRESHOLD_NESTING"

        METRICS_JSON_FILE=$(mktemp /tmp/dcm_metrics_XXXXXX.json)

        # Try JSON reporter first (structured, parseable).
        # DCM writes progress spinner (ANSI codes) to stdout — strip them,
        # then extract the JSON object line (starts with '{' or '[').
        if [ -n "$TIMEOUT_CMD" ]; then
            $TIMEOUT_CMD $METRICS_TIMEOUT $METRICS_CMD analyze lib/ --reporter=json 2>/dev/null \
                | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
                | tr -d '\r' \
                | grep -E '^\[|^\{' > "$METRICS_JSON_FILE"
        else
            $METRICS_CMD analyze lib/ --reporter=json 2>/dev/null \
                | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
                | tr -d '\r' \
                | grep -E '^\[|^\{' > "$METRICS_JSON_FILE"
        fi
        METRICS_JSON_EXIT=${PIPESTATUS[0]}

        METRICS_PARSED=""
        if [ $METRICS_JSON_EXIT -eq 0 ] && [ -s "$METRICS_JSON_FILE" ]; then
            METRICS_PARSED=$(python3 -c "
import json, sys, re

CC_LIMIT = int(sys.argv[1])
NOP_LIMIT = int(sys.argv[2])
NEST_LIMIT = int(sys.argv[3])

try:
    raw = open(sys.argv[4]).read()
    # Extra safety: strip any remaining ANSI codes
    raw = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', raw)
    data = json.loads(raw)
except (json.JSONDecodeError, FileNotFoundError):
    sys.exit(1)

records = data.get('records', data.get('report', []))
if not isinstance(records, list):
    sys.exit(1)

cc_max = 0
nop_max = 0
nest_max = 0
cc_violations = []
nop_violations = []
nest_violations = []
woc_values = []
total_functions = 0
total_classes = 0

def get_metric_map(metrics):
    \"\"\"Handle both list and dict metric formats across DCM versions.\"\"\"
    if isinstance(metrics, list):
        return {m.get('metricsId', m.get('id', '')): m.get('value', 0) for m in metrics if isinstance(m, dict)}
    elif isinstance(metrics, dict):
        result = {}
        for k, v in metrics.items():
            if isinstance(v, dict):
                result[k] = v.get('value', 0)
            elif isinstance(v, (int, float)):
                result[k] = v
        return result
    return {}

def iter_items(container):
    \"\"\"Iterate items from a dict (DCM 5.x: name->obj) or list (older: [obj]).\"\"\"
    if isinstance(container, dict):
        for name, obj in container.items():
            if isinstance(obj, dict):
                yield name, obj
    elif isinstance(container, list):
        for obj in container:
            if isinstance(obj, dict):
                yield obj.get('name', obj.get('shortName', '?')), obj

for record in records:
    path = record.get('path', record.get('relativePath', ''))

    for name, func in iter_items(record.get('functions', {})):
        total_functions += 1
        metric_map = get_metric_map(func.get('metrics', []))

        cc = metric_map.get('cyclomatic-complexity', 0)
        nop_val = metric_map.get('number-of-parameters', 0)
        nest = metric_map.get('maximum-nesting-level', metric_map.get('nesting-level', 0))

        if cc > cc_max:
            cc_max = cc
        if nop_val > nop_max:
            nop_max = nop_val
        if nest > nest_max:
            nest_max = nest

        if cc > CC_LIMIT:
            cc_violations.append(f'{path}:{name}:{cc}')
        if nop_val > NOP_LIMIT:
            nop_violations.append(f'{path}:{name}:{nop_val}')
        if nest > NEST_LIMIT:
            nest_violations.append(f'{path}:{name}:{nest}')

    for name, cls in iter_items(record.get('classes', {})):
        total_classes += 1
        metric_map = get_metric_map(cls.get('metrics', []))

        woc = metric_map.get('weight-of-class', -1)
        if isinstance(woc, (int, float)) and woc >= 0:
            woc_values.append((path, name, float(woc)))

# Output results
print(f'CC_MAX={cc_max}')
print(f'CC_VIOLATIONS={len(cc_violations)}')
for v in cc_violations[:5]:
    print(f'CC_V={v}')

print(f'NOP_MAX={nop_max}')
print(f'NOP_VIOLATIONS={len(nop_violations)}')
for v in nop_violations[:5]:
    print(f'NOP_V={v}')

print(f'NEST_MAX={nest_max}')
print(f'NEST_VIOLATIONS={len(nest_violations)}')
for v in nest_violations[:5]:
    print(f'NEST_V={v}')

print(f'TOTAL_FUNCTIONS={total_functions}')
print(f'TOTAL_CLASSES={total_classes}')
print(f'WOC_COUNT={len(woc_values)}')
if woc_values:
    woc_min = min(woc_values, key=lambda x: x[2])
    woc_max_v = max(woc_values, key=lambda x: x[2])
    print(f'WOC_MIN={woc_min[2]:.2f}')
    print(f'WOC_MAX={woc_max_v[2]:.2f}')
    print(f'WOC_MIN_LOC={woc_min[0]}:{woc_min[1]}')
else:
    print('WOC_MIN=N/A')
    print('WOC_MAX=N/A')
print('PARSE_OK=1')
" "$THRESHOLD_CC" "$THRESHOLD_NOP" "$THRESHOLD_NESTING" "$METRICS_JSON_FILE" 2>/dev/null)
        fi

        if echo "$METRICS_PARSED" | grep -q "PARSE_OK=1"; then
            # ── Extract parsed values ──
            CC_MAX_VAL=$(echo "$METRICS_PARSED" | grep '^CC_MAX=' | cut -d= -f2)
            CC_VIOLATIONS=$(echo "$METRICS_PARSED" | grep '^CC_VIOLATIONS=' | cut -d= -f2)
            CC_DETAILS=$(echo "$METRICS_PARSED" | grep '^CC_V=' | cut -d= -f2-)

            NOP_MAX_VAL=$(echo "$METRICS_PARSED" | grep '^NOP_MAX=' | cut -d= -f2)
            NOP_VIOLATIONS=$(echo "$METRICS_PARSED" | grep '^NOP_VIOLATIONS=' | cut -d= -f2)
            NOP_DETAILS=$(echo "$METRICS_PARSED" | grep '^NOP_V=' | cut -d= -f2-)

            NEST_MAX_VAL=$(echo "$METRICS_PARSED" | grep '^NEST_MAX=' | cut -d= -f2)
            NEST_VIOLATIONS=$(echo "$METRICS_PARSED" | grep '^NEST_VIOLATIONS=' | cut -d= -f2)
            NEST_DETAILS=$(echo "$METRICS_PARSED" | grep '^NEST_V=' | cut -d= -f2-)

            TOTAL_FUNCTIONS=$(echo "$METRICS_PARSED" | grep '^TOTAL_FUNCTIONS=' | cut -d= -f2)
            WOC_COUNT=$(echo "$METRICS_PARSED" | grep '^WOC_COUNT=' | cut -d= -f2)
            WOC_MIN=$(echo "$METRICS_PARSED" | grep '^WOC_MIN=' | cut -d= -f2)
            WOC_MAX=$(echo "$METRICS_PARSED" | grep '^WOC_MAX=' | cut -d= -f2)

            # ── Cyclomatic Complexity ──
            if [ "${CC_VIOLATIONS:-0}" -gt 0 ]; then
                print_error "Cyclomatic Complexity: ${CC_VIOLATIONS} funciones exceden limite (max: ${CC_MAX_VAL}, limite: ${THRESHOLD_CC})"
                echo "$CC_DETAILS" | head -5 | while IFS=: read -r f func val; do
                    printf "     ${DIM}%s:%s — CC %s${NC}\n" "$f" "$func" "$val"
                done
                CC_STATUS="fail"
                mark_failed "Cyclomatic Complexity"
            else
                print_success "Cyclomatic Complexity: OK (max: ${CC_MAX_VAL}, limite: ${THRESHOLD_CC})"
                CC_STATUS="pass"
            fi

            # ── Number of Parameters ──
            if [ "${NOP_VIOLATIONS:-0}" -gt 0 ]; then
                print_error "Number of Parameters: ${NOP_VIOLATIONS} funciones exceden limite (max: ${NOP_MAX_VAL}, limite: ${THRESHOLD_NOP})"
                echo "$NOP_DETAILS" | head -5 | while IFS=: read -r f func val; do
                    printf "     ${DIM}%s:%s — %s params${NC}\n" "$f" "$func" "$val"
                done
                NOP_STATUS="fail"
                mark_failed "Number of Parameters"
            else
                print_success "Number of Parameters: OK (max: ${NOP_MAX_VAL}, limite: ${THRESHOLD_NOP})"
                NOP_STATUS="pass"
            fi

            # ── Maximum Nesting Level ──
            if [ "${NEST_VIOLATIONS:-0}" -gt 0 ]; then
                print_error "Maximum Nesting Level: ${NEST_VIOLATIONS} funciones exceden limite (max: ${NEST_MAX_VAL}, limite: ${THRESHOLD_NESTING})"
                echo "$NEST_DETAILS" | head -5 | while IFS=: read -r f func val; do
                    printf "     ${DIM}%s:%s — nesting %s${NC}\n" "$f" "$func" "$val"
                done
                NEST_STATUS="fail"
                mark_failed "Maximum Nesting Level"
            else
                print_success "Maximum Nesting Level: OK (max: ${NEST_MAX_VAL}, limite: ${THRESHOLD_NESTING})"
                NEST_STATUS="pass"
            fi

            # ── Weight of Class (informational) ──
            if [ "${WOC_COUNT:-0}" -gt 0 ] && [ "$WOC_MIN" != "N/A" ]; then
                WOC_RANGE="${WOC_MIN} — ${WOC_MAX}"
                print_info "Weight of Class: rango ${WOC_RANGE} (${WOC_COUNT} clases)"
                WOC_STATUS="info"
            else
                print_info "Weight of Class: sin datos de clases"
                WOC_STATUS="info"
                WOC_RANGE="N/A"
            fi
        else
            # ── Fallback: console reporter ──
            print_warning "Metricas JSON no disponible — usando console reporter"
            METRICS_OUTPUT=$($METRICS_CMD analyze lib/ --reporter=console --set-exit-on-violation-level=noted 2>&1)

            # Parse console output for individual metric violations
            CC_CONSOLE=$(echo "$METRICS_OUTPUT" | grep -ci "cyclomatic-complexity" 2>/dev/null; true)
            NOP_CONSOLE=$(echo "$METRICS_OUTPUT" | grep -ci "number-of-parameters" 2>/dev/null; true)
            NEST_CONSOLE=$(echo "$METRICS_OUTPUT" | grep -ci "maximum-nesting-level\|nesting-level" 2>/dev/null; true)

            if [ "$CC_CONSOLE" -gt 0 ]; then
                print_error "Cyclomatic Complexity: ${CC_CONSOLE} violaciones detectadas"
                CC_STATUS="fail"
                mark_failed "Cyclomatic Complexity"
            else
                print_success "Cyclomatic Complexity: sin violaciones"
                CC_STATUS="pass"
            fi

            if [ "$NOP_CONSOLE" -gt 0 ]; then
                print_error "Number of Parameters: ${NOP_CONSOLE} violaciones detectadas"
                NOP_STATUS="fail"
                mark_failed "Number of Parameters"
            else
                print_success "Number of Parameters: sin violaciones"
                NOP_STATUS="pass"
            fi

            if [ "$NEST_CONSOLE" -gt 0 ]; then
                print_error "Maximum Nesting Level: ${NEST_CONSOLE} violaciones detectadas"
                NEST_STATUS="fail"
                mark_failed "Maximum Nesting Level"
            else
                print_success "Maximum Nesting Level: sin violaciones"
                NEST_STATUS="pass"
            fi

            WOC_STATUS="info"
            WOC_RANGE="N/A (console fallback)"
        fi

        # Cleanup handled by EXIT trap
    else
        # DCM not installed
        print_warning "dart_code_metrics no instalado. Instala con: dart pub global activate dart_code_metrics"
        CC_STATUS="skip"
        NOP_STATUS="skip"
        NEST_STATUS="skip"
        WOC_STATUS="skip"
    fi
else
    print_skip "Code metrics"
    CC_STATUS="skip"
    NOP_STATUS="skip"
    NEST_STATUS="skip"
    WOC_STATUS="skip"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY TABLE
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DURATION=$((SECONDS - SCRIPT_START))

print_summary() {
    local total_checks=0 pass_count=0 warn_count=0 fail_count=0 skip_count=0 info_count=0

    for status in "$FORMAT_STATUS" "$ANALYZE_STATUS" "$TESTS_STATUS" "$COVERAGE_STATUS" \
                  "$LINECOUNT_STATUS" "$SECRETS_STATUS" "$DEADCODE_STATUS" "$NOPRINT_STATUS" \
                  "$ARCH_STATUS" "$CC_STATUS" "$NOP_STATUS" "$NEST_STATUS"; do
        case "$status" in
            pass) pass_count=$((pass_count + 1)); total_checks=$((total_checks + 1)) ;;
            warn) warn_count=$((warn_count + 1)); total_checks=$((total_checks + 1)) ;;
            fail) fail_count=$((fail_count + 1)); total_checks=$((total_checks + 1)) ;;
            skip) skip_count=$((skip_count + 1)) ;;
        esac
    done
    # WOC is info-only, count separately
    if [ "$WOC_STATUS" = "info" ]; then
        info_count=1
    elif [ "$WOC_STATUS" = "skip" ]; then
        skip_count=$((skip_count + 1))
    fi

    printf "\n"
    printf "${BOLD}=======================================================================${NC}\n"
    printf "${BOLD}              RESUMEN DE CALIDAD — %s${NC}\n" "$MODE_UPPER"
    printf "${BOLD}=======================================================================${NC}\n"
    printf "\n"

    # Helper to print a summary row with emoji icons
    summary_row() {
        local icon="$1" label="$2" color="$3" status="$4" detail="$5"
        if [ -n "$detail" ]; then
            printf "  %s %-28s %b%-4s%b  %s\n" "$icon" "$label" "$color" "$status" "$NC" "$detail"
        else
            printf "  %s %-28s %b%s%b\n" "$icon" "$label" "$color" "$status" "$NC"
        fi
    }

    # ── Standard checks ──

    # 1. Format
    case "$FORMAT_STATUS" in
        pass) summary_row "✅" "Format" "$GREEN" "PASS" ;;
        fail) summary_row "❌" "Format" "$RED" "FAIL" ;;
        skip) [ -z "$ONLY_CHECKS" ] && summary_row "⏭️ " "Format" "$DIM" "SKIP" ;;
    esac

    # 2. Analyze
    case "$ANALYZE_STATUS" in
        pass) summary_row "✅" "Analyze" "$GREEN" "PASS" "0 issues" ;;
        warn) summary_row "⚠️ " "Analyze" "$YELLOW" "WARN" "${ANALYZE_ERRORS} errors, ${ANALYZE_WARNINGS} warnings, ${ANALYZE_INFOS} infos" ;;
        fail) summary_row "❌" "Analyze" "$RED" "FAIL" "${ANALYZE_ERRORS} errores" ;;
        skip) [ -z "$ONLY_CHECKS" ] && summary_row "⏭️ " "Analyze" "$DIM" "SKIP" ;;
    esac

    # 3. Tests
    case "$TESTS_STATUS" in
        pass)
            if [ "$MODE" = "pre-commit" ] && [ "$NEED_COVERAGE_FLAG" = false ]; then
                summary_row "✅" "Tests (unit)" "$GREEN" "PASS" "${TESTS_COUNT:-0} tests"
            else
                summary_row "✅" "Tests" "$GREEN" "PASS" "${TESTS_COUNT:-0} tests"
            fi ;;
        fail) summary_row "❌" "Tests" "$RED" "FAIL" "${TESTS_FAILED:-some} failed" ;;
        skip) [ -z "$ONLY_CHECKS" ] && summary_row "⏭️ " "Tests" "$DIM" "SKIP" ;;
    esac

    # 4. Coverage
    case "$COVERAGE_STATUS" in
        pass) summary_row "✅" "Coverage" "$GREEN" "${COVERAGE_PCT}%" ;;
        warn)
            if [ -n "$COVERAGE_PCT" ]; then
                summary_row "⚠️ " "Coverage" "$YELLOW" "${COVERAGE_PCT}%"
            else
                summary_row "⚠️ " "Coverage" "$YELLOW" "N/A"
            fi ;;
        fail) summary_row "❌" "Coverage" "$RED" "${COVERAGE_PCT}%" ;;
        skip) [ -z "$ONLY_CHECKS" ] && summary_row "⏭️ " "Coverage" "$DIM" "SKIP" ;;
    esac

    # 5. Line count
    case "$LINECOUNT_STATUS" in
        pass) summary_row "✅" "Line count (<=200)" "$GREEN" "PASS" ;;
        fail) summary_row "❌" "Line count (<=200)" "$RED" "FAIL" "${OVER_COUNT} archivos" ;;
        skip) [ -z "$ONLY_CHECKS" ] && summary_row "⏭️ " "Line count (<=200)" "$DIM" "SKIP" ;;
    esac

    # 6. Secrets
    case "$SECRETS_STATUS" in
        pass) summary_row "✅" "Secrets scan" "$GREEN" "PASS" ;;
        warn) summary_row "⚠️ " "Secrets scan" "$YELLOW" "WARN" ;;
        fail) summary_row "❌" "Secrets scan" "$RED" "FAIL" ;;
        skip) [ -z "$ONLY_CHECKS" ] && summary_row "⏭️ " "Secrets scan" "$DIM" "SKIP" ;;
    esac

    # 7. Dead code
    case "$DEADCODE_STATUS" in
        pass) summary_row "✅" "Dead code" "$GREEN" "PASS" ;;
        warn) summary_row "⚠️ " "Dead code" "$YELLOW" "WARN" "${DEADCODE_COUNT} items" ;;
        skip) [ -z "$ONLY_CHECKS" ] && summary_row "⏭️ " "Dead code" "$DIM" "SKIP" ;;
    esac

    # 8. No print()
    case "$NOPRINT_STATUS" in
        pass) summary_row "✅" "No print()" "$GREEN" "PASS" ;;
        warn) summary_row "⚠️ " "No print()" "$YELLOW" "WARN" "${NOPRINT_COUNT} calls" ;;
        skip) [ -z "$ONLY_CHECKS" ] && summary_row "⏭️ " "No print()" "$DIM" "SKIP" ;;
    esac

    # 9. Architecture layers
    case "$ARCH_STATUS" in
        pass) summary_row "✅" "Architecture layers" "$GREEN" "PASS" ;;
        warn) summary_row "⚠️ " "Architecture layers" "$YELLOW" "WARN" "${ARCH_SHARED_COUNT} shared→features" ;;
        fail) summary_row "❌" "Architecture layers" "$RED" "FAIL" "${ARCH_CORE_COUNT} core violations" ;;
        skip) [ -z "$ONLY_CHECKS" ] && summary_row "⏭️ " "Architecture layers" "$DIM" "SKIP" ;;
    esac

    # ── Code metrics (individual rows) ──

    # Show metrics separator only if at least one metric ran
    if [ "$CC_STATUS" != "skip" ] || [ "$NOP_STATUS" != "skip" ] || [ "$NEST_STATUS" != "skip" ] || [ "$WOC_STATUS" != "skip" ]; then
        printf "  ${DIM}--- Code Metrics (dart_code_metrics) -------------------------${NC}\n"
    fi

    # 9. Cyclomatic Complexity
    case "$CC_STATUS" in
        pass) summary_row "✅" "Cyclomatic Complexity" "$GREEN" "PASS" "max: ${CC_MAX_VAL} (<=${THRESHOLD_CC})" ;;
        fail) summary_row "❌" "Cyclomatic Complexity" "$RED" "FAIL" "${CC_VIOLATIONS} over limit (<=${THRESHOLD_CC})" ;;
        skip) [ -z "$ONLY_CHECKS" ] && summary_row "⏭️ " "Cyclomatic Complexity" "$DIM" "SKIP" ;;
    esac

    # 10. Number of Parameters
    case "$NOP_STATUS" in
        pass) summary_row "✅" "Number of Parameters" "$GREEN" "PASS" "max: ${NOP_MAX_VAL} (<=${THRESHOLD_NOP})" ;;
        fail) summary_row "❌" "Number of Parameters" "$RED" "FAIL" "${NOP_VIOLATIONS} over limit (<=${THRESHOLD_NOP})" ;;
        skip) [ -z "$ONLY_CHECKS" ] && summary_row "⏭️ " "Number of Parameters" "$DIM" "SKIP" ;;
    esac

    # 11. Maximum Nesting Level
    case "$NEST_STATUS" in
        pass) summary_row "✅" "Maximum Nesting Level" "$GREEN" "PASS" "max: ${NEST_MAX_VAL} (<=${THRESHOLD_NESTING})" ;;
        fail) summary_row "❌" "Maximum Nesting Level" "$RED" "FAIL" "${NEST_VIOLATIONS} over limit (<=${THRESHOLD_NESTING})" ;;
        skip) [ -z "$ONLY_CHECKS" ] && summary_row "⏭️ " "Maximum Nesting Level" "$DIM" "SKIP" ;;
    esac

    # 12. Weight of Class (info only)
    case "$WOC_STATUS" in
        info) summary_row "ℹ️ " "Weight of Class" "$CYAN" "INFO" "${WOC_RANGE:-N/A}" ;;
        skip) [ -z "$ONLY_CHECKS" ] && summary_row "⏭️ " "Weight of Class" "$DIM" "SKIP" ;;
    esac

    printf "\n"
    printf "${BOLD}-----------------------------------------------------------------------${NC}\n"

    # Final verdict
    if [ -n "$FAILED_CHECKS" ]; then
        printf "  ${RED}${BOLD}REQUIERE ATENCIÓN${NC} - Fallos en: ${RED}%s${NC}\n" "$FAILED_CHECKS"
        printf "  ${YELLOW}Recomendación: Arregla los errores antes de continuar${NC}\n"
    elif [ "$warn_count" -gt 0 ]; then
        printf "  ${YELLOW}${BOLD}OK${NC} - Listo (con warnings)\n"
    else
        printf "  ${GREEN}${BOLD}TODO OK${NC} - Listo\n"
    fi

    printf "${BOLD}-----------------------------------------------------------------------${NC}\n"
    local skip_info=""
    if [ "$skip_count" -gt 0 ] && [ -z "$ONLY_CHECKS" ] && [ -z "$SKIP_CHECKS" ]; then
        skip_info=" | ${skip_count} skipped"
    fi
    local flutter_ver
    flutter_ver=$($FLUTTER --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    printf "  ${DIM}Duracion: %s | Flutter: %s%s${NC}\n" "$(format_duration $SCRIPT_DURATION)" "$flutter_ver" "$skip_info"
    printf "${BOLD}-----------------------------------------------------------------------${NC}\n"
    printf "\n"
}

# ─── JSON Summary ──────────────────────────────────────────────────────────────

print_json_summary() {
    local exit_code=0
    [ -n "$FAILED_CHECKS" ] && exit_code=1

    local _vdir
    _vdir=$(mktemp -d /tmp/qc_json_XXXXXX)

    # Write violation data to temp files for python to read safely
    { echo "${FORMAT_OUTPUT:-}" | grep "Changed" || true; } > "$_vdir/format" 2>/dev/null
    { echo "${ANALYZE_CLEAN:-}" | grep -E " error | warning " || true; } > "$_vdir/analyze" 2>/dev/null
    { printf '%b\n' "${LINECOUNT_OVER:-}" || true; } > "$_vdir/linecount" 2>/dev/null
    echo "${PRINT_OUTPUT:-}" > "$_vdir/noprint" 2>/dev/null
    echo "${ARCH_CORE_OUTPUT:-}" > "$_vdir/arch_core" 2>/dev/null
    echo "${ARCH_SHARED_OUTPUT:-}" > "$_vdir/arch_shared" 2>/dev/null
    echo "${DEADCODE_OUTPUT:-}" > "$_vdir/deadcode" 2>/dev/null

    cat > "$_vdir/status" <<SDATA
mode=${MODE}
exit_code=${exit_code}
duration=${SCRIPT_DURATION}
format_status=${FORMAT_STATUS}
analyze_status=${ANALYZE_STATUS}
analyze_errors=${ANALYZE_ERRORS:-0}
analyze_warnings=${ANALYZE_WARNINGS:-0}
analyze_infos=${ANALYZE_INFOS:-0}
tests_status=${TESTS_STATUS}
tests_count=${TESTS_COUNT:-0}
tests_passed=${TESTS_PASSED:-0}
tests_failed=${TESTS_FAILED:-0}
coverage_status=${COVERAGE_STATUS}
coverage_pct=${COVERAGE_PCT:-}
linecount_status=${LINECOUNT_STATUS}
secrets_status=${SECRETS_STATUS}
deadcode_status=${DEADCODE_STATUS}
noprint_status=${NOPRINT_STATUS}
arch_status=${ARCH_STATUS}
cc_status=${CC_STATUS}
cc_max=${CC_MAX_VAL:-0}
cc_violations=${CC_VIOLATIONS:-0}
cc_threshold=${THRESHOLD_CC}
nop_status=${NOP_STATUS}
nop_max=${NOP_MAX_VAL:-0}
nop_violations=${NOP_VIOLATIONS:-0}
nop_threshold=${THRESHOLD_NOP}
nest_status=${NEST_STATUS}
nest_max=${NEST_MAX_VAL:-0}
nest_violations=${NEST_VIOLATIONS:-0}
nest_threshold=${THRESHOLD_NESTING}
woc_status=${WOC_STATUS}
woc_range=${WOC_RANGE:-N/A}
failed_checks=${FAILED_CHECKS}
SDATA

    python3 - "$_vdir" <<'PYEOF'
import json, sys, os

vdir = sys.argv[1]

def read_lines(name):
    path = os.path.join(vdir, name)
    try:
        with open(path) as f:
            return [l.strip() for l in f if l.strip()]
    except FileNotFoundError:
        return []

def read_status():
    d = {}
    with open(os.path.join(vdir, "status")) as f:
        for line in f:
            line = line.strip()
            if "=" in line:
                k, v = line.split("=", 1)
                d[k] = v
    return d

def safe_int(val):
    try:
        return int(val)
    except (ValueError, TypeError):
        return 0

s = read_status()
failed = [x.strip() for x in s.get("failed_checks", "").split(",") if x.strip()]

cov_pct = s.get("coverage_pct", "")
coverage_val = safe_int(cov_pct) if cov_pct else None

data = {
    "version": "1.0",
    "mode": s["mode"],
    "exit_code": safe_int(s["exit_code"]),
    "duration_seconds": safe_int(s["duration"]),
    "checks": {
        "format": {
            "status": s["format_status"],
            "violations": read_lines("format")
        },
        "analyze": {
            "status": s["analyze_status"],
            "errors": safe_int(s["analyze_errors"]),
            "warnings": safe_int(s["analyze_warnings"]),
            "infos": safe_int(s["analyze_infos"]),
            "violations": read_lines("analyze")
        },
        "tests": {
            "status": s["tests_status"],
            "total": safe_int(s["tests_count"]),
            "passed": safe_int(s["tests_passed"]),
            "failed": safe_int(s["tests_failed"]),
            "violations": []
        },
        "coverage": {
            "status": s["coverage_status"],
            "percent": coverage_val,
            "violations": []
        },
        "linecount": {
            "status": s["linecount_status"],
            "violations": read_lines("linecount")
        },
        "secrets": {
            "status": s["secrets_status"],
            "violations": []
        },
        "deadcode": {
            "status": s["deadcode_status"],
            "violations": read_lines("deadcode")
        },
        "noprint": {
            "status": s["noprint_status"],
            "violations": read_lines("noprint")
        },
        "architecture": {
            "status": s["arch_status"],
            "violations": read_lines("arch_core") + read_lines("arch_shared")
        },
        "metrics": {
            "cyclomatic_complexity": {
                "status": s["cc_status"],
                "max_value": safe_int(s["cc_max"]),
                "threshold": safe_int(s["cc_threshold"]),
                "violations": safe_int(s["cc_violations"])
            },
            "number_of_parameters": {
                "status": s["nop_status"],
                "max_value": safe_int(s["nop_max"]),
                "threshold": safe_int(s["nop_threshold"]),
                "violations": safe_int(s["nop_violations"])
            },
            "maximum_nesting_level": {
                "status": s["nest_status"],
                "max_value": safe_int(s["nest_max"]),
                "threshold": safe_int(s["nest_threshold"]),
                "violations": safe_int(s["nest_violations"])
            },
            "weight_of_class": {
                "status": s["woc_status"],
                "range": s.get("woc_range", "N/A")
            }
        }
    },
    "failed_checks": failed,
    "summary": "FAIL: {}".format(", ".join(failed)) if failed else "All checks passed"
}

print(json.dumps(data, indent=2))
PYEOF

    rm -rf "$_vdir"
}

# ─── GitHub Actions Summary ────────────────────────────────────────────────────

print_github_summary() {
    [ -z "$GITHUB_STEP_SUMMARY" ] && return

    {
        echo "## Quality Check Results — ${MODE_UPPER}"
        echo ""
        echo "| Check | Status | Details |"
        echo "|-------|--------|---------|"

        case "$FORMAT_STATUS" in
            pass) echo "| Format | PASS | Code formatted |" ;;
            fail) echo "| Format | FAIL | Unformatted files |" ;;
            skip) echo "| Format | SKIP | |" ;;
        esac

        case "$ANALYZE_STATUS" in
            pass) echo "| Analyze | PASS | No issues |" ;;
            warn) echo "| Analyze | WARN | ${ANALYZE_ISSUES:-some} issues |" ;;
            fail) echo "| Analyze | FAIL | ${ANALYZE_ERRORS} errors |" ;;
            skip) echo "| Analyze | SKIP | |" ;;
        esac

        case "$TESTS_STATUS" in
            pass) echo "| Tests | PASS | ${TESTS_COUNT:-All} tests passed |" ;;
            fail) echo "| Tests | FAIL | Test failures |" ;;
            skip) echo "| Tests | SKIP | |" ;;
        esac

        case "$COVERAGE_STATUS" in
            pass) echo "| Coverage | ${COVERAGE_PCT}% | Excellent |" ;;
            warn) echo "| Coverage | WARN | ${COVERAGE_PCT:-N/A}% |" ;;
            fail) echo "| Coverage | ${COVERAGE_PCT}% | Below 80% |" ;;
            skip) echo "| Coverage | SKIP | |" ;;
        esac

        case "$LINECOUNT_STATUS" in
            pass) echo "| Line count | PASS | All <=200 lines |" ;;
            fail) echo "| Line count | FAIL | ${OVER_COUNT} files over limit |" ;;
            skip) echo "| Line count | SKIP | |" ;;
        esac

        case "$SECRETS_STATUS" in
            pass) echo "| Secrets | PASS | No secrets found |" ;;
            warn) echo "| Secrets | WARN | Possible secrets |" ;;
            fail) echo "| Secrets | FAIL | Secrets detected |" ;;
            skip) echo "| Secrets | SKIP | |" ;;
        esac

        case "$DEADCODE_STATUS" in
            pass) echo "| Dead code | PASS | No unused code |" ;;
            warn) echo "| Dead code | WARN | ${DEADCODE_COUNT} items |" ;;
            skip) echo "| Dead code | SKIP | |" ;;
        esac

        case "$NOPRINT_STATUS" in
            pass) echo "| No print() | PASS | Clean |" ;;
            warn) echo "| No print() | WARN | ${NOPRINT_COUNT} calls |" ;;
            skip) echo "| No print() | SKIP | |" ;;
        esac

        case "$ARCH_STATUS" in
            pass) echo "| Architecture | PASS | Import rules OK |" ;;
            warn) echo "| Architecture | WARN | ${ARCH_SHARED_COUNT} shared→features imports |" ;;
            fail) echo "| Architecture | FAIL | ${ARCH_CORE_COUNT} core violations |" ;;
            skip) echo "| Architecture | SKIP | |" ;;
        esac

        echo "| **Code Metrics** | | |"

        case "$CC_STATUS" in
            pass) echo "| Cyclomatic Complexity | PASS | max: ${CC_MAX_VAL} (<=${THRESHOLD_CC}) |" ;;
            fail) echo "| Cyclomatic Complexity | FAIL | ${CC_VIOLATIONS} violations (limit: ${THRESHOLD_CC}) |" ;;
            skip) echo "| Cyclomatic Complexity | SKIP | |" ;;
        esac

        case "$NOP_STATUS" in
            pass) echo "| Number of Parameters | PASS | max: ${NOP_MAX_VAL} (<=${THRESHOLD_NOP}) |" ;;
            fail) echo "| Number of Parameters | FAIL | ${NOP_VIOLATIONS} violations (limit: ${THRESHOLD_NOP}) |" ;;
            skip) echo "| Number of Parameters | SKIP | |" ;;
        esac

        case "$NEST_STATUS" in
            pass) echo "| Maximum Nesting Level | PASS | max: ${NEST_MAX_VAL} (<=${THRESHOLD_NESTING}) |" ;;
            fail) echo "| Maximum Nesting Level | FAIL | ${NEST_VIOLATIONS} violations (limit: ${THRESHOLD_NESTING}) |" ;;
            skip) echo "| Maximum Nesting Level | SKIP | |" ;;
        esac

        case "$WOC_STATUS" in
            info) echo "| Weight of Class | INFO | range: ${WOC_RANGE:-N/A} |" ;;
            skip) echo "| Weight of Class | SKIP | |" ;;
        esac

        echo ""
        echo "Duration: $(format_duration $SCRIPT_DURATION)"
        echo ""
        if [ -n "$FAILED_CHECKS" ]; then
            echo "### Failed: ${FAILED_CHECKS}"
        else
            echo "### All critical checks passed"
        fi
    } >> "$GITHUB_STEP_SUMMARY"
}

# ─── RUN SUMMARIES ─────────────────────────────────────────────────────────────

if [ "$OUTPUT_FORMAT" = "json" ]; then
    print_json_summary
else
    print_summary
    print_github_summary
fi

# ─── EXIT CODE ─────────────────────────────────────────────────────────────────

if [ -n "$FAILED_CHECKS" ]; then
    exit 1
else
    exit 0
fi
