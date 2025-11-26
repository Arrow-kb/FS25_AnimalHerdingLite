AnimalManager = {}


AnimalManager.CONFLICTS = {}
AnimalManager.ANIMAL_TYPE_INDEX_TO_AGE_OFFSET = {}


local AnimalManager_mt = Class(AnimalManager)
local modDirectory = g_currentModDirectory
local modName = g_currentModName


function AnimalManager.new()

	local self = setmetatable({}, AnimalManager_mt)

	self.debugEnabled = false
	self.herdingEnabled = false
	self.cache = {}
    self.animals = {}
    self.husbandries = {}
    self.ticksSinceLastHusbandryCheck = 0
    self.ticksSinceLastPlayerCheck = 0
    self.ticksSinceLastAnimalHusbandryCheck = 0
    self.collisionControllers = {}

	self:overwriteEngineFunctions()

	--g_isDevelopmentVersion = true
	--g_addCheatCommands = true

	addConsoleCommand("toggleAnimalDebug", "Toggle animal debug mode", "consoleCommandToggleDebug", AnimalManager)

	return self

end


function AnimalManager:update(dT)
    
    if not self.herdingEnabled then

        self.ticksSinceLastHusbandryCheck = self.ticksSinceLastHusbandryCheck + 1

        if self.ticksSinceLastHusbandryCheck >= 75 then

            self.ticksSinceLastHusbandryCheck = 0

            local husbandry = self:getHusbandryInRange()
        
            g_inputBinding:setActionEventActive(self.herdingEventId, husbandry ~= nil)

            if husbandry ~= nil then g_inputBinding:setActionEventText(self.herdingEventId, g_i18n:getText("ahl_startHerding", modName)) end

        end
    
        return

    end

    self.ticksSinceLastPlayerCheck = self.ticksSinceLastPlayerCheck + 1
    self.ticksSinceLastAnimalHusbandryCheck = self.ticksSinceLastAnimalHusbandryCheck + 1

    local updateRelativeToPlayer = false
    local updateRelativeToPlaceables = false
    local x, y, z, placeables
    
    if self.ticksSinceLastPlayerCheck >= 10 then

        self.ticksSinceLastPlayerCheck = 0

        x, y, z = g_localPlayer:getPosition()
        updateRelativeToPlayer = true

    end
    
    if self.ticksSinceLastAnimalHusbandryCheck >= 35 and not updateRelativeToPlayer then

        self.ticksSinceLastAnimalHusbandryCheck = 0

        placeables = {}

        local husbandries = g_currentMission.husbandrySystem:getPlaceablesByFarm(nil, self.currentlyHerdedAnimalTypeIndex)

        for _, husbandry in pairs(husbandries) do
            table.insert(placeables, {
                ["id"] = husbandry:getUniqueId(),
                ["placeable"] = husbandry
            })
        end

        updateRelativeToPlaceables = #placeables > 0

    end

    local animalsToRemove = {}

    for i, animal in ipairs(self.animals) do
    
        if updateRelativeToPlaceables then

            local hitPlaceable = animal:processPlaceableDetection(placeables)

            if hitPlaceable ~= nil then
                table.insert(animalsToRemove, {
                    ["animal"] = i,
                    ["placeable"] = hitPlaceable
                })
                continue
            end

        end

        if updateRelativeToPlayer then animal:updateRelativeToPlayer(x, y, z) end

        animal:update(dT)

    end

    for i = #animalsToRemove, 1, -1 do self:returnAnimalToPlaceable(animalsToRemove[i].animal, placeables[animalsToRemove[i].placeable].placeable) end

    if #self.animals == 0 then
        self.herdingEnabled = false
        g_inputBinding:setActionEventActive(g_animalManager.herdingEventId, false)
    end

end


function AnimalManager:draw()

	if self.debugEnabled then

        for _, animal in pairs(self.animals) do animal:visualise() end

	end

end


function AnimalManager:save(filename)

    local xmlFile = XMLFile.create("animalHerding", filename, "animalHerding")

    if self.currentlyHerdedAnimalTypeIndex ~= nil then xmlFile:setInt("animalHerding#currentlyHerdedAnimalTypeIndex", self.currentlyHerdedAnimalTypeIndex) end

    for i, animal in ipairs(self.animals) do

        local key = string.format("animalHerding.animals.animal(%s)", i - 1)
        animal:saveToXMLFile(xmlFile, key)

    end

    xmlFile:save(false, true)
    xmlFile:delete()

end


function AnimalManager:load()

    if g_currentMission.missionInfo == nil or g_currentMission.missionInfo.savegameDirectory == nil then return end

    local xmlFile = XMLFile.loadIfExists("animalHerding", g_currentMission.missionInfo.savegameDirectory .. "/animalHerding.xml")

    if xmlFile == nil then return end

    self.currentlyHerdedAnimalTypeIndex = xmlFile:getInt("animalHerding#currentlyHerdedAnimalTypeIndex")
    local animalTypeIndex = self.currentlyHerdedAnimalTypeIndex

    xmlFile:iterate("animalHerding.animals.animal", function(_, key)

        local visualAnimalIndex = xmlFile:getInt(key .. "#visualAnimalIndex")
        local tiles = xmlFile:getVector(key .. "#tiles", { 1, 1, 1, 1 })

        local cache = g_animalManager:getVisualAnimalFromCache(animalTypeIndex, visualAnimalIndex)

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
        animal:loadFromXMLFile(xmlFile, key, AnimalManager.CONFLICTS.REALISTIC_LIVESTOCK)
        animal:createCollisionController(cache.navMeshAgent.height, cache.navMeshAgent.radius, animalTypeIndex)
        animal:setData(visualAnimalIndex, tiles[1], tiles[2], tiles[3], tiles[4])
		animal:updatePosition()
		animal:updateRotation()

		table.insert(self.animals, animal)
    
    end)
    
    xmlFile:delete()

    self.herdingEnabled = #self.animals > 0
    if self.herdingEnabled then g_inputBinding:setActionEventText(self.herdingEventId, g_i18n:getText("ahl_stopHerding", modName)) end
    g_inputBinding:setActionEventActive(self.herdingEventId, self.herdingEnabled)


end


function AnimalManager:overwriteEngineFunctions()


	local engine = {
        ["addHusbandryAnimal"] = addHusbandryAnimal,
        ["removeHusbandryAnimal"] = removeHusbandryAnimal,
        ["createAnimalHusbandry"] = createAnimalHusbandry,
        ["getAnimalRootNode"] = getAnimalRootNode,
        ["setAnimalTextureTile"] = setAnimalTextureTile
    }


	getAnimalRootNode = function(husbandryId, animalId)

		return engine.getAnimalRootNode(husbandryId, animalId)

	end


    createAnimalHusbandry = function(animalTypeName, navigationNode, xmlPath, raycastDistance, collisionFilter, collisionMask, audioGroup)

        local husbandryId = engine.createAnimalHusbandry(animalTypeName, navigationNode, xmlPath, raycastDistance, collisionFilter, collisionMask, audioGroup)

        if husbandryId == 0 then return 0 end

        self.husbandries[husbandryId] = {}

        return husbandryId

    end


    addHusbandryAnimal = function(husbandryId, visualAnimalIndex)

        local animalId = engine.addHusbandryAnimal(husbandryId, visualAnimalIndex)

        if animalId == 0 then return 0 end

        self.husbandries[husbandryId][animalId] = {
            ["tiles"] = { ["u"] = 1, ["v"] = 1 },
            ["visualAnimalIndex"] = visualAnimalIndex + 1
        }

        return animalId

    end


    removeHusbandryAnimal = function(husbandryId, animalId)

        engine.removeHusbandryAnimal(husbandryId, animalId)

        table.removeElement(self.husbandries[husbandryId], animalId)

    end


	setAnimalTextureTile = function(husbandryId, animalId, tileU, tileV)

        self.husbandries[husbandryId][animalId].tiles = { ["u"] = tileU, ["v"] = tileV }

		engine.setAnimalTextureTile(husbandryId, animalId, tileU, tileV)

	end

end


function AnimalManager:validateConflicts()

    AnimalManager.CONFLICTS.REALISTIC_LIVESTOCK = g_modIsLoaded["FS25_RealisticLivestock"]
    AnimalManager.CONFLICTS.MORE_VISUAL_ANIMALS = g_modIsLoaded["FS25_MoreVisualAnimals"]

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


function AnimalManager:addAnimalTypeToCache(animalType)

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

                local modelI3D = loadI3DFile(Utils.getFilename(configXml:getString(key .. ".assets#filename"), directory), false, false, false)

                link(getRootNode(), modelI3D)

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

                    self:loadCollisionController(animalTypeIndex, height, radius)

                    local cache = {
                        ["root"] = modelI3D,
                        ["shader"] = shaderIndex,
                        ["mesh"] = meshIndex,
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

				    local animationFilename = Utils.getFilename(locomotionXML:getString("locomotion.animation#filename"), directory)
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


function AnimalManager:getHusbandryInRange(node, animalTypeIndex)

    local husbandries = g_currentMission.husbandrySystem:getPlaceablesByFarm(nil, animalTypeIndex)

    node = node or g_localPlayer.rootNode
    local x, _, z = getWorldTranslation(node)

    for _, husbandry in pairs(husbandries) do

        if husbandry:getIsInAnimalDeliveryArea(x, z) then return husbandry end

    end

    return nil

end


function AnimalManager:returnAnimalToPlaceable(animalIndex, placeable)

    local animal = self.animals[animalIndex]
    if self:getHasHusbandryConflict() then animal.cluster.idFull, animal.cluster.id = nil, nil end

    placeable:addCluster(animal.cluster)

    animal:delete()
    table.remove(self.animals, animalIndex)

end


function AnimalManager:getVisualDataForEngineAnimal(husbandryId, animalId)

    local husbandry = self.husbandries[husbandryId]

    if husbandry == nil then return nil, nil, nil end

    local animal = husbandry[animalId]

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


function AnimalManager:getCollisionController(animalTypeIndex)

    return clone(self.collisionControllers[animalTypeIndex] or self.collisionControllerTemplate, true, false, false)

end


function AnimalManager.onToggleHerding()

    if g_animalManager.herdingEnabled then

        local placeables = g_currentMission.husbandrySystem:getPlaceablesByFarm(nil, g_animalManager.currentlyHerdedAnimalTypeIndex)
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

        for i = #g_animalManager.animals, 1, -1 do

            local closest
            local animal = g_animalManager.animals[i]
            local x, z = animal.position.x, animal.position.z

            for j, placeable in pairs(validPlaceables) do

                local distance = MathUtil.vector2Length(x - placeable.x, z - placeable.z)

                if closest == nil or distance < closest.distance then

                    closest = {
                        ["index"] = j,
                        ["distance"] = distance
                    }

                end

            end

            local placeable = validPlaceables[closest.index].placeable
            g_animalManager:returnAnimalToPlaceable(i, placeable)
            if placeable:getNumOfFreeAnimalSlots() <= 0 then
                table.remove(validPlaceables, closest.index)
                if #validPlaceables == 0 and i ~= 1 then return end
            end

        end
        
        g_animalManager.herdingEnabled = false
        g_inputBinding:setActionEventActive(g_animalManager.herdingEventId, false)

    else

        local husbandry = g_animalManager:getHusbandryInRange()

        g_inputBinding:setActionEventActive(g_animalManager.herdingEventId, husbandry ~= nil)

        if husbandry == nil then return end

        g_animalManager.currentlyHerdedAnimalTypeIndex = husbandry:getAnimalTypeIndex()
        g_animalManager.herdingEnabled = true
	    g_inputBinding:setActionEventText(g_animalManager.herdingEventId, g_i18n:getText("ahl_stopHerding", modName))
        husbandry:toggleHerding()

    end

end


function AnimalManager.consoleCommandToggleDebug()

	g_animalManager.debugEnabled = not g_animalManager.debugEnabled

	return string.format("Animal debug mode: %s", g_animalManager.debugEnabled and "on" or "off")

end


g_animalManager = AnimalManager.new()