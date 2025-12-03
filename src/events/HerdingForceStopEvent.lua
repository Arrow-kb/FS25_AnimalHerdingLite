HerdingForceStopEvent = {}

local HerdingForceStopEvent_mt = Class(HerdingForceStopEvent, Event)
InitEventClass(HerdingForceStopEvent, "HerdingForceStopEvent")


function HerdingForceStopEvent.emptyNew()
    local self = Event.new(HerdingForceStopEvent_mt)
    return self
end


function HerdingForceStopEvent.new(farmId)

    local self = HerdingForceStopEvent.emptyNew()

    self.farmId = farmId

    return self

end


function HerdingForceStopEvent:readStream(streamId, connection)

    self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)

    self:run(connection)

end


function HerdingForceStopEvent:writeStream(streamId, connection)

    streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)

end


function HerdingForceStopEvent:run(connection)

    local farm = g_animalManager.farms[self.farmId]

    if farm == nil then return end

    for _, animal in pairs(farm.animals) do animal:delete() end

    g_animalManager.farms[self.farmId] = nil
    local hasFarms = false

    for _, farm in pairs(g_animalManager.farms) do
        hasFarms = true
        break
    end

    g_animalManager.herdingEnabled = hasFarms
    g_animalManager:setHerdingInputData()

end