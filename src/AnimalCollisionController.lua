AnimalCollisionController = {}


local AnimalCollisionController_mt = Class(AnimalCollisionController)
local modDirectory = g_currentModDirectory
local collisionFlag = CollisionFlag.STATIC_OBJECT + CollisionFlag.DYNAMIC_OBJECT + CollisionFlag.VEHICLE + CollisionFlag.BUILDING + CollisionFlag.ANIMAL + CollisionFlag.PLAYER


function AnimalCollisionController.new(proxy)

	local self = setmetatable({}, AnimalCollisionController_mt)

	self.hasFrontCollision, self.hasGroundHighCollision, self.hasGroundLowCollision, self.hasLeftCollision, self.hasRightCollision, self.hadLeftCollision, self.hadRightCollision = false, false, false, false, false, false, false
	self.height, self.radius = 1, 0.5
	self.proxy = proxy

	return self

end


function AnimalCollisionController:load(rootNode, animalTypeIndex, age)

	local node = g_animalManager:getCollisionController(animalTypeIndex)
	link(rootNode, node)
	
    -- young animals should have smaller navMeshAgent attributes. default attributes are intended for adults
	if age < (AnimalManager.ANIMAL_TYPE_INDEX_TO_AGE_OFFSET[animalTypeIndex] or 12) then
		self.height, self.radius = self.height * 0.5, self.radius * 0.75
		setScale(node, self.radius, self.height, self.radius)
	end

	setTranslation(node, 0, self.height / 2 + 0.15, self.radius * 1.5)
	
	self.frontCollision = getChild(node, "frontCollision")
	self.leftCollision = getChild(node, "leftCollision")
	self.rightCollision = getChild(node, "rightCollision")
	self.groundCollisionLow = getChild(node, "groundCollisionLow")
	self.groundCollisionHigh = getChild(node, "groundCollisionHigh")
	self.playerCollision = getChild(node, "playerCollision")

	if self.proxy ~= nil then
		addToPhysics(self.proxy)
	else
		local proxyI3D = g_animalManager:getCollisionProxy(animalTypeIndex)
		link(rootNode, proxyI3D)
		setScale(proxyI3D, self.radius, self.height, self.radius)
		setTranslation(proxyI3D, 0, 0, -self.radius * 0.5)
		self.proxy = getChildAt(proxyI3D, 0)
		addToPhysics(self.proxy)
	end

end


function AnimalCollisionController:setAttributes(height, radius)

	self.height, self.radius = height, radius

end


function AnimalCollisionController:onOverlapFrontConvexCallback(node)

	if node ~= self.proxy then

		self.hasFrontCollision = true
		return true

	end

end


function AnimalCollisionController:onOverlapLeftConvexCallback(node)

	if node ~= self.proxy then

		self.hasLeftCollision = true
		return true

	end

end


function AnimalCollisionController:onOverlapRightConvexCallback(node)

	if node ~= self.proxy then

		self.hasRightCollision = true
		return true

	end

end


function AnimalCollisionController:onOverlapGroundLowConvexCallback(node)

	if node ~= self.proxy then

		self.hasGroundLowCollision = true
		return true

	end

end


function AnimalCollisionController:onOverlapGroundHighConvexCallback(node)

	if node ~= self.proxy then

		self.hasGroundHighCollision = true
		return true

	end

end


function AnimalCollisionController:onOverlapPlayerConvexCallback()

	return true

end


function AnimalCollisionController:onOverlapConvexCallbackTemp(node)

	self.hasTempCollision = true
	return true

end


function AnimalCollisionController:updateCollisions(updateTurningCollisions)

	self.hasFrontCollision, self.hasGroundLowCollision, self.hasGroundHighCollision = false, false, false

	overlapConvex(self.frontCollision, "onOverlapFrontConvexCallback", self, collisionFlag)
	overlapConvex(self.groundCollisionLow, "onOverlapGroundLowConvexCallback", self, collisionFlag)

	if updateTurningCollisions then

		self.hadLeftCollision, self.hadRightCollision = self.hasLeftCollision, self.hasRightCollision
		self.hasLeftCollision, self.hasRightCollision = false, false

		overlapConvex(self.leftCollision, "onOverlapLeftConvexCallback", self, collisionFlag)
		overlapConvex(self.rightCollision, "onOverlapRightConvexCallback", self, collisionFlag)

	end

	--if self.hasGroundLowCollision then overlapConvex(self.groundCollisionHigh, "onOverlapGroundHighConvexCallback", self, collisionFlag) end

end


function AnimalCollisionController:getHasPlayerInVicinity()

	return overlapConvex(self.playerCollision, "onOverlapPlayerConvexCallback", self, CollisionFlag.PLAYER) > 0

end


function AnimalCollisionController:getHasCollisionAtPosition(x, y, z, rx, ry, rz)

	self.hasTempCollision = false
	overlapBox(x, y + self.height / 2, z, rx, ry, rz, self.radius, self.height, self.radius, "onOverlapConvexCallbackTemp", self, CollisionFlag.STATIC_OBJECT + CollisionFlag.DYNAMIC_OBJECT + CollisionFlag.VEHICLE + CollisionFlag.BUILDING)

	return self.hasTempCollision

end


function AnimalCollisionController:getHasCollision()

	return self.hasFrontCollision, self.hasGroundLowCollision

end


function AnimalCollisionController:getCanTurnLeft()

	local canTurn = true

	if self.hasLeftCollision or self.hadLeftCollision then canTurn = false end

	return canTurn

end


function AnimalCollisionController:getCanTurnRight()

	local canTurn = true

	if self.hasRightCollision or self.hadRightCollision then canTurn = false end

	return canTurn

end


function AnimalCollisionController:visualise(info, x, y, z, rx, ry, rz)

	local dx, dz = MathUtil.getDirectionFromYRotation(ry)
	DebugUtil.drawOverlapBox(x + dx * self.radius * 2, y + self.height / 2, z + dz * self.radius * 2, rx, ry, rz, self.radius / 2, self.height / 2, self.radius / 2, 1, 0, 0)

	table.insert(info, { ["title"] = "Collision", ["content"] = {} })
	local infoIndex = #info

	table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "hasFrontCollision = ", ["value"] = tostring(self.hasFrontCollision) })
	table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "canTurnLeft = ", ["value"] = tostring(self:getCanTurnLeft()) })
	table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "canTurnRight = ", ["value"] = tostring(self:getCanTurnRight()) })
	table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "hasGroundLowCollision = ", ["value"] = tostring(self.hasGroundLowCollision) })
	table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "hasPlayerInVicinity = ", ["value"] = tostring(self:getHasPlayerInVicinity()) })

end