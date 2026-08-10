# TODO (the second coming)

## init
- [ ] Replace the `startServices` step with starting the daemon and keeping its pid
- [ ] In `pid1.zig#intoRebootSyscall`, send SIGINT to the daemon to start shutting down, wait a few seconds, and then send SIGQUIT if its not dead

## Services:
- [ ] Cron
- [ ] Network stuff
- [ ] Syslog
