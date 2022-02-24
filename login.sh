#!/bin/sh

set -eu

# Set this to 1 for more verbosity (on stderr)
LOGIN_VERBOSE=${LOGIN_VERBOSE:-0}

LOGIN_CONFIG=${LOGIN_CONFIG:-"${HOME}/.docker/config.json"}
LOGIN_USERNAME=${LOGIN_USERNAME:-}
LOGIN_PASSWORD=${LOGIN_PASSWORD:-}
LOGIN_PASSWORD_STDIN=${LOGIN_PASSWORD_STDIN:-0}
LOGIN_DEFAULT_REGISTRY=${LOGIN_DEFAULT_REGISTRY:-"docker.io"}

# This uses the comments behind the options to show the help. Not extremly
# correct, but effective and simple.
usage() {
  echo "$0 logins at the registry passed as an argument:" && \
    grep "[[:space:]].)\ #" "$0" |
    sed 's/#//' |
    sed -r 's/([a-z])\)/-\1/'
  exit "${1:-0}"
}

while getopts "c:u:ip:vh-" opt; do
  case "$opt" in
    c) # Path to Docker configuration file, dir will be created if necessary
      LOGIN_CONFIG=$OPTARG;;
    u) # Username to use for authentication.
      LOGIN_USERNAME=$OPTARG;;
    p) # Password to use for authentication.
      LOGIN_PASSWORD=$OPTARG;;
    i) # Obtain password from stdin instead
      LOGIN_PASSWORD_STDIN=1;;
    v) # Turn on verbosity
      LOGIN_VERBOSE=1;;
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
  if [ "$LOGIN_VERBOSE" = "1" ]; then
    printf %s\\n "$1" >&2
  fi
}

_error() {
  printf %s\\n "$1" >&2
  exit 1
}

# Do not continue if no user provided.
if [ -z "$LOGIN_USERNAME" ]; then
  usage 1
fi

# Check binary dependencies
for b in base64 jq; do
  if ! command -v "$b" >/dev/null 2>&1; then
    _error "Cannot continue without $b installed"
  fi
done

# Create Docker configuration directory and JSON configuration file, if
# necessary.
if ! [ -d "$(dirname "$LOGIN_CONFIG")" ]; then
  _verbose "Creating Docker configuration directory $(dirname "$LOGIN_CONFIG")"
  mkdir -p "$(dirname "$LOGIN_CONFIG")"
  touch "$LOGIN_CONFIG"
fi
set -x

# No argument, default to Docker
if [ "$#" = "0" ]; then
  LOGIN_REGISTRY=$LOGIN_DEFAULT_REGISTRY
else
  LOGIN_REGISTRY=$1
fi

# The docker registry has a special case...
if [ "$LOGIN_REGISTRY" = "docker.io" ]; then
  LOGIN_REGISTRY="https://index.docker.io/v1/"
fi
# Scream when there are two password input methods setup
if [ -n "$LOGIN_PASSWORD" ] && [ "$LOGIN_PASSWORD_STDIN" = "1" ]; then
  usage 1
fi

# Get password from stdin
if [ "$LOGIN_PASSWORD_STDIN" = "1" ]; then
  read -r LOGIN_PASSWORD
fi

# Generate a Docker config compatible file with just the information from the
# command-line. Arrange to get it wiped in all circumstances, and do this BEFORE
# it even gets filled with content.
tmp_auth=$(mktemp -t authXXXXX.json)
#shellcheck disable=SC2064  # We WANT to expand now!
trap "rm -f $tmp_auth" EXIT
printf '{"auths":{"%s":{"auth":"%s"}}}\n' \
  "$LOGIN_REGISTRY" \
  "$(printf %s:%s\\n "$LOGIN_USERNAME" "$LOGIN_PASSWORD"| tr -d '\n' | base64 -i -w 0)" \
  > "$tmp_auth"

# Merge the existing configuration with the new information, via a temporary
# configuration file.
tmp_config=$(mktemp -t configXXXXX.json)
if [ -s "$LOGIN_CONFIG" ]; then
  jq -sM '.[0] * .[1]' "$LOGIN_CONFIG" "$tmp_auth" > "$tmp_config"
else
  # Special case: the Docker configuration file was empty: then just format the
  # auth information generated in the previous step.
  jq -M < "$tmp_auth" > "$tmp_config"
fi

# Make configuration the real one and cleanup.
mv "$tmp_config" "$LOGIN_CONFIG"
