-- GearInsight - Simplified->Traditional source-name conversion (zhTW only).
-- Loads after BisData but is gated on a zhTW client: zhCN and enUS never build
-- the map and never call it, so their drop-source rendering is byte-for-byte
-- unchanged. Converts the baked Simplified source/boss strings (e.g.
-- "虚影尖塔（团本）-陨落之王萨哈达尔") to Taiwan Traditional Chinese at display time.
-- Char-level mapping covers every CJK character that appears in BisData source/
-- bossName fields; characters identical in both scripts are left untouched.

GearInsight = GearInsight or {}

if GearInsight.LOCALE == "zhTW" then
    -- Simplified -> Traditional, one UTF-8 char per entry.
    local S2T_MAP = {
        ["业"]="業", ["丝"]="絲", ["临"]="臨", ["乌"]="烏", ["乱"]="亂", ["争"]="爭", ["亚"]="亞", ["仪"]="儀",
        ["传"]="傳", ["伪"]="偽", ["体"]="體", ["余"]="餘", ["侠"]="俠", ["侦"]="偵", ["兰"]="蘭", ["兽"]="獸",
        ["军"]="軍", ["决"]="決", ["凯"]="凱", ["凶"]="兇", ["击"]="擊", ["刚"]="剛", ["别"]="別", ["制"]="製",
        ["剑"]="劍", ["剧"]="劇", ["华"]="華", ["卫"]="衛", ["厉"]="厲", ["压"]="壓", ["参"]="參", ["双"]="雙",
        ["变"]="變", ["台"]="臺", ["叶"]="葉", ["响"]="響", ["团"]="團", ["图"]="圖", ["圣"]="聖", ["坚"]="堅",
        ["坠"]="墜", ["垒"]="壘", ["垫"]="墊", ["埚"]="堝", ["堕"]="墮", ["头"]="頭", ["夺"]="奪", ["奥"]="奧",
        ["学"]="學", ["宝"]="寶", ["审"]="審", ["导"]="導", ["尔"]="爾", ["尸"]="屍", ["尽"]="盡", ["层"]="層",
        ["师"]="師", ["带"]="帶", ["干"]="幹", ["开"]="開", ["异"]="異", ["弃"]="棄", ["弥"]="彌", ["弯"]="彎",
        ["强"]="強", ["态"]="態", ["恒"]="恆", ["恶"]="惡", ["恸"]="慟", ["惧"]="懼", ["戏"]="戲", ["战"]="戰",
        ["托"]="託", ["执"]="執", ["扫"]="掃", ["扬"]="揚", ["抚"]="撫", ["护"]="護", ["担"]="擔", ["拥"]="擁",
        ["挥"]="揮", ["换"]="換", ["撑"]="撐", ["斗"]="鬥", ["断"]="斷", ["无"]="無", ["晋"]="晉", ["晓"]="曉",
        ["晕"]="暈", ["术"]="術", ["条"]="條", ["杰"]="傑", ["构"]="構", ["枪"]="槍", ["标"]="標", ["树"]="樹",
        ["梦"]="夢", ["棱"]="稜", ["横"]="橫", ["残"]="殘", ["殒"]="殞", ["毕"]="畢", ["气"]="氣", ["涂"]="塗",
        ["涡"]="渦", ["渊"]="淵", ["渍"]="漬", ["渗"]="滲", ["游"]="遊", ["溅"]="濺", ["灭"]="滅", ["灯"]="燈",
        ["灵"]="靈", ["灾"]="災", ["点"]="點", ["炽"]="熾", ["烂"]="爛", ["烧"]="燒", ["烬"]="燼", ["热"]="熱",
        ["爱"]="愛", ["狱"]="獄", ["猎"]="獵", ["献"]="獻", ["环"]="環", ["瓮"]="甕", ["电"]="電", ["盗"]="盜",
        ["盘"]="盤", ["矿"]="礦", ["确"]="確", ["祷"]="禱", ["祸"]="禍", ["种"]="種", ["稳"]="穩", ["笼"]="籠",
        ["籁"]="籟", ["红"]="紅", ["纪"]="紀", ["纱"]="紗", ["纳"]="納", ["纵"]="縱", ["纹"]="紋", ["纽"]="紐",
        ["线"]="線", ["织"]="織", ["终"]="終", ["结"]="結", ["绕"]="繞", ["绝"]="絕", ["维"]="維", ["绽"]="綻",
        ["缚"]="縛", ["缠"]="纏", ["网"]="網", ["胫"]="脛", ["节"]="節", ["苍"]="蒼", ["荆"]="荊", ["荚"]="莢",
        ["药"]="藥", ["莱"]="萊", ["萨"]="薩", ["藓"]="蘚", ["虚"]="虛", ["虫"]="蟲", ["蚀"]="蝕", ["衬"]="襯",
        ["装"]="裝", ["裤"]="褲", ["视"]="視", ["触"]="觸", ["誉"]="譽", ["计"]="計", ["记"]="記", ["证"]="證",
        ["识"]="識", ["诈"]="詐", ["词"]="詞", ["诡"]="詭", ["语"]="語", ["谑"]="謔", ["谜"]="謎", ["贝"]="貝",
        ["责"]="責", ["贤"]="賢", ["败"]="敗", ["贵"]="貴", ["赛"]="賽", ["赞"]="贊", ["践"]="踐", ["踪"]="蹤",
        ["轨"]="軌", ["转"]="轉", ["轮"]="輪", ["软"]="軟", ["轻"]="輕", ["辉"]="輝", ["达"]="達", ["迈"]="邁",
        ["进"]="進", ["远"]="遠", ["连"]="連", ["迹"]="跡", ["选"]="選", ["遗"]="遺", ["里"]="裡", ["钧"]="鈞",
        ["铁"]="鐵", ["铐"]="銬", ["铜"]="銅", ["铠"]="鎧", ["铭"]="銘", ["银"]="銀", ["铸"]="鑄", ["链"]="鏈",
        ["锁"]="鎖", ["锋"]="鋒", ["锐"]="銳", ["锦"]="錦", ["镜"]="鏡", ["镣"]="鐐", ["长"]="長", ["门"]="門",
        ["闪"]="閃", ["队"]="隊", ["阳"]="陽", ["阵"]="陣", ["阶"]="階", ["陈"]="陳", ["陨"]="隕", ["隐"]="隱",
        ["难"]="難", ["韧"]="韌", ["顶"]="頂", ["项"]="項", ["须"]="須", ["领"]="領", ["颈"]="頸", ["题"]="題",
        ["风"]="風", ["飞"]="飛", ["饥"]="飢", ["饰"]="飾", ["饿"]="餓", ["马"]="馬", ["骇"]="駭", ["骑"]="騎",
        ["髅"]="髏", ["鲁"]="魯", ["鳞"]="鱗", ["龙"]="龍",
        -- 12.0.7 孢陨幽境（腐沼/M10）掉落名新增用字
        ["唤"]="喚", ["溃"]="潰", ["谬"]="謬", ["盖"]="蓋",
    }

    -- Defensive EN->Traditional fallback. Live BisData is fully Chinese, but if a
    -- baked string ever ships an English boss/instance fragment (mirrors the
    -- zhCN-only EN->CN swaps in GearInsight.lua), translate it here so zhTW shows
    -- Traditional Chinese instead of leaking English. Plain substring patterns.
    local EN2T = {
        { "Midnight Falls", "午夜之落" },
        { "Belo'ren", "貝羅倫" },
        { "Imperator Averzian", "統治者阿瓦齊恩" },
        { "Fallen%-King Salhadaar", "墮落之王薩哈達爾" },
        { "Crown of the Cosmos", "宇宙之冠" },
        { "Chimaerus", "奇美魯斯" },
        { "Vaelgor & Ezzorak", "維爾葛與艾札瑞克" },
        { "Lightblinded Vanguard", "光盲先鋒" },
        { "Vorasius", "瓦拉西斯" },
    }

    -- Replace each mapped Simplified char with its Traditional form. The WoW
    -- client has NO global `utf8` library (it is nil in 12.x), so we must not use
    -- utf8.*. Instead match each whole UTF-8 char with a byte-class gsub pattern:
    -- a lead byte (ASCII or 2/3/4-byte UTF-8 lead) followed by its continuation
    -- bytes. Mapped Simplified chars (3-byte CJK) are swapped; unmapped chars
    -- (incl. ASCII/punct) return nil from the callback and gsub keeps them as-is.
    function GearInsight.S2T(str)
        if not str or str == "" then return str end
        -- EN->Traditional first (cheap, usually no-op on the all-Chinese live data).
        for _, p in ipairs(EN2T) do
            str = str:gsub(p[1], p[2])
        end
        str = str:gsub("[%z\1-\127\194-\244][\128-\191]*", function(ch)
            return S2T_MAP[ch]
        end)
        return str
    end
end
