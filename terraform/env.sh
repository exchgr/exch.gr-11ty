#!/usr/bin/env bash

set -e

cd "$(dirname $0)"

envsubst < env.json
