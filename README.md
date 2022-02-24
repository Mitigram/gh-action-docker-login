# Clientless Docker Login

This action login at a remote Docker registry, without requiring the Docker
client to be installed. It should otherwise behave as the official [login]
action: it accepts the same inputs and has the same defaults. This action is
meant to be used when building Docker images in dockerless environments.

  [login]: https://github.com/docker/login-action

## Usage

To authenticate against the [Docker Hub][hub] use a token, stored as a secret.
The example below is shamelessly adapted from the [official][login] lead
example:

```yaml
name: ci

on:
  push:
    branches: main

jobs:
  login:
    runs-on: ubuntu-latest
    steps:
      -
        name: Login to Docker Hub
        uses: Mitigram/gh-action-docker-login@main
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
```

  [hub]: https://hub.docker.com/

## Implementation Details

This action is a composite action and uses shell scripts for login/logout
operations. The implemenation requires `jq` to be installed in the runner.

As there is no `post` support for [composite] actions, this action uses a
separate [action][action-post-run] to schedule logout from the registry.

  [composite]: https://docs.github.com/en/actions/creating-actions/metadata-syntax-for-github-actions#runs-for-composite-actions
  [action-post-run]: https://github.com/webiny/action-post-run
