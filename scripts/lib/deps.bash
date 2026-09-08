# scripts/lib/deps.bash — deps phases: direct-dependency bumps (production
# deps + dev-deps), dependabot security bumps, transitive refresh, dedupe,
# install.
# Selectors: deps (phase_deps), dev-deps (phase_dev_deps), transitive
# (phase_transitive) — split so the CLI selectors can pick them
# independently. The dependabot sub-flow lives in the transitive phase: its
# set-resolution overrides must be written AFTER the wildcard refresh (a
# later `yarn up` would clobber them) and the single final install at the end
# of the phase pays for the whole sweep.
# Dependencies: common.bash, helpers.bash.
# shellcheck source=scripts/lib/common.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.bash"
# shellcheck source=scripts/lib/helpers.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.bash"

# The range declared for $1 in the repo's package.json — empty when
# undeclared. Reads a file, but is side-effect-free.
declared_range() {
  # --arg keeps the package name out of the jq program string: an interpolated
  # name is a jq-injection vector even though npm naming makes it unreachable.
  jq -r --arg p "$1" '.dependencies[$p] // empty' "$REPO_DIR/package.json" 2>/dev/null
}

# The declared top-level dependency names from the repo's package.json, one
# per line. Reads a file, but is side-effect-free; specs set REPO_DIR.
declared_deps() {
  jq -r '.dependencies | keys[]' "$REPO_DIR/package.json" 2>/dev/null
}

# Same as declared_deps over devDependencies — the dev-deps phase floats the
# same way as the deps phase, just over the other half of the manifest.
declared_dev_deps() {
  jq -r '.devDependencies | keys[]' "$REPO_DIR/package.json" 2>/dev/null
}

# Pure: the float arguments for a newline-separated dep list — each name as
# `<dep>@latest`. Shared by the deps and dev-deps phases so both float the
# manifest the same way. Empty input names nothing (callers skip the blanket
# run rather than pass an empty `yarn up`).
up_args_for() {
  local dep
  while IFS= read -r dep; do
    [[ -n "$dep" ]] || continue
    printf '%s@latest\n' "$dep"
  done <<<"$1"
}

# Pure: the "version" field from `yarn npm info --fields version --json`
# output. Empty when absent.
parse_version_field() {
  jq -r 'first(.. | objects | select(.version?) | .version) // empty'
}

# Registry-fresh latest release of a package. Specs shadow this name or stub
# yarn via PATH.
latest_version_of() {
  yarn npm info "$1@latest" --fields version --json 2>/dev/null | parse_version_field
}

# Dependabot security bumps: the gh call and every per-package lookup are
# soft — a failure warns and skips (the whole step for gh, one package for a
# lookup) so an opaque package or an unavailable API can never abort the
# phase. Per-package bumps are classified by bump_package.
dependabot_bumps() {
  local alerts pkgs pkg
  if ! alerts="$(fetch_dependabot_alerts)"; then
    warn "deps: gh dependabot alerts unavailable — skipping security bumps"
    return 0
  fi
  pkgs="$(printf '%s' "$alerts" | dependabot_pkgs)"
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    bump_package "$pkg"
  done <<<"$pkgs"
}

# Bump one dependabot-alerted package by its dependency class:
# - declared in package.json -> `yarn up <pkg>@latest` (a direct dependency can
#   be floated normally);
# - transitive-only -> force the lockfile resolution to the latest release via
#   `yarn set resolution <pkg>@npm:* npm:<latest>` (yarn 4 syntax: the
#   resolution is `npm:`-prefixed). `yarn up` dies with a usage error on
#   packages no workspace references, so a bare up would abort the run — the
#   resolution override is the way to still honor the security intent for
#   transitive-only alerts. A failed latest lookup warns and skips the
#   package (soft-fail), never dies.
bump_package() {
  local pkg="$1" latest
  if [[ -n "$(declared_range "$pkg")" ]]; then
    run yarn up "${pkg}@latest"
    return 0
  fi
  if latest="$(latest_version_of "$pkg")" && [[ -n "$latest" ]]; then
    run yarn set resolution "${pkg}@npm:*" "npm:${latest}"
  else
    warn "deps: could not resolve latest $pkg — skipping transitive security bump"
  fi
}

# The gh call is stubbed in specs by shadowing this name directly.
fetch_dependabot_alerts() {
  gh api "/repos/$GH_REPO/dependabot/alerts?state=open" --paginate
}

# Shared body of the deps and dev-deps phases: floats the packages <list_fn>
# enumerates into ONE explicit `yarn up` (never a wildcard), then installs.
# <label> feeds the completion log so each phase keeps its selector identity.
manifest_float_up() {
  local list_fn="$1" label="$2" up_args=() dep
  # Explicit enumeration, never `yarn up '*'`: a wildcard float rewrites
  # every range in the manifest wholesale, while the explicit list keeps the
  # bump auditable against what package.json actually declares. The list is
  # enumerated into ONE up call so yarn resolves all floats in a single pass.
  while IFS= read -r dep; do
    up_args+=("$dep")
  done < <(up_args_for "$("$list_fn")")
  if (( ${#up_args[@]} )); then
    run yarn up "${up_args[@]}"
  fi
  run yarn install
  log "$label: phase complete"
}

# selector: deps
phase_deps() {
  manifest_float_up declared_deps deps
}

# selector: dev-deps
# Same float body as phase_deps, over the devDependencies half of the
# manifest.
phase_dev_deps() {
  manifest_float_up declared_dev_deps dev-deps
}

# selector: transitive
phase_transitive() {
  # run dies itself on failure; this return-guard covers non-dying run
  # stubs (spec seams).
  run yarn up -R '*' || return 1
  run yarn dedupe
  # The dependabot sub-flow runs AFTER the refresh: its set-resolution
  # overrides must not be clobbered by the wildcard up. The one install at
  # the end materializes the refresh, the dedupe, and the overrides together.
  dependabot_bumps
  run yarn install
  log "transitive: phase complete"
}
