HerdableAnimal = {}
HerdableAnimal.WALK_DISTANCE = 20
HerdableAnimal.RUN_DISTANCE = 5
HerdableAnimal.TURN_DISTANCE = 15

local herdableAnimal_mt = Class(HerdableAnimal)
local modDirectory = g_currentModDirectory
local modName = g_currentModName
local nextId = 1


function HerdableAnimal.getNextId()

	nextId = nextId + 1
	return nextId - 1

end


function HerdableAnimal.new(placeable, rootNode, meshNode, shaderNode, skinNode, animationSet, animationCache, proxyNode)

	local self = setmetatable({}, herdableAnimal_mt)

	if g_server ~= nil then self.id = HerdableAnimal.getNextId() end

	I3DUtil.setShaderParameterRec(meshNode, "dirt", 0, nil, nil, nil)

	-- animal has 2 ways to end herding:
	-- 1. "Stop Herding" button - teleports animal to closest compatible placeable
	-- 2. Dynamic stop - stops being herdable when it enters a placeable, with the exception of the original placeable. Original placeable reference is removed after leaving for a certain amount of time, then can be dynamically returned to the original placeable

	self.placeable = placeable
	self.placeableLeaveTimer = 0
	self.stuckTimer = 0
	self.terrainHeight = 0
	self.startWalking = false

	self.nodes = {
		["root"] = rootNode,
		["mesh"] = meshNode,
		["shader"] = shaderNode,
		["skin"] = skinNode,
		["proxy"] = proxyNode
	}

	self.animation = AnimalAnimation.new(self, animationSet, animationCache)

	self.state = {
		["isIdle"] = true,
		["isWalking"] = false,
		["isRunning"] = false,
		["dirY"] = 0,
		["lastDirY"] = 0,
		["targetDirY"] = 0,
		["isTurning"] = false
	}

	self.herdingTarget = { ["distance"] = 100 }

	self.animation:setState(self.state)

	self.position = { ["x"] = 0, ["y"] = 0, ["z"] = 0 }
	self.rotation = { ["x"] = 0, ["y"] = 0, ["z"] = 0 }
	self.speed = 0
	self.tiles = { 1, 1, 1, 1 }

	self.collisionController = AnimalCollisionController.new(proxyNode)

	self.mapHotspot = AnimalHotspot.new()
	self.mapHotspot:setAnimal(self)
	g_currentMission:addMapHotspot(self.mapHotspot)
	self.lastStuckTurn = 0

	return self

end


function HerdableAnimal:delete()

	g_animalManager:deleteAnimalCollisionNode(self.collisionController.proxy)
	g_currentMission:removeMapHotspot(self.mapHotspot)
	self.mapHotspot:delete()
	delete(self.nodes.root)

end


function HerdableAnimal:loadFromXMLFile(xmlFile, key, isRealisticLivestockLoaded)

	self.placeable = xmlFile:getString(key .. "#placeable")
	self.placeableLeaveTimer = xmlFile:getFloat(key .. "#placeableLeaveTimer")
	self.stuckTimer = xmlFile:getFloat(key .. "#stuckTimer")

	self.position.x = xmlFile:getFloat(key .. ".position#x", 0)
	self.position.y = xmlFile:getFloat(key .. ".position#y", 0)
	self.position.z = xmlFile:getFloat(key .. ".position#z", 0)

	self:updateTerrainHeight(true)

	self.rotation.x = xmlFile:getFloat(key .. ".rotation#x", 0)
	self.rotation.y = xmlFile:getFloat(key .. ".rotation#y", 0)
	self.rotation.z = xmlFile:getFloat(key .. ".rotation#z", 0)

	local classObject = ClassUtil.getClassObject(xmlFile:getString(key .. "#className", "AnimalCluster")) or AnimalCluster

	self.tiles = xmlFile:getVector(key .. "#tiles")

	local clusterKey = key .. ".cluster"

	if isRealisticLivestockLoaded then
		self.cluster = classObject.loadFromXMLFile(xmlFile, clusterKey)
	else
		self.cluster = classObject.new()
		self.cluster:loadFromXMLFile(xmlFile, clusterKey)

		if classObject == AnimalCluster or classObject == AnimalClusterHorse then
		
			self.cluster.subTypeIndex = g_currentMission.animalSystem:getSubTypeIndexByName(xmlFile:getString(clusterKey .. "#subType", ""))

		end

	end

end


function HerdableAnimal:saveToXMLFile(xmlFile, key)

	xmlFile:setInt(key .. "#visualAnimalIndex", self.visualAnimalIndex)

	if self.placeable ~= nil then xmlFile:setString(key .. "#placeable", self.placeable) end
	xmlFile:setFloat(key .. "#placeableLeaveTimer", self.placeableLeaveTimer)
	xmlFile:setFloat(key .. "#stuckTimer", self.stuckTimer)

	xmlFile:setFloat(key .. ".position#x", self.position.x)
	xmlFile:setFloat(key .. ".position#y", self.position.y)
	xmlFile:setFloat(key .. ".position#z", self.position.z)

	xmlFile:setFloat(key .. ".rotation#x", self.rotation.x)
	xmlFile:setFloat(key .. ".rotation#y", self.rotation.y)
	xmlFile:setFloat(key .. ".rotation#z", self.rotation.z)

	xmlFile:setString(key .. "#className", ClassUtil.getClassNameByObject(self.cluster))

	xmlFile:setVector(key .. "#tiles", self.tiles)

	local subType = g_currentMission.animalSystem:getSubTypeByIndex(self.cluster.subTypeIndex)
	xmlFile:setString(key .. ".cluster#subType", subType.name)
	self.cluster:saveToXMLFile(xmlFile, key .. ".cluster")

end


function HerdableAnimal:readStream(streamId)

	self.id = streamReadUInt8(streamId)
	self.placeable = streamReadString(streamId)

	if #self.placeable == 0 then self.placeable = nil end

	self.placeableLeaveTimer = streamReadFloat32(streamId)
	self.stuckTimer = streamReadFloat32(streamId)

	self.position.x = streamReadFloat32(streamId)
	self.position.y = streamReadFloat32(streamId)
	self.position.z = streamReadFloat32(streamId)

	self:updateTerrainHeight(true)

	self.rotation.x = streamReadFloat32(streamId)
	self.rotation.y = streamReadFloat32(streamId)
	self.rotation.z = streamReadFloat32(streamId)

	local classObject = ClassUtil.getClassObject(streamReadString(streamId)) or AnimalCluster
	local subTypeIndex = streamReadUInt8(streamId)

	self.cluster = classObject.new()
	self.cluster:readStream(streamId)

	if classObject == AnimalCluster or classObject == AnimalClusterHorse then self.cluster.subTypeIndex = subTypeIndex end

end


function HerdableAnimal:writeStream(streamId)

	streamWriteUInt8(streamId, self.id)
	streamWriteString(streamId, self.placeable or "")
	streamWriteFloat32(streamId, self.placeableLeaveTimer)
	streamWriteFloat32(streamId, self.stuckTimer)

	streamWriteFloat32(streamId, self.position.x)
	streamWriteFloat32(streamId, self.position.y)
	streamWriteFloat32(streamId, self.position.z)

	streamWriteFloat32(streamId, self.rotation.x)
	streamWriteFloat32(streamId, self.rotation.y)
	streamWriteFloat32(streamId, self.rotation.z)

	streamWriteString(streamId, ClassUtil.getClassNameByObject(self.cluster))
	streamWriteUInt8(streamId, self.cluster.subTypeIndex)
	self.cluster:writeStream(streamId)

end


function HerdableAnimal:readUpdateStream(streamId)

	local position, rotation = self.position, self.rotation

	position.x = streamReadFloat32(streamId)
	position.z = streamReadFloat32(streamId)
	rotation.y = streamReadFloat32(streamId)

end


function HerdableAnimal:writeUpdateStream(streamId)

	local position, rotation = self.position, self.rotation

	streamWriteFloat32(streamId, position.x)
	streamWriteFloat32(streamId, position.z)
	streamWriteFloat32(streamId, rotation.y)

end


function HerdableAnimal:setHotspotIcon(animalTypeIndex)

	self.mapHotspot:setIcon(animalTypeIndex)

end


function HerdableAnimal:setHotspotFarmId(farmId)

	self.mapHotspot:setOwnerFarmId(farmId)

end


function HerdableAnimal:getHotspotFarmId()

	return self.mapHotspot:getOwnerFarmId()

end


function HerdableAnimal:setData(visualAnimalIndex, x, y, z, w)

	self.visualAnimalIndex = visualAnimalIndex
	self.tiles = { x, y, z, w }

end


function HerdableAnimal:getData()

	return self.visualAnimalIndex, self.tiles

end


function HerdableAnimal:getPlayerTeleportPosition()

	local dx, _, dz = localDirectionToWorld(self.nodes.root, 0, 0, -1)
	local radius = self.collisionController.radius

	return self.position.x + dx * radius, self.position.y + 0.2, self.position.z + dz * radius

end


function HerdableAnimal:setCluster(cluster)

	self.cluster = cluster

end


function HerdableAnimal:processPlaceableDetection(placeables)

	local x, z = self.position.x, self.position.z
	local originalPlaceable = self.placeable

	for i, placeable in ipairs(placeables) do

		if originalPlaceable == placeable.id then
		
			if not placeable.placeable:getIsInAnimalDeliveryArea(x, z) then

				self.placeableLeaveTimer = self.placeableLeaveTimer + 1

				if self.placeableLeaveTimer >= 10 then self.placeable = nil end

			else

				self.placeableLeaveTimer = 0

			end
		
		elseif placeable.placeable:getIsInAnimalDeliveryArea(x, z) then
			return i
		end

	end

	return nil

end


function HerdableAnimal:setPosition(x, y, z)

	self.position.x = x
	self.position.y = y
	self.position.z = z
	self:updateTerrainHeight(true)

end


function HerdableAnimal:setRotation(x, y, z)

	self.rotation.x = x
	self.rotation.y = y
	self.rotation.z = z

end


function HerdableAnimal:createCollisionController(height, radius, animalTypeIndex)

	self.collisionController:setAttributes(height, radius)
	self.collisionController:load(self.nodes.root, animalTypeIndex, self.cluster.age or 12)
	g_animalManager:addAnimalCollisionNode(self, self.collisionController.proxy)

end


function HerdableAnimal:validateSpeed(animalTypeIndex)



end


function HerdableAnimal:updatePosition()

	setWorldTranslation(self.nodes.root, self.position.x, self.position.y, self.position.z)

end


function HerdableAnimal:updateRotation()

	setWorldRotation(self.nodes.root, 0, self.rotation.y, 0)

end


function HerdableAnimal:update(dT)

	local x, y, z = self.position.x, self.position.y, self.position.z
	local state = self.state

	local isWalkingFromPlayer = false
	local hasCollision = false

	state.wasWalking, state.wasRunning, state.wasIdle = state.isWalking, state.isRunning, state.isIdle

	if self.startWalking then

		self.startWalking = false
		state.isIdle = false

	end

	if not state.isIdle then
	
		self.collisionController:updateCollisions(state.isTurning)
		hasCollision, needsYAdjustment = self.collisionController:getHasCollision()

		self.position.y = self.terrainHeight + (needsYAdjustment and 0.2 or 0)

		if hasCollision then

			state.isIdle, state.isWalking, state.isRunning = true, false, false
			self.stuckTimer = math.min(self.stuckTimer + dT, 1500)

		else

			if not hasCollision then self.stuckTimer = 0 end

			local distance

			if self.herdingTarget.distance < HerdableAnimal.WALK_DISTANCE and not (self.herdingTarget.followingBucket and self.herdingTarget.distance < HerdableAnimal.RUN_DISTANCE / 2) then

				distance = self.herdingTarget.distance
				isWalkingFromPlayer = true

			else

				--if self.target == nil then self:findTarget() end

				--local dx, dy, dz = self.target.x - x, self.target.y - y, self.target.z - z
				--distance = math.abs(dx) + math.abs(dy) + math.abs(dz)

				state.isIdle = true
				state.isWalking, state.isRunning = false, false

			end

			if isWalkingFromPlayer then

				local stepX, _, stepZ = localDirectionToWorld(self.nodes.root, 0, 0, 1)

				if distance > 0 then
	
					self.position.x = x + stepX * dT * 0.002 * self.speed
					self.position.z = z + stepZ * dT * 0.002 * self.speed

				end

				local isMoving = stepX ~= 0 or stepZ ~= 0

				state.isWalking = isMoving
				state.isRunning = false
		
				if isMoving then
				
					if self.herdingTarget.followingBucket then
						
						state.isRunning = distance > HerdableAnimal.WALK_DISTANCE - HerdableAnimal.RUN_DISTANCE
						state.isWalking = not state.isRunning

					elseif (isWalkingFromPlayer and distance < HerdableAnimal.RUN_DISTANCE) or (not isWalkingFromPlayer and distance > 25) then
		
						state.isRunning = true
						state.isWalking = false

					end

				end

				if state.isWalking then

					--self.walkingState.movementDirX = stepX
					--self.walkingState.movementDirZ = stepZ

				end

				--if distance <= 0.25 then

					--if math.random() >= 0.65 then

						--state.isIdle = true
						--state.isWalking = false
						--state.isRunning = false

					--else

						--self:findTarget()

					--end

				--end

			end

			self:updatePosition()

		end

	else

		--if math.random() >= 0.95 then self:findTarget() end

	end


	-- ##########################################################################
	-- TODO:
	-- Animal sometimes gets stuck on tight corners when being herded with bucket
	-- Have tried to mitigate this but still occasionally happens
	-- ##########################################################################


	if state.isTurning or (hasCollision and not state.isIdle and self.herdingTarget.followingBucket) then

		local ry = math.deg(self.rotation.y)
		--local turnTarget = hasCollision and self.stuckTimer > 1000 and (ry + 10) or math.deg(state.targetDirY)
		local turnTarget = math.deg(state.targetDirY)

		local canTurnLeft = self.collisionController:getCanTurnLeft()
		local canTurnRight = self.collisionController:getCanTurnRight()

		state.lastDirY = self.rotation.y
		ry, turnTarget = ry + 180, turnTarget + 180

		if self.herdingTarget.followingBucket and hasCollision then

			if canTurnRight and canTurnLeft then
				turnTarget = ry + 10 * (ry < turnTarget and 1 or -1)
				self.lastStuckTurn = (ry < turnTarget and 1 or -1)
			elseif canTurnLeft then
				turnTarget = ry - 10
				self.lastStuckTurn = -1
			elseif canTurnRight then
				turnTarget = ry + 10
				self.lastStuckTurn = 1
			end

		else

				self.lastStuckTurn = 0

		end

		if ry < turnTarget then

			if canTurnLeft and math.abs(ry - turnTarget) < 180 then
				ry = ry + dT * 0.035
			elseif canTurnRight then
				ry = ry - dT * 0.035
			end

		else

			if canTurnRight and math.abs(ry - turnTarget) < 180 then
				ry = ry - dT * 0.035
			elseif canTurnLeft then
				ry = ry + dT * 0.035
			end

		end

		ry = ry - 180
		if ry < -180 then ry = 180 end
		if ry > 180 then ry = -180 end

		self.rotation.y = math.rad(ry)

		state.dirY = self.rotation.y

		if self.rotation.y <= state.targetDirY + 0.05 and self.rotation.y >= state.targetDirY - 0.05 then
			state.targetDirY = 0
			state.isTurning = false
		end

		self:updateRotation()

	end

	self.animation:setState(self.state)
	self.animation:update(dT, isWalkingFromPlayer)

	self.speed = self.animation:getMovementSpeed()

end


function HerdableAnimal:updateRelativeToPlayers(players, updateTerrain)

	local x, y, z = self.position.x, self.position.y, self.position.z
	local ax, az, closestDistance
	local numClosePlayers = 0
	local state = self.state
	local hasBucketInRange = false

	for _, player in pairs(players) do

		local px, pz = player[1], player[2]
		local distance = MathUtil.vector2Length(px - x, pz - z)

		if distance > HerdableAnimal.WALK_DISTANCE then continue end

		if player[3] then
			if not hasBucketInRange then closestDistance = nil end
			hasBucketInRange = true
			if closestDistance == nil or distance < closestDistance then ax, az = px, pz end
		elseif not hasBucketInRange then
		
			if ax == nil or az == nil then
				ax, az = px, pz
			else
				ax, az = ax + px, az + pz
			end

		end

		if closestDistance == nil or distance < closestDistance then closestDistance = distance end

		numClosePlayers = numClosePlayers + 1

	end

	if ax == nil or az == nil then
	
		state.isIdle = true
		self.herdingTarget.distance = HerdableAnimal.WALK_DISTANCE + 1
		if updateTerrain then self:updateTerrainHeight() end
		return
	
	end

	if not hasBucketInRange then ax, az = ax / numClosePlayers, az / numClosePlayers end

	local dx, dz = x - ax, z - az
	local dy

	if hasBucketInRange then
		local dirX, dirZ = MathUtil.vector2Normalize(ax - x, az - z)
		dy = MathUtil.getYRotationFromDirection(dirX, dirZ)
	else
		dy = math.atan2(dx, dz)
	end

	if state.isIdle and not self.startWalking and not (hasBucketInRange and closestDistance < HerdableAnimal.RUN_DISTANCE / 2) then self.startWalking = true end

	self.herdingTarget = {
		["ry"] = dy,
		["distance"] = closestDistance,
		["followingBucket"] = hasBucketInRange,
		["dx"] = dx,
		["dz"] = dz,
		["x"] = x,
		["z"] = z,
		["ax"] = ax,
		["az"] = az
	}

	if self.herdingTarget.distance > HerdableAnimal.TURN_DISTANCE or (self.rotation.y <= dy + 0.05 and self.rotation.y >= dy - 0.05) or self.collisionController:getHasPlayerInVicinity() then
		state.isTurning = false
		state.targetDirY = self.rotation.y
	else
		state.isTurning = true
		state.targetDirY = dy
	end

	if self.herdingTarget.distance < HerdableAnimal.WALK_DISTANCE and state.isIdle then self.startWalking = true end

	if updateTerrain then self:updateTerrainHeight() end

end


function HerdableAnimal:updateTerrainHeight(updateY)

	self.terrainHeight = getTerrainHeightAtWorldPos(g_terrainNode, self.position.x, 0, self.position.z) + 0.01

	if updateY then self.position.y = self.position.y > self.terrainHeight and self.position.y or self.terrainHeight end

end


function HerdableAnimal:findTarget(isColliding)

	local state = self.state

	if isColliding then

		local ry = self.rotation.y

		while isColliding do

			local dx, dz = MathUtil.getDirectionFromYRotation(ry)
			local x, y, z = self.position.x + dx * 2, self.position.y, self.position.z + dz * 25

			isColliding = self.collisionController:getHasCollisionAtPosition(x, y, z, self.rotation.x, ry, self.rotation.z)

			if not isColliding then

				self.target = {
					["x"] = x,
					["y"] = self.position.y,
					["z"] = z,
					["ry"] = ry
				}

				return

			end

			ry = ry + 0.1

			if ry >= math.pi / 2 then ry = -math.pi / 2 end

			if ry >= self.rotation.y - 0.04 and ry <= self.rotation.y + 0.04 then return end

		end

	end

	self.target = {
		["x"] = math.random(self.position.x - 5, self.position.x + 5),
		["y"] = self.position.y,
		["z"] = math.random(self.position.z - 5, self.position.z + 5)
	}

	self.target.ry = math.atan2(self.target.x - self.position.x, self.target.z - self.position.z)

	self.state.isTurning = true
	self.state.targetDirY = self.target.ry
	self.state.isIdle = false

end


function HerdableAnimal:forceNewState()

	local state = self.state

	if state.followingPath then return end

	if state.isIdle then
		state.isIdle = false
		state.wasIdle = true
		self:findTarget()
	elseif state.isWalking then
		state.isIdle = true
		state.wasWalking = true
		state.isWalking = false
		state.isTurning = false
		state.targetDirY = 0
	elseif state.isRunning then
		state.isIdle = false
		state.wasWalking = false
		state.isWalking = true
		state.isRunning = false
		state.wasRunning = true
		self:findTarget()
	end

	self.animation:setState(self.state)

end


function HerdableAnimal:setIsWalking(value)

	self.state.isWalking = value
	self.state.wasWalking = not value

end


function HerdableAnimal:setIsRunning(value)

	self.state.isRunning = value
	self.state.wasRunning = not value

end


function HerdableAnimal:setIsIdle(value)

	self.state.isIdle = value
	self.state.wasIdle = not value

end


function HerdableAnimal:setIsTurning(value)

	self.state.isTurning = value

end


function HerdableAnimal:showInfo(box)

	box:setTitle(g_i18n:getText("ahl_herdedAnimal", modName))
	self.cluster:showInfo(box)

end


function HerdableAnimal:visualise()

	local info = {
		{ ["title"] = "Player Response", ["content"] = {} },
		{ ["title"] = "Movement", ["content"] = {} }
	}

	for key, value in pairs(self.herdingTarget) do table.insert(info[1].content, { ["sizeFactor"] = 0.7, ["name"] = key .. " = ", ["value"] = tostring(value) }) end

	local stepX, _, stepZ = localDirectionToWorld(self.nodes.root, 0, 0, 1)

	table.insert(info[2].content, { ["sizeFactor"] = 0.7, ["name"] = "stepX = ", ["value"] = tostring(stepX) })
	table.insert(info[2].content, { ["sizeFactor"] = 0.7, ["name"] = "stepZ = ", ["value"] = tostring(stepZ) })

	self.animation:visualise(self.nodes.root, info)
	self.collisionController:visualise(info, self.position.x, self.position.y + 0.15, self.position.z, self.rotation.x, self.rotation.y, self.rotation.z)
	table.insert(info[#info].content, { ["sizeFactor"] = 0.7, ["name"] = "lastStuckTurn = ", ["value"] = tostring(self.lastStuckTurn) })

	local infoTable = DebugInfoTable.new()
	infoTable:createWithNodeToCamera(self.nodes.root, info, 1, 0.05)
	g_debugManager:addFrameElement(infoTable)

end