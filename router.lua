local _VERSION = '1.3.1';

local firstArg = ...;

if firstArg == '-version' or firstArg == '--version' then
  print('v' .. _VERSION);
  return;
end

local verbose = true
local printVerbose = print

if firstArg == '-silent' or firstArg == '--silent' then
  verbose = false
  printVerbose = function() end
end

local ROUTER_CHANNEL = 10;

local modem = peripheral.find("modem") or error("modem not found");
modem.open(ROUTER_CHANNEL);

printVerbose('started router on port ' .. tostring(ROUTER_CHANNEL) .. '...')

local routerId = os.getComputerID();

_G.isRouterEnabled = true;

while true do
  local channel, replyChannel, payload, distance;

  repeat
    _, _, channel, replyChannel, payload, distance = os.pullEvent("modem_message");

    local channelOk = channel == ROUTER_CHANNEL;
    local payloadOk = type(payload) == 'table' and not payload.routerId;
    local loopFinished = channelOk and payloadOk;
  until loopFinished


  if payload and not payload.routerId then
    payload.routerId = routerId;

    if payload.destId == nil or payload.destId == os.getComputerID() or payload.destId == os.getComputerLabel() then
      os.queueEvent('modem_message', peripheral.getName(modem), replyChannel, replyChannel, payload, distance);
    end
    if payload.destId ~= os.getComputerID() then
      modem.transmit(replyChannel, replyChannel, payload);
    end
  end

  if payload.destId then
    printVerbose("Routed message from " .. tostring(payload.sourceId)
      .. " to " .. tostring(payload.destId)
      .. " using channel " .. tostring(replyChannel));
  else
    printVerbose("Broadcasted message from " .. tostring(payload.sourceId)
      .. " using channel " .. tostring(replyChannel));
  end
end
