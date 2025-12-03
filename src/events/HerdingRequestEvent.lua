HerdingRequestEvent = {}

local HerdingRequestEvent_mt = Class(HerdingRequestEvent, Event)
InitEventClass(HerdingRequestEvent, "HerdingRequestEvent")


function HerdingRequestEvent.emptyNew()
    local self = Event.new(HerdingRequestEvent_mt)
    return self
end


function HerdingRequestEvent.new(enable, placeable, farmId)

    local self = HerdingRequestEvent.emptyNew()

    self.enable = enable
    self.placeable = placeable
    self.farmId = farmId

    return self

end


function HerdingRequestEvent:readStream(streamId, connection)

    if not connection:getIsServer() then
        self.enable = streamReadBool(streamId)
        self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
        local hasPlaceable = streamReadBool(streamId)
        if hasPlaceable then self.placeable = NetworkUtil.readNodeObject(streamId) end
        self:run(connection)
    end

end


function HerdingRequestEvent:writeStream(streamId, connection)

    if connection:getIsServer() then
        streamWriteBool(streamId, self.enable or false)
        streamWriteUIntN(streamId, self.farmId or 0, FarmManager.FARM_ID_SEND_NUM_BITS)
        streamWriteBool(streamId, self.placeable ~= nil)
        if self.placeable ~= nil then NetworkUtil.writeNodeObject(streamId, self.placeable) end
    end

end


function HerdingRequestEvent:run(connection)

    if self.enable and self.placeable ~= nil then
        g_animalManager:startHerding(self.placeable)
    elseif self.farmId ~= nil then
        g_animalManager:stopHerding(self.farmId)
    end

end