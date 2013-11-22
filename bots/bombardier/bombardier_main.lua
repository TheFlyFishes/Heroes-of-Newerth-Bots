
local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic 		= true
object.bRunBehaviors	= true
object.bUpdates 		= true
object.bUseShop 		= true

object.bRunCommands 	= true
object.bMoveCommands 	= true
object.bAttackCommands 	= true
object.bAbilityCommands = true
object.bOtherCommands 	= true

object.bReportBehavior = false
object.bDebugUtility = false
object.bDebugExecute = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core 		= {}
object.eventsLib 	= {}
object.metadata 	= {}
object.behaviorLib 	= {}
object.skills 		= {}

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading bomb_main.lua...')

object.heroName = 'Hero_Bombardier'

object.tSkills = {
    2, 1, 2, 0, 0,
    3, 0, 0, 1, 1, 
    3, 1, 2, 2, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()

-- takes care at load/reload, <name_#> to be replaced by some convinient name.
    local unitSelf = self.core.unitSelf
    if  skills.abilStickyBomb == nil then
        skills.abilStickyBomb = unitSelf:GetAbility(0)
        skills.abilBombardment = unitSelf:GetAbility(1)
        skills.abilDust = core.WrapInTable(unitSelf:GetAbility(2))
        skills.abilDust.nLastCastTime = 0
        skills.abilAirStrike = unitSelf:GetAbility(3)
        skills.abilAttributeBoost = unitSelf:GetAbility(4)
    end
    if unitSelf:GetAbilityPointsAvailable() <= 0 then
        return
    end
    
   
    local nlev = unitSelf:GetLevel()
    local nlevpts = unitSelf:GetAbilityPointsAvailable()
    for i = nlev, nlev+nlevpts do
        unitSelf:GetAbility( object.tSkills[i] ):LevelUp()
    end
end


---------------------------------------------------
--                    Items                      --
---------------------------------------------------
behaviorLib.StartingItems = {"Item_PretendersCrown", "Item_PretendersCrown", "Item_MinorTotem", "Item_ManaPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_EnhancedMarchers", "Item_GraveLocket", "Item_Weapon1"} --ManaRegen3 is Ring of the Teacher
behaviorLib.MidItems =  {"Item_SpellShards", "Item_Lightbrand", "Item_Intelligence7"} --Intelligence7 is Staff of the Master
behaviorLib.LateItems = {"Item_Morph", "Item_BehemothsHeart", "Item_GrimoireOfPower"} --Morph is Sheepstick.

---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

----------------------------------
--	Hero specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nStickyBombUp = 10
object.nBombardmentUp = 15
object.nDustUp = 5
object.nAirStrikeUp = 35
object.nSheepstickUp = 20

object.abilQUse = 20
object.abilWUse = 20
object.abilEUse = 0
object.abilRUse = 45
object.nSheepstickUse = 0

local function AbilitiesUpUtility(hero)
	local nUtility = 0
	
	if skills.abilStickyBomb:CanActivate() then
		nUtility = nUtility + object.nStickyBombUp
	end
	
	if skills.abilBombardment:CanActivate() then
		nUtility = nUtility + object.nBombardmentUp
	end
	
	if skills.abilDust:CanActivate() then
		nUtility = nUtility + object.nDustUp
	end
	
	if skills.abilAirStrike:CanActivate() then
		nUtility = nUtility + object.nAirStrikeUp
	end
	
	if object.itemSheepstick and object.itemSheepstick:CanActivate() then
		nUtility = nUtility + object.nSheepstickUp
	end
	return nUtility
end

--Hero ability use gives bonus to harass util for a while
object.abilEUseTime = 0
object.abilWUseTime = 0

--for ability que
object.UseQ = false
object.UseR = false
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local bDebugEchos = false
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if bDebugEchos then BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName) end
		if EventData.InflictorName == "Ability_Bombardier1" then
			nAddBonus = nAddBonus + object.abilQUse
		elseif EventData.InflictorName == "Ability_Bombardier2" then
			nAddBonus = nAddBonus + object.abilWUse
			object.abilWUseTime = EventData.TimeStamp
		elseif EventData.InflictorName == "Ability_Bombardier3" then
			nAddBonus = nAddBonus + object.abilEUse
			object.abilEUseTime = EventData.TimeStamp
		elseif EventData.InflictorName == "Ability_Bombardier4" then
			nAddBonus = nAddBonus + object.abilRUse
		end
	elseif EventData.Type == "Item" then
		if core.itemSheepstick ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemSheepstick:GetName() then
			nAddBonus = nAddBonus + self.nSheepstickUse
		end
	end
	
	if nAddBonus > 0 then
		--decay before we add
		core.DecayBonus(self)
	
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

--Util calc override
local function CustomHarassUtilityFnOverride(hero)
	local nUtility = AbilitiesUpUtility(hero)
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

----------------------------------
--           Fights             --
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local target = behaviorLib.heroTarget
	if target == nil then
		return false --Eh nothing here
	end
	
	--fetch some variables 
	local self = core.unitSelf
	local selfPosition = self:GetPosition()
	
	local attackRange = core.GetAbsoluteAttackRangeToUnit(self, target)
	
	local bCantDodge = target:IsStunned() or target:IsImmobilized() or target:GetMoveSpeed() < 160
	local bCanSee = core.CanSeeUnit(botBrain, target)
	
	local targetPosition = target:GetPosition()
	local nDistanceSQ = Vector3.Distance2DSq(selfPosition, targetPosition)
	
	local nAggroValue = behaviorLib.lastHarassUtil
	local bActionTaken = false

	local Qup = skills.abilStickyBomb:CanActivate()
	local Wup = skills.abilBombardment:CanActivate()
	local Eup = skills.abilDust:CanActivate()
	local Rup = skills.abilAirStrike:CanActivate()

	local targetHealt = target:GetHealth()
	
	if object.useQ then
		if canSee then
			bActionTaken = core.OrderAbilityPosition(botBrain, skills.abilStickyBomb, targetPosition)
		end
		object.useQ = false
	end
	
	if not bActionTaken then
		if object.useR then
			if bCanSee then
				--Todo some math based targets runing direction
				botBrain:OrderAbilityVector(skills.abilAirStrike, Vector3.Create(targetPosition.x - 100, targetPosition.y - 100), targetPosition)
				actionTaken = true
			end
			object.useR = false
		end
	end

	if not bActionTaken and bCantDodge then
		if Qup then --No questions just do it
			if distance < skills.abilStickyBomb:GetRange() then
				bActionTaken = core.OrderAbilityPosition(botBrain, skills.abilStickyBomb, targetPosition)
			end
		end
	end

	if not actionTaken then
		if (nAggroValue < 35 and nAggroValue > 20) or (nAggroValue > 20 and self:GetLevel() < 6) then
			if Qup and Wup then
				if distance < skills.abilStickyBomb:GetRange() and distance < skills.abilBombardment:GetRange() then
					actionTaken = core.OrderAbilityPosition(botBrain, skills.abilBombardment, targetPosition, true)
					object.useQ = false
				end
			end
		end
	end
	
	--Todo: MANA
	if not actionTaken then
		if Qup and Wup and Rup then
			if nDistanceSQ < skills.abilStickyBomb:GetRange() ^ 2 and nDistanceSQ < skills.abilBombardment:GetRange() ^ 2 then
				actionTaken = core.OrderAbilityPosition(botBrain, skills.abilBombardment, targetPosition, true)
				object.useQ = true
				object.useR = true
			end
		end
	end

	if not bActionTaken and Eup then
		local nTime = HoN.GetGameTime()
		if skills.abilDust.nLastCastTime + 1000 < nTime then --Dont spam all charges at once
			if nDistanceSQ < skills.abilDust:GetRange() ^ 2 then
				bActionTaken = core.OrderAbilityEntity(botBrain, skills.abilDust, target)
				if bActionTaken then
					skills.abilDust.nLastCastTime = nTime
				end
				core.OrderAttack(botBrain, self, target, true)
			end
		end
	end
	
	if not actionTaken then
		return object.harassExecuteOld(botBrain)
	end
end

object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

--Run away. Run away
local function RetreatFromThreatExecuteOverride(botBrain)
	local bActionTaken = false
	local heroes = HoN.GetUnitsInRadius(core.unitSelf:GetPosition(), 800, core.UNIT_MASK_ALIVE + core.UNIT_MASK_HERO)
	enemyHeroes = {}
	for i, hero in ipairs(heroes) do
		if hero:GetTeam() ~= core.unitSelf:GetTeam() then
			table.insert(enemyHeroes, hero)
		end
	end

	if #enemyHeroes > 0 then
		--Todo if multiple do some math
		bActionTaken = core.OrderAbilityPosition(botBrain, skills.abilBombardment, enemyHeroes[1].GetPosition())
	end

	if not bActionTaken then
		object.RetreatFromThreatExecuteOld(botBrain)
	end
end

object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatBehavior["Execute"]
behaviorLib.RetreatFromThreatBehavior["Execute"] = RetreatFromThreatExecuteOverride


BotEcho('finished loading bomb_main.lua')
