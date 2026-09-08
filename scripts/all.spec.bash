#!/usr/bin/env bash
# scripts/all.spec.bash — combined spec runner. Run: bash scripts/all.spec.bash
set -u
SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/specs"
# shellcheck source=scripts/specs/test-utils.bash
source "$SPEC_DIR/test-utils.bash"

# One entry per ported lib module; appended wave by wave.
for spec in common helpers lookups yarn preflight deps node workflows cli upgrade; do
  source "$SPEC_DIR/$spec.spec.bash"
done

printf 'PASS: %d FAIL: %d\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
