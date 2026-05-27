--10.0.0
CursorCanGoInSlot = C_PaperDollInfo.CanCursorCanGoInSlot
C_TradeSkillUI.GetRecipeRepeatCount = function()
	return C_TradeSkillUI.GetRemainingRecasts() + 1;
end;

--10.1.0
TooltipUtil.SurfaceArgs = nop;
GetAddOnMetadata = C_AddOns.GetAddOnMetadata

--10.1.5
GetClassIDFromSpecID = C_SpecializationInfo.GetClassIDFromSpecID

--10.2.0
GetCVarInfo = C_CVar.GetCVarInfo
EnableAddOn = C_AddOns.EnableAddOn
DisableAddOn = C_AddOns.DisableAddOn
GetAddOnEnableState = function(character, name) return C_AddOns.GetAddOnEnableState(name, character); end
LoadAddOn = C_AddOns.LoadAddOn
IsAddOnLoaded = C_AddOns.IsAddOnLoaded
EnableAllAddOns = C_AddOns.EnableAllAddOns
DisableAllAddOns = C_AddOns.DisableAllAddOns
GetAddOnInfo = C_AddOns.GetAddOnInfo
GetAddOnDependencies = C_AddOns.GetAddOnDependencies
GetAddOnOptionalDependencies = C_AddOns.GetAddOnOptionalDependencies
GetNumAddOns = C_AddOns.GetNumAddOns
SaveAddOns = C_AddOns.SaveAddOns
ResetAddOns = C_AddOns.ResetAddOns
ResetDisabledAddOns = C_AddOns.ResetDisabledAddOns
IsAddonVersionCheckEnabled = C_AddOns.IsAddonVersionCheckEnabled
SetAddonVersionCheck = C_AddOns.SetAddonVersionCheck
IsAddOnLoadOnDemand = C_AddOns.IsAddOnLoadOnDemand

--10.2.5
do
	GetTimeToWellRested = function() return nil; end
	FillLocalizedClassList = function(tbl, isFemale)
		local classList = LocalizedClassList(isFemale);
		MergeTable(tbl, classList);
		return tbl;
	end
	GetSetBonusesForSpecializationByItemID = C_Item.GetSetBonusesForSpecializationByItemID;
	GetItemStats = function(itemLink, existingTable)
		local statTable = C_Item.GetItemStats(itemLink);
		if existingTable then
			MergeTable(existingTable, statTable);
			return existingTable;
		else
			return statTable;
		end
	end
	GetItemStatDelta = function(itemLink1, itemLink2, existingTable)
		local statTable = C_Item.GetItemStatDelta(itemLink1, itemLink2);
		if existingTable then
			MergeTable(existingTable, statTable);
			return existingTable;
		else
			return statTable;
		end
	end
	UnitAura = function(unitToken, index, filter)
		local auraData = C_UnitAuras.GetAuraDataByIndex(unitToken, index, filter);
		if not auraData then
			return nil;
		end

		return AuraUtil.UnpackAuraData(auraData);
	end
	UnitBuff = function(unitToken, index, filter)
		local auraData = C_UnitAuras.GetBuffDataByIndex(unitToken, index, filter);
		if not auraData then
			return nil;
		end

		return AuraUtil.UnpackAuraData(auraData);
	end
	UnitDebuff = function(unitToken, index, filter)
		local auraData = C_UnitAuras.GetDebuffDataByIndex(unitToken, index, filter);
		if not auraData then
			return nil;
		end

		return AuraUtil.UnpackAuraData(auraData);
	end
	UnitAuraBySlot = function(unitToken, index)
		local auraData = C_UnitAuras.GetAuraDataBySlot(unitToken, index);
		if not auraData then
			return nil;
		end

		return AuraUtil.UnpackAuraData(auraData);
	end
	UnitAuraSlots = C_UnitAuras.GetAuraSlots;
end

--10.2.6
FrameXML_Debug = C_Debug.FrameXMLDebug
GetMawPowerLinkBySpellID = C_Spell.GetMawPowerLinkBySpellID

--10.2.7
do
   -- The following functions have been moved into the C_StableInfo namespace:
   ClosePetStables = C_StableInfo.ClosePetStables;
   GetStablePetInfo = function(...)
      local t = C_StableInfo.GetStablePetInfo(...);
      if t then
         return unpack({t.icon, t.name, t.level, t.familyName, t.specialization});
      end
   end
   PickupStablePet = C_StableInfo.PickupStablePet;
   GetStablePetFoodTypes = function(...)
      local t = C_StableInfo.GetStablePetFoodTypes(...);
      if t then
         return unpack(t);
      end
   end
   IsAtStableMaster = C_StableInfo.IsAtStableMaster;
   SetPetSlot = C_StableInfo.SetPetSlot;

   -- The following functions have been moved into the C_PetInfo namespace:
   PetAbandon = C_PetInfo.PetAbandon;
   PetRename = function(...)
      local name, declensions = ...;
      C_PetInfo.PetRename(name, nil, declensions);
   end 
   PetCanBeRenamed = function()  -- There are no more restrictions on when/how many times a pet can be renamed
      return true;
   end;
end
function TextStatusBar_Initialize(self)
   self:InitializeTextStatusBar();
end

function SetTextStatusBarText(bar, text)
   bar:SetBarText(text);
end

function TextStatusBar_OnEvent(self, event, ...)
   self:TextStatusBarOnEvent(event, ...);
end

function TextStatusBar_UpdateTextString(textStatusBar)
   textStatusBar:UpdateTextString();
end

function TextStatusBar_UpdateTextStringWithValues(statusFrame, textString, value, valueMin, valueMax)
   statusFrame:UpdateTextStringWithValues(textString, value, valueMin, valueMax);
end

function TextStatusBar_OnValueChanged(self)
   self:OnStatusBarValueChanged();
end

function TextStatusBar_OnMinMaxChanged(self, min, max)
   self:OnStatusBarMinMaxChanged(min, max);
end

function SetTextStatusBarTextPrefix(bar, prefix)
   bar:SetBarTextPrefix(prefix);
end

function SetTextStatusBarTextZeroText(bar, zeroText)
   bar:SetBarTextZeroText(zeroText);
end

function ShowTextStatusBarText(bar)
   bar:ShowStatusBarText();
end

function HideTextStatusBarText(bar)
   bar:HideStatusBarText();
end

--11.0.0
do
    MAX_PLAYER_LEVEL = MAX_PLAYER_LEVEL or GetMaxLevelForPlayerExpansion();

	GetSpellInfo = function(spellID)
		if not spellID then
			return nil;
		end

		local spellInfo = C_Spell.GetSpellInfo(spellID);
		if spellInfo then
			return spellInfo.name, nil, spellInfo.iconID, spellInfo.castTime, spellInfo.minRange, spellInfo.maxRange, spellInfo.spellID, spellInfo.originalIconID;
		end
	end

	GetNumSpellTabs = C_SpellBook.GetNumSpellBookSkillLines;

	GetSpellTabInfo = function(index)
		local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(index);
		if skillLineInfo then
			return	skillLineInfo.name, 
					skillLineInfo.iconID, 
					skillLineInfo.itemIndexOffset, 
					skillLineInfo.numSpellBookItems, 
					skillLineInfo.isGuild, 
					skillLineInfo.offSpecID,
					skillLineInfo.shouldHide,
					skillLineInfo.specID;
		end
	end

	GetSpellCooldown = function(spellID)
		local spellCooldownInfo = C_Spell.GetSpellCooldown(spellID);
		if spellCooldownInfo then
			return spellCooldownInfo.startTime, spellCooldownInfo.duration, spellCooldownInfo.isEnabled, spellCooldownInfo.modRate;
		end
	end

	BOOKTYPE_SPELL = "spell";

	GetSpellBookItemName = function(index, bookType)
		local spellBank = (bookType == BOOKTYPE_SPELL) and Enum.SpellBookSpellBank.Player or Enum.SpellBookSpellBank.Pet;
		return C_SpellBook.GetSpellBookItemName(index, spellBank);
	end

	GetSpellTexture = function(spellID)
		return C_Spell.GetSpellTexture(spellID);
	end

	GetSpellCharges = function(spellID)
		local spellChargeInfo = C_Spell.GetSpellCharges(spellID);
		if spellChargeInfo then
			return spellChargeInfo.currentCharges, spellChargeInfo.maxCharges, spellChargeInfo.cooldownStartTime, spellChargeInfo.cooldownDuration, spellChargeInfo.chargeModRate;
		end
	end

	GetSpellDescription = function(spellID)
		return C_Spell.GetSpellDescription(spellID);
	end

	GetSpellCount = function(spellID)
		return C_Spell.GetSpellCastCount(spellID);
	end

	IsUsableSpell = function(spellID)
		return C_Spell.IsSpellUsable(spellID);
	end
end

