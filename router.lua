-- router v1.2.0

local ROUTER_CHANNEL = 10;
local VERBOSE = true;

local modem = peripheral.find("modem") or error("modem not found");
modem.open(ROUTER_CHANNEL);

print('started router on port ' .. tostring(ROUTER_CHANNEL) .. '...')

local routerId = os.getComputerID();

local function isPingForServer(payload)

  if not payload.message then
    return false;
  end

  if payload.message.type ~= 'ping' then
    return false;
  end

  if payload.destId == routerId or payload.destId == os.getComputerLabel() then
    return true;
  end

  if payload.destId == nil then
    return true;
  end

  return false;
end

while true do
  local channel, replyChannel, payload, pingForServer;

  repeat
    _, _, channel, replyChannel, payload = os.pullEvent("modem_message");
    pingForServer = isPingForServer(payload)

    local channelOk = channel == ROUTER_CHANNEL;
    local payloadOk = type(payload) == 'table' and not payload.routerId or pingForServer;
    local loopFinished = channelOk and payloadOk;
  until loopFinished


  if payload and not payload.routerId then
    if pingForServer then
      local responseRouterPayload = {
        sourceId = os.getComputerID(),
        sourceLabel = os.getComputerLabel(),
        routerId = routerId,
        destId = payload.sourceId,
        message = { type = "ping_response", payload = "pong" }
      }
      modem.transmit(replyChannel, replyChannel, responseRouterPayload)
    end
    if not pingForServer or payload.destId == nil then
      payload.routerId = routerId;
      modem.transmit(replyChannel, replyChannel, payload);
    end
  end

  if VERBOSE then
    if payload.destId then
      if pingForServer then
        print('ping for server received!');
      else
        print("Routed message from " .. tostring(payload.sourceId)
          .. " to " .. tostring(payload.destId)
          .. " using channel " .. tostring(replyChannel));
      end
    else
      print("Broadcasted message from " .. tostring(payload.sourceId)
        .. " using channel " .. tostring(replyChannel));
    end
  end
end
