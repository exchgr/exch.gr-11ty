# scripts/lib/workflows.bash — workflows phase: bump `uses: owner/repo@ref`
# pins and container images across every .github/workflows/*.yml. Only `uses:`
# lines are matched for pins, so `runs-on:` lines can never be touched; only
# `image: node:<major>-<codename>-slim` lines are matched for containers, so
# cache keys (e.g. `${{ env.NODE_VERSION }}-yarn-...`) can never be touched.
# The tag lookups are sanctioned warn-and-continue seams: a failed lookup
# warns, keeps the old value, and keeps going (preflight remains hard-fail for
# the environment itself).
# Dependencies: common.bash, helpers.bash, lookups.bash.
# shellcheck source=scripts/lib/common.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.bash"
# shellcheck source=scripts/lib/helpers.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.bash"
# shellcheck source=scripts/lib/lookups.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lookups.bash"

# selector: workflows
phase_workflows() {
  local dir="$REPO_DIR/.github/workflows"
  if [[ ! -d "$dir" ]]; then
    log "workflows: no .github/workflows directory — skipping"
    return 0
  fi
  # The LTS lookup is a run-level cost (one network fetch), not a per-file
  # one — resolve the major once here; a failure is soft for the whole phase.
  local lts_major
  if ! lts_major="$(resolve_lts_major)"; then
    warn "workflows: no latest node LTS found — keeping container images"
    lts_major=""
  fi
  local file
  for file in "$dir"/*.yml; do
    [[ -e "$file" ]] || continue
    bump_workflow_pins "$file"
    if [[ -n "$lts_major" ]]; then
      bump_workflow_container_image "$file" "$lts_major"
    fi
  done
  log "workflows: phase complete"
}

# Resolve the latest node LTS major for the whole run: print the major and
# return 0, or return 1 when the lookup fails or the answer is not a valid
# version tag. The caller owns the warn — this stays a warn-free seam.
resolve_lts_major() {
  local lts_version
  lts_version="$(latest_node_lts)" || return 1
  [[ -n "$lts_version" ]] || return 1
  is_vtag "v$lts_version" || return 1
  semver_major "$lts_version"
}

# All `owner/repo ref` pins in $1, deduped (a repo referenced twice is bumped
# once and logged once). Text-in/text-out: pairs with the parse_uses_line seam.
collect_workflow_pins() {
  local file="$1" raw_pins
  raw_pins="$(grep 'uses:' "$file" 2>/dev/null)" || raw_pins=""
  printf '%s\n' "$raw_pins" | while IFS= read -r line; do
    parse_uses_line "$line" 2>/dev/null || true
  done | sort -u
}

# Resolve + apply one pin bump in $1: warn-and-keep on lookup failure, bump
# only when action_tag_newer says the latest is a strictly-higher major, and
# replace the exact `uses:$repo@$old` token.
bump_pin() {
  local file="$1" pin="$2" repo ref new
  repo="${pin% *}"
  ref="${pin#* }"
  if ! new="$(latest_tag_for_repo "$repo")" || [[ -z "$new" ]]; then
    warn "workflows: no latest tag found for $repo — keeping $repo@$ref"
    return 0
  fi
  if action_tag_newer "$ref" "$new"; then
    apply_edit "bump $repo@$ref -> $repo@$new in $(basename "$file")" \
      replace_all_in_file "$file" "$repo@$ref" "$repo@$new"
    (( DRY_RUN )) || log "workflows: bumped $repo@$ref -> $repo@$new in $(basename "$file")"
  else
    log "workflows: $repo@$ref in $(basename "$file") already current — no-op"
  fi
}

# Extract the file's pins (collect_workflow_pins), then delegate the per-pin
# decision to bump_pin.
bump_workflow_pins() {
  local file="$1" pins pin
  pins="$(collect_workflow_pins "$file")"
  if [[ -z "${pins//[[:space:]]/}" ]]; then
    log "workflows: $(basename "$file") has no uses: pins — skipping"
    return 0
  fi
  while IFS= read -r pin; do
    [[ -n "$pin" ]] || continue
    bump_pin "$file" "$pin"
  done <<<"$pins"
}

# Distinct `node:<major>-<codename>-slim` tokens in $1, one per line, deduped
# (a job grid sharing an image is bumped once and logged once). Only `image:`
# lines are scanned, so cache keys and `runs-on:` lines can never match.
# Text-in/text-out.
collect_container_images() {
  local file="$1" matches
  matches="$(grep -E 'image:[[:space:]]*node:[0-9]+-[a-z0-9]+-slim' "$file" 2>/dev/null)" || matches=""
  printf '%s\n' "$matches" | sed -En 's#.*image:[[:space:]]*(node:[0-9]+-[a-z0-9]+-slim).*#\1#p' | sort -u
}

# Pure: the major from a `node:<major>-<codename>-slim` token.
container_image_major() {
  local rest="${1#node:}"
  printf '%s\n' "${rest%%-*}"
}

# Pure: the codename from a `node:<major>-<codename>-slim` token — whatever
# the matched line says is what gets preserved on the rewritten image.
container_image_codename() {
  local major rest
  major="$(container_image_major "$1")"
  rest="${1#node:${major}-}"
  printf '%s\n' "${rest%-slim}"
}

# Decide + apply + log one image in $2 against the pre-resolved LTS major $3:
# a same-or-newer major is a no-op (downgrading is not this phase's job); a
# stale major is rewritten to node:<lts_major>-<codename>-slim with the
# codename from the matched line preserved. Dry-run aware via apply_edit.
bump_container_image() {
  local file="$1" image="$2" lts_major="$3" major codename
  major="$(container_image_major "$image")"
  if (( major >= lts_major )); then
    log "workflows: container image $image in $(basename "$file") already current — no-op"
    return 0
  fi
  codename="$(container_image_codename "$image")"
  apply_edit "bump container image $image -> node:${lts_major}-${codename}-slim in $(basename "$file")" \
    replace_all_in_file "$file" "$image" "node:${lts_major}-${codename}-slim"
  (( DRY_RUN )) || log "workflows: bumped container image $image -> node:${lts_major}-${codename}-slim in $(basename "$file")"
}

# Extract the file's images (collect_container_images), then delegate the
# per-image decision to bump_container_image. The LTS major arrives
# pre-resolved from phase_workflows — no lookups happen here.
bump_workflow_container_image() {
  local file="$1" lts_major="$2" images image
  images="$(collect_container_images "$file")"
  if [[ -z "${images//[[:space:]]/}" ]]; then
    return 0
  fi
  while IFS= read -r image; do
    [[ -n "$image" ]] || continue
    bump_container_image "$file" "$image" "$lts_major"
  done <<<"$images"
}
