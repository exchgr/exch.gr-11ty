#!/usr/bin/env bash
# scripts/specs/workflows.spec.bash — spec for scripts/lib/workflows.bash
# (workflow pin bumps + container-image bumps across .github/workflows/*.yml).
# The production wiring for latest_tag_for_repo / latest_node_lts lives in
# lookups.spec.bash — these cases shadow the lookup seams directly.
# Standalone: bash scripts/specs/workflows.spec.bash
set -u
SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/specs/test-utils.bash
source "$SPEC_DIR/test-utils.bash"
# shellcheck source=scripts/lib/workflows.bash
source "$SPEC_DIR/../lib/workflows.bash"
# The sourced lib hardens IFS; restore the default for spec-internal string ops.
IFS=$' \t\n'

wtmp="$(mktemp -d)"
register_tmp "$wtmp"

# --- collect_workflow_pins (pure text-in/text-out: uses: lines only, deduped) ---
mkdir -p "$wtmp/pins"
cat > "$wtmp/pins/wf.yml" <<'EOF'
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/checkout@v7
      - uses: foo/bar@v1
EOF
assert_eq "$(collect_workflow_pins "$wtmp/pins/wf.yml")" $'actions/checkout v7\nfoo/bar v1' \
  "collect_workflow_pins yields deduped owner/repo ref pairs and ignores runs-on: lines"

# --- happy path: both checkout pins bumped, flyctl kept, runs-on untouched ---
mkdir -p "$wtmp/happy/.github/workflows"
cat > "$wtmp/happy/.github/workflows/ci.yml" <<'EOF'
name: ci
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/checkout@v7
      - uses: superfly/flyctl-actions/setup-flyctl@v1.4
EOF
happy_log="$wtmp/happy-log"
(
  latest_tag_for_repo() {
    case "$1" in
      actions/checkout) printf 'v8\n' ;;
      superfly/flyctl-actions/setup-flyctl) printf 'v1.4\n' ;;
      *) return 1 ;;
    esac
  }
  latest_node_lts() { printf '26.0.0\n'; }
  REPO_DIR="$wtmp/happy" phase_workflows
) > "$happy_log"
happy_rc=$?
wf="$wtmp/happy/.github/workflows/ci.yml"
assert_status "$happy_rc" 0 "phase_workflows happy path completes with status 0"
assert_eq "$(grep -c 'uses: actions/checkout@v8' "$wf")" "2" \
  "phase_workflows bumps both actions/checkout@v7 pins to v8 in one pass"
assert_eq "$(grep -c 'uses: actions/checkout@v7' "$wf")" "0" \
  "phase_workflows leaves no stale actions/checkout@v7 pins"
assert_eq "$(grep -c 'uses: superfly/flyctl-actions/setup-flyctl@v1.4' "$wf")" "1" \
  "phase_workflows keeps superfly/flyctl-actions/setup-flyctl@v1.4 (same tag — no-op)"
assert_eq "$(grep -c 'runs-on: ubuntu-latest' "$wf")" "1" \
  "phase_workflows never touches runs-on: lines (only uses: lines are matched)"
assert_eq "$(grep -c 'bumped actions/checkout@v7 -> actions/checkout@v8' "$happy_log")" "1" \
  "phase_workflows logs the checkout bump once (pins deduped)"
assert_eq "$(grep -c 'setup-flyctl@v1.4.*no-op' "$happy_log")" "1" \
  "phase_workflows logs the unchanged flyctl pin as a no-op"

# --- lookup failure: old pin kept + warn, other pins still processed ---
mkdir -p "$wtmp/fail/.github/workflows"
cat > "$wtmp/fail/.github/workflows/ci.yml" <<'EOF'
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: foo/bar@v1
EOF
fail_log="$wtmp/fail-log"
fail_err="$wtmp/fail-err"
(
  latest_tag_for_repo() {
    [[ "$1" == 'actions/checkout' ]] && return 1
    [[ "$1" == 'foo/bar' ]] && printf 'v2\n'
  }
  latest_node_lts() { printf '26.0.0\n'; }
  REPO_DIR="$wtmp/fail" phase_workflows
) > "$fail_log" 2> "$fail_err"
wff="$wtmp/fail/.github/workflows/ci.yml"
assert_eq "$(grep -c 'uses: actions/checkout@v7' "$wff")" "1" \
  "phase_workflows keeps the old pin when the latest-tag lookup fails"
assert_eq "$(grep -c 'uses: foo/bar@v2' "$wff")" "1" \
  "phase_workflows still processes the other pins when one lookup fails"
assert_eq "$(grep -c 'no latest tag found for actions/checkout' "$fail_err")" "1" \
  "phase_workflows warns on a failed lookup and keeps the old pin"

# --- no uses: pins in a file -> skip log ---
mkdir -p "$wtmp/empty/.github/workflows"
printf 'jobs:\n  build:\n    runs-on: ubuntu-latest\n' > "$wtmp/empty/.github/workflows/ci.yml"
empty_log="$wtmp/empty-log"
(
  latest_tag_for_repo() { printf 'v9\n'; }
  latest_node_lts() { printf '26.0.0\n'; }
  REPO_DIR="$wtmp/empty" phase_workflows
) > "$empty_log"
assert_eq "$(grep -c 'no uses: pins — skipping' "$empty_log")" "1" \
  "phase_workflows logs a skip for a workflow file with no uses: pins"

# --- missing .github/workflows directory -> skip log ---
mkdir -p "$wtmp/no-dir"
no_dir_log="$wtmp/nodir-log"
(
  REPO_DIR="$wtmp/no-dir" phase_workflows
) > "$no_dir_log"
assert_eq "$(grep -c 'no .github/workflows directory — skipping' "$no_dir_log")" "1" \
  "phase_workflows skips when .github/workflows is missing"

# --- dry-run: the planned edit is printed, the file is never mutated ---
mkdir -p "$wtmp/dryrun/.github/workflows"
cat > "$wtmp/dryrun/.github/workflows/ci.yml" <<'EOF'
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: node:24-trixie-slim
    steps:
      - uses: actions/checkout@v7
EOF
cp "$wtmp/dryrun/.github/workflows/ci.yml" "$wtmp/dryrun-original.yml"
dryrun_log="$wtmp/dryrun-log"
(
  latest_tag_for_repo() { printf 'v8\n'; }
  latest_node_lts() { printf '26.0.0\n'; }
  DRY_RUN=1
  REPO_DIR="$wtmp/dryrun" phase_workflows
) > "$dryrun_log"
dryrun_rc=$?
assert_status "$dryrun_rc" 0 "phase_workflows dry-run completes with status 0"
cmp -s "$wtmp/dryrun/.github/workflows/ci.yml" "$wtmp/dryrun-original.yml"
assert_status "$?" 0 "phase_workflows dry-run leaves the file byte-identical"
assert_contains "$(cat "$dryrun_log")" "[dry-run] edit: bump actions/checkout@v7 -> actions/checkout@v8" \
  "phase_workflows dry-run prints the planned pin edit"
assert_contains "$(cat "$dryrun_log")" "[dry-run] edit: bump container image node:24-trixie-slim -> node:26-trixie-slim" \
  "phase_workflows dry-run prints the planned container-image edit"
assert_eq "$(grep -c 'workflows: bumped' "$dryrun_log")" "0" \
  "phase_workflows dry-run never claims a completed bump"

# --- collect_container_images (pure: image: lines only, deduped) ---
mkdir -p "$wtmp/images"
cat > "$wtmp/images/wf.yml" <<'EOF'
jobs:
  one:
    runs-on: ubuntu-latest
    container:
      image: node:24-trixie-slim
  two:
    runs-on: ubuntu-latest
    container:
      image: node:24-trixie-slim
  three:
    runs-on: ubuntu-latest
    container:
      image: node:22-bookworm-slim
EOF
assert_eq "$(collect_container_images "$wtmp/images/wf.yml")" $'node:22-bookworm-slim\nnode:24-trixie-slim' \
  "collect_container_images yields distinct node:<major>-<codename>-slim tokens (runs-on: lines can never match)"

# --- container_image_major / container_image_codename (pure extractors) ---
assert_eq "$(container_image_major 'node:24-trixie-slim')" "24" \
  "container_image_major extracts the major from a node image token"
assert_eq "$(container_image_codename 'node:24-trixie-slim')" "trixie" \
  "container_image_codename extracts the codename from a trixie image token"
assert_eq "$(container_image_codename 'node:22-bookworm-slim')" "bookworm" \
  "container_image_codename extracts a non-trixie codename (bookworm)"

# --- bump_container_image (per-image decision: stale major rewritten) ---
mkdir -p "$wtmp/per-image/.github/workflows"
cat > "$wtmp/per-image/.github/workflows/main.yml" <<'EOF'
jobs:
  test-build:
    runs-on: ubuntu-latest
    container:
      image: node:24-trixie-slim
EOF
per_img="$wtmp/per-image/.github/workflows/main.yml"
per_img_log="$wtmp/per-image-log"
bump_container_image "$per_img" 'node:24-trixie-slim' 26 > "$per_img_log"
assert_eq "$(grep -c 'image: node:26-trixie-slim' "$per_img")" "1" \
  "bump_container_image rewrites a stale image to the resolved LTS major"
assert_eq "$(grep -c 'bumped container image node:24-trixie-slim -> node:26-trixie-slim' "$per_img_log")" "1" \
  "bump_container_image logs the bump for a stale image"
assert_eq "$(grep -c 'runs-on: ubuntu-latest' "$per_img")" "1" \
  "bump_container_image never touches runs-on: lines"

# --- bump_container_image (per-image decision: same-or-newer major kept) ---
mkdir -p "$wtmp/per-current/.github/workflows"
cat > "$wtmp/per-current/.github/workflows/main.yml" <<'EOF'
jobs:
  test-build:
    runs-on: ubuntu-latest
    container:
      image: node:26-trixie-slim
EOF
cur_img="$wtmp/per-current/.github/workflows/main.yml"
cur_img_log="$wtmp/per-current-log"
bump_container_image "$cur_img" 'node:26-trixie-slim' 26 > "$cur_img_log"
assert_eq "$(grep -c 'image: node:26-trixie-slim' "$cur_img")" "1" \
  "bump_container_image keeps an image whose major matches the LTS major"
assert_eq "$(grep -c 'container image node:26-trixie-slim in main.yml already current — no-op' "$cur_img_log")" "1" \
  "bump_container_image logs a same-major image as a no-op"

mkdir -p "$wtmp/per-newer/.github/workflows"
cat > "$wtmp/per-newer/.github/workflows/main.yml" <<'EOF'
jobs:
  test-build:
    runs-on: ubuntu-latest
    container:
      image: node:27-trixie-slim
EOF
newer_img="$wtmp/per-newer/.github/workflows/main.yml"
newer_img_log="$wtmp/per-newer-log"
bump_container_image "$newer_img" 'node:27-trixie-slim' 26 > "$newer_img_log"
assert_eq "$(grep -c 'image: node:27-trixie-slim' "$newer_img")" "1" \
  "bump_container_image never downgrades an image newer than the LTS major"
assert_eq "$(grep -c 'already current — no-op' "$newer_img_log")" "1" \
  "bump_container_image logs a newer-major image as a no-op"

# --- LTS lookup resolved exactly once per run, not once per workflow file ---
mkdir -p "$wtmp/lts-once/.github/workflows"
printf 'jobs:\n  a:\n    container:\n      image: node:24-trixie-slim\n' > "$wtmp/lts-once/.github/workflows/a.yml"
printf 'jobs:\n  b:\n    container:\n      image: node:22-bookworm-slim\n' > "$wtmp/lts-once/.github/workflows/b.yml"
lts_count="$wtmp/lts-count"
: > "$lts_count"
(
  latest_node_lts() { printf '1\n' >> "$lts_count"; printf '26.0.0\n'; }
  latest_tag_for_repo() { printf 'v9\n'; }
  REPO_DIR="$wtmp/lts-once" phase_workflows
) > /dev/null
assert_eq "$(wc -l < "$lts_count" | tr -d ' ')" "1" \
  "phase_workflows resolves the node LTS exactly once per run (not once per workflow file)"
assert_eq "$(grep -c 'image: node:26-trixie-slim' "$wtmp/lts-once/.github/workflows/a.yml")" "1" \
  "phase_workflows still bumps the container image in a.yml under the hoisted LTS lookup"
assert_eq "$(grep -c 'image: node:26-bookworm-slim' "$wtmp/lts-once/.github/workflows/b.yml")" "1" \
  "phase_workflows still bumps the container image in b.yml under the hoisted LTS lookup"

# --- container bump: stale image rewritten, cache keys + runs-on untouched ---
mkdir -p "$wtmp/img-bump/.github/workflows"
cat > "$wtmp/img-bump/.github/workflows/main.yml" <<'EOF'
jobs:
  test-build:
    runs-on: ubuntu-latest
    container:
      image: node:24-trixie-slim
    steps:
      - name: "checkout"
        uses: actions/checkout@v7
      - name: "cache packages"
        uses: actions/cache@v6
        with:
          key: ${{ env.NODE_VERSION }}-yarn-${{ hashFiles('yarn.lock', 'package.json') }}
      - name: "upload"
        uses: actions/checkout@v7
EOF
img_log="$wtmp/img-bump-log"
(
  latest_tag_for_repo() { printf 'v8\n'; }
  latest_node_lts() { printf '26.0.0\n'; }
  REPO_DIR="$wtmp/img-bump" phase_workflows
) > "$img_log"
imgf="$wtmp/img-bump/.github/workflows/main.yml"
assert_eq "$(grep -c 'image: node:26-trixie-slim' "$imgf")" "1" \
  "phase_workflows rewrites node:24-trixie-slim to node:26-trixie-slim (shadowed LTS major, codename preserved)"
assert_eq "$(grep -c 'node:24-trixie-slim' "$imgf")" "0" \
  "phase_workflows leaves no stale container image"
assert_eq "$(grep -c 'uses: actions/checkout@v8' "$imgf")" "2" \
  "phase_workflows bumps workflow pins and the container image in one pass"
assert_eq "$(grep -c 'key: ${{ env.NODE_VERSION }}-yarn-' "$imgf")" "1" \
  "phase_workflows never touches cache-key structures (env.NODE_VERSION keys stay intact)"
assert_eq "$(grep -c 'runs-on: ubuntu-latest' "$imgf")" "1" \
  "phase_workflows never touches runs-on: lines when bumping container images"
assert_eq "$(grep -c 'bumped container image node:24-trixie-slim -> node:26-trixie-slim' "$img_log")" "1" \
  "phase_workflows logs the container-image bump once (images deduped)"

# --- already-current image: no-op ---
mkdir -p "$wtmp/img-current/.github/workflows"
cat > "$wtmp/img-current/.github/workflows/main.yml" <<'EOF'
jobs:
  test-build:
    runs-on: ubuntu-latest
    container:
      image: node:24-trixie-slim
EOF
current_log="$wtmp/img-current-log"
(
  latest_node_lts() { printf '24.5.1\n'; }
  REPO_DIR="$wtmp/img-current" phase_workflows
) > "$current_log"
assert_eq "$(grep -c 'image: node:24-trixie-slim' "$wtmp/img-current/.github/workflows/main.yml")" "1" \
  "phase_workflows keeps a container image whose major already matches the LTS major"
assert_eq "$(grep -c 'container image node:24-trixie-slim in main.yml already current — no-op' "$current_log")" "1" \
  "phase_workflows logs an already-current container image as a no-op"

# --- node LTS lookup failure: every file left byte-identical, warn exactly once ---
mkdir -p "$wtmp/img-fail/.github/workflows"
cat > "$wtmp/img-fail/.github/workflows/main.yml" <<'EOF'
jobs:
  test-build:
    runs-on: ubuntu-latest
    container:
      image: node:24-trixie-slim
EOF
cat > "$wtmp/img-fail/.github/workflows/alt.yml" <<'EOF'
jobs:
  test-build:
    runs-on: ubuntu-latest
    container:
      image: node:22-bookworm-slim
EOF
cp "$wtmp/img-fail/.github/workflows/main.yml" "$wtmp/img-fail-original.yml"
cp "$wtmp/img-fail/.github/workflows/alt.yml" "$wtmp/img-fail-alt-original.yml"
img_fail_log="$wtmp/img-fail-log"
img_fail_err="$wtmp/img-fail-err"
(
  latest_node_lts() { return 1; }
  REPO_DIR="$wtmp/img-fail" phase_workflows
) > "$img_fail_log" 2> "$img_fail_err"
cmp -s "$wtmp/img-fail/.github/workflows/main.yml" "$wtmp/img-fail-original.yml"
assert_status "$?" 0 "phase_workflows leaves the file byte-identical when the node LTS lookup fails"
cmp -s "$wtmp/img-fail/.github/workflows/alt.yml" "$wtmp/img-fail-alt-original.yml"
assert_status "$?" 0 "phase_workflows leaves every other file byte-identical when the node LTS lookup fails"
assert_eq "$(grep -c 'no latest node LTS found — keeping container images' "$img_fail_err")" "1" \
  "phase_workflows warns exactly once on a failed node LTS lookup and keeps all images"

# --- codename other than trixie preserved ---
mkdir -p "$wtmp/img-codename/.github/workflows"
cat > "$wtmp/img-codename/.github/workflows/main.yml" <<'EOF'
jobs:
  test-build:
    runs-on: ubuntu-latest
    container:
      image: node:22-bookworm-slim
EOF
(
  latest_node_lts() { printf '26.2.0\n'; }
  REPO_DIR="$wtmp/img-codename" phase_workflows
) > /dev/null
assert_eq "$(grep -c 'image: node:26-bookworm-slim' "$wtmp/img-codename/.github/workflows/main.yml")" "1" \
  "phase_workflows preserves the codename from the matched line (bookworm)"

# Bottom guard: standalone run prints totals; sourced run defers to the runner.
finish_spec
