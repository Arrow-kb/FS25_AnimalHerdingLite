AnimalManager = {}


AnimalManager.CONFLICTS = {}
AnimalManager.ANIMAL_TYPE_INDEX_TO_AGE_OFFSET = {}


local AnimalManager_mt = Class(AnimalManager)
local modDirectory = g_currentModDirectory
local modName = g_currentModName


function AnimalManager.new()

	local self = setmetatable({}, AnimalManager_mt)

	self.debugEnabled = false
	self.cache = {}
    self.farms = {}
    self.husbandries = {}
    self.ticksSinceLastHusbandryCheck = 0
    self.ticksSinceLastPlayerCheck = 0
    self.ticksSinceLastAnimalHusbandryCheck = 0
    self.ticksSinceLastInputForce = 0
    self.ticksSinceLastSync = 0
    self.collisionControllers = {}
    self.proxies = {}
    self.isInitialised = false
    self.herdingEnabled = false
    self.connections = {}
    self.syncQueue = {}
    self.feedBuckets = {}
    self.collisionNodes = {}
    self.carriedAnimals = {}
    self.handToolsPostLoad = {}

	self:overwriteEngineFunctions()

	--g_isDevelopmentVersion = true
	--g_addCheatCommands = true

	addConsoleCommand("toggleAnimalDebug", "Toggle animal debug mode", "consoleCommandToggleDebug", AnimalManager)

    _G[modName].ClassUtil = ClassUtil

	return self

end


function AnimalManager:update(dT)
    
    if g_localPlayer ~= nil then

        if self.farms[g_localPlayer.farmId] == nil then

            self.ticksSinceLastHusbandryCheck = self.ticksSinceLastHusbandryCheck + 1

            if self.ticksSinceLastHusbandryCheck >= 75 then

                self.ticksSinceLastHusbandryCheck = 0

                local husbandry = self:getHusbandryInRange()
        
                g_inputBinding:setActionEventActive(self.herdingEventId, husbandry ~= nil)

                if husbandry ~= nil then g_inputBinding:setActionEventText(self.herdingEventId, g_i18n:getText("ahl_startHerding", modName)) end

            end

        else

            self.ticksSinceLastInputForce = self.ticksSinceLastInputForce + 1

            if self.ticksSinceLastInputForce == 100 then

                self.ticksSinceLastInputForce = 0
                self:setHerdingInputData()
        
            end

        end

    end

    self.ticksSinceLastAnimalHusbandryCheck = self.ticksSinceLastAnimalHusbandryCheck + 1

    local updateRelativeToPlaceables = false
    local updateRelativeToPlayers = self.ticksSinceLastAnimalHusbandryCheck % 10 == 0
    local placeables
    local farms = self.farms
    
    if self.ticksSinceLastAnimalHusbandryCheck >= 35 then

        self.ticksSinceLastAnimalHusbandryCheck = 0

        placeables = {}

        local husbandries = g_currentMission.husbandrySystem.placeables

        for _, husbandry in pairs(husbandries) do

            local farmId = husbandry:getOwnerFarmId()
            if farms[farmId] == nil then continue end

            if placeables[farmId] == nil then placeables[farmId] = {} end

            table.insert(placeables[farmId], {
                ["id"] = husbandry:getUniqueId(),
                ["placeable"] = husbandry
            })

        end

        updateRelativeToPlaceables = true

    end

    for farmId, farm in pairs(farms) do

        local animalsToRemove = {}
        local farmPlaceables
        local players = farm.players

        if updateRelativeToPlaceables then farmPlaceables = placeables[farmId] end

        for i, animal in ipairs(farm.animals) do
    
            if updateRelativeToPlaceables and farmPlaceables ~= nil then

                local hitPlaceable = animal:processPlaceableDetection(farmPlaceables)

                if hitPlaceable ~= nil then
                    table.insert(animalsToRemove, {
                        ["animal"] = i,
                        ["placeable"] = hitPlaceable
                    })
                    continue
                end

            end

            animal:updateRelativeToPlayers(players, updateRelativeToPlayers)
            animal:update(dT)

        end
        
        if self.isServer and updateRelativeToPlaceables then

            for i = #animalsToRemove, 1, -1 do self:returnAnimalToPlaceable(farmId, animalsToRemove[i].animal, farmPlaceables[animalsToRemove[i].placeable].placeable) end

        end

    end

    if self.isServer then

        self.ticksSinceLastPlayerCheck = self.ticksSinceLastPlayerCheck + 1
        self.ticksSinceLastSync = self.ticksSinceLastSync + 1

        if self.ticksSinceLastPlayerCheck >= 6 then

            self.ticksSinceLastPlayerCheck = 0
            self:updatePlayerPositions()

            for farmId, farm in pairs(farms) do farm.players = self:getPlayerPositions(farmId) end

            g_server:broadcastEvent(HerdingPlayerSyncEvent.new())

            local carriedAnimals = self.carriedAnimals

            for i = #carriedAnimals, 1, -1 do

                local carriedAnimal = carriedAnimals[i]
                local handTool = carriedAnimal.handTool
                local farmId = handTool:getOwnerFarmId()
                local husbandry = self:getHusbandryInRange(carriedAnimal.player.rootNode, handTool:getAnimalTypeIndex(), farmId)

                if husbandry == nil and carriedAnimal.placeable ~= nil then
                    carriedAnimal.leaveTimer = carriedAnimal.leaveTimer + 1
                    if carriedAnimal.leaveTimer >= 50 then carriedAnimal.placeable = nil end
                end

                if husbandry == nil or husbandry:getUniqueId() == carriedAnimal.placeable then continue end

                local animal = handTool:getAnimal()

                if self:getHasHusbandryConflict() then animal.idFull, animal.id = nil, nil end

                husbandry:addCluster(animal)
                g_currentMission.handToolSystem:markHandToolForDeletion(handTool)
                table.remove(self.carriedAnimals, i)

            end

        end

        if self.ticksSinceLastSync >= 15 then
            self.ticksSinceLastSync = 0
            self:executeSyncQueue()
        end

        local farmsToRemove = {}
        local hasFarms = false

        for farmId, farm in pairs(farms) do

            if #farm.animals == 0 then
                table.insert(farmsToRemove, farmId)
                g_server:broadcastEvent(HerdingForceStopEvent.new(farmId))
            else
                hasFarms = true
            end

        end

        for _, farmId in pairs(farmsToRemove) do
            for i, j in pairs(self.syncQueue) do
                if j == farmId then table.remove(self.syncQueue, i) end
            end
            farms[farmId] = nil
        end

        if not hasFarms then self.herdingEnabled = false end

    end

    if self.handToolsPostLoad ~= nil then

        for i = #self.handToolsPostLoad, 1, -1 do
            local remove = self.handToolsPostLoad[i]:loadFromPostLoad()
            if remove then table.remove(self.handToolsPostLoad, i) end
        end

        if #self.handToolsPostLoad == 0 then self.handToolsPostLoad = nil end

    end

end


function AnimalManager:draw()

	if self.debugEnabled then

        for _, farm in pairs(self.farms) do
            for _, animal in pairs(farm.animals) do animal:visualise() end
        end

        self.debugProfiler:visualise()

	end

end


function AnimalManager:save(filename)

    if not self.isServer then return end

    local xmlFile = XMLFile.create("animalHerding", filename, "animalHerding")
    local i = 0

    for farmId, farm in pairs(self.farms) do

        local key = string.format("animalHerding.farms.farm(%s)", i)

        xmlFile:setInt(key .. "#farmId", farmId)
        xmlFile:setInt(key .. "#animalTypeIndex", farm.animalTypeIndex)

        for j, animal in ipairs(farm.animals) do
            animal:saveToXMLFile(xmlFile, string.format("%s.animals.animal(%s)", key, j - 1))
        end

        i = i + 1

    end

    xmlFile:save(false, true)
    xmlFile:delete()

end


function AnimalManager:load()

    self.isInitialised = true
    self.isServer = g_currentMission:getIsServer()

    if not self.isServer or g_currentMission.missionInfo == nil or g_currentMission.missionInfo.savegameDirectory == nil then return end

    local xmlFile = XMLFile.loadIfExists("animalHerding", g_currentMission.missionInfo.savegameDirectory .. "/animalHerding.xml")

    if xmlFile == nil then return end

    self.farms, self.syncQueue = {}, {}

    xmlFile:iterate("animalHerding.farms.farm", function(_, key)
    
        local farmId = xmlFile:getInt(key .. "#farmId")
        local animalTypeIndex = xmlFile:getInt(key .. "#animalTypeIndex")
        local farm = {
            ["animals"] = {},
            ["players"] = {},
            ["animalTypeIndex"] = animalTypeIndex
        }

        xmlFile:iterate(key .. ".animals.animal", function(_, animalKey)
        
            local visualAnimalIndex = xmlFile:getInt(animalKey .. "#visualAnimalIndex")
            local tiles = xmlFile:getVector(animalKey .. "#tiles", { 1, 1, 1, 1 })

            local animal, navMeshAgent = self:createHerdableAnimalFromData(animalTypeIndex, visualAnimalIndex, tiles)
            animal:setHotspotFarmId(farmId)
            animal:loadFromXMLFile(xmlFile, animalKey, AnimalManager.CONFLICTS.REALISTIC_LIVESTOCK)
            animal:createCollisionController(navMeshAgent.height, navMeshAgent.radius, animalTypeIndex)
		    animal:updatePosition()
		    animal:updateRotation()

		    table.insert(farm.animals, animal)
        
        end)

        if #farm.animals > 0 then
            self.farms[farmId] = farm
            self.herdingEnabled = true
            table.insert(self.syncQueue, farmId)
        end
    
    end)
    
    xmlFile:delete()
    self:updatePlayerPositions()

    for farmId, farm in pairs(self.farms) do farm.players = self:getPlayerPositions(farmId) end

end


function AnimalManager:postLoad()

    if not self.isServer then return end

end


function AnimalManager:executeSyncQueue()

    local queue = self.syncQueue

    if #queue == 0 then return end

    local farmId = queue[1]

    table.remove(queue, 1)
    if self.farms[farmId] == nil then return end
    table.insert(queue, farmId)

    g_server:broadcastEvent(HerdingSyncEvent.new(self.farms[farmId].animals, farmId))

end


function AnimalManager:updatePlayerPositions()

    local players = g_currentMission.playerSystem.players
    local positions = {}

    for _, player in pairs(players) do

        local farmId = player.farmId

        if self.farms[farmId] == nil then continue end

        if positions[farmId] == nil then positions[farmId] = {} end

        local x, _, z = player:getPosition()
        table.insert(positions[farmId], { x, z, self:getIsPlayerCarryingBucket(player) })

    end

    self.playerPositions = positions

end


function AnimalManager:getPlayerPositions(farmId)

    return self.playerPositions[farmId] or {}

end


function AnimalManager:setPlayerPositions(players)

    self.playerPositions = players

end


function AnimalManager:createHerdableAnimalFromData(animalTypeIndex, visualAnimalIndex, tiles)

    local cache = self:getVisualAnimalFromCache(animalTypeIndex, visualAnimalIndex)

	if cache == nil or cache.root == 0 then return end

    local node = clone(cache.root, false, false, false)
	link(getRootNode(), node)
	setVisibility(node, true)

	local shaderNode = I3DUtil.indexToObject(node, cache.shader)
	local meshNode = I3DUtil.indexToObject(node, cache.mesh)
	local skeletonNode = I3DUtil.indexToObject(node, cache.skeleton)
	local proxyNode = cache.proxy ~= nil and I3DUtil.indexToObject(node, cache.proxy)
	local skinNode = getChildAt(skeletonNode, 0)
	local animationSet = getAnimCharacterSet(skinNode)

	I3DUtil.setShaderParameterRec(meshNode, "atlasInvSizeAndOffsetUV", tiles[1], tiles[2], tiles[3], tiles[4], false)
    
    local animal = HerdableAnimal.new(nil, node, meshNode, shaderNode, skinNode, animationSet, cache.animation, proxyNode)
    animal:setHotspotIcon(animalTypeIndex)
    animal:setData(visualAnimalIndex, tiles[1], tiles[2], tiles[3], tiles[4])
    animal:validateSpeed(animalTypeIndex)
	
    return animal, cache.navMeshAgent

end


function AnimalManager:overwriteEngineFunctions()


	local engine = {
        ["addHusbandryAnimal"] = addHusbandryAnimal,
        ["removeHusbandryAnimal"] = removeHusbandryAnimal,
        ["createAnimalHusbandry"] = createAnimalHusbandry,
        ["getAnimalRootNode"] = getAnimalRootNode,
        ["setAnimalTextureTile"] = setAnimalTextureTile
    }


	--getAnimalRootNode = function(husbandryId, animalId)

		--return engine.getAnimalRootNode(husbandryId, animalId)

	--end


    createAnimalHusbandry = function(animalTypeName, navigationNode, xmlPath, raycastDistance, collisionFilter, collisionMask, audioGroup)

        local husbandryId = engine.createAnimalHusbandry(animalTypeName, navigationNode, xmlPath, raycastDistance, collisionFilter, collisionMask, audioGroup)

        if husbandryId == 0 then return 0 end

        self.husbandries[husbandryId] = {
            ["animalTypeIndex"] = AnimalType[animalTypeName],
            ["animals"] = {}
        }

        return husbandryId

    end


    addHusbandryAnimal = function(husbandryId, visualAnimalIndex)

        local animalId = engine.addHusbandryAnimal(husbandryId, visualAnimalIndex)

        if animalId == 0 then return 0 end

        self.husbandries[husbandryId].animals[animalId] = {
            ["tiles"] = { ["u"] = 1, ["v"] = 1 },
            ["visualAnimalIndex"] = visualAnimalIndex + 1
        }

        -- ########### TODO
        -- add collisions to basegame animals (chickens) without collisions
        -- this will allow them to be picked up
        -- ###########

        --local animalTypeIndex = self.husbandries[husbandryId].animalTypeIndex
        --local cache = self:getVisualAnimalFromCache(animalTypeIndex, visualAnimalIndex)

        --if cache.proxy == nil then

            --local proxyI3D = self:getCollisionProxy(animalTypeIndex)
            --local rootNode = getAnimalRootNode(husbandryId, animalId)
            --link(rootNode, proxyI3D)
		    --setScale(proxyI3D, self.radius, self.height, self.radius)
		    --setTranslation(proxyI3D, 0, 0, -self.radius * 0.5)
		    --addToPhysics(getChildAt(proxyI3D, 0))

        --end

        return animalId

    end


    removeHusbandryAnimal = function(husbandryId, animalId)

        engine.removeHusbandryAnimal(husbandryId, animalId)

        table.removeElement(self.husbandries[husbandryId].animals, animalId)

    end


	setAnimalTextureTile = function(husbandryId, animalId, tileU, tileV)

        self.husbandries[husbandryId].animals[animalId].tiles = { ["u"] = tileU, ["v"] = tileV }

		engine.setAnimalTextureTile(husbandryId, animalId, tileU, tileV)

	end

end


function AnimalManager:validateConflicts()

    AnimalManager.CONFLICTS.REALISTIC_LIVESTOCK = g_modIsLoaded["FS25_RealisticLivestock"]
    AnimalManager.CONFLICTS.MORE_VISUAL_ANIMALS = g_modIsLoaded["FS25_MoreVisualAnimals"]

    if AnimalManager.CONFLICTS.REALISTIC_LIVESTOCK then FS25_RealisticLivestock.source(modDirectory .. "animals/husbandry/cluster/Animal.lua") end

end


function AnimalManager:configureCollisionControllerOffsets()

    AnimalManager.ANIMAL_TYPE_INDEX_TO_AGE_OFFSET = {
        [AnimalType.COW] = 12,
	    [AnimalType.PIG] = 6,
	    [AnimalType.SHEEP] = 8,
	    [AnimalType.HORSE] = 0,
	    [AnimalType.CHICKEN] = 6
    }

end


function AnimalManager:getHasHusbandryConflict()

    return AnimalManager.CONFLICTS.REALISTIC_LIVESTOCK or AnimalManager.CONFLICTS.MORE_VISUAL_ANIMALS

end


function AnimalManager:getVisualAnimalFromCache(animalTypeIndex, visualAnimalIndex)

	if self.cache[animalTypeIndex] == nil then self.cache[animalTypeIndex] = {} end

	local cache = self.cache[animalTypeIndex]

	--if cache[visualAnimalIndex] == nil then self:addVisualAnimalToCache(animalTypeIndex, visualAnimalIndex) end

	return cache[visualAnimalIndex]

end


function AnimalManager:addAnimalTypeToCache(animalType, baseDirectory)

	local animalTypeIndex = animalType.typeIndex
    self.cache[animalTypeIndex] = {}

	local splitPath = string.split(animalType.configFilename, "/")
    local directory = table.concat(splitPath, "/", 1, #splitPath - 1) .. "/"
	local animationI3Ds, locomotionXMLs, animationXMLs = {}, {}, {}
	local configXml = XMLFile.load("animalHusbandryConfigXML_" .. animalType.groupTitle, animalType.configFilename)

    configXml:iterate("animalHusbandry.animals.animal", function(visualAnimalIndex, key)

	    local animationI3DFilename = Utils.getFilename(configXml:getString(key .. ".assets#animation"), directory)
        local animationI3D = animationI3Ds[animationI3DFilename]

        if animationI3D == nil then
		    animationI3D = loadI3DFile(animationI3DFilename, false, false, false)
            animationI3Ds[animationI3DFilename] = animationI3D
        end

        local skeletonIndex = string.gsub(configXml:getString(key .. ".assets#skeletonIndex"), ">", "|")
	    local skeletonNode = I3DUtil.indexToObject(animationI3D, skeletonIndex)

        local shaderIndex = string.gsub(configXml:getString(key .. ".assets#shaderIndex"), ">", "|")
        local meshIndex = string.gsub(configXml:getString(key .. ".assets#meshIndex"), ">", "|")
        
        local proxyIndexLiteral = configXml:getString(key .. ".assets#proxyIndex")
        local proxyIndex
        if proxyIndexLiteral ~= nil then proxyIndex = string.gsub(proxyIndexLiteral, ">", "|") end

	    if skeletonNode == nil then

		    Logging.xmlError(configXml, "Invalid skeleton index %q given at %q. Unable to find node", skeletonIndex, key .. ".assets#skeletonIndex")

	    else

		    local skinNode = getChildAt(skeletonNode, 0)
		    local animationSet = getAnimCharacterSet(skinNode)

            if animationSet ~= 0 then

                local modelFilename = configXml:getString(key .. ".assets#filename")
                local posedFilename = configXml:getString(key .. ".assets#filenamePosed")
                local modelI3D, posedI3D

                if fileExists(Utils.getFilename(modelFilename, directory)) then
                    modelI3D = loadI3DFile(Utils.getFilename(modelFilename, directory), false, false, false)
                elseif fileExists(Utils.getFilename(modelFilename, baseDirectory)) then
                    modelI3D = loadI3DFile(Utils.getFilename(modelFilename, baseDirectory), false, false, false)
                end

                if fileExists(Utils.getFilename(posedFilename, directory)) then
                    posedI3D = loadI3DFile(Utils.getFilename(posedFilename, directory), false, false, false)
                elseif fileExists(Utils.getFilename(posedFilename, baseDirectory)) then
                    posedI3D = loadI3DFile(Utils.getFilename(posedFilename, baseDirectory), false, false, false)
                end

                if modelI3D ~= nil and posedI3D ~= nil and modelI3D ~= 0 and posedI3D ~= 0 then

                    link(getRootNode(), modelI3D)
                    link(getRootNode(), posedI3D)

                    local modelSkeletonNode = I3DUtil.indexToObject(modelI3D, skeletonIndex)
                    local modelSkinNode = getChildAt(modelSkeletonNode, 0)
                    setVisibility(modelI3D, false)

                    local numTilesU = configXml:getInt(key .. ".assets.texture(0)#numTilesU", 1)
                    local numTilesV = configXml:getInt(key .. ".assets.texture(0)#numTilesV", 1)

                    local animationUsesSkeleton = false
                    local animCloneSuccess = cloneAnimCharacterSet(skinNode, modelSkinNode)

                    if not animCloneSuccess then
                        animCloneSuccess = cloneAnimCharacterSet(skeletonNode, modelSkeletonNode)
                        animationUsesSkeleton = true
                    end

                    if animCloneSuccess and animationUsesSkeleton then Logging.warning(string.format("Animation at \'%s\' has no skeleton node, using skin node instead", animationI3DFilename)) end

                    local modelAnimationSet = getAnimCharacterSet(animationUsesSkeleton and modelSkeletonNode or modelSkinNode)

                    if modelAnimationSet ~= 0 then

                        local height, radius = animalType.navMeshAgentAttributes.height, animalType.navMeshAgentAttributes.radius
                   
                        if proxyIndex ~= nil then
                            local proxyNode = I3DUtil.indexToObject(modelI3D, proxyIndex)
                            setScale(proxyNode, 1, 1, 0.9)
                        else
                            self:loadProxy(animalTypeIndex, height, radius)
                        end

                        self:loadCollisionController(animalTypeIndex, height, radius)

                        local posedMeshIndex = meshIndex

                        if tonumber(string.sub(posedMeshIndex, 1, 1)) > tonumber(string.sub(skeletonIndex, 1, 1)) then

                            posedMeshIndex = (tonumber(string.sub(posedMeshIndex, 1, 1)) - 1) .. string.sub(posedMeshIndex, 2)

                        end

                        local cache = {
                            ["root"] = modelI3D,
                            ["posed"] = posedI3D,
                            ["shader"] = shaderIndex,
                            ["mesh"] = meshIndex,
                            ["posedMesh"] = posedMeshIndex,
                            ["skeleton"] = skeletonIndex,
                            ["proxy"] = proxyIndex,
                            ["tiles"] = {
                                ["x"] = 1 / numTilesU,
                                ["y"] = 1 / numTilesV
                            },
                            ["animation"] = {},
                            ["navMeshAgent"] = {
                                ["height"] = height,
                                ["radius"] = radius
                            }
                        }

                        local locomotionFilename = Utils.getFilename(configXml:getString(key .. ".locomotion#filename"), directory)
                        local locomotionXML = locomotionXMLs[locomotionFilename]
                    
                        if locomotionXML == nil then
                            locomotionXML = XMLFile.load(string.format("locomotionXML_%s_%s", animalType.groupTitle, visualAnimalIndex), locomotionFilename)
                            locomotionXMLs[locomotionFilename] = locomotionXML
                        end

				        local animationFilename = locomotionXML:getString("locomotion.animation#filename")

                        if fileExists(Utils.getFilename(animationFilename, directory)) then
                            animationFilename = Utils.getFilename(animationFilename, directory)
                        elseif fileExists(Utils.getFilename(animationFilename, baseDirectory)) then
                            animationFilename = Utils.getFilename(animationFilename, baseDirectory)
                        else
                            local splitPathLocomotion = string.split(locomotionFilename, "/")
                            local animationDirectory = table.concat(splitPathLocomotion, "/", 1, #splitPathLocomotion - 1) .. "/"
                            if fileExists(Utils.getFilename(animationFilename, animationDirectory)) then animationFilename = Utils.getFilename(animationFilename, animationDirectory) end
                        end

                        local animation

                        for _, existingCache in pairs(self.cache[animalTypeIndex]) do

                            if existingCache.animation.filename == animationFilename then
                                animation = existingCache.animation
                                break
                            end

                        end
                    
                        if animation == nil then

                            animation = self:loadAnimations(animationFilename, modelAnimationSet, animationUsesSkeleton)

                            animation.wanderMin = configXml:getInt(key .. ".statesTimers#wanderMin", 5000)
                            animation.wanderMax = configXml:getInt(key .. ".statesTimers#wanderMax", 10000)

                            animation.idleMin = configXml:getInt(key .. ".statesTimers#idleMin", 5000)
                            animation.idleMax = configXml:getInt(key .. ".statesTimers#idleMax", 10000)

                        end

                        cache.animation = animation
                
                        self.cache[animalTypeIndex][visualAnimalIndex] = cache

                    end

                else

                    if modelI3D == nil or modelI3D == 0 then Logging.warning(string.format("AnimalManager:addAnimalTypeToCache() - could not load model %s from directory (%s or %s)", modelFilename, Utils.getFilename(modelFilename, directory), Utils.getFilename(modelFilename, baseDirectory))) end
                    if posedI3D == nil or posedI3D == 0 then Logging.warning(string.format("AnimalManager:addAnimalTypeToCache() - could not load model %s from directory (%s or %s)", posedFilename, Utils.getFilename(posedFilename, directory), Utils.getFilename(posedFilename, baseDirectory))) end

                end

            end

	    end

    end)

    configXml:delete()

    for _, animationI3D in pairs(animationI3Ds) do delete(animationI3D) end
    for _, locomotionXML in pairs(locomotionXMLs) do locomotionXML:delete() end

    print("", string.format("AnimalHerdingLite: cached animal type \'%s\'", animalType.groupTitle))

    for visualAnimalIndex, cache in pairs(self.cache[animalTypeIndex]) do
        print(string.format("| ----- %s", visualAnimalIndex))
    end

    print("")

end


function AnimalManager:cacheAnimationsFromExistingCache(cache, animationSet)

    local clipTypes = {
        "clip",
        "clipLeft",
        "clipRight"
    }

    for _, state in pairs(cache.states) do

        for _, animation in pairs(state) do

            for _, clipType in pairs(clipTypes) do

                if animation.clipType == nil then continue end

                assignAnimTrackClip(animationSet, animation[clipType].track, animation[clipType].index)

            end

        end

    end

    for _, clip in pairs(cache.clips) do

        assignAnimTrackClip(animationSet, clip.track, clip.index)

    end

    return cache

end


function AnimalManager:loadAnimations(filename, animationSet, useSkeleton)

    local xmlFile = XMLFile.load(string.format("animationXML_%s_%s", filename, animationSet), filename)

    local cache = {
        ["states"] = {},
        ["clips"] = {},
        ["filename"] = filename,
        ["useSkeleton"] = useSkeleton
    }

    if animationSet == 0 then return cache end

    local clipTypes = {
        "clip",
        "clipLeft",
        "clipRight"
    }

    xmlFile:iterate("animation.states.state", function(_, key)
    
        local stateId = xmlFile:getString(key .. "#id")
        local animations = {}

        xmlFile:iterate(key .. ".animation", function(_, animKey)
        
            local animation = {
                ["id"] = xmlFile:getString(animKey .. "#id"),
                ["transitions"] = {},
                ["speed"] = xmlFile:getFloat(animKey .. "#speed", 1.0)
            }
            
            for _, clipType in pairs(clipTypes) do

                local clipKey = string.format("%s#%s", animKey, clipType)

                if xmlFile:hasProperty(clipKey) then

                    local clipName = xmlFile:getString(clipKey)
                    local clipIndex = getAnimClipIndex(animationSet, clipName)

                    if clipIndex ~= nil then

                        animation[clipType] = {
                            ["name"] = clipName,
                            ["index"] = clipIndex,
                            ["type"] = clipType
                        }

                    end

                end

            end

            animations[animation.id] = animation
        
        end)
        
        cache.states[stateId] = animations

    end)

    local defaultBlendTime = xmlFile:getInt("animation.transitions#defaultBlendTime", 750)

    xmlFile:iterate("animation.transitions.transition", function(_, key)
    
        local idFrom = xmlFile:getString(key .. "#animationIdFrom")
        local idTo = xmlFile:getString(key .. "#animationIdTo")
        local blendTime = xmlFile:getInt(key .. "#blendTime", defaultBlendTime)
        local targetTime = xmlFile:getInt(key .. "#targetTime", 0)

        local clip = xmlFile:getString(key .. "#clip")
        local indexes = {}

        if clip ~= nil then

            if cache.clips[clip] == nil then

                local clipIndex = getAnimClipIndex(animationSet, clip)

                table.insert(indexes, clipIndex)

                cache.clips[clip] = {
                    ["name"] = clip,
                    ["index"] = clipIndex
                }

            end

        else

             for _, state in pairs(cache.states) do

                if state[idTo] == nil then continue end
                
                local animation = state[idTo]

                if animation.clipLeft ~= nil then table.insert(indexes, animation.clipLeft.index) end
                if animation.clipRight ~= nil then table.insert(indexes, animation.clipRight.index) end
                if animation.clip ~= nil then table.insert(indexes, animation.clip.index) end

             end

        end

        if #indexes > 0 then

            for _, state in pairs(cache.states) do

                if state[idFrom] == nil then continue end

                state[idFrom].transitions[idTo] = {
                    ["blendTime"] = blendTime,
                    ["targetTime"] = targetTime,
                    ["indexes"] = indexes
                }

            end

        end
    
    end)

    xmlFile:delete()

    return cache

end


function AnimalManager:getHusbandryInRange(node, animalTypeIndex, farmId)

    local husbandries = g_currentMission.husbandrySystem:getPlaceablesByFarm(farmId, animalTypeIndex)

    node = node or g_localPlayer.rootNode
    local x, _, z = getWorldTranslation(node)

    for _, husbandry in pairs(husbandries) do

        if husbandry:getIsInAnimalDeliveryArea(x, z) then return husbandry end

    end

    return nil

end


function AnimalManager:returnAnimalToPlaceable(farmId, animalIndex, placeable)

    local farm = self.farms[farmId]
    local animal = farm.animals[animalIndex]
    if self:getHasHusbandryConflict() then animal.cluster.idFull, animal.cluster.id = nil, nil end

    placeable:addCluster(animal.cluster)

    animal:delete()
    table.remove(farm.animals, animalIndex)

end


function AnimalManager:removeHerdedAnimal(farmId, animal)

    if self.farms[farmId] == nil then return end

    local animals = self.farms[farmId].animals
    local id = animal.id

    for i, j in ipairs(animals) do

        if j.id == id then
            j:delete()
            table.remove(animals, i)
            return
        end

    end

end


function AnimalManager:getVisualDataForEngineAnimal(husbandryId, animalId)

    local husbandry = self.husbandries[husbandryId]

    if husbandry == nil then return nil, nil, nil end

    local animal = husbandry.animals[animalId]

    if animal == nil then return nil, nil, nil end

    return animal.visualAnimalIndex, animal.tiles.u, animal.tiles.v

end


function AnimalManager:loadCollisionController(animalTypeIndex, height, radius)

    if self.collisionControllers[animalTypeIndex] ~= nil then return end

    if self.collisionControllerTemplate == nil then
        self.collisionControllerTemplate = g_i3DManager:loadI3DFile(modDirectory .. "i3d/collisionController.i3d")
        link(getRootNode(), self.collisionControllerTemplate)
        setVisibility(self.collisionControllerTemplate, false)
    end

    local node = clone(self.collisionControllerTemplate, true, false, false)
    setScale(node, radius, height, radius)
    self.collisionControllers[animalTypeIndex] = node

end


function AnimalManager:loadProxy(animalTypeIndex, height, radius)

    if self.proxies[animalTypeIndex] ~= nil then return end

    if self.proxyTemplate == nil then
        self.proxyTemplate = g_i3DManager:loadI3DFile(modDirectory .. "i3d/proxy.i3d")
        link(getRootNode(), self.proxyTemplate)
        setVisibility(self.proxyTemplate, false)
    end

    local node = clone(self.proxyTemplate, true, false, false)
    setScale(node, radius, height, radius)
    self.proxies[animalTypeIndex] = node

end


function AnimalManager:getCollisionController(animalTypeIndex)

    return clone(self.collisionControllers[animalTypeIndex] or self.collisionControllerTemplate, true, false, false)

end


function AnimalManager:getCollisionProxy(animalTypeIndex)

    return clone(self.proxies[animalTypeIndex] or self.proxyTemplate, true, false, false)

end


function AnimalManager:getIsConnectionInitialised(connection)

    return self.connections[connection.streamId]

end


function AnimalManager:setConnectionInitialised(connection)

    self.connections[connection.streamId] = true

end


function AnimalManager:startHerding(husbandry)

    if not self.isServer then return end
 
    local farmId = husbandry:getOwnerFarmId()

    if self.farms[farmId] ~= nil then return end

    local animals = {}

    husbandry:toggleHerding(animals)

    if #animals == 0 then return end

    self.farms[farmId] = {
        ["animals"] = animals,
        ["players"] = {},
        ["animalTypeIndex"] = husbandry:getAnimalTypeIndex()
    }

    table.insert(self.syncQueue, farmId)

    self.farms[farmId].players = self:getPlayerPositions(farmId)
    self.herdingEnabled = true

    g_server:broadcastEvent(HerdingEvent.new(farmId))

end


function AnimalManager:stopHerding(farmId)

    if not self.isServer or not self.herdingEnabled or self.farms[farmId] == nil then return end

    local farm = self.farms[farmId]
    local placeables = g_currentMission.husbandrySystem:getPlaceablesByFarm(farmId, farm.animalTypeIndex)
    local validPlaceables = {}

    for _, placeable in pairs(placeables) do
        if placeable:getNumOfFreeAnimalSlots() > 0 then
            local x, z = getWorldTranslation(placeable.rootNode)
            table.insert(validPlaceables, {
                ["placeable"] = placeable,
                ["x"] = x,
                ["z"] = z
            })
        end
    end

    if #validPlaceables == 0 then return end

    for i = #farm.animals, 1, -1 do

        local closest
        local animal = farm.animals[i]
        local x, z = animal.position.x, animal.position.z

        for j, placeable in pairs(validPlaceables) do

            if placeable.placeable:getIsInAnimalDeliveryArea(x, z) then
                closest = {
                    ["index"] = j,
                    ["distance"] = 0
                }
                break
            end

            local distance = MathUtil.vector2Length(x - placeable.x, z - placeable.z)

            if closest == nil or distance < closest.distance then

                closest = {
                    ["index"] = j,
                    ["distance"] = distance
                }

            end

        end

        local placeable = validPlaceables[closest.index].placeable
        self:returnAnimalToPlaceable(farmId, i, placeable)

        if placeable:getNumOfFreeAnimalSlots() <= 0 then
            table.remove(validPlaceables, closest.index)
            if #validPlaceables == 0 and i ~= 1 then return end
        end

    end
        
    g_server:broadcastEvent(HerdingForceStopEvent.new(farmId))
    self.farms[farmId] = nil
    self.herdingEnabled = false

    for j, _ in pairs(self.farms) do
        self.herdingEnabled = true
        break
    end

    for i, j in pairs(self.syncQueue) do
        if j == farmId then
            table.remove(self.syncQueue, i)
            break
        end
    end

end


function AnimalManager:setHerdingInputData()

    if g_localPlayer == nil then return end
    
    local herdingEnabled = self.farms[g_localPlayer.farmId] ~= nil

    g_inputBinding:setActionEventActive(self.herdingEventId, herdingEnabled)
    g_inputBinding:setActionEventText(self.herdingEventId, g_i18n:getText(herdingEnabled and "ahl_stopHerding" or "ahl_startHerding", modName))

end


function AnimalManager:getIsPlayerCarryingBucket(player)
    
    return self.feedBuckets[player:getUniqueId()] or false

end


function AnimalManager:setPlayerUsingBucket(player, hasBucket)

    self.feedBuckets[player:getUniqueId()] = hasBucket

end


function AnimalManager:addAnimalCollisionNode(animal, node)

    self.collisionNodes[node] = animal

end


function AnimalManager:deleteAnimalCollisionNode(node)

    table.removeElement(self.collisionNodes, node)

end


function AnimalManager:getAnimalFromCollisionNode(node, farmId)

    local animal = self.collisionNodes[node]

    if animal ~= nil and animal:getHotspotFarmId() == farmId then return animal end

    return nil

end


function AnimalManager:addCarriedAnimalToPlayer(player, handTool, placeable)

    table.insert(self.carriedAnimals, {
        ["player"] = player,
        ["handTool"] = handTool,
        ["placeable"] = placeable,
        ["leaveTimer"] = 0
    })

end


function AnimalManager:addHandToolToSetOnPostLoad(handTool)

    table.insert(self.handToolsPostLoad, handTool)

end


function AnimalManager:getAnimalTypeIndexForFarm(farmId)

    if self.farms[farmId] == nil then return nil end

    return self.farms[farmId].animalTypeIndex

end


function AnimalManager.onToggleHerding()

    if g_localPlayer == nil then return end

    if g_animalManager.farms[g_localPlayer.farmId] ~= nil then

        g_client:getServerConnection():sendEvent(HerdingRequestEvent.new(false, nil, g_localPlayer.farmId))

    else

        local husbandry = g_animalManager:getHusbandryInRange()

        if husbandry ~= nil then g_client:getServerConnection():sendEvent(HerdingRequestEvent.new(true, husbandry)) end

    end

end


function AnimalManager.consoleCommandToggleDebug()

	g_animalManager.debugEnabled = not g_animalManager.debugEnabled
	g_animalManager.debugProfiler.debugEnabled = g_animalManager.debugEnabled

	return string.format("Animal debug mode: %s", g_animalManager.debugEnabled and "on" or "off")

end


g_animalManager = AnimalManager.new()