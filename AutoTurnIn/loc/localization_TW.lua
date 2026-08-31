local addonName, privateTable = ...
if (GetLocale() == "zhTW") then --沒翻譯的是代碼裏沒有的
privateTable.L = setmetatable({
	["Skip everywhere"]="跳過所有地方",
	["Skip in instances only"]="僅在實例中跳過",
	["Do not skip"]="不要跳過",
	["Add sell button"]="添加賣出按鈕",
	["Autosell junk"]="自動銷售垃圾",
	["Don't do anything"]="什麼都別做",
	["global settings"]="任務交接設置",
	["reset"]="設置已重置",
	["usage1"]="'on'/'off' 命令用來啟用或禁用自動交接（啟用後按住SHIFT可禁用）",
	["usage2"]="'all'/'list' 是全部任務還是僅列表中的人物",
	["usage3"]="'loot' do not complete quests with a list of rewards or complete it and choose most expensive one of rewards",
	["enabled"]="啟用",
	["disabled"]="禁用",
	["debug"]="調試：解釋任務獎勵的選擇原因",
	["all"]="ready to handle every quest",
	["list"]="only daily quests will be handled",
	["dontlootfalse"]="loot most expensive reward",
	["dontloottrue"]="do not complete quests with rewards",
	["resetbutton"]="默認設置",
	
	["questTypeLabel"] = "自動交接的任務",
	["questTypeAll"] = "全部",
    ["questTypeList"] = "日常",
    ["questTypeExceptDaily"] = "除日常外的全部",
    ["TrivialQuests"]="接受低等級任務",
	["ShareQuestsLabel"] = "自動與隊友分享任務",
    ["AcceptSharedQuestsLabel"] = "自動接受隊友分享的任務",
    ["CompleteOnly"] = "只自動交任務(不自動接)",

	["lootTypeLabel"]="有獎勵的任務",
	["lootTypeFalse"]="不自動交",
	["lootTypeGreed"]="選擇最貴的獎勵",
	["lootTypeNeed"]="根據規則選擇",
	
	["tournamentLabel"]="銀色錦標賽(WLK)",
	["tournamentWrit"]="冠軍的文書", -- 46114
	["tournamentPurse"]="冠軍的錢包",  -- 45724
	
	["DarkmoonTeleLabel"]="暗月：傳送到大炮",
	["ToDarkmoonLabel"]="暗月：傳送到島",
	["DarkmoonAutoLabel"]="暗月：開始遊戲",
	["Darkmoon Island"]="暗月島",
	["Darkmoon Faire Mystic Mage"]="暗月馬戲團秘法師",
	
	["ReviveBattlePetLabel"]="對話NPC時自動選擇治療戰鬥寵物",
	["ReviveBattlePetQ"]="我要治療和復活我的戰鬥寵物。",
	["ReviveBattlePetA"]="為物資支付一些費用是必需的。", --獸欄管理員
	
	["DismissKyrianStewardLabel"]="解散格裏恩執事者",
	["CovenantSwapGossipCompletion"]="自動完成切換盟約對話",
	["The Jade Forest"]="翡翠林",
    ["Scared Pandaren Cub"]="受驚嚇的熊貓人兒童",
	
	["rewardtext"]="顯示任務完成的聊天文本",
	["questlevel"]="顯示任務等級",
	["watchlevel"]="任務追蹤列表中顯示任務等級",
	["autoequip"]="自動裝備任務獎勵",
	["togglekey"]="暫時啟用/停用熱鍵",
	
	['Jewelry']="珠寶",
	["rewardlootoptions"]="獎勵選擇規則",
	['greedifnothing']='如果沒有符合規則的獎勵，則選擇最貴的',
	["multiplefound"]="存在多個符合規則的獎勵. "..ERR_QUEST_MUST_CHOOSE,
	["nosuitablefound"]="沒有符合規則的獎勵. "..ERR_QUEST_MUST_CHOOSE,
	["gogreedy"]="沒有符合規則的獎勵, 自動選擇了價值最高的一個.",
	["rewardlag"]=BUTTON_LAG_LOOT_TOOLTIP.. '. '..ERR_QUEST_MUST_CHOOSE,
	["stopitemfound"]="獎勵中有 %s, 請自己選擇一個獎勵並裝備.",
	["relictoggle"]="禁用神器獎勵",
	["artifactpowertoggle"]="禁用神器能量獎勵的自動完成.",
	["ivechosen"]="已經為你選擇了第一個選項.",
	["ivechosenfive"]="已經為你選擇了第5個選項.",
	["norewardsettings"]="選擇獎勵規則未設置，自動裝備功能禁用.",
	["ignorenpc"]="忽略這個NPC",
	["cantstopignore"]="無法停止忽略這個NPC",
	},
	{__index = function(table, index) return index end})
	
privateTable.L.quests = {
-- Steamwheedle Cartel
['Making Amends']={item="Runecloth", amount=40, currency=false},
['War at Sea']={item="Mageweave Cloth", amount=40, currency=false},
['Traitor to the Bloodsail']={item="Silk Cloth", amount=40, currency=false},
['Mending Old Wounds']={item="Linen Cloth", amount=40, currency=false},
-- AV both fractions
['補充坐騎']={donotaccept=true}, --7001, 7027
-- Alliance AV Quests
['水晶簇']={donotaccept=true}, --7386
['森林之王伊弗斯']={donotaccept=true}, --6881
["天空的召喚 - 艾克曼的空軍"]={donotaccept=true}, --6943
["天空的召喚 - 斯裏多爾的空軍"]={donotaccept=true}, --6942
["天空的召喚 - 維波裏的空軍"]={donotaccept=true}, --6941
['護甲碎片']={donotaccept=true}, --7223
['護甲碎片']={donotaccept=true}, --6781
['Ram Riding Harnesses']={donotaccept=true}, --7026
-- Horde AV Quests
['聯盟之血']={donotaccept=true}, --7385
['冰雪之王洛克霍拉']={donotaccept=true}, --6801
["天空的召喚 - 古斯的部隊"]={donotaccept=true}, --6825
["天空的召喚 - 傑斯托的部隊"]={donotaccept=true}, --6826
["天空的召喚 - 穆維裏克的部隊"]={donotaccept=true}, --6827
['敵人的物資']={donotaccept=true}, --7224
['取之於敵']={donotaccept=true}, --6741
['羊皮坐具']={donotaccept=true}, --7002
-- Timbermaw Quests
['Feathers for Grazle']={item="Deadwood Headdress Feather", amount=5, currency=false},
['Feathers for Nafien']={item="Deadwood Headdress Feather", amount=5, currency=false},
['More Beads for Salfa']={item="Winterfall Spirit Beads", amount=5, currency=false},
-- Cenarion
['Encrypted Twilight Texts']={item="Encrypted Twilight Text", amount=10, currency=false},
['Still Believing']={item="Encrypted Twilight Text", amount=10, currency=false},
-- Thorium Brotherhood
['Favor Amongst the Brotherhood, Blood of the Mountain']={item="Blood of the Mountain", amount=1, currency=false},
['Favor Amongst the Brotherhood, Core Leather']={item="Core Leather", amount=2, currency=false},
['Favor Amongst the Brotherhood, Dark Iron Ore']={item="Dark Iron Ore", amount=10, currency=false},
['Favor Amongst the Brotherhood, Fiery Core']={item="Fiery Core", amount=1, currency=false},
['Favor Amongst the Brotherhood, Lava Core']={item="Lava Core", amount=1, currency=false},
['Gaining Acceptance']={item="Dark Iron Residue", amount=4, currency=false},
['Gaining Even More Acceptance']={item="Dark Iron Residue", amount=100, currency=false},

-- Fiona's Caravan http://www.wowhead.com/npc=45400
["阿古斯的日記"]={donotaccept=true}, --27560
["Beezil's Cog"]={donotaccept=true}, --27562
["菲奧拉的好運符"]={donotaccept=true}, --27555
["吉德文的武器油"]={donotaccept=true}, --27556
["帕米拉的洋娃娃"]={donotaccept=true}, --27558
["雷布拉特的石塊"]={donotaccept=true}, --27561
["塔倫納的護符"]={donotaccept=true}, --27557
["維克斯圖的臂章"]={donotaccept=true}, --27559

--[[Burning Crusade]]--
--Lower City
["More Feathers"]={item="Arakkoa Feather", amount=30, currency=false},
--Aldor
["More Marks of Kil'jaeden"]={item="Mark of Kil'jaeden", amount=10, currency=false},
["More Marks of Sargeras"]={item="Mark of Sargeras", amount=10, currency=false},
["Fel Armaments"]={item="Fel Armaments", amount=10, currency=false},
["Single Mark of Kil'jaeden"]={item="Mark of Kil'jaeden", amount=1, currency=false},
["Single Mark of Sargeras"]={item="Mark of Sargeras", amount=1, currency=false},
["More Venom Sacs"]={item="Dreadfang Venom Sac", amount=8, currency=false},
--Scryer
["More Firewing Signets"]={item="Firewing Signet", amount=10, currency=false},
["More Sunfury Signets"]={item="Sunfury Signet", amount=10, currency=false},
["Arcane Tomes"]={item="Arcane Tome", amount=1, currency=false},
["Single Firewing Signet"]={item="Firewing Signet", amount=1, currency=false},
["Single Sunfury Signet"]={item="Sunfury Signet", amount=1, currency=false},
["More Basilisk Eyes"]={item="Dampscale Basilisk Eye", amount=8, currency=false},
--Skettis
["More Shadow Dust"]={item="Shadow Dust", amount=6, currency=false},
--SporeGar
["Bring Me Another Shrubbery!"]={item="Sanguine Hibiscus", amount=5, currency=false},
["More Fertile Spores"]={item="Fertile Spores", amount=6, currency=false},
["More Glowcaps"]={item="Glowcap", amount=10, currency=false},
["More Spore Sacs"]={item="Mature Spore Sac", amount=10, currency=false},
["More Tendrils!"]={item="Bog Lord Tendril", amount=6, currency=false},
-- Halaa
["Oshu'gun Crystal Powder"]={item="Oshu'gun Crystal Powder Sample", amount=10, currency=false},

["Hodir's Tribute"]={item="Relic of Ulduar", amount=10, currency=false},
["Remember Everfrost!"]={item="Everfrost Chip", amount=1, currency=false},
["Additional Armaments"]={item=416, amount=125, currency=true},
["Calling the Ancients"]={item=416, amount=125, currency=true},
["Filling the Moonwell"]={item=416, amount=125, currency=true},
["進入火焰之中"]={donotaccept=true}, --29206
["The Forlorn Spire"]={donotaccept=true}, --20205
["Fun for the Little Ones"] = {item=393, amount=15, currency=true},
--MoP
["Seeds of Fear"]={item="Dread Amber Shards", amount=5, currency=false},
["A Dish for Jogu"]={item="Sauteed Carrots", amount=5, currency=false},

["A Dish for Ella"]={item="Shrimp Dumplings", amount=5, currency=false},
["Valley Stir Fry"]={item="Valley Stir Fry", amount=5, currency=false},
["A Dish for Farmer Fung"]={item="Wildfowl Roast", amount=5, currency=false},
["A Dish for Fish"]={item="Twin Fish Platter", amount=5, currency=false},
["Swirling Mist Soup"]={item="Swirling Mist Soup", amount=5, currency=false},
["A Dish for Haohan"]={item="Charbroiled Tiger Steak", amount=5, currency=false},
["A Dish for Old Hillpaw"]={item="Braised Turtle", amount=5, currency=false},
["A Dish for Sho"]={item="Eternal Blossom Fish", amount=5, currency=false},
["A Dish for Tina"]={item="Fire Spirit Salmon", amount=5, currency=false},
["Replenishing the Pantry"]={item="Bundle of Groceries", amount=1, currency=false},
--MOP timeless Island
['Great Turtle Meat']={item="Great Turtle Meat", amount=1, currency=false},
['Heavy Yak Flank']={item="Heavy Yak Flank", amount=1, currency=false},
['Meaty Crane Leg']={item="Meaty Crane Leg", amount=1, currency=false},
['Pristine Firestorm Egg']={item="Pristine Firestorm Egg", amount=1, currency=false},
['Thick Tiger Haunch']={item="Thick Tiger Haunch", amount=1, currency=false},

}

privateTable.L.ignoreList = {
--MOP Tillers http://db.178.com/wow/cn/faction/1277.html http://www.wowhead.com/faction=1277
["的澤地百合"]="", --30401
["的可愛的蘋果"]="",
["的玉貓"]="",
["的藍色羽毛"]="",
["的紅寶石碎片"]="",
["補給需求：星光玫瑰"]="", --41303
["聖光之城"]="", --10211
}
end