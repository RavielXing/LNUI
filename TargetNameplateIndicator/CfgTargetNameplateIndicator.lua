local TexturesList = {
	"红色发光箭头", "NeonRedArrow",
	"绿色发光箭头", "NeonGreenArrow",
	"圆形准星", "Reticule",
	"发光圆形准星", "NeonReticule",
	"纯红色箭头", "RedArrow",
	"纯绿色箭头", "green_arrow_down_11384",
	"渐变箭头", "RedChevronArrow",
	"加速箭头", "PaleRedChevronArrow",
	"绿色锥形", "arrow_tip_green",
	"红色锥形", "arrow_tip_red",
	"红色箭头","NewRedArrow",
	"蓝色箭头", "BlueArrow",
	"蓝色弧形", "bluearrow1",
	"紫色弧形", "PurpleArrow",
	"绿色点状", "greenarrowtarget",
	"圆形标靶", "circles_target",
	"猎人标记", "Hunters_Mark",
	"战争机器", "gearsofwar",
	"红色五星", "red_star",
	"智慧天使", "malthael",
	"白色骷髅", "NewSkull",
	"大骷髅", "skull",
	"盾牌", "Shield",
	"新绿色火焰", "Q_FelFlamingSkull",
	"新红色火焰", "Q_RedFlamingSkull",
	"新紫色火焰", "Q_ShadowFlamingSkull",
	"新绿色定位", "Q_GreenGPS",
	"新红色定位", "Q_RedGPS",
	"新白色定位", "Q_WhiteGPS",
	"新绿色目标", "Q_GreenTarget",
	"新红色目标", "Q_RedTarget",
	"新白色目标", "Q_WhiteTarget",
	"红色内括号", "Arrows_Towards",
	"红色外括号", "Arrows_Away",
	"蓝色内括号", "Arrows_SelfTowards",
	"蓝色外括号", "Arrows_SelfAway",
	"绿色内括号", "Arrows_FriendTowards",
	"绿色外括号", "Arrows_FriendAway",
	"黄色内括号", "Arrows_FocusTowards",
	"黄色外括号", "Arrows_FocusAway",
};

local OptTargetType = "target";
local OptTargetReaction = "all";
local TempInfo = { "indicators", "target", "hostile", "texture", };
local TargetTypeList = { "target", "focus", "mouseover", "targettarget", };
local TargetReactionList = { "self", "friendly", "hostile", };
local function OptSet(Type, Reaction, opt, v)
	local TNIOpt = LibStub("AceConfigRegistry-3.0"):GetOptionsTable("TargetNameplateIndicator")("cmd", "AceConfigCmd-3.0");
	if TNIOpt then
		TempInfo[4] = opt;
		if Type == "all" then
			for _, Type in next, TargetTypeList do
				TempInfo[2] = Type;
				if Reaction == "all" then
					for _, Reaction in next, TargetReactionList do
						TempInfo[3] = Reaction;
						TNIOpt.set(TempInfo, v);
					end
				else
						TempInfo[3] = Reaction;
						TNIOpt.set(TempInfo, v);
				end
			end
		else
				TempInfo[2] = Type;
				if Reaction == "all" then
					for _, Reaction in next, TargetReactionList do
						TempInfo[3] = Reaction;
						TNIOpt.set(TempInfo, v);
					end
				else
						TempInfo[3] = Reaction;
						TNIOpt.set(TempInfo, v);
				end
		end
		return true;
	end
end
local function OptGetByType(Type, opt)
	local TNIOpt = LibStub("AceConfigRegistry-3.0"):GetOptionsTable("TargetNameplateIndicator")("cmd", "AceConfigCmd-3.0");
	if TNIOpt then
		TempInfo[4] = opt;
		for _, v in next, TargetTypeList do
			if v == Type then
				TempInfo[2] = Type;
				local v0 = nil;
					for _, Reaction in next, TargetReactionList do
						TempInfo[3] = Reaction;
						local v = TNIOpt.get(TempInfo);
						if v0 == nil or v == v0 then
							v0 = v;
						else
							return nil, false;
						end
					end
				return v0, true;
			end
		end
	end
end

U1RegisterAddon("TargetNameplateIndicator", {
    title = LOCALE_zhCN and "目标姓名板标记" or "目標姓名板標記",
	defaultEnable = 0,
	load = "LOGIN",  --不然好像会报错

    tags = { TAG_COMBATINFO },
    icon = [[Interface\Icons\Ability_Hunter_MarkedForDeath]],
	nopic = 1,

    desc = LOCALE_zhCN and "说明`在当前目标头顶显示一个选择的图标, 注意必须开启姓名版才能生效，因为这个图标是依附在姓名版上的，姓名版不显示的时候自然也没有标记。" or "說明`在當前目標頭頂顯示一個選擇的圖標, 註意必須開啟姓名版才能生效，因為這個圖標是依附在姓名版上的，姓名版不顯示的時候自然也沒有標記。",

	runAfterLoad = function(info, name)
		local DB = TargetNameplateIndicatorDB;
		if DB ~= nil then
			OptSet("target", "all", "texture", [[Interface\AddOns\TargetNameplateIndicator\Textures\NeonRedArrow]]);
			OptSet("mouseover", "all", "texture", [[Interface\AddOns\TargetNameplateIndicator\Textures\NeonGreenArrow]]);
			OptSet("focus", "all", "texture", [[Interface\AddOns\TargetNameplateIndicator\Textures\NeonReticule]]);
			OptSet("targettarget", "all", "texture", [[Interface\AddOns\TargetNameplateIndicator\Textures\Reticule]]);
		end
	end,

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("TargetNameplateIndicator"))
        end
    },
	{
		text = "选择设置目标类型",
		var = "optTargetType",
		type = "radio",
		options = {
			"所有目标", "all",
			"目标", "target",
			"焦点", "focus",
			"鼠标指向", "mouseover",
			"目标的目标", "targettarget",
		},
		default = "target",
		callback = function(cfg, v, loading)
			OptTargetType = v;
		end,
	},
	{
		text = "选择设置目标敌对状态",
		var = "optTargetReaction",
		type = "radio",
		options = {
			"所有类型", "all",
			"自己", "self",
			"友方单位", "friendly",
			"敌方单位", "hostile",
		},
		default = "all",
		callback = function(cfg, v, loading)
			OptTargetReaction = v;
		end,
	},
	{
		text = "启用",
		var = "enable",
		default = true,
		callback = function(cfg, v, loading)
			OptSet(OptTargetType, OptTargetReaction, "enable", not not v);
		end,
	},
	{
		text = "透明度",
		var = "alpha",
		default = 1,
		type = "spin",
		range = { 0.0, 1.0, 0.05 },
		callback = function(cfg, v, loading)
			OptSet(OptTargetType, OptTargetReaction, "opacity", v);
		end,
	},
	{
		text = "选择图标样式",
		var = "tex",
		type = "radio",
		options = TexturesList,
		default = "NeonRedArrow",
		callback = function(cfg, v, loading)
			OptSet(OptTargetType, OptTargetReaction, "texture", [[Interface\AddOns\TargetNameplateIndicator\Textures\]] .. v);
		end,
	},
});
