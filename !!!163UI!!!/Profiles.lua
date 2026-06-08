
local _, _NS = ...
local L = _NS.L
U1Profiles = {}
local P = U1Profiles

local format = format
local wipe = wipe
local pairs = pairs


local function copyTable(src, dest)
	if (type(dest) ~= "table") or (src == dest) then dest = {} end
	if type(src) == "table" then
        wipe(dest);
		for k,v in pairs(src) do
			if type(v) == "table" then
				-- try to index the key first so that the metatable creates the defaults, if set, and use that table
				v = copyTable(v, dest[k])
			end
			dest[k] = v
		end
	end
	return dest
end

local function checkNCreate(tbl, key)
    if(not tbl[key]) then
        tbl[key] = {}
    end
    return tbl[key]
end

local function upgradeProfile(prof)
end

local function sortByDate(a, b)
    return a.savedate > b.savedate
end

function P:Initialize()
    U1DBG.profiles = U1DBG.profiles or {}
    checkNCreate(U1DBG, 'profiles')

    self.db = U1DBG.profiles

    checkNCreate(self.db, 'auto')
    checkNCreate(self.db, 'manual')

    for _, k in next, { 'auto', 'manual' } do
        for _,  v in next, self.db[k] do
            upgradeProfile(v)
        end
    end

    P.Initialize = nil
end

function P:Show()
    if(not self.Frame) then
        self.Frame = self:CreateFrame()
    else
        self.Frame:Show()
    end
end

function P:GetProfileByIndex(index ,ptype)
    return self.db[ptype] and self.db[ptype][index]
end

function P:GetProfileByName(name, ptype)
    for index, prof in self:IterateProfiles(ptype) do
        if(prof.name == name) then
            return prof, index
        end
    end
end

function P:GetProfile(name, ptype)
    if(type(name) == 'number') then
        return self:GetProfileByIndex(name, ptype)
    else
        return self:GetProfileByName(name, ptype)
    end
end

function P:IterateProfiles(ptype)
    return next, self.db and self.db[ptype] or _empty_table
end

function P:GetNumProfiles(ptype)
    return self.db and #self.db[ptype]
end

function P:CreateProfile(name, ptype)
    assert(ptype, 'must give a type')
    assert(name, 'must give a name')

    local prof = self:NewProfile()
    prof.name = name
    prof.ptype = ptype
    prof.config = {
        -- defaults ?
        --u1db = true,
    }

    table.insert(self.db[ptype], prof)

    --print('P:CreateProfile returns', prof, #self.db[ptype])
    return prof, #self.db[ptype]
end

function P:NewProfile()
    return {
        --U1DBG = {},
        --time = time(),
    }
end

function P:EditProfileOption(prof, opts)
    for k, v in next, opts do
        prof.config[k] = v
    end
end

function P:RemoveProfile(index, ptype)
    assert(type(index) == 'number', 'index is not numeric.')
    table.remove(self.db[ptype], index or index)
end

function P:SaveProfile(prof)
    if(prof.config.u1dbconfigs) then
        prof.u1dbconfigs = copyTable(U1DB.configs, prof.u1dbconfigs)
        prof.u1dbframes = copyTable(U1DB.frames, prof.u1dbframes)
        prof.u1dbignoreList = copyTable(U1DB.ignoreList, prof.u1dbignoreList)
        prof.u1dbcollectList = copyTable(U1DB.collectList, prof.u1dbcollectList)
    else
        prof.u1dbconfigs = nil
        prof.u1dbframes = nil
        prof.u1dbignoreList = nil
        prof.u1dbcollectList = nil
    end

    if(prof.config.u1dbaddons) then
        prof.u1dbaddons = copyTable(U1DB.addons, prof.u1dbaddons)
    else
        prof.u1dbaddons = nil
    end

    prof.savedate = time()
    prof.class = select(2, UnitClass'player')
    prof.user = UnitName'player'
    prof.realm = GetRealmName()

    table.sort(self.db.auto, sortByDate)
    table.sort(self.db.manual, sortByDate)
end

function P:LoadProfile(prof, opts, revert)
    assert(prof and opts, "[U1Profiles:LoadProfile] usage: prof, opts")

    local backupName = L["Before Load Profile"]
    if prof.name == backupName then
        backupName = backupName .. "-2"
    end
    self:BackupSession(backupName) --如果加载的是"加载之前"的咋办？

    if(opts.u1dbconfigs and prof.u1dbconfigs) then
        U1DB.configs = copyTable(prof.u1dbconfigs, U1DB.configs)
        U1DB.frames = copyTable(prof.u1dbframes, U1DB.frames)
        U1DB.ignoreList = copyTable(prof.u1dbignoreList, U1DB.ignoreList)
        U1DB.collectList = copyTable(prof.u1dbcollectList, U1DB.collectList)
    end

    if(opts.u1dbaddons and prof.u1dbaddons) then
        if revert then
            --100个插件, 关掉其中30, 开70, 选中100个插件的方案, 已经关掉的30个打开, 开启的70个关闭
            local revertProf = {}
            for addon, state in pairs(prof.u1dbaddons) do
                if state == 1 then
                    if U1DB.addons[addon] == 0 then
                        revertProf[addon] = 1 --方案里开启的, 当前未开启, 开启
                    else
                        if addon ~= "!!!163ui!!!" and addon ~= "wowlua" and addon ~= "!warbaby" then
                            revertProf[addon] = 0 --方案里开启的, 当前未开启, 开启
                        end
                    end
                else
                    revertProf[addon] = 0
                end
            end
            --方案里没有的插件不变
            U1DB.addons = copyTable(revertProf, U1DB.addons)
            self:EnableOrDisableAddOn(U1DB.addons)
        else
            U1DB.addons = copyTable(prof.u1dbaddons, U1DB.addons)
        end
        self:EnableOrDisableAddOn(U1DB.addons)
    end
end

function P:EnableOrDisableAddOn(addons)
    if(addons) then
        for k, v in pairs(addons) do
            local origin = C_AddOns.GetAddOnEnableState(k, U1PlayerGuid)>=2
            if v==1 then
                if not origin then U1EnableAddOn(k) end
            else
                if origin then U1DisableAddOn(k) end
            end
        end
    end
end

--[[------------------------------------------------------------
全账号共享插件启停 - 特殊 Profile
sharedProfile 是 manual[1],永远排在第一位,作为"全局通用配置"基线
- 开关打开:EnsureSharedProfile 从当前角色状态填充;ApplySharedToCurrent 应用到当前角色
- 写操作(U1Enable/U1Disable/U1ToggleAddon/saveState):双写到 sharedProfile.u1dbaddons
- 开关关闭:保留 sharedProfile(留作下次开启的基线)
---------------------------------------------------------------]]
function P:GetSharedProfileName()
    return L["Shared Profile"] or "Shared Profile"
end

function P:IsSharedProfile(prof)
    if not prof then return false end
    return prof.name == self:GetSharedProfileName()
end

-- 保证 manual[1] 是 sharedProfile,不存在就创建并填充当前角色状态
function P:EnsureSharedProfile()
    if not self.db then return nil end
    checkNCreate(self.db, 'manual')
    local name = self:GetSharedProfileName()

    -- 查找已存在
    for i = 1, #self.db.manual do
        if self.db.manual[i] and self.db.manual[i].name == name then
            if i ~= 1 then
                local prof = table.remove(self.db.manual, i)
                table.insert(self.db.manual, 1, prof)
            end
            return self.db.manual[1]
        end
    end

    -- 不存在,创建(用当前角色状态填充)
    local prof = self:NewProfile()
    prof.name = name
    prof.ptype = 'manual'
    prof.config = { u1dbaddons = true, u1dbconfigs = false }
    prof.savedate = time()
    if U1DB and U1DB.addons then
        prof.u1dbaddons = copyTable(U1DB.addons, prof.u1dbaddons)
    end
    table.insert(self.db.manual, 1, prof)
    return prof
end

-- 只读获取 sharedProfile:不存在返回 nil(不创建)
-- 用于"读取/检查"场景(例如单次复制按钮判断共享配置是否存在)
-- 不要在需要"创建"语义的场景用 — 那种请用 EnsureSharedProfile
function P:GetSharedProfile()
    if not self.db or not self.db.manual then return nil end
    local name = self:GetSharedProfileName()
    for i = 1, #self.db.manual do
        if self.db.manual[i] and self.db.manual[i].name == name then
            return self.db.manual[i]
        end
    end
    return nil
end

-- 把 sharedProfile 应用到当前角色(无 reload,运行时切换)
function P:ApplySharedToCurrent()
    if not (U1DB and U1DB.shareAddonEnable) then return end
    if not U1DB or not U1DB.addons then return end

    local prof = self:EnsureSharedProfile()
    if not prof or not prof.u1dbaddons then return end

    local applied = 0
    for k, v in pairs(prof.u1dbaddons) do
        if type(k) == "string" and (v == 0 or v == 1) then
            U1DB.addons[k] = v  -- 同步到角色级,让 163UI UI 显示一致
            local curEnabled = C_AddOns.GetAddOnEnableState(k, U1PlayerGuid) >= 2
            local wantEnabled = v == 1
            if curEnabled ~= wantEnabled then
                if wantEnabled then
                    U1EnableAddOn(k)
                else
                    U1DisableAddOn(k)
                end
                applied = applied + 1
            end
        end
    end

    if applied > 0 then
        U1Message(format(LOCALE_zhCN and "[共享启停]已应用 %d 个插件的启停状态" or "[共用啟停]已套用 %d 個插件的啟停狀態", applied))
    end
end

-- 单条状态变更同步到 sharedProfile(供 U1Enable/DisableAddOn, saveState, U1ToggleAddon 调用)
function P:SyncToSharedProfile(name, value)
    if not (U1DB and U1DB.shareAddonEnable) then return end
    if not name or type(name) ~= "string" then return end
    local prof = self:EnsureSharedProfile()
    if prof then
        prof.u1dbaddons = prof.u1dbaddons or {}
        prof.u1dbaddons[name:lower()] = (value == 1 or value == true) and 1 or 0
    end
end

-- 阻止用户通过 UI 删除 sharedProfile
local _origRemoveProfile = P.RemoveProfile
function P:RemoveProfile(index, ptype)
    if ptype == 'manual' and self.db.manual[index] and self:IsSharedProfile(self.db.manual[index]) then
        U1Message(LOCALE_zhCN and "[共享启停]全局通用配置受保护,不能删除。" or "[共用啟停]全帳號通用配置受保護,不能刪除。")
        return
    end
    return _origRemoveProfile(self, index, ptype)
end

--[[------------------------------------------------------------
全账号共享 - 开关切换时的 backup/restore
核心问题: 启动 ApplySharedToCurrent 会覆盖 U1DB.addons,关闭开关后
        角色无法回到"开启前"状态。解决方案:开启前先 snapshot,
        关闭时 restore。
存储: U1DBG.preSharedBackup[charKey] 账号级 map(U1DBG 是账号级,不会跟角色混淆)
---------------------------------------------------------------]]

local function _u1GetCharKey()
    return (UnitName'player' or '?') .. '-' .. (GetRealmName() or '?')
end

-- 开启开关时调用:备份当前 U1DB.addons(仅首次开启时备份,后续启动不再备份)
function P:BackupPreSharedAddons()
    if not U1DB or not U1DB.addons then return end
    U1DBG = U1DBG or {}
    U1DBG.preSharedBackup = U1DBG.preSharedBackup or {}
    local key = _u1GetCharKey()
    -- 只有在没备份过的情况下才备份(后续启动不能覆盖原始备份)
    if not U1DBG.preSharedBackup[key] then
        U1DBG.preSharedBackup[key] = copyTable(U1DB.addons, U1DBG.preSharedBackup[key])
    end
end

-- 关闭开关时调用:从 backup 恢复 U1DB.addons,并清掉 backup
function P:RestorePreSharedAddons()
    if not U1DB then return end
    U1DBG = U1DBG or {}
    U1DBG.preSharedBackup = U1DBG.preSharedBackup or {}
    local key = _u1GetCharKey()
    if U1DBG.preSharedBackup[key] then
        -- 恢复 U1DB.addons = backup
        U1DB.addons = copyTable(U1DBG.preSharedBackup[key], U1DB.addons)
        -- 根据恢复后的状态调暴雪 API(无 reload,已加载的不动)
        self:EnableOrDisableAddOn(U1DB.addons)
        -- 提示恢复了几条
        local n = 0
        for _ in pairs(U1DBG.preSharedBackup[key]) do n = n + 1 end
        U1DBG.preSharedBackup[key] = nil
        U1Message(format(LOCALE_zhCN and "[共享启停]已恢复本角色原始启停配置(%d 个插件)。" or "[共用啟停]已恢復本角色原始啟停配置(%d 個插件)。", n))
    end
end

local backup_type = 'auto'
local backup_opts = { 
    u1dbaddons = true,
    u1dbconfigs = true,
}
local _has_backed_up = false
local _player, _realm = (UnitName'player'), GetRealmName()

function P:BackupSession(key)
    --print(key, _has_backed_up)
    if(not _has_backed_up) then
        _has_backed_up = true
    else
        return
    end

    local prof
    -- go through profiles to find the one for current user
    for index, profile in self:IterateProfiles(backup_type) do
        if(profile.name == key and profile.user == _player and profile.realm == _realm) then
            prof = profile
            break
        end
    end

    -- if not found , start a new one
    if(not prof) then
        prof = self:CreateProfile(key, backup_type)
        self:EditProfileOption(prof, backup_opts)
    end

    prof.num_addons = nil
    self:SaveProfile(prof)
end

local eventFrame = CreateFrame'Frame'
P.eventFrame = eventFrame

local reloading
eventFrame:SetScript('OnEvent', function(self, event)
    if(event == 'VARIABLES_LOADED') then
        if P.Initialize then P:Initialize() end
    elseif event == 'PLAYER_LOGIN' then
        if P.Initialize then
            self:UnregisterEvent("VARIABLES_LOADED")
            P:Initialize()
        end
        local last_time = U1DB.last_logout_time
        -- ignore reload login event, and login soon after logout in 1 hour
        if last_time ~= "reload" and (last_time == nil or time() - last_time > 60 * 60) then
            if(UnitLevel("player") >= 10) then
                P:BackupSession(L["After Login"])
            end
        end
    elseif event == 'PLAYER_LOGOUT' then
        U1DB.last_logout_time = reloading and "reload" or time()
        if not reloading then U1DBG.lastReloadTime = nil end
        if(not reloading and UnitLevel("player") >= 10) then
            P:BackupSession(L["Before Logout"])
        end
    end
end)

eventFrame:RegisterEvent'VARIABLES_LOADED'
eventFrame:RegisterEvent'PLAYER_LOGOUT'
eventFrame:RegisterEvent'PLAYER_LOGIN'

hooksecurefunc("ReloadUI", function()
    U1DBG.lastReloadTime = GetTime()
    reloading = true
end)
