AnimalCollisionController = {}


local AnimalCollisionController_mt = Class(AnimalCollisionController)
local modDirectory = g_currentModDirectory
local collisionFlag = CollisionFlag.STATIC_OBJECT + CollisionFlag.DYNAMIC_OBJECT + CollisionFlag.VEHICLE + CollisionFlag.BUILDING + CollisionFlag.ANIMAL


function AnimalCollisionController.new(proxy)

	local self = setmetatable({}, AnimalCollisionController_mt)

	self.hasFrontCollision, self.hasGroundHighCollision, self.hasGroundLowCollision = false, false, false
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
	self.groundCollisionLow = getChild(node, "groundCollisionLow")
	self.groundCollisionHigh = getChild(node, "groundCollisionHigh")

	if self.proxy ~= nil then addToPhysics(self.proxy) end

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


function AnimalCollisionController:onOverlapConvexCallbackTemp(node)

	self.hasTempCollision = true
	return true

end


function AnimalCollisionController:updateCollisions()

	self.hasFrontCollision, self.hasGroundLowCollision, self.hasGroundHighCollision = false, false, false

	overlapConvex(self.frontCollision, "onOverlapFrontConvexCallback", self, collisionFlag)
	overlapConvex(self.groundCollisionLow, "onOverlapGroundLowConvexCallback", self, collisionFlag)

	--if self.hasGroundLowCollision then overlapConvex(self.groundCollisionHigh, "onOverlapGroundHighConvexCallback", self, collisionFlag) end

end


function AnimalCollisionController:getHasCollisionAtPosition(x, y, z, rx, ry, rz)

	self.hasTempCollision = false
	overlapBox(x, y + self.height / 2, z, rx, ry, rz, self.radius, self.height, self.radius, "onOverlapConvexCallbackTemp", self, CollisionFlag.STATIC_OBJECT + CollisionFlag.DYNAMIC_OBJECT + CollisionFlag.VEHICLE + CollisionFlag.BUILDING)

	return self.hasTempCollision

end


function AnimalCollisionController:getHasCollision()

	return self.hasFrontCollision, self.hasGroundLowCollision

end


function AnimalCollisionController:visualise(x, y, z, rx, ry, rz)

	local dx, dz = MathUtil.getDirectionFromYRotation(ry)
	DebugUtil.drawOverlapBox(x + dx * self.radius * 2, y + self.height / 2, z + dz * self.radius * 2, rx, ry, rz, self.radius / 2, self.height / 2, self.radius / 2, 1, 0, 0)

end