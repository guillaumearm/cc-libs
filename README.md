# Trap's ComputerCraft APIs

## Installation
```
wget run https://raw.githubusercontent.com/guillaumearm/cc-libs/master/install.lua
```

## Apis
- `/apis/eventloop`: a simple event loop api
- `/apis/net`: api to simplify sending and receiving routed messages (based on `eventloop` library)

## Servers
All servers are automatically started at boot

- `/servers/ping-server`: allow a machine to respond to a `ping` command.
- `/servers/cube-server`: allow a machine to be controllable via `cube`.
- `/servers/cube-startup.lua`: `cube` startup script.

## Programs
- `router`: route messages (you need to setup a router to be able to use all `apis/net` based programs and libs)
- `ping` : ping machines (use `apis/net`)
- `cube`: cube client for deployment (use `cube help` command for more details)