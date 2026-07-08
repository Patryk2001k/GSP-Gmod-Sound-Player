GModReactBridge = {}
GModReactBridge.__index = GModReactBridge

function GModReactBridge:New(dhtml_panel)
    local obj = {
        Panel = dhtml_panel,
        Callbacks = {},
        IsReady = false,
        Queue = {}
    }
    setmetatable(obj, GModReactBridge)

    dhtml_panel:AddFunction("gmod_internal", "sendEvent", function(eventName, jsonData)
        local data = util.JSONToTable(jsonData or "{}")
        if obj.Callbacks[eventName] then
            obj.Callbacks[eventName](data)
        end
    end)

    dhtml_panel:AddFunction("gmod_internal", "markReady", function()
        obj.IsReady = true
        for _, evt in ipairs(obj.Queue) do
            obj:Emit(evt.name, evt.data)
        end
        obj.Queue = {}
    end)

    return obj
end

function GModReactBridge:On(eventName, callback)
    self.Callbacks[eventName] = callback
end

function GModReactBridge:Emit(eventName, data)
    if not self.IsReady then
        table.insert(self.Queue, {name = eventName, data = data})
        return
    end
    
    if type(data) ~= "table" then
        data = { value = data }
    end

    local json = util.TableToJSON(data)
    local jsCode = string.format("window.__GMOD_RECEIVE('%s', %s);", eventName, json)
    self.Panel:RunJavascript(jsCode)
end