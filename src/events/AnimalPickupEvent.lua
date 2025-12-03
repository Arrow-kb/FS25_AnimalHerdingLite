AnimalPickupEvent = {}

local AnimalPickupEvent_mt = Class(AnimalPickupEvent, Event)
InitEventClass(AnimalPickupEvent, "AnimalPickupEvent")


function AnimalPickupEvent.emptyNew()
    local self = Event.new(AnimalPickupEvent_mt)
    return self
end


function AnimalPickupEvent.new(husbandry, clusterId, numAnimals)

    local self = AnimalPickupEvent.emptyNew()

    self.husbandry = husbandry
    self.clusterId = clusterId
    self.numAnimals = numAnimals

    return self

end


function AnimalPickupEvent:readStream(streamId, connection)

    if not connection:getIsServer() then
        self.husbandry = NetworkUtil.readNodeObject(streamId)
        self.clusterId = streamReadUInt32(streamId)
        self.numAnimals = streamReadUInt16(streamId)
        self:run(connection)
    end

end


function AnimalPickupEvent:writeStream(streamId, connection)

    if connection:getIsServer() then
        NetworkUtil.writeNodeObject(streamId, self.husbandry)
        streamWriteUInt32(streamId, self.clusterId)
        streamWriteUInt16(streamId, self.numAnimals)
    end

end


function AnimalPickupEvent:run(connection)

    if self.husbandry == nil then return end
	
    local cluster = self.husbandry:getClusterById(self.clusterId)

	if cluster == nil then return end

    if cluster.numAnimals <= self.numAnimals then
        self.husbandry:getClusterSystem():addPendingRemoveCluster(cluster)
    else
        cluster.numAnimals = cluster.numAnimals - self.numAnimals
    end

end