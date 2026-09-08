#!/usr/bin/env bash
# scripts/specs/cli.spec.bash — spec for scripts/lib/cli.bash (arg parsing only:
# flags -> WANT_* selection booleans, usage text, error exits).
# Standalone: bash scripts/specs/cli.spec.bash
set -u
SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/specs/test-utils.bash
source "$SPEC_DIR/test-utils.bash"
# shellcheck source=scripts/lib/cli.bash
source "$SPEC_DIR/../lib/cli.bash"
# The sourced lib hardens IFS; restore the default for spec-internal string ops.
IFS=$' \t\n'

reset_selection() {
  WANT_ALL=0 WANT_YARN=0 WANT_NODE=0 WANT_DEPS=0 WANT_DEV_DEPS=0
  WANT_TRANSITIVE=0 WANT_WORKFLOWS=0
  DRY_RUN=0
}

# Maps a phase short flag to its WANT_* value; the long/short equivalence loop
# below compares short-flag runs against long-flag runs through this lens.
want_flag_value() {
  case "$1" in
    a) printf '%s' "$WANT_ALL" ;;
    y) printf '%s' "$WANT_YARN" ;;
    n) printf '%s' "$WANT_NODE" ;;
    d) printf '%s' "$WANT_DEPS" ;;
    D) printf '%s' "$WANT_DEV_DEPS" ;;
    t) printf '%s' "$WANT_TRANSITIVE" ;;
    w) printf '%s' "$WANT_WORKFLOWS" ;;
  esac
}

# --- single short flags select exactly their phase ---
for pair in a:all y:yarn n:node d:dependencies D:dev-deps t:transitive w:workflows; do
  short="${pair%%:*}"
  long="--${pair#*:}"
  reset_selection
  parse_args "-$short"
  assert_eq "$(want_flag_value "$short")" "1" "parse_args -$short selects $long"
done

# --- combined shorts -dt select exactly deps + transitive ---
reset_selection
parse_args -dt
assert_eq "$WANT_DEPS" "1" "parse_args -dt selects deps"
assert_eq "$WANT_TRANSITIVE" "1" "parse_args -dt selects transitive"
assert_eq "$WANT_YARN" "0" "parse_args -dt does not select yarn"
assert_eq "$WANT_ALL" "0" "parse_args -dt does not select all"
assert_eq "$DRY_RUN" "0" "parse_args -dt does not set dry-run"

# --- combined shorts -dD select deps + dev-deps (uppercase D is dev-deps) ---
reset_selection
parse_args -dD
assert_eq "$WANT_DEPS" "1" "parse_args -dD selects deps"
assert_eq "$WANT_DEV_DEPS" "1" "parse_args -dD selects dev-deps"
assert_eq "$WANT_TRANSITIVE" "0" "parse_args -dD does not select transitive"

# --- --all selects everything ---
reset_selection
parse_args --all
assert_eq "$WANT_ALL" "1" "parse_args --all selects all"
assert_eq "$WANT_YARN" "0" "parse_args --all leaves individual flags untouched (orchestrator reads WANT_ALL)"

# --- long/short equivalence for every phase flag ---
for pair in a:all y:yarn n:node d:dependencies D:dev-deps t:transitive w:workflows; do
  short="${pair%%:*}"
  long="--${pair#*:}"
  reset_selection
  parse_args "-$short"
  short_value="$(want_flag_value "$short")"
  reset_selection
  parse_args "$long"
  assert_eq "$(want_flag_value "$short")" "$short_value" "parse_args $long matches -$short"
done

# --- dry-run long/short equivalence + composition with a selection ---
reset_selection
parse_args --dry-run -y
assert_eq "$DRY_RUN" "1" "parse_args --dry-run sets DRY_RUN"
assert_eq "$WANT_YARN" "1" "parse_args --dry-run -y still selects yarn"

reset_selection
parse_args -ry
assert_eq "$DRY_RUN" "1" "parse_args -ry sets DRY_RUN like --dry-run"
assert_eq "$WANT_YARN" "1" "parse_args -ry still selects yarn"

# A later parse without -r must not inherit the earlier dry-run: parse_args
# defines the complete selection state every time it runs.
parse_args -y
assert_eq "$DRY_RUN" "0" "parse_args -y after a dry-run parse resets DRY_RUN"
assert_eq "$WANT_YARN" "1" "parse_args -y selects yarn"

# Runner-scope hygiene: nothing this spec parsed may leak into later specs
# (the combined runner sources every spec into one shell).
unset DRY_RUN

# --- --workflows long form ---
reset_selection
parse_args --workflows
assert_eq "$WANT_WORKFLOWS" "1" "parse_args --workflows selects workflows"

# --- -h short form: usage to stdout, exit 0 ---
rc=0
help_out="$( { parse_args -h; } )" || rc=$?
assert_status "$rc" 0 "parse_args -h exits 0"
assert_contains "$help_out" "Usage:" "parse_args -h prints usage to stdout"

# --- --help long form: usage to stdout, exit 0 ---
rc=0
help_out="$( { parse_args --help; } )" || rc=$?
assert_status "$rc" 0 "parse_args --help exits 0"
assert_contains "$help_out" "Usage:" "parse_args --help prints usage to stdout"

# --- no selection: usage on stderr, exit 2 ---
rc=0
err="$( { parse_args 2>&1 1>/dev/null; } )" || rc=$?
assert_status "$rc" 2 "parse_args with no selection exits 2"
assert_contains "$err" "no phases selected" "parse_args no-selection explains the error"
assert_contains "$err" "Usage:" "parse_args no-selection prints usage to stderr"

# --- unknown flag: usage error, exit 2 ---
rc=0
( parse_args --bogus ) 2>/dev/null || rc=$?
assert_status "$rc" 2 "parse_args --bogus exits 2"

rc=0
( parse_args -z ) 2>/dev/null || rc=$?
assert_status "$rc" 2 "parse_args -z exits 2"

# --- leftover positional operand: usage error, exit 2 ---
rc=0
( parse_args bogus-arg ) 2>/dev/null || rc=$?
assert_status "$rc" 2 "parse_args positional argument exits 2"

rc=0
( parse_args -y leftover-arg ) 2>/dev/null || rc=$?
assert_status "$rc" 2 "parse_args selection followed by positional exits 2"

# --- usage text lists every flag ---
usage_text="$(usage)"
for flag in --all --yarn --node --dependencies --dev-deps --transitive --workflows --dry-run --help; do
  assert_contains "$usage_text" "$flag" "usage mentions $flag"
done

# --- usage text describes the 11ty phases (canonical order yarn..workflows) ---
assert_contains "$usage_text" "yarn" "usage describes the yarn phase"
assert_contains "$usage_text" "asdf" "usage describes the node phase (asdf LTS pin)"
assert_contains "$usage_text" "dependency" "usage describes the deps phase"
assert_contains "$usage_text" "devDependencies" "usage describes the dev-deps phase"
assert_contains "$usage_text" "transitive" "usage describes the transitive phase"
assert_contains "$usage_text" "GitHub Actions" "usage describes the workflows phase"

# Bottom guard: standalone run prints totals; sourced run defers to the runner.
finish_spec
