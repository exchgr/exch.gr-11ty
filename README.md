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

## Deploying 

For trunk-based development workflows:
```shell
git push origin master
```
or merge your branch.
