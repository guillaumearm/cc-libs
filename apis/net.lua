local _VERSION = '2.1.2';

local createEventLoop = require('/apis/eventloop');

local DEFAULT_TIMEOUT_WAIT_MESSAGE = 0.5;  -- in seconds
local DEFAULT_ROUTING_CHANNEL = 10;

-- Utilitaire pour savoir si un packet nous est destiné.
-- le parametre 'packet' est une table avec les champs suivants:
--   - sourceId: l'id de la machine qui a envoyé le message
--   - destId: l'id du destinataire, si l'id est nil le message est routé a tout le monde
--   - routerId: l'id du routeur qui s'est occupé de transmettre le message
--   - message: le contenu du message (qui sera le plus souvent une table)
-- return un boolean
local function isPacketOk(packet)
  if type(packet) ~= "table" then
    return false;
  end


  if not packet.routerId or not packet.sourceId then
    return false;
  end

  -- if packet.sourceId == os.getComputerID() then
  --   return false;
  -- end

  if packet.destId == nil then
    return true;
  end

  if type(packet.destId) == 'number' and packet.destId == os.getComputerID() then
    return true;
  end

  if type(packet.destId) == 'string' and packet.destId == os.getComputerLabel() then
    return true;
  end

  return false;
end

-- -- Example: implementation simple de ping
--
--
-- local createNet = require('apis/net');
-- net = createNet();
-- local net = createNet(nil, modem);

-- net.listenRequest(PING_CHANNEL, 'ping', function(message, reply)
--   if message == 'ping' then
--     reply('pong');
--   end
-- end)
--
local function createNetwork(el, modem, routingChannel, timeoutInSec)
  el = el or createEventLoop();
  modem = modem or peripheral.find("modem") or error("modem not found");
  routingChannel = routingChannel or DEFAULT_ROUTING_CHANNEL;
  timeoutInSec = timeoutInSec or DEFAULT_TIMEOUT_WAIT_MESSAGE;

  local function openChannel(chan)
    return modem.open(chan);
  end

  -- net.send function
  local function sendRaw(channel, message, destId)
    local sourceId = os.getComputerID()
    local sourceLabel = os.getComputerLabel();
    local routerId = nil;

    if _G.isRouterEnabled then
      routerId = sourceId
    end

    local packet = {
      sourceId = sourceId,
      sourceLabel = sourceLabel,
      routerId = routerId,
      destId = tonumber(destId) or destId,
      message = message
    }

    if packet.destId ~= nil and packet.destId == sourceId then
      packet.routerId = packet.sourceId;
      os.queueEvent('modem_message', peripheral.getName(modem), channel, channel, packet, 0);
      return nil;
    end

    if packet.destId == nil or packet.destId == sourceLabel then
      os.queueEvent('modem_message', peripheral.getName(modem), channel, channel, packet, 0);
    end

    if packet.routerId then
      return modem.transmit(channel, channel, packet);
    end

    return modem.transmit(routingChannel, channel, packet);
  end

  local function listenRaw(channel, handler)
    openChannel(channel);

    return el.register('modem_message', function(_, _, replyChannel, packet)
      if isPacketOk(packet) and channel == replyChannel then
        handler(packet.message, packet);
      end
    end)
  end

  local function send(channel, eventType, payload, destId)
    local event = { type = eventType, payload = payload };
    return sendRaw(channel, event, destId);
  end

  local function listen(channel, eventType, handler)
    return listenRaw(channel, function(event, packet)
      if event.type == eventType then
        handler(event.payload, packet)
      end
    end)
  end

  local function listenRequest(channel, eventType, handler)
    return listen(channel, eventType, function(payload, packet)
      local reply = function(responsePayload)
        send(channel, eventType .. "_response", responsePayload, packet.sourceId);
      end

      handler(payload, reply, packet);
    end)
  end

  local function sendRequest(channel, eventType, payload, destId)
    local ok = false;
    local result = nil;
    local packetResult = nil;

    local privateEventLoop = createEventLoop();
    local privateNet = createNetwork(privateEventLoop, modem, routingChannel, timeoutInSec);

    privateNet.listen(channel, eventType .. "_response", function(responsePayload, packet)
      ok = true;
      result = responsePayload
      packetResult = packet;
      privateNet.stop();
    end)

    privateEventLoop.setTimeout(function()
      result = "net.sendRequest timeout!"
      privateNet.stop();
    end, timeoutInSec);

    privateNet.onStart(function()
      privateNet.send(channel, eventType, payload, destId);
    end)

    privateNet.startLoop();

    return ok, result, packetResult;
  end

  local function sendMultipleRequests(channel, eventType, payload, destId)
    if destId ~= nil and tonumber(destId) ~= nil then
      local ok, res, packet = sendRequest(channel, eventType, payload, destId);

      if not ok then
        return ok, res, packet
      end

      return ok, { res }, { packet };
    end

    local ok = false;
    local results = {};
    local packetResults = {};

    local privateEventLoop = createEventLoop();
    local privateNet = createNetwork(privateEventLoop, modem, routingChannel, timeoutInSec);

    privateNet.listen(channel, eventType .. "_response", function(responsePayload, packet)
      ok = true;
      table.insert(results, responsePayload)
      table.insert(packetResults, packet);
    end)

    privateEventLoop.setTimeout(function()
      if #results == 0 then
        results = "net.sendRequest timeout!"
      end
      privateNet.stop();
    end, timeoutInSec);

    privateNet.onStart(function()
      privateNet.send(channel, eventType, payload, destId);
    end)

    privateNet.startLoop();

    return ok, results, packetResults;
  end

  local function createRequest(channel, eventType)
    local requestApi = {};

    function requestApi.send(payload, destId)
      return sendRequest(channel, eventType, payload, destId);
    end

    function requestApi.sendMultiple(payload, destId)
      return sendMultipleRequests(channel, eventType, payload, destId);
    end

    function requestApi.listen(handler)
      return listenRequest(channel, eventType, handler)
    end

    return requestApi;
  end

  local function createEvent(channel, eventType)
    local eventApi = {}


    function eventApi.send(payload, destId)
      return send(channel, eventType, payload, destId);
    end

    function eventApi.listen(handler)
      return listen(channel, eventType, handler)
    end

    return eventApi;
  end

  local function start()
    return el.startLoop();
  end

  local function stop()
    return el.stopLoop();
  end

  return {
    sendRaw = sendRaw,
    listenRaw = listenRaw,
    send = send,
    listen = listen,
    sendRequest = sendRequest,
    sendMultipleRequests = sendMultipleRequests,
    listenRequest = listenRequest,
    createRequest = createRequest,
    createEvent = createEvent,
    isPacketOk = isPacketOk,
    openChannel = openChannel,
    open = openChannel,
    events = el,
    eventloop = el,
    start = start,
    startLoop = start,
    stop = stop,
    stopLoop = stop,
    onStart = el.onStart,
    onStop = el.onStop,
  }
end

return createNetwork;
