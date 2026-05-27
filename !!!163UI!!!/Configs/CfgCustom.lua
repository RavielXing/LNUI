--如果 UI163_USER_MODE = 1 則不需要寫alwaysRegister，而且插件會列在愛不易整合裏，如果不提供USER_MODE，只寫alwaysRegister，則插件會列在分類裏，但仍然在單體插件裏，而不是愛不易整合裏
--UI163_USER_MODE = 1

U1RegisterAddon("DailyTamerCheck", {
    title = "寵物日常檢測",
    defaultEnable = 0,
    tags = {TAG_MAPQUEST},
    desc = "檢測寵物日常任務完成情況，配合TomTom插件，可以設置各個任務的路徑點。`快捷命令：/dtc 或 /dtcheck",
	nopic = 1,
    icon = "Interface\\ICONS\\INV_MISC_PETMOONKINTA",
	{
		text="設置相關選項",
		type = "text",
		{
			var = "show_npcicons",
			text = "顯示寵物類型圖標",
			default = false,
			getvalue=function() 
				return GetOptionValue("show_npcicons") 
			end,
			callback = function(cfg, v, loading)
				RefreshOption(cfg.var, 3, v)
			end,
		},
		{
			var = "show_coordinates",
			text = "顯示任務坐標",
			getvalue=function() 
				return GetOptionValue("show_coordinates") 
			end,
			callback = function(cfg, v, loading)
				RefreshOption(cfg.var, 0, v)
			end,
		},
		{
			var = "show_npcnames",
			text = "顯示NPC名字",
			default = false,
			getvalue=function() 
				return GetOptionValue("show_npcnames") 
			end,
			callback = function(cfg, v, loading)
				RefreshOption(cfg.var, 1, v)
			end,
		},
		{
			var = "show_npclevel",
			text = "顯示寵物等級",
			default = false,
			getvalue=function() 
				return GetOptionValue("show_npclevel") 
			end,
			callback = function(cfg, v, loading)
				RefreshOption(cfg.var, 2, v)
			end,
		},
		{
			var = "show_mapicons",
			text = "顯示世界地圖圖標",
			default = false,
			getvalue=function() 
				return GetOptionValue("show_mapicons") 
			end,
			callback = function(cfg, v, loading)
				RefreshOption(cfg.var, 4, v)
			end,
		},
		{
			var = "show_faction",
			text = "顯示對立陣營任務",
			default = true,
			getvalue=function() 
				return GetOptionValue("show_faction") 
			end,
			callback = function(cfg, v, loading)
				RefreshOption(cfg.var, 5, v)
			end,
		},
	},
})

U1RegisterAddon("YOBUFF", {
    title = "YOBUFF",
    defaultEnable = 0,
    tags = {"MANAGEMENT"},
    icon = "Interface\\Icons\\Spell_ChargeNegative",
    nopic = 1,
	{
		text = "配置插件",
		callback = function()
			SlashCmdList["YOBUFF"]()
		end,
	},
})