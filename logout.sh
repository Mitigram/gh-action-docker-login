#!/bin/sh

set -eu

# Set this to 1 for more verbosity (on stderr)
LOGOUT_VERBOSE=${LOGOUT_VERBOSE:-0}

LOGOUT_CONFIG=${LOGOUT_CONFIG:-"${HOME}/.docker/config.json"}
LOGOUT_DEFAULT_REGISTRY=${LOGOUT_DEFAULT_REGISTRY:-"docker.io"}

# This uses the comments behind the options to show the help. Not extremly
# correct, but effective and simple.
usage() {
  echo "$0 logouts from the registry passed as an argument:" && \
    grep "[[:space:]].)\ #" "$0" |
    sed 's/#//' |
    sed -r 's/([a-z])\)/-\1/'
  exit "${1:-0}"
}

while getopts "c:vh-" opt; do
  case "$opt" in
    c) # Path to Docker configuration file, dir will be created if necessary
      LOGOUT_CONFIG=$OPTARG;;
    v) # Turn on verbosity
      LOGOUT_VERBOSE=1;;
    h) # Print help and exit
      usage;;
    -)
      break;;
    *)
      usage 1;;
  esac
done
shift $((OPTIND-1))


_verbose() {
  if [ "$LOGOUT_VERBOSE" = "1" ]; then
    printf %s\\n "$1" >&2
  fi
}

_error() {
  printf %s\\n "$1" >&2
  exit 1
}

# Check binary dependencies
for b in base64 jq; do
  if ! command -v "$b" >/dev/null 2>&1; then
    _error "Cannot continue without $b installed"
  fi
done

# Create Docker configuration directory and JSON configuration file, if
# necessary.
if ! [ -d "$(dirname "$LOGOUT_CONFIG")" ]; then
  _verbose "Creating Docker configuration directory $(dirname "$LOGOUT_CONFIG")"
  mkdir -p "$(dirname "$LOGOUT_CONFIG")"
  touch "$LOGOUT_CONFIG"
fi

# No argument, default to Docker
if [ "$#" = "0" ] || [ -z "$1" ]; then
  LOGOUT_REGISTRY=$LOGOUT_DEFAULT_REGISTRY
else
  LOGOUT_REGISTRY=$1
fi

# The docker registry has a special case...
if [ "$LOGOUT_REGISTRY" = "docker.io" ]; then
  LOGOUT_REGISTRY="https://index.docker.io/v1/"
fi

if jq -rM '.|keys' < "$LOGOUT_CONFIG" | grep -Fq '"auths"'; then
  if jq -rM '.auths|keys' < "$LOGOUT_CONFIG" | grep -Fq "\"$LOGOUT_REGISTRY\""; then
    tmp_config=$(mktemp -t configXXXXX.json)
    jq -M "del(.auths.\"$LOGOUT_REGISTRY\")" < "$LOGOUT_CONFIG" > "$tmp_config"
    # Make configuration the real one
    mv "$tmp_config" "$LOGOUT_CONFIG"
  fi
fi
