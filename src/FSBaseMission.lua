FSBaseMission.onStartMission = Utils.prependedFunction(FSBaseMission.onStartMission, function(self)

	g_animalManager:validateConflicts()
	g_animalManager:configureCollisionControllerOffsets()
	g_animalManager:load()

	self:addUpdateable(g_animalManager)
	self:addDrawable(g_animalManager)

end)