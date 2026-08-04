local PotionConfig = require(script.Parent:WaitForChild("PotionConfig"))

local RetentionConfig = {}

RetentionConfig.SecondsPerDay = 86_400
RetentionConfig.ActiveTickSeconds = 30
RetentionConfig.MaximumExactInteger = 9_007_199_254_740_991
RetentionConfig.MaximumReadyCount = 64

RetentionConfig.DeedOrder = { "daily_roll_10", "daily_crystal_25", "daily_upgrade_3" }
RetentionConfig.Deeds = {
	 daily_roll_10 = { DeedId = "daily_roll_10", Label = "Roll Ritual Pets", Description = "Complete successful pet rolls online.", EventId = "successful_pet_roll", Requirement = 10, Reward = { RitualGems = 3 } },
	 daily_crystal_25 = { DeedId = "daily_crystal_25", Label = "Break Crystals", Description = "Finalize online crystal breaks.", EventId = "online_crystal_break", Requirement = 25, Reward = { PotionId = PotionConfig.PotionIds.Essence2x15m, Count = 1 } },
	 daily_upgrade_3 = { DeedId = "daily_upgrade_3", Label = "Improve the Core", Description = "Buy Stone or Rune levels.", EventId = "stone_or_rune_upgrade", Requirement = 3, Reward = { RitualGems = 5 } },
}

RetentionConfig.PlaytimeOrder = { "playtime_15m", "playtime_45m", "playtime_90m" }
RetentionConfig.PlaytimeMilestones = {
	playtime_15m = { MilestoneId = "playtime_15m", Label = "First Blessing", Description = "Stay online for fifteen active minutes.", ActiveSeconds = 900, Reward = { RitualGems = 5 } },
	playtime_45m = { MilestoneId = "playtime_45m", Label = "Deep Practice", Description = "Stay online for forty-five active minutes.", ActiveSeconds = 2700, Reward = { PotionId = PotionConfig.PotionIds.RollFlow1_5x15m, Count = 1 } },
	playtime_90m = { MilestoneId = "playtime_90m", Label = "Master's Hour", Description = "Stay online for ninety active minutes.", ActiveSeconds = 5400, Reward = { PotionId = PotionConfig.PotionIds.RuneFlow1_5x15m, Count = 1 } },
}

RetentionConfig.AchievementOrder = {
	"rolls_100", "rolls_1000", "rolls_10000",
	"zones_5", "zones_10", "zones_15",
	"rebirths_1", "rebirths_10", "rebirths_50",
	"ascensions_1", "ascensions_3",
}
RetentionConfig.Achievements = {
	rolls_100 = { AchievementId = "rolls_100", Label = "First Hundred Rolls", Description = "Complete one hundred total rolls.", Family = "Rolls", SourceField = "Rolls", Threshold = 100, Reward = { RitualGems = 5 } },
	rolls_1000 = { AchievementId = "rolls_1000", Label = "A Thousand Rituals", Description = "Complete one thousand total rolls.", Family = "Rolls", SourceField = "Rolls", Threshold = 1000, Reward = { RitualGems = 15 } },
	rolls_10000 = { AchievementId = "rolls_10000", Label = "Ritual Legend", Description = "Complete ten thousand total rolls.", Family = "Rolls", SourceField = "Rolls", Threshold = 10000, Reward = { RitualGems = 30 } },
	zones_5 = { AchievementId = "zones_5", Label = "Five Frontiers", Description = "Unlock five zones.", Family = "Zones", SourceField = "UnlockedZones", Threshold = 5, Reward = { RitualGems = 5 } },
	zones_10 = { AchievementId = "zones_10", Label = "Ten Frontiers", Description = "Unlock ten zones.", Family = "Zones", SourceField = "UnlockedZones", Threshold = 10, Reward = { RitualGems = 10 } },
	zones_15 = { AchievementId = "zones_15", Label = "All Frontiers", Description = "Unlock all fifteen zones.", Family = "Zones", SourceField = "UnlockedZones", Threshold = 15, Reward = { RitualGems = 20 } },
	rebirths_1 = { AchievementId = "rebirths_1", Label = "Reborn", Description = "Complete your first Rebirth.", Family = "Rebirths", SourceField = "Rebirths", Threshold = 1, Reward = { RitualGems = 5 } },
	rebirths_10 = { AchievementId = "rebirths_10", Label = "Cycle Master", Description = "Complete ten Rebirths.", Family = "Rebirths", SourceField = "Rebirths", Threshold = 10, Reward = { RitualGems = 15 } },
	rebirths_50 = { AchievementId = "rebirths_50", Label = "Eternal Cycle", Description = "Complete fifty Rebirths.", Family = "Rebirths", SourceField = "Rebirths", Threshold = 50, Reward = { RitualGems = 30 } },
	ascensions_1 = { AchievementId = "ascensions_1", Label = "First Ascension", Description = "Complete your first Ascension.", Family = "Ascensions", SourceField = "Ascensions", Threshold = 1, Reward = { RitualGems = 10 } },
	ascensions_3 = { AchievementId = "ascensions_3", Label = "Three Ascensions", Description = "Complete three Ascensions.", Family = "Ascensions", SourceField = "Ascensions", Threshold = 3, Reward = { RitualGems = 30 } },
}

return RetentionConfig
