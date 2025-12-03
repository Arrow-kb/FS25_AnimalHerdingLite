local modName = g_currentModName


PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(PlayerInputComponent.registerGlobalPlayerActionEvents, function(self)

    local _, eventId = g_inputBinding:registerActionEvent(InputAction.HerdingLite, AnimalManager, AnimalManager.onToggleHerding, false, true, false, true, nil, true)

    g_animalManager.herdingEventId = eventId
    g_animalManager.herdingStartText = g_i18n:getText("ahl_startHerding")
    g_animalManager.herdingStopText = g_i18n:getText("ahl_stopHerding")
    g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_HIGH)
	g_inputBinding:setActionEventText(eventId, g_animalManager.herdingEnabled and g_animalManager.herdingStopText or g_animalManager.herdingStartText)
    g_inputBinding:setActionEventActive(eventId, true)

end)


PlayerInputComponent.update = Utils.appendedFunction(PlayerInputComponent.update, function(self)

    self.animalPickup = nil

    if not self.player.isOwner or g_inputBinding:getContextName() ~= PlayerInputComponent.INPUT_CONTEXT_NAME or self.player:getIsCarryingAnimal() or not g_currentMission:getIsServer() or g_server.netIsRunning then return end

    local accessHandler, vehicleInRange = g_currentMission.accessHandler, g_currentMission.interactiveVehicleInRange
    local canAccess

    if vehicleInRange == nil then
        canAccess = false
    else
        canAccess = accessHandler:canPlayerAccess(vehicleInRange, self.player)
    end

    local closestNode = self.player.targeter:getClosestTargetedNodeFromType(PlayerInputComponent)
    self.player.hudUpdater:setCurrentRaycastTarget(closestNode)

    if not canAccess and closestNode ~= nil then

        local husbandryId, animalId = getAnimalFromCollisionNode(closestNode)

        if husbandryId ~= nil and husbandryId ~= 0 then

            local clusterHusbandry = g_currentMission.husbandrySystem:getClusterHusbandryById(husbandryId)

            if clusterHusbandry ~= nil then

                local placeable = clusterHusbandry:getPlaceable()
                local animal = clusterHusbandry:getClusterByAnimalId(animalId, husbandryId)

                if animal ~= nil and accessHandler:canFarmAccess(self.player.farmId, placeable) and animal.getCanBePickedUp ~= nil and animal:getCanBePickedUp() then

                    self.animalPickup = {
                        ["herding"] = false,
                        ["husbandryId"] = husbandryId,
                        ["animalId"] = animalId
                    }

                    g_inputBinding:setActionEventText(self.enterActionId, g_i18n:getText("ahl_pickupAnimal"))
                    g_inputBinding:setActionEventActive(self.enterActionId, true)

                end

            end

        else

            local animal = g_animalManager:getAnimalFromCollisionNode(closestNode, self.player.farmId)

            if animal ~= nil and animal.cluster.getCanBePickedUp ~= nil and animal.cluster:getCanBePickedUp() then

                self.animalPickup = {
                    ["herding"] = true,
                    ["node"] = closestNode
                }

                g_inputBinding:setActionEventText(self.enterActionId, g_i18n:getText("ahl_pickupAnimal"))
                g_inputBinding:setActionEventActive(self.enterActionId, true)

            end

        end

    end

end)


PlayerInputComponent.onInputEnter = Utils.appendedFunction(PlayerInputComponent.onInputEnter, function(self)

    if g_time <= g_currentMission.lastInteractionTime + 200 or g_currentMission.interactiveVehicleInRange ~= nil or self.rideablePlaceable ~= nil or self.animalPickup == nil then return end

    local handToolType = g_handToolTypeManager:getTypeByName(modName .. ".animal")
    local handTool = _G[handToolType.className].new(g_currentMission:getIsServer(), g_currentMission:getIsClient())

    handTool:setType(handToolType)
    handTool:setLoadCallback(self.onFinishedLoadAnimalPickup, self, { ["animal"] = self.animalPickup })
    handTool:loadNonStoreItemAHL({ ["ownerFarmId"] = g_localPlayer.farmId, ["isRegistered"] = false, ["holder"] = g_localPlayer }, AHLHandTools.xmlPaths.animal)

end)


function PlayerInputComponent:onFinishedLoadAnimalPickup(handTool, loadingState, args)

    if loadingState == HandToolLoadingState.OK then

        local success = false

        if args.animal.herding then
            success = handTool:setHerdingAnimal(args.animal.node, self.player.farmId)
        else
            success = handTool:setEngineAnimal(args.animal.husbandryId, args.animal.animalId)
        end

        if success then
            self.player:setCurrentHandTool(handTool)
        elseif g_currentMission:getIsServer() then
            g_currentMission.handToolSystem:markHandToolForDeletion(handTool)
        end

    end

end