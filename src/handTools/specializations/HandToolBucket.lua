HandToolBucket = {}

local specName = "spec_FS25_AnimalHerdingLite.bucket"


function HandToolBucket.registerFunctions(handTool)
end


function HandToolBucket.registerOverwrittenFunctions(handTool)
end


function HandToolBucket.registerEventListeners(handTool)
	SpecializationUtil.registerEventListener(handTool, "onHeldStart", HandToolBucket)
	SpecializationUtil.registerEventListener(handTool, "onHeldEnd", HandToolBucket)
end


function HandToolBucket.prerequisitesPresent()

	print("Loaded handTool: HandToolBucket")

	return true

end


function HandToolBucket:onHeldStart()

	if not self.isServer then return end

	g_animalManager:setPlayerUsingBucket(self:getCarryingPlayer(), true)

end


function HandToolBucket:onHeldEnd()

	if not self.isServer then return end

	g_animalManager:setPlayerUsingBucket(self:getCarryingPlayer(), false)

end