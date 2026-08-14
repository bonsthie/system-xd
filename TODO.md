# TODO (the second coming)

- cli/daemon
  - [ ] Add "enabled" status back to the service, but get it from the filename (.disabled.toml or not)
    - That way, even disabled services can be started/stopped
    - Make sure reloading after a service changed enabled state doesn't restart it
