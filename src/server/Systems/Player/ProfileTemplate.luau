local ProfileSchema = require(script.Parent:WaitForChild("ProfileSchema"))

local ProfileTemplate = {}

ProfileTemplate.DATA_VERSION = ProfileSchema.CURRENT_VERSION

function ProfileTemplate.create(nowUnix)
	return ProfileSchema.createTemplate(nowUnix)
end

function ProfileTemplate.migrateBeforeReconcile(savedData, nowUnix)
	return ProfileSchema.migrateBeforeReconcile(savedData, nowUnix)
end

function ProfileTemplate.applyPreReconcileMigration(savedData, migratedData)
	ProfileSchema.applyPreReconcileMigration(savedData, migratedData)
end

function ProfileTemplate.createRuntimeProfile(savedData, nowUnix)
	return ProfileSchema.createRuntimeProfile(savedData, nowUnix)
end

function ProfileTemplate.overlayDurable(savedData, runtimeProfile, nowUnix)
	return ProfileSchema.overlayDurable(savedData, runtimeProfile, nowUnix)
end

function ProfileTemplate.applyNormalizedDurable(runtimeProfile, normalizedData)
	ProfileSchema.applyNormalizedDurable(runtimeProfile, normalizedData)
end

return ProfileTemplate
