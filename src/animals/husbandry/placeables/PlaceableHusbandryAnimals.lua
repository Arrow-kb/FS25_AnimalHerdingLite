PlaceableHusbandryAnimals.registerFunctions = Utils.appendedFunction(PlaceableHusbandryAnimals.registerFunctions, function(placeable)
	SpecializationUtil.registerFunction(placeable, "toggleHerding", PlaceableHusbandryAnimals.toggleHerding)
end)


function PlaceableHusbandryAnimals:toggleHerding(animals)

	local spec = self.spec_husbandryAnimals
	local uniqueId = self:getUniqueId()

	local husbandry = spec.clusterHusbandry
	local clusterSystem = self:getClusterSystem()
	local animalTypeIndex = self:getAnimalTypeIndex()
	local clustersToRemove = {}
	local hasRealisticLivestock = AnimalManager.CONFLICTS.REALISTIC_LIVESTOCK
	local farmId = self:getOwnerFarmId()

	local function makeAnimalHerdable(husbandryId, animalId, cluster)

		local visualAnimalIndex = g_animalManager:getVisualDataForEngineAnimal(husbandryId, animalId)
		local x, y, z, w = getAnimalShaderParameter(husbandryId, animalId, "atlasInvSizeAndOffsetUV")

		local cache = g_animalManager:getVisualAnimalFromCache(animalTypeIndex, visualAnimalIndex)

		if cache == nil or cache.root == 0 then return end

		local px, py, pz = getAnimalPosition(husbandryId, animalId)
		local rx, ry, rz = getAnimalRotation(husbandryId, animalId)

		local node = clone(cache.root, false, false, false)
		link(getRootNode(), node)
		setVisibility(node, true)

		local shaderNode = I3DUtil.indexToObject(node, cache.shader)
		local meshNode = I3DUtil.indexToObject(node, cache.mesh)
		local skeletonNode = I3DUtil.indexToObject(node, cache.skeleton)
		local proxyNode = cache.proxy ~= nil and I3DUtil.indexToObject(node, cache.proxy) or nil
		local skinNode = getChildAt(skeletonNode, 0)
		local animationSet = getAnimCharacterSet(skinNode)

		I3DUtil.setShaderParameterRec(meshNode, "atlasInvSizeAndOffsetUV", x, y, z, w, false)

		local animal = HerdableAnimal.new(uniqueId, node, meshNode, shaderNode, skinNode, animationSet, cache.animation, proxyNode)

		animal:setPosition(px, py, pz)
		animal:setRotation(rx, ry, rz)

		if hasRealisticLivestock then

			animal:setCluster(cluster)

		else

			local newCluster = cluster:clone()
			newCluster.oldId = cluster.id
			newCluster.numAnimals = cluster.numAnimals
			animal:setCluster(newCluster)

		end
		
		animal:setHotspotIcon(animalTypeIndex)
		animal:setHotspotFarmId(farmId)
		animal:validateSpeed(animalTypeIndex)
		animal:createCollisionController(cache.navMeshAgent.height, cache.navMeshAgent.radius, animalTypeIndex)
		animal:setData(visualAnimalIndex, x, y, z, w)

		animal:updatePosition()
		animal:updateRotation()
		
		table.insert(clustersToRemove, cluster)
		table.insert(animals, animal)

	end

	if g_animalManager:getHasHusbandryConflict() then

		for i, animalIds in pairs(husbandry.animalIdToCluster) do

			local husbandryId = husbandry.husbandryIds[i]

			for animalId, cluster in pairs(animalIds) do

				makeAnimalHerdable(husbandryId, animalId, cluster)

			end

		end

		husbandry:updateVisuals(true)

	else
	
		local husbandryId = husbandry.husbandryId

		for animalId, cluster in pairs(husbandry.animalIdToCluster) do

			makeAnimalHerdable(husbandryId, animalId, cluster)

		end

	end

	if not hasRealisticLivestock then

		local clusterIdToNumAnimals = {}

		for _, cluster in pairs(clustersToRemove) do

			if clusterIdToNumAnimals[cluster.id] == nil then
				clusterIdToNumAnimals[cluster.id] = {
					["numAnimals"] = cluster.numAnimals,
					["removedNumAnimals"] = 0,
					["totalNumVisualAnimals"] = 0,
					["numVisualAnimals"] = 0
				}
			end

			clusterIdToNumAnimals[cluster.id].totalNumVisualAnimals = clusterIdToNumAnimals[cluster.id].totalNumVisualAnimals + 1

		end

		for _, animal in pairs(animals) do

			local cluster = animal.cluster
			local data = clusterIdToNumAnimals[cluster.oldId]

			data.numVisualAnimals = data.numVisualAnimals + 1
			local numAnimals = math.floor(data.numAnimals / data.totalNumVisualAnimals)

			if data.numVisualAnimals == data.totalNumVisualAnimals then numAnimals = data.numAnimals - data.removedNumAnimals end

			data.removedNumAnimals = data.removedNumAnimals + numAnimals
			cluster.numAnimals = numAnimals

		end

	end

	for i = #clustersToRemove, 1, -1 do

		clusterSystem:addPendingRemoveCluster(clustersToRemove[i])

	end

end


function PlaceableHusbandryAnimals:getIsInAnimalDeliveryArea(x, z)

	local spec = self.spec_husbandryAnimals

	if spec.outdoorContourPolygon ~= nil and spec.outdoorContourPolygon:getIsPosInside(x, z) then return true end

	local indoorAreas = {}
	
	if self.spec_indoorAreas.areas ~= nil then indoorAreas = self.spec_indoorAreas.areas end

	for _, indoorArea in ipairs(indoorAreas) do
		local sx, _, sz = getWorldTranslation(indoorArea.start)
		local wx, _, wz = getWorldTranslation(indoorArea.width)
		local hx, _, hz = getWorldTranslation(indoorArea.height)
		if MathUtil.isPointInParallelogram(x, z, sx, sz, wx - sx, wz - sz, hx - sx, hz - sz) then return true end
	end

	if spec.outdoorContourPolygon ~= nil and #indoorAreas > 0 then return false end

	for _, deliveryArea in ipairs(spec.deliveryAreas) do
		local sx, _, sz = getWorldTranslation(deliveryArea.start)
		local wx, _, wz = getWorldTranslation(deliveryArea.width)
		local hx, _, hz = getWorldTranslation(deliveryArea.height)
		if MathUtil.isPointInParallelogram(x, z, sx, sz, wx - sx, wz - sz, hx - sx, hz - sz) then return true end
	end

	if #spec.deliveryAreas == 0 then
		local px, _, pz = getWorldTranslation(self.rootNode)
		if MathUtil.vector2Length(px - x, pz - z) < 30 then return true end
	end

	return false

end