# exch.gr 11ty frontend

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
