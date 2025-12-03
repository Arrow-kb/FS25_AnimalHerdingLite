HerdingPlayerSyncEvent = {}

local HerdingPlayerSyncEvent_mt = Class(HerdingPlayerSyncEvent, Event)
InitEventClass(HerdingPlayerSyncEvent, "HerdingPlayerSyncEvent")


function HerdingPlayerSyncEvent.emptyNew()
    local self = Event.new(HerdingPlayerSyncEvent_mt)
    return self
end


function HerdingPlayerSyncEvent.new()

    local self = HerdingPlayerSyncEvent.emptyNew()

    return self

end


function HerdingPlayerSyncEvent:readStream(streamId, connection)

    -- sync player positions for animal direction calculation

    local playerPositions = {}
    local farms = g_animalManager.farms
    local numFarms = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)

    for i = 1, numFarms do
    
        local farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
        local numPositions = streamReadUIntN(streamId, 5)
        local positions = {}

        for j = 1, numPositions do

            local x = streamReadFloat32(streamId)
            local z = streamReadFloat32(streamId)
            local hasBucket = streamReadBool(streamId)

            table.insert(positions, { x, z, hasBucket })

        end

        farms[farmId].players = positions
        playerPositions[farmId] = positions

    end

    g_animalManager.playerPositions = playerPositions

end


function HerdingPlayerSyncEvent:writeStream(streamId, connection)

    local playerPositions = g_animalManager.playerPositions
    local numFarms = 0

    for farmId, _ in pairs(playerPositions) do numFarms = numFarms + 1 end

    streamWriteUIntN(streamId, numFarms, FarmManager.FARM_ID_SEND_NUM_BITS)

    for farmId, positions in pairs(playerPositions) do

        streamWriteUIntN(streamId, farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
        streamWriteUIntN(streamId, #positions, 5)

        for _, position in ipairs(positions) do

            streamWriteFloat32(streamId, position[1])
            streamWriteFloat32(streamId, position[2])
            streamWriteBool(streamId, position[3]) -- is carrying feed bucket

        end

    end

end


function HerdingPlayerSyncEvent:run(connection)



end