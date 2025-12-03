-- ###########################################

-- This mod requires engine-level functions to be overwritten. Therefore, code must be executed at the root level, not in a contained mod environment.
-- This is so that vanilla/other mod code executes this mod's overwritten engine functions rather than the original engine functions.

-- ###########################################


local files = {
	"animals/husbandry/cluster/AnimalCluster.lua",
	"animals/husbandry/placeables/PlaceableHusbandryAnimals.lua",
	"animals/husbandry/AnimalSystem.lua",
	"animation/AnimalAnimation.lua",
	"events/AnimalPickupEvent.lua",
	"events/HerdingEvent.lua",
	"events/HerdingForceStopEvent.lua",
	"events/HerdingPlayerSyncEvent.lua",
	"events/HerdingRequestEvent.lua",
	"events/HerdingSyncEvent.lua",
	"gui/hud/mapHotspots/AnimalHotspot.lua",
	"gui/InGameMenuMapFrame.lua",
	"gui/MPLoadingScreen.lua",
	"player/Player.lua",
	"player/PlayerHUDUpdater.lua",
	"AnimalCollisionController.lua",
	"AnimalManager.lua",
	"FSBaseMission.lua",
	"FSCareerMissionInfo.lua",
	"HerdableAnimal.lua",
	"debug/AnimalHerdingProfiler.lua"
}


local root = getmetatable(_G).__index
local modDirectory = g_currentModDirectory

for _, file in pairs(files) do root.source(modDirectory .. "src/" .. file) end