PlayerHUDUpdater.updateRaycastObject = Utils.appendedFunction(PlayerHUDUpdater.updateRaycastObject, function(self)

    self.isHerdableAnimal = false

    if not self.isAnimal and self.currentRaycastTarget ~= nil and entityExists(self.currentRaycastTarget) then

        local animal = g_animalManager:getAnimalFromCollisionNode(self.currentRaycastTarget, g_localPlayer.farmId)

        if animal ~= nil then

            self.object = animal.cluster
            self.isHerdableAnimal = true

        end

    end

end)


PlayerHUDUpdater.update = Utils.appendedFunction(PlayerHUDUpdater.update, function(self, dt)

    if self.isHerdableAnimal then self:showAnimalInfo(self.object) end
    if Platform.playerInfo.showVehicleInfo and self.carriedAnimal ~= nil then self:showHandToolInfo(self.carriedAnimal) end

end)


function PlayerHUDUpdater:showHandToolInfo(object)

    if object == nil then return end

    if self.handToolBox == nil then self.handToolBox = g_currentMission.hud.infoDisplay:createBox(InfoDisplayKeyValueBox) end

	local box = self.handToolBox

	box:clear()
	object:showInfo(box)
	box:showNextFrame()

end


function PlayerHUDUpdater:setCarriedAnimal(handTool)

    self.carriedAnimal = handTool

end