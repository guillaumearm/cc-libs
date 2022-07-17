local _VERSION = '2.0.2';

local firstArg = ...;
if firstArg == '-version' or firstArg == '--version' then
  print('v' .. _VERSION);
  return;
end

local PING_CHANNEL = 9;

local createNet = require('/apis/net');
local net = createNet();

local args = table.pack(...);
local targetComputerId = tonumber(args[1]) or args[1];

local sourceId = os.getComputerID()
local sourceLabel = os.getComputerLabel();


-- envoyer un message sur le canal 9 à la machine cible

local ok, results, packets = net.sendMultipleRequests(PING_CHANNEL, 'ping', 'ping', targetComputerId);

if not ok and (targetComputerId ~= sourceId and targetComputerId ~= sourceLabel) then
  error(results)
end

if not ok then
  return;
end

for k, message in ipairs(results) do
  if message == 'pong' then
    local packet = packets[k];

    -- if targetComputerId == nil or targetComputerId == packet.sourceId or targetComputerId == packet.sourceLabel then
    print("=> pong from " .. tostring(packet.sourceId)
      .. (packet.sourceLabel and " (label=" .. tostring(packet.sourceLabel) .. ")" or ""));
    -- end
  end
end
