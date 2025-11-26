local executed = false

MPLoadingScreen.update = Utils.appendedFunction(MPLoadingScreen.update, function(self, dt)

		if g_currentMission ~= nil and not executed then
			executed = true
			AnimalSystem.loadAnimalConfig = Utils.overwrittenFunction(AnimalSystem.loadAnimalConfig, AH_AnimalSystem.loadAnimalConfig)
		end

end)