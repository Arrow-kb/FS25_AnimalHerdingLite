InGameMenuMapFrame.setMapSelectionItem = Utils.appendedFunction(InGameMenuMapFrame.setMapSelectionItem, function(self, hotspot)

	if hotspot == nil or not hotspot:isa(AnimalHotspot) or hotspot:getWorldPosition() == nil then return end

	local name = hotspot:getName()
	local imageFilename = hotspot:getImageFilename()
	local farmId = hotspot:getOwnerFarmId()
	self.currentHotspot = hotspot

	self:setMapInputContext(false, false, false, true, false, false, false, false, false)
	InGameMenuMapUtil.hideContextBox(self.contextBox)
	InGameMenuMapUtil.showContextBox(self.contextBox, hotspot, name, imageFilename, Overlay.DEFAULT_UVS, farmId, nil, false, false, false)

end)