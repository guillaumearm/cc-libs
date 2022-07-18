local _VERSION = '1.2.0';
local CUBE_CHANNEL = 64;

local net = require('/apis/net')();

local cubeCommand, firstArg, secondArg = ...;

--- Pads str to length len with char from right
local leftPad = function(str, len, char)
  if char == nil then char = ' ' end
  local nbRepetition = len - #str;

  if nbRepetition > 0 then
    return str .. string.rep(char, len - #str)
  end

  return str;
end

--- Pads str to length len with char from left
local rightPad = function(str, len, char)
  if char == nil then char = ' ' end
  local nbRepetition = len - #str;

  if nbRepetition > 0 then
    return string.rep(char, len - #str) .. str
  end

  return str;
end

local function getRow(str1, str2, str3)
  local row1 = leftPad(tostring(str1 or ''), 6, ' ')
  local row2 = leftPad(tostring(str2 or ''), 16, ' ')
  local row3 = leftPad(tostring(str3 or ''), 6, ' ')

  return row1 .. row2 .. row3;
end

local function isFlag(name)
  return function(arg)
    return arg == '-' .. name or arg == '--' .. name;
  end
end

local isHelpFlag = isFlag('help');
local isVersionFlag = isFlag('version');

local function writeFile(path, content)
  local file = fs.open(path, "w");

  if not file then
    return false;
  end

  file.write(content)
  file.close();

  return true;
end

local function isConfigFileExists()
  return fs.exists('.cuberc');
end

local function printUsage()
  print('cube usage:')
  print();
  print('\t\t\tcube init');
  print('\t\t\tcube ls');
  print('\t\t\tcube configure');
  print('\t\t\tcube set-startup <machineId> [command]')
  print('\t\t\tcube reboot <machineId>')
  print('\t\t\tcube deploy')
  print('\t\t\tcube version')
  print('\t\t\tcube help <command>')
end

local function printUsageCommand(commandName)
  local USAGES = {
    init = function()
      print('\t\t\tcube init');
      print('Init the master cube directory.')
    end,
    ls = function()
      print('\t\t\tcube ls');
      print('Print all available cubes in the cluster.')
    end,
    configure = function()
      print('\t\t\tcube configure');
      print('Setup remote slave cubes.')
    end,
    ["set-startup"] = function()
      print('\t\t\tcube set-startup <machineId> [command]')
      print('Setup a startup shell command on a remote cube.')
    end,
    reboot = function()
      print('\t\t\tcube reboot <machineId>')
      print('Reboot a cube machine.');
    end,
    deploy = function()
      print('\t\t\tcube deploy')
      print('Transfer files on all slave cubes.')
    end,
    version = function()
      print('\t\t\tcube version')
      print('Print the program version.')
    end,
    help = function()
      print('\t\t\tcube help <command>')
      print('Print help on commands.')
    end,
  }

  local usageFn = USAGES[commandName]

  if not usageFn then
    return printUsage();
  end

  return usageFn();
end

if cubeCommand == nil or cubeCommand == '' or isHelpFlag(cubeCommand) then
  printUsage();
  return;
end

local rebootCommand = function(machineId)
  if not isConfigFileExists() then
    print('Error: unable to deploy because \'.cuberc\' file is missing\nTry: \'cube init\' command')
    return;
  end

  if not machineId or machineId == '' then
    printUsageCommand('reboot');
    return;
  end

  local ok, results, packets = net.sendMultipleRequests(CUBE_CHANNEL, 'reboot', true, machineId);

  if not ok then
    error(results);
  end

  for k in ipairs(results) do
    local packet = packets[k];

    print('reboot machine \'' .. tostring(packet.sourceId) .. '\'.');
  end
end

local COMMANDS = {
  init = function()
    if isConfigFileExists() then
      print('cube is already initialized.');
    else
      local ok = writeFile('.cuberc', '');
      if ok then
        print('.cuberc file created');
      else
        error('Cannot create .cuberc file');
      end
    end
  end,
  ls = function()
    local ok, results, packets = net.sendMultipleRequests(CUBE_CHANNEL, 'ping', 'ping');

    if not ok then
      error(results);
    end

    -- print('ID    LABEL\t\t\t\tSTARTUP');
    print(getRow('ID', 'LABEL', 'STARTUP'))

    for k in ipairs(results) do
      local result = results[k];
      local packet = packets[k];


      -- local row1 = leftPad(tostring(packet.sourceId or ''), 8, ' ')
      -- local row2 = leftPad(tostring(packet.sourceLabel or ''), 12, ' ')
      -- local row3 = leftPad(tostring(result.startup or ''), 12, ' ')
      -- print(packet.sourceId, packet.sourceLabel or '', result.startup)
      print(getRow(packet.sourceId, packet.sourceLabel, result.startup))
      -- print("=> " .. tostring(packet.sourceId)
      --   ..
      --   (
      --   packet.sourceLabel and " (label=" .. tostring(packet.sourceLabel) .. ")" or
      --       "") .. ": startup='" .. result.startup .. "'");
    end
  end,
  configure = function()
    if not isConfigFileExists() then
      print('Error: unable to configure because \'.cuberc\' file is missing\nTry: \'cube init\' command')
      return;
    end
    print('not implemented yet.');
  end,
  ["set-startup"] = function(machineId, shellCommand)
    if not isConfigFileExists() then
      print('Error: unable to deploy because \'.cuberc\' file is missing\nTry: \'cube init\' command')
      return;
    end

    if not machineId then
      printUsageCommand('set-startup');
      return;
    end

    local ok, results, packets = net.sendMultipleRequests(CUBE_CHANNEL, 'set-startup', shellCommand, machineId);

    if not ok then
      error(results);
    end

    for k in ipairs(results) do
      local packet = packets[k];

      print('changed startup script on machine \'' ..
        tostring(packet.sourceId) .. '\' by \'' .. tostring(shellCommand or '') .. '\'');

      rebootCommand(packet.sourceId);
    end
  end,
  reboot = rebootCommand,
  deploy = function()
    if not isConfigFileExists() then
      print('Error: unable to deploy because \'.cuberc\' file is missing\nTry: \'cube init\' command')
      return;
    end

    print('not implemented yet.');
  end,
  version = function()
    print('cube client v' .. _VERSION);
  end,
  help = function(commandName)
    printUsageCommand(commandName);
  end
}

local cmd;
if isVersionFlag(cubeCommand) then
  cmd = COMMANDS.version;
else
  cmd = COMMANDS[cubeCommand];
end

if not cmd then
  printUsage();
  return;
end

if (isHelpFlag(firstArg)) then
  printUsageCommand(cubeCommand);
  return;
end

cmd(firstArg, secondArg);
