local _VERSION = '1.0.0';

local net = require('/apis/net')();

local CUBE_CHANNEL = 64;

local function trim(str)
  return str:gsub("%s+", "");
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
  return trim(readFile('.cubestartup') or "")
end

-- ping event
net.listenRequest(CUBE_CHANNEL, "ping", function(_, reply)
  local startupCommand = getStartupCommand();

  reply({ startup = startupCommand });
end)

-- reboot event
net.listenRequest(CUBE_CHANNEL, "reboot", function(_, reply)
  reply(true);
  os.reboot();
end)

-- set-startup event
net.listenRequest(CUBE_CHANNEL, "set-startup", function(startupCommand, reply)
  local res = writeFile('/.cubestartup', startupCommand);
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