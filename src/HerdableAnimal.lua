HerdableAnimal = {}

local herdableAnimal_mt = Class(HerdableAnimal)
local modDirectory = g_currentModDirectory


function HerdableAnimal.new(placeable, rootNode, meshNode, shaderNode, skinNode, animationSet, animationCache, proxyNode)

	local self = setmetatable({}, herdableAnimal_mt)

	I3DUtil.setShaderParameterRec(meshNode, "dirt", 0, nil, nil, nil)

	-- animal has 2 ways to end herding:
	-- 1. "Stop Herding" button - teleports animal to closest compatible placeable
	-- 2. Dynamic stop - stops being herdable when it enters a placeable, with the exception of the original placeable. Original placeable reference is removed after leaving for a certain amount of time, then can be dynamically returned to the original placeable

	self.placeable = placeable
	self.placeableLeaveTimer = 0
	self.stuckTimer = 0
	self.terrainHeight = 0

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

	return self

end


function HerdableAnimal:delete()

	delete(self.nodes.root)

end


function HerdableAnimal:loadFromXMLFile(xmlFile, key, isRealisticLivestockLoaded)

	self.placeable = xmlFile:getString(key .. "#placeable")
	self.placeableLeaveTimer = xmlFile:getFloat(key .. "#placeableLeaveTimer")
	self.stuckTimer = xmlFile:getFloat(key .. "#stuckTimer")

	self.position.x = xmlFile:getFloat(key .. ".position#x", 0)
	self.position.y = xmlFile:getFloat(key .. ".position#y", 0)
	self.position.z = xmlFile:getFloat(key .. ".position#z", 0)

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


function HerdableAnimal:setData(visualAnimalIndex, x, y, z, w)

	self.visualAnimalIndex = visualAnimalIndex
	self.tiles = { x, y, z, w }

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

end


function HerdableAnimal:setRotation(x, y, z)

	self.rotation.x = x
	self.rotation.y = y
	self.rotation.z = z

end


function HerdableAnimal:createCollisionController(height, radius, animalTypeIndex)

	self.collisionController:setAttributes(height, radius)
	self.collisionController:load(self.nodes.root, animalTypeIndex, self.cluster.age or 12)

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

	state.wasWalking, state.wasRunning, state.wasIdle = state.isWalking, state.isIdle, state.isRunning

	if not state.isIdle then
	
		self.collisionController:updateCollisions()
		hasCollision, needsYAdjustment = self.collisionController:getHasCollision()

		self.position.y = self.terrainHeight + (needsYAdjustment and 0.2 or 0)

		if hasCollision then

			state.isIdle, state.isWalking, state.isRunning = true, false, false
			self.stuckTimer = math.min(self.stuckTimer + dT, 1500)

		else

			if not hasCollision then self.stuckTimer = 0 end

			local distance

			if self.herdingTarget.distance < 20 then

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
		
				if isMoving and ((isWalkingFromPlayer and distance < 5) or (not isWalkingFromPlayer and distance > 25)) then
		
					state.isRunning = true
					state.isWalking = false

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


	--if state.isTurning or (hasCollision and self.stuckTimer > 1000) then
	if state.isTurning then

		local ry = math.deg(self.rotation.y)
		--local turnTarget = hasCollision and self.stuckTimer > 1000 and (ry + 10) or math.deg(state.targetDirY)
		local turnTarget = math.deg(state.targetDirY)

		state.lastDirY = self.rotation.y

		ry, turnTarget = ry + 180, turnTarget + 180

		if ry < turnTarget then

			if math.abs(ry - turnTarget) < 180 then
				ry = ry + dT * 0.035
			else
				ry = ry - dT * 0.035
			end

		else

			if math.abs(ry - turnTarget) < 180 then
				ry = ry - dT * 0.035
			else
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


function HerdableAnimal:updateRelativeToPlayer(px, py, pz)

	local x, y, z = self.position.x, self.position.y, self.position.z

	
	local dx, dz = x - px, z - pz
	local dy = math.atan2(dx, dz)


	self.herdingTarget = {
		["ry"] = dy,
		["distance"] = MathUtil.vector2Length(px - x, pz - z),
		["dx"] = dx,
		["dz"] = dz,
		["x"] = x,
		["z"] = z,
		["px"] = px,
		["pz"] = pz
	}

	if self.herdingTarget.distance > 12.5 or (self.rotation.y <= dy + 0.05 and self.rotation.y >= dy - 0.05) then
		self.state.isTurning = false
		self.state.targetDirY = self.rotation.y
	else
		self.state.isTurning = true
		self.state.targetDirY = dy
	end

	if self.herdingTarget.distance < 25 then self.state.isIdle = false end

	local terrainHeight = getTerrainHeightAtWorldPos(g_terrainNode, self.position.x, 0, self.position.z) + 0.01
	self.terrainHeight = terrainHeight

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

	local infoTable = DebugInfoTable.new()
	infoTable:createWithNodeToCamera(self.nodes.root, info, 1, 0.05)
	g_debugManager:addFrameElement(infoTable)

	self.collisionController:visualise(self.position.x, self.position.y + 0.15, self.position.z, self.rotation.x, self.rotation.y, self.rotation.z)

end