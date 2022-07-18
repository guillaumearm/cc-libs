local _VERSION = '2.2.0';
local CUBE_CHANNEL = 64;

local net = require('/apis/net')();

local cubeCommand, firstArg, secondArg = ...;

local IGNORED_PATHS = {
  ['/rom'] = true,
  ['/.cubeboot'] = true,
  ['/.git'] = true,
  ['/.gitignore'] = true,
}

local function isValidPath(givenPath)
  return not IGNORED_PATHS[givenPath]
end

local function getAllFiles(basePath, result)
  basePath = basePath or '/'
  result = result or {};

  local fileNames = fs.list(basePath)

  for i = 1, #fileNames do
    local filePath = basePath .. fileNames[i];
    local valid = isValidPath(filePath);

    if valid and fs.isDir(filePath) then
      getAllFiles(filePath .. '/', result);
    elseif valid and not fs.isDir(filePath) then
      table.insert(result, filePath)
    end
  end

  return result;
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

------------
-- reboot --
------------
local function rebootCommand(machineId)
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

--------------
-- set-boot --
--------------
local function setBootCommand(machineId, shellCommand)
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

------------
-- deploy --
------------
local function deployCommand()
  local allFiles = getAllFiles()

  -- 1. get all machine ids (except the current one)
  local ok, results, packets = net.sendMultipleRequests(CUBE_CHANNEL, 'ping', 'ping');

  if not ok then
    error(results);
  end

  local machineIds = {};

  local localComputerId = os.getComputerID();

  for k in ipairs(results) do
    local packet = packets[k];

    if packet.sourceId ~= localComputerId then
      table.insert(machineIds, packet.sourceId);
    end
  end

  -- 2. transfer files on all concerned machines
  for machineIndex = 1, #machineIds do
    local machineId = machineIds[machineIndex];

    local fileTransfered = 0;

    for i = 1, #allFiles do
      local filePath = allFiles[i];
      local fileContent = readFile(filePath)

      local ok, res = net.sendRequest(CUBE_CHANNEL, 'deploy-file', { path = filePath, content = fileContent }, machineId);

      if ok and res then
        fileTransfered = fileTransfered + 1;
      else
        print('Error transfering file \'' .. filePath .. '\'');
      end
    end

    print('|> ' .. tostring(fileTransfered) .. ' file(s) transfered on machine ' .. tostring(machineId))

    rebootCommand(machineId);
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

    local localMachineId = os.getComputerID();

    for k in ipairs(results) do
      local result = results[k];
      local packet = packets[k];

      local prefix = '  ';

      if packet.sourceId == localMachineId then
        prefix = '* '
      end

      print(getRow(prefix, packet.sourceId, packet.sourceLabel, result.startup))
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
  deploy = deployCommand,
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
