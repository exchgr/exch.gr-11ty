# exch.gr-11ty

## What It Is
exch.gr-11ty is the front-end web portion of the blog hosted at https://exch.gr/. Using [11ty](https://www.11ty.dev), it pulls data from the [strapi backend](https://github.com/exchgr/exch.gr-strapi) and generates static HTML pages, stylesheets, RSS feeds, and minimal javascript.

## Developing

1. In [strapi](https://github.com/exchgr/exch.gr-strapi), generate an API token and remember it for the next step.
1. Set these environment variables: 

```shell
STRAPI_PROTOCOL=http
STRAPI_HOST=127.0.0.1
STRAPI_PORT=1337
STRAPI_TOKEN=TOKEN_YOU_JUST_GENERATED
STRAPI_FETCH_INTERVAL=0s
```
3. Run:
```
$ npx 11ty-serve
```

## Upgrading

Toolchain prerequisites:

- `brew bundle` installs the CLI tools in the `Brewfile` (everything required by `scripts/upgrade.sh`).
- node is managed by asdf and pinned in `.tool-versions`.
- yarn upgrades itself via `yarn set version berry`.

The `upgrade` yarn script (`bash scripts/upgrade.sh`) runs the phases selected by the flags below. A hard-fail preflight aborts the run if a required tool is missing, `gh` is not authenticated, or the worktree is dirty.

Run everything with `yarn run upgrade --all`, or select phases piecemeal to control blast radius — flags combine; running with no flags is a usage error.

| Flag | Phase |
| --- | --- |
| `-a`, `--all` | every phase |
| `-y`, `--yarn` | yarn berry + install |
| `-n`, `--node` | asdf node LTS pin + engines rewrite |
| `-d`, `--dependencies` | direct dependency bumps |
| `-D`, `--dev-deps` | devDependencies bumps |
| `-t`, `--transitive` | transitive refresh + dedupe + dependabot security bumps |
| `-w`, `--workflows` | GitHub Actions action pins + the `node:<major>-trixie-slim` container image in `.github/workflows/main.yml` |
| `-r`, `--dry-run` | print planned mutations without applying them; composes with any selection |
| `-h`, `--help` | show usage |

```
yarn run upgrade -dt              # deps + transitive only
yarn run upgrade --all --dry-run  # preview everything, change nothing
```

Notes:

- Dependabot alerts (fetched via `gh` during the `-t` phase) trigger bumps: packages declared in `package.json` get `yarn up`, transitive-only packages get `yarn set resolution`. If the `gh` fetch fails, this step is skipped with a warning — the rest of the run continues.
- `NODE_VERSION` is a GitHub repository variable (`${{ vars.NODE_VERSION }}`) that feeds the CI cache keys — the script cannot manage it. Update it in GitHub settings whenever the node major changes (the run summary reminds you).
- The script never commits; inspect `git diff` before committing.

Development: `bash scripts/all.spec.bash` runs the script's test suite.

## Deploying 

For trunk-based development workflows:
```shell
git push origin master
```
or merge your branch.
