local min = math.min
local type = type
local strfind = strfind
local tonumber = tonumber
local tostring = tostring
local GetItemInfo = GetItemInfo
local floor = floor
local format = format

-- ==========================================
-- 12.0 API 适配（仅 C_Container 命名空间存在）
-- ==========================================
local C_Container = C_Container

-- 背包API（10.0+ 在 C_Container 下）
local GetContainerItemLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
local GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local UseContainerItem = C_Container and C_Container.UseContainerItem or UseContainerItem

-- 获取背包物品ID（C_Container.GetContainerItemID 可能不存在，用 GetContainerItemInfo 替代）
local GetContainerItemID = function(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return info and info.itemID
    end
    return GetContainerItemID and GetContainerItemID(bag, slot)
end

-- 获取背包物品信息（结构体转多返回值）
local GetContainerItemInfo = function(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            return info.iconFileID, info.stackCount, info.isLocked, info.quality, info.isReadable, info.hasLoot, info.hyperlink, info.isFiltered, info.hasNoValue, info.itemID
        end
        return nil
    else
        return GetContainerItemInfo(bag, slot)
    end
end

-- ==========================================
-- 12.0 商人API适配（关键修复：先缓存全局函数）
-- ==========================================
-- 先保存原始全局函数引用（避免被局部变量覆盖）
local _GetMerchantItemInfo = GetMerchantItemInfo
local _GetMerchantItemLink = GetMerchantItemLink
local _GetMerchantNumItems = GetMerchantNumItems
local _GetMerchantItemMaxStack = GetMerchantItemMaxStack
local _BuyMerchantItem = BuyMerchantItem

-- 适配函数：处理12.0结构体返回值
local GetMerchantItemInfo = function(index)
    if not _GetMerchantItemInfo then return nil end
    local info = _GetMerchantItemInfo(index)
    if type(info) == "table" then
        -- 12.0 返回结构体
        local stackCount = info.stackCount or info.quantity or 1
        local numAvailable = info.numAvailable or -1
        return info.name, info.texture, info.price, stackCount, numAvailable, info.isPurchasable, info.isUsable, info.hasExtendedCost
    elseif info then
        -- 旧版多返回值（第一次调用已经返回了第一个值，需要重新获取）
        local name, texture, price, quantity, numAvailable, isPurchasable, isUsable, hasExtendedCost = _GetMerchantItemInfo(index)
        return name, texture, price, quantity, numAvailable, isPurchasable, isUsable, hasExtendedCost
    end
    return nil
end

-- 导出适配后的API
local GetMerchantItemLink = _GetMerchantItemLink
local GetMerchantNumItems = _GetMerchantNumItems
local GetMerchantItemMaxStack = _GetMerchantItemMaxStack
local BuyMerchantItem = _BuyMerchantItem
-- ==========================================

local CanMerchantRepair = CanMerchantRepair
local GetRepairAllCost = GetRepairAllCost
local IsInGuild = IsInGuild
local CanGuildBankRepair = CanGuildBankRepair
local GetGuildBankWithdrawMoney = GetGuildBankWithdrawMoney
local GetGuildBankMoney = GetGuildBankMoney
local RepairAllItems = RepairAllItems
local GetMoney = GetMoney
local pairs = pairs
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local GOLD_AMOUNT_TEXTURE = GOLD_AMOUNT_TEXTURE
local SILVER_AMOUNT_TEXTURE = SILVER_AMOUNT_TEXTURE
local COPPER_AMOUNT_TEXTURE = COPPER_AMOUNT_TEXTURE
local GOLD_AMOUNT = GOLD_AMOUNT
local SILVER_AMOUNT = SILVER_AMOUNT
local COPPER_AMOUNT = COPPER_AMOUNT
local MerchantFrame = MerchantFrame

MerchantEx = {}

local addon = MerchantEx
addon.version = GetAddOnMetadata("MerchantEx", "Version") or "2.0"
addon.db = { option = {}, exception = {}, myexception = {}, buy = {} }
local L = MERCHANTEX_LOCALE

function addon:GetItemId(link)
	if type(link) ~= "string" then return nil end
	local _, _, id = strfind(link, "Hitem:(%d+)")
	return id and tonumber(id)
end

function addon:Print(msg, ...)
    local LNicon = "|TInterface/AddOns/!!!163UI!!!/Textures/UI2-logo-small.blp:20|t"
	if msg then
		DEFAULT_CHAT_FRAME:AddMessage(LNicon .. "|cff19CCF9"..L["title"]..":|r "..tostring(msg), ...)
	end
end

function addon:ParseLink(link)
	local id = self:GetItemId(link)
	if id then
		local name, hl, quality, _, _, _, _, maxStack, _, texture, vendorPrice = GetItemInfo(id)
		if name then
			return id, name, hl, quality or 0, maxStack or 1, texture, vendorPrice or 0
		end
	end
end

local function FormatMoney(money, clientOnly)
	if type(money) ~= "number" or money == 0 then
		return ""
	end

	if money < 0 then
		money = -money
	end

	local copper = money % 100
	local silver = floor(money / 100) % 100
	local gold = floor(money / 10000)

	local gf = clientOnly and GOLD_AMOUNT_TEXTURE or GOLD_AMOUNT
	local sf = clientOnly and SILVER_AMOUNT_TEXTURE or SILVER_AMOUNT
	local cf = clientOnly and COPPER_AMOUNT_TEXTURE or COPPER_AMOUNT

	local str
	if gold > 0 then
		str = format(gf, gold, 0, 0)
	end

	if silver > 0 then
		if str then
			str = str.." "..format(sf, silver, 0, 0)
		else
			str = format(sf, silver, 0, 0)
		end
	end

	if copper > 0 then
		if str then
			str = str.." "..format(cf, copper, 0, 0)
		else
			str = format(cf, copper, 0, 0)
		end
	end

	return str
end

local function CheckAndSellItem(bag, slot)
	local id, name, link, quality, _, _, vendorPrice = addon:ParseLink(GetContainerItemLink(bag, slot))
	if not id or vendorPrice < 1 then
		return
	end

	local isException = addon.db.exception[id] or addon.db.myexception[id]
    if addon.db.option.keep910 and quality == 0 then
        local keep910ids = {
            [11406] = 1,
            [11944] = 1,
            [25402] = 1,
            [3300] = 1,
            [3670] = 1,
            [6150] = 1,
            [36812] = 1,
            [62072] = 1,
            [67410] = 1,
        }
        isException = isException or keep910ids[id]
    end

	if (quality == 0 and not isException) or ((quality == 1 or quality == 3) and isException) then
		local _, count = GetContainerItemInfo(bag, slot)
        if not count then count = 1 end
		vendorPrice = vendorPrice * count
		UseContainerItem(bag, slot)
		return vendorPrice, link, count
	end
end

function addon:SellTrash(silent)
	if not MerchantFrame:IsVisible() then
		return 0
	end

	local total = 0
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local sold, link, count = CheckAndSellItem(bag, slot)
			if sold then
				total = total + sold
				if not silent and self.db.option.details then
					local details = L["sold"]..link
					if count > 1 then
						details = details.." x"..count
					end
					self:Print(details)
				end
			end
		end
	end

	if not silent and total > 0 then
		self:Print(L["sold trash"]..FormatMoney(total, 1))
	end

	return total
end

function addon:RepairItems(silent)
	if not MerchantFrame:IsVisible() or not CanMerchantRepair() then
		return 0
	end

	local cost = GetRepairAllCost()
	if cost <= 0 then
		return 0
	end

	if self.db.option.guild and IsInGuild() and CanGuildBankRepair() then
		if GetGuildBankWithdrawMoney() >= cost then
			RepairAllItems(1)
            RepairAllItems()
			if not silent then
				self:Print(L["repaired items by using guild bank"]..FormatMoney(cost, 1))
			end
			return cost
		elseif not silent then
			self:Print(L["guild bank cannot afford repair, will use your own money"])
		end
	end

	if GetMoney() >= cost then
		RepairAllItems()
		if not silent then
			self:Print(L["repaired items"]..FormatMoney(cost, 1))
		end
		return cost
	else
		if not silent then
			self:Print(L["repair cannot afford"])
		end
		return 0
	end
end

-- 统计背包物品数量（使用新API）
local function GetContainerItemCount(itemID)
	local count = 0
	for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots then
		    for slot = 1, numSlots do
                local slotItemID, slotCount
                if C_Container and C_Container.GetContainerItemInfo then
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    if info then
                        slotItemID = info.itemID
                        slotCount = info.stackCount or 0
                    end
                else
                    slotItemID = GetContainerItemID(bag, slot)
                    local _, itemCount = GetContainerItemInfo(bag, slot)
                    slotCount = itemCount or 0
                end
                
			    if slotItemID and slotItemID == itemID then
				    count = count + slotCount
			    end
		    end
        end
	end
	return count
end

-- 查找商人商品（修复版）
local function FindMerchatItem(targetID)
    if not targetID then return nil end
    
	for i = 1, GetMerchantNumItems() do
		local link = GetMerchantItemLink(i)
        local name, texture, price, stackCount, numAvailable = GetMerchantItemInfo(i)
        
        local itemID = link and addon:GetItemId(link)
        
		if itemID and itemID == targetID then
            -- 确保stackCount有效（12.0关键修复）
            if not stackCount or stackCount < 1 then
                stackCount = 1
            end
            if not price then price = 0 end
			return i, link, stackCount, price, numAvailable
		end
	end
    return nil
end

local function BuyItem(id, qty)
    if not id or not qty or qty < 1 then return 0 end
    
	local needed = qty - GetContainerItemCount(id)
	if needed < 1 then return 0 end

	local idx, link, size, price, maxNum = FindMerchatItem(id)
	if not idx then return 0 end
    
    if not size or size < 1 then size = 1 end
    if not price then price = 0 end
    
    if maxNum == 0 then return 0 end
    if maxNum and maxNum ~= -1 then
        needed = min(needed, maxNum)
    end

    local stacksize = GetMerchantItemMaxStack(idx) or size
    if stacksize < 1 then stacksize = 1 end

    local loops = floor(needed / stacksize)
    local leftovers = needed % stacksize
    local unitprice = price / size

    if loops > 0 then
        for i = 1, loops do
            BuyMerchantItem(idx, stacksize)
        end
    end
    if leftovers > 0 then
        BuyMerchantItem(idx, leftovers)
    end

    return unitprice * needed
end

function addon:BuyReagents(silent)
	if not MerchantFrame:IsVisible() then return 0 end

	local cost = 0
	for id, qty in pairs(self.db.buy) do
        local numId = tonumber(id)
        local numQty = tonumber(qty)
        if numId and numQty and numQty > 0 then
		    cost = cost + BuyItem(numId, numQty)
        end
	end

	if not silent and cost > 0 then
		self:Print(L["refilled items"]..FormatMoney(cost, 1))
	end
	return cost
end

function addon:Interact(silent)
	if not MerchantFrame:IsVisible() then return end

	local balance = 0
	if self.db.option.sell then
		balance = balance + self:SellTrash(silent)
	end
	if self.db.option.repair then
		balance = balance - self:RepairItems(silent)
	end
	if self.db.option.buy then
		balance = balance - self:BuyReagents(silent)
	end
	return balance
end

function addon:Final(total, balance)
    if total == 0 then
        self:Print(L["equal final"])
    elseif total > 0 then
        self:Print(L["earned final"]..FormatMoney(total, 1))
    else
        self:Print(L["lost final"]..FormatMoney(total, 1))
    end
end