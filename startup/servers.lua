-- Server Launcher v1.0.0

local SERVERS = {
  "ping-server",
};

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

parallel.waitForAny(shellFn, table.unpack(servers));

print("Servers stopped, reboot the machine...");

os.sleep(1);
os.reboot();
