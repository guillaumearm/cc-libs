local _VERSION = '2.0.0';

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

local startupCommand = trim(readFile('.cubeboot') or "");


if startupCommand ~= "" then
  print('cube-boot v' .. _VERSION .. ': execute \'' .. startupCommand .. '\'...');
  shell.run(startupCommand);
else
  print('cube-startup v' .. _VERSION .. ' no startup command detected.')
end
