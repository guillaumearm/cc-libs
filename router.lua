local _VERSION = '1.2.0';

local firstArg = ...;

if firstArg == '-version' or firstArg == '--version' then
  print('v' .. _VERSION);
  return;
end

if firstArg then
  error('Invalid router argument.');
  return
end

local ROUTER_CHANNEL = 10;
local VERBOSE = true;

local modem = peripheral.find("modem") or error("modem not found");
modem.open(ROUTER_CHANNEL);

print('started router on port ' .. tostring(ROUTER_CHANNEL) .. '...')

local routerId = os.getComputerID();

_G.isRouterEnabled = true;

while true do
  local channel, replyChannel, payload;

  repeat
    _, _, channel, replyChannel, payload = os.pullEvent("modem_message");

    local channelOk = channel == ROUTER_CHANNEL;
    local payloadOk = type(payload) == 'table' and not payload.routerId;
    local loopFinished = channelOk and payloadOk;
  until loopFinished


  if payload and not payload.routerId then
    payload.routerId = routerId;
    modem.transmit(replyChannel, replyChannel, payload);
  end

  if VERBOSE then
    if payload.destId then
      print("Routed message from " .. tostring(payload.sourceId)
        .. " to " .. tostring(payload.destId)
        .. " using channel " .. tostring(replyChannel));
    else
      print("Broadcasted message from " .. tostring(payload.sourceId)
        .. " using channel " .. tostring(replyChannel));
    end
  end
end
