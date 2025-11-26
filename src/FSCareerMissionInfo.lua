FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, function(self)

	g_animalManager:save(self.savegameDirectory .. "/animalHerding.xml")

end)