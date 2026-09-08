#!/usr/bin/env bash
# scripts/upgrade.sh — thin orchestrator for the idempotent exch.gr 11ty
# upgrade. cli.bash parses the flags into WANT_* selection booleans; main then
# conditionally runs each phase in canonical order (preflight always first,
# summary always last). --dry-run composes with any selection and prints every
# mutation without applying it.
set -uo pipefail
IFS=$'\n\t'

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
source "$LIB_DIR/common.bash"
source "$LIB_DIR/helpers.bash"
source "$LIB_DIR/lookups.bash"
source "$LIB_DIR/preflight.bash"
source "$LIB_DIR/yarn.bash"
source "$LIB_DIR/node.bash"
source "$LIB_DIR/deps.bash"
source "$LIB_DIR/workflows.bash"
source "$LIB_DIR/cli.bash"

# --- orchestrator ------------------------------------------------------------------

# Read-only closing report: what ran, where yarn/node now stand, the reminder
# to review the diff before committing, and the NODE_VERSION note. No side
# effects. NODE_VERSION is a GitHub repo variable — the one input this script
# cannot manage from the repo — so the reminder prints unconditionally.
phase_summary() {
  local ran="all"
  if (( ! WANT_ALL )); then
    ran=""
    (( WANT_YARN )) && ran+=" yarn"
    (( WANT_NODE )) && ran+=" node"
    (( WANT_DEPS )) && ran+=" deps"
    (( WANT_DEV_DEPS )) && ran+=" dev-deps"
    (( WANT_TRANSITIVE )) && ran+=" transitive"
    (( WANT_WORKFLOWS )) && ran+=" workflows"
    ran="${ran# }"
  fi
  local yarn_version node_version
  yarn_version="$(current_yarn_version)"
  node_version="$(current_node_pin)"
  log "summary: ran [$ran]"
  log "summary: resolved yarn=${yarn_version:-unknown} node=${node_version:-unset}"
  log "summary: inspect 'git diff' before committing"
  log "summary: reminder: NODE_VERSION is a GitHub repo variable — update it in GitHub settings"
}

# --- entry point -------------------------------------------------------------------

# Blast-radius control: run one phase and abort the whole run on any failure.
# Under set -uo pipefail (no -e) a bare failing phase would return non-zero and
# main would silently continue mutating — unacceptable, so every phase goes
# through here and a failure stops the run with a non-zero exit.
dispatch_phase() {
  "$@" || die "$1 failed"
}

main() {
  parse_args "$@"
  dispatch_phase phase_preflight
  if (( WANT_ALL || WANT_YARN )); then dispatch_phase phase_yarn; fi
  if (( WANT_ALL || WANT_NODE )); then dispatch_phase phase_node; fi
  if (( WANT_ALL || WANT_DEPS )); then dispatch_phase phase_deps; fi
  if (( WANT_ALL || WANT_DEV_DEPS )); then dispatch_phase phase_dev_deps; fi
  if (( WANT_ALL || WANT_TRANSITIVE )); then dispatch_phase phase_transitive; fi
  if (( WANT_ALL || WANT_WORKFLOWS )); then dispatch_phase phase_workflows; fi
  dispatch_phase phase_summary
}

# Bottom execution guard: never run phases when sourced (also honors the
# spec harness's UPGRADE_SH_SOURCE_ONLY escape hatch). Lives only here.
if [[ "${BASH_SOURCE[0]}" == "$0" && "${UPGRADE_SH_SOURCE_ONLY:-0}" != "1" ]]; then
  main "$@"
fi
