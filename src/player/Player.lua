local specName = "spec_FS25_AnimalHerdingLite.animal"


function Player:setIsCarryingAnimal(isCarrying)

	self.isCarryingAnimal = isCarrying

end


function Player:getIsCarryingAnimal()

	return self.isCarryingAnimal

end


Player.cycleHandTool = Utils.overwrittenFunction(Player.cycleHandTool, function(self, superFunc, direction)

	if self:getIsCarryingAnimal() then return end

	superFunc(self, direction)

end)


Player.toggleHandTool = Utils.overwrittenFunction(Player.toggleHandTool, function(self, superFunc)

	if self:getIsCarryingAnimal() then return end

	superFunc(self)

end)


Player.switchToHandToolIndex = Utils.overwrittenFunction(Player.switchToHandToolIndex, function(self, superFunc, index)

	if self:getIsCarryingAnimal() then return end

	superFunc(self, index)

end)


Player.setCurrentHandTool = Utils.overwrittenFunction(Player.setCurrentHandTool, function(self, superFunc, handTool, noEventSend)

	if self:getIsCarryingAnimal() and (handTool == nil or handTool[specName] == nil) then return false end

	return superFunc(self, handTool, noEventSend)

end)