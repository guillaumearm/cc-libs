local _VERSION = '1.1.1'

local SERVERS = {
  "servers/ping-server",
  "servers/cube-server.lua",
  "servers/cube-startup.lua",
};

local function init()
  shell.setPath(shell.path() .. ':/programs');
end

init();

local periphEmulation = function()
  -- attach modem
  periphemu.create('top', 'modem');

  if os.getComputerID() == 0 then
    -- attach computers

    os.sleep(0.1)
    periphemu.create(1, 'computer');

    os.sleep(0.1)
    periphemu.create(2, 'computer');

    -- attach router
    os.sleep(0.1)
    periphemu.create(10, 'computer');
  end
end

if periphemu then
  periphEmulation();
end

local function shellFn()
  os.sleep(0.1);
  shell.run("shell");
end

local function getServerFns(serverList)
  local servers = {};

  for k, v in ipairs(serverList) do
    local serverName = serverList[k];

    servers[k] = function()
      if serverName then
        shell.run(serverName);
      end
    end
  end

  return servers;
end

local servers = getServerFns(SERVERS);

print("\nStarting servers...");

for _, v in ipairs(SERVERS) do
  print("\t\t" .. v)
end

parallel.waitForAll(shellFn, table.unpack(servers));

print("Servers stopped, reboot the machine...");

os.sleep(1);
os.reboot();
