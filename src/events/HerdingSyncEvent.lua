HerdingSyncEvent = {}

local HerdingSyncEvent_mt = Class(HerdingSyncEvent, Event)
InitEventClass(HerdingSyncEvent, "HerdingSyncEvent")


function HerdingSyncEvent.emptyNew()
    local self = Event.new(HerdingSyncEvent_mt)
    return self
end


function HerdingSyncEvent.new(animals, farmId)

    local self = HerdingSyncEvent.emptyNew()

    self.animals = animals
    self.farmId = farmId

    return self

end


function HerdingSyncEvent:readStream(streamId, connection)

    local animalManager = g_animalManager

    -- event can be received before the animal manager is initialised in FSBaseMission.onStartMission
    if not animalManager.isInitialised then return end

    local farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
    local animals = animalManager.farms[farmId].animals
    local numAnimals = streamReadUInt8(streamId)
    local updatedIds = {}
    local hasMoreVisualAnimals = animalManager:getHasHusbandryConflict()
    local idToAnimal = {}

    for _, animal in pairs(animals) do idToAnimal[animal.id] = animal end

    -- sync xz position and y-rotation of animals

    for i = 1, numAnimals do

        local id = streamReadUInt8(streamId)
        updatedIds[id] = true
        idToAnimal[id]:readUpdateStream(streamId)

    end

    -- check if out-of-sync animal has been returned to husbandry server-side

    if numAnimals < #animals then

        for i = #animals, 1, -1 do

            local animal = animals[i]

            if updatedIds[animal.id] == nil then

                if hasMoreVisualAnimals then animal.cluster.idFull, animal.cluster.id = nil, nil end
                animal:delete()
                table.remove(animals, i)

            end

        end

    end

    if #animals == 0 then

        animalManager.herdingEnabled = false
        g_inputBinding:setActionEventActive(animalManager.herdingEventId, false)

    end

end


function HerdingSyncEvent:writeStream(streamId, connection)

    if not g_animalManager:getIsConnectionInitialised(connection) then return end

    local animals = self.animals

    streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
    streamWriteUInt8(streamId, #animals)

    for i, animal in pairs(animals) do

        streamWriteUInt8(streamId, animal.id)
        animal:writeUpdateStream(streamId)

    end

end


function HerdingSyncEvent:run(connection)



end