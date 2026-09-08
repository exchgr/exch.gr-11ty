#!/usr/bin/env bash
# scripts/specs/test-utils.bash — shared assert library for all per-module specs.
# Counter semantics: PASS/FAIL are shared across specs; sourcing this file never
# resets counters that already exist (the combined runner sources it once).
if [[ -z "${PASS+x}" || -z "${FAIL+x}" ]]; then
  PASS=0
  FAIL=0
fi

# Fixture-dir cleanup registry. Bash allows only ONE EXIT trap, so a per-spec
# `trap 'rm -rf ...' EXIT` is overwritten by the next sourced spec in the
# combined runner, leaking every earlier mktemp fixture. Specs register their
# fixture dirs here instead; the single trap below wipes them all on EXIT.
CLEANUP_DIRS=()

register_tmp() {
  CLEANUP_DIRS+=("$1")
}

cleanup_tmp_dirs() {
  # Bash 3.2 with `set -u`: expanding an EMPTY array via "${arr[@]}" errors,
  # so expand only when entries exist.
  if [[ ${#CLEANUP_DIRS[@]} -gt 0 ]]; then
    rm -rf "${CLEANUP_DIRS[@]}"
  fi
}

trap cleanup_tmp_dirs EXIT

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  expected: <%s>\n  actual:   <%s>\n' "$label" "$expected" "$actual" >&2
  fi
}

assert_status() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  expected status: <%s>\n  actual status:   <%s>\n' "$label" "$expected" "$actual" >&2
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  expected to contain: <%s>\n  actual: <%s>\n' "$label" "$needle" "$haystack" >&2
  fi
}

# Bottom guard shared by every spec: a standalone run prints totals and exits
# on FAIL; a sourced run (the combined runner) defers — the runner owns the
# single combined totals print. BASH_SOURCE[1] is the spec that called this,
# which equals $0 exactly when that spec is the executing script.
finish_spec() {
  if [[ "${BASH_SOURCE[1]}" == "$0" ]]; then
    printf 'PASS: %d FAIL: %d\n' "$PASS" "$FAIL"
    if [[ "$FAIL" -gt 0 ]]; then
      exit 1
    fi
    exit 0
  fi
}

# Bottom guard for test-utils itself (standalone run of the library only).
# Self-test: a subshell does NOT inherit this shell's EXIT trap, so the test
# sources the library inside a real child process that registers a fixture
# and relies on the EXIT-time cleanup contract.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  selftest_dir="$(mktemp -d)"
  bash -c 'source "$1"; register_tmp "$2"; printf "canary\n" > "$2/canary"' \
    _ "$BASH_SOURCE" "$selftest_dir" 2>/dev/null
  if [[ -e "$selftest_dir/canary" ]]; then
    FAIL=$((FAIL + 1))
    printf 'FAIL: register_tmp does not remove the registered dir on EXIT\n' >&2
  else
    PASS=$((PASS + 1))
  fi
  printf 'PASS: %d FAIL: %d\n' "$PASS" "$FAIL"
  if [[ "$FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
fi
