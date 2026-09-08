#!/usr/bin/env bash
# scripts/specs/deps.spec.bash — spec for scripts/lib/deps.bash (deps,
# dev-deps + transitive phases). All mocks live inside subshells so they can't
# leak into the combined runner, and die/exit can't escape them.
# Standalone: bash scripts/specs/deps.spec.bash
set -u
SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/specs/test-utils.bash
source "$SPEC_DIR/test-utils.bash"
# shellcheck source=scripts/lib/deps.bash
source "$SPEC_DIR/../lib/deps.bash"
# The sourced lib hardens IFS; restore the default for spec-internal string ops.
IFS=$' \t\n'

dtmp="$(mktemp -d)"
register_tmp "$dtmp"

# Tab-indented fixture package.json mirroring the real repo's shape.
printf '{\n\t"dependencies": {\n\t\t"@11ty/eleventy": "^3.1.6",\n\t\t"chai": "^4.5.0"\n\t},\n\t"devDependencies": {\n\t\t"eslint": "^10.9.1",\n\t\t"mocha": "^11.8.0"\n\t}\n}\n' > "$dtmp/package.json"

# --- fetch_dependabot_alerts (production gh wiring via PATH stub, in a subshell) ---
ghstub="$(mktemp -d)"
printf '#!/usr/bin/env sh\nprintf "%%s\\n" "$*" >> "$0.args"\n' > "$ghstub/gh"
chmod +x "$ghstub/gh"
rc=0
(
  PATH="$ghstub:$PATH"
  export GH_REPO="exchgr/exch.gr-11ty"
  fetch_dependabot_alerts >/dev/null
) || rc=$?
assert_status "$rc" 0 "fetch_dependabot_alerts succeeds via the gh PATH stub"
assert_eq "$(cat "$ghstub/gh.args")" "api /repos/exchgr/exch.gr-11ty/dependabot/alerts?state=open --paginate" \
  "fetch_dependabot_alerts invokes gh api with the open-state paginate query against GH_REPO"
rm -rf "$ghstub"

# --- latest_version_of (production yarn wiring via PATH stub, in a subshell) ---
lvstub="$(mktemp -d)"
cat > "$lvstub/yarn" <<'EOF'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$0.args"
printf '%s\n' '{"name":"qs","version":"6.15.3"}'
EOF
chmod +x "$lvstub/yarn"
rc=0
(
  PATH="$lvstub:$PATH"
  latest_version_of qs
) > "$lvstub/out" || rc=$?
assert_status "$rc" 0 "latest_version_of succeeds via the yarn npm info PATH stub"
assert_eq "$(cat "$lvstub/yarn.args")" "npm info qs@latest --fields version --json" \
  "latest_version_of queries the registry for the newest release of the package"
assert_eq "$(cat "$lvstub/out")" "6.15.3" \
  "latest_version_of prints the package's latest version"
rm -rf "$lvstub"

# --- parse_version_field (pure): the version field from yarn npm info output ---
assert_eq "$(printf '%s\n' '{"name":"html-entities","version":"2.6.0"}' | parse_version_field)" "2.6.0" \
  "parse_version_field extracts the version from yarn npm info --fields version --json output"
assert_eq "$(printf '%s\n' '{"name":"html-entities"}' | parse_version_field)" "" \
  "parse_version_field returns empty when no version field is present"

# --- declared_range: the dep's range from the fixture repo's package.json ---
assert_eq "$(REPO_DIR="$dtmp" declared_range chai)" "^4.5.0" \
  "declared_range reads the dep's range from package.json"
assert_eq "$(REPO_DIR="$dtmp" declared_range vue)" "" \
  "declared_range returns empty for an undeclared dep"

# --- up_args_for (pure): newline-separated dep names -> <dep>@latest lines ---
assert_eq "$(up_args_for $'@11ty/eleventy\nchai')" $'@11ty/eleventy@latest\nchai@latest' \
  "up_args_for appends @latest to every dep name"
assert_eq "$(up_args_for 'chai')" "chai@latest" \
  "up_args_for handles a single dep"
assert_eq "$(up_args_for '')" "" \
  "up_args_for of an empty dep list names nothing (callers skip the blanket run)"
assert_eq "$(up_args_for $'chai\n\nhtml-entities')" $'chai@latest\nhtml-entities@latest' \
  "up_args_for skips blank lines between dep names"

# --- declared_deps / declared_dev_deps: the manifest's dependency names ---
assert_eq "$(REPO_DIR="$dtmp" declared_deps)" $'@11ty/eleventy\nchai' \
  "declared_deps lists the manifest's dependency names"
assert_eq "$(REPO_DIR="$dtmp" declared_dev_deps)" $'eslint\nmocha' \
  "declared_dev_deps lists the manifest's devDependency names"

# --- bump_package: declared pkg -> yarn up @latest ---
bump_declared_calls="$dtmp/bump-declared-calls"
: > "$bump_declared_calls"
(
  run() { printf '%s\n' "$*" >> "$bump_declared_calls"; }
  REPO_DIR="$dtmp" bump_package chai
)
assert_eq "$(cat "$bump_declared_calls")" "yarn up chai@latest" \
  "bump_package bumps a package declared in package.json with yarn up @latest"

# --- bump_package: transitive-only pkg -> yarn set resolution to the latest version ---
bump_transitive_calls="$dtmp/bump-transitive-calls"
: > "$bump_transitive_calls"
(
  run() { printf '%s\n' "$*" >> "$bump_transitive_calls"; }
  latest_version_of() { printf '6.15.3'; }
  REPO_DIR="$dtmp" bump_package qs
)
assert_eq "$(cat "$bump_transitive_calls")" "yarn set resolution qs@npm:* npm:6.15.3" \
  "bump_package forces a transitive-only package's lockfile resolution to its latest version (yarn 4 set resolution syntax)"

# --- bump_package: unresolvable latest -> warn + skip, no run calls, no die ---
bump_lookup_calls="$dtmp/bump-lookup-fail-calls"
bump_lookup_err="$dtmp/bump-lookup-fail-err"
: > "$bump_lookup_calls"
bump_lookup_rc=0
(
  run() { printf '%s\n' "$*" >> "$bump_lookup_calls"; }
  latest_version_of() { return 1; }
  {
    REPO_DIR="$dtmp" bump_package qs
  } 2> "$bump_lookup_err"
) || bump_lookup_rc=$?
assert_status "$bump_lookup_rc" 0 \
  "bump_package on a failed latest lookup skips the package instead of dying (soft-fail step)"
assert_eq "$(cat "$bump_lookup_calls")" "" \
  "bump_package on a failed latest lookup records no run calls for that package"
assert_contains "$(cat "$bump_lookup_err")" "could not resolve latest qs" \
  "bump_package warns when it skips a transitive bump over a failed latest lookup"

# --- dependabot_bumps: declared + transitive-only alerts get their class-correct bumps ---
depbumps_calls="$dtmp/depbumps-calls"
: > "$depbumps_calls"
(
  run() { printf '%s\n' "$*" >> "$depbumps_calls"; }
  # Fixture: chai duplicated, qs open, nanoid dismissed. dependabot_pkgs
  # (from helpers.bash) must dedupe to the sorted open set.
  fetch_dependabot_alerts() {
    printf '%s\n' '[{"state":"open","dependency":{"package":{"name":"chai"}}},{"state":"open","dependency":{"package":{"name":"qs"}}},{"state":"open","dependency":{"package":{"name":"chai"}}},{"state":"dismissed","dependency":{"package":{"name":"nanoid"}}}]'
  }
  latest_version_of() { printf '6.15.3'; }
  REPO_DIR="$dtmp" dependabot_bumps
)
assert_eq "$(cat "$depbumps_calls")" $'yarn up chai@latest\nyarn set resolution qs@npm:* npm:6.15.3' \
  "dependabot_bumps bumps declared packages with yarn up and transitive-only packages with yarn set resolution (sorted, deduped alert order)"

# --- dependabot_bumps: gh fetch failure -> warn + skip the whole step ---
depbumps_gh_calls="$dtmp/depbumps-gh-calls"
depbumps_gh_err="$dtmp/depbumps-gh-err"
: > "$depbumps_gh_calls"
depbumps_gh_rc=0
(
  run() { printf '%s\n' "$*" >> "$depbumps_gh_calls"; }
  fetch_dependabot_alerts() { return 1; }
  {
    REPO_DIR="$dtmp" dependabot_bumps
  } 2> "$depbumps_gh_err"
) || depbumps_gh_rc=$?
assert_status "$depbumps_gh_rc" 0 \
  "dependabot_bumps on gh failure returns 0 (soft skip, never aborts the phase)"
assert_eq "$(cat "$depbumps_gh_calls")" "" \
  "dependabot_bumps on gh failure records no run calls"
assert_contains "$(cat "$depbumps_gh_err")" "skipping security bumps" \
  "dependabot_bumps on gh failure warns about skipping the security bumps"

# --- phase_deps happy path (recorder run, in a subshell) ---
dep_calls="$dtmp/dep-calls"
: > "$dep_calls"
deps_out="$(
  run() { printf '%s\n' "$*" >> "$dep_calls"; }
  REPO_DIR="$dtmp" phase_deps
)"
assert_eq "$(cat "$dep_calls")" $'yarn up @11ty/eleventy@latest chai@latest\nyarn install' \
  "phase_deps enumerates the declared deps into ONE explicit yarn up (never yarn up '*') and ends with yarn install"
assert_contains "$(printf '%s' "$deps_out")" "deps: phase complete" \
  "phase_deps logs its completion"

# --- phase_deps with no declared deps: no blanket up at all, still installs ---
nodeps_dir="$dtmp/nodeps"
mkdir -p "$nodeps_dir"
printf '{\n\t"devDependencies": {\n\t\t"eslint": "^10.9.1"\n\t}\n}\n' > "$nodeps_dir/package.json"
nodeps_calls="$dtmp/nodeps-calls"
: > "$nodeps_calls"
(
  run() { printf '%s\n' "$*" >> "$nodeps_calls"; }
  REPO_DIR="$nodeps_dir" phase_deps
)
assert_eq "$(cat "$nodeps_calls")" "yarn install" \
  "phase_deps with no declared dependencies records only the final yarn install (no empty yarn up)"

# --- phase_dev_deps happy path (recorder run, in a subshell) ---
devdep_calls="$dtmp/devdep-calls"
: > "$devdep_calls"
devdeps_out="$(
  run() { printf '%s\n' "$*" >> "$devdep_calls"; }
  REPO_DIR="$dtmp" phase_dev_deps
)"
assert_eq "$(cat "$devdep_calls")" $'yarn up eslint@latest mocha@latest\nyarn install' \
  "phase_dev_deps enumerates the declared devDependencies into ONE explicit yarn up and ends with yarn install"
assert_contains "$(printf '%s' "$devdeps_out")" "dev-deps: phase complete" \
  "phase_dev_deps logs its completion"

# --- phase_transitive happy path: refresh, dedupe, dependabot bumps, one final install ---
happy_calls="$dtmp/happy-calls"
: > "$happy_calls"
(
  run() { printf '%s\n' "$*" >> "$happy_calls"; }
  fetch_dependabot_alerts() {
    printf '%s\n' '[{"state":"open","dependency":{"package":{"name":"chai"}}},{"state":"open","dependency":{"package":{"name":"qs"}}}]'
  }
  latest_version_of() { printf '6.15.3'; }
  REPO_DIR="$dtmp" phase_transitive
)
assert_eq "$(cat "$happy_calls")" $'yarn up -R *\nyarn dedupe\nyarn up chai@latest\nyarn set resolution qs@npm:* npm:6.15.3\nyarn install' \
  "phase_transitive records: yarn up -R *, yarn dedupe, the dependabot bumps (after the refresh so set-resolutions are not clobbered), then ONE final yarn install"

# --- phase_transitive with gh failure: warn + skip dependabot, keep the rest ---
tf_gh_calls="$dtmp/tf-gh-calls"
tf_gh_err="$dtmp/tf-gh-err"
: > "$tf_gh_calls"
(
  run() { printf '%s\n' "$*" >> "$tf_gh_calls"; }
  fetch_dependabot_alerts() { return 1; }
  {
    REPO_DIR="$dtmp" phase_transitive
  } 2> "$tf_gh_err"
)
assert_eq "$(cat "$tf_gh_calls")" $'yarn up -R *\nyarn dedupe\nyarn install' \
  "phase_transitive on gh failure still records the refresh, dedupe, and final install (no dependabot ups)"
assert_contains "$(cat "$tf_gh_err")" "skipping security bumps" \
  "phase_transitive on gh failure warns about skipping the security bumps"

# --- phase_transitive hard failure: wildcard -R fails -> propagates, nothing further runs ---
tf_calls="$dtmp/tf-calls"
: > "$tf_calls"
tf_rc=0
(
  run() {
    printf '%s\n' "$*" >> "$tf_calls"
    [[ "$*" == 'yarn up -R *' ]] && return 1
    return 0
  }
  REPO_DIR="$dtmp" phase_transitive
) || tf_rc=$?
assert_status "$tf_rc" 1 \
  "phase_transitive propagates a failing wildcard -R as a hard error (no fallback)"
assert_eq "$(cat "$tf_calls")" "yarn up -R *" \
  "phase_transitive records nothing after a failing wildcard -R (no dedupe, no dependabot, no install)"

# --- dry run: DRY_RUN=1 mutates nothing (cmp against a pristine copy) ---
dry_dir="$dtmp/dryrun"
mkdir -p "$dry_dir"
printf '{\n\t"dependencies": {\n\t\t"chai": "^4.5.0"\n\t},\n\t"devDependencies": {\n\t\t"eslint": "^10.9.1"\n\t}\n}\n' > "$dry_dir/package.json"
cp "$dry_dir/package.json" "$dry_dir/package.json.orig"
dry_out="$(
  export DRY_RUN=1
  fetch_dependabot_alerts() { printf '[]\n'; }
  REPO_DIR="$dry_dir" phase_deps
  REPO_DIR="$dry_dir" phase_dev_deps
  REPO_DIR="$dry_dir" phase_transitive
)"
cmp -s "$dry_dir/package.json" "$dry_dir/package.json.orig"
assert_status "$?" 0 \
  "dry run leaves the fixture package.json byte-identical (cmp — no yarn execution, no mutation)"
assert_contains "$(printf '%s' "$dry_out")" "[dry-run] yarn up chai@latest" \
  "dry run logs the planned deps up without executing it"
assert_contains "$(printf '%s' "$dry_out")" "[dry-run] yarn up eslint@latest" \
  "dry run logs the planned dev-deps up without executing it"

# Bottom guard: standalone run prints totals; sourced run defers to the runner.
finish_spec
