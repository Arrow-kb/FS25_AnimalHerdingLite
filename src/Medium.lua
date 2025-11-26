-- ###########################################

-- This mod requires engine-level functions to be overwritten. Therefore, code must be executed at the root level, not in a contained mod environment.
-- This is so that vanilla/other mod code executes this mod's overwritten engine functions rather than the original engine functions.

-- ###########################################


local files = {
	"animals/husbandry/AnimalSystem.lua",
	"animals/husbandry/placeables/PlaceableHusbandryAnimals.lua",
	"animation/AnimalAnimation.lua",
	"gui/MPLoadingScreen.lua",
	--"player/PlayerHUDUpdater.lua",
	"AnimalCollisionController.lua",
	"AnimalManager.lua",
	"FSBaseMission.lua",
	"FSCareerMissionInfo.lua",
	"HerdableAnimal.lua"
}


local root = getmetatable(_G).__index
local modDirectory = g_currentModDirectory

for _, file in pairs(files) do root.source(modDirectory .. "src/" .. file) end