# scripts/lib/cli.bash — CLI argument parsing ONLY: turns flags into the
# WANT_* selection booleans (+ DRY_RUN) that the orchestrator (upgrade.sh)
# reads to decide which phases run. Owns the usage text and the usage-error
# convention (message + usage on stderr, exit 2). No phase logic here.
# Dependencies: common.bash.
# shellcheck source=scripts/lib/common.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.bash"

# Selection result consumed by upgrade.sh's main: 1 = phase requested.
WANT_ALL=0
WANT_YARN=0
WANT_NODE=0
WANT_DEPS=0
WANT_DEV_DEPS=0
WANT_TRANSITIVE=0
WANT_WORKFLOWS=0

usage() {
  cat <<'EOF'
Usage: bash scripts/upgrade.sh [options]

Preflight always runs first, then exactly the selected phases in canonical
order (yarn -> node -> deps -> dev-deps -> transitive -> workflows), then a
summary. No selection is an error: choose the blast radius.

  -a, --all            every phase (yarn node deps dev-deps transitive workflows)
  -y, --yarn           yarn phase: yarn set version berry + install
  -n, --node           node phase: asdf LTS pin + engines rewrite
  -d, --dependencies   deps phase: Eleventy plugin dependency bumps
  -D, --dev-deps       dev-deps phase: devDependencies bumps
  -t, --transitive     transitive phase: yarn up -R + dedupe
  -w, --workflows      workflows phase: GitHub Actions action bumps
  -r, --dry-run        print every mutation without applying it
  -h, --help           show this help and exit
EOF
}

usage_error() {
  warn "$*"
  usage >&2
  exit 2
}

# The ONE place long flags are spelled: long -> single letter consumed by the
# getopts loop (r is the internal letter for --dry-run; D is dev-deps so d
# stays free for --dependencies, as in the deps/dev-deps split).
map_long_option() {
  case "$1" in
    --all) printf 'a' ;;
    --yarn) printf 'y' ;;
    --node) printf 'n' ;;
    --dependencies) printf 'd' ;;
    --dev-deps) printf 'D' ;;
    --transitive) printf 't' ;;
    --workflows) printf 'w' ;;
    --dry-run) printf 'r' ;;
    --help) printf 'h' ;;
    *) return 1 ;;
  esac
}

# The ONE place argv is reshaped for getopts: every `--long` becomes its
# single letter via map_long_option (unknown long flags are usage errors);
# short flags and positionals pass through untouched. Writes the
# NORMALIZED_ARGS global for the immediately following parse_args pass — a
# stdout round-trip would strand usage_error's exit inside a subshell.
NORMALIZED_ARGS=()

normalize_args() {
  NORMALIZED_ARGS=()
  local arg short
  while (( $# )); do
    arg="$1"
    shift
    if [[ "$arg" == --* ]]; then
      short="$(map_long_option "$arg")" || usage_error "unknown option: $arg"
      NORMALIZED_ARGS+=("-$short")
    else
      NORMALIZED_ARGS+=("$arg")
    fi
  done
}

# Post-parse guards, shared by parse_args: a leftover positional operand is a
# usage error, and so is a parse that selected no phase (choose the blast
# radius).
validate_selection() {
  local -a normalized=("$@")
  if (( OPTIND <= ${#normalized[@]} )); then
    usage_error "unexpected argument: ${normalized[OPTIND - 1]}"
  fi
  if (( WANT_ALL + WANT_YARN + WANT_NODE + WANT_DEPS + WANT_DEV_DEPS + WANT_TRANSITIVE + WANT_WORKFLOWS == 0 )); then
    usage_error "no phases selected (use --all for everything)"
  fi
}

parse_args() {
  WANT_ALL=0 WANT_YARN=0 WANT_NODE=0 WANT_DEPS=0 WANT_DEV_DEPS=0
  WANT_TRANSITIVE=0 WANT_WORKFLOWS=0
  # DRY_RUN resets with the selection: a re-parse without -r must not inherit
  # a prior dry-run. No export — DRY_RUN is consumed in-process by the libs.
  DRY_RUN=0
  OPTIND=1
  normalize_args "$@"
  local optspec=":ayndDtwrh" opt
  # ${arr[@]+...} keeps bash 3.2 happy about empty arrays under set -u.
  while getopts "$optspec" opt ${NORMALIZED_ARGS[@]+"${NORMALIZED_ARGS[@]}"}; do
    case "$opt" in
      a) WANT_ALL=1 ;;
      y) WANT_YARN=1 ;;
      n) WANT_NODE=1 ;;
      d) WANT_DEPS=1 ;;
      D) WANT_DEV_DEPS=1 ;;
      t) WANT_TRANSITIVE=1 ;;
      w) WANT_WORKFLOWS=1 ;;
      r) DRY_RUN=1 ;;
      h)
        usage
        exit 0
        ;;
      \?) usage_error "unknown option: -${OPTARG}" ;;
    esac
  done
  validate_selection ${NORMALIZED_ARGS[@]+"${NORMALIZED_ARGS[@]}"}
}
