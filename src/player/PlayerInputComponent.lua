AH_PlayerInputComponent = {}


function AH_PlayerInputComponent:registerGlobalPlayerActionEvents()

    local _, eventId = g_inputBinding:registerActionEvent(InputAction.HerdingLite, AnimalManager, AnimalManager.onToggleHerding, false, true, false, true, nil, true)

    g_animalManager.herdingEventId = eventId
    g_animalManager.herdingStartText = g_i18n:getText("ahl_startHerding")
    g_animalManager.herdingStopText = g_i18n:getText("ahl_stopHerding")
    g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_HIGH)
	g_inputBinding:setActionEventText(eventId, g_animalManager.herdingEnabled and g_animalManager.herdingStopText or g_animalManager.herdingStartText)
    g_inputBinding:setActionEventActive(eventId, true)

end


PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(PlayerInputComponent.registerGlobalPlayerActionEvents, AH_PlayerInputComponent.registerGlobalPlayerActionEvents)