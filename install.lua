local LIST_FILES = {
  'ping.lua',
  'ping-server.lua',
  'router.lua',
  'startup/servers.lua',
  'apis/net.lua',
};

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
