#!/bin/sh
# Compatibility shim for the openbao-helm chart. The chart overrides the
# entrypoint and starts the server as
#   /usr/local/bin/docker-entrypoint.sh bao server -config=/tmp/storageconfig.hcl
# which is the upstream image's convention. This image runs as non-root, so
# there is nothing to chown or setcap (the chart sets SKIP_CHOWN/SKIP_SETCAP
# anyway); only the core-dump guard and bare-flag handling are kept.
set -e

# Core dumps could contain key material.
ulimit -c 0

case "$1" in
    -*) set -- bao "$@" ;;
esac

exec "$@"
