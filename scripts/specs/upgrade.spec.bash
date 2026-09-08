#!/usr/bin/env bash
# scripts/specs/upgrade.spec.bash — outer-shell spec for scripts/upgrade.sh
# (entry-point integration: main's phase dispatch, phase_summary, bottom
# execution guard). Arg-parsing units live in cli.spec.bash.
# Standalone: bash scripts/specs/upgrade.spec.bash
set -u
SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPGRADE_SH="$SPEC_DIR/../upgrade.sh"
# shellcheck source=scripts/specs/test-utils.bash
source "$SPEC_DIR/test-utils.bash"
# Source with the escape hatch set: the orchestrator must never run phases on
# load, and the variable documents that intent at the spec's single source site.
UPGRADE_SH_SOURCE_ONLY=1
# shellcheck source=scripts/upgrade.sh
source "$UPGRADE_SH"
# The sourced entry point hardens IFS; restore the default for spec-internal string ops.
IFS=$' \t\n'

# The combined runner sources every spec into one shell; a stale exported
# DRY_RUN from another spec (e.g. cli.spec's dry-run parse) must not leak
# into these dispatch tests.
unset DRY_RUN

# Scratch space for fixtures; test-utils' cleanup registry removes it even on
# a crashed run (its single EXIT trap survives the combined runner, where a
# local trap would be overwritten by the next sourced spec).
spec_tmp="${TMPDIR:-/tmp}/upgrade-spec.$$"
mkdir -p "$spec_tmp"
register_tmp "$spec_tmp"

# --- phase_summary (real implementation against a read-only fixture repo) ---
summary_repo="$spec_tmp/summary"
mkdir -p "$summary_repo"
printf '{\n\t"packageManager": "yarn@4.18.0"\n}\n' > "$summary_repo/package.json"
printf 'nodejs 24.9.0\n' > "$summary_repo/.tool-versions"
summary_out="$(
  REPO_DIR="$summary_repo"
  WANT_ALL=0 WANT_YARN=0 WANT_NODE=0 WANT_DEPS=1 WANT_DEV_DEPS=0
  WANT_TRANSITIVE=1 WANT_WORKFLOWS=0
  phase_summary
)"
assert_eq "$summary_out" \
  $'summary: ran [deps transitive]\nsummary: resolved yarn=yarn@4.18.0 node=24.9.0\nsummary: inspect \'git diff\' before committing\nsummary: reminder: NODE_VERSION is a GitHub repo variable — update it in GitHub settings' \
  "phase_summary logs the selection, resolved yarn/node, the git-diff reminder, and the NODE_VERSION reminder"

# --- dispatch: phases shadowed to append their name to a call-order file, so
# each main invocation's dispatched sequence can be asserted afterwards ---

record() {
  printf '%s\n' "$1" >> "$spec_tmp/calls"
}

phase_preflight() { record preflight; }
phase_yarn() { record yarn; }
phase_node() { record node; }
phase_deps() { record deps; }
phase_dev_deps() { record dev-deps; }
phase_transitive() { record transitive; }
phase_workflows() { record workflows; }
phase_summary() { record summary; }

recorded_order() {
  # Join the recorded names with single spaces for a one-line comparison.
  local line
  line="$(tr '\n' ' ' < "$spec_tmp/calls")"
  printf '%s' "${line% }"
}

# --- main --all dispatches preflight + all six phases + summary, in order ---
: > "$spec_tmp/calls"
main --all >/dev/null
assert_eq "$(recorded_order)" \
  "preflight yarn node deps dev-deps transitive workflows summary" \
  "main --all dispatches all six phases in canonical order"

# --- main -w: preflight -> workflows -> summary, exactly ---
: > "$spec_tmp/calls"
main -w >/dev/null
assert_eq "$(recorded_order)" "preflight workflows summary" \
  "main -w dispatches preflight workflows summary only"

# --- main -dD: preflight -> deps -> dev-deps -> summary, exactly ---
: > "$spec_tmp/calls"
main -dD >/dev/null
assert_eq "$(recorded_order)" "preflight deps dev-deps summary" \
  "main -dD dispatches preflight deps dev-deps summary only"

# --- hard-error dispatch: a failing phase must abort the whole run — no later
# phase dispatched, no summary, non-zero exit (blast-radius control) ---
phase_deps() { record deps; return 1; }
: > "$spec_tmp/calls"
rc=0
out="$( { main -d 2>&1 1>/dev/null; } )" || rc=$?
assert_status "$rc" 1 "main aborts with non-zero exit when a phase fails"
assert_contains "$out" "phase_deps failed" "main reports which phase failed on stderr"
assert_eq "$(recorded_order)" "preflight deps" \
  "a failing phase stops dispatch: later phases and summary are never run"

# restore the happy-path shadow for the remaining tests
phase_deps() { record deps; }

# --- parse failures abort before any dispatch: a main invocation whose args
# don't parse must exit 2 with zero phases run — not even phase_preflight ---
: > "$spec_tmp/calls"
rc=0
( main ) 2>/dev/null || rc=$?
assert_status "$rc" 2 "main with no selection exits 2"
assert_eq "$(recorded_order)" "" \
  "main with no selection dispatches zero phases (not even preflight)"

: > "$spec_tmp/calls"
rc=0
( main --bogus ) 2>/dev/null || rc=$?
assert_status "$rc" 2 "main --bogus exits 2"
assert_eq "$(recorded_order)" "" \
  "main --bogus dispatches zero phases (not even preflight)"

# --- --help: usage on stdout, exit 0, safe because parse-only ---
help_rc=0
help_out="$(bash "$UPGRADE_SH" --help)" || help_rc=$?
assert_status "$help_rc" 0 "--help exits 0"
assert_contains "$help_out" "Usage:" "--help prints the usage text to stdout"

# --- bottom execution guard: stub PATH makes preflight deterministically die ---
stubdir="$spec_tmp/stub"
mkdir -p "$stubdir"
for guard_tool in yarn git gh jq yq curl asdf; do
  printf '#!/usr/bin/env sh\nexit 9\n' > "$stubdir/$guard_tool"
  chmod +x "$stubdir/$guard_tool"
done

# Sourced (in a fresh subshell, no escape hatch): guard must NOT fire — exits 0.
rc=0
(
  PATH="$stubdir:$PATH"
  unset UPGRADE_SH_SOURCE_ONLY
  source "$UPGRADE_SH" >/dev/null 2>&1
) || rc=$?
assert_status "$rc" 0 "sourcing upgrade.sh never executes phases (guard honored)"

# Direct execution: guard fires, main runs, preflight dies on the stub PATH.
# A selection is required to get past arg parsing and reach preflight.
rc=0
(
  PATH="$stubdir:$PATH"
  unset UPGRADE_SH_SOURCE_ONLY
  bash "$UPGRADE_SH" --all >/dev/null 2>&1
) || rc=$?
assert_status "$rc" 1 "direct execution dispatches main (preflight dies on stub PATH)"

# Direct execution with UPGRADE_SH_SOURCE_ONLY=1: escape hatch suppresses main.
rc=0
(
  PATH="$stubdir:$PATH"
  export UPGRADE_SH_SOURCE_ONLY=1
  bash "$UPGRADE_SH" --all >/dev/null 2>&1
) || rc=$?
assert_status "$rc" 0 "UPGRADE_SH_SOURCE_ONLY=1 suppresses main on direct execution"

# Bottom guard: standalone run prints totals; sourced run defers to the runner.
finish_spec
