#!/usr/bin/env bash
# scripts/specs/lookups.spec.bash — spec for scripts/lib/lookups.bash (fetch-seam lookups).
# Standalone: bash scripts/specs/lookups.spec.bash
set -u
SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/specs/test-utils.bash
source "$SPEC_DIR/test-utils.bash"
# shellcheck source=scripts/lib/lookups.bash
source "$SPEC_DIR/../lib/lookups.bash"
# The sourced lib hardens IFS; restore the default for spec-internal string ops.
IFS=$' \t\n'

ltmp="$(mktemp -d)"
register_tmp "$ltmp"

# --- parse_node_lts (index.json is newest-first: skip non-LTS entries) ---
node_lts_fixture='[{"version":"v25.0.0","lts":false},{"version":"v24.99.0","lts":"Jod"}]'
assert_eq "$(parse_node_lts <<<"$node_lts_fixture")" "24.99.0" "parse_node_lts skips non-LTS v25, picks v24.99.0"

# --- parse_uses_line ---
assert_eq "$(parse_uses_line "uses: actions/checkout@v7")" "actions/checkout v7" "parse_uses_line actions/checkout@v7"
assert_eq "$(parse_uses_line "uses: superfly/flyctl-actions/setup-flyctl@v1.4")" "superfly/flyctl-actions/setup-flyctl v1.4" "parse_uses_line nested repo path"
assert_eq "$(parse_uses_line "- uses: actions/cache@v4")" "actions/cache v4" "parse_uses_line tolerates a list-dash prefix"

# Negative case: a `uses:` line with no @ref fails the parse contract.
uses_rc=0
uses_out="$(parse_uses_line "uses: actions/checkout")" || uses_rc=$?
assert_status "$uses_rc" 1 "parse_uses_line returns 1 for a uses: line with no @ref"
assert_eq "$uses_out" "" "parse_uses_line prints nothing for a refless uses: line"

# --- parse_remote_tags (pure fallback parsing behind latest_tag_for_repo) ---
remote_tags_fixture='abc123	refs/tags/v9.1.0
def456	refs/tags/v10.2.0
abc123^{}	refs/tags/v10.2.0
zzz	refs/tags/some-branch'
assert_eq "$(parse_remote_tags <<<"$remote_tags_fixture")" "v10.2.0" "parse_remote_tags strips refs, filters ^v, picks highest"
assert_eq "$(printf 'abc\trefs/tags/main\n' | parse_remote_tags)" "" "parse_remote_tags no vtags -> empty"

# --- latest_* wrappers: network confined behind PATH-stubbed executables ---
# Each stub shadows the real binary only for the subshell run on the modified
# PATH, so the wiring (fetch -> parse) is proven with zero network access.
stubbin="$ltmp/bin"
mkdir -p "$stubbin"
stub() { # name body: write an executable stub for PATH-prefixed subshells
  printf '#!/usr/bin/env bash\n%s\n' "$2" > "$stubbin/$1"
  chmod +x "$stubbin/$1"
}

# latest_node_lts: stub curl cats a fixture, proving the wrapper pipes its
# fetch output into the pure parser.
node_index_fixture="$ltmp/node-index.json"
printf '%s' "$node_lts_fixture" > "$node_index_fixture"
stub curl 'cat "$LOOKUPS_CURL_FIXTURE"'
out="$(LOOKUPS_CURL_FIXTURE="$node_index_fixture" PATH="$stubbin:$PATH" latest_node_lts)"
assert_eq "$out" "24.99.0" "latest_node_lts pipes the curl fetch through parse_node_lts"

# --- latest_tag_for_repo (command seam: gh first, git ls-remote fallback) ---
stub gh 'printf "v4.1.0\n"'
out="$(PATH="$stubbin:$PATH" latest_tag_for_repo "owner/repo")"
assert_eq "$out" "v4.1.0" "latest_tag_for_repo uses gh api path"

stub gh 'exit 1'
stub git 'printf "abc\trefs/tags/v3.2.1\n"'
out="$(PATH="$stubbin:$PATH" latest_tag_for_repo "owner/repo")"
assert_eq "$out" "v3.2.1" "latest_tag_for_repo falls back to git ls-remote"

# Negative case: a non-slug repo never reaches gh or git — both stubs are
# invocation sentinels that would leave evidence if the network path ran.
network_sentinel="$ltmp/network-invoked"
stub gh 'printf gh >> "$LOOKUPS_NETWORK_SENTINEL"'
stub git 'printf git >> "$LOOKUPS_NETWORK_SENTINEL"'
out="$(LOOKUPS_NETWORK_SENTINEL="$network_sentinel" PATH="$stubbin:$PATH" latest_tag_for_repo "not a slug")" || true
assert_eq "$out" "" "latest_tag_for_repo prints nothing for a non-slug repo"
assert_eq "$(cat "$network_sentinel" 2>/dev/null || printf '')" "" \
  "latest_tag_for_repo makes no network call for a non-slug repo"

# --- current_yarn_version / current_node_pin (local-file lookups, no network) ---
printf '{\n  "packageManager": "yarn@4.18.0"\n}\n' > "$ltmp/package.json"
printf 'yarn 4.12.0\nnodejs 24.20.0\n' > "$ltmp/.tool-versions"
assert_eq "$(REPO_DIR="$ltmp" current_yarn_version)" "yarn@4.18.0" \
  "current_yarn_version reads the packageManager entry from package.json"
assert_eq "$(REPO_DIR="$ltmp" current_node_pin)" "24.20.0" \
  "current_node_pin reads the nodejs pin from .tool-versions"
printf '{}\n' > "$ltmp/package.json"
assert_eq "$(REPO_DIR="$ltmp" current_yarn_version)" "" \
  "current_yarn_version is empty without a packageManager entry"

# Bottom guard: standalone run prints totals; sourced run defers to the runner.
finish_spec
