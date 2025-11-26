AnimalAnimation = {}


local AnimalAnimation_mt = Class(AnimalAnimation)


function AnimalAnimation.new(animal, animationSet, animationCache)

	local self = setmetatable({}, AnimalAnimation_mt)

	self.animal = animal
	self.animationSet = animationSet
	self.cache = animationCache
	self.tracks = {}

	self.currentAnimationTime = 0
	self.targetAnimationTime = 10000

	setAnimTrackLoopState(animationSet, 0, true)
	setAnimTrackLoopState(animationSet, 1, true)
	setAnimTrackLoopState(animationSet, 2, true)
	setAnimTrackLoopState(animationSet, 3, true)

	self.currentAnimationTime = 0

	return self

end


function AnimalAnimation:setDefaultState()

	self.state = {
		["isIdle"] = true,
		["isWalking"] = false,
		["isRunning"] = false,
		["dirY"] = 0,
		["targetDirY"] = 0
	}

end


function AnimalAnimation:setState(state)

	self.state = state

end


function AnimalAnimation:update(dT, isWalkingFromPlayer)

	self.currentAnimationTime = self.currentAnimationTime + dT

	local state = self.state
	local animationSet = self.animationSet

	local dirChange = state.dirY - state.lastDirY
	self.turnDirection = dirChange > 0 and "left" or (dirChange < 0 and "right" or "none")

	if self.transition ~= nil then

		local transition = self.transition
		local targetTime = transition.targetTime
		local blendTime = transition.blendTime

		transition.currentTime = transition.currentTime - dT

		local currentTime = transition.currentTime

		if (currentTime <= targetTime and currentTime < blendTime) or (currentTime >= targetTime and currentTime > blendTime) then
			
			for _, track in pairs(transition.from) do
				disableAnimTrack(animationSet, track.index)
				track.enabled = false
			end
			
			for _, track in pairs(transition.to) do
				track.blend = 1 / #transition.to
				setAnimTrackBlendWeight(animationSet, track.index, track.blend)
				self.tracks[track.index] = table.clone(track, 5)
			end

			local idTo = transition.to[1].id

			if idTo == "walk" then

				self.animal:setIsWalking(true)
				self.animal:setIsIdle(false)
				
			elseif idTo == "idle" then

				self.animal:setIsWalking(false)
				self.animal:setIsTurning(false)
				self.animal:setIsIdle(true)

			end

			self.transition = nil
			self.currentAnimationTime = 0

			return

		end

		local blend = (currentTime - targetTime) / blendTime

		for _, track in pairs(transition.from) do
			track.blend = blend / #transition.from
			setAnimTrackBlendWeight(animationSet, track.index, track.blend)
		end

		for _, track in pairs(transition.to) do
			track.blend = (1 - blend) / #transition.to
			setAnimTrackBlendWeight(animationSet, track.index, track.blend)
		end

		transition.blend = blend

	else

		if self.currentAnimationTime >= self.targetAnimationTime and not isWalkingFromPlayer then
			self.animal:forceNewState()
			state = self.state
			self.currentAnimationTime = 0
			dirChange = state.dirY - state.lastDirY
			self.turnDirection = dirChange > 0 and "left" or (dirChange < 0 and "right" or "none")
		end

		if state.isIdle and state.wasWalking then
				
			state.wasWalking = false
			self:startTransition("walk", "idle", "walk1", "idle1")

		elseif state.isWalking and state.wasIdle then
				
			state.wasIdle = false
			self:startTransition("idle", "walk", "idle1", "walk1")

		elseif state.isRunning and state.wasWalking then
				
			state.wasWalking = false
			self:startTransition("walk", "run", "walk1", "run1")

		elseif state.isIdle then

			local hasTrack = false

			for i, track in pairs(self.tracks) do

				if track.enabled and track.id ~= "idle" then

					disableAnimTrack(animationSet, i)
					track.enabled = false

				elseif track.enabled then

					hasTrack = true

				end

			end

			if not hasTrack then

				local animation = self:getRandomAnimation("idle")

				self.tracks[0] = {
					["id"] = "idle",
					["clip"] = animation.clip,
					["blend"] = 1,
					["enabled"] = true,
					["speed"] = 0
				}

				assignAnimTrackClip(animationSet, 0, animation.clip.index)
				setAnimTrackBlendWeight(animationSet, 0, 1)
				enableAnimTrack(animationSet, 0)
				
				self.currentAnimationTime = 0
				self.targetAnimationTime = self:getTargetAnimationDuration("idle")

			end

		elseif state.isWalking or state.isRunning then

			local targetId = state.isWalking and "walk" or "run"
			if targetId == "run" and self.cache.states.run == nil then targetId = "walk" end
			local hasTrack = false
			local track1, track2

			for i, track in pairs(self.tracks) do

				if track.enabled and track.id ~= targetId then

					disableAnimTrack(animationSet, i)
					track.enabled = false

				elseif track.enabled then

					hasTrack = true

					if track.clip.type == "clipLeft" then track1 = track end
					if track.clip.type == "clipRight" then track2 = track end

				end

			end

			if not hasTrack then

				local animation = self:getRandomAnimation(targetId)

				self.tracks[0] = {
					["id"] = targetId,
					["clip"] = animation.clipLeft,
					["blend"] = 0.5,
					["enabled"] = true,
					["speed"] = animation.speed
				}

				self.tracks[1] = {
					["id"] = targetId,
					["clip"] = animation.clipRight,
					["blend"] = 0.5,
					["enabled"] = true,
					["speed"] = animation.speed
				}

				track1 = self.tracks[0]
				track2 = self.tracks[1]

				assignAnimTrackClip(animationSet, 0, animation.clipLeft.index)
				setAnimTrackBlendWeight(animationSet, 0, 0.5)
				enableAnimTrack(animationSet, 0)

				assignAnimTrackClip(animationSet, 1, animation.clipRight.index)
				setAnimTrackBlendWeight(animationSet, 1, 0.5)
				enableAnimTrack(animationSet, 1)
				
				self.currentAnimationTime = 0
				self.targetAnimationTime = self:getTargetAnimationDuration(targetId)

			end
			
			if self.turnDirection == "left" then

				track1.blend = math.clamp(track1.blend + dT * 0.0005, 0, 1)
				track2.blend = math.clamp(track2.blend - dT * 0.0005, 0, 1)

			elseif self.turnDirection == "right" then

				track1.blend = math.clamp(track1.blend - dT * 0.0005, 0, 1)
				track2.blend = math.clamp(track2.blend + dT * 0.0005, 0, 1)

			else

				if track1.blend < 0.5 then
					track1.blend = math.clamp(track1.blend + dT * 0.0005, 0, 0.5)
				else
					track1.blend = math.clamp(track1.blend - dT * 0.0005, 0.5, 1)
				end

				if track2.blend < 0.5 then
					track2.blend = math.clamp(track2.blend + dT * 0.0005, 0, 0.5)
				else
					track2.blend = math.clamp(track2.blend - dT * 0.0005, 0.5, 1)
				end

			end
			
			setAnimTrackBlendWeight(animationSet, 0, track1.blend)
			setAnimTrackBlendWeight(animationSet, 1, track2.blend)

		end

	end

	state.lastDirY = state.dirY

end


function AnimalAnimation:getRandomAnimation(id)

	local state = self.cache.states[id]
	if state == nil then return nil end
	local numAnimations = 0

	for _, animation in pairs(state) do numAnimations = numAnimations + 1 end

	local randomAnimation = math.random(1, numAnimations)

	local i = 1

	for _, animation in pairs(state) do

		if i == randomAnimation then return animation end

		i = i + 1

	end

	return nil

end


function AnimalAnimation:getMovementSpeed()

	local speed, numTracks = 0, 0

	if self.transition == nil then

		for _, track in pairs(self.tracks) do

			if not track.enabled then continue end

			speed = speed + track.speed * track.blend
			numTracks = numTracks + 1

		end

	else

		local transition = self.transition

		for _, track in pairs(transition.to) do

			if not track.enabled then continue end

			speed = speed + track.speed * track.blend
			numTracks = numTracks + 1

		end

		for _, track in pairs(transition.from) do

			if not track.enabled then continue end

			speed = speed + track.speed * track.blend
			numTracks = numTracks + 1

		end

	end

	if numTracks == 0 then return 0 end

	return math.clamp(speed / numTracks, 0, 2)

end


function AnimalAnimation:startTransition(stateIdFrom, stateIdTo, idFrom, idTo)

	local states = self.cache.states

	if states[stateIdFrom] == nil or states[stateIdTo] == nil then return end

	local animationFrom = states[stateIdFrom][idFrom]
	local animationTo = states[stateIdTo][idTo]

	if animationTo == nil or animationFrom == nil then return end

	local templateTransition = animationFrom.transitions[idTo]

	if templateTransition == nil then
		templateTransition = {
			["targetTime"] = 0,
			["blendTime"] = 1000
		}
	end

	local transition = {
		["targetTime"] = templateTransition.targetTime,
		["blendTime"] = templateTransition.blendTime,
		["currentTime"] = templateTransition.blendTime,
		["from"] = {},
		["to"] = {}
	}
	
	self.targetAnimationTime = self:getTargetAnimationDuration(stateIdTo)


	if animationTo.clipLeft ~= nil then

		table.insert(transition.to, {
			["id"] = stateIdTo,
			["clip"] = animationTo.clipLeft,
			["blend"] = 0,
			["enabled"] = true,
			["speed"] = animationTo.speed
		})

	end

	if animationTo.clipRight ~= nil then

		table.insert(transition.to, {
			["id"] = stateIdTo,
			["clip"] = animationTo.clipRight,
			["blend"] = 0,
			["enabled"] = true,
			["speed"] = animationTo.speed
		})

	end

	if animationTo.clip ~= nil then

		table.insert(transition.to, {
			["id"] = stateIdTo,
			["clip"] = animationTo.clip,
			["blend"] = 0,
			["enabled"] = true,
			["speed"] = animationTo.speed
		})

	end



	if animationFrom.clipLeft ~= nil then

		table.insert(transition.from, {
			["id"] = stateIdFrom,
			["clip"] = animationFrom.clipLeft,
			["blend"] = 0,
			["enabled"] = true,
			["speed"] = animationFrom.speed
		})

	end

	if animationFrom.clipRight ~= nil then

		table.insert(transition.from, {
			["id"] = stateIdFrom,
			["clip"] = animationFrom.clipRight,
			["blend"] = 0,
			["enabled"] = true,
			["speed"] = animationFrom.speed
		})

	end

	if animationFrom.clip ~= nil then

		table.insert(transition.from, {
			["id"] = stateIdFrom,
			["clip"] = animationFrom.clip,
			["blend"] = 0,
			["enabled"] = true,
			["speed"] = animationFrom.speed
		})

	end



	for _, clip in pairs(transition.from) do clip.blend = 1 / #transition.from end



	for i, track in pairs(self.tracks) do

		if track.enabled then
			track.enabled = false
			disableAnimTrack(self.animationSet, i)
		end

	end

	local trackIndex = 0

	for _, track in pairs(transition.from) do

		track.index = trackIndex
		assignAnimTrackClip(self.animationSet, trackIndex, track.clip.index)
		setAnimTrackBlendWeight(self.animationSet, trackIndex, track.blend)
		enableAnimTrack(self.animationSet, trackIndex)

		trackIndex = trackIndex + 1

	end

	for _, track in pairs(transition.to) do

		track.index = trackIndex
		assignAnimTrackClip(self.animationSet, trackIndex, track.clip.index)
		setAnimTrackBlendWeight(self.animationSet, trackIndex, track.blend)
		enableAnimTrack(self.animationSet, trackIndex)

		trackIndex = trackIndex + 1

	end

	self.transition = transition

end


function AnimalAnimation:getTargetAnimationDuration(id)

	if id == "idle" then return math.random(self.cache.idleMin, self.cache.idleMax) end
	if id == "walk" or id == "run" then return math.random(self.cache.wanderMin, self.cache.wanderMax) end

end


function AnimalAnimation:visualise(node, info)

	table.insert(info, { ["title"] = "States", ["content"] = {} })
	local infoIndex = #info

	for state, value in pairs(self.state) do

		table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = state .. " = ", ["value"] = tostring(value) })

	end

	table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "Turning = ", ["value"] = self.turnDirection })

	table.insert(info, { ["title"] = "Animations", ["content"] = {} })
	infoIndex = #info

	for _, track in pairs(self.tracks) do

		if not track.enabled then continue end

		table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "State ID = ", ["value"] = track.id })
		table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "Blend Weight = ", ["value"] = track.blend })
		table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "Clip = ", ["value"] = track.clip.name })

	end

	if self.transition ~= nil then

		table.insert(info, { ["title"] = "Transition", ["content"] = {} })
		infoIndex = #info

		local transition = self.transition

		table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "Blend Time = ", ["value"] = transition.blendTime })
		table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "Target Time = ", ["value"] = transition.targetTime })
		table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "Current Time = ", ["value"] = transition.currentTime })

		for _, clip in pairs(transition.from) do

			table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "Type = ", ["value"] = "FROM" })
			table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "State ID = ", ["value"] = clip.id })
			table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "Blend Weight = ", ["value"] = clip.blend })
			table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "Clip = ", ["value"] = clip.clip.name })

		end

		for _, clip in pairs(transition.to) do
		
			table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "Type = ", ["value"] = "TO" })
			table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "State ID = ", ["value"] = clip.id })
			table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "Blend Weight = ", ["value"] = clip.blend })
			table.insert(info[infoIndex].content, { ["sizeFactor"] = 0.7, ["name"] = "Clip = ", ["value"] = clip.clip.name })

		end

	end

end