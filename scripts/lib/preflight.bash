# scripts/lib/preflight.bash — preflight phase: hard-fail environment checks; any
# failure aborts the run. Owns REQUIRED_TOOLS, derive_gh_repo, and GH_REPO.
# Dependencies: common.bash.
# shellcheck source=scripts/lib/common.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.bash"

REQUIRED_TOOLS=(yarn git gh jq yq curl asdf)

# yq FLAVOR gate: parse_uses_line (workflows phase) depends on mikefarah yq v4
# syntax. The kislyuk/Python yq shares the binary name but speaks jq, which
# would turn the workflows phase into a SILENT no-op with plausible logs —
# reject it here instead of failing softly later.
verify_yq_flavor() {
  local version
  version="$(yq --version 2>/dev/null)" || version=""
  if [[ "$version" != *mikefarah* ]]; then
    die "yq is the wrong flavor: expected mikefarah yq v4 (see the Brewfile), got: ${version:-no version output}"
  fi
}

derive_gh_repo() {
  local url
  url="$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null)" || return 1
  url="${url##*github.com[:/]}"
  url="${url%.git}"
  validate_gh_slug "$url" \
    || die "origin remote is not a valid owner/repo GitHub slug: '$url'"
  printf '%s\n' "$url"
}

# GH_REPO is interpolated into `gh api /repos/$GH_REPO/...` URLs, so only a
# strict owner/repo slug is accepted — anything else is rejected rather than
# interpolating unvalidated remote data.
validate_gh_slug() {
  [[ "$1" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]
}

GH_REPO="$(derive_gh_repo || true)"
# The `|| true` above is deliberate: sourcing this file must stay spec-safe
# (specs stub git), so the derivation itself never kills the shell. The
# fail-closed contract is enforced in phase_preflight instead — an empty or
# invalid GH_REPO aborts the run there rather than letting the dependabot
# sweep soft-skip forever.

# Hard-error preflight: any failure aborts the run. No skip-and-continue.
phase_preflight() {
  if [[ -z "$GH_REPO" ]]; then
    die "could not derive GH_REPO from the origin remote"
  fi
  validate_gh_slug "$GH_REPO" \
    || die "GH_REPO is not a valid owner/repo GitHub slug: '$GH_REPO'"
  local -a missing=()
  local tool
  for tool in "${REQUIRED_TOOLS[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if (( ${#missing[@]} > 0 )); then
    die "missing required tools: ${missing[*]}"
  fi
  verify_yq_flavor
  gh auth status >/dev/null 2>&1 || die "gh is not authenticated — run 'gh auth login' first"
  if [[ -n "$(git -C "$REPO_DIR" status --porcelain)" ]]; then
    die "worktree is dirty — commit or stash before running the upgrade"
  fi
  log "preflight: all checks passed (repo: ${GH_REPO:-unknown})"
}
