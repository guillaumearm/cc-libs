local _VERSION = "2.0.0"

-- -- Example: implementation simple de ping-server
local PING_CHANNEL = 9;
local MODEM_DETECTION_TIME = 3;  -- in seconds

local createNet = require('/apis/net');

local modem = peripheral.find('modem');

if not modem then
  print("Warning: modem not found!");
end

-- on attend le modem
while not modem do
  modem = peripheral.find('modem');
  os.sleep(MODEM_DETECTION_TIME);
end

local net = createNet(nil, modem);

net.listenRequest(PING_CHANNEL, 'ping', function(message, reply)
  if message == 'ping' then
    reply('pong');
  end
end)

print('ping-server v' .. _VERSION .. ' started.')

net.start();
