# Trap's ComputerCraft APIs

## Installation
```
wget run https://raw.githubusercontent.com/guillaumearm/cc-libs/master/install.lua
```

## Apis
- `apis/eventloop`: a simple eventloop library
- `apis/net`: api to simplify sending and receiving routed messages (based on eventloop library)

## Servers
- `router`: route messages (you need to setup a router to be able to use all `apis/net` based programs and libs)
- `servers/ping-server`: is automatically started on boot (use `apis/net`)

## Programs
- `ping` : ping machines (use `apis/net`)