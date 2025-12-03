HerdingEvent = {}

local HerdingEvent_mt = Class(HerdingEvent, Event)
InitEventClass(HerdingEvent, "HerdingEvent")


function HerdingEvent.emptyNew()
    local self = Event.new(HerdingEvent_mt)
    return self
end


function HerdingEvent.new(farmId)

    local self = HerdingEvent.emptyNew()

    self.farmId = farmId

    return self

end


function HerdingEvent:readStream(streamId, connection)

    local animalManager = g_animalManager

    if not animalManager.isInitialised then

        animalManager:validateConflicts()
	    animalManager:configureCollisionControllerOffsets()
        animalManager.isInitialised = true

    end

    local isAllFarms = streamReadBool(streamId)

    if isAllFarms then

        local numFarms = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)

        for i = 1, numFarms do
    
            local farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
            local animalTypeIndex = streamReadUInt8(streamId)
            local numAnimals = streamReadUInt8(streamId)
            local farm = {
                ["animals"] = {},
                ["players"] = {},
                ["animalTypeIndex"] = animalTypeIndex
            }

            for j = 1, numAnimals do

                local visualAnimalIndex = streamReadUInt8(streamId)
                local tiles = {}

                for k = 1, 4 do tiles[k] = streamReadFloat32(streamId) end

                local animal, navMeshAgent = animalManager:createHerdableAnimalFromData(animalTypeIndex, visualAnimalIndex, tiles)
                animal:readStream(streamId)
                animal:setHotspotFarmId(farmId)
		        animal:validateSpeed(animalTypeIndex)
                animal:createCollisionController(navMeshAgent.height, navMeshAgent.radius, animalTypeIndex)
		        animal:updatePosition()
		        animal:updateRotation()

                table.insert(farm.animals, animal)

            end

            animalManager.farms[farmId] = farm

        end

        animalManager.herdingEnabled = numFarms > 0

    else

        local farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
        local animalTypeIndex = streamReadUInt8(streamId)
        local numAnimals = streamReadUInt8(streamId)
        local farm = {
            ["animals"] = {},
            ["players"] = {},
            ["animalTypeIndex"] = animalTypeIndex
        }

        for j = 1, numAnimals do

            local visualAnimalIndex = streamReadUInt8(streamId)
            local tiles = {}

            for k = 1, 4 do tiles[k] = streamReadFloat32(streamId) end

            local animal, navMeshAgent = animalManager:createHerdableAnimalFromData(animalTypeIndex, visualAnimalIndex, tiles)
            animal:readStream(streamId)
            animal:setHotspotFarmId(farmId)
		    animal:validateSpeed(animalTypeIndex)
            animal:createCollisionController(navMeshAgent.height, navMeshAgent.radius, animalTypeIndex)
		    animal:updatePosition()
		    animal:updateRotation()

            table.insert(farm.animals, animal)

        end

        animalManager.farms[farmId] = farm
        animalManager.herdingEnabled = true

    end

    self:run(connection)

end


function HerdingEvent:writeStream(streamId, connection)

    local animalManager = g_animalManager

    streamWriteBool(streamId, self.farmId == nil)

    if self.farmId == nil then

        local numFarms = 0

        for farmId, _ in pairs(animalManager.farms) do numFarms = numFarms + 1 end
    
        streamWriteUIntN(streamId, numFarms, FarmManager.FARM_ID_SEND_NUM_BITS)

        for farmId, farm in pairs(animalManager.farms) do

            streamWriteUIntN(streamId, farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
            streamWriteUInt8(streamId, farm.animalTypeIndex)
            streamWriteUInt8(streamId, #farm.animals)

            for i, animal in pairs(farm.animals) do

                local visualAnimalIndex, tiles = animal:getData()
                streamWriteUInt8(streamId, visualAnimalIndex)
        
                for _, tile in ipairs(tiles) do streamWriteFloat32(streamId, tile) end

                animal:writeStream(streamId)

            end

        end

    else

        local farm = animalManager.farms[self.farmId]
        streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
        streamWriteUInt8(streamId, farm.animalTypeIndex)
        streamWriteUInt8(streamId, #farm.animals)

        for i, animal in pairs(farm.animals) do

            local visualAnimalIndex, tiles = animal:getData()
            streamWriteUInt8(streamId, visualAnimalIndex)
        
            for _, tile in ipairs(tiles) do streamWriteFloat32(streamId, tile) end

            animal:writeStream(streamId)

        end

    end

end


function HerdingEvent:run(connection)

    g_animalManager:setHerdingInputData()

end