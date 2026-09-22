
local wipe = wipe
local tinsert = table.insert

local db, list

-- 默认值统一在 Core.lua 的 LiteBuff.DEFAULTS, 改默认只改那一处
-- 下面FALLBACK这份字面量只是兜底: 163UI在插件加载前(VARIABLES_LOADED)就会读一次default,
-- 那时LiteBuff还不存在(本文件由163UI的Configs.xml加载, 插件自己是load="LOGIN")。
-- 两份必须一致, harness会核对, 对不上直接报错
local FALLBACK = {
    ["layout.growh"] = true,
    ["layout.gap"] = 4,
    ["layout.scale"] = 80,
    ["behavior.lock"] = false,
    ["behavior.percharpos"] = true,
    ["behavior.simpletip"] = false,
    ["alerts.alertMissing"] = false,
    ["alerts.missingLock"] = true,
}

-- 插件加载了就现读DEFAULTS, 没加载就用兜底值
-- disabledButtons单独处理: 面板要的是"每个按钮一条"的开关表, DEFAULTS里是按职业分组的
-- (插件没加载时按钮清单还不存在, 这张表只能是空的, 面板显示靠getvalue补)
local function DefaultOf(path)
    local d = LiteBuff and LiteBuff.DEFAULTS
    local value
    if d then
        local group, key = path:match("^(%a+)%.(%a+)$")
        if group then
            local t = d[group]
            value = t and t[key]
        else
            value = d[path]
        end
    end
    if value == nil then
        value = FALLBACK[path]
    end

    if path == "disabledButtons" then
        local flat = {}
        if type(value) == "table" then
            for _, group in pairs(value) do
                for key, disabled in pairs(group) do
                    flat[key] = disabled and true or false
                end
            end
        end
        return flat
    end
    return value
end

local options = {
    title = LOCALE_zhCN and "智能快捷按钮" or "智能快捷按鈕",
    defaultEnable = 1,
    tags = { TAG_INTERFACE },
    frames = { 'LiteBuffFrame' },
    optionsAfterVar = 0,
    load = "LOGIN",
    icon = [[Interface\AddOns\LiteBuff\LiteBuff]],
    desc = LOCALE_zhCN and "Abin的最新作品，针对每个职业配置的快捷施法条。例如潜行者有3个按钮，分别代表主手、副手、远程武器，鼠标滚轮选择要使用的毒药，左键点击是上毒，右键点击是移除毒药。再比如法师开门，也是滚动选择目的地，左键开门，右键自己传送。部分状态类的按钮上，红色表示缺失此状态，黄色表示部分人员缺失，绿色表示齐备。`此外还提供了天赋切换、精炼合计、随机坐骑的按钮。插件完全使用安全模板开发，战斗中不会出错，Abin出品值得信赖。" or "Abin的最新作品，針對每個職業配置的快捷施法條。例如潛行者有3個按鈕，分別代表主手、副手、遠程武器，鼠標滾輪選擇要使用的毒藥，左鍵點擊是上毒，右鍵點擊是移除毒藥。再比如法師開門，也是滾動選擇目的地，左鍵開門，右鍵自己傳送。部分狀態類的按鈕上，紅色表示缺失此狀態，黃色表示部分人員缺失，綠色表示齊備。`此外還提供了天賦切換、精煉合計、隨機坐騎的按鈕。插件完全使用安全模板開發，戰鬥中不會出錯，Abin出品值得信賴。",
    author = "Abin",
    --modifier = "|cffcd1a1c[Warbaby@163]|r",

    toggle = function(name, info, enable, justload)
        if not justload then
            if not InCombatLockdown() then
                CoreUIShowOrHide(LiteBuffFrame, enable)
            end
        end
        if(not InCombatLockdown()) then
            return LiteBuff:RefreshLiteBuffs()
        end
    end,

    {
        var = 'growh',
        text = LOCALE_zhCN and '横向排列' or '橫向排列',
        default = function() return DefaultOf("layout.growh") end,
        -- 值一律从插件存档读, 面板只是入口(163UI自己那份只是镜像)
        getvalue = function() return LiteBuff:GetSetting("growh") end,
        callback = function(cfg, v, loading)
            if loading then return end
            LiteBuff:SetSetting("growh", v)
            LiteBuff:RefreshLiteBuffs()
        end,
    },

    {
        var = 'locked',
        text = LOCALE_zhCN and '锁定位置' or '鎖定位置',
        default = function() return DefaultOf("behavior.lock") end,
        getvalue = function() return LiteBuff:GetSetting("lock") end,
        callback = function(cfg, v, loading)
            -- loading这轮只是拿默认值, 不能拿它覆盖插件存档
            if loading then return end
            LiteBuff:SetSetting("lock", v)
            -- 立即刷新定位框, 不等2秒兜底ticker
            if LiteBuff_UpdateMissingDragFrame then
                LiteBuff_UpdateMissingDragFrame()
            end
        end,
    },

    {
        var = 'percharpos',
        text = LOCALE_zhCN and '位置按角色独立保存' or '位置按角色獨立保存',
        default = function() return DefaultOf("behavior.percharpos") end,
        getvalue = function() return LiteBuff:GetSetting("percharpos") end,
        callback = function(cfg, v, loading)
            if loading then return end
            LiteBuff:SetSetting("percharpos", v)
        end,
    },

    -- 按钮尺寸(iconsize)选项已废弃: 10.0之后按钮尺寸固定, 见Templates/Main.lua的ICON_SIZE

    {
        var = 'gap',
        text = LOCALE_zhCN and '图标间隔' or '圖標間隔',
        default = function() return DefaultOf("layout.gap") end,
        type = "spin",
        range = {-2, 20, 1},
        getvalue = function() return LiteBuff:GetSetting("gap") end,
        callback = function(cfg, v, loading)
            if loading then return end
            LiteBuff:SetSetting("gap", v)
            LiteBuff:RefreshLiteBuffs()
        end,
    },

    {
        type = 'spin',
        var = 'scale',
        text = LOCALE_zhCN and '缩放' or '縮放',
        range = { .2, 3, .05 }, -- Limit from litebuff itself
        default = function() return DefaultOf("layout.scale") / 100 end,   -- 存档里存百分比, 面板是倍数
        getvalue = function() return LiteBuff:GetScale() / 100 end,
        callback = function(cfg, v, loading)
            if loading then return end
            LiteBuff:SetScale(v * 100)
        end,
    },
    {
        var = 'simpletip',
        text = LOCALE_zhCN and '简短提示' or '簡短提示',
        default = function() return DefaultOf("behavior.simpletip") end,
        getvalue = function() return LiteBuff:GetSetting("simpletip") end,
        callback = function(cfg, v, loading)
            if loading then return end
            LiteBuff:SetSetting("simpletip", v)
        end,
    },

    {
        type = 'checklist',
        -- var是为了让163UI把这张表也存进它的方案里(不带var的话它不存, 方案就带不动按钮开关)
        var = 'disabled',
        text = LOCALE_zhCN and '禁用按鈕' or '禁用按鈕',
        -- 每个按钮都有默认开关(DEFAULTS.disabledButtons里一条不落), 这里给163UI一份摊平的表
        default = function() return DefaultOf("disabledButtons") end,
        -- 按钮是受保护的, 战斗中Disable/Enable会被暴雪拦, 面板上直接不给点
        secure = 1,

        -- 面板上显示的是实际状态: 存档里有记录听存档, 没记录就是默认值
        getvalue = function()
            db = db or {}
            wipe(db)
            for i = 1, LiteBuff:GetNumButtons() do
                local b = LiteBuff:GetButton(i)
                db[b.key] = LiteBuff:IsButtonDisabled(b.key)
            end
            return db
        end, 

        callback = function(cfg, v, loading)
            if(loading) then return end
            db = v
            for key, checked in next, v do
                if(checked ~= LiteBuff:IsButtonDisabled(key)) then
                    LiteBuff:SetButtonDisabled(key, checked)
                end
            end
        end, 

        options = function()
            list = list or {}
            wipe(list)
            if(LiteBuff) then
                for i = 1, LiteBuff:GetNumButtons() do
                    local b = LiteBuff:GetButton(i)
                    tinsert(list, b.title)
                    tinsert(list, b.key)
                end
            end
            return list
        end,
        indent = nil,
        cols = 2,
    },

    {
        var = 'alertMissing',
        text = LOCALE_zhCN and '提示Buff缺失' or '提示Buff缺失',
        tip = LOCALE_zhCN and '说明`在屏幕中央提示某些必须且容易遗忘的Buff状态，例如惩戒骑的祝福' or '說明`在屏幕中央提示某些必須且容易遺忘的Buff狀態，例如懲戒騎的祝福',
        default = function() return DefaultOf("alerts.alertMissing") end,
        getvalue = function() return LiteBuff:GetSetting("alertMissing") end,
        callback = function(cfg, v, loading)
            if loading then return end
            LiteBuff:SetSetting("alertMissing", v)
            -- 立即生效: 刷新定位框 + 重算提示(否则要等2秒兜底ticker)
            if LiteBuff_UpdateMissingDragFrame then LiteBuff_UpdateMissingDragFrame() end
            if LiteBuff_RefreshAlerts then LiteBuff_RefreshAlerts() end
        end,
    },

    {
        var = 'missingLock',
        text = LOCALE_zhCN and '锁定缺失Buff提示位置' or '鎖定缺失Buff提示位置',
        tip = LOCALE_zhCN and '关闭后可以拖动屏幕中央的缺失Buff提示框' or '關閉後可以拖動螢幕中央的缺失Buff提示框',
        default = function() return DefaultOf("alerts.missingLock") end,
        getvalue = function() return LiteBuff:GetSetting("missingLock") end,
        callback = function(cfg, v, loading)
            if loading then return end
            LiteBuff:SetSetting("missingLock", v)
            if LiteBuff_UpdateMissingDragFrame then
                LiteBuff_UpdateMissingDragFrame()
            end
        end,
    },

}

U1RegisterAddon("LiteBuff", options)