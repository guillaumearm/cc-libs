-- ping v1.2.0
local PING_CHANNEL = 9;

local createNet = require('apis/net');
local net = createNet();

local args = table.pack(...);
local targetComputerId = tonumber(args[1]) or args[1];


local sourceId = os.getComputerID()
local sourceLabel = os.getComputerLabel();

-- gérer les pongs locales
if targetComputerId == nil or targetComputerId == sourceId or targetComputerId == sourceLabel then
  print("=> local pong from " .. tostring(sourceId)
    .. (sourceLabel and " (label=" .. tostring(sourceLabel) .. ")" or ""));
end

-- envoyer un message sur le canal 9 à la machine cible
net.send(PING_CHANNEL, "ping", targetComputerId);

-- recevoir et afficher un message sur le canal 9
while true do
  local message, payload = net.waitMessage(PING_CHANNEL);

  if message == "pong" then
    print("=> pong from " .. tostring(payload.sourceId)
      .. (payload.sourceLabel and " (label=" .. tostring(payload.sourceLabel) .. ")" or ""));
  elseif message == nil then
    break
  end
end
