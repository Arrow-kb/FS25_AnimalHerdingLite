AnimalHerdingProfiler = {}


local modName = g_currentModName
local modTitle = "AnimalHerding - Lite"
local xmlFile = XMLFile.load("ahlProfilerXML", g_modNameToDirectory[modName] .. "modDesc.xml")
local modVersion = xmlFile:getString("modDesc.version", "1.0.0.0")
local modSource = xmlFile:getString("modDesc.source", "Modhub")
xmlFile:delete()
local AnimalHerdingProfiler_mt = Class(AnimalHerdingProfiler)


function AnimalHerdingProfiler.new()

	local self = setmetatable({}, AnimalHerdingProfiler_mt)

	self.debugEnabled = g_animalManager.debugEnabled
	self.profiles = {}
	self.ticksSinceLastWipe = 0

	self:setupFunctions()

	return self

end


function AnimalHerdingProfiler:setupFunctions()

	local modTable = _G[modName]

	local classes = {
		[AnimalAnimation] = "AnimalAnimation",
		[AnimalCollisionController] = "AnimalCollisionController",
		[AnimalHotspot] = "AnimalHotspot",
		[AnimalManager] = "AnimalManager",
		[AnimalPickupEvent] = "AnimalPickupEvent",
		--[modTable.HandToolAnimal] = "HandToolAnimal",
		--[modTable.HandToolBucket] = "HandToolBucket",
		[HerdableAnimal] = "HerdableAnimal",
		[HerdingEvent] = "HerdingEvent",
		[HerdingForceStopEvent] = "HerdingForceStopEvent",
		[HerdingPlayerSyncEvent] = "HerdingPlayerSyncEvent",
		[HerdingRequestEvent] = "HerdingRequestEvent",
		[HerdingSyncEvent] = "HerdingSyncEvent"
	}

	local skipFunctions = {
		["new"] = true,
		["emptyNew"] = true,
		["copy"] = true,
		["isa"] = true,
		["class"] = true,
		["superClass"] = true
	}

	for classObject, className in pairs(classes) do

		self.profiles[className] = {}
		
		for funcName, func in pairs(classObject) do

			if type(func) ~= "function" or skipFunctions[funcName] then continue end

			classObject[funcName] = Utils.overwrittenFunction(classObject[funcName], function(object, superFunc, ...)

				if not self.debugEnabled then return superFunc(object, ...) end

				local time1 = getTimeSec() * 1000

				local returnValues = { superFunc(object, ...) }

				if self.profiles[className][funcName] == nil then
					self.profiles[className][funcName] = {
						["calls"] = 0,
						["time"] = 0
					}
				end

				local profile = self.profiles[className][funcName]
			
				profile.calls = profile.calls + 1
				profile.time = profile.time + (getTimeSec() * 1000 - time1)

				return table.unpack(returnValues)
			
			end)

		end

	end

end


function AnimalHerdingProfiler:visualise()

	if self.debugOverlay == nil then
		_, self.offsetY = getNormalizedScreenValues(20, 20)
		self.debugOverlay = g_overlayManager:createOverlay("gui.serverDetails", 0.3, 0.05, 0.35, 0.65)
        self.debugOverlay:setAlignment(Overlay.ALIGN_VERTICAL_TOP, Overlay.ALIGN_HORIZONTAL_LEFT)
		self.debugOverlay:setColor(0, 0, 0, 0.75)
		self.debugOverlay:setPosition(0.675, 0.9)
	end

	self.debugOverlay:render()
	
	setTextColor(1, 0, 0, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
	setTextBold(true)
	
	renderText(0.775, 0.875, 0.01, string.format("%s (%s - v%s) Profiler", modTitle, modSource, modVersion))
	renderText(0.7, 0.85, 0.01, "Function")
	renderText(0.85, 0.85, 0.01, "Time")
	renderText(0.9, 0.85, 0.01, "Calls")
	renderText(0.925, 0.85, 0.01, "Time / Call")

	setTextColor(1, 1, 1, 1)
	setTextBold(false)

	local y = 0.825
	local sortedTimes = {}

	for className, functions in pairs(self.profiles) do
	
		for funcName, profile in pairs(functions) do
		
			table.insert(sortedTimes, {
				["name"] = className .. "." .. funcName,
				["time"] = profile.time,
				["calls"] = profile.calls
			})
			
		end
	
	end

	table.sort(sortedTimes, function(a, b)

		if a.time == b.time then
			if a.calls == b.calls then return a.name > b.name end
			return a.calls > b.calls
		end
	
		return a.time > b.time
	
	end)

	for i = 1, math.min(#sortedTimes, 25) do

		local profile = sortedTimes[i]

		renderText(0.7, y, 0.01, profile.name)
		renderText(0.85, y, 0.01, string.format("%.6f ms", profile.time))
		renderText(0.9, y, 0.01, string.format("%s", profile.calls))
		renderText(0.925, y, 0.01, string.format("%.6f ms", profile.time / profile.calls))

		y = y - self.offsetY

	end

	self.ticksSinceLastWipe = self.ticksSinceLastWipe + 1

	if self.ticksSinceLastWipe >= 500 then
		self.ticksSinceLastWipe = 0
		for className, profile in pairs(self.profiles) do self.profiles[className] = {} end
	end

end


g_animalManager.debugProfiler = AnimalHerdingProfiler.new()