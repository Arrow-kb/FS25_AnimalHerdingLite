function Animal:getCanBePickedUp()

	local animalTypeIndex = self:getAnimalTypeIndex()
	
	if animalTypeIndex == AnimalType.HORSE then return false end
	if animalTypeIndex == AnimalType.CHICKEN then return true end

	if self.weight > 60 then return false end

	if animalTypeIndex == AnimalType.COW then return self.age < 12 end
	if animalTypeIndex == AnimalType.PIG then return self.age < 6 end
	if animalTypeIndex == AnimalType.SHEEP then return self.age < 8 end

	return true

end