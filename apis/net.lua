-- Network API v1.0.1

local DEFAULT_TIMEOUT_WAIT_MESSAGE = 0.5;  -- in seconds
local DEFAULT_ROUTING_CHANNEL = 10;

-- Utilitaire pour savoir si un payload nous est destiné.
-- le parametre 'payload' est une table avec les champs suivants:
--   - sourceId: l'id de la machine qui a envoyé le message
--   - destId: l'id du destinataire, si l'id est nil le message est routé a tout le monde
--   - routerId: l'id du routeur qui s'est occupé de transmettre le message
--   - message: le contenu du message (qui sera le plus souvent une table)
-- return un boolean
local function isPayloadOk(payload)
  if type(payload) ~= "table" then
    return false;
  end

  if not payload.routerId or not payload.sourceId then
    return false;
  end

  if payload.sourceId == os.getComputerID() then
    return false;
  end

  if payload.destId == nil then
    return true;
  end

  if type(payload.destId) == 'number' and payload.destId == os.getComputerID() then
    return true;
  end

  if type(payload.destId) == 'string' and payload.destId == os.getComputerLabel() then
    return true;
  end

  return false;
end

-- Une simple fonction pour chercher une valeur dans une table
local function find(predicate, values)
  for k, v in ipairs(values) do
    if predicate(v, k) then
      return v;
    end
  end

  return nil;
end

-- Fonction utilitaire pour pouvoir pull plusieurs events (modem_message et timer par exemple)
local function pullMultipleEvents(...)
  local eventNames = table.pack(...);

  while true do
    local payload = table.pack(os.pullEvent());
    local eventName = payload[1]

    -- TODO index events
    if find(function(e) return e == eventName end, eventNames) then
      return table.unpack(payload);
    end
  end
end

-- -- Example: implementation simple de ping
--
--
-- local createNet = require('apis/net');
-- net = createNet();
--
-- -- envoyer un message sur le canal 9
-- net.send(9, 'ping');
--
-- -- recevoir et afficher un message sur le canal 9
-- local message = net.waitMessage(9);
-- if message == 'pong' then
--   print('pong recu');
-- end
--
local function createNetwork(modem, routingChannel, timeoutInSec)
  modem = modem or peripheral.find("modem") or error("modem not found");
  routingChannel = routingChannel or DEFAULT_ROUTING_CHANNEL;
  timeoutInSec = timeoutInSec or DEFAULT_TIMEOUT_WAIT_MESSAGE;

  -- net.send function
  local function send(channel, message, destId)
    local payload = {
      sourceId = os.getComputerID(),
      sourceLabel = os.getComputerLabel(),
      routerId = nil,
      destId = destId,
      message = message
    }

    modem.transmit(routingChannel, channel, payload);
  end

  -- net.waitMessage function
  local function waitMessage(channelToListen)
    local receivedPayload;

    modem.open(channelToListen);

    local timerId = os.startTimer(timeoutInSec);
    local timedOut = false;

    repeat
      local messageType, timerIdOrSide, channel, _, payload = pullMultipleEvents("modem_message", "timer");
      local channelOk, payloadOk;

      if messageType == "modem_message" then
        receivedPayload = payload;
        channelOk = channel == channelToListen;
        payloadOk = isPayloadOk(payload);
      elseif messageType == 'timer' and timerIdOrSide == timerId then
        timedOut = true;
      end
    until channelOk and payloadOk or timedOut

    if timedOut then
      return nil;
    end

    if receivedPayload then
      return receivedPayload.message, receivedPayload;
    end

    return nil;
  end

  local function openChannel(chan)
    modem.open(chan);
  end

  return {
    send = send,
    waitMessage = waitMessage,
    isPayloadOk = isPayloadOk,
    openChannel = openChannel,
  }
end

return createNetwork;
