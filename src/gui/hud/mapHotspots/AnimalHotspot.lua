AnimalHotspot = {}


local AnimalHotspot_mt = Class(AnimalHotspot, MapHotspot)


function AnimalHotspot.new(customMt)

	local self = MapHotspot.new(customMt or AnimalHotspot_mt)
	
	self.width, self.height = getNormalizedScreenValues(60, 60)
	_, self.textSize = getNormalizedScreenValues(0, 10)
	self.textOffsetX, self.textOffsetY = getNormalizedScreenValues(25, 21)

	self.icon = g_overlayManager:createOverlay("mapHotspots.playerPosition", 0, 0, self.width, self.height)
	self.icon:setColor(unpack(self.color))
	self.isBlinking = false
	
	self.clickArea = MapHotspot.getClickArea({
		32,
		40,
		36,
		46
	}, { 100, 100 }, 0)

	return self

end


function AnimalHotspot:getCategory()

	return MapHotspot.CATEGORY_ANIMAL

end


function AnimalHotspot:setIcon(animalTypeIndex)

	if AnimalHotspot.ANIMAL_TYPE_TO_ICON == nil then

		AnimalHotspot.ANIMAL_TYPE_TO_ICON = {
			[AnimalType.COW] = "gui.multiplayer_bull",
			[AnimalType.PIG] = "gui.multiplayer_pig",
			[AnimalType.SHEEP] = "gui.multiplayer_goat",
			[AnimalType.HORSE] = "gui.multiplayer_horse",
			[AnimalType.CHICKEN] = "gui.multiplayer_chicken"
		}

	end

	self.icon = g_overlayManager:createOverlay(AnimalHotspot.ANIMAL_TYPE_TO_ICON[animalTypeIndex] or "gui.multiplayer_bull", 0, 0, self.width, self.height)
	self.icon:setColor(unpack(self.color))


end


function AnimalHotspot:setAnimal(animal)

	self.animal = animal

end


function AnimalHotspot:getAnimal()

	return self.animal

end


function AnimalHotspot:getWorldPosition()

	local position = self.animal.position

	return position.x, position.z

end


function AnimalHotspot:getName()

	local cluster = self.animal.cluster

	if cluster == nil then return nil end

	local name = cluster.name

	if name ~= nil and #name > 0 then return name end

	local subType = g_currentMission.animalSystem:getSubTypeByIndex(cluster.subTypeIndex)
	return g_fillTypeManager:getFillTypeTitleByIndex(subType.fillTypeIndex)

end


function AnimalHotspot:getImageFilename()

	local cluster = self.animal.cluster

	if cluster == nil then return nil end

	return g_currentMission.animalSystem:getVisualByAge(cluster.subTypeIndex, cluster.age).store.imageFilename

end


function AnimalHotspot:getOwnerFarmId()

	return self.farmId

end


function AnimalHotspot:setOwnerFarmId(farmId)

	self.farmId = farmId

end


function AnimalHotspot:getBeVisited()

	return true

end


function AnimalHotspot:getTeleportWorldPosition()

	return self.animal:getPlayerTeleportPosition()

end