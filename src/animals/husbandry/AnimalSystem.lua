AH_AnimalSystem = {}


function AnimalSystem:addAnimalTypeToCache(animalType, baseDirectory)

    local configXml = XMLFile.load("animalHusbandryConfigXML_" .. animalType.groupTitle, animalType.configFilename)

    local splitPath = string.split(animalType.configFilename, "/")
    local directory = table.concat(splitPath, "/", 1, #splitPath - 1) .. "/"

    print("-----", animalType.groupTitle)

    local locomotionXMLs = {}
    local animationXMLs = {}
    local animationI3Ds = {}
    local animationCache = {}
    local numVisualAnimalIndexes = configXml:getNumOfChildren("animalHusbandry.animals")

    for visualAnimalIndex, key in configXml:iterator("animalHusbandry.animals.animal") do

        print("---", visualAnimalIndex)

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

		if skeletonNode == nil then

			Logging.xmlError(configXml, "Invalid skeleton index %q given at %q. Unable to find node", skeletonIndex, key .. ".assets#skeletonIndex")

		else

			local skinNode = getChildAt(skeletonNode, 0)
			local animationSet = getAnimCharacterSet(skinNode)

            if animationSet ~= 0 then

                local modelI3D = loadI3DFile(Utils.getFilename(configXml:getString(key .. ".assets#filename"), directory), false, false, false)
                local modelSkeletonNode = I3DUtil.indexToObject(modelI3D, skeletonIndex)
                local modelSkinNode = getChildAt(modelSkeletonNode, 0)

                cloneAnimCharacterSet(skinNode, modelSkinNode)
                setVisibility(modelI3D, false)

                local numTilesU = configXml:getInt(key .. ".assets.texture(0)#numTilesU", 1)
                local numTilesV = configXml:getInt(key .. ".assets.texture(0)#numTilesV", 1)
			
                local modelAnimationSet = getAnimCharacterSet(modelSkinNode)

                if modelAnimationSet ~= 0 then

                    local cache = {
                        ["root"] = modelI3D,
                        ["shader"] = shaderIndex,
                        ["mesh"] = meshIndex,
                        ["skeleton"] = skeletonIndex,
                        ["tiles"] = {
                            ["x"] = 1 / numTilesU,
                            ["y"] = 1 / numTilesV
                        },
                        ["animation"] = {}
                    }

                    local locomotionFilename = Utils.getFilename(configXml:getString(key .. ".locomotion#filename"), directory)
                    local locomotionXML = locomotionXMLs[locomotionFilename]
                    
                    if locomotionXML == nil then
                        locomotionXML = XMLFile.load(string.format("locomotionXML_%s_%s", animalType.groupTitle, visualAnimalIndex), locomotionFilename)
                        locomotionXMLs[locomotionFilename] = locomotionXML
                    end

					local animationFilename = Utils.getFilename(locomotionXML:getString("locomotion.animation#filename"), directory)


                    local animationXML = animationXMLs[animationFilename]

                    if animationXML == nil then
                        animationXML = XMLFile.load(string.format("animationXML_%s_%s", animalType.groupTitle, visualAnimalIndex), animationFilename)
                        animationXMLs[animationFilename] = animationXML
                    end

                    local animation
                    
                    if animationCache[animationFilename] == nil then
                        animation = self:loadAnimations(animationXML, modelAnimationSet)
                        animationCache[animationFilename] = animation
                    else
                        animation = self:cacheAnimationsFromExisting(animationCache[animationFilename], modelAnimationSet)
                    end

                    cache.animation = animation
                    animalType.cache[visualAnimalIndex] = cache

                end

            end

		end

        if visualAnimalIndex == numVisualAnimalIndexes then

            --g_asyncTaskManager:addTask(function()

                --print("finished")

                --configXml:delete()

                --local filesToDelete = {}

                --for _, xml in pairs(locomotionXMLs) do table.insert(filesToDelete, xml) end
                --for _, xml in pairs(animationXMLs) do table.insert(filesToDelete, xml) end
                --for _, i3d in pairs(animationI3Ds) do table.insert(filesToDelete, i3d) end

                --for i, file in pairs(filesToDelete) do

                    --print(i .. " = " .. type(file))
                    --print(file, "-")
                --end

                --local numFilesToDelete = #filesToDelete
                --print(numFilesToDelete)

                --for i = numFilesToDelete, 1, -1 do
    
                    --local file = filesToDelete[i]
        
                    --if type(file) == "number" then
                        --print(file)
                        --delete(file)
                    --else
                        --print(file)
                        --file:delete()
                    --end

                --end

                --print(string.format("AnimalHerding: deleted %d temp cache files", numFilesToDelete))

            --end)

        end

    end

                configXml:delete()

end


function AnimalSystem:cacheAnimationsFromExisting(cache, animationSet)

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


function AnimalSystem:loadAnimations(xmlFile, animationSet)

    local cache = {
        ["states"] = {},
        ["tracks"] = {},
        ["clips"] = {}
    }

    if animationSet == 0 then return cache end

    local clipTypes = {
        "clip",
        "clipLeft",
        "clipRight"
    }

    local nextTrackId = 0

    xmlFile:iterate("animation.states.state", function(_, key)
    
        local stateId = xmlFile:getString(key .. "#id")
        local animations = {}

        xmlFile:iterate(key .. ".animation", function(_, animKey)
        
            local animation = {
                ["id"] = xmlFile:getString(animKey .. "#id"),
                ["transitions"] = {}
            }
            
            for _, clipType in pairs(clipTypes) do

                local clipKey = string.format("%s#%s", animKey, clipType)

                if xmlFile:hasProperty(clipKey) then

                    local clipName = xmlFile:getString(clipKey)
                    local clipIndex = getAnimClipIndex(animationSet, clipName)

                    if clipIndex ~= nil then

                        assignAnimTrackClip(animationSet, nextTrackId, clipIndex)

                        animation[clipType] = {
                            ["name"] = clipName,
                            ["index"] = clipIndex,
                            ["track"] = nextTrackId
                        }

                        cache.tracks[nextTrackId] = {
                            ["id"] = animation.id,
                            ["type"] = clipType,
                            ["name"] = clipName
                        }

                        nextTrackId = nextTrackId + 1

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
        local tracks = {}

        --print(string.format("idFrom = %s, idTo = %s, blendTime = %d, targetTime = %d, clip = %s", idFrom, idTo, blendTime, targetTime, clip or "n/a"))

        if clip ~= nil then

            if cache.clips[clip] == nil then

                local clipIndex = getAnimClipIndex(animationSet, clip)
                assignAnimTrackClip(animationSet, nextTrackId, clipIndex)

                cache.clips[clip] = {
                    ["name"] = clip,
                    ["index"] = clipIndex,
                    ["track"] = nextTrackId
                }

                cache.tracks[nextTrackId] = {
                    ["id"] = idFrom,
                    ["type"] = "clip",
                    ["name"] = clip
                }

                nextTrackId = nextTrackId + 1

            end

            tracks = { cache.clips[clip].track }

        else

             for _, state in pairs(cache.states) do

                if state[idTo] == nil then continue end

                local animation = state[idTo]

                if animation.clipLeft ~= nil then table.insert(tracks, animation.clipLeft.track) end
                if animation.clipRight ~= nil then table.insert(tracks, animation.clipRight.track) end
                if animation.clip ~= nil then table.insert(tracks, animation.clip.track) end

             end

        end

        if #tracks > 0 then

            for _, state in pairs(cache.states) do

                if state[idFrom] == nil then continue end

                state[idFrom].transitions[idTo] = {
                    ["blendTime"] = blendTime,
                    ["targetTime"] = targetTime,
                    ["tracks"] = tracks
                }

            end

        end
    
    end)

    return cache

end


function AH_AnimalSystem:loadAnimalConfig(superFunc, animalType, directory, configFilename, ...)

    local returnValue = superFunc(self, animalType, directory, configFilename, ...)

    animalType.cache = {}

    if not returnValue then return false end

    g_animalManager:addAnimalTypeToCache(animalType)

    --self:addAnimalTypeToCache(animalType, directory)

    --print(string.format("AnimalHerding: cached animal type \'%s\'", animalType.groupTitle))

    --for visualAnimalIndex, config in pairs(animalType.cache) do
        --print(string.format("| ----- %s = %s", visualAnimalIndex, config.root))
    --end

    return true

end