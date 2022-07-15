-- ping-server v1.0.0

-- -- Example: implementation simple de ping-server
local PING_CHANNEL = 9;
local MODEM_DETECTION_TIME = 3;  -- in seconds

local createNet = require('apis/net');

local modem = peripheral.find('modem');

if not modem then
  print("Warning: modem not found!");
end

-- on attend le modem
while not modem do
  modem = peripheral.find('modem');
  os.sleep(MODEM_DETECTION_TIME);
end

local net = createNet(modem);

while true do
  local message, payload = net.waitMessage(PING_CHANNEL);

  if message == 'ping' then
    -- le troisième parametre de la fonction `net.send` est pour router un message a une machine specifique
    net.send(PING_CHANNEL, 'pong', payload.sourceId);
  end
end
