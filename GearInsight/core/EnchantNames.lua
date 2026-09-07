-- 由 build_enchant_names_lua.py 生成，⛔别手改。附魔 id → 各语言名（去掉部位前缀）。
GearInsight = GearInsight or {}
GearInsight.EnchantNames = {
    [1704] = { deDE = "Thoriumstachel", enUS = "Thorium Spike", esES = "Punta de torio", frFR = "Pointe en thorium", itIT = "Chiodatura di Torio", koKR = "토륨 쐐기", ptBR = "Espigão de Tório", ruRU = "Ториевый шип", zhCN = "瑟银盾刺", zhTW = "瑟銀盾刺" },
    [2603] = { deDE = "+$24303s1 Angeln", enUS = "+$24303s1 Fishing", esES = "+$24303s1 pesca", frFR = "+$24303s1 en Pêche", itIT = "+$24303s1 Pesca", koKR = "낚시 숙련도 +$24303s1", ptBR = "+$24303s1 de Pesca", ruRU = "+$24303s1 к навыку рыбной ловли", zhCN = "+$24303s1 钓鱼", zhTW = "+$24303s1釣魚" },
    [2841] = { deDE = "+$k1 Ausdauer", enUS = "+$k1 Stamina", esES = "+$k1 aguante", frFR = "+$k1 à l’Endurance", itIT = "+$k1 Tempra", koKR = "체력 +$k1", ptBR = "+$k1 de Vigor", ruRU = "+$k1 к выносливости", zhCN = "+$k1 耐力", zhTW = "+$k1耐力" },
    [3368] = { deDE = "Rune des gefallenen Kreuzfahrers", enUS = "Rune of the Fallen Crusader", esES = "Runa del cruzado caído", frFR = "Rune du Croisé déchu", itIT = "Runa del Crociato Caduto", koKR = "타락한 성전사의 룬", ptBR = "Runa do Cruzado Caído", ruRU = "Руна павшего рыцаря", zhCN = "堕落十字军符文", zhTW = "墮落十字軍符文" },
    [3847] = { deDE = "Rune des Steinhautgargoyles", enUS = "Rune of the Stoneskin Gargoyle", esES = "Runa de la gárgola piel de piedra", frFR = "Rune de la gargouille peau de pierre", itIT = "Runa del Gargoyle Pellepietrosa", koKR = "돌가죽 가고일의 룬", ptBR = "Runa da Gárgula Litopele", ruRU = "Руна каменной горгульи", zhCN = "岩肤石像鬼符文", zhTW = "石膚石像鬼符文" },
    [4216] = { deDE = "Pyriumstachel", enUS = "Pyrium Spike", esES = "Punta de pirium", frFR = "Pointe en pyrium", itIT = "Chiodatura di Pirio", koKR = "황철 쐐기", ptBR = "Espigão de Pírio", ruRU = "Колчедановый шип", zhCN = "燃钢盾刺", zhTW = "黃鐵盾刺" },
    [4732] = { deDE = "+$71691s1 Angeln", enUS = "+$71691s1 Fishing", esES = "+$71691s1 pesca", frFR = "+$71691s1 en Pêche", itIT = "+$71691s1 Pesca", koKR = "낚시 숙련도 +$71691s1", ptBR = "+$71691s1 de Pesca", ruRU = "+$71691s1 к навыку рыбной ловли", zhCN = "+$71691s1 钓鱼", zhTW = "+$71691s1釣魚" },
    [5445] = { deDE = "Bergbau der Verheerten Inseln", enUS = "Legion Mining", esES = "Minería de Legion", frFR = "Minage de la Légion", itIT = "Estrazione di Legion", koKR = "군단 채광", ptBR = "Mineração de Legion", ruRU = "Горное дело Легиона", zhCN = "军团采矿", zhTW = "軍團採礦" },
    [5447] = { deDE = "Vermessung der Verheerten Inseln", enUS = "Legion Surveying", esES = "Topografía de Legion", frFR = "Levé de la Légion", itIT = "Rilevamento di Legion", koKR = "군단 조사", ptBR = "Sondagem de Legion", ruRU = "Археология Legion", zhCN = "军团勘测", zhTW = "軍團勘察" },
    [5934] = { deDE = "Kürschnerei von Kul Tiras", enUS = "Kul Tiran Skinning", esES = "Desuello de Kul Tiras", frFR = "Dépeçage de Kul Tiras", itIT = "Scuoiatura di Kul Tiras", koKR = "쿨 티란 무두질", ptBR = "Esfolamento de Kul Tiraz", ruRU = "Кул-тирасское снятие шкур", zhCN = "库尔提拉斯剥皮", zhTW = "庫爾提拉斯剝皮" },
    [5937] = { deDE = "Handwerkskunst von Kul Tiras", enUS = "Kul Tiran Crafting", esES = "Artesanía de Kul Tiras", frFR = "Artisanat de Kul Tiras", itIT = "Artigianato di Kul Tiras", koKR = "쿨 티란 제작", ptBR = "Criação de Kul Tiraz", ruRU = "Кул-тирасское ремесло", zhCN = "库尔提拉斯工艺", zhTW = "庫爾提拉斯製作" },
    [6205] = { deDE = "Sammeln der Schattenlande", enUS = "Shadowlands Gathering", esES = "Recolección de las Tierras Sombrías", frFR = "Récolte d’Ombreterre", itIT = "Raccolta di Shadowlands", koKR = "어둠땅 채집", ptBR = "Coleta nas Terras Sombrias", ruRU = "Сбор ресурсов в Темных Землях", zhCN = "暗影界采集", zhTW = "暗影之境採集" },
    [6241] = { deDE = "Rune der Sanguination", enUS = "Rune of Sanguination", esES = "Runa de desangramiento", frFR = "Rune d’exsanguination", itIT = "Runa del Dissanguamento", koKR = "혈기의 룬", ptBR = "Runa da Sangradura", ruRU = "Руна полнокровия", zhCN = "鲜红符文", zhTW = "淌血符文" },
    [6245] = { deDE = "Rune der Apokalypse", enUS = "Rune of the Apocalypse", esES = "Runa del Apocalipsis", frFR = "Rune de l’apocalypse", itIT = "Runa dell'Apocalisse", koKR = "대재앙의 룬", ptBR = "Runa do Apocalipse", ruRU = "Руна апокалипсиса", zhCN = "天启符文", zhTW = "天啟符文" },
    [7935] = { deDE = "+$k1 Intelligenz und +$k2 Ausdauer", enUS = "+$k1 Intellect & +$k2 Stamina", esES = "+$k1 p. de intelecto y +$k2 p. de aguante", frFR = "+$k1 à l’intelligence et +$k2 à l’endurance", itIT = "+$k1 Intelletto e +$k2 Tempra", koKR = "지능 +$k1 / 체력 +$k2", ptBR = "+$k1 de Intelecto e +$k2 de Vigor", ruRU = "+$k1 к интеллекту и +$k2 к выносливости", zhCN = "+$k1 智力和+$k2 耐力", zhTW = "+$k1點智力和+$k2點耐力" },
    [7937] = { deDE = "+$k1 Intelligenz und +$457616s1% Mana", enUS = "+$k1 Intellect & +$457616s1% Mana", esES = "+$k1 p. de intelecto y +$457616s1% de maná", frFR = "+$k1 à l’intelligence et +$457616s1 % de mana", itIT = "+$k1 Intelletto e +$457616s1% Mana", koKR = "지능 +$k1 / 마나 +$457616s1%", ptBR = "+$k1 de Intelecto e +$457616s1% de Mana", ruRU = "+$k1 к интеллекту и +$457616s1% маны", zhCN = "+$k1 智力和+$457616s1% 法力值", zhTW = "+$k1點智力和+$457616s1%法力" },
    [7957] = { deDE = "Zeichen von Nalorakk", enUS = "Mark of Nalorakk", esES = "Marca de Nalorakk", frFR = "marque de Nalorakk", itIT = "Marchio di Nalorakk", koKR = "날로라크의 징표", ptBR = "Torso", ruRU = "метка Налоракка", zhCN = "纳洛拉克印记", zhTW = "納羅拉克印記" },
    [7961] = { deDE = "Ermächtigter Lebensraubzauber", enUS = "Empowered Hex of Leeching", esES = "Maleficio de parasitismo potenciado", frFR = "maléfice de sangsue renforcé", itIT = "Maleficio dell'Assorbimento Potenziato", koKR = "강화된 생기흡수의 사술", ptBR = "Encantamento de Bagata Sorvedora Potencializada - Elmo", ruRU = "усиленный сглаз самоисцеления", zhCN = "强化吸血妖术", zhTW = "強化汲取妖術" },
    [7963] = { deDE = "Gewandtheit des Luchses", enUS = "Lynx's Dexterity", esES = "Destreza de lince", frFR = "dextérité du lynx", itIT = "Destrezza della Lince", koKR = "스라소니의 기민함", ptBR = "Botas", ruRU = "рысья стремительность", zhCN = "山猫之敏", zhTW = "山貓迅敏" },
    [7967] = { deDE = "Augen des Adlers", enUS = "Eyes of the Eagle", esES = "Ojos del águila", frFR = "yeux de l’aigle", itIT = "Occhi dell'Aquila", koKR = "독수리의 눈", ptBR = "Anel", ruRU = "глаза орла", zhCN = "鹰眼神视", zhTW = "老鷹之眼" },
    [7969] = { deDE = "Zul'jins Meisterschaft", enUS = "Zul'jin's Mastery", esES = "Maestría de Zul'jin", frFR = "maîtrise de Zul’jin", itIT = "Maestria di Zul'jin", koKR = "줄진의 특화", ptBR = "Anel", ruRU = "искусность Зул'джина", zhCN = "祖尔金的精通", zhTW = "祖爾金精通" },
    [7973] = { deDE = "Akil'zons Schnelligkeit", enUS = "Akil'zon's Swiftness", esES = "Presteza de Akil'zon", frFR = "Rapidité d’Akil’zon", itIT = "Rapidità di Akil'zon", koKR = "아킬존의 신속함", ptBR = "Ombros", ruRU = "стремительность Акил'зон", zhCN = "埃基尔松的迅捷", zhTW = "阿奇爾森的迅捷" },
    [7981] = { deDE = "Jan'alais Präzision", enUS = "Jan'alai's Precision", esES = "Precisión de Jan'alai", frFR = "précision de Jan’alai", itIT = "Precisione di Jan'alai", koKR = "잔알라이의 정밀함", ptBR = "Arma", ruRU = "точность Джан'алай", zhCN = "加亚莱的精准", zhTW = "賈納雷的精準" },
    [7983] = { deDE = "Berserkerwut", enUS = "Berserker's Rage", esES = "Ira de rabioso", frFR = "rage du berserker", itIT = "Rabbia del Berserker", koKR = "광전사의 분노", ptBR = "Arma", ruRU = "ярость берсерка", zhCN = "狂战士之怒", zhTW = "狂戰士之怒" },
    [7987] = { deDE = "Zeichen der Weltenseele", enUS = "Mark of the Worldsoul", esES = "Marca del alma-mundo", frFR = "marque de l’Âme-monde", itIT = "Marchio dell'Anima del Mondo", koKR = "세계혼의 징표", ptBR = "Torso", ruRU = "метка души мира", zhCN = "世界之魂印记", zhTW = "世界之魂印記" },
    [7991] = { deDE = "Ermächtigter Segen der Geschwindigkeit", enUS = "Empowered Blessing of Speed", esES = "Bendición de velocidad potenciada", frFR = "bénédiction de vitesse renforcée", itIT = "Benedizione della Velocità Potenziata", koKR = "강화된 속도의 축복", ptBR = "Encantamento da Bênção da Velocidade Potencializada - Elmo", ruRU = "усиленное благословение скорости", zhCN = "强化加速祝福", zhTW = "強化速度祝福" },
    [7993] = { deDE = "Shaladrassils Wurzeln", enUS = "Shaladrassil's Roots", esES = "Raíces de Shaladrassil", frFR = "racines de Shaladrassil", itIT = "Radici di Shaladrassil", koKR = "샬라드라실의 뿌리", ptBR = "Botas", ruRU = "корни Шаладрассила", zhCN = "莎拉达希尔之根", zhTW = "夏達希爾之根" },
    [7997] = { deDE = "Furor der Natur", enUS = "Nature's Fury", esES = "Furia de la Naturaleza", frFR = "fureur de la nature", itIT = "Furia della Natura", koKR = "자연의 격노", ptBR = "Anel", ruRU = "гнев природы", zhCN = "自然之怒", zhTW = "自然之怒" },
    [8001] = { deDE = "Amirdrassils Anmut", enUS = "Amirdrassil's Grace", esES = "Gracia de Amirdrassil", frFR = "grâce d’Amirdrassil", itIT = "Grazia di Amirdrassil", koKR = "아미드랏실의 은혜", ptBR = "Ombros", ruRU = "милость Амирдрассила", zhCN = "阿梅达希尔之赐", zhTW = "埃達希爾之賜" },
    [8013] = { deDE = "Mal des Magisters", enUS = "Mark of the Magister", esES = "Marca del magister", frFR = "marque de magistère", itIT = "Marchio del Magistro", koKR = "마법학자의 징표", ptBR = "Torso", ruRU = "метка магистра", zhCN = "魔导师印记", zhTW = "博學者印記" },
    [8017] = { deDE = "Ermächtigte Rune der Vermeidung", enUS = "Empowered Rune of Avoidance", esES = "Runa de evasión potenciada", frFR = "rune d’évitement renforcée", itIT = "Runa dell'Elusione Potenziata", koKR = "강화된 광역회피의 룬", ptBR = "Encantamento da Runa da Evasão Potencializada - Elmo", ruRU = "усиленная руна избежания", zhCN = "强化闪避符文", zhTW = "強化迴避符文" },
    [8019] = { deDE = "Jagd des Weltenwanderers", enUS = "Farstrider's Hunt", esES = "Cacería de errante", frFR = "chasse de pérégrin", itIT = "Caccia dei Lungopasso", koKR = "원정순찰대의 추적", ptBR = "Botas", ruRU = "охота Странника", zhCN = "远行者的狩猎", zhTW = "遠行者之狩" },
    [8025] = { deDE = "Inbrunst von Silbermond", enUS = "Silvermoon's Alacrity", esES = "Prontitud de Lunargenta", frFR = "empressement de Lune-d’Argent", itIT = "Alacrità di Lunargenta", koKR = "실버문의 기민함", ptBR = "Anel", ruRU = "луносветская расторопность", zhCN = "银月城之捷", zhTW = "銀月城的矯捷" },
    [8027] = { deDE = "Hartnäckigkeit von Silbermond", enUS = "Silvermoon's Tenacity", esES = "Tenacidad de Lunargenta", frFR = "ténacité de Lune-d’Argent", itIT = "Tenacia di Lunargenta", koKR = "실버문의 끈기", ptBR = "Anel", ruRU = "луносветское упорство", zhCN = "银月城之韧", zhTW = "銀月城的堅毅" },
    [8031] = { deDE = "Heilung von Silbermond", enUS = "Silvermoon's Mending", esES = "Alivio de Lunargenta", frFR = "Guérison de Lune-d’Argent", itIT = "Guarigione di Lunargenta", koKR = "실버문의 치유", ptBR = "Ombros", ruRU = "луносветское исцеление", zhCN = "银月城治愈", zhTW = "銀月城的癒合" },
    [8039] = { deDE = "Scharfsinn der Ren'dorei", enUS = "Acuity of the Ren'dorei", esES = "Agudeza de los ren'dorei", frFR = "acuité des Ren’dorei", itIT = "Acutezza dei Ren'dorei", koKR = "렌도레이의 명민함", ptBR = "Arma", ruRU = "проницательность рен'дорай", zhCN = "朗多雷之锐", zhTW = "刃多雷的敏銳" },
    [8041] = { deDE = "Arkane Meisterschaft", enUS = "Arcane Mastery", esES = "Maestría Arcana", frFR = "maîtrise des arcanes", itIT = "Maestria Arcana", koKR = "비전 숙련", ptBR = "Arma", ruRU = "чародейская искусность", zhCN = "奥术精通", zhTW = "秘法專精" },
    [8159] = { deDE = "+$k2 Beweglichkeit/Stärke und +$k1 Ausdauer", enUS = "+$k2 Agility/Strength & +$k1 Stamina", esES = "+$k2 p. de agilidad/fuerza y +$k1 p. de aguante", frFR = "+$k2 à l’agilité/force et +$k1 à l’endurance", itIT = "+$k2 Agilità/Forza e +$k1 Tempra", koKR = "민첩성/힘 +$k2 / 체력 +$k1", ptBR = "+$k2 de Agilidade/Força e +$k1 de Vigor", ruRU = "+$k2 к ловкости/силе и +$k1 к выносливости", zhCN = "+$k2 敏捷/力量 &+$k1 耐力", zhTW = "+$k2點敏捷/力量和+$k1點耐力" },
    [8163] = { deDE = "+$k2 Beweglichkeit/Stärke und +$k1 Rüstung", enUS = "+$k2 Agility/Strength & +$k1 Armor", esES = "+$k2 p. de agilidad/fuerza y +$k1 p. de armadura", frFR = "+$k2 à l’agilité/force et +$k1 à l’armure", itIT = "+$k2 Agilità/Forza e +$k1 Armatura", koKR = "민첩성/힘 +$k2 / 방어도 +$k1", ptBR = "+$k2 de Agilidade/Força e +$k1 de Armadura", ruRU = "+$k2 к ловкости/силе и +$k1 к броне", zhCN = "+$k2 敏捷/力量和+$k1 护甲", zhTW = "+$k2點敏捷/力量和+$k1點護甲值" },
    [8689] = { deDE = "Ritual der Hash'ey", enUS = "Rite of the Hash'ey", esES = "Ritual del hash'ey", frFR = "Rite des hash’ey", itIT = "Rito degli Hash'ey", koKR = "하셰이의 의례", ptBR = "Rito dos Hash'ey", ruRU = "Обряд хаш'эй", zhCN = "哈谢仪式", zhTW = "哈謝之儀" },
}

-- 取当前客户端语言的附魔名：zhCN 优先烤制的 nameCn（口径最熟），其它语言查表，再退到配方物品名，再退 nameCn。
-- 腿部护甲片/魔线：法术名是「+$k2 敏捷/力量」这种带占位符的模板（上表被 $ 挡掉），
-- 只有对应物品才有干净的多语言名 → 附魔 id → 护甲片物品 id。⛔ ui/GearMap.lua 的 LEG_KIT 同款，两处同改。
GearInsight.EnchantKitItem = {
    [8159] = 244641, [8163] = 244643,   -- 森林猎手的护甲片 / 血骑士的护甲片
    [7935] = 240133, [7937] = 240155,   -- 阳炎丝绸魔线 / 奥纹魔线
}
function GearInsight.EnchName(e, fallback)
    if not e then return fallback or "" end
    local kitItem = e.id and GearInsight.EnchantKitItem[e.id]
    if kitItem and C_Item and C_Item.GetItemNameByID then
        local loc0 = GearInsight.LOCALE or "enUS"
        if loc0 ~= "zhCN" then
            local n = C_Item.GetItemNameByID(kitItem)
            if n and n ~= "" then return n end
            if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, kitItem) end
        end
    end
    local loc = GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
    if loc == "esMX" then loc = "esES" elseif loc == "enGB" then loc = "enUS" end
    if loc == "zhCN" and e.nameCn and e.nameCn ~= "" then return e.nameCn end
    local t = e.id and GearInsight.EnchantNames[e.id]
    if t then
        local n = t[loc] or t.enUS
        if n and n ~= "" and not n:find("$", 1, true) then return n end
        -- 模板名（"+$k2 Agility/Strength & +$k1 Armor"）：物品名还没缓存时剥掉占位符顶上，
        -- ⛔ 不许掉回 nameCn（非中文客户端会印出简中）。
        if n and n ~= "" and loc ~= "zhCN" then
            local c = n:gsub("%+?%$[%w%.]+%%?%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if c ~= "" then return c end
        end
    end
    if e.item and C_Item and C_Item.GetItemNameByID then
        local n = C_Item.GetItemNameByID(e.item)
        if n and n ~= "" then return n end
    end
    if e.nameCn and e.nameCn ~= "" then return e.nameCn end
    return fallback or ""
end
