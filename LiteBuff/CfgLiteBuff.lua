
local wipe = wipe
local tinsert = table.insert

local db, list

U1RegisterAddon("LiteBuff", {
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
        default = 1,
        callback = function(cfg, v, loading)
            if(not loading) then LiteBuff:RefreshLiteBuffs() end
        end,
    },

    {
        var = 'locked',
        text = LOCALE_zhCN and '锁定位置' or '鎖定位置',
        default = false,
        callback = function(cfg, v, loading)
            LiteBuff.chardb.lock = v
            -- 立即刷新定位框, 不等2秒兜底ticker
            if not loading and LiteBuff_UpdateMissingDragFrame then
                LiteBuff_UpdateMissingDragFrame()
            end
        end,
    },

    {
        var = 'percharpos',
        text = LOCALE_zhCN and '位置按角色独立保存' or '位置按角色獨立保存',
        default = true,
        callback = function(cfg, v, loading)
            LiteBuff:SaveData("db", "percharpos", v)
        end,
    },

    --[[ --10.0按钮尺寸固定
    {
        var = 'iconsize',
        text = '图标尺寸',
        default = 45,
        type = "spin",
        range = {24, 64, 1},
        callback = function(cfg, v, loading)
            if(not loading) then LiteBuff:RefreshLiteBuffs() end
        end,
    },
    --]]

    {
        var = 'gap',
        text = LOCALE_zhCN and '图标间隔' or '圖標間隔',
        default = 4,
        type = "spin",
        range = {-2, 20, 1},
        callback = function(cfg, v, loading)
            if(not loading) then LiteBuff:RefreshLiteBuffs() end
        end,
    },

    {
        type = 'spin',
        var = 'scale',
        text = LOCALE_zhCN and '缩放' or '縮放',
        range = { .2, 3, .05 }, -- Limit from litebuff itself
        default = 0.8,
        callback = function(cfg, v, loading)
            local scale = v * 100
            if(scale > 300 or scale < 20) then
                scale = 100
            end
            LiteBuff.db.scale = scale
            CoreUISetScale(LiteBuff.frame, scale / 100)
        end,
    },
    {
        var = 'simpletip',
        text = LOCALE_zhCN and '简短提示' or '簡短提示',
        default = false,
        callback = function(cfg, v, loading)
            LiteBuff.db.simpletip = v
        end,
    },

    {
        type = 'checklist',
        text = LOCALE_zhCN and '禁用按鈕' or '禁用按鈕',
        getvalue = function()
            db = db or {}
            wipe(db)
            for i = 1, LiteBuff:GetNumButtons() do
                local b = LiteBuff:GetButton(i)
                db[b.key] = LiteBuff:LoadData('disabledb', b.key)
            end
            return db
        end, 

        callback = function(cfg, v, loading)
            if(loading) then return end
            db = v
            for key, checked in next, v do
                if(checked ~= LiteBuff:LoadData('disabledb', key)) then
                    LiteBuff:SaveData("disabledb", key, checked)
                    local button = LiteBuff:GetButton(key)
                    if checked then
                        button:Disable()
                    else
                        button:Enable()
                    end
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
        default = false,
        callback = function(cfg, v, loading)
            -- 立即生效: 刷新定位框 + 重算提示(否则要等2秒兜底ticker)
            if not loading then
                if LiteBuff_UpdateMissingDragFrame then LiteBuff_UpdateMissingDragFrame() end
                if LiteBuff_RefreshAlerts then LiteBuff_RefreshAlerts() end
            end
        end,
    },

    {
        var = 'missingLock',
        text = LOCALE_zhCN and '锁定缺失Buff提示位置' or '鎖定缺失Buff提示位置',
        tip = LOCALE_zhCN and '关闭后可以拖动屏幕中央的缺失Buff提示框' or '關閉後可以拖動螢幕中央的缺失Buff提示框',
        default = true,
        callback = function(cfg, v, loading)
            if not loading and LiteBuff_UpdateMissingDragFrame then
                LiteBuff_UpdateMissingDragFrame()
            end
        end,
    },

});