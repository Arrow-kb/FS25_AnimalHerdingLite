PlayerHUDUpdater.updateRaycastObject = Utils.appendedFunction(PlayerHUDUpdater.updateRaycastObject, function(self)

    self.isHerdableAnimal = false

    if self.isAnimal == false and self.currentRaycastTarget ~= nil and entityExists(self.currentRaycastTarget) then

        local object = g_currentMission:getNodeObject(self.currentRaycastTarget)

        if self.currentRaycastTarget ~= 0 then print(self.currentRaycastTarget) end

    end

end)