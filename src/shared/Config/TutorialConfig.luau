local TutorialConfig = {}

TutorialConfig.StepIds = {
	Intro = "intro",
	FirstRoll = "first_roll",
	FirstStoneUpgrade = "first_stone_upgrade",
	FirstRebirth = "first_rebirth",
}

TutorialConfig.CompletionModes = {
	Complete = "complete",
	Skip = "skip",
}

TutorialConfig.StepOrder = {
	TutorialConfig.StepIds.Intro,
	TutorialConfig.StepIds.FirstRoll,
	TutorialConfig.StepIds.FirstStoneUpgrade,
	TutorialConfig.StepIds.FirstRebirth,
}

TutorialConfig.Steps = {
	[TutorialConfig.StepIds.Intro] = {
		DisplayName = "Intro",
		CompletionSource = "Client",
	},
	[TutorialConfig.StepIds.FirstRoll] = {
		DisplayName = "Roll your first pet",
		CompletionSource = "Server",
	},
	[TutorialConfig.StepIds.FirstStoneUpgrade] = {
		DisplayName = "Buy your first Ritual Stone upgrade",
		CompletionSource = "Server",
	},
	[TutorialConfig.StepIds.FirstRebirth] = {
		DisplayName = "Complete your first rebirth",
		CompletionSource = "Server",
	},
}

local stepIndexes = {}

for index, stepId in ipairs(TutorialConfig.StepOrder) do
	stepIndexes[stepId] = index
end

function TutorialConfig.getStep(stepId)
	return TutorialConfig.Steps[stepId]
end

function TutorialConfig.isStepId(stepId)
	return TutorialConfig.Steps[stepId] ~= nil
end

function TutorialConfig.getStepIndex(stepId)
	return stepIndexes[stepId]
end

function TutorialConfig.isClientCompletable(stepId)
	local step = TutorialConfig.getStep(stepId)

	return step ~= nil and step.CompletionSource == "Client"
end

function TutorialConfig.isSkippable(stepId)
	local step = TutorialConfig.getStep(stepId)

	return step ~= nil and step.CanSkip ~= false
end

function TutorialConfig.getCompletedStepIds(completedSteps)
	local stepIds = {}

	for _, stepId in ipairs(TutorialConfig.StepOrder) do
		if completedSteps ~= nil and completedSteps[stepId] == true then
			table.insert(stepIds, stepId)
		end
	end

	return stepIds
end

function TutorialConfig.getNextStepId(completedSteps)
	for _, stepId in ipairs(TutorialConfig.StepOrder) do
		if completedSteps == nil or completedSteps[stepId] ~= true then
			return stepId
		end
	end

	return nil
end

function TutorialConfig.areAllStepsComplete(completedSteps)
	return TutorialConfig.getNextStepId(completedSteps) == nil
end

function TutorialConfig.getStepSnapshots(completedSteps)
	local snapshots = {}

	for _, stepId in ipairs(TutorialConfig.StepOrder) do
		local step = TutorialConfig.Steps[stepId]

		table.insert(snapshots, {
			StepId = stepId,
			DisplayName = step.DisplayName,
			IsComplete = completedSteps ~= nil and completedSteps[stepId] == true,
		})
	end

	return snapshots
end

return TutorialConfig
