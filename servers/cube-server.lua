local _VERSION = '2.0.0';

local net = require('/apis/net')();

local CUBE_CHANNEL = 64;

local function trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function readFile(path)
  local file = fs.open(path, "r");

  if not file then
    return nil;
  end

  local contents = file.readAll()
  file.close()

  return contents
end

local function writeFile(path, content)
  local file = fs.open(path, "w");

  if not file then
    return false;
  end

  file.write(content)
  file.close();

  return true;
end

local function getStartupCommand()
  return trim(readFile('.cubeboot') or "")
end

-- ping event
net.listenRequest(CUBE_CHANNEL, "ping", function(_, reply)
  local startupCommand = getStartupCommand();

  reply({ startup = startupCommand });
end)

-- reboot event
net.listenRequest(CUBE_CHANNEL, "reboot", function(_, reply)
  reply(true);

  os.sleep(0.2)
  os.reboot()
end)

-- set-boot event
net.listenRequest(CUBE_CHANNEL, "set-boot", function(startupCommand, reply)
  local res = writeFile('/.cubeboot', startupCommand);
  reply(res);
end)

-- deploy-file event
net.listenRequest(CUBE_CHANNEL, "deploy-file", function(payload, reply)
  writeFile(payload.path, payload.content);
  reply(true);
end)

print('cube-server v' .. _VERSION .. ' started.')

-- start event loop
net.startLoop();
