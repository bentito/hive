#!/bin/bash -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

docker build \
    -t quay.io/coreos/hive:metering-2.3.3 \
    -f "$DIR/Dockerfile" \
    "$DIR"
