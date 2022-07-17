local _VERSION = '2.0.0'

-- Basic event loop library for computer craft
--
-- Example usage:
--
-- local events = require('apis/eventloop')()
--
-- local disposeRedstoneEvent = events.register("redstone", function()
--   print("Redstone signal received!")
-- end)
--
-- events.register("key_up", function(k)
--   if k == keys.q then
--     disposeRedstoneEvent()
--     events.stopLoop()
--   end
-- end)
--
-- events.runLoop();
local next_eventloop_id = 1;

local function noop()
end

local STOP = '@libeventloop/STOP_HANDLER_SUBSCRIPTION';

local function createEventLoop()
  local api = {}

  local runningLoop = false;
  local eventloop_id = next_eventloop_id;
  next_eventloop_id = next_eventloop_id + 1;

  local shouldCheckHandlers = true;

  local handlersCounter = 0;
  local allHandlers = {};

  local runningHandlers = nil;
  local unregisterQueue = {};

  -- used when setTimeout are registered when runningLoop is false
  local runningTimeoutHandler = false;
  local timeoutFactoryCounter = 0;
  local nextTimeoutFactoryId = 1;
  local timeoutFactories = {};
  local removeTimeoutQueue = {};

  -- used at runtime
  local timeoutHandlersCounter = 0;
  local timeoutHandlers = {};

  -- onStop handlers
  local onStopHandlerCounter = 0;
  local nextOnStopHandlerId = 1;
  local onStopHandlers = {};

  -- onStart handlers
  local nextOnStartHandlerId = 1;
  local onStartHandlers = {};

  local function resetOnStartHandlers()
    nextOnStartHandlerId = 1;
    onStartHandlers = {};
  end

  local function resetOnStopHandlers()
    onStopHandlerCounter = 0;
    nextOnStopHandlerId = 1;
    onStopHandlers = {};
  end

  local function addOnStopHandler(h)
    local id = nextOnStopHandlerId;

    nextOnStopHandlerId = nextOnStopHandlerId + 1;
    onStopHandlerCounter = onStopHandlerCounter + 1;

    onStopHandlers[id] = h;

    return id;
  end

  local function execOnStartHandlers()
    for _, h in pairs(onStartHandlers) do
      h();
    end
    resetOnStartHandlers();
  end

  local function execOnStopHandlers()
    for _, h in pairs(onStopHandlers) do
      h();
    end
    resetOnStopHandlers();
  end

  local function shouldStop()
    if shouldCheckHandlers then
      return timeoutHandlersCounter + handlersCounter == 0 and timeoutFactoryCounter == 0;
    end

    return false
  end

  local function insertTimeoutHandler(id, handler)
    timeoutHandlers[id] = handler;
    timeoutHandlersCounter = timeoutHandlersCounter + 1
  end

  local function removeTimeoutHandler(id)
    local function removeFn()
      if timeoutHandlers[id] then
        timeoutHandlers[id] = nil;
        timeoutHandlersCounter = timeoutHandlersCounter - 1

        if shouldStop() then
          api.stopLoop();
        end
      end
    end

    table.insert(removeTimeoutQueue, removeFn);
  end

  local function resetFactories()
    timeoutFactoryCounter = 0;
    nextTimeoutFactoryId = 1;
    timeoutFactories = {}
  end

  local function applyTimeoutFactories()
    for _, f in pairs(timeoutFactories) do
      local timerId, h = f()
      insertTimeoutHandler(timerId, h)
    end

    resetFactories();
  end

  local function resetAll()
    runningLoop = false;
    handlersCounter = 0;
    allHandlers = {};
    runningHandlers = nil;
    unregisterQueue = {};

    resetFactories();

    for k, _ in pairs(timeoutHandlers) do
      os.cancelTimer(k);
    end

    runningTimeoutHandler = false;
    timeoutHandlersCounter = 0;
    timeoutHandlers = {};
    removeTimeoutQueue = {};

    resetOnStartHandlers();
    resetOnStopHandlers();
  end

  local function flushUnregisterQueue()
    if #unregisterQueue == 0 then
      return
    end

    for _, f in pairs(unregisterQueue) do
      f()
    end

    unregisterQueue = {}
  end

  local END_OF_LOOP = '@libeventloop/END_OF_LOOP/' .. eventloop_id

  api.STOP = STOP

  -- isRunningLoop
  function api.isRunningLoop()
    return runningLoop;
  end

  -- stopLoop
  function api.stopLoop()
    if api.isRunningLoop() then
      os.queueEvent(END_OF_LOOP)
    else
      error("libeventloop error: loop is already stopped")
    end
  end

  -- unregister
  function api.unregister(eventName, handler)
    assert(type(eventName) == 'string', 'bad argument #1 (string expected)')
    assert(type(handler) == 'function', 'bad argument #2 (function expected)')

    local function removeHandler()
      local handlers = allHandlers[eventName]

      if not handlers then
        error("libeventloop error: no handler registered for the '" .. eventName .. "' event")
      end

      if handlers[handler] then
        handlers[handler] = nil
        handlersCounter = handlersCounter - 1;
        if shouldStop() then
          api.stopLoop();
        end
      end
    end

    if runningHandlers then
      table.insert(unregisterQueue, function()
        return removeHandler()
      end)
      return
    end

    return removeHandler()
  end

  -- register
  function api.register(eventName, handler)
    assert(type(eventName) == 'string', 'bad argument #1 (string expected)')
    assert(type(handler) == 'function', 'bad argument #2 (function expected)')

    if not allHandlers[eventName] then
      allHandlers[eventName] = {}
    end

    local handlers = allHandlers[eventName]
    if handlers[handler] then
      error("libeventloop error: handler already registered for event '" .. eventName .. "'")
    end

    handlers[handler] = handler;
    handlersCounter = handlersCounter + 1;

    return function()
      api.unregister(eventName, handler)
    end
  end

  -- runLoop
  function api.runLoop(noCheckHandlers)
    if api.isRunningLoop() then
      error("libeventloop error: event loop is already ran")
    end

    shouldCheckHandlers = not noCheckHandlers

    applyTimeoutFactories()

    if shouldStop() then
      if onStopHandlerCounter > 0 then
        execOnStopHandlers()
      end
      return
    end

    runningLoop = true;
    execOnStartHandlers()

    while true do
      local packed = table.pack(os.pullEventRaw())
      local eventName = table.remove(packed, 1)

      if eventName == 'timer' then
        -- setTimeout handlers
        local timerId = packed[1];

        runningTimeoutHandler = true
        for k, h in pairs(timeoutHandlers) do
          if k == timerId then
            removeTimeoutHandler(k)
            h();
          end
        end
        runningTimeoutHandler = false

        for _, removeFn in ipairs(removeTimeoutQueue) do
          removeFn()
        end
        removeTimeoutQueue = {}

        applyTimeoutFactories()
      else
        -- regular event handlers
        local handlers = allHandlers[eventName]
        if handlers then
          runningHandlers = eventName
          for _, handler in pairs(handlers) do
            local result_handler = handler(table.unpack(packed))
            if result_handler == api.STOP then
              api.unregister(eventName, handler)
            end
          end
          runningHandlers = nil
          flushUnregisterQueue()
        end

        if eventName == END_OF_LOOP or eventName == 'terminate' then
          execOnStopHandlers()
          resetAll()
          break
        end
      end
    end
  end

  -- startLoop
  api.startLoop = api.runLoop

  -- setTimeout
  function api.setTimeout(handler, seconds)
    seconds = math.abs(seconds or 0);

    assert(type(handler) == 'function', 'bad argument #1 (function expected)')
    assert(type(seconds) == 'number', 'bad argument #2 (number expected)')

    if api.isRunningLoop() and not runningTimeoutHandler then
      local timerId = os.startTimer(seconds)

      insertTimeoutHandler(timerId, handler)

      return function()
        -- clearTimeout
        if timeoutHandlers[timerId] then
          removeTimeoutHandler(timerId)
          os.cancelTimer(timerId);
        end
      end
    else
      local timeoutFactoryId = nextTimeoutFactoryId;
      nextTimeoutFactoryId = nextTimeoutFactoryId + 1

      local timerId = nil;

      local factory = function()
        timerId = os.startTimer(seconds)
        return timerId, handler;
      end

      timeoutFactories[timeoutFactoryId] = factory
      timeoutFactoryCounter = timeoutFactoryCounter + 1;

      return function()
        -- clearTimeout
        if timerId == nil and timeoutFactories[timeoutFactoryId] then
          timeoutFactories[timeoutFactoryId] = nil
          timeoutFactoryCounter = timeoutFactoryCounter - 1;
        elseif timeoutHandlers[timerId] then
          removeTimeoutHandler(timerId)
          os.cancelTimer(timerId);
        end
      end
    end
  end

  -- onStop
  function api.onStop(handler)
    assert(type(handler) == 'function', 'bad argument #1 (function expected)')

    local handlerId = addOnStopHandler(handler);

    return function()
      local h = onStopHandlers[handlerId];
      if h then
        h();
        onStopHandlers[handlerId] = nil
        onStopHandlerCounter = onStopHandlerCounter - 1;
      end
    end
  end

  -- onStart
  function api.onStart(handler)
    assert(type(handler) == 'function', 'bad argument #1 (function expected)');

    if api.isRunningLoop() then
      handler();
      return noop;
    else
      local onStartId = nextOnStartHandlerId;
      nextOnStartHandlerId = nextOnStartHandlerId + 1;

      onStartHandlers[onStartId] = handler

      return function()
        if onStartHandlers[onStartId] then
          onStartHandlers[onStartId] = nil;
        end
      end
    end
  end

  return api;
end

return createEventLoop;
