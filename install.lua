local _VERSION = '1.0.0'

local LIST_FILES = {
  'startup/servers.lua',
  'servers/ping-server.lua',
  'ping.lua',
  'router.lua',
  'apis/net.lua',
  'apis/eventloop.lua',
};

-- remove old files
fs.delete('ping-server.lua')

local REPO_PREFIX = 'https://raw.githubusercontent.com/guillaumearm/cc-libs/master/'

local previousDir = shell.dir()

shell.setDir('/')

fs.makeDir('/apis');
fs.makeDir('/startup');

for _, filePath in pairs(LIST_FILES) do
  fs.delete(filePath)
  shell.execute('wget', REPO_PREFIX .. filePath, filePath)
end

print()
print('=> Execute startup.lua')
shell.execute('/startup.lua')

shell.setDir(previousDir)
