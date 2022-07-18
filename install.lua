local _VERSION = '2.0.0'

local LIST_FILES = {
  -- startup
  'startup/servers.lua',
  -- servers
  'servers/ping-server.lua',
  'servers/cube-server.lua',
  'servers/cube-boot.lua',
  -- programs
  'programs/router.lua', -- router is not in servers folder because he's not ran on every machines
  'programs/ping.lua',
  'programs/cube.lua',
  -- apis
  'apis/net.lua',
  'apis/eventloop.lua',
};

-- remove old files
fs.delete('ping-server.lua'); -- replaced by `servers/ping-server.lua`
fs.delete('ping.lua') -- replaced by `programs/ping.lua`
fs.delete('cube.lua') -- replaced by `programs/cube.lua`
fs.delete('router.lua') -- replaced by `programs/router.lua`
fs.delete('servers/cube-startup.lua'); -- replaced by `servers/cube-boot.lua`

local REPO_PREFIX = 'https://raw.githubusercontent.com/guillaumearm/cc-libs/master/'

local previousDir = shell.dir()

shell.setDir('/')

fs.makeDir('/programs');
fs.makeDir('/apis');
fs.makeDir('/startup');

for _, filePath in pairs(LIST_FILES) do
  fs.delete(filePath)
  shell.execute('wget', REPO_PREFIX .. filePath, filePath)
end

print()
print('=> Execute startup/servers.lua')
shell.execute('/startup/servers.lua')

shell.setDir(previousDir)
