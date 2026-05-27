local _, addon = ...
addon.L = addon.L or NewLocale();
local L = addon.L;

L["BtnRescanText"] = "重新获取";
L["BtnRescanTipTitle"] = "重新获取天赋和GS";
L["BtnRescanTip"] = "为了减少资源占用,插件并不会实时更新成员信息，请选中要更新的成员后点击此按钮";

L["BtnAnnText"] = "信息广播";
L["BtnAnnTipTitle"] = "信息广播";
L["BtnAnnTip"] = "将选中团员的信息发布到团队频道, 请谨慎选择, 防止刷屏和纠纷。";
L["BtnAnnPopupText"] = "确定广播|cffff7f00[%d]|r条信息到|cffff7f00[%s]|r频道吗?";
L["BtnAnnNoSelect"] = "请至少选择一个团员";

L["CopyDialogTitleText"] = "请按Ctrl+C复制到浏览器中打开";

L["TitleText"] = "团员信息统计";
L["HeaderClass"] = CLASS;
L["HeaderPlayerName"] = "成员名称";
L["HeaderGS"] = "装等";
L["HeaderHealth"] = "血量";

L["StatusGetting"] = "正在获取资料";
L["StatusCannotGet"] = "有玩家距离过远,无法获得";
L["StatusAllDone"] = "全部资料获取完毕";
L["StatusPaused"] = "战斗中暂停获取";

L["HUNTER"]="猎人";
L["WARLOCK"]="术士";
L["PRIEST"]="牧师";
L["PALADIN"]="圣骑";
L["MAGE"]="法师";
L["ROGUE"]="盗贼";
L["DRUID"]="德鲁伊";
L["SHAMAN"]="萨满";
L["WARRIOR"]="战士";
L["DEATHKNIGHT"]="死骑";

L["MiniTipTitle"] = "TeamStats - 团队信息统计";
L["MiniTip"] = "打开团队信息统计界面, 集中查看所有团员的天赋、装备GS和副本击杀经验. 图标闪烁表示有新获取的数据";

if L["zhTW"] then
L["BtnRescanText"] = "重新獲取";
L["BtnRescanTipTitle"] = "重新獲取天賦和GS";
L["BtnRescanTip"] = "為了減少資源占用,插件並不會實時更新成員信息，請選中要更新的成員後點擊此按鈕";

L["BtnAnnText"] = "信息廣播";
L["BtnAnnTipTitle"] = "信息廣播";
L["BtnAnnTip"] = "將選中團員的信息發布到團隊頻道, 請謹慎選擇, 防止刷屏和糾紛。";
L["BtnAnnPopupText"] = "確定廣播|cffff7f00[%d]|r條信息到|cffff7f00[%s]|r頻道嗎?";
L["BtnAnnNoSelect"] = "請至少選擇一個團員";

L["CopyDialogTitleText"] = "請按Ctrl+C復製到瀏覽器中打開";

L["TitleText"] = "團員信息統計";
L["HeaderClass"] = CLASS;
L["HeaderPlayerName"] = "成員名稱";
L["HeaderGS"] = "裝等";
L["HeaderHealth"] = "血量";

L["StatusGetting"] = "正在獲取資料";
L["StatusCannotGet"] = "有玩家距離過遠,無法獲得";
L["StatusAllDone"] = "全部資料獲取完畢";
L["StatusPaused"] = "戰鬥中暫停獲取";

L["HUNTER"]="獵人";
L["WARLOCK"]="術士";
L["PRIEST"]="牧師";
L["PALADIN"]="聖騎";
L["MAGE"]="法師";
L["ROGUE"]="盜賊";
L["DRUID"]="德魯伊";
L["SHAMAN"]="薩滿";
L["WARRIOR"]="戰士";
L["DEATHKNIGHT"]="死騎";

L["MiniTipTitle"] = "TeamStats - 團隊信息統計";
L["MiniTip"] = "打開團隊信息統計界面, 集中查看所有團員的天賦、裝備GS和副本擊殺經驗. 圖標閃爍表示有新獲取的數據";

end