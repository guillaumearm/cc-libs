local _VERSION = '2.1.0';
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

local function getRow(margin, str1, str2, str3)

  margin = margin or '';

  local row1 = leftPad(margin .. tostring(str1 or ''), 8, ' ')
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

local function printUsage()
  print('cube usage:')
  print();
  print('\t\t\tcube ls');
  print('\t\t\tcube configure');
  print('\t\t\tcube set-boot <machineId> [command]')
  print('\t\t\tcube reboot <machineId>')
  print('\t\t\tcube deploy')
  print('\t\t\tcube version')
  print('\t\t\tcube help <command>')
end

local function printUsageCommand(commandName)
  local function setBootUsage()
    print('\t\t\tcube set-boot <machineId> [command]')
    print('Setup a startup shell command on a remote cube.')
  end

  local USAGES = {
    ls = function()
      print('\t\t\tcube ls');
      print('Print all available cubes in the cluster.')
    end,
    configure = function()
      print('\t\t\tcube configure');
      print('Setup remote slave cubes.')
    end,
    ["set-boot"] = setBootUsage,
    ["setboot"] = setBootUsage,
    ["set-start"] = setBootUsage,
    ["setstart"] = setBootUsage,
    ["set-startup"] = setBootUsage,
    ["setstartup"] = setBootUsage,
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

    print('reboot machine \'' .. tostring(packet.sourceId) .. '\'');
  end
end

local setBootCommand = function(machineId, shellCommand)
  if not machineId then
    printUsageCommand('set-boot');
    return;
  end

  local ok, results, packets = net.sendMultipleRequests(CUBE_CHANNEL, 'set-boot', shellCommand, machineId);

  if not ok then
    error(results);
  end

  for k in ipairs(results) do
    local packet = packets[k];

    if shellCommand == nil or shellCommand == '' then
      print('boot DELETED');
    else
      print('boot UPDATED');
    end

    rebootCommand(packet.sourceId);
  end
end

local COMMANDS = {
  ls = function()
    local ok, results, packets = net.sendMultipleRequests(CUBE_CHANNEL, 'ping', 'ping');

    if not ok then
      error(results);
    end

    -- print('ID    LABEL\t\t\t\tSTARTUP');
    print(getRow('  ', 'ID', 'LABEL', 'BOOT'))
    print('--------------------------------------------')

    for k in ipairs(results) do
      local result = results[k];
      local packet = packets[k];

      print(getRow('  ', packet.sourceId, packet.sourceLabel, result.startup))
    end
  end,
  configure = function()
    print('not implemented yet.');
  end,
  ["set-boot"] = setBootCommand,
  ["setboot"] = setBootCommand,
  ["set-start"] = setBootCommand,
  ["setstart"] = setBootCommand,
  ["set-startup"] = setBootCommand,
  ["setstartup"] = setBootCommand,
  reboot = rebootCommand,
  deploy = function()
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
