HandToolAnimal = {}

local specName = "spec_FS25_AnimalHerdingLite.animal"
local keyName = "FS25_AnimalHerdingLite.animal"


function HandToolAnimal.registerFunctions(handTool)

	SpecializationUtil.registerFunction(handTool, "setEngineAnimal", HandToolAnimal.setEngineAnimal)
	SpecializationUtil.registerFunction(handTool, "setHerdingAnimal", HandToolAnimal.setHerdingAnimal)
	SpecializationUtil.registerFunction(handTool, "getAnimalTypeIndex", HandToolAnimal.getAnimalTypeIndex)
	SpecializationUtil.registerFunction(handTool, "getAnimal", HandToolAnimal.getAnimal)
	SpecializationUtil.registerFunction(handTool, "loadAnimal", HandToolAnimal.loadAnimal)
	SpecializationUtil.registerFunction(handTool, "loadFromPostLoad", HandToolAnimal.loadFromPostLoad)
	SpecializationUtil.registerFunction(handTool, "showInfo", HandToolAnimal.showInfo)

end


function HandToolAnimal.registerOverwrittenFunctions(handTool)
	--SpecializationUtil.registerOverwrittenFunction(handTool, "getShowInHandToolsOverview", HandToolAnimal.getShowInHandToolsOverview)
end


function HandToolAnimal.registerEventListeners(handTool)
	SpecializationUtil.registerEventListener(handTool, "onPostLoad", HandToolAnimal)
	SpecializationUtil.registerEventListener(handTool, "onHeldStart", HandToolAnimal)
	SpecializationUtil.registerEventListener(handTool, "onHeldEnd", HandToolAnimal)
	SpecializationUtil.registerEventListener(handTool, "onDelete", HandToolAnimal)
end


function HandToolAnimal.prerequisitesPresent()

	print("Loaded handTool: HandToolAnimal")

	return true

end


function HandToolAnimal:onPostLoad(savegame)

	if savegame == nil then return end
	
	local key = string.format("%s.%s", savegame.key, keyName)
	local xmlFile = savegame.xmlFile
	local spec = self[specName]

	local classObject = ClassUtil.getClassObject(xmlFile:getString(key .. "#className", "AnimalCluster")) or AnimalCluster
	spec.tiles = xmlFile:getVector(key .. "#tiles")
	spec.animalTypeIndex = xmlFile:getInt(key .. "#animalTypeIndex", 1)
	spec.visualAnimalIndex = xmlFile:getInt(key .. "#visualAnimalIndex", 1)

	local clusterKey = key .. ".cluster"

	if g_modIsLoaded["FS25_RealisticLivestock"] then
		spec.animal = classObject.loadFromXMLFile(xmlFile, clusterKey)
	else
		spec.animal = classObject.new()
		spec.animal:loadFromXMLFile(xmlFile, clusterKey)

		if classObject == AnimalCluster or classObject == AnimalClusterHorse then
		
			spec.animal.subTypeIndex = g_currentMission.animalSystem:getSubTypeIndexByName(xmlFile:getString(clusterKey .. "#subType", ""))

		end

	end

	spec.placeable = xmlFile:getString(key .. "#placeable")

	local cache = g_animalManager:getVisualAnimalFromCache(spec.animalTypeIndex, spec.visualAnimalIndex)

	if cache == nil or cache.posed == 0 then return false end

	local node = clone(cache.posed, false, false, false)
	link(self.graphicalNode, node)
	setVisibility(node, true)

	local meshNode = I3DUtil.indexToObject(node, cache.posedMesh)
	local x, y, z, w = unpack(spec.tiles)
	I3DUtil.setShaderParameterRec(meshNode, "atlasInvSizeAndOffsetUV", x, y, z, w, false)
	I3DUtil.setShaderParameterRec(meshNode, "dirt", 0, nil, nil, nil)

	g_animalManager:addHandToolToSetOnPostLoad(self)

end


function HandToolAnimal:saveToXMLFile(xmlFile, key)

	local spec = self[specName]

	xmlFile:setString(key .. "#className", ClassUtil.getClassNameByObject(spec.animal))
	xmlFile:setVector(key .. "#tiles", spec.tiles)
	xmlFile:setInt(key .. "#visualAnimalIndex", spec.visualAnimalIndex)
	xmlFile:setInt(key .. "#animalTypeIndex", spec.animalTypeIndex)
	xmlFile:setString(key .. "#placeable", spec.placeable)

	local subType = g_currentMission.animalSystem:getSubTypeByIndex(spec.animal.subTypeIndex)
	xmlFile:setString(key .. ".cluster#subType", subType.name)
	spec.animal:saveToXMLFile(xmlFile, key .. ".cluster")

end


function HandToolAnimal:getAnimalTypeIndex()

	return self[specName].animalTypeIndex

end


function HandToolAnimal:getAnimal()

	return self[specName].animal

end


function HandToolAnimal:loadAnimal(animal, animalTypeIndex, placeable)

	local spec = self[specName]

	spec.animal = animal
	spec.animalTypeIndex = animalTypeIndex

	local player = self:getCarryingPlayer()
	player:setIsCarryingAnimal(true)
	g_animalManager:addCarriedAnimalToPlayer(player, self, placeable)
	spec.player = player
	spec.placeable = placeable

end


function HandToolAnimal:loadFromPostLoad()

	local spec = self[specName]

	local player = self:getCarryingPlayer()

	if player == nil then return false end

	player:setIsCarryingAnimal(true)
	player:setCurrentHandTool(self)
	g_animalManager:addCarriedAnimalToPlayer(player, self, spec.placeable)
	spec.player = player

	return true

end


function HandToolAnimal:showInfo(box)

	box:setTitle(g_i18n:getText("ahl_carriedAnimal"))
	self[specName].animal:showInfo(box)

end


function HandToolAnimal:setEngineAnimal(husbandryId, animalId)

	local spec = self[specName]

	local husbandry = g_currentMission.husbandrySystem:getClusterHusbandryById(husbandryId)
	local animal = husbandry:getClusterByAnimalId(animalId, husbandryId)
	local clonedAnimal = animal:clone()
	clonedAnimal.id = animal.id
	clonedAnimal.numAnimals = animal.numAnimals

	local animalTypeIndex = g_currentMission.animalSystem:getTypeIndexBySubTypeIndex(clonedAnimal.subTypeIndex)
	local visualAnimalIndex = g_animalManager:getVisualDataForEngineAnimal(husbandryId, animalId)
	local x, y, z, w = getAnimalShaderParameter(husbandryId, animalId, "atlasInvSizeAndOffsetUV")

	local cache = g_animalManager:getVisualAnimalFromCache(animalTypeIndex, visualAnimalIndex)

	if cache == nil or cache.posed == 0 then return false end

	local node = clone(cache.posed, false, false, false)
	link(self.graphicalNode, node)
	setVisibility(node, true)

	--local meshNode = I3DUtil.indexToObject(node, cache.posedMesh)
	I3DUtil.setShaderParameterRec(node, "atlasInvSizeAndOffsetUV", x, y, z, w, false)
	I3DUtil.setShaderParameterRec(node, "dirt", 0, nil, nil, nil)

	spec.tiles = { x, y, z, w }
	spec.visualAnimalIndex = visualAnimalIndex

	if g_animalManager:getHasHusbandryConflict() then
		husbandry:updateVisuals(true)
	else
	
		local numVisualAnimals, numAnimals, numRemovedAnimals = 0, clonedAnimal.numAnimals, 0

		for animalId, cluster in pairs(husbandry.animalIdToCluster) do

			if cluster.id == animal.id then numVisualAnimals = numVisualAnimals + 1 end

		end

		if numVisualAnimals == 1 then
			--husbandry.placeable:getClusterSystem():addPendingRemoveCluster(animal)
		else
			clonedAnimal.numAnimals = math.floor(numAnimals / numVisualAnimals)
		end

		g_client:getServerConnection():sendEvent(AnimalPickupEvent.new(husbandry.placeable, animal.id, clonedAnimal.numAnimals))

	end

	self:loadAnimal(clonedAnimal, animalTypeIndex, husbandry.placeable:getUniqueId())

	return true

end


function HandToolAnimal:setHerdingAnimal(animalNode, farmId)

	local spec = self[specName]

	local animal = g_animalManager:getAnimalFromCollisionNode(animalNode, farmId)
	local visualAnimalIndex = animal.visualAnimalIndex
	local animalTypeIndex = g_animalManager:getAnimalTypeIndexForFarm(farmId)

	local cache = g_animalManager:getVisualAnimalFromCache(animalTypeIndex, visualAnimalIndex)

	if cache == nil or cache.posed == 0 then return false end

	local node = clone(cache.posed, false, false, false)
	link(self.graphicalNode, node)
	setVisibility(node, true)

	--local meshNode = I3DUtil.indexToObject(node, cache.posedMesh)
	I3DUtil.setShaderParameterRec(node, "atlasInvSizeAndOffsetUV", x, y, z, w, false)
	I3DUtil.setShaderParameterRec(node, "dirt", 0, nil, nil, nil)

	spec.visualAnimalIndex = visualAnimalIndex
	spec.tiles = animal.tiles

	self:loadAnimal(animal.cluster, animalTypeIndex, animal.placeable)
	g_animalManager:removeHerdedAnimal(farmId, animal)

	return true

end


function HandToolAnimal:onHeldStart()

	g_localPlayer.hudUpdater:setCarriedAnimal(self)

end


function HandToolAnimal:onHeldEnd()

	if g_localPlayer == nil then return end

	g_localPlayer.hudUpdater:setCarriedAnimal()

end


function HandToolAnimal:onDelete()

	if g_localPlayer == nil then return end

	self[specName].player:setIsCarryingAnimal(false)
	g_localPlayer.hudUpdater:setCarriedAnimal()

end