local StoryRegistry = {}

local stories = {
	{
		Id = "component-gallery",
		Label = "Component Gallery",
		Description = "Neutral tokens, controls, cards, and modal anatomy.",
		Module = "ComponentGallery",
	},
}

function StoryRegistry.all()
	return stories
end

function StoryRegistry.get(id)
	for _, story in stories do
		if story.Id == id then
			return story
		end
	end
	return stories[1]
end

return StoryRegistry
