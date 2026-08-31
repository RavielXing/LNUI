-- 自动生成(generate_rotation_lua.py ← build_rotation_teaching.py)，勿手改。
-- WCL 顶尖玩家循环参考：raid=团本M1 top5；mplus=冲分各本top2聚合。
-- core={ {spellID,每分钟次数}.. } watch={ {spellID,uptime%}.. } opener=前3名真实起手。
GearInsightRotation = {
  ["DEATHKNIGHT/BLOOD"] = {
    specID=250,
    raid={
      n=5, dur=533, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="阿露伊", server="罗宁", region="CN", seq={1259633,49028,195292,1236616,433895,434144,433895,434144,433895,434144,433895,434144} },
        { player="Giffelknäckt", server="Tarren Mill", region="EU", seq={195292,1236616,49028,46585,1259633,50842,433895,434144,433895,434144,433895,434144} },
        { player="Rokonxd", server="Blackrock", region="EU", seq={43265,1293326,1295735,46585,49028,1236616,50842,433895,434144,433895,434144,49998} },
      },
      core={ {49998,14.8},{206930,13.1},{50842,9.8},{433895,8.3},{43265,3.9},{195182,1.4},{49576,1.4},{195292,1.3},{48265,1.1},{49028,0.7},{1259633,0.7},{55233,0.6},{46585,0.4},{48707,0.3} }, -- Death Strike, Heart Strike, Blood Boil, Vampiric Strike, Death and Decay, Marrowrend, Death Grip, Death's Caress, Death's Advance, Dancing Rune Weapon, Charge!, Vampiric Blood, Raise Dead, Anti-Magic Shell
      watch={ {219788,97.0},{1310372,95.8},{463730,94.4},{194879,94.2},{274009,91.2},{372014,89.4},{77535,86.3},{1287772,83.0},{465,82.8},{180612,67.3} }, -- Ossuary, Blood Debt, Coagulating Blood, Icy Talons, Voracious, Visage, Blood Shield, Rune of Critical Power, Devotion Aura, Recently Used Death Strike
      coach={ cn="怎么打：心脏打击攒符能，灵界打击按得极勤（顶尖19.8次/分）——但别空按，尽量接在吃了伤害之后，回血护盾才不浪费。血液沸腾保持疾病，枯萎凋零踩在脚下（顶尖覆盖73%）。骨盾低了用精髓分裂或死神的抚摩远程补。盯什么：血之护盾（顶尖覆盖95.5%）——盾掉了又要承伤时优先打一个灵界打击；脚下的枯萎凋零圈别走丢。", en="How to play: Heart Strike builds runic power; Death Strike gets pressed constantly (top players: 19.8/min) — but don't waste it, time it right after taking damage so the heal and shield count. Blood Boil keeps diseases up; stand in your Death and Decay (73% top uptime). Refresh bone shield with Marrowrend or Death's Caress at range. Watch: Blood Shield (95.5% top uptime) — if it drops with damage incoming, prioritize a Death Strike; don't drift out of your Death and Decay." },
    },
    mplus={
      n=8, dur=1713,
      core={ {49998,15.5},{206930,13.5},{433895,9.2},{50842,7.5},{43265,3.5},{195182,1.8},{55233,1.6},{195292,1.0},{48265,0.9},{48707,0.9},{49576,0.7},{49028,0.6},{49039,0.5},{46585,0.3} }, -- Death Strike, Heart Strike, Vampiric Strike, Blood Boil, Death and Decay, Marrowrend, Vampiric Blood, Death's Caress, Death's Advance, Anti-Magic Shell, Death Grip, Dancing Rune Weapon, Lichborne, Raise Dead
      watch={ {465,96.9},{1310372,93.8},{433925,93.6},{391481,93.6},{219788,92.6},{194879,91.3},{274009,89.9},{1287774,82.7},{463730,74.0},{188290,68.2} }, -- Devotion Aura, Blood Debt, Essence of the Blood Queen, Coagulopathy, Ossuary, Icy Talons, Voracious, Rune of Burning Haste, Coagulating Blood, Death and Decay
      coach={ cn="怎么打：大秘境骨盾掉得飞快，精髓分裂要按得比团本勤得多——看到骨盾低于5层就补。拉怪先铺枯萎凋零再血液沸腾上疾病，灵界打击照旧留给大额承伤后。盯什么：骨盾层数是第一优先（顶尖玩家 骨盾增益 覆盖96%，意味着骨盾几乎从不掉光）；其次盯血之护盾，AOE 承伤期保持它在身上。", en="How to play: Bone Shield drains fast in Mythic+ — press Marrowrend far more than in raid, refreshing below 5 stacks. Open pulls with Death and Decay then Blood Boil for diseases; save Death Strike for after big damage. Watch: Bone Shield stacks first (top players keep Ossuary at 96%, meaning it never fully drops), then Blood Shield during AoE damage." },
    },
  },
  ["DEATHKNIGHT/FROST"] = {
    specID=251,
    raid={
      n=5, dur=530, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Kagesendo", server="Bleeding Hollow", region="US", seq={47568,49020,51271,1259633,1249658,46585,439843,49020,47568,441424,441426,279302} },
        { player="Phatgrip", server="Draenor", region="EU", seq={47568,49020,1250580,51271,46585,1249658,439843,49020,441424,47568,441426,49020} },
        { player="冰晶亂流之術", server="白银之手", region="CN", seq={48265,46585,49020,47568,1297761,51271,439843,1249658,279302,49020,47568,441424} },
      },
      core={ {49020,15.7},{49143,11.2},{49184,8.8},{47568,4.4},{441424,3.8},{207230,2.5},{194913,1.6},{48265,1.5},{439843,1.3},{51271,1.3},{49576,1.0},{48707,0.8},{279302,0.7},{1265384,0.7} }, -- Obliterate, Frost Strike, Howling Blast, Empower Rune Weapon, Exterminate, Frostscythe, Glacial Advance, Death's Advance, Reaper's Mark, Pillar of Frost, Death Grip, Anti-Magic Shell, Frostwyrm's Fury, Frostwyrm's Fury
      watch={ {194879,97.4},{440289,93.1},{1230916,93.1},{440290,90.4},{1287772,82.6},{456370,81.0},{53365,66.4},{1297365,60.0},{372014,55.1},{51124,51.2} }, -- Icy Talons, Rune Carved Plates, Killing Streak, Rune Carved Plates, Rune of Critical Power, Cryogenic Chamber, Unholy Strength, Freezing Tempest, Visage, Killing Machine
      coach={ cn="怎么打：湮灭是绝对主轴（顶尖23.8次/分），符能用冰霜打击泄掉防溢出，凛风冲击补缝。冰霜之柱和死神印记按 CD 对齐打爆发窗口（各1.4次/分=几乎每个 CD 都没浪费）。盯什么：符文和符能都别溢出——湮灭和冰霜打击的比例接近3:2，手不能停；爆发窗口内把资源全倾泻进去。", en="How to play: Obliterate is the absolute core (top players: 23.8/min); dump runic power with Frost Strike to avoid capping, fill gaps with Howling Blast. Line up Pillar of Frost and Reaper's Mark on cooldown for burst windows (1.4/min each = barely a wasted cooldown). Watch: never cap runes or runic power — the Obliterate-to-Frost-Strike ratio is roughly 3:2, so hands never stop; pour everything into your burst windows." },
    },
    mplus={
      n=8, dur=1705,
      core={ {207230,8.8},{49184,8.7},{194913,8.0},{49020,7.7},{49143,6.3},{47568,4.0},{441424,3.1},{51271,1.1},{439843,1.1},{48707,0.8},{48265,0.7},{279302,0.6},{1249658,0.6},{1265384,0.6} }, -- Frostscythe, Howling Blast, Glacial Advance, Obliterate, Frost Strike, Empower Rune Weapon, Exterminate, Pillar of Frost, Reaper's Mark, Anti-Magic Shell, Death's Advance, Frostwyrm's Fury, Breath of Sindragosa, Frostwyrm's Fury
      watch={ {465,95.2},{1459,92.9},{194879,88.7},{440289,84.8},{1230916,83.3},{440290,83.1},{456370,81.1},{207203,70.3},{53365,59.3},{1297365,58.9} }, -- Devotion Aura, Arcane Intellect, Icy Talons, Rune Carved Plates, Killing Streak, Rune Carved Plates, Cryogenic Chamber, Frost Shield, Unholy Strength, Freezing Tempest
      coach={ cn="怎么打：打群怪把湮灭换成冰霜之镰，凛风冲击照常吃触发，冰川突进对准一条线的怪放。单体目标（精英/boss）切回湮灭主键。盯什么：冰爪 攻速层（92.5%覆盖）——它靠持续输出维持，赶路或换怪群时断了会明显掉伤害，接战后第一时间把层数叠回来。", en="How to play: Swap Obliterate for Frostscythe on packs, keep Howling Blast for procs, and aim Glacial Advance down a line of enemies. Switch back to Obliterate on single elites and bosses. Watch: Icy Talons (92.5% uptime) — it's sustained by continuous attacks, drops during transitions, so rebuild stacks immediately on engagement." },
    },
  },
  ["DEATHKNIGHT/UNHOLY"] = {
    specID=252,
    raid={
      n=5, dur=538, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Leedlle", server="Silvermoon", region="EU", seq={77575,85948,458128,1247378,1247378,1259633,42650,1233448,1242174,1242174,433895,1242174} },
        { player="okkeujukgiya", server="ajeusyara", region="KR", seq={77575,85948,458128,1259633,42650,1233448,343294,1247378,1242174,1242174,1242174,1247378} },
        { player="Glizzard", server="Sylvanas", region="EU", seq={77575,85948,458128,1259633,42650,1233448,1247378,1242174,1247378,1242174,343294,1242174} },
      },
      core={ {433895,13.0},{47541,10.8},{55090,8.3},{1242174,7.0},{1247378,3.3},{458128,3.0},{85948,3.0},{343294,2.2},{49576,1.4},{48265,1.4},{1271967,1.3},{1233448,1.3},{48707,0.9},{42650,0.7} }, -- Vampiric Strike, Death Coil, Scourge Strike, Necrotic Coil, Putrefy, Festering Scythe, Festering Strike, Soul Reaper, Death Grip, Death's Advance, Blightfall, Dark Transformation, Anti-Magic Shell, Army of the Dead
      watch={ {1256576,97.4},{1241077,96.8},{372014,93.5},{1254252,92.8},{1287771,85.6},{434159,72.7},{390260,64.7},{1266687,61.5},{1229746,61.0},{51460,57.9} }, -- Forbidden Sacrifice, Festering Scythe, Visage, Lesser Ghoul, Rune of Masterful Cunning, Visceral Strength, Commander of the Dead, Alnscorned Essence, Arcanoweave Insight, Runic Corruption
      coach={ cn="怎么打：天灾打击按得远比其他键勤（顶尖23.5次/分），脓疮打击只为补脓疮（3.2次/分就够），凋零缠绕泄符能。黑暗突变按 CD（1.4次/分），灵魂收割留给斩杀段。盯什么：脓疮数量别清空也别溢出——天灾打击要有疮可爆；黑暗突变的石像鬼窗口内资源全倾泻。", en="How to play: Scourge Strike dwarfs every other button (top players: 23.5/min); Festering Strike exists only to apply wounds (3.2/min is enough), Death Coil dumps runic power. Dark Transformation on cooldown (1.4/min); save Soul Reaper for execute. Watch: wound count — never empty, never capped, Scourge Strike needs wounds to burst; dump all resources inside Dark Transformation windows." },
    },
    mplus={
      n=8, dur=1670,
      core={ {433895,13.7},{207317,6.4},{55090,5.5},{47541,4.7},{383269,3.8},{1247378,3.3},{1242174,2.8},{458128,2.6},{85948,2.6},{43265,1.5},{1233448,1.1},{77575,0.8},{48265,0.8},{48707,0.7} }, -- Vampiric Strike, Epidemic, Scourge Strike, Death Coil, Graveyard, Putrefy, Necrotic Coil, Festering Scythe, Festering Strike, Death and Decay, Dark Transformation, Outbreak, Death's Advance, Anti-Magic Shell
      watch={ {1254252,93.7},{433925,89.6},{1241077,89.2},{1241569,87.1},{1268917,84.1},{194879,83.0},{1242998,82.6},{1256576,79.9},{1287772,75.2},{434159,63.5} }, -- Lesser Ghoul, Essence of the Blood Queen, Festering Scythe, Clawing Shadows, Unholy Aura, Icy Talons, Lesser Ghoul, Forbidden Sacrifice, Rune of Critical Power, Visceral Strength
      coach={ cn="怎么打：群怪用扩散代替凋零缠绕泄符能，灾殃坟茔丢进怪堆，天灾打击照常主键。进新怪群前留好符文，先脓疮打击铺脓疮再开打。盯什么：冰爪 攻速层（90%）别断；脓疮管理在 AOE 里更容易崩——多目标时盯紧主要目标的脓疮层数，别打空。", en="How to play: On packs, spend runic power on Epidemic instead of Death Coil, drop Graveyard into the pile, and keep Scourge Strike as your main button. Bank runes before each new pack so you can apply wounds with Festering Strike first. Watch: keep Icy Talons (90%) rolling; wound management collapses easily in AoE — track your primary target's wounds and never strike without them." },
    },
  },
  ["DEMONHUNTER/DEVAURER"] = {
    specID=1480,
    raid={
      n=5, dur=547, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="魂魄妖夢", server="永恒之井", region="CN", seq={1223412,1241937,1223412,1223412,1223412,473662,1223412,1223412,473662,1223412,1223412,1223412} },
        { player="Floriodh", server="Area 52", region="US", seq={473662,1223412,1223412,1223412,1223412,473662,1226019,1223412,1223412,473662,1223412,1223412} },
        { player="Velnias", server="Hyjal", region="EU", seq={473662,1223412,1223412,1223412,473662,1223412,1223412,1223412,473662,1226019,1223412,1223412} },
      },
      core={ {473728,6.6},{473662,6.5},{1217610,6.5},{1245470,3.7},{1245453,3.5},{198793,3.1},{1226019,2.9},{1241937,2.6},{1245414,2.5},{1245483,1.3},{1259431,1.2},{1245412,1.2},{1246167,0.6},{1260459,0.6} }, -- Void Ray, Consume, Devour, Reaper's Toll, Cull, Vengeful Retreat, Reap, Soul Immolation, Voidblade, Pierce the Veil, Predator's Wake, Voidblade, The Hunt, Nullsight
      watch={ {1245577,88.9},{1287771,86.7},{1241759,60.0},{453314,54.5},{1225789,49.9},{372014,46.0},{1217607,45.8},{1227702,41.8},{382024,41.2},{1229746,35.1} }, -- Soul Fragments, Rune of Masterful Cunning, Genius Insight, Enduring Torment, Void Metamorphosis, Visage, Void Metamorphosis, Collapsing Star, Earthliving Weapon, Arcanoweave Insight
      coach={ cn="怎么打：Devour 是主填充（顶尖22次/分），吞噬回收灵魂碎片，虚空射线7.3次/分穿插。Collapsing Star 按 CD（3.8次/分），灵魂献祭是大 CD 对齐爆发。盯什么：灵魂碎片（顶尖覆盖97.3%=场上几乎永远有碎片可吃）——吞噬别让碎片烂在地上；Collapsing Star 窗口覆盖64%，窗口内输出全压进去。", en="How to play: Devour is your main filler (top players: 22/min), Consume harvests soul fragments, Void Ray weaves in at 7.3/min. Collapsing Star on cooldown (3.8/min); Soul Immolation is the big cooldown to align bursts with. Watch: soul fragments (97.3% top uptime = fragments are almost always available) — Consume them, don't let them rot; Collapsing Star windows cover 64% of the fight, stack your damage inside them." },
    },
    mplus={
      n=8, dur=1769,
      core={ {1217610,16.6},{473662,7.3},{473728,6.2},{1221150,3.2},{1241937,1.5},{131347,0.7},{198589,0.5},{1250533,0.5} }, -- Devour, Consume, Void Ray, Collapsing Star, Soul Immolation, Glide, Blur, Freightrunner's Flask
      watch={ {1232310,92.2},{1245577,90.2},{1229746,64.9},{1256301,57.2},{1241759,55.3},{1217607,52.8},{1227702,52.7},{1242504,52.2},{1256322,47.7},{1227338,46.3} }, -- Feast of Souls, Soul Fragments, Arcanoweave Insight, Voidfall, Genius Insight, Void Metamorphosis, Collapsing Star, Emptiness, Voidfall, Impending Apocalypse
      coach={ cn="怎么打：和团本同一套手法，吞蚀 主键、吞噬虚空射线穿插，坍缩之星 对准怪群中心放（大秘境里它更值钱）。疾影别只当保命技，按节奏用能平滑承伤。盯什么：灵魂盛宴 覆盖95.5%——灵魂碎片的回收别断，碎片在地上没吃等于白产。", en="How to play: Same hands as raid — Devour as the main button, Consume and Void Ray woven in, Collapsing Star aimed at pack centers (it's worth more here). Use Blur rhythmically, not just in emergencies. Watch: Feast of Souls sits at 95.5% — never break the soul fragment pickup loop; fragments left on the ground are wasted production." },
    },
  },
  ["DEMONHUNTER/HAVOC"] = {
    specID=577,
    raid={
      n=5, dur=545, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Verrottung", server="Blackrock", region="EU", seq={370965,370966,213243,232893,198013,258860,210152,201427,210152,228537,201427,198793} },
        { player="Yunadh", server="Eredar", region="EU", seq={427917,1250533,198013,370965,370966,213243,232893,258860,210152,210152,201427,198793} },
        { player="Vynz", server="Blackhand", region="EU", seq={383781,195072,198013,370965,370966,258860,210152,210152,201427,198793,228537,200166} },
      },
      core={ {162794,10.4},{201427,9.7},{210152,6.6},{232893,2.7},{198793,2.3},{188499,2.2},{198013,2.2},{258920,2.1},{195072,1.7},{185123,1.4},{258860,1.3},{370965,0.9},{452497,0.7},{198589,0.7} }, -- Chaos Strike, Annihilation, Death Sweep, Felblade, Vengeful Retreat, Blade Dance, Eye Beam, Immolation Aura, Fel Rush, Throw Glaive, Essence Break, The Hunt, Abyssal Gaze, Blur
      watch={ {1459,96.4},{208628,89.4},{1287772,84.9},{465,84.9},{372014,72.6},{1229746,69.8},{453314,56.5},{1241761,56.4},{162264,43.7},{258920,41.2} }, -- Arcane Intellect, Exergy, Rune of Critical Power, Devotion Aura, Visage, Arcanoweave Insight, Enduring Torment, Precision of the Dragonhawk, Metamorphosis, Immolation Aura
      coach={ cn="怎么打：怒气喂混乱打击，变形期间它变成灭杀、刃舞变成死亡横扫——顶尖玩家一半时间在变形里（覆盖49.6%），所以灭杀次数反超混乱打击。眼棱和刃舞按 CD，邪能之刃补怒气，复仇回避当输出技主动按（2.4次/分）。盯什么：变形剩余时间——窗口内优先把眼棱、死亡横扫全打进去；怒气别溢出。", en="How to play: Fury feeds Chaos Strike; inside Metamorphosis it becomes Annihilation and Blade Dance becomes Death Sweep — top players spend half the fight transformed (49.6% uptime), which is why Annihilation counts exceed Chaos Strike. Eye Beam and Blade Dance on cooldown, Felblade refills fury, and Vengeful Retreat is pressed offensively (2.4/min). Watch: Metamorphosis time remaining — pack Eye Beam and Death Sweep inside the window; never cap fury." },
    },
    mplus={
      n=8, dur=1637,
      core={ {162794,8.9},{201427,7.8},{210152,5.9},{185123,3.4},{232893,2.5},{198793,2.0},{198013,1.9},{188499,1.9},{258920,1.7},{258860,1.4},{195072,1.0},{370965,0.8},{452497,0.7},{131347,0.7} }, -- Chaos Strike, Annihilation, Death Sweep, Throw Glaive, Felblade, Vengeful Retreat, Eye Beam, Blade Dance, Immolation Aura, Essence Break, Fel Rush, The Hunt, Abyssal Gaze, Glide
      watch={ {208628,83.8},{1287772,81.5},{453314,57.2},{1241759,53.2},{1229746,51.4},{1241761,50.9},{162264,42.5},{452416,40.3},{258920,35.8},{390192,34.4} }, -- Exergy, Rune of Critical Power, Enduring Torment, Genius Insight, Arcanoweave Insight, Precision of the Dragonhawk, Metamorphosis, Demonsurge, Immolation Aura, Ragefire
      coach={ cn="怎么打：主手法不变，多了高频投掷利刃——空档和远离怪的瞬间都用它补伤害。刃舞对准怪群放，眼棱扫一整排。复仇回避照常循环化使用，注意别把自己甩出怪群。盯什么：虚空浸染 覆盖96.9%是输出底线；刃舞放完看怪群存活，决定下一轮是续 AOE 还是转单体。", en="How to play: Same core hands, plus high-frequency Throw Glaive — fill every gap and ranged moment with it. Aim Blade Dance into packs and sweep full lines with Eye Beam. Keep cycling Vengeful Retreat, but don't launch yourself out of the pack. Watch: Void-Touched at 96.9% is your damage floor; after each Blade Dance, check pack health to decide between continuing AoE or swapping to single-target." },
    },
  },
  ["DEMONHUNTER/VENGEANCE"] = {
    specID=581,
    raid={
      n=3, dur=547, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Grìmbles", server="Hyjal", region="US", seq={203720,258920,204255,204255,225919,263642,225921,204255,204255,225919,263642,225921} },
        { player="Thanquiol", server="Stormreaver", region="US", seq={225919,263642,225921,1236616,204255,204255,204021,258920,204255,204596,204255,225919} },
        { player="上官月夜", server="奥尔加隆", region="CN", seq={258920,203720,204255,390163,1236616,213243,232893,204596,225919,263642,225921,204255} },
      },
      core={ {263642,15.1},{228477,12.8},{203720,5.8},{258920,4.1},{232893,2.9},{247454,1.6},{204596,1.2},{187827,1.1},{204021,0.9},{390163,0.8},{204157,0.7},{202138,0.6},{212084,0.6} }, -- Fracture, Soul Cleave, Demon Spikes, Immolation Aura, Felblade, Spirit Bomb, Sigil of Flame, Metamorphosis, Fiery Brand, Sigil of Spite, Throw Glaive, Sigil of Chains, Fel Devastation
      watch={ {1459,94.7},{1126,94.7},{6673,94.7},{462854,94.7},{1287774,88.1},{465,85.4},{1270547,81.5},{203981,65.5},{1252488,64.4},{1229746,61.6} }, -- Arcane Intellect, Mark of the Wild, Battle Shout, Skyfury, Rune of Burning Haste, Devotion Aura, Seething Anger, Soul Fragments, Masterful Hunt, Arcanoweave Insight
      coach={ cn="怎么打：破裂是产能主键（顶尖18.3次/分），攒碎片和怒气，灵魂裂劈和幽魂炸弹消耗。献祭光环按 CD 保持（覆盖74.6%），邪能之刃补缝。恶魔尖刺别屯着——顶尖覆盖87.6%，物理承伤期几乎常驻。盯什么：恶魔尖刺的层数和覆盖（87.6%是顶尖标准）；灵魂碎片数量，裂劈和幽魂炸弹要有碎片才值。", en="How to play: Fracture is your builder (top players: 18.3/min), generating fragments and fury; Soul Cleave and Spirit Bomb spend them. Keep Immolation Aura rolling on cooldown (74.6% uptime), Felblade fills gaps. Don't hoard Demon Spikes — top players hold 87.6% uptime, nearly permanent through physical damage. Watch: Demon Spikes charges and uptime (87.6% is the top-player bar); soul fragment count — Soul Cleave and Spirit Bomb only pay off with fragments banked." },
    },
    mplus={
      n=8, dur=1827,
      core={ {263642,15.0},{228477,14.8},{203720,5.4},{258920,4.3},{247454,3.3},{187827,2.0},{204596,1.4},{204021,1.2},{212084,1.2},{131347,1.2},{232893,1.0},{390163,0.8},{204157,0.6} }, -- Fracture, Soul Cleave, Demon Spikes, Immolation Aura, Spirit Bomb, Metamorphosis, Sigil of Flame, Fiery Brand, Fel Devastation, Glide, Felblade, Sigil of Spite, Throw Glaive
      watch={ {465,97.4},{203819,95.5},{212988,93.9},{1270547,87.0},{1287774,83.1},{203981,66.4},{393009,64.7},{258920,64.4},{1229746,60.7},{1241762,56.6} }, -- Devotion Aura, Demon Spikes, Painbringer, Seething Anger, Rune of Burning Haste, Soul Fragments, Fel Flame Fortification, Immolation Aura, Arcanoweave Insight, Frenzied Focus
      coach={ cn="怎么打：破裂攒灵魂碎片、灵魂裂劈花掉——这对循环永远在转。幽魂炸弹在碎片≥4时放收益最高。恶魔尖刺别存着：看到物理怪抬手就按，顶尖玩家把它按到7次/分接近填充技。献祭光环 CD 好了就开。盯什么：自己脚下的碎片及时吸收；恶魔尖刺增益在承伤瞬间必须在线，掉了立刻补。", en="How to play: Fracture builds soul fragments, Soul Cleave spends them — that loop never stops. Spirit Bomb pays best at 4+ fragments. Don't bank Demon Spikes: press it as physical hits wind up — top players use it at 7/min, near filler frequency. Immolation Aura on cooldown. Watch: absorb your fragments promptly; Demon Spikes must be active the moment physical damage lands — reapply instantly if it drops." },
    },
  },
  ["DRUID/BALANCE"] = {
    specID=102,
    raid={
      n=5, dur=524, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Cotti", server="Tarren Mill", region="EU", seq={190984,93402,8921,1233272,194153,202770,1293316,102560,78674,78674,78674,194153} },
        { player="yakppannoru", server="ajeusyara", region="KR", seq={194153,8921,93402,202770,1293316,102560,78674,194153,191034,78674,78674,194153} },
        { player="Boomanddown", server="Thrall", region="EU", seq={190984,8921,93402,202770,102560,1236616,1293316,194153,78674,194153,194153,78674} },
      },
      core={ {194153,12.8},{78674,11.0},{191034,7.1},{93402,5.8},{8921,5.2},{202770,2.4},{1233272,1.9},{102560,0.7},{22812,0.6},{1293316,0.5},{102383,0.4} }, -- Starfire, Starsurge, Starfall, Sunfire, Moonfire, Fury of Elune, Lunar Eclipse, Incarnation: Chosen of Elune, Barkskin, Empowering Venom, Wild Charge
      watch={ {1303480,96.3},{465,90.3},{279709,84.0},{1287772,81.9},{343648,67.7},{1229746,67.5},{48518,67.3},{1301768,67.3},{139,65.7},{462568,46.7} }, -- Orbit Breaker, Devotion Aura, Starlord, Rune of Critical Power, Solstice, Arcanoweave Insight, Eclipse (Lunar), Akil'zon's Clarity, Renew, Elemental Resistance
      coach={ cn="怎么打：愤怒持续填充推日蚀（顶尖23.9次/分），星能喂星涌术（13.8次/分），阳炎术和月火术全程不掉。星辰坠落在单体也按（7.7次/分，配合天赋收益），自然之力和艾露恩之怒按 CD。盯什么：星辰领主层数（顶尖覆盖85.3%）——星涌术打得勤它才常驻；日蚀窗口（太阳日蚀覆盖71.8%），窗口内愤怒伤害更高。", en="How to play: Wrath fills constantly to push Eclipse (top players: 23.9/min), Astral Power feeds Starsurge (13.8/min), and Sunfire plus Moonfire never drop. Starfall gets pressed even on single target (7.7/min with the right talents); Force of Nature and Fury of Elune on cooldown. Watch: Starlord stacks (85.3% top uptime) — frequent Starsurges keep it rolling; Eclipse windows (Solar at 71.8% uptime) where Wrath hits harder." },
    },
    mplus={
      n=8, dur=1686,
      core={ {194153,15.0},{191034,8.6},{78674,6.2},{8921,3.9},{93402,2.6},{202770,2.0},{1233272,1.7},{102560,0.5},{24858,0.4},{22812,0.4} }, -- Starfire, Starfall, Starsurge, Moonfire, Sunfire, Fury of Elune, Lunar Eclipse, Incarnation: Chosen of Elune, Moonkin Form, Barkskin
      watch={ {6673,95.6},{1303480,95.4},{378992,93.7},{24858,93.7},{1295057,89.7},{279709,77.0},{1287771,75.3},{1264426,64.2},{48518,57.5},{1301768,57.0} }, -- Battle Shout, Orbit Breaker, Lycara's Teachings, Moonkin Form, Tidal Insight, Starlord, Rune of Masterful Cunning, Void-Touched, Eclipse (Lunar), Akil'zon's Clarity
      coach={ cn="怎么打：进怪群先把月火/阳炎甩到每个目标上（DOT 是隐形输出大头），然后星火术读条、星辰坠落保持常驻、星能给星涌术。艾露恩之怒 CD 好了对准怪群放。盯什么：星辰坠落的剩余时间——它快结束而怪还没死就续；保持枭兽形态别乱切（顶尖玩家94%时间在鸟里）。", en="How to play: Open packs by flinging Moonfire/Sunfire onto every target (DoTs are the hidden damage share), then channel Starfire, keep Starfall permanently down, and feed Astral Power to Starsurge. Fury of Elune on cooldown into packs. Watch: Starfall's remaining duration — recast if the pack will outlive it; stay in Moonkin Form (top players spend 94% of the run in it)." },
    },
  },
  ["DRUID/FERAL"] = {
    specID=103,
    raid={
      n=5, dur=561, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="魍魉叔叔丶", server="影之哀伤", region="CN", seq={5217,1822,155625,1079,1236616,106951,1293316,274837,22568,391528,22568,1079} },
        { player="喵喵猫猫喵喵", server="贫瘠之地", region="CN", seq={1822,5217,155625,106951,1236616,1079,274837,22568,5221,22568,5221,22568} },
        { player="yasaenguinoru", server="ajeusyara", region="KR", seq={106951,1297761,5217,1822,274837,1079,22568,155625,22568,391528,22568,1822} },
      },
      core={ {5221,13.2},{22568,11.8},{1822,5.2},{155625,4.8},{1079,3.1},{106785,2.1},{5217,1.9},{274837,1.9},{8936,1.5},{285381,1.5},{106951,0.5},{391528,0.5},{77764,0.4},{22812,0.4} }, -- Shred, Ferocious Bite, Rake, Moonfire, Rip, Swipe, Tiger's Fury, Feral Frenzy, Regrowth, Primal Wrath, Berserk, Convoke the Spirits, Stampeding Roar, Barkskin
      watch={ {465,93.7},{69369,85.8},{372014,72.6},{1229746,63.3},{1241715,62.0},{1301600,50.0},{5217,46.4},{135700,45.8},{391876,44.5},{382024,42.1} }, -- Devotion Aura, Predatory Swiftness, Visage, Arcanoweave Insight, Might of the Void, Halazzi's Fury, Tiger's Fury, Clearcasting, Frantic Momentum, Earthliving Weapon
      coach={ cn="怎么打：撕碎攒连击点（顶尖19.9次/分），凶猛撕咬满星泄（13.6次/分），斜掠、割裂、月火三个 DoT 全程保持。猛虎之怒按 CD 并对齐野性狂乱（各2次/分）。掠食者的迅捷触发的免费愈合顺手打掉。盯什么：猛虎之怒覆盖（顶尖50.5%=每个 CD 都按）；清晰预兆触发（覆盖46.7%）——亮了优先消耗，撕碎免费。", en="How to play: Shred builds combo points (top players: 19.9/min), Ferocious Bite spends at full points (13.6/min), and Rake, Rip, and Moonfire stay up permanently. Tiger's Fury on cooldown, aligned with Feral Frenzy (2/min each). Spend free Predatory Swiftness Regrowths as they proc. Watch: Tiger's Fury uptime (top players: 50.5% = every cooldown used); Clearcasting procs (46.7% uptime) — consume them immediately for free Shreds." },
    },
    mplus={
      n=8, dur=1684,
      core={ {106785,10.5},{1822,7.4},{5221,7.4},{22568,5.6},{285381,4.7},{441591,4.3},{5217,1.7},{1079,1.2},{1243807,1.1},{5487,0.8},{8936,0.6},{22812,0.6},{106951,0.4},{22842,0.4} }, -- Swipe, Rake, Shred, Ferocious Bite, Primal Wrath, Ravage, Tiger's Fury, Rip, Frantic Frenzy, Bear Form, Regrowth, Barkskin, Berserk, Frenzied Regeneration
      watch={ {1263939,96.4},{378990,94.3},{768,94.3},{69369,89.4},{207400,75.7},{382024,67.6},{1229746,65.8},{462568,64.5},{1241715,55.0},{441825,51.5} }, -- Unseen Predator's Craving, Lycara's Teachings, Cat Form, Predatory Swiftness, Ancestral Vigor, Earthliving Weapon, Arcanoweave Insight, Elemental Resistance, Might of the Void, Killing Strikes
      coach={ cn="怎么打：群怪改用横扫攒星，终结技用原始之怒把割裂一次铺满全场；凶猛撕咬留给该死的优先目标。斜掠照常上。蹂躏 触发亮了优先按。盯什么：怪群里每个目标的割裂覆盖（原始之怒续）；保持猎豹形态（91%），治疗压力大也先确认再切熊。", en="How to play: On packs, build with Swipe and finish with Primal Wrath to blanket Rip across everything; save Ferocious Bite for priority kill targets. Keep Rake up as usual, and press Ravage procs when they light. Watch: Rip coverage on every pack member (re-spread via Primal Wrath); stay in Cat Form (91%) — verify before shifting bear even under pressure." },
    },
  },
  ["DRUID/GUARDIAN"] = {
    specID=104,
    raid={
      n=5, dur=519, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Sol", server="Tichondrius", region="US", seq={1236616,77758,1270292,204066,1822,33917,1293316,77758,102558,1252871,1269658,400254} },
        { player="Réversibel", server="Blackhand", region="EU", seq={1270292,204066,1822,1250557,1236616,102558,1269658,77758,33917,33917,77758,400254} },
        { player="Ahrilia", server="Stormrage", region="US", seq={1270292,204066,1236616,1252871,1293326,102558,1295735,1269658,33917,77758,33917,400254} },
      },
      core={ {33917,14.4},{77758,12.6},{192081,11.0},{213771,7.6},{400254,6.8},{22842,1.4},{204066,1.4},{1252871,1.3},{22812,0.8},{16979,0.7},{1269658,0.5},{102558,0.5},{77761,0.3} }, -- Mangle, Thrash, Ironfur, Swipe, Raze, Frenzied Regeneration, Lunar Beam, Red Moon, Barkskin, Wild Charge, Wild Guardian, Incarnation: Guardian of Ursoc, Stampeding Roar
      watch={ {1253600,95.3},{465,80.2},{1251877,72.1},{192081,72.0},{139,64.0},{1241715,55.7},{1229746,29.2},{102558,26.8},{204066,26.4},{156322,23.0} }, -- Lunar Wrath, Devotion Aura, Gift of an Ancient Guardian, Ironfur, Renew, Might of the Void, Arcanoweave Insight, Incarnation: Guardian of Ursoc, Lunar Beam, Eternal Flame
      coach={ cn="怎么打：裂伤 CD 好了必按（顶尖18.3次/分），痛击保持流血，怒气在进攻期喂摧折（10.8次/分）、承伤期喂铁鬃。明月普照和赤红之月按 CD（明月覆盖44.8%=几乎每次都站满圈）。盯什么：铁鬃层数——物理大伤害前提前叠；明月普照的圈，输出和减伤都要求你站在里面。", en="How to play: Mangle on cooldown always (top players: 18.3/min), Thrash keeps the bleed rolling, and rage goes to Raze when attacking (10.8/min) or Ironfur when tanking damage. Lunar Beam and Red Moon on cooldown (44.8% Lunar Beam uptime = standing in the full beam nearly every cast). Watch: Ironfur stacks — pre-stack before big physical hits; your Lunar Beam circle, since both damage and mitigation want you inside it." },
    },
    mplus={
      n=8, dur=1667,
      core={ {192081,23.5},{8921,14.5},{77758,14.3},{33917,12.0},{22842,1.4},{204066,1.2},{22812,1.1},{213771,0.6},{1269658,0.5},{102558,0.5},{6807,0.4},{99,0.3},{61336,0.3} }, -- Ironfur, Moonfire, Thrash, Mangle, Frenzied Regeneration, Lunar Beam, Barkskin, Swipe, Wild Guardian, Incarnation: Guardian of Ursoc, Maul, Incapacitating Roar, Survival Instincts
      watch={ {378991,94.2},{5487,94.2},{1251877,91.9},{192081,91.9},{1287770,81.7},{1295582,74.8},{372505,59.6},{1241715,52.8},{1229746,50.7},{213708,41.6} }, -- Lycara's Teachings, Bear Form, Gift of an Ancient Guardian, Ironfur, Rune of the Versatile Warrior, Focus of Ula'tek, Ursoc's Fury, Might of the Void, Arcanoweave Insight, Galactic Guardian
      coach={ cn="怎么打：大秘境换打法——月火术见缝插针地按（顶尖玩家25次/分），痛击打 AOE，怒气几乎全喂铁鬃。铁鬃要按成肌肉记忆：物理怪群里有怒气就点，可以叠层。明月普照 CD 好了对怪群放。盯什么：自己身上的铁鬃图标——顶尖玩家覆盖91%，它就是你的硬度；掉了而怪还在打你，立刻补上。淤血 触发亮了裂伤免费，顺手按。", en="How to play: Mythic+ flips the playbook — weave Moonfire constantly (top players hit 25/min), Thrash for AoE, and feed nearly all rage into Ironfur. Make Ironfur muscle memory: in physical packs, press it whenever you have rage; it stacks. Lunar Beam on cooldown into packs. Watch: your own Ironfur icon — top players hold 91% uptime, and it IS your toughness; if it drops while mobs are hitting you, reapply now. Press free Mangles when Gore procs." },
    },
  },
  ["DRUID/RESTORATION"] = {
    specID=105,
    raid={
      n=5, dur=537, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Penguindruid", server="Area 52", region="US", seq={8936,774,18562,155777,774,132158,18562,8936,48438,391528,33763,8936} },
        { player="Sellene", server="Burning Blade", region="US", seq={1291894,774,774,33763,132158,8936,391528,18562,774,774,1822,5221} },
        { player="Kokokk", server="冰风岗", region="CN", seq={774,22812,18562,132158,155777,774,48438,391528,157982,740,157982,157982} },
      },
      core={ {8936,16.9},{774,13.3},{18562,5.1},{48438,3.9},{33763,3.5},{132158,0.9},{391528,0.8},{88423,0.7},{5176,0.7},{22812,0.6},{29166,0.3},{740,0.3} }, -- Regrowth, Rejuvenation, Swiftmend, Wild Growth, Lifebloom, Nature's Swiftness, Convoke the Spirits, Nature's Cure, Wrath, Barkskin, Innervate, Tranquility
      watch={ {439888,96.3},{1268058,94.9},{207640,93.8},{1287774,87.5},{400126,77.8},{465,76.8},{1302255,72.8},{1229746,70.7},{1266687,63.2},{1241762,58.6} }, -- Root Network, Deepening Temptation, Abundance, Rune of Burning Haste, Forestwalk, Devotion Aura, Genesis, Arcanoweave Insight, Alnscorned Essence, Frenzied Focus
      coach={ cn="怎么打：治疗的关键是提前量——团队要吃伤害前3-5秒铺回春（顶尖20.5次/分），伤害落地野性成长跟上，单点掉血用愈合（17.5次/分）+迅捷治愈秒。生命绽放全程挂坦克。万灵之召留给最疼的轴。盯什么：DBM/团队时间轴比血条更重要——HOT 要先于伤害生效；迅捷治愈 CD（4.6次/分=转好就用），它是唯一的瞬发应急。", en="How to play: Healing is about lead time — blanket Rejuvenation 3-5 seconds before raid damage (top players: 20.5/min), follow with Wild Growth as it lands, and spot-heal with Regrowth (17.5/min) plus Swiftmend. Lifebloom lives on the tank. Save Convoke for the hardest hit. Watch: the fight timeline matters more than health bars — HoTs must tick before damage arrives; Swiftmend's cooldown (4.6/min = used on refresh), your only instant emergency button." },
    },
    mplus={
      n=8, dur=1789,
      core={ {774,11.6},{8936,6.8},{18562,4.1},{33763,4.0},{48438,2.7},{1822,1.7},{5221,1.2},{1079,1.0},{768,0.9},{8921,0.9},{88423,0.8},{391528,0.7},{22812,0.5},{102342,0.5} }, -- Rejuvenation, Regrowth, Swiftmend, Lifebloom, Wild Growth, Rake, Shred, Rip, Cat Form, Moonfire, Nature's Cure, Convoke the Spirits, Barkskin, Ironbark
      watch={ {1232285,96.6},{378989,84.8},{1287774,78.7},{1294727,74.9},{207640,67.6},{1229746,57.2},{400126,52.7},{1302255,44.7},{439530,37.4},{16870,27.3} }, -- Efflorescence, Lycara's Teachings, Rune of Burning Haste, Well Fed, Abundance, Arcanoweave Insight, Forestwalk, Genesis, Symbiotic Blooms, Clearcasting
      coach={ cn="怎么打：治疗没压力时果断切猫输出（斜掠/撕碎/割裂），队伍要吃 AOE 前切回来铺回春+野性成长。生命绽放常驻坦克。诀窍是回春保持多个目标在跳——丰饶 层数（96%覆盖）会让愈合越来越便宜。盯什么：坦克血线趋势（不是瞬时值），以及自己回春的存量——它既是治疗也是 丰饶 的燃料。", en="How to play: When healing is light, swap to cat and deal damage (Rake/Shred/Rip); shift back before group damage to blanket Rejuvenation + Wild Growth. Keep Lifebloom on the tank. The trick: keep Rejuvenation ticking on several targets — Abundance stacks (96% uptime) make each Regrowth cheaper. Watch: the tank's health trend, and your live Rejuv count — it's both healing and Abundance fuel." },
    },
  },
  ["EVOKER/AUGMENTATION"] = {
    specID=1473,
    raid={
      n=4, dur=525, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Trinvoker", server="Turalyon", region="EU", seq={431443,403631,409311,409311,395152,370553,357208,396286,1260459,404977,395152,409311} },
        { player="Augmentfluup", server="Tarren Mill", region="EU", seq={395152,409311,409311,403631,1260459,370553,396286,357208,404977,357208,396286,409311} },
        { player="Robsvoker", server="Illidan", region="US", seq={395152,409311,403631,370553,357208,396286,409311,404977,431443,396286,357208,409311} },
      },
      core={ {395160,16.2},{431443,9.8},{409311,6.4},{396286,5.6},{357208,4.7},{358267,3.3},{395152,2.0},{370553,0.8},{363916,0.7},{358733,0.6},{403631,0.6},{404977,0.5},{374968,0.4} }, -- Eruption, Chrono Flames, Prescience, Upheaval, Fire Breath, Hover, Ebon Might, Tip the Scales, Obsidian Scales, Glide, Breath of Eons, Time Skip, Time Spiral
      watch={ {395296,93.0},{1229746,75.3},{431654,72.9},{358267,66.6},{1241715,58.4},{408005,52.9},{1259171,46.8},{410263,43.7},{1297728,37.9},{431698,37.9} }, -- Ebon Might, Arcanoweave Insight, Primacy, Hover, Might of the Void, Momentum Shift, Duplicate, Inferno's Blessing, Magnified Fate, Temporal Burst
      coach={ cn="怎么打：增辉的输出就是队友的输出——黑檀之力按 CD 开（自身覆盖96.5%），先知先觉提前挂给爆发位（6.7次/分）。精华喂喷发（顶尖19.6次/分），地壳激变和火焰吐息按 CD，扭转天平配合大窗口瞬发满蓄力。盯什么：黑檀之力的剩余时间——它掉了你的全队增益就断了；先知先觉保持两个目标轮转不空档。", en="How to play: Augmentation's damage IS your allies' damage — Ebon Might on cooldown (96.5% self uptime), Prescience pre-applied to burst players (6.7/min). Essence feeds Eruption (top players: 19.6/min); Upheaval and Fire Breath on cooldown, with Tip the Scales for an instant max-empower during big windows. Watch: Ebon Might's remaining duration — if it drops, your raid-wide buff chain breaks; keep Prescience cycling on two targets with no gaps." },
    },
    mplus={
      n=8, dur=1774,
      core={ {395160,13.5},{361469,5.3},{409311,4.9},{396286,4.2},{357208,3.3},{358267,2.0},{395152,1.6},{358733,0.8},{442204,0.6},{363916,0.5},{370553,0.5},{1250533,0.5} }, -- Eruption, Living Flame, Prescience, Upheaval, Fire Breath, Hover, Ebon Might, Glide, Breath of Eons, Obsidian Scales, Tip the Scales, Freightrunner's Flask
      watch={ {465,95.4},{441248,92.3},{395296,74.2},{207400,71.5},{1287771,70.9},{382024,65.1},{462568,62.4},{1229746,60.2},{1241715,56.8},{408005,43.8} }, -- Devotion Aura, Unrelenting Siege, Ebon Might, Ancestral Vigor, Rune of Masterful Cunning, Earthliving Weapon, Elemental Resistance, Arcanoweave Insight, Might of the Void, Momentum Shift
      coach={ cn="怎么打：手法同团本——黑檀之力常驻、先知先觉轮转、喷发主键、吐息卡CD。五人本的额外要求：持续施法别停（不懈围攻 覆盖92%靠这个），赶路转场也尽量保持有东西在读条。盯什么：黑檀之力与队伍开怪节奏的对齐——在坦克拉下一波之前就把增益续好。", en="How to play: Same hands as raid — Ebon Might permanent, Prescience rotating, Eruption as the main button, breaths on cooldown. The five-man extra: never stop casting (Unrelenting Siege's 92% uptime depends on it), even through transitions. Watch: sync Ebon Might with pull rhythm — refresh it before the tank grabs the next pack." },
    },
  },
  ["EVOKER/DEVASTATION"] = {
    specID=1467,
    raid={
      n=5, dur=542, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Aphrokin", server="Zul'jin", region="US", seq={361469,433874,375087,1293316,1236616,370553,357208,356995,359073,362969,358267,356995} },
        { player="Hxssion", server="Area 52", region="US", seq={361469,433874,375087,1236616,370553,357208,359073,356995,356995,356995,361469,356995} },
        { player="Creachy", server="Kil'jaeden", region="US", seq={361469,433874,375087,1236616,370553,359073,357208,356995,356995,356995,356995,358267} },
      },
      core={ {356995,16.5},{359073,6.8},{357208,6.1},{361469,4.5},{358267,3.8},{433874,2.4},{1292321,2.0},{363916,0.7},{370553,0.5},{1293316,0.5},{375087,0.5},{358733,0.4},{362969,0.3},{374968,0.3} }, -- Disintegrate, Eternity Surge, Fire Breath, Living Flame, Hover, Deep Breath, Unbound Flame, Obsidian Scales, Tip the Scales, Empowering Venom, Dragonrage, Glide, Azure Strike, Time Spiral
      watch={ {465,96.2},{1287772,86.0},{1229746,70.3},{375802,68.4},{411055,66.0},{358267,64.8},{1241715,60.0},{372470,56.7},{370901,50.3},{1271783,46.2} }, -- Devotion Aura, Rune of Critical Power, Arcanoweave Insight, Burnout, Imminent Destruction, Hover, Might of the Void, Scarlet Adaptation, Leaping Flames, Rising Fury
      coach={ cn="怎么打：裂解是核心引导（顶尖16.9次/分），打满别剪——它和永恒之涌、火焰吐息构成主轴。吐息类蓄力看场合：单体满蓄力收益最高。活化烈焰只是移动补缝（3.1次/分）。悬空保持施法机动（覆盖84.6%=顶尖几乎全程边飞边读条）。盯什么：精华别溢出——裂解要持续吃精华；燃尽触发（覆盖76.3%）让活化烈焰瞬发，移动轴前留着。", en="How to play: Disintegrate is your core channel (top players: 16.9/min) — let it finish, don't clip — alongside Eternity Surge and Fire Breath. Empower levels depend on context: max empower wins on single target. Living Flame is just a movement filler (3.1/min). Hover keeps you casting while mobile (84.6% uptime = top players basically fly and cast all fight). Watch: never cap essence — Disintegrate needs constant feeding; Burnout procs (76.3% uptime) make Living Flame instant, bank them for movement." },
    },
    mplus={
      n=8, dur=1629,
      core={ {356995,11.2},{359073,6.0},{357208,5.6},{361469,5.6},{358267,3.3},{357211,3.2},{433874,2.0},{1292321,1.6},{362969,1.4},{358733,1.3},{363916,0.5},{375087,0.4},{1293316,0.4},{370553,0.4} }, -- Disintegrate, Eternity Surge, Fire Breath, Living Flame, Hover, Pyre, Deep Breath, Unbound Flame, Azure Strike, Glide, Obsidian Scales, Dragonrage, Empowering Venom, Tip the Scales
      watch={ {441248,88.2},{370454,86.1},{1287772,79.6},{411055,62.7},{1229746,62.1},{358267,55.8},{375802,54.5},{1241715,52.5},{370901,38.6},{376850,36.5} }, -- Unrelenting Siege, Charged Blast, Rune of Critical Power, Imminent Destruction, Arcanoweave Insight, Hover, Burnout, Might of the Void, Leaping Flames, Power Swell
      coach={ cn="怎么打：群怪把精华改喂葬火（对准怪堆丢），裂解留给精英和 boss；火焰吐息尽量蓄到能扫到整群怪的角度再放。悬空照常保持移动输出。盯什么：怪群数量——3个以上葬火，少了切回裂解；火焰吐息的覆盖角度比时机更重要。", en="How to play: On packs, feed Essence into Pyre (thrown at the pile) and reserve Disintegrate for elites and bosses; angle Fire Breath to sweep the whole pack before releasing. Hover keeps you casting through movement. Watch: target count — Pyre at 3+, back to Disintegrate below; Fire Breath's coverage angle matters more than its timing." },
    },
  },
  ["EVOKER/PRESERVATION"] = {
    specID=1468,
    raid={
      n=5, dur=516, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Ambient", server="Bleeding Hollow", region="US", seq={370537,355936,355936,373861,355913,1265991,355913,1265991,364343,1265991,364343,1256581} },
        { player="Hastydwagon", server="Tichondrius", region="US", seq={370537,355936,355936,373861,355913,1265991,355913,1265991,364343,1256581,355913,1265991} },
        { player="Evoulker", server="Stonemaul", region="US", seq={355936,373861,355913,1265991,370564,355941,355941,373861,355913,1265991,355913,1265991} },
      },
      core={ {355913,11.7},{364343,8.5},{355936,5.5},{357208,4.8},{1256581,4.1},{373861,4.0},{361469,2.3},{358267,1.2},{360823,0.9},{358733,0.6},{370537,0.6},{370564,0.6},{370553,0.5},{366155,0.4} }, -- Emerald Blossom, Echo, Dream Breath, Fire Breath, Merithra's Blessing, Temporal Anomaly, Living Flame, Hover, Naturalize, Glide, Stasis (Store), Stasis (Release), Tip the Scales, Reversion
      watch={ {377102,96.7},{375583,89.8},{1287771,88.5},{465,84.4},{362877,74.3},{1229746,68.8},{1241759,60.4},{1266687,58.9},{1256579,53.1},{370901,51.9} }, -- Exhilarating Burst, Ancient Flame, Rune of Masterful Cunning, Devotion Aura, Temporal Compression, Arcanoweave Insight, Genius Insight, Alnscorned Essence, Merithra's Blessing, Leaping Flames
      coach={ cn="怎么打：回响铺给即将吃伤害的人（顶尖11.1次/分），梦境吐息一口气把回响全部引爆成 HOT（8.1次/分）——这个组合就是奶龙的核心。翡翠之花补面板，时空畸体配合大伤害轴。火焰吐息别忘了打（1.3次/分），治疗间隙补输出。盯什么：团队时间轴——回响要在伤害前铺好；精华和蓝量管理，大轴前留满。", en="How to play: Echo goes on players about to take damage (top players: 11.1/min), then Dream Breath detonates every Echo into rolling HoTs (8.1/min) — that combo IS Preservation. Emerald Blossom patches the grid, Temporal Anomaly lines up with big damage events. Don't forget Fire Breath (1.3/min) for damage in healing gaps. Watch: the raid timeline — Echoes must be placed before damage lands; manage essence and mana so you enter big phases full." },
    },
    mplus={
      n=8, dur=1708,
      core={ {356995,7.5},{355913,6.8},{355936,6.1},{357208,5.5},{361469,5.3},{373861,4.2},{1256581,4.1},{358267,1.3},{358733,1.1},{360823,0.6},{370537,0.5},{370553,0.5},{363916,0.5},{357170,0.5} }, -- Disintegrate, Emerald Blossom, Dream Breath, Fire Breath, Living Flame, Temporal Anomaly, Merithra's Blessing, Hover, Glide, Naturalize, Stasis (Store), Tip the Scales, Obsidian Scales, Time Dilation
      watch={ {372470,95.3},{375583,91.5},{390148,80.5},{1277482,78.2},{1287772,77.7},{443176,67.2},{1256579,59.9},{362877,59.6},{369299,57.4},{1297663,52.7} }, -- Scarlet Adaptation, Ancient Flame, Flow State, Voidlust, Rune of Critical Power, Lifespark, Merithra's Blessing, Temporal Compression, Essence Burst, Halazzi's Rite
      coach={ cn="怎么打：没人掉血就打输出（裂解照常引导），队伍要承伤前回响铺好、梦境吐息引爆。进怪群前先丢时空畸体铺一层盾。逆转挂给持续掉血的目标。盯什么：坦克进怪的时机（提前铺盾），时光压缩 层数（86%覆盖）——保持施法别长时间挂机。", en="How to play: Deal damage when nobody's dropping (channel Disintegrate as normal); before group damage, spread Echoes and detonate with Dream Breath. Pre-shield with Temporal Anomaly before each pull, Reversion on targets taking sustained damage. Watch: the tank's pull timing for pre-shields, and Temporal Compression stacks (86%) — keep casting, don't idle." },
    },
  },
  ["HUNTER/BEASTMASTERY"] = {
    specID=253,
    raid={
      n=5, dur=538, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Steveerwin", server="Blackmoore", region="EU", seq={217200,1236616,1293316,217200,19574,34026,193455,34026,217200,34026,193455,217200} },
        { player="Gârrúk", server="Blackmoore", region="EU", seq={271107,1236616,217200,217200,19574,1308188,34026,34026,1308188,217200,34026,217200} },
        { player="hwareulnaejianhneunsaram", server="garona", region="KR", seq={217200,19574,1236616,34026,217200,34026,193455,34026,217200,34026,193455,34026} },
      },
      core={ {34026,17.9},{193455,15.2},{217200,10.4},{1308188,6.8},{19574,2.0},{264735,0.5} }, -- Kill Command, Cobra Shot, Barbed Shot, Dire Beast, Bestial Wrath, Survival of the Fittest
      watch={ {246152,95.8},{471877,90.1},{1287771,86.0},{459731,85.2},{465,84.4},{372014,78.9},{1306960,65.3},{1276720,61.8},{382024,51.8},{139,50.3} }, -- Barbed Shot, Howl of the Pack Leader, Rune of Masterful Cunning, Huntmaster's Call, Devotion Aura, Visage, Dire Beast, Nature's Ally, Earthliving Weapon, Renew
      coach={ cn="怎么打：杀戮命令 CD 好了必按（顶尖19.1次/分），倒刺射击保持狂乱三层不断（11次/分），眼镜蛇射击泄集中值并给杀戮命令减 CD。狂野怒火按 CD 开（2次/分，覆盖50.6%）。盯什么：宠物狂乱的剩余时间——倒刺射击要在它掉之前接上；集中值别溢出也别打空，眼镜蛇射击的节奏跟着杀戮命令的 CD 走。", en="How to play: Kill Command on cooldown always (top players: 19.1/min), Barbed Shot keeps pet Frenzy at three stacks without dropping (11/min), and Cobra Shot dumps focus while reducing Kill Command's cooldown. Bestial Wrath on cooldown (2/min, 50.6% uptime). Watch: pet Frenzy's remaining duration — Barbed Shot must land before it falls; never cap or starve focus, pacing Cobra Shots around Kill Command's cooldown." },
    },
    mplus={
      n=8, dur=1687,
      core={ {34026,12.1},{193455,10.8},{217200,8.0},{1264359,4.1},{19574,1.7},{34477,0.6},{264735,0.6},{781,0.4},{257284,0.3} }, -- Kill Command, Cobra Shot, Barbed Shot, Wild Thrash, Bestial Wrath, Misdirection, Survival of the Fittest, Disengage, Hunter's Mark
      watch={ {246152,82.8},{471877,79.4},{1287771,79.0},{462568,68.9},{207400,68.6},{382024,65.2},{268877,63.9},{1276720,58.8},{1241761,52.6},{1229746,49.6} }, -- Barbed Shot, Howl of the Pack Leader, Rune of Masterful Cunning, Elemental Resistance, Ancestral Vigor, Earthliving Weapon, Beast Cleave, Nature's Ally, Precision of the Dragonhawk, Arcanoweave Insight
      coach={ cn="怎么打：核心三键不变，群怪加狂野鞭笞（对准怪群）。倒刺射击在多目标时优先保证狂乱不断，再考虑分给副目标。盯什么：狂乱层数依然是第一位；宠物嚎叫增益（86%覆盖）的触发节奏——它亮的时候宠物伤害更高，杀戮命令尽量压在里面。", en="How to play: Same three-button core, adding Wild Thrash aimed into packs. With multiple targets, Barbed Shot first protects Frenzy uptime, then spreads. Watch: Frenzy stacks remain priority one; track Howl of the Pack Leader's rhythm (86% uptime) — pet damage spikes while it's up, so line Kill Commands into it." },
    },
  },
  ["HUNTER/MARKSMANSHIP"] = {
    specID=254,
    raid={
      n=5, dur=510, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Imnotanorc", server="Tichondrius", region="US", seq={19434,212431,212431,260243,1297761,288613,257044,19434,185358,19434,185358,19434} },
        { player="Bîstand", server="Ragnaros", region="EU", seq={19434,212431,212431,383781,288613,257044,260243,19434,185358,19434,185358,19434} },
        { player="Notaudric", server="Area 52", region="US", seq={383781,212431,1236616,212431,260243,288613,257044,19434,185358,19434,185358,19434} },
      },
      core={ {19434,10.3},{185358,6.3},{56641,5.6},{257044,4.5},{212431,3.7},{257620,1.5},{53351,1.2},{260243,1.1},{288613,0.5},{264735,0.5},{1264949,0.5},{383781,0.5} }, -- Aimed Shot, Arcane Shot, Steady Shot, Rapid Fire, Explosive Shot, Multi-Shot, Kill Shot, Volley, Trueshot, Survival of the Fittest, Moonlight Chakram, Algeth'ar Puzzle
      watch={ {1253750,96.1},{372014,87.7},{1287772,84.3},{465,82.8},{389020,66.8},{1229746,63.1},{1241761,59.4},{204090,35.2},{1279347,33.8},{139,28.0} }, -- Stargazer, Visage, Rune of Critical Power, Devotion Aura, Bulletstorm, Arcanoweave Insight, Precision of the Dragonhawk, Bullseye, Quick Draw, Renew
      coach={ cn="怎么打：瞄准射击是核心炮（顶尖10.1次/分，两充能别屯满），黑蚀箭按节奏打（8.3次/分），精确射击触发用奥术射击消耗，稳固射击只在没事干时填充。急速射击按 CD（4.1次/分），百发百中对齐爆发轴。盯什么：弹幕风暴层数（覆盖86.1%）和精确射击触发（覆盖31.7%）——触发亮了优先消耗再继续读瞄准。", en="How to play: Aimed Shot is your cannon (top players: 10.1/min — don't sit on two charges), Black Arrow on rhythm (8.3/min), Precise Shots procs spent on Arcane Shot, and Steady Shot only as idle filler. Rapid Fire on cooldown (4.1/min), Trueshot aligned with burst windows. Watch: Bulletstorm stacks (86.1% uptime) and Precise Shots procs (31.7% uptime) — when lit, spend the proc before casting the next Aimed Shot." },
    },
    mplus={
      n=8, dur=1646,
      core={ {19434,7.8},{257620,7.7},{257044,4.0},{212431,3.1},{185358,2.9},{56641,2.8},{260243,1.1},{34477,0.7},{264735,0.6},{257284,0.4},{288613,0.4},{1264949,0.4},{781,0.3} }, -- Aimed Shot, Multi-Shot, Rapid Fire, Explosive Shot, Arcane Shot, Steady Shot, Volley, Misdirection, Survival of the Fittest, Hunter's Mark, Trueshot, Moonlight Chakram, Disengage
      watch={ {1253750,87.3},{1287772,79.0},{207400,72.9},{462568,67.8},{382024,64.5},{389020,60.4},{1229746,55.2},{1241761,54.0},{257622,51.4},{204090,46.5} }, -- Stargazer, Rune of Critical Power, Ancestral Vigor, Elemental Resistance, Earthliving Weapon, Bulletstorm, Arcanoweave Insight, Precision of the Dragonhawk, Trick Shots, Bullseye
      coach={ cn="怎么打：先多重射击挂上 戏法射击，再接瞄准射击/急速射击让它们跳弹打全群——顺序错了伤害差一截。黑蚀箭照 CD 用。盯什么：戏法射击 增益（覆盖40%，还有提升空间）——每轮 AOE 前确认它在身上；怪群剩血决定继续 AOE 还是转单体打优先目标。", en="How to play: Multi-Shot first to apply Trick Shots, THEN Aimed Shot/Rapid Fire so they ricochet across the pack — wrong order costs real damage. Black Arrow on cooldown. Watch: the Trick Shots buff (40% uptime — room to improve) — confirm it's up before each AoE burst; pack health decides whether to keep cleaving or swap to priority targets." },
    },
  },
  ["HUNTER/SURVIVAL"] = {
    specID=255,
    raid={
      n=3, dur=548, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Tozbek", server="Area 52", region="US", seq={1253859,1250646,259495,1261193,259489,259495,1264949,259489,186270,259495,259489,1262293} },
        { player="Proudidiot", server="Stormscale", region="EU", seq={259495,1250533,1250646,1253859,1261193,259489,259495,259495,259489,1264949,186270,259489} },
        { player="Farmaryna", server="Blackrock", region="EU", seq={259495,1253859,1250646,1261193,259495,259489,186270,1262293,186270,259489,1264949,259495} },
      },
      core={ {259489,13.5},{186270,8.0},{259495,7.4},{1261193,1.2},{1250646,0.9},{264735,0.7},{1264949,0.7},{257284,0.5},{781,0.5},{186257,0.3},{109304,0.3} }, -- Kill Command, Raptor Strike, Wildfire Bomb, Boomstick, Takedown, Survival of the Fittest, Moonlight Chakram, Hunter's Mark, Disengage, Aspect of the Cheetah, Exhilaration
      watch={ {259388,92.3},{1287772,87.5},{1264426,84.0},{260286,80.6},{1229746,60.6},{1241759,50.5},{1273155,45.6},{1292687,37.0},{139,35.0},{382024,34.8} }, -- Mongoose Fury, Rune of Critical Power, Void-Touched, Tip of the Spear, Arcanoweave Insight, Genius Insight, Raptor Swipe!, Shrapnel Bomb, Renew, Earthliving Weapon
      coach={ cn="怎么打：杀戮命令产能（顶尖14.6次/分），猛禽一击泄集中值（10.6次/分），野火炸弹 CD 好了必丢（6.8次/分）。矛尖优势的逻辑贯穿全程：杀戮命令先按，下一发技能吃增伤（覆盖84.4%）。狩魂一击留斩杀段。盯什么：矛尖优势的窗口——它覆盖84.4%意味着顶尖玩家几乎每个技能都吃到增伤；野火炸弹充能别屯。", en="How to play: Kill Command generates (top players: 14.6/min), Raptor Strike spends focus (10.6/min), Wildfire Bomb thrown on cooldown (6.8/min). Tip of the Spear logic runs the whole fight: Kill Command first, next ability eats the damage bonus (84.4% uptime). Save Takedown for execute. Watch: Tip of the Spear windows — 84.4% uptime means top players buff nearly every ability; never sit on Wildfire Bomb charges." },
    },
    mplus={
      n=8, dur=1722,
      core={ {259489,12.8},{186270,7.7},{259495,6.3},{1261193,1.8},{1250646,0.8},{264735,0.5},{34477,0.5},{1250533,0.5},{781,0.4},{257284,0.4} }, -- Kill Command, Raptor Strike, Wildfire Bomb, Boomstick, Takedown, Survival of the Fittest, Misdirection, Freightrunner's Flask, Disengage, Hunter's Mark
      watch={ {260249,90.5},{259388,89.4},{471877,81.8},{260286,73.5},{207400,68.7},{462568,64.2},{382024,58.4},{1241759,54.6},{1229746,54.4},{1273155,45.6} }, -- Bloodseeker, Mongoose Fury, Howl of the Pack Leader, Tip of the Spear, Ancestral Vigor, Elemental Resistance, Earthliving Weapon, Genius Insight, Arcanoweave Insight, Raptor Swipe!
      coach={ cn="怎么打：手法同团本——杀戮命令、猛禽一击、野火炸弹三件套，炸弹对准怪群丢。换怪群时保持近战在场，别在跑动中空转。盯什么：猫鼬狂怒 层数（91%覆盖）——它是输出地板，掉层重叠等于从头再来；优胜劣汰在大伤害前提前按。", en="How to play: Same hands as raid — Kill Command, Raptor Strike, Wildfire Bomb, with bombs aimed into packs. Keep melee uptime through pack swaps; don't idle while running. Watch: Mongoose Fury stacks (91% uptime) — they're your damage floor, and re-stacking from zero is starting over; press Survival of the Fittest ahead of big hits." },
    },
  },
  ["MAGE/ARCANE"] = {
    specID=62,
    raid={
      n=5, dur=544, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Magipie", server="Frostmourne", region="US", seq={365350,5143,1260459,44425,321507,1236616,5143,44425,5143,44425,153626,153626} },
        { player="每天高乐高", server="冰风岗", region="CN", seq={30451,153626,365350,44425,1260459,1236616,321507,5143,5143,30451,30451,44425} },
        { player="鹤望兰丶", server="神圣之歌", region="CN", seq={365350,44425,321507,1250533,1236616,5143,44425,5143,44425,1295924,5143,44425} },
      },
      core={ {5143,15.2},{44425,14.2},{1295924,5.1},{30451,4.1},{321507,1.3},{212653,1.1},{235450,1.0},{365350,0.7},{1260459,0.7},{153626,0.7} }, -- Arcane Missiles, Arcane Barrage, Prismatic Bolt, Arcane Blast, Touch of the Magi, Shimmer, Prismatic Barrier, Arcane Surge, Nullsight, Arcane Orb
      watch={ {448604,92.5},{461531,92.4},{1287772,84.5},{1296930,83.0},{263725,78.2},{1242974,77.0},{1229746,70.1},{1241715,59.6},{394195,59.3},{372014,57.4} }, -- Spellfire Sphere, Brainstorm, Rune of Critical Power, Cumulative Power, Clearcasting, Arcane Salvo, Arcanoweave Insight, Might of the Void, Overflowing Energy, Visage
      coach={ cn="怎么打：奥术冲击堆四层魔力（顶尖26.9次/分，全场最高频按键），奥术弹幕只在魔力满+触发时泄（8.7次/分），奥术宝珠按 CD 补充能（7次/分）。爆发轴：奥术涌动+大法师之触全部对齐，窗口内倾泻。盯什么：净化魔杖/清晰预兆类触发（清晰预兆覆盖61.4%）——它决定弹幕时机；蓝量曲线，爆发轴外别把蓝烧穿。", en="How to play: Arcane Blast stacks four charges (top players: 26.9/min, your busiest button), Arcane Barrage only dumps at full charges plus procs (8.7/min), Arcane Orb on cooldown for charge refills (7/min). Burst: Arcane Surge and Touch of the Magi stacked together, everything poured into the window. Watch: Clearcasting procs (61.4% uptime) — they time your Barrages; your mana curve, never burning dry outside burst windows." },
    },
    mplus={
      n=8, dur=1693,
      core={ {5143,13.3},{44425,11.6},{1295924,4.7},{30451,3.7},{235450,1.4},{212653,1.1},{321507,1.1},{153626,0.7},{365350,0.6},{55342,0.4} }, -- Arcane Missiles, Arcane Barrage, Prismatic Bolt, Arcane Blast, Prismatic Barrier, Shimmer, Touch of the Magi, Arcane Orb, Arcane Surge, Mirror Image
      watch={ {465,97.2},{448604,95.2},{1295057,90.7},{449322,86.3},{461531,82.0},{1287770,79.6},{1242974,76.7},{1296930,72.9},{263725,64.0},{394195,58.7} }, -- Devotion Aura, Spellfire Sphere, Tidal Insight, Mana Cascade, Brainstorm, Rune of the Versatile Warrior, Arcane Salvo, Cumulative Power, Clearcasting, Overflowing Energy
      coach={ cn="怎么打：模型不变，但弹幕在群怪时更激进——多目标分裂收益高，层数没满也可以泄。大法师之触对齐怪群刚拉稳的时机开。盯什么：怪群数量驱动弹幕时机；奥术齐射 覆盖95.5%说明顶尖玩家施法几乎不停——你的目标也是零空转。", en="How to play: Same model, but Barrage gets aggressive on packs — its multi-target split pays off even below max charges. Open Touch of the Magi once the pull is grouped. Watch: let pack size drive Barrage timing; Arcane Salvo's 95.5% uptime shows top players never stop casting — zero downtime is the goal." },
    },
  },
  ["MAGE/FIRE"] = {
    specID=63,
    mplus={
      n=8, dur=1669,
      core={ {108853,16.5},{11366,15.9},{2948,7.0},{133,4.8},{235313,1.3},{153561,0.9},{190319,0.8},{212653,0.8} }, -- Fire Blast, Pyroblast, Scorch, Fireball, Blazing Barrier, Meteor, Combustion, Shimmer
      watch={ {465,97.0},{448604,95.3},{461531,81.9},{449314,80.0},{383395,63.8},{383811,57.8},{1241715,54.6},{1229746,49.6},{1257350,43.7},{269651,39.8} }, -- Devotion Aura, Spellfire Sphere, Brainstorm, Mana Cascade, Feel the Burn, Fevered Incantation, Might of the Void, Arcanoweave Insight, Fired Up, Pyroclasm
      coach={ cn="怎么打：转化逻辑不变，但法术连击 在 3 个以上目标时转烈焰风暴而不是炎爆——丢在怪群脚下。灼烧照常处理移动。燃烧对齐大波怪群开。盯什么：目标数量决定转化去向（风暴/炎爆的切换阈值）；法火球 层数（95.7%覆盖）靠持续施法维持。", en="How to play: Same conversion logic, but at 3+ targets Hot Streak goes into Flamestrike at the pack's feet instead of Pyroblast. Scorch handles movement as usual; align Combustion with big pulls. Watch: target count decides the conversion target (your Flamestrike/Pyroblast threshold); Spellfire Sphere stacks (95.7%) live on continuous casting." },
    },
  },
  ["MAGE/FROST"] = {
    specID=64,
    raid={
      n=5, dur=532, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Choechoi", server="ajeusyara", region="KR", seq={116,44614,1260459,205021,30455,84714,30455,44614,30455,30455,30455,30455} },
        { player="Terstroik", server="Sanguino", region="EU", seq={116,44614,1250533,30455,205021,212653,30455,84714,30455,44614,30455,30455} },
        { player="Zhenglanxin", server="Illidan", region="US", seq={116,44614,1236616,84714,44614,30455,205021,30455,30455,30455,30455,199786} },
      },
      core={ {30455,23.8},{44614,6.8},{116,4.4},{199786,4.2},{84714,2.0},{205021,1.5},{212653,1.3},{11426,0.8},{414658,0.3} }, -- Ice Lance, Flurry, Frostbolt, Glacial Spike, Frozen Orb, Ray of Frost, Shimmer, Ice Barrier, Ice Cold
      watch={ {205473,91.5},{1287772,84.0},{372014,82.3},{465,81.6},{1263263,70.2},{1229746,67.3},{139,57.5},{461531,53.5},{394195,52.6},{382024,51.6} }, -- Icicles, Rune of Critical Power, Visage, Devotion Aura, Hand of Frost, Arcanoweave Insight, Renew, Brainstorm, Overflowing Energy, Earthliving Weapon
      coach={ cn="怎么打：冰枪术是消耗主力（顶尖26.7次/分），寒冰箭攒冰柱，攒满打冰川尖刺，冰风暴的寒冰指窗口把尖刺和冰枪打进去。寒冰宝珠和冰霜射线按 CD（各约2次/分）。盯什么：冰柱数量（覆盖92.5%=几乎一直有冰柱在手）——五根满了别浪费；冰风暴之后的连招顺序，尖刺要吃到碎裂加成。", en="How to play: Ice Lance is your spender (top players: 26.7/min), Frostbolt builds Icicles, Glacial Spike fires at five, and Flurry's shatter window carries the Spike and Ice Lances. Frozen Orb and Ray of Frost on cooldown (~2/min each). Watch: Icicle count (92.5% uptime = Icicles banked almost constantly) — don't waste at five; your post-Flurry sequence, the Spike must land inside shatter." },
    },
    mplus={
      n=8, dur=1703,
      core={ {30455,13.6},{44614,6.6},{199786,4.2},{11426,1.5},{212653,1.2},{205021,1.1},{84714,0.9},{342245,0.3} }, -- Ice Lance, Flurry, Glacial Spike, Ice Barrier, Shimmer, Ray of Frost, Frozen Orb, Alter Time
      watch={ {465,96.5},{205473,90.6},{1287772,77.4},{1232585,74.8},{207400,73.1},{382024,72.8},{462568,71.1},{1241715,55.6},{461531,52.5},{1287665,51.2} }, -- Devotion Aura, Icicles, Rune of Critical Power, Well Fed, Ancestral Vigor, Earthliving Weapon, Elemental Resistance, Might of the Void, Brainstorm, Rune of Lingering
      coach={ cn="怎么打：寒冰宝珠开怪群（高产触发），冰枪术照常吃碎冰连发，单体逻辑对精英保留。寒冰护体进入常规循环——拉怪前先套盾。盯什么：宝珠在怪群中的滚动路径（蹭满目标）；冰指触发的消耗速度跟上产出，多目标下很容易溢出。", en="How to play: Open packs with Frozen Orb (high proc generation), chain Ice Lance on shatter as usual, keep single-target logic for elites. Ice Barrier joins the regular loop — shield up before pulls. Watch: Orb's roll path through the pack (graze everything); spend Fingers procs as fast as they generate — they overcap easily multi-target." },
    },
  },
  ["MONK/BREWMASTER"] = {
    specID=268,
    raid={
      n=5, dur=562, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Telleria", server="Sargeras", region="US", seq={132578,1236616,115181,121253,115181,121253,115181,325153,121253,119582,115181,124506} },
        { player="Monkjz", server="Ravencrest", region="EU", seq={132578,115181,121253,115181,325153,121253,115181,124503,121253,115181,1263438,124506} },
        { player="Randraak", server="Blackrock", region="EU", seq={123986,121253,132578,1236616,1241059,119582,205523,124503,100780,121253,121253,325153} },
      },
      core={ {121253,11.4},{115181,10.6},{100780,9.2},{205523,8.7},{119582,7.4},{109132,2.4},{1241059,1.6},{123986,1.2},{322101,1.1},{325153,0.9},{116841,0.7},{115399,0.7},{132578,0.6},{322109,0.3} }, -- Keg Smash, Breath of Fire, Tiger Palm, Blackout Kick, Purifying Brew, Roll, Celestial Infusion, Chi Burst, Expel Harm, Exploding Keg, Tiger's Lust, Black Ox Brew, Invoke Niuzao, the Black Ox, Touch of Death
      watch={ {1263345,96.4},{455071,96.2},{1287770,88.1},{465,82.4},{1301477,65.3},{195630,62.0},{393515,60.4},{1241715,60.2},{451021,60.1},{451230,49.0} }, -- Swift as a Coursing River, Ox Stance, Rune of the Versatile Warrior, Devotion Aura, Hot Potato, Elusive Brawler, Pretense of Instability, Might of the Void, Flurry Charge, Predictive Training
      coach={ cn="怎么打：醉酿投 CD 好了必按（顶尖13.6次/分），火焰之息跟上（12.7次/分），猛虎掌和幻灭踢填充。活血酒看醉拳条按（7.8次/分）——重伤变中伤就喝，别屯满两充能。天神灌注按 CD。盯什么：醉拳承伤条的颜色——黄了就该考虑活血酒，红了必须喝；醉酿投的充能（13.6次/分=转好就按），它是输出和减伤的发动机。", en="How to play: Keg Smash on cooldown always (top players: 13.6/min), Breath of Fire follows (12.7/min), Tiger Palm and Blackout Kick fill. Purifying Brew reacts to your stagger bar (7.8/min) — purify at moderate, never sit on two charges. Celestial Infusion on cooldown. Watch: your stagger bar's color — yellow means consider purifying, red means purify now; Keg Smash charges (13.6/min = pressed on refresh), the engine behind both damage and mitigation." },
    },
    mplus={
      n=8, dur=1800,
      core={ {205523,11.0},{121253,10.7},{100780,10.5},{115181,10.5},{119582,7.2},{1241059,1.9},{109132,1.6},{123986,1.3},{115399,0.5},{132578,0.4},{322109,0.4},{322101,0.4},{116841,0.4},{115203,0.3} }, -- Blackout Kick, Keg Smash, Tiger Palm, Breath of Fire, Purifying Brew, Celestial Infusion, Roll, Chi Burst, Black Ox Brew, Invoke Niuzao, the Black Ox, Touch of Death, Expel Harm, Tiger's Lust, Fortifying Brew
      watch={ {215479,96.1},{392883,95.9},{383733,88.5},{1287770,82.7},{207400,82.4},{462568,75.9},{382024,73.3},{451508,71.3},{450521,71.1},{414143,68.0} }, -- Shuffle, Vivacious Vivification, Training of Niuzao, Rune of the Versatile Warrior, Ancestral Vigor, Elemental Resistance, Earthliving Weapon, Balanced Stratagem, Aspect of Harmony, Yu'lon's Grace
      coach={ cn="怎么打：手法同团本，活血酒按得更勤。核心纪律：金钟罩必须近乎全程在线（顶尖玩家96.7%）——它靠醉酿投/幻灭踢 的循环自然维持，所以输出循环停了减伤也停。大波怪群进场前确认活血酒有充能。盯什么：金钟罩 剩余时间和活血酒充能数，这两个就是你的生死面板。", en="How to play: Same hands as raid, with Purifying Brew busier. Core discipline: Shuffle must stay near-permanent (top players 96.7%) — it's sustained by your Keg Smash/Blackout Kick loop, so stopping your rotation stops your mitigation. Enter big pulls with brew charges ready. Watch: Shuffle's remaining duration and brew charges — that's your life-or-death dashboard." },
    },
  },
  ["MONK/MISTWEAVER"] = {
    specID=270,
    raid={
      n=5, dur=548, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Bauchi", server="Sargeras", region="US", seq={115151,116849,467307,322118,440836,1236616,124682,124682,124682,116670,467307,116670} },
        { player="Vashmonk", server="Kil'jaeden", region="US", seq={115151,467307,467307,115151,115151,467307,116670,116670,115151,467307,116670,124682} },
        { player="Poipoipio", server="Blackhand", region="EU", seq={116849,1258283,443028,116670,467307,124682,388615,116670,467307,116680,115151,115151} },
      },
      core={ {467307,12.6},{116670,12.3},{115151,10.4},{124682,7.4},{115294,2.9},{116680,2.6},{115175,0.9},{115450,0.8},{443028,0.6},{116849,0.5},{109132,0.5},{322118,0.5},{115310,0.3} }, -- Rushing Wind Kick, Vivify, Renewing Mist, Enveloping Mist, Mana Tea, Thunder Focus Tea, Soothing Mist, Detox, Celestial Conduit, Life Cocoon, Roll, Invoke Yu'lon, the Jade Serpent, Revival
      watch={ {115867,95.9},{1287774,85.5},{388497,84.8},{465,84.4},{372014,80.6},{1229746,60.4},{1241715,58.0},{392883,46.9},{443569,44.1},{1260565,42.2} }, -- Mana Tea, Rune of Burning Haste, Secret Infusion, Devotion Aura, Visage, Arcanoweave Insight, Might of the Void, Vivacious Vivification, Chi-Ji's Swiftness, Spiritfont
      coach={ cn="怎么打：复苏之雾按 CD 铺（顶尖10.5次/分），活血术吃它做群刷（15.6次/分），氤氲之雾给重点目标（9.6次/分）。雷光聚神茶强化下一个技能——配氤氲之雾或活血术看需求（2.8次/分）。疾风呼啸踢别停（10.9次/分），武僧的输出就是治疗。盯什么：复苏之雾在团队里的张数——活血术的溅射跟着它走；法力茶的窗口（覆盖97.4%=顶尖几乎全程在茶态省蓝）。", en="How to play: Renewing Mist on cooldown (top players: 10.5/min), Vivify rides it for group healing (15.6/min), Enveloping Mist for focus targets (9.6/min). Thunder Focus Tea empowers your next spell — pair with Enveloping or Vivify as needed (2.8/min). Keep Rushing Wind Kick going (10.9/min); a Mistweaver's damage IS healing. Watch: Renewing Mist count across the raid — Vivify cleave follows it; Mana Tea windows (97.4% uptime = top players basically live in discounted casts)." },
    },
    mplus={
      n=8, dur=1687,
      core={ {107428,13.4},{101546,9.7},{100780,6.5},{100784,5.9},{124682,2.7},{116680,2.2},{399491,1.2},{109132,0.9},{115294,0.9},{115175,0.6},{116849,0.5},{115450,0.5},{1258283,0.5},{443028,0.5} }, -- Rising Sun Kick, Spinning Crane Kick, Tiger Palm, Blackout Kick, Enveloping Mist, Thunder Focus Tea, Sheilun's Gift, Roll, Mana Tea, Soothing Mist, Life Cocoon, Detox, Beacon of Lightblind Wrath, Celestial Conduit
      watch={ {399497,91.0},{399510,90.8},{392883,87.6},{414143,69.1},{443112,38.8},{1260565,38.5},{202090,36.2},{1260670,31.5},{443569,29.7},{443421,29.0} }, -- Sheilun's Gift, Sheilun's Gift, Vivacious Vivification, Yu'lon's Grace, Strength of the Black Ox, Spiritfont, Teachings of the Monastery, Spiritfont, Chi-Ji's Swiftness, Heart of the Jade Serpent
      coach={ cn="怎么打：没治疗压力就打输出连段（神鹤引项踢/旭日东升踢/猛虎掌），要奶的时候神龙之赐层数攒够直接灌，点名用氤氲之雾。这个玩法的核心是敢打——输出循环就是你的法力和治疗引擎。盯什么：神龙之赐的层数（对齐承伤波次释放）；坦克血线趋势，留一个反应窗口。", en="How to play: With no healing pressure, run your damage chain (Spinning Crane Kick / Rising Sun Kick / Tiger Palm); when healing is needed, dump banked Sheilun's Gift stacks and spot-heal with Enveloping Mist. The core skill is daring to fight — your damage loop IS your mana and healing engine. Watch: Sheilun's Gift stacks (release into damage waves) and the tank's health trend, keeping a reaction window." },
    },
  },
  ["MONK/WINDWALKER"] = {
    specID=269,
    raid={
      n=5, dur=510, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Aidan", server="Lothar", region="US", seq={100780,383781,1249625,113656,107428,152175,101546,100784,113656,467307,107428,100780} },
        { player="Vengmonk", server="Draenor", region="EU", seq={116841,100780,1250533,1249625,107428,113656,152175,101546,100784,122470,107428,109132} },
        { player="Khromak", server="Emerald Dream", region="US", seq={100780,1250533,1249625,113656,107428,152175,100784,101546,107428,113656,100784,100780} },
      },
      core={ {100780,11.6},{100784,7.2},{107428,6.6},{113656,4.6},{101546,4.2},{467307,2.1},{109132,1.8},{152175,1.6},{1249625,0.9},{322109,0.4},{122470,0.4},{115203,0.3},{116844,0.3},{101545,0.3} }, -- Tiger Palm, Blackout Kick, Rising Sun Kick, Fists of Fury, Spinning Crane Kick, Rushing Wind Kick, Roll, Whirling Dragon Punch, Zenith, Touch of Death, Touch of Karma, Fortifying Brew, Ring of Peace, Flying Serpent Kick
      watch={ {392883,96.1},{465,91.7},{1287772,85.3},{372014,75.0},{451021,66.9},{1229746,64.2},{451298,59.7},{202090,58.9},{1241762,53.7},{196742,46.0} }, -- Vivacious Vivification, Devotion Aura, Rune of Critical Power, Visage, Flurry Charge, Arcanoweave Insight, Momentum Boost, Teachings of the Monastery, Frenzied Focus, Whirling Dragon Punch
      coach={ cn="怎么打：猛虎掌产真气（顶尖10次/分），旭日东升踢 CD 好了必按（8.9次/分），幻灭踢消耗填充（9.2次/分），怒雷破按 CD 打满（6.2次/分）——记住连击规则：同一技能不连按两次。升龙霸转好就按（2次/分）。盯什么：连击序列别断——这是踏风的核心收益；动量提升（覆盖72.5%）和升龙霸的可用窗口（覆盖69.9%），亮了优先。", en="How to play: Tiger Palm builds chi (top players: 10/min), Rising Sun Kick on cooldown always (8.9/min), Blackout Kick spends as filler (9.2/min), Fists of Fury channeled fully on cooldown (6.2/min) — and remember the combo rule: never the same ability twice in a row. Whirling Dragon Punch on refresh (2/min). Watch: never break your combo chain — it's Windwalker's core payoff; Momentum Boost (72.5% uptime) and Whirling Dragon Punch availability (69.9%), press when lit." },
    },
    mplus={
      n=8, dur=1719,
      core={ {100780,9.9},{101546,7.4},{100784,5.5},{107428,5.0},{113656,4.9},{1272696,1.8},{152175,1.7},{467307,1.7},{1249625,0.9},{109132,0.9},{322109,0.4},{122470,0.4},{115203,0.3} }, -- Tiger Palm, Spinning Crane Kick, Blackout Kick, Rising Sun Kick, Fists of Fury, Zenith Stomp, Whirling Dragon Punch, Rushing Wind Kick, Zenith, Roll, Touch of Death, Touch of Karma, Fortifying Brew
      watch={ {196741,95.9},{392883,88.3},{1248705,87.7},{1287771,81.4},{202090,70.0},{414143,69.6},{451298,62.7},{1241715,54.5},{1229746,39.9},{129914,38.7} }, -- Hit Combo, Vivacious Vivification, Skyfire Heel, Rune of Masterful Cunning, Teachings of the Monastery, Yu'lon's Grace, Momentum Boost, Might of the Void, Arcanoweave Insight, Combat Wisdom
      coach={ cn="怎么打：群怪把神鹤引项踢插进连击链，不重复的铁律照旧（连击增益 覆盖97.3%）。怒雷破对准怪群引导。换目标不影响连击——大胆切优先目标。盯什么：连击增益是否还在；怪群数量决定神鹤的出场频率，3 个以上就值得进链。", en="How to play: Slot Spinning Crane Kick into the combo chain on packs — the no-repeat rule still applies (Hit Combo at 97.3%). Channel Fists of Fury into the pack. Target swaps don't break your combo — swap to priority targets freely. Watch: that the combo buff stays up; pack size sets Crane Kick's frequency — worth chaining at 3+ targets." },
    },
  },
  ["PALADIN/HOLY"] = {
    specID=65,
    raid={
      n=5, dur=547, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Silliee", server="Zul'jin", region="US", seq={19750,20473,415388,415388,275773,85222,200025,375576,415388,415388,415388,415388} },
        { player="Nears", server="Thrall", region="US", seq={1291894,20473,415388,415388,200025,20473,415388,415388,20473,415388,415388,156322} },
        { player="Alanih", server="Blackhand", region="EU", seq={20473,415388,415388,275773,20473,415388,415388,85222,200025,375576,415388,415388} },
      },
      core={ {20473,13.4},{156322,11.5},{19750,7.2},{200025,3.3},{85222,2.8},{275773,1.9},{375576,1.5},{1241413,0.9},{31884,0.5},{4987,0.5},{190784,0.5},{498,0.4},{31821,0.3} }, -- Holy Shock, Eternal Flame, Flash of Light, Beacon of Virtue, Light of Dawn, Judgment, Divine Toll, Hammer of Wrath, Avenging Wrath, Cleanse, Divine Steed, Divine Protection, Aura Mastery
      watch={ {1287771,87.2},{447988,84.4},{448087,75.1},{1252488,62.1},{1229746,61.7},{1241715,60.9},{54149,36.7},{382024,35.7},{462568,34.5},{139,33.6} }, -- Rune of Masterful Cunning, Light of the Martyr, Bestow Light, Masterful Hunt, Arcanoweave Insight, Might of the Void, Infusion of Light, Earthliving Weapon, Elemental Resistance, Renew
      coach={ cn="怎么打：神圣震击 CD 好了必按（顶尖13.5次/分），圣能喂黎明之光群刷（13.5次/分），圣光闪现补单点（9.2次/分）。圣洁鸣钟按 CD（1.7次/分）一口气刷五个震击。审判别忘了打（1.6次/分），它给治疗增益。盯什么：圣能别溢出——震击转好前把存量花掉；殉道者之光（覆盖75.6%）这类增益的窗口，大轴前对齐复仇之怒。", en="How to play: Holy Shock on cooldown always (top players: 13.5/min), Holy Power feeds Light of Dawn for group healing (13.5/min), Flash of Light spot-heals (9.2/min). Divine Toll on cooldown (1.7/min) fires five Shocks at once. Don't skip Judgment (1.6/min) for its healing buff. Watch: never cap Holy Power — spend before Shock refreshes; buff windows like Light of the Martyr (75.6% uptime), and align Avenging Wrath with big damage events." },
    },
    mplus={
      n=8, dur=1719,
      core={ {415091,9.6},{19750,8.8},{20473,7.4},{275773,5.4},{85673,5.1},{82326,2.4},{1241413,1.3},{432472,1.0},{432459,1.0},{4987,0.7},{190784,0.5},{498,0.5},{31884,0.5},{1291894,0.3} }, -- Shield of the Righteous, Flash of Light, Holy Shock, Judgment, Word of Glory, Holy Light, Hammer of Wrath, Sacred Weapon, Holy Bulwark, Cleanse, Divine Steed, Divine Protection, Avenging Wrath, Soulcoiler Ritual Vessel
      watch={ {6673,96.5},{460822,75.4},{432502,66.8},{1241715,55.4},{432496,53.2},{432607,52.6},{54149,50.7},{1271436,48.1},{387178,47.8},{1229746,47.2} }, -- Battle Shout, Divine Guidance, Sacred Weapon, Might of the Void, Holy Bulwark, Holy Bulwark, Infusion of Light, Masterwork: Weapon, Empyrean Legacy, Arcanoweave Insight
      coach={ cn="怎么打：钥石里你是半个近战 DPS——没人掉血就贴怪打正义盾击和审判（它们产圣能、回法力），要奶的时候圣能转永恒之火/荣耀圣令。神圣震击照常卡 CD。盯什么：自己的站位（近战范围内才有完整体系）；坦克血线和圣能存量的联动——大伤害来临前留 3 圣能。", en="How to play: In keys you're half a melee DPS — when nobody's dropping, stay on the mobs with Shield of the Righteous and Judgment (they generate Holy Power), converting to Eternal Flame or Word of Glory when healing is needed. Holy Shock on cooldown as always. Watch: your positioning (the kit only works in melee range); link the tank's health to your Holy Power reserve — bank 3 before big hits." },
    },
  },
  ["PALADIN/PROTECTION"] = {
    specID=66,
    raid={
      n=5, dur=547, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Kitch", server="Lightbringer", region="EU", seq={53600,375576,1236616,53600,1241413,26573,432472,1241413,31935,53600,1241413,1241413} },
        { player="Oudpala", server="Eredar", region="EU", seq={275779,389539,1236616,375576,53600,1241413,53600,31935,53600,1241413,432459,53600} },
        { player="Logbewbble", server="Illidan", region="US", seq={31935,275779,26573,389539,1293316,375576,53600,432459,1241413,1241413,432472,1241413} },
      },
      core={ {53600,15.7},{204019,14.3},{275779,12.2},{31935,6.6},{1241413,5.0},{26573,4.4},{85673,1.3},{190784,1.2},{389539,1.0},{375576,1.0},{432472,0.6},{31850,0.5},{432459,0.5},{86659,0.3} }, -- Shield of the Righteous, Blessed Hammer, Judgment, Avenger's Shield, Hammer of Wrath, Consecration, Word of Glory, Divine Steed, Sentinel, Divine Toll, Sacred Weapon, Ardent Defender, Holy Bulwark, Guardian of Ancient Kings
      watch={ {327510,95.8},{132403,95.2},{372014,90.9},{379017,81.0},{460822,79.1},{188370,73.3},{1229746,70.2},{182104,66.2},{432502,60.5},{382024,58.8} }, -- Shining Light, Shield of the Righteous, Visage, Faith's Armor, Divine Guidance, Consecration, Arcanoweave Insight, Shining Light, Sacred Weapon, Earthliving Weapon
      coach={ cn="怎么打：正义盾击几乎常驻（顶尖22.8次/分，圣能全喂它），祝福之锤和审判转好就按（16.7和10.8次/分）维持产能，复仇者之盾按 CD，奉献别离脚下。掉血大了圣能转荣耀圣令。盯什么：正义盾击的剩余时间——物理承伤期不能断；闪耀之光的免费荣耀圣令触发（覆盖97.5%=顶尖从不浪费），白嫖的治疗记得用。", en="How to play: Shield of the Righteous stays near-permanent (top players: 22.8/min, all Holy Power feeds it), Blessed Hammer and Judgment on refresh (16.7 and 10.8/min) to keep generation rolling, Avenger's Shield on cooldown, and never leave your Consecration. Divert Holy Power to Word of Glory when health dips. Watch: Shield of the Righteous remaining duration — never let it drop during physical damage; free Word of Glory procs from Shining Light (97.5% uptime = top players never waste one)." },
    },
    mplus={
      n=8, dur=1817,
      core={ {53600,16.3},{204019,11.8},{275779,11.4},{31935,6.5},{1241413,6.0},{26573,4.1},{85673,3.4},{204079,1.5},{389539,0.8},{375576,0.8},{190784,0.8},{432459,0.6},{31850,0.6},{432472,0.5} }, -- Shield of the Righteous, Blessed Hammer, Judgment, Avenger's Shield, Hammer of Wrath, Consecration, Word of Glory, Final Stand, Sentinel, Divine Toll, Divine Steed, Holy Bulwark, Ardent Defender, Sacred Weapon
      watch={ {393038,91.8},{132403,91.1},{327510,84.2},{1287772,82.2},{460822,82.2},{379017,80.2},{207400,77.4},{188370,71.7},{280375,70.1},{382024,67.7} }, -- Strength in Adversity, Shield of the Righteous, Shining Light, Rune of Critical Power, Divine Guidance, Faith's Armor, Ancestral Vigor, Consecration, Redoubt, Earthliving Weapon
      coach={ cn="怎么打：盾击覆盖纪律不变，多目标承伤下荣耀圣令按得更勤（自奶需求上来了）。拉怪时复仇者之盾开场、奉献落在怪群将要站定的位置。圣能在生存和输出间动态分——稳了才打输出。盯什么：盾击和奉献的双覆盖；法系怪群盾击挡不了法伤，提前规划保命 CD。", en="How to play: Same SotR discipline, with Word of Glory pressed more as multi-target damage raises self-healing needs. Open pulls with Avenger's Shield and drop Consecration where the pack will settle. Split Holy Power dynamically between survival and damage — damage only once stable. Watch: dual coverage of SotR and Consecration; SotR doesn't block spell damage, so plan defensives ahead for caster packs." },
    },
  },
  ["PALADIN/RETRIBUTION"] = {
    specID=70,
    raid={
      n=5, dur=550, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Ezee", server="Frostmourne", region="US", seq={383781,190784,184575,31884,408385,408385,1236616,343527,255937,408385,383328,408385} },
        { player="Celi", server="Illidan", region="US", seq={184575,408385,31884,1293316,343527,255937,408385,383328,408385,408385,383328,375576} },
        { player="Harrydin", server="Draenor", region="EU", seq={20271,408385,184575,31884,1293316,1236616,408385,343527,255937,408385,408385,383328} },
      },
      core={ {408385,35.5},{383328,19.1},{53385,7.2},{184575,6.1},{20271,5.4},{24275,5.0},{255937,2.0},{190784,1.1},{375576,1.0},{31884,1.0},{343527,1.0},{403876,0.3} }, -- Crusading Strikes, Final Verdict, Divine Storm, Blade of Justice, Judgment, Hammer of Wrath, Wake of Ashes, Divine Steed, Divine Toll, Avenging Wrath, Execution Sentence, Divine Protection
      watch={ {407065,87.7},{1287771,87.0},{1305230,86.2},{372014,69.9},{139,54.1},{382024,42.7},{1229746,40.5},{31884,40.2},{1264050,40.2},{1241410,40.2} }, -- Rush of Light, Rune of Masterful Cunning, Divine Power, Visage, Renew, Earthliving Weapon, Arcanoweave Insight, Avenging Wrath, Born in Sunlight, Hammer of Wrath
      coach={ cn="怎么打：圣能产出靠公正之剑、审判、愤怒之锤转好就按（10.6、6.1、5.7次/分），最终审判是消耗主力（顶尖23.6次/分）。灰烬觉醒和圣洁鸣钟按 CD（各2.1次/分）。光之圣锤的窗口里优先打它（4.3次/分）。盯什么：圣能别溢出——三个产能键的 CD 错开按；光芒涌动（覆盖97.2%）说明顶尖玩家的资源循环从不停转。", en="How to play: Holy Power flows from Blade of Justice, Judgment, and Hammer of Wrath on refresh (10.6, 6.1, 5.7/min); Final Verdict is your main spender (top players: 23.6/min). Wake of Ashes and Divine Toll on cooldown (2.1/min each). Prioritize Hammer of Light inside its window (4.3/min). Watch: never cap Holy Power — stagger your three generators; Rush of Light at 97.2% uptime shows top players' resource loop never stalls." },
    },
    mplus={
      n=8, dur=1804,
      core={ {408385,41.9},{53385,13.0},{383328,11.9},{184575,6.0},{20271,5.2},{24275,4.2},{255937,1.7},{343527,0.8},{31884,0.8},{375576,0.8},{403876,0.5},{190784,0.5} }, -- Crusading Strikes, Divine Storm, Final Verdict, Blade of Justice, Judgment, Hammer of Wrath, Wake of Ashes, Execution Sentence, Avenging Wrath, Divine Toll, Divine Protection, Divine Steed
      watch={ {407065,84.8},{1264426,80.2},{1287771,76.3},{1305230,74.6},{207400,71.3},{382024,66.2},{462568,65.7},{1229746,42.5},{31884,31.9},{1241410,31.9} }, -- Rush of Light, Void-Touched, Rune of Masterful Cunning, Divine Power, Ancestral Vigor, Earthliving Weapon, Elemental Resistance, Arcanoweave Insight, Avenging Wrath, Hammer of Wrath
      coach={ cn="怎么打：产能链不变，泄能键换成神圣风暴（2-3 个以上目标）；单体优先目标仍用最终审判。圣洁鸣钟丢进怪群一次性产能。盯什么：目标数量决定风暴/审判的切换；免费圣光之锤触发（95.5%覆盖）亮了立刻用，攒着就是亏。", en="How to play: Same builders; the spender becomes Divine Storm at 2-3+ targets, with Final Verdict kept for priority singles. Divine Toll into packs for a burst of Holy Power. Watch: target count drives the Storm/Verdict switch; spend free Hammer of Light procs from Light's Deliverance (95.5% uptime) immediately — sitting on them is pure loss." },
    },
  },
  ["PRIEST/DISCIPLINE"] = {
    specID=256,
    raid={
      n=5, dur=542, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Doting", server="Bleeding Hollow", region="US", seq={589,2061,10060,10060,200829,17,194509,472433,194509,194509,1236616,8092} },
        { player="Stopthecount", server="Thrall", region="US", seq={17,589,194509,472433,1295885,194509,10060,10060,8092,47540,1236616,1253593} },
        { player="Bottledfaith", server="Illidan", region="US", seq={585,589,10060,10060,194509,194509,472433,1236616,8092,585,1253593,47540} },
      },
      core={ {585,23.5},{47540,8.4},{1253593,5.9},{194509,4.0},{8092,4.0},{2061,3.9},{17,2.8},{32379,2.3},{10060,1.1},{1295885,1.1},{589,1.0},{586,1.0},{527,0.9},{472433,0.7} }, -- Smite, Penance, Void Shield, Power Word: Radiance, Mind Blast, Flash Heal, Power Word: Shield, Shadow Word: Death, Power Infusion, Hex Lord's Doom, Shadow Word: Pain, Fade, Purify, Evangelism
      watch={ {449887,97.3},{465,96.9},{1307470,93.0},{1287774,86.7},{1253725,80.7},{450193,69.9},{1241715,59.6},{390692,58.7},{1229746,57.5},{193065,54.5} }, -- Voidheart, Devotion Aura, Hex Lord's Doom, Rune of Burning Haste, Greater Smite, Entropic Rift, Might of the Void, Borrowed Time, Arcanoweave Insight, Protective Light
      coach={ cn="怎么打：戒律的治疗走伤害——先铺救赎：团伤前真言术：盾+真言术：耀铺开（4.7和4.2次/分），然后惩击和苦修把救赎转成治疗（11.8和10次/分）。暗言术：灭和心灵震爆插缝。快速治疗只救急（6.9次/分）。盯什么：团队时间轴——救赎要在伤害前铺好，铺晚了惩击就白打；苦修的充能和触发窗口。", en="How to play: Discipline heals through damage — pre-spread Atonement with Power Word: Shield and Power Word: Radiance before raid damage (4.7 and 4.2/min), then Smite and Penance convert it to healing (11.8 and 10/min). Shadow Word: Death and Mind Blast weave in. Flash Heal is emergencies only (6.9/min). Watch: the raid timeline — Atonement must be out before damage hits or your Smites heal nothing; Penance charges and proc windows." },
    },
    mplus={
      n=8, dur=1665,
      core={ {585,13.6},{47540,8.8},{1253593,4.6},{186263,4.4},{17,3.0},{8092,2.3},{589,2.2},{194509,1.8},{586,1.1},{121536,0.9},{10060,0.8},{32379,0.8},{527,0.6},{472433,0.5} }, -- Smite, Penance, Void Shield, Shadow Mend, Power Word: Shield, Mind Blast, Shadow Word: Pain, Power Word: Radiance, Fade, Angelic Feather, Power Infusion, Shadow Word: Death, Purify, Evangelism
      watch={ {1459,96.0},{462854,90.7},{1287774,81.5},{41635,57.8},{390978,53.8},{1241715,50.9},{390692,50.1},{472433,49.4},{390787,49.3},{1229746,45.9} }, -- Arcane Intellect, Skyfury, Rune of Burning Haste, Prayer of Mending, Twist of Fate, Might of the Void, Borrowed Time, Evangelism, Weal and Woe, Arcanoweave Insight
      coach={ cn="怎么打：小怪阶段轻量维护——坦克挂盾、自己输出（惩击/苦修），大伤害前才完整铺救赎。暗影治愈 点名补。暗言术：灭在打断/补刀两用。盯什么：哪些伤害需要提前铺（看怪的读条和狂暴技能）；命运扭曲 触发期间多打两下，增伤不白给。", en="How to play: Light maintenance on trash — shield the tank, deal damage with Smite and Penance, saving full Atonement ramps for big hits. Shadow Mend for spot healing; Shadow Word: Death doubles for executes. Watch: which incoming abilities need a pre-ramp (read enemy cast bars and enrage timers); swing harder during Twist of Fate windows — free damage." },
    },
  },
  ["PRIEST/HOLY"] = {
    specID=257,
    raid={
      n=5, dur=542, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Squidword", server="Area 52", region="US", seq={14914,88625,14914,14914,10060,10060,33076,1262763,2050,1262763,1291894,33076} },
        { player="Ragrappy", server="Stormreaver", region="US", seq={14914,10060,10060,2050,120517,2050,1236616,200183,2050,596,2050,596} },
        { player="songha", server="ajeusyara", region="KR", seq={10060,10060,2050,33076,120517,1236616,1293316,200183,2050,2050,596,596} },
      },
      core={ {1262763,9.8},{2050,7.0},{33076,6.9},{596,6.1},{2061,4.0},{132157,1.8},{585,1.4},{10060,1.1},{586,0.9},{121536,0.9},{527,0.8},{14914,0.7},{64843,0.4},{200183,0.4} }, -- Benediction, Holy Word: Serenity, Prayer of Mending, Prayer of Healing, Flash Heal, Holy Nova, Smite, Power Infusion, Fade, Angelic Feather, Purify, Holy Fire, Divine Hymn, Apotheosis
      watch={ {465,89.5},{193065,88.5},{1287772,87.8},{1306118,85.2},{405963,84.5},{372014,76.7},{1262766,73.0},{1229746,68.6},{1241715,57.2},{139,54.5} }, -- Devotion Aura, Protective Light, Rune of Critical Power, Renewed Vigor, Divine Image, Visage, Benediction, Arcanoweave Insight, Might of the Void, Renew
      coach={ cn="怎么打：治疗祷言是群刷主力（顶尖11.9次/分），圣言术：静秒单点（8次/分），愈合祷言丢 CD 让它自己跳（4.6次/分）。神圣词语的逻辑贯穿全程：祷言降静的 CD，互相喂。没人掉血就惩击（4.6次/分）。能量灌注给自己或爆发位。盯什么：圣言术的 CD 缩减循环别停；神圣身影（覆盖92.2%）的窗口，大轴对齐它。", en="How to play: Prayer of Healing is your group heal (top players: 11.9/min), Holy Word: Serenity nukes single targets (8/min), Prayer of Mending tossed on cooldown to bounce on its own (4.6/min). Holy Word logic runs everything: prayers reduce Serenity's cooldown, feeding each other. Nobody hurt? Smite (4.6/min). Power Infusion to yourself or a burst player. Watch: keep the Holy Word cooldown-reduction loop spinning; Divine Image windows (92.2% uptime), align big moments with it." },
    },
    mplus={
      n=8, dur=1811,
      core={ {33076,8.9},{14914,7.8},{1262763,7.5},{585,5.6},{2050,4.1},{2061,3.9},{88625,2.7},{586,1.4},{132157,1.3},{121536,1.0},{10060,0.9},{527,0.5},{19236,0.3},{200183,0.3} }, -- Prayer of Mending, Holy Fire, Benediction, Smite, Holy Word: Serenity, Flash Heal, Holy Word: Chastise, Fade, Holy Nova, Angelic Feather, Power Infusion, Purify, Desperate Prayer, Apotheosis
      watch={ {1306118,94.0},{1295057,91.0},{1287774,79.5},{193065,76.9},{139,69.2},{1262766,62.8},{41635,59.8},{1297663,53.5},{1252488,52.4},{390978,43.2} }, -- Renewed Vigor, Tidal Insight, Rune of Burning Haste, Protective Light, Renew, Benediction, Prayer of Mending, Halazzi's Rite, Masterful Hunt, Twist of Fate
      coach={ cn="怎么打：能打就打——神圣之火、惩击、圣言术：罚都参与输出，神圣新星在怪堆里放。治疗靠快速治疗点名加圣言术：静救急，恢复提前挂给坦克。盯什么：坦克身上的恢复别掉（79%覆盖，是常驻工具不是备选）；自己输出和治疗的切换时机——打着打着别忘了看血条。", en="How to play: Fight when you can — Holy Fire, Smite and Chastise all contribute, Holy Nova inside packs. Heal with Flash Heal spots and Holy Word: Serenity saves, keeping Renew rolling on the tank ahead of damage. Watch: Renew on the tank (79% uptime — it's a standard tool, not optional); your DPS-to-healing switch timing — don't get lost in the damage and miss a dropping bar." },
    },
  },
  ["PRIEST/SHADOW"] = {
    specID=258,
    raid={
      n=5, dur=544, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Anamemana", server="Frostmourne", region="US", seq={8092,1227280,341263,341263,589,341263,120644,1242173,228260,1242173,1293316,10060} },
        { player="Fish", server="Kul Tiras", region="US", seq={8092,1227280,341263,341263,589,120644,1242173,341263,228260,10060,10060,1260459} },
        { player="Snowgigarat", server="Stormrage", region="US", seq={8092,1227280,341263,341263,589,1242173,120644,341263,228260,15286,1250533,10060} },
      },
      core={ {335467,7.9},{1242173,7.0},{15407,6.8},{8092,5.2},{1227280,5.1},{589,4.3},{391403,3.8},{34914,3.0},{586,1.3},{17,1.3},{32379,1.1},{10060,1.0},{120644,1.0},{19236,0.6} }, -- Shadow Word: Madness, Void Volley, Mind Flay, Mind Blast, Tentacle Slam, Shadow Word: Pain, Mind Flay: Insanity, Vampiric Touch, Fade, Power Word: Shield, Shadow Word: Death, Power Infusion, Halo, Desperate Prayer
      watch={ {465,84.2},{373213,82.6},{1287772,81.2},{1229746,73.0},{232698,69.2},{391092,68.5},{373277,67.1},{393919,64.1},{1266687,60.8},{1241759,56.3} }, -- Devotion Aura, Insidious Ire, Rune of Critical Power, Arcanoweave Insight, Shadowform, Shattered Psyche, Thing from Beyond, Screams of the Void, Alnscorned Essence, Genius Insight
      coach={ cn="怎么打：吸血鬼之触和暗言术：痛全程不掉（1.8和2次/分=只在快掉时补），心灵震爆按 CD（顶尖11.6次/分），暗言术：癫是高频消耗（10.3次/分），精神鞭笞填充（9.6次/分）。触须猛击转好就按（4.1次/分）。盯什么：两个 DoT 的剩余时间——掉了一切收益归零；暗影形态覆盖75.1%说明顶尖玩家几乎不离开形态。", en="How to play: Vampiric Touch and Shadow Word: Pain never drop (1.8 and 2/min = refresh only near expiry), Mind Blast on cooldown (top players: 11.6/min), Shadow Word: Madness is your high-frequency spender (10.3/min), Mind Flay fills (9.6/min). Tentacle Slam on refresh (4.1/min). Watch: both DoTs' remaining time — everything scales off them; Shadowform at 75.1% uptime means top players almost never leave it." },
    },
    mplus={
      n=8, dur=1734,
      core={ {335467,8.2},{1242173,5.8},{8092,5.4},{589,5.4},{15407,5.3},{1227280,4.4},{263165,1.6},{32379,1.5},{586,1.2},{17,1.1},{10060,0.8},{1293316,0.4},{15286,0.4},{228260,0.4} }, -- Shadow Word: Madness, Void Volley, Mind Blast, Shadow Word: Pain, Mind Flay, Tentacle Slam, Void Torrent, Shadow Word: Death, Fade, Power Word: Shield, Power Infusion, Empowering Venom, Vampiric Embrace, Voidform
      watch={ {465,97.4},{462854,95.8},{1264426,87.1},{232698,80.5},{373277,74.9},{393919,60.9},{390978,58.4},{449887,55.8},{1241759,53.9},{377066,52.1} }, -- Devotion Aura, Skyfury, Void-Touched, Shadowform, Thing from Beyond, Screams of the Void, Twist of Fate, Voidheart, Genius Insight, Mental Fortitude
      coach={ cn="怎么打：进怪群先把暗言术：痛甩到每个目标（多目标 DOT 是大头），然后癫、心灵震爆、鞭笞照常转。虚空洪流对准怪群引导。渐隐术按节奏脱仇恨。盯什么：每个怪身上的痛是否都在；触发出的虚空实体——它在打输出，尽量让它存活满时长。", en="How to play: Open packs by flinging Shadow Word: Pain onto every target (multi-DoTting is the bulk), then run Madness, Mind Blast and Mind Flay as usual. Channel Void Torrent into the pack; Fade rhythmically for threat. Watch: Pain's presence on every mob; your Thing from Beyond void spawns — they're dealing damage, so let them live out their full duration." },
    },
  },
  ["ROGUE/ASSASSINATION"] = {
    specID=259,
    raid={
      n=5, dur=552, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Chainbleed", server="Area 52", region="US", seq={703,27576,1329,1943,703,27576,1329,27576,1329,381623,32645,1236616} },
        { player="Zerøcool", server="Silvermoon", region="EU", seq={703,1236616,703,27576,1329,1943,383781,360194,385627,32645,27576,1329} },
        { player="Weak", server="Stormreaver", region="EU", seq={2983,703,27576,1329,1943,27576,1329,703,27576,1329,32645,1297761} },
      },
      core={ {1329,17.9},{32645,10.2},{51723,4.5},{703,2.9},{1247227,2.6},{1943,2.4},{385627,1.0},{36554,0.6},{2983,0.6},{185311,0.6},{1966,0.6},{360194,0.5},{1856,0.4} }, -- Mutilate, Envenom, Fan of Knives, Garrote, Crimson Tempest, Rupture, Kingsbane, Shadowstep, Sprint, Crimson Vial, Feint, Deathmark, Vanish
      watch={ {394080,96.6},{32645,80.6},{1264297,65.9},{462568,61.9},{1241762,59.6},{139,58.6},{1248775,54.6},{1287665,53.2},{382024,52.9},{1229746,47.2} }, -- Scent of Blood, Envenom, Cold Blood, Elemental Resistance, Frenzied Focus, Renew, Unshakeable Drive, Rune of Lingering, Earthliving Weapon, Arcanoweave Insight
      coach={ cn="怎么打：毁伤攒连击点（顶尖21次/分），毒伤满星泄（16.6次/分，自身增益覆盖94.6%=几乎常驻），锁喉和割裂两个流血全程保持（3和2.3次/分=只补不抢）。君王之灾和死亡印记按 CD 对齐。盯什么：毒伤增益的剩余时间——它断了你的毒就软了；锁喉和割裂的倒计时，在潜伏窗口里刷出强化版。", en="How to play: Mutilate builds combo points (top players: 21/min), Envenom dumps at full points (16.6/min, with 94.6% buff uptime = nearly permanent), and Garrote plus Rupture stay up all fight (3 and 2.3/min = refresh, don't clip). Kingsbane and Deathmark aligned on cooldown. Watch: Envenom's buff timer — if it drops your poisons go soft; Garrote and Rupture countdowns, refreshing empowered versions from stealth windows." },
    },
    mplus={
      n=8, dur=1743,
      core={ {32645,11.6},{51723,9.7},{1329,6.8},{1247227,5.5},{703,2.6},{1943,2.2},{1966,1.4},{1298826,1.0},{385627,0.8},{185311,0.5},{2983,0.5},{36554,0.4},{57934,0.4},{360194,0.4} }, -- Envenom, Fan of Knives, Mutilate, Crimson Tempest, Garrote, Rupture, Feint, Thistle Tea, Kingsbane, Crimson Vial, Sprint, Shadowstep, Tricks of the Trade, Deathmark
      watch={ {462854,96.5},{6673,96.2},{315496,96.0},{1264426,86.8},{394080,83.2},{207400,71.9},{32645,70.2},{1248775,65.7},{1264297,62.9},{462568,61.0} }, -- Skyfury, Battle Shout, Slice and Dice, Void-Touched, Scent of Blood, Ancestral Vigor, Envenom, Unshakeable Drive, Cold Blood, Elemental Resistance
      coach={ cn="怎么打：群怪改刀扇攒星，终结技用猩红风暴铺群体流血（怪能活 6 秒以上才值）；优先目标照旧毁伤+毒伤。佯攻按进循环里——AOE 伤害高的本子它就是你的血条。盯什么：猩红风暴的覆盖与怪群剩余血量的匹配；切割照旧全程维持。", en="How to play: Build with Fan of Knives on packs and finish with Crimson Tempest for group bleeds (worth it if mobs live 6+ seconds); priority targets still get Mutilate + Envenom. Weave Feint into the loop — in heavy-AoE dungeons it's your health bar. Watch: match Crimson Tempest coverage against pack lifetime; Slice and Dice stays permanent as ever." },
    },
  },
  ["ROGUE/OUTLAW"] = {
    specID=260,
    raid={
      n=5, dur=563, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="边缘之锋", server="奥尔加隆", region="CN", seq={13750,1214909,315341,1236616,193315,51690,1277933,315341,185763,185763,185763,193315} },
        { player="Loktark", server="Stormreaver", region="US", seq={13750,315496,1214909,271877,1297761,193315,193315,1236616,315341,185763,185763,185763} },
        { player="食尘剑怨念物", server="罗宁", region="CN", seq={13750,1214909,315496,193315,1236616,193315,185763,185763,185763,315341,193315,185763} },
      },
      core={ {185763,25.4},{193315,16.2},{315341,10.2},{2098,9.8},{441776,2.6},{271877,2.3},{13877,2.1},{2983,1.9},{13750,1.8},{51690,1.8},{1214909,1.5},{1966,1.0},{381989,0.7},{195457,0.7} }, -- Pistol Shot, Sinister Strike, Between the Eyes, Dispatch, Coup de Grace, Blade Rush, Blade Flurry, Sprint, Adrenaline Rush, Killing Spree, Roll the Bones, Feint, Keep It Rolling, Grappling Hook
      watch={ {1265931,91.5},{441326,90.9},{1287772,84.4},{1259486,84.3},{441786,74.2},{1229746,69.2},{1214909,65.3},{1241715,55.0},{1214935,54.6},{256171,51.0} }, -- Palmed Bullets, Flawless Form, Rune of Critical Power, Zero In, Escalating Blade, Arcanoweave Insight, Roll the Bones, Might of the Void, Triple Threat, Loaded Dice
      coach={ cn="怎么打：影袭产星（顶尖17.8次/分），机会触发的手枪射击优先打（30.9次/分=全场最高频，说明触发极多），斩击满星泄（10.1次/分），正中眉心按 CD 保持增益（覆盖97.2%）。刀锋冲刺和冲动转好就按。盯什么：正中眉心的增益剩余时间（97.2%是顶尖标准，等于从不断）；机会触发——亮了手枪射击免费且更疼。", en="How to play: Sinister Strike builds (top players: 17.8/min), Opportunity-procced Pistol Shots take priority (30.9/min — your busiest button, that's how often it procs), Dispatch dumps at full points (10.1/min), Between the Eyes on cooldown for its buff (97.2% uptime). Blade Rush and Adrenaline Rush on refresh. Watch: Between the Eyes' buff timer (97.2% is the top-player bar — it never drops); Opportunity procs — a lit Pistol Shot is free and hits harder." },
    },
    mplus={
      n=8, dur=1769,
      core={ {185763,20.6},{193315,12.9},{315341,9.4},{2098,8.9},{13877,4.4},{271877,4.2},{441776,2.4},{1966,2.2},{51690,1.6},{13750,1.6},{1214909,1.5},{2983,1.2},{195457,0.9},{381989,0.6} }, -- Pistol Shot, Sinister Strike, Between the Eyes, Dispatch, Blade Flurry, Blade Rush, Coup de Grace, Feint, Killing Spree, Adrenaline Rush, Roll the Bones, Sprint, Grappling Hook, Keep It Rolling
      watch={ {59628,94.9},{315341,91.4},{441326,87.1},{1265931,86.7},{1287772,80.6},{1259486,78.8},{207400,72.5},{441786,71.2},{382024,68.4},{462568,67.7} }, -- Tricks of the Trade, Between the Eyes, Flawless Form, Palmed Bullets, Rune of Critical Power, Zero In, Ancestral Vigor, Escalating Blade, Earthliving Weapon, Elemental Resistance
      coach={ cn="怎么打：2 个以上目标开剑刃乱舞（它把你的单体连击转成 AOE），其余手法不变。嫁祸丢给坦克配合拉怪。佯攻照常进循环。盯什么：剑刃乱舞的开关状态（切单体记得关注收益）；嫁祸诀窍 当常驻增益维护（顶尖玩家覆盖96.8%）。", en="How to play: Open Blade Flurry at 2+ targets (it converts your single-target combo into AoE); everything else stays the same. Tricks of the Trade to the tank on pulls, Feint woven in as usual. Watch: Blade Flurry's toggle state (mind its value when swapping to single-target); maintain Tricks like a permanent buff — top players hold it at 96.8%." },
    },
  },
  ["ROGUE/SUBTLETY"] = {
    specID=261,
    raid={
      n=5, dur=519, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Codeyy", server="ajeusyara", region="KR", seq={185438,196819,1856,212743,197835,196819,426591,185313,121471,1250533,212743,197835} },
        { player="Parse", server="Tichondrius", region="US", seq={185438,196819,1856,185438,196819,1236616,1297761,121471,185313,426591,280719,282449} },
        { player="Dommothop", server="Turalyon", region="US", seq={185438,196819,1856,185438,196819,185313,426591,121471,1236616,280719,282449,282449} },
      },
      core={ {196819,18.6},{53,7.9},{185438,7.0},{197835,4.3},{185313,3.1},{319175,3.0},{1966,1.4},{426591,1.3},{36554,0.8},{2983,0.7},{121471,0.7},{185311,0.6},{31224,0.3},{1856,0.3} }, -- Eviscerate, Backstab, Shadowstrike, Shuriken Storm, Shadow Dance, Black Powder, Feint, Goremaw's Bite, Shadowstep, Sprint, Shadow Blades, Crimson Vial, Cloak of Shadows, Vanish
      watch={ {1264521,92.3},{1248775,87.9},{1287774,83.2},{465,82.3},{385960,76.4},{1229746,57.5},{112942,42.6},{185422,42.5},{139,42.3},{386237,41.9} }, -- Find Weakness, Unshakeable Drive, Rune of Burning Haste, Devotion Aura, Lingering Shadow, Arcanoweave Insight, Shadow Focus, Shadow Dance, Renew, Fade to Nothing
      coach={ cn="怎么打：背刺产星（顶尖10.8次/分），暗影之舞窗口里换暗影打击（9.7次/分），刺骨满星泄（19.1次/分）。暗影之舞转好就进（3.3次/分），暗影之刃对齐爆发。盯什么：弱点识破（覆盖86.2%）——它几乎常驻说明顶尖玩家的舞和暗影打击衔接没有空档；暗影技巧的能量回馈（覆盖95.3%），星和能量都别溢出。", en="How to play: Backstab builds (top players: 10.8/min), Shadowstrike replaces it inside Shadow Dance windows (9.7/min), Eviscerate dumps at full combo points (19.1/min). Shadow Dance on refresh (3.3/min), Shadow Blades aligned with burst. Watch: Find Weakness (86.2% uptime) — near-permanent coverage means top players chain Dance and Shadowstrike with no gaps; Shadow Techniques energy feedback (95.3% uptime), never cap points or energy." },
    },
    mplus={
      n=8, dur=1747,
      core={ {319175,10.7},{197835,10.5},{196819,10.0},{53,4.4},{185438,3.3},{185313,2.8},{1966,2.1},{426591,1.0},{121471,0.6},{36554,0.5},{1784,0.4},{57934,0.4},{2983,0.3} }, -- Black Powder, Shuriken Storm, Eviscerate, Backstab, Shadowstrike, Shadow Dance, Feint, Goremaw's Bite, Shadow Blades, Shadowstep, Stealth, Tricks of the Trade, Sprint
      watch={ {465,97.3},{315496,96.3},{196911,95.8},{1264521,88.7},{1248775,81.8},{385960,71.4},{457115,64.8},{1241715,55.5},{1241759,53.2},{428488,43.9} }, -- Devotion Aura, Slice and Dice, Shadow Techniques, Find Weakness, Unshakeable Drive, Lingering Shadow, Momentum of Despair, Might of the Void, Genius Insight, Exhilarating Execution
      coach={ cn="怎么打：群怪用袖剑风暴攒星、黑火药终结；单体优先目标仍走刺骨。舞照常高频开，对齐怪群密度最高的时刻。佯攻常态化。盯什么：黑火药/刺骨按目标数切换；舞窗口里优先把星花完——窗口外的终结技亏一截。", en="How to play: Build with Shuriken Storm and finish with Black Powder on packs; priority singles still get Eviscerate. Keep opening Dance at high frequency, aligned with peak pack density. Feint stays routine. Watch: switch Black Powder/Eviscerate by target count; dump combo points inside Dance windows — finishers outside them lose real value." },
    },
  },
  ["SHAMAN/ELEMENTAL"] = {
    specID=262,
    raid={
      n=5, dur=521, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Eliasshaman", server="Thrall", region="EU", seq={191634,1236616,114050,1293316,443454,51505,188196,51505,188196,79206,51505,188196} },
        { player="Moneyshaman", server="Tichondrius", region="US", seq={191634,188196,188196,1236616,1293316,443454,114050,51505,79206,117014,51505,117014} },
        { player="Steambuns", server="Illidan", region="US", seq={51505,114050,1236616,1293316,443454,188196,51505,188196,51505,188196,79206,51505} },
      },
      core={ {188196,12.9},{51505,11.5},{188443,7.0},{117014,5.9},{188389,2.9},{443454,1.8},{462620,1.6},{191634,1.3},{79206,0.8},{114050,0.5},{2645,0.5},{1293316,0.5},{192063,0.4},{108271,0.3} }, -- Lightning Bolt, Lava Burst, Chain Lightning, Elemental Blast, Flame Shock, Ancestral Swiftness, Earthquake, Stormkeeper, Spiritwalker's Grace, Ascendance, Ghost Wolf, Empowering Venom, Gust of Wind, Astral Shift
      watch={ {1287772,87.3},{465,86.3},{372014,82.5},{173183,79.4},{173184,78.7},{118522,75.2},{1229746,67.7},{447244,66.7},{260734,32.1},{263806,23.6} }, -- Rune of Critical Power, Devotion Aura, Visage, Elemental Blast: Haste, Elemental Blast: Mastery, Elemental Blast: Critical Strike, Arcanoweave Insight, Call of the Ancestors, Master of the Elements, Wind Gust
      coach={ cn="怎么打：闪电箭是主填充（顶尖19.1次/分），熔岩爆裂吃烈焰震击的触发按（11.6次/分），烈焰震击全程不掉（2.5次/分=只补）。漩涡值喂元素冲击（6次/分），Tempest 触发了优先打（3.8次/分）。风暴守护者按 CD。盯什么：烈焰震击的剩余时间——熔岩爆裂的触发全靠它；漩涡值别溢出，元素冲击转好就泄。", en="How to play: Lightning Bolt is your filler (top players: 19.1/min), Lava Burst rides Flame Shock procs (11.6/min), and Flame Shock never drops (2.5/min = refresh only). Maelstrom feeds Elemental Blast (6/min); a procced Tempest takes priority (3.8/min). Stormkeeper on cooldown. Watch: Flame Shock's remaining time — every Lava Burst proc depends on it; never cap Maelstrom, dump Elemental Blast on refresh." },
    },
    mplus={
      n=8, dur=1719,
      core={ {188443,9.7},{51505,8.4},{61882,5.9},{188196,5.5},{470057,5.5},{117014,3.4},{443454,1.5},{191634,1.2},{2645,0.9},{1293316,0.5},{192063,0.5},{79206,0.4},{114050,0.4},{108271,0.3} }, -- Chain Lightning, Lava Burst, Earthquake, Lightning Bolt, Voltaic Blaze, Elemental Blast, Ancestral Swiftness, Stormkeeper, Ghost Wolf, Empowering Venom, Gust of Wind, Spiritwalker's Grace, Ascendance, Astral Shift
      watch={ {1287772,80.2},{447244,62.8},{118522,55.0},{173183,54.6},{173184,54.2},{1241866,42.6},{1307922,34.0},{77762,32.9},{1259491,28.7},{157128,27.1} }, -- Rune of Critical Power, Call of the Ancestors, Elemental Blast: Critical Strike, Elemental Blast: Haste, Elemental Blast: Mastery, Glistening Radiance, Venomcursed Mastery, Lava Surge, Purging Flames, Saved by the Light
      coach={ cn="怎么打：群怪改闪电链读条，漩涡值喂地震术（丢在怪群脚下、覆盖移动路径），熔岩爆裂留给挂了 烈焰震击 的优先目标。土元素常驻召唤——它是你的第二条命。盯什么：地震术的落点是否罩住怪群；目标数 2-3 个以上切闪电链，回到单体切回闪电箭。", en="How to play: Swap to Chain Lightning on packs and feed Maelstrom into Earthquake (placed under the pack, covering their path); Lava Burst goes to Flame-Shocked priority targets. Keep Earth Elemental summoned — it's your second life. Watch: Earthquake placement actually covering the pack; switch to Chain Lightning at 2-3+ targets and back to Lightning Bolt on singles." },
    },
  },
  ["SHAMAN/ENHANCEMENT"] = {
    specID=263,
    raid={
      n=5, dur=552, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Langni", server="Area 52", region="US", seq={470057,187874,17364,383781,114051,469270,452201,115356,469270,188196,115356,469270} },
        { player="Spreadout", server="Area 52", region="US", seq={470057,114051,1293316,469270,452201,187874,469270,188196,115356,469270,188196,115356} },
        { player="Try", server="Windrunner", region="US", seq={383781,470057,114051,469270,452201,187874,469270,188196,115356,469270,188196,115356} },
      },
      core={ {17364,16.2},{188196,10.4},{469270,10.1},{187874,7.7},{115356,5.2},{470057,5.0},{452201,4.8},{188443,3.1},{60103,1.6},{58875,0.7},{114051,0.5},{2645,0.4},{196884,0.4},{108271,0.3} }, -- Stormstrike, Lightning Bolt, Doom Winds, Crash Lightning, Windstrike, Voltaic Blaze, Tempest, Chain Lightning, Lava Lash, Spirit Walk, Ascendance, Ghost Wolf, Feral Lunge, Astral Shift
      watch={ {382889,97.1},{1252415,93.5},{344179,88.4},{454394,84.0},{465,83.8},{372014,67.7},{1229746,67.5},{1252488,64.7},{1241762,58.3},{470466,37.7} }, -- Flurry, Crash Lightning, Maelstrom Weapon, Unlimited Power, Devotion Aura, Visage, Arcanoweave Insight, Masterful Hunt, Frenzied Focus, Stormblast
      coach={ cn="怎么打：风暴打击和熔岩猛击转好就按（顶尖14.9和17次/分），毁灭闪电保持增益（7.2次/分），攒满漩涡武器层数后闪电箭泄（10.9次/分，覆盖86.8%=层数几乎不空）。末日之风和 Sundering 高频进轴（11和15.8次/分），Primordial Storm 窗口全力倾泻。盯什么：漩涡武器层数——满了立刻泄别浪费；热手触发（覆盖67.1%）让熔岩猛击免费且更疼。", en="How to play: Stormstrike and Lava Lash on refresh (top players: 14.9 and 17/min), Crash Lightning keeps its buff up (7.2/min), and Lightning Bolt dumps at max Maelstrom Weapon stacks (10.9/min, 86.8% uptime = stacks are never empty). Doom Winds and Sundering cycle in hard (11 and 15.8/min); pour everything into Primordial Storm windows. Watch: Maelstrom Weapon stacks — dump immediately at cap; Hot Hand procs (67.1% uptime) make Lava Lash free and harder-hitting." },
    },
    mplus={
      n=8, dur=1679,
      core={ {17364,13.9},{469270,9.1},{188443,8.4},{187874,7.4},{452201,4.5},{470057,4.4},{188196,4.2},{115356,4.0},{60103,1.4},{2645,0.6},{114051,0.4},{58875,0.3},{192058,0.3},{108271,0.3} }, -- Stormstrike, Doom Winds, Chain Lightning, Crash Lightning, Tempest, Voltaic Blaze, Lightning Bolt, Windstrike, Lava Lash, Ghost Wolf, Ascendance, Spirit Walk, Capacitor Totem, Astral Shift
      watch={ {465,97.0},{6673,96.8},{410681,90.5},{382889,88.9},{344179,85.0},{1252415,83.1},{454394,74.5},{1229746,58.8},{384451,33.8},{454025,31.8} }, -- Devotion Aura, Battle Shout, Overflowing Maelstrom, Flurry, Maelstrom Weapon, Crash Lightning, Unlimited Power, Arcanoweave Insight, Lightning Strikes, Electroshock
      coach={ cn="怎么打：先按毁灭闪电挂上 AOE 增益（没它你的群伤不成立），漩涡层改喂闪电链，风暴打击照常主键，风切插入。盯什么：毁灭闪电增益（84.7%覆盖）掉了先补它再继续；漩涡层在多目标下产得飞快——花的速度必须跟上，卡手就是亏。", en="How to play: Press Crash Lightning first to apply the AoE buff (without it your cleave doesn't function), route Maelstrom stacks into Chain Lightning, keep Stormstrike as the main button, weave Windstrike. Watch: the Crash Lightning buff (84.7% uptime) — if it drops, restore it before anything else; multi-target Maelstrom generation is torrential, so spend as fast as it builds." },
    },
  },
  ["SHAMAN/RESTORATION"] = {
    specID=264,
    raid={
      n=5, dur=522, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Driptinus", server="Argent Dawn", region="EU", seq={61295,98008,1064,5394,1064,444995,378081,1267068,1064,1064,61295,1064} },
        { player="Meowtide", server="Sylvanas", region="EU", seq={51505,188389,470411,61295,444995,378081,1267068,1064,1267068,1064,5394,1064} },
        { player="Xhottie", server="Stormrage", region="US", seq={61295,444995,61295,1291894,5394,1064,61295,1064,61295,77472,61295,108287} },
      },
      core={ {1064,16.3},{61295,11.4},{5394,3.6},{77472,3.4},{444995,2.2},{51505,1.8},{1267068,1.6},{188389,1.5},{108287,1.3},{378081,0.9},{77130,0.9},{2645,0.6},{79206,0.4},{114052,0.3} }, -- Chain Heal, Riptide, Healing Stream Totem, Healing Wave, Surging Totem, Lava Burst, Stormstream Totem, Flame Shock, Totemic Projection, Nature's Swiftness, Purify Spirit, Ghost Wolf, Spiritwalker's Grace, Ascendance
      watch={ {456369,91.8},{1307888,90.6},{1287772,87.7},{465,83.9},{53390,77.5},{1229746,68.8},{1241715,60.8},{453407,51.2},{470077,49.4},{462568,44.6} }, -- Amplification Core, Healing Rain, Rune of Critical Power, Devotion Aura, Tidal Waves, Arcanoweave Insight, Might of the Void, Whirling Water, Coalescing Water, Elemental Resistance
      coach={ cn="怎么打：激流按 CD 铺（顶尖10.8次/分），治疗链是群刷主力（19次/分，吃激流的潮汐涌动增益），生命释放强化下一个技能（2.9次/分）。治疗之泉图腾和涌动图腾转好就放。治疗间隙打熔岩爆裂和烈焰震击（2.5和2.1次/分）。盯什么：潮汐涌动（覆盖81.5%）——治疗链要吃着它读；图腾的落点和剩余时间，大轴前提前摆。", en="How to play: Riptide on cooldown (top players: 10.8/min), Chain Heal is your group-heal workhorse (19/min, riding Riptide's Tidal Waves buff), Unleash Life empowers the next spell (2.9/min). Healing Stream and Surging Totems on refresh. Fill healing gaps with Lava Burst and Flame Shock (2.5 and 2.1/min). Watch: Tidal Waves (81.5% uptime) — Chain Heal wants to be cast under it; totem placement and remaining duration, pre-drop before big damage." },
    },
    mplus={
      n=8, dur=1780,
      core={ {61295,7.5},{1064,6.6},{77472,6.6},{5394,2.9},{51505,2.6},{188389,2.2},{444995,2.0},{188443,1.9},{73685,1.7},{108287,1.3},{1267068,1.2},{188196,1.1},{378081,0.8},{2645,0.7} }, -- Riptide, Chain Heal, Healing Wave, Healing Stream Totem, Lava Burst, Flame Shock, Surging Totem, Chain Lightning, Unleash Life, Totemic Projection, Stormstream Totem, Lightning Bolt, Nature's Swiftness, Ghost Wolf
      watch={ {456369,85.1},{1307888,84.1},{1287772,83.4},{53390,72.4},{207400,71.4},{1264426,70.4},{462568,68.1},{382024,65.0},{1241715,55.9},{470077,47.5} }, -- Amplification Core, Healing Rain, Rune of Critical Power, Tidal Waves, Ancestral Vigor, Void-Touched, Elemental Resistance, Earthliving Weapon, Might of the Void, Coalescing Water
      coach={ cn="怎么打：点名治疗为主——激流先手、治疗波跟上，治疗链留给群伤瞬间。没人掉血就打熔岩爆裂和 烈焰震击 参与输出。治疗之泉、涌动图腾在拉怪前预置。盯什么：坦克身上保持激流常驻；图腾的覆盖范围跟上队伍走位，落后了及时挪。", en="How to play: Spot healing leads — Riptide first, Healing Wave follows, Chain Heal saved for group damage moments. When bars are stable, contribute Lava Burst and Flame Shock. Pre-place Healing Stream and Surging Totem before pulls. Watch: keep Riptide rolling on the tank; make sure totem range follows the group's movement — relocate them when left behind." },
    },
  },
  ["WARLOCK/AFFLICTION"] = {
    specID=265,
    raid={
      n=5, dur=536, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Zhocksy", server="Tarren Mill", region="EU", seq={48181,980,172,980,1236616,205180,1250508,1259790,1259790,1259790,1259790,1261153} },
        { player="Manni", server="ajeusyara", region="KR", seq={48181,980,172,205180,1236616,1259790,1259790,1257052,1259790,1261153,1259790,1261153} },
        { player="Hayner", server="Thrall", region="EU", seq={48181,1259790,980,172,1257052,205180,1293316,1236616,1259790,1259790,1259790,1259790} },
      },
      core={ {1259790,17.2},{980,7.7},{198590,6.5},{48181,3.4},{1261153,2.5},{1257052,1.2},{172,0.8},{1250508,0.6},{108416,0.6},{205180,0.6},{111400,0.6},{119905,0.3},{27243,0.3},{6789,0.3} }, -- Unstable Affliction, Agony, Drain Soul, Haunt, Malefic Grasp, Dark Harvest, Corruption, Emberwing Heatwave, Dark Pact, Summon Darkglare, Burning Rush, Singe Magic, Seed of Corruption, Mortal Coil
      watch={ {1261125,96.6},{1305774,91.5},{1287772,77.2},{1229746,71.7},{1241715,55.5},{108366,42.4},{462568,40.1},{264571,39.6},{449793,34.0},{382024,33.5} }, -- Cascading Calamity, Unstable Empowerment, Rune of Critical Power, Arcanoweave Insight, Might of the Void, Soul Leech, Elemental Resistance, Nightfall, Succulent Soul, Earthliving Weapon
      coach={ cn="怎么打：痛楚全程不掉（6.5次/分），痛苦无常是高频主轴（顶尖19.5次/分），鬼影缠身按 CD（3.6次/分），暗影箭/Malefic Grasp 填充。幽冥收割和召唤黑眼对齐爆发轴，DoT 铺满再开。盯什么：所有 DoT 的剩余时间——痛苦术的一切都建立在 DoT 全挂之上；灵魂碎片别溢出，黑眼窗口前攒满。", en="How to play: Agony never drops (6.5/min), Unstable Affliction is your high-frequency core (top players: 19.5/min), Haunt on cooldown (3.6/min), Shadow Bolt or Malefic Grasp fills. Dark Harvest and Summon Darkglare align with burst — DoTs fully rolled before opening. Watch: every DoT's remaining time — everything Affliction does stands on full DoT coverage; never cap soul shards, bank them before Darkglare windows." },
    },
    mplus={
      n=8, dur=1667,
      core={ {686,9.9},{27243,9.2},{980,6.7},{1259790,5.6},{48181,3.0},{172,1.4},{1257052,1.0},{119910,0.9},{108416,0.6},{111400,0.5},{385899,0.4},{205180,0.4},{1714,0.3} }, -- Shadow Bolt, Seed of Corruption, Agony, Unstable Affliction, Haunt, Corruption, Dark Harvest, Spell Lock, Dark Pact, Burning Rush, Soulburn, Summon Darkglare, Curse of Tongues
      watch={ {108366,82.8},{1287772,77.5},{1305774,74.2},{1229746,53.3},{1241715,51.3},{264571,44.9},{449793,42.1},{48018,32.7},{1269042,16.3},{1295898,15.3} }, -- Soul Leech, Rune of Critical Power, Unstable Empowerment, Arcanoweave Insight, Might of the Void, Nightfall, Succulent Soul, Demonic Circle, Manifested Demonic Soul, Versatile Ritual
      coach={ cn="怎么打：进怪群腐蚀之种先手（一发铺全场），痛楚和无常往主要目标上挂，吸取灵魂照常引导。黑暗契约按节奏保命。盯什么：种子的引爆目标选血厚的（保证炸得出来）；灵魂榨取护盾（84.7%覆盖）就是你的被动血条——DOT 不停它就不停。", en="How to play: Lead packs with Seed of Corruption (one cast blankets everything), hang Agony and UA on primary targets, channel Drain Soul as usual. Dark Pact rhythmically for survival. Watch: detonate Seeds off high-health targets (so they actually pop); your Soul Leech shield (84.7% uptime) is a passive health bar — it keeps flowing as long as your DoTs do." },
    },
  },
  ["WARLOCK/DEMONOLOGY"] = {
    specID=266,
    raid={
      n=5, dur=530, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="游荡小鬼", server="死亡之翼", region="CN", seq={1276452,686,265187,1293316,105174,105174,686,196277,686,686,105174,686} },
        { player="Pfw", server="Mal'Ganis", region="US", seq={264178,1276452,104316,686,1250508,265187,105174,105174,108416,686,686,196277} },
        { player="Kastarak", server="Kazzak", region="EU", seq={264178,104316,1293316,1236616,1276452,265187,686,111400,105174,105174,196277,686} },
      },
      core={ {105174,13.3},{264178,10.4},{686,8.4},{196277,3.4},{104316,2.8},{434635,1.5},{265187,1.0},{108416,1.0},{111400,0.9},{1276452,0.6},{1293316,0.5},{6789,0.4} }, -- Hand of Gul'dan, Demonbolt, Shadow Bolt, Implosion, Call Dreadstalkers, Ruination, Summon Demonic Tyrant, Dark Pact, Burning Rush, Grimoire: Imp Lord, Empowering Venom, Mortal Coil
      watch={ {1281559,96.9},{1276623,95.3},{465,82.7},{1287772,81.0},{1269879,74.2},{1229746,63.3},{1269643,58.4},{1241715,56.4},{382024,51.0},{264173,47.8} }, -- Hellbent Commander, Singe Magic, Devotion Aura, Rune of Critical Power, Mind's Eyes, Arcanoweave Insight, Demonic Oculi, Might of the Void, Earthliving Weapon, Demonic Core
      coach={ cn="怎么打：暗影箭攒碎片（8.7次/分），古尔丹之手满3碎片砸（顶尖17.1次/分），恶魔核心触发的恶魔之箭优先（14.8次/分，核心覆盖71.2%=触发不断）。召唤恐惧猎犬转好就放（2.9次/分），恶魔暴君把场上恶魔全部延长——开之前把恶魔铺满。盯什么：恶魔核心层数——有触发先吃；暴君窗口前的铺场节奏（猎犬+小鬼都在场再开）。", en="How to play: Shadow Bolt builds shards (8.7/min), Hand of Gul'dan slams at three (top players: 17.1/min), and Demonic Core-procced Demonbolts take priority (14.8/min, 71.2% Core uptime = procs keep flowing). Call Dreadstalkers on refresh (2.9/min); Summon Demonic Tyrant extends everything on the field — fill your board first. Watch: Demonic Core stacks — spend procs first; your pre-Tyrant setup rhythm (dogs and imps out before you press it)." },
    },
    mplus={
      n=8, dur=1795,
      core={ {105174,11.8},{264178,9.2},{686,7.2},{196277,2.9},{104316,2.6},{434635,1.4},{108416,0.8},{265187,0.8},{385899,0.6},{119914,0.6},{1276452,0.4},{1714,0.4},{6789,0.3},{111400,0.3} }, -- Hand of Gul'dan, Demonbolt, Shadow Bolt, Implosion, Call Dreadstalkers, Ruination, Dark Pact, Summon Demonic Tyrant, Soulburn, Axe Toss, Grimoire: Imp Lord, Curse of Tongues, Mortal Coil, Burning Rush
      watch={ {1281559,97.4},{1276623,85.8},{108366,84.7},{48018,84.1},{1287772,77.3},{264173,63.4},{1269879,62.7},{1269643,57.4},{1229746,48.1},{1276166,34.1} }, -- Hellbent Commander, Singe Magic, Soul Leech, Demonic Circle, Rune of Critical Power, Demonic Core, Mind's Eyes, Demonic Oculi, Arcanoweave Insight, Dominion of Argus
      coach={ cn="怎么打：手法同团本，多一个决策：怪群快死时内爆把小鬼炸成 AOE，怪群能活就攒着等暴君。古尔丹之手照常铺场。盯什么：怪群剩余存活时间（内爆/留暴君的分水岭）；小鬼的能量在衰减——犹豫太久它们自己就消失了，该炸就炸。", en="How to play: Same hands as raid, plus one decision: Implode your imps into AoE when the pack is about to die, or hold them for Tyrant if it'll live. Hand of Gul'dan keeps seeding as usual. Watch: pack lifetime is the Implosion-versus-Tyrant dividing line; imp energy decays — hesitate too long and they expire on their own, so detonate when the call is made." },
    },
  },
  ["WARLOCK/DESTRUCTION"] = {
    specID=267,
    raid={
      n=5, dur=522, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="taenggeulreumang", server="ajeusyara", region="KR", seq={6353,17962,1122,1250533,1236616,442726,116858,116858,29722,17962,116858,29722} },
        { player="Badros", server="Ragnaros", region="EU", seq={6353,1122,1250533,17962,442726,1236616,116858,29722,116858,17962,116858,29722} },
        { player="Jaylokk", server="Mal'Ganis", region="US", seq={6353,1122,1250533,442726,1236616,17962,116858,116858,29722,17962,116858,17962} },
      },
      core={ {29722,12.4},{116858,9.2},{17877,8.4},{17962,8.2},{445468,4.8},{6353,1.3},{80240,1.2},{442726,1.0},{111400,0.8},{1122,0.7},{1250533,0.7},{108416,0.6} }, -- Incinerate, Chaos Bolt, Shadowburn, Conflagrate, Wither, Soul Fire, Havoc, Malevolence, Burning Rush, Summon Infernal, Freightrunner's Flask, Dark Pact
      watch={ {372014,92.8},{1265939,91.5},{1287772,86.7},{465,83.6},{1229746,63.6},{1241715,59.5},{382024,57.6},{442726,56.7},{462568,52.1},{139,50.3} }, -- Visage, Vision of Nihilam, Rune of Critical Power, Devotion Aura, Arcanoweave Insight, Might of the Void, Earthliving Weapon, Malevolence, Elemental Resistance, Renew
      coach={ cn="怎么打：烧尽攒碎片（顶尖16次/分），混乱之箭满碎片泄（10.8次/分），燃烧按 CD 给暴击触发（8.4次/分），暗影灼烧高频插缝（7.8次/分）。灵魂之火和 Malevolence 按 CD，召唤地狱火对齐爆发轴。盯什么：灵魂碎片别溢出——燃烧转好前把碎片花掉；混乱之箭尽量在增益窗口里打出去。", en="How to play: Incinerate builds shards (top players: 16/min), Chaos Bolt dumps at full shards (10.8/min), Conflagrate on cooldown for crit procs (8.4/min), Shadowburn weaves in often (7.8/min). Soul Fire and Malevolence on cooldown; Summon Infernal aligns with burst. Watch: never cap soul shards — spend before Conflagrate refreshes; land Chaos Bolts inside buff windows whenever possible." },
    },
    mplus={
      n=8, dur=1711,
      core={ {29722,9.1},{1244918,8.2},{17877,7.1},{17962,6.8},{116858,6.5},{5740,3.9},{348,1.6},{152108,1.2},{434635,1.1},{6353,1.0},{111400,0.6},{119910,0.6},{1122,0.6},{108416,0.5} }, -- Incinerate, Lake of Fire, Shadowburn, Conflagrate, Chaos Bolt, Rain of Fire, Immolate, Cataclysm, Ruination, Soul Fire, Burning Rush, Spell Lock, Summon Infernal, Dark Pact
      watch={ {108366,84.1},{1265939,80.5},{1287772,80.0},{1269643,78.1},{1234969,77.6},{1269879,60.4},{1229746,57.7},{48018,54.8},{117828,40.2},{1252488,30.0} }, -- Soul Leech, Vision of Nihilam, Rune of Critical Power, Demonic Oculi, Ethereal Augmentation, Mind's Eyes, Arcanoweave Insight, Demonic Circle, Backdraft, Masterful Hunt
      coach={ cn="怎么打：群怪灰烬改喂火焰之雨（怪群脚下连铺），大灾变一发把献祭铺满全场，混乱之箭只打必须死的优先目标。火焰之湖 维持。盯什么：火焰之雨的覆盖与怪群走位；3 个以上目标雨更值，回到单体马上切回混乱之箭——这条切换线打熟它。", en="How to play: On packs, pour embers into Rain of Fire (layered under the pack) and spread Immolate everywhere with one Cataclysm; Chaos Bolt only hits priority targets that must die. Keep Lake of Fire maintained. Watch: Rain of Fire's coverage versus pack movement; Rain wins at 3+ targets and Chaos Bolt takes over on singles — drill that switching line until it's automatic." },
    },
  },
  ["WARRIOR/ARMS"] = {
    specID=71,
    raid={
      n=5, dur=557, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Jokerrdx", server="Tarren Mill", region="EU", seq={100,126664,845,107574,1293316,167105,1236616,281000,1269383,446035,12294,107570} },
        { player="Swordish", server="Aerie Peak", region="US", seq={100,845,126664,107574,167105,281000,446035,12294,12294,12294,12294,12294} },
        { player="Faris", server="Frostmourne", region="US", seq={126664,845,107574,167105,281000,281000,12294,446035,12294,12294,12294,23920} },
      },
      core={ {12294,16.9},{281000,12.1},{7384,6.4},{1269383,5.1},{845,4.4},{1464,2.8},{167105,1.9},{446035,1.8},{107574,1.0},{23920,0.8},{260708,0.7},{100,0.7},{52174,0.4},{384110,0.3} }, -- Mortal Strike, Execute, Overpower, Heroic Strike, Cleave, Slam, Colossus Smash, Bladestorm, Avatar, Spell Reflection, Sweeping Strikes, Charge, Heroic Leap, Wrecking Throw
      watch={ {1269394,97.3},{445584,97.1},{260708,93.1},{1287774,87.8},{372014,85.6},{445606,79.6},{1300670,78.7},{392778,75.7},{1292058,72.3},{1241762,60.5} }, -- Master of Warfare, Executioner, Sweeping Strikes, Rune of Burning Haste, Visage, Imminent Demise, Winding Up, Wild Strikes, Heroic Might, Frenzied Focus
      coach={ cn="怎么打：致死打击 CD 好了必按（顶尖17.5次/分），压制喂它增伤（11.1次/分），斩杀段斩杀优先（11.7次/分=斩杀期占比很大）。巨人打击按 CD 开窗口（2.3次/分），窗口内把致死和斩杀全压进去。撕裂别掉（1.6次/分）。怒气多了英勇打击泄。盯什么：巨人打击的破甲窗口——你的爆发全在里面；处刑人（覆盖94%）说明斩杀段的节奏就是一切。", en="How to play: Mortal Strike on cooldown always (top players: 17.5/min), Overpower feeds it (11.1/min), Execute takes over in execute range (11.7/min — that phase is huge). Colossus Smash opens windows on cooldown (2.3/min); pack Mortal Strikes and Executes inside. Keep Rend up (1.6/min). Dump excess rage with Heroic Strike. Watch: the Colossus Smash armor-break window — all your burst lives there; Executioner at 94% uptime says execute-phase rhythm is everything." },
    },
    mplus={
      n=8, dur=1735,
      core={ {12294,13.9},{281000,11.1},{845,8.0},{7384,7.7},{1269383,2.5},{446035,1.8},{167105,1.6},{260708,1.3},{100,0.9},{1464,0.9},{23920,0.9},{107574,0.8} }, -- Mortal Strike, Execute, Cleave, Overpower, Heroic Strike, Bladestorm, Colossus Smash, Sweeping Strikes, Charge, Slam, Spell Reflection, Avatar
      watch={ {445584,92.8},{1269394,92.2},{260708,84.9},{1287774,82.5},{445606,76.3},{1292058,73.9},{1295582,73.3},{392778,72.2},{207400,67.8},{1300670,66.7} }, -- Executioner, Master of Warfare, Sweeping Strikes, Rune of Burning Haste, Imminent Demise, Heroic Might, Focus of Ula'tek, Wild Strikes, Ancestral Vigor, Winding Up
      coach={ cn="怎么打：进怪群第一件事按横扫挂增益——挂上后你的致死打击和压制全变成范围技；增益快掉就续，AOE 期间绝不裸打。撕裂铺给会活久的目标。崩摧 CD 好了对怪群放。盯什么：横扫增益的剩余时间（它是 AOE 的开关）；怪群血量决定撕裂值不值得铺。", en="How to play: First button into any pack is Sweeping Strikes for its buff — once applied, your Mortal Strikes and Overpowers all cleave; refresh it before it falls and never swing without it during AoE. Rend goes on targets that will live. Demolish on cooldown into the pack. Watch: the Sweeping Strikes buff's remaining duration (it's the AoE switch); pack health decides whether Rend is worth spreading." },
    },
  },
  ["WARRIOR/FURY"] = {
    specID=72,
    raid={
      n=5, dur=560, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="桀骜斯达瑞", server="雷克萨", region="CN", seq={1719,1236616,184367,446035,335096,335096,184367,385059,385060,385061,385062,385061} },
        { player="Chideki", server="Blackhand", region="EU", seq={100,1719,126664,184367,446035,335096,107570,335096,5308,184367,335097,184367} },
        { player="Zuo", server="Frostmourne", region="US", seq={1719,100,385059,126664,385060,385061,385062,385061,184367,446035,335096,107570} },
      },
      core={ {184367,19.1},{85288,10.1},{5308,6.9},{335097,6.0},{335096,4.7},{23881,4.3},{190411,3.9},{446035,1.3},{1719,1.3},{385060,1.2},{100,1.0},{107570,0.7},{23920,0.6},{52174,0.3} }, -- Rampage, Raging Blow, Execute, Crushing Blow, Bloodbath, Bloodthirst, Whirlwind, Bladestorm, Recklessness, Odyn's Fury, Charge, Storm Bolt, Spell Reflection, Heroic Leap
      watch={ {335082,97.2},{445584,96.6},{1269349,94.4},{184362,87.1},{1287774,84.7},{465,83.3},{445606,79.7},{392778,79.7},{372014,70.1},{1229746,67.0} }, -- Frenzy, Executioner, Berserk, Enrage, Rune of Burning Haste, Devotion Aura, Imminent Demise, Wild Strikes, Visage, Arcanoweave Insight
      coach={ cn="怎么打：暴怒是怒气出口（顶尖21.6次/分，激怒全靠它），嗜血和 Bloodbath 产怒（11.3和10.4次/分），怒击插缝（6.7次/分），斩杀段斩杀高频进轴（10.2次/分）。奥丁之怒和剑刃风暴按 CD。盯什么：狂乱层数（覆盖95.7%=顶尖几乎不断层）——暴怒要按得够勤它才不掉；激怒状态没了优先暴怒补回来。", en="How to play: Rampage is your rage outlet (top players: 21.6/min — Enrage depends on it), Bloodthirst and Bloodbath generate (11.3 and 10.4/min), Raging Blow fills (6.7/min), and Execute cycles in hard during execute range (10.2/min). Odyn's Fury and Bladestorm on cooldown. Watch: Frenzy stacks (95.7% uptime = top players basically never drop them) — Rampage often enough to keep them rolling; if Enrage falls off, Rampage first to restore it." },
    },
    mplus={
      n=8, dur=1700,
      core={ {184367,19.8},{190411,8.1},{85288,7.5},{5308,6.7},{335097,6.1},{335096,4.8},{23881,4.6},{1719,1.2},{385060,1.2},{446035,1.2},{23920,0.9},{100,0.6},{184364,0.3} }, -- Rampage, Whirlwind, Raging Blow, Execute, Crushing Blow, Bloodbath, Bloodthirst, Recklessness, Odyn's Fury, Bladestorm, Spell Reflection, Charge, Enraged Regeneration
      watch={ {1459,94.7},{445584,89.8},{335082,89.7},{1269349,88.8},{184362,86.0},{1287771,81.4},{445606,80.4},{392778,75.9},{85739,59.6},{1229746,58.1} }, -- Arcane Intellect, Executioner, Frenzy, Berserk, Enrage, Rune of Masterful Cunning, Imminent Demise, Wild Strikes, Whirlwind, Arcanoweave Insight
      coach={ cn="怎么打：先按旋风斩挂顺劈增益（之后两次单体技能自动溅射），然后照常暴怒/嗜血/斩杀——记住每两次主力技能就要补一次旋风斩。鲁莽对齐怪群开。盯什么：旋风斩增益的剩余次数；激怒覆盖纪律不变（91.3%）——AOE 打得再欢，激怒断了都是白打。", en="How to play: Press Whirlwind first for its cleave buff (your next two single-target abilities splash automatically), then run Rampage/Bloodthirst/Execute as usual — remembering to re-Whirlwind every two main attacks. Recklessness aligned with packs. Watch: the Whirlwind buff's remaining charges; Enrage discipline is unchanged (91.3%) — however busy the AoE gets, swinging without Enrage is wasted effort." },
    },
  },
  ["WARRIOR/PROTECTION"] = {
    specID=73,
    raid={
      n=5, dur=548, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Sense", server="Tichondrius", region="US", seq={100,107574,435222,2565,126664,1236616,1160,435222,2565,385952,435222,23922} },
        { player="Whitearms", server="Kil'jaeden", region="US", seq={100,126664,23922,107574,1293316,1236616,1160,435222,2565,190456,435222,385952} },
        { player="Hubartus", server="Blackhand", region="EU", seq={100,57755,126664,1236616,107574,1160,2565,6343,385952,385954,2565,23922} },
      },
      core={ {23922,13.2},{190456,11.9},{6572,9.2},{6343,9.1},{2565,5.2},{1160,1.6},{100,1.2},{107574,1.1},{57755,0.8},{23920,0.8},{871,0.8},{52174,0.7},{202168,0.6} }, -- Shield Slam, Ignore Pain, Revenge, Thunder Clap, Shield Block, Demoralizing Shout, Charge, Avatar, Heroic Throw, Spell Reflection, Shield Wall, Heroic Leap, Impending Victory
      watch={ {202602,92.0},{23922,91.6},{465,84.6},{132404,82.2},{372014,74.6},{190456,67.6},{1229746,67.1},{392778,66.3},{1241715,62.2},{1278009,55.7} }, -- Into the Fray, Shield Slam, Devotion Aura, Shield Block, Visage, Ignore Pain, Arcanoweave Insight, Wild Strikes, Might of the Void, Phalanx
      coach={ cn="怎么打：盾牌猛击 CD 好了必按（顶尖21.1次/分，输出和怒气都靠它），怒气优先喂无视苦痛保持吸收盾常驻（覆盖92.9%）；物理承伤期盾牌格挡必须在线（覆盖92.5%）——两层充能轮着用别同时烧光。复仇触发亮了免费按（10.1次/分）。挫志怒吼和天神下凡按 CD。盯什么：盾牌格挡的剩余时间和充能数；无视苦痛的吸收量余量。", en="How to play: Shield Slam on cooldown always (top players: 21.1/min — it drives both damage and rage), rage fed into Ignore Pain to keep the absorb shield standing (92.9% uptime); Shield Block must be active through physical damage (92.5% uptime) — cycle its two charges rather than burning both. Press free Revenge procs (10.1/min). Demoralizing Shout and Avatar on cooldown. Watch: Shield Block's duration and charges; how much Ignore Pain absorb remains." },
    },
    mplus={
      n=8, dur=1677,
      core={ {190456,16.9},{23922,15.5},{6572,9.2},{6343,8.3},{2565,5.4},{1160,1.9},{107574,1.0},{23920,0.8},{100,0.8},{163201,0.6},{57755,0.6},{384110,0.5},{202168,0.5},{46968,0.5} }, -- Ignore Pain, Shield Slam, Revenge, Thunder Clap, Shield Block, Demoralizing Shout, Avatar, Spell Reflection, Charge, Execute, Heroic Throw, Wrecking Throw, Impending Victory, Shockwave
      watch={ {202602,96.9},{386029,94.2},{23922,90.1},{132404,87.0},{1287774,80.9},{190456,76.7},{207400,74.7},{382024,64.6},{392778,60.6},{107574,55.3} }, -- Into the Fray, Brace For Impact, Shield Slam, Shield Block, Rune of Burning Haste, Ignore Pain, Ancestral Vigor, Earthliving Weapon, Wild Strikes, Avatar
      coach={ cn="怎么打：拉怪用雷霆一击抓仇恨+减速（按得比团本勤得多），盾猛/无视苦痛双核照旧。法系怪群盾块挡不住——读条怪抬手时法术反射怼回去。盯什么：盾牌格挡对齐物理怪的攻击节奏；怪群里谁在读条（法术反射的目标）；无视苦痛在 AOE 承伤期保持满额。", en="How to play: Pull with Thunder Clap for threat and slows (pressed far more than in raid), with the Shield Slam / Ignore Pain core unchanged. Shield Block can't stop casters — answer their cast bars with Spell Reflection instead. Watch: Shield Block timed against physical swing patterns; which pack member is casting (your Spell Reflection target); Ignore Pain kept topped through AoE damage." },
    },
  },
}
GearInsightRotation.notes = {
  [139]={ cn="15秒内缓慢回血", en="Heals over 15 sec" },
  [768]={ cn="变猫加伤害和移速，解减速，免疫变羊", en="Turn into a cat, more damage and speed, break slows, immune to Polymorph." },
  [5217]={ cn="回50能量，伤害提高15%，持续10秒。", en="Restores 50 energy and increases damage by 15% for 10 sec." },
  [5487]={ cn="变熊加护甲和耐力，免疫变羊，仇恨更高，变身后解定身。", en="Bear form: +220% armor, +25% stamina, immune to Polymorph, more threat, breaks roots on shift." },
  [6673]={ cn="全队攻击强度提高5%，持续1小时。", en="Increases party/raid attack power by 5% for 1 hour." },
  [16870]={ cn="生命绽放回血有4%几率让下个愈合免费。", en="Lifebloom HoT has 4% chance to make next Regrowth free." },
  [19574]={ cn="你和宠物伤害+20%，持续15秒，并立即造成280物理伤害，移除宠物控制效果。", en="You and pet deal 20% more damage for 15 sec, instantly deal 280 Physical damage, and remove pet CC." },
  [22812]={ cn="减伤20%且施法不被打断，持续8秒，控场时可用。", en="20% damage reduction and uninterruptible casting for 8 sec, usable while CC'd." },
  [23922]={ cn="用盾牌猛击造成物理伤害并产生怒气", en="Slams with shield for damage and generates rage" },
  [24858]={ cn="变枭兽，法伤+10%，护甲+125%，免疫变形，解定身。", en="Turn into a moonkin, +10% spell damage, +125% armor, immune to polymorph, break roots." },
  [31884]={ cn="伤害治疗爆击提高20%，持续20秒。", en="Increases damage, healing, and crit chance by 20% for 20 sec." },
  [32645]={ cn="终结技，立即造成自然伤害并提高药膏生效几率30%。", en="Finisher dealing instant Nature damage and boosting poison application chance by 30%." },
  [102558]={ cn="强化熊形态，狂暴+裂伤打3目标+30%血量，持续30秒可自由切换形态。", en="Improved Bear Form with Berserk, Mangle hits 3 targets, +30% health, lasts 30s, freely switch forms." },
  [107574]={ cn="变巨人，伤害+20%，范围伤害-5%，持续20秒。", en="Transform into a giant, +20% damage, -5% AoE damage taken, 20 sec." },
  [108366]={ cn="单体伤害给自身和宠物加盾，吸收3%伤害，最多5%血量。", en="Single-target damage grants shields absorbing 3% of damage dealt, up to 5% health." },
  [156322]={ cn="给队友回血并持续16秒，对自己用效果+25%", en="Heals ally over time, 25% more on self" },
  [187827]={ cn="变恶魔15秒，血量+40%并回血，护甲+200%", en="Transform into demon for 15s, +40% HP heal, +200% armor" },
  [190456]={ cn="12秒内减伤50%，最多挡451点伤害。", en="Reduce damage taken by 50% for 12 sec or until 451 damage prevented." },
  [191034]={ cn="召唤星辰打击40码内敌人，8秒造成伤害，可叠加。", en="Calls stars to hit enemies within 40 yds, dealing damage over 8 sec, can overlap." },
  [192081]={ cn="护甲提高124点，持续7秒。", en="Increases armor by 124 for 7 sec." },
  [198103]={ cn="召唤土元素，拉怪并嘲讽敌人，持续30秒。", en="Summon an earth elemental to tank and taunt enemies for 30 sec." },
  [200183]={ cn="重置圣言术CD，20秒内圣言术冷却缩短200%，消耗减半。", en="Reset Holy Words CD, 20 sec of 200% faster cooldown and 50% less cost." },
  [204066]={ cn="放月光，打怪加精通还回血", en="Deals damage, boosts mastery, and heals you." },
  [232698]={ cn="变暗影形态，法术伤害+10%。", en="Shadowform increases spell damage by 10%." },
  [258920]={ cn="6秒内对周围造成火焰伤害", en="Deals fire damage to nearby enemies over 6 sec." },
  [260708]={ cn="下12次单体技能额外打一个附近目标，伤害75%。", en="Next 12 single-target abilities hit an extra nearby target for 75% damage." },
  [315341]={ cn="手枪终结技，增伤4%，可叠加。", en="Finisher with pistol, +4% damage, stacks." },
  [315496]={ cn="终结技，消耗连击点，攻速+50%，连击点越多持续越久。", en="Finisher: +50% attack speed, longer per combo point." },
  [316440]={ cn="压制和猛击增伤下次致死打击，最多叠3层", en="Overpower and Slam boost next Mortal Strike damage, up to 3 stacks" },
  [358267]={ cn="飞起加速30%持续6秒，移动施法，不影响蓄力。", en="Fly up, 30% speed for 6 sec, cast while moving, not for empowered." },
  [386164]={ cn="爆击+3%，减速时间-10%，持续到取消。", en="Crit +3%, slow duration -10%, lasts until canceled." },
  [386196]={ cn="自动攻击伤害+15%，恐惧/闷棍/瘫痪时间-10%。", en="Auto-attack damage +15%, Fear/Sap/Incapacitate duration -10%." },
  [395152]={ cn="给队友加你8%主属性，自己加20%伤害，超过2人效果分摊，喷发等技能可延长。", en="Give allies 8% of your main stat, yourself 20% damage, split if more than 2 allies, extendable by Eruption etc." },
  [1214909]={ cn="掷骰子随机获得战斗增益，效果随骰子数提升。", en="Roll dice for random combat buffs; more dice = stronger effects." },
  [1241059]={ cn="喝药酒造守卫，吸收30%伤害最多794点", en="Drink brew to create guard absorbing 30% damage up to 794." },
}
GearInsightRotation.sources = {
  [139]={ cn="天赋「恢复」", en="Talent: Renew", t="talent" },
  [5217]={ cn="天赋「猛虎之怒」", en="Talent: Tiger's Fury", t="talent" },
  [19574]={ cn="天赋「狂野怒火」", en="Talent: Bestial Wrath", t="talent" },
  [24858]={ cn="天赋「枭兽形态」", en="Talent: Moonkin Form", t="talent" },
  [31884]={ cn="天赋「复仇之怒」", en="Talent: Avenging Wrath", t="talent" },
  [41635]={ cn="套装「角斗士的天职」", en="Set bonus: 角斗士的天职" },
  [48018]={ cn="天赋「Demonic Circle」", en="Talent: Demonic Circle", t="talent" },
  [51460]={ cn="套装「死灵骨制战甲」", en="Set bonus: 死灵骨制战甲" },
  [53390]={ cn="天赋「Tidal Waves」", en="Talent: Tidal Waves", t="talent" },
  [54149]={ cn="天赋「Infusion of Light」", en="Talent: Infusion of Light", t="talent" },
  [59628]={ cn="天赋「Tricks of the Trade」", en="Talent: Tricks of the Trade", t="talent" },
  [77535]={ cn="套装「魔颅骨板战甲」", en="Set bonus: 魔颅骨板战甲" },
  [93622]={ cn="天赋「Gore」", en="Talent: Gore", t="talent" },
  [102558]={ cn="天赋「化身：乌索克的守护者」", en="Talent: Incarnation: Guardian of Ursoc", t="talent" },
  [107574]={ cn="天赋「天神下凡」", en="Talent: Avatar", t="talent" },
  [108366]={ cn="天赋「灵魂榨取」", en="Talent: Soul Leech", t="talent" },
  [115867]={ cn="天赋「Mana Tea」", en="Talent: Mana Tea", t="talent" },
  [117828]={ cn="天赋「Backdraft」", en="Talent: Backdraft", t="talent" },
  [129914]={ cn="天赋「Combat Wisdom」", en="Talent: Combat Wisdom", t="talent" },
  [132403]={ cn="套装「公正护甲」", en="Set bonus: 公正护甲" },
  [132404]={ cn="套装「毁灭者护甲」", en="Set bonus: 毁灭者护甲" },
  [135700]={ cn="套装「夜歌战甲」", en="Set bonus: 夜歌战甲" },
  [156322]={ cn="天赋「永恒之火」", en="Talent: Eternal Flame", t="talent" },
  [162264]={ cn="套装「善变惩罚者的织痛战甲」", en="Set bonus: 善变惩罚者的织痛战甲" },
  [182104]={ cn="天赋「Shining Light」", en="Talent: Shining Light", t="talent" },
  [184362]={ cn="套装「鬼林护甲」", en="Set bonus: 鬼林护甲" },
  [188290]={ cn="套装「天灾领主战铠」", en="Set bonus: 天灾领主战铠" },
  [188370]={ cn="套装「正义」", en="Set bonus: 正义" },
  [190456]={ cn="天赋「无视苦痛」", en="Talent: Ignore Pain", t="talent" },
  [191034]={ cn="天赋「星辰坠落」", en="Talent: Starfall", t="talent" },
  [192081]={ cn="天赋「铁鬃」", en="Talent: Ironfur", t="talent" },
  [193065]={ cn="天赋「Protective Light」", en="Talent: Protective Light", t="talent" },
  [194879]={ cn="天赋「Icy Talons」", en="Talent: Icy Talons", t="talent" },
  [195630]={ cn="套装「阴郁凝视战甲」", en="Set bonus: 阴郁凝视战甲" },
  [196741]={ cn="天赋「Hit Combo」", en="Talent: Hit Combo", t="talent" },
  [196742]={ cn="天赋「Whirling Dragon Punch」", en="Talent: Whirling Dragon Punch", t="talent" },
  [198103]={ cn="天赋「土元素」", en="Talent: Earth Elemental", t="talent" },
  [200183]={ cn="天赋「神圣化身」", en="Talent: Apotheosis", t="talent" },
  [202090]={ cn="天赋「Teachings of the Monastery」", en="Talent: Teachings of the Monastery", t="talent" },
  [202147]={ cn="天赋「Second Wind」", en="Talent: Second Wind", t="talent" },
  [202602]={ cn="天赋「Into the Fray」", en="Talent: Into the Fray", t="talent" },
  [204066]={ cn="天赋「明月普照」", en="Talent: Lunar Beam", t="talent" },
  [204090]={ cn="天赋「Bullseye」", en="Talent: Bullseye", t="talent" },
  [205473]={ cn="天赋「Icicles」", en="Talent: Icicles", t="talent" },
  [207400]={ cn="天赋「Ancestral Vigor」", en="Talent: Ancestral Vigor", t="talent" },
  [207640]={ cn="天赋「Abundance」", en="Talent: Abundance", t="talent" },
  [211805]={ cn="天赋「Gathering Storm」", en="Talent: Gathering Storm", t="talent" },
  [215479]={ cn="天赋「Shuffle」", en="Talent: Shuffle", t="talent" },
  [215785]={ cn="天赋「Hot Hand」", en="Talent: Hot Hand", t="talent" },
  [219788]={ cn="天赋「Ossuary」", en="Talent: Ossuary", t="talent" },
  [246152]={ cn="天赋「Barbed Shot」", en="Talent: Barbed Shot", t="talent" },
  [257622]={ cn="天赋「Trick Shots」", en="Talent: Trick Shots", t="talent" },
  [259388]={ cn="天赋「Mongoose Fury」", en="Talent: Mongoose Fury", t="talent" },
  [260242]={ cn="天赋「Precise Shots」", en="Talent: Precise Shots", t="talent" },
  [260249]={ cn="天赋「Bloodseeker」", en="Talent: Bloodseeker", t="talent" },
  [260286]={ cn="天赋「Tip of the Spear」", en="Talent: Tip of the Spear", t="talent" },
  [260708]={ cn="天赋「横扫攻击」", en="Talent: Sweeping Strikes", t="talent" },
  [263725]={ cn="套装「夜歌战甲」", en="Set bonus: 夜歌战甲" },
  [264571]={ cn="天赋「Nightfall」", en="Talent: Nightfall", t="talent" },
  [268877]={ cn="天赋「Beast Cleave」", en="Talent: Beast Cleave", t="talent" },
  [274009]={ cn="天赋「Voracious」", en="Talent: Voracious", t="talent" },
  [279709]={ cn="天赋「Starlord」", en="Talent: Starlord", t="talent" },
  [316440]={ cn="天赋「武技神威」", en="Talent: Martial Prowess", t="talent" },
  [327510]={ cn="天赋「Shining Light」", en="Talent: Shining Light", t="talent" },
  [335082]={ cn="天赋「Frenzy」", en="Talent: Frenzy", t="talent" },
  [343648]={ cn="天赋「Solstice」", en="Talent: Solstice", t="talent" },
  [344179]={ cn="天赋「Maelstrom Weapon」", en="Talent: Maelstrom Weapon", t="talent" },
  [362877]={ cn="天赋「Temporal Compression」", en="Talent: Temporal Compression", t="talent" },
  [365362]={ cn="天赋「Arcane Surge」", en="Talent: Arcane Surge", t="talent" },
  [369299]={ cn="天赋「Essence Burst」", en="Talent: Essence Burst", t="talent" },
  [370901]={ cn="天赋「Leaping Flames」", en="Talent: Leaping Flames", t="talent" },
  [372470]={ cn="天赋「Scarlet Adaptation」", en="Talent: Scarlet Adaptation", t="talent" },
  [372505]={ cn="天赋「Ursoc's Fury」", en="Talent: Ursoc's Fury", t="talent" },
  [372617]={ cn="天赋「Empyreal Blaze」", en="Talent: Empyreal Blaze", t="talent" },
  [373213]={ cn="天赋「Insidious Ire」", en="Talent: Insidious Ire", t="talent" },
  [373267]={ cn="天赋「Lifebind」", en="Talent: Lifebind", t="talent" },
  [374585]={ cn="天赋「Rune Mastery」", en="Talent: Rune Mastery", t="talent" },
  [375583]={ cn="天赋「Ancient Flame」", en="Talent: Ancient Flame", t="talent" },
  [375802]={ cn="天赋「Burnout」", en="Talent: Burnout", t="talent" },
  [376850]={ cn="天赋「Power Swell」", en="Talent: Power Swell", t="talent" },
  [377066]={ cn="天赋「Mental Fortitude」", en="Talent: Mental Fortitude", t="talent" },
  [377102]={ cn="天赋「Exhilarating Burst」", en="Talent: Exhilarating Burst", t="talent" },
  [378770]={ cn="天赋「Deathblow」", en="Talent: Deathblow", t="talent" },
  [378989]={ cn="天赋「Lycara's Teachings」", en="Talent: Lycara's Teachings", t="talent" },
  [378990]={ cn="天赋「Lycara's Teachings」", en="Talent: Lycara's Teachings", t="talent" },
  [378991]={ cn="天赋「Lycara's Teachings」", en="Talent: Lycara's Teachings", t="talent" },
  [378992]={ cn="天赋「Lycara's Teachings」", en="Talent: Lycara's Teachings", t="talent" },
  [379017]={ cn="天赋「Faith's Armor」", en="Talent: Faith's Armor", t="talent" },
  [382024]={ cn="天赋「Earthliving Weapon」", en="Talent: Earthliving Weapon", t="talent" },
  [382889]={ cn="天赋「Flurry」", en="Talent: Flurry", t="talent" },
  [383395]={ cn="天赋「Feel the Burn」", en="Talent: Feel the Burn", t="talent" },
  [383733]={ cn="天赋「Training of Niuzao」", en="Talent: Training of Niuzao", t="talent" },
  [383800]={ cn="天赋「Counterstrike」", en="Talent: Counterstrike", t="talent" },
  [383811]={ cn="天赋「Fevered Incantation」", en="Talent: Fevered Incantation", t="talent" },
  [386029]={ cn="天赋「Brace For Impact」", en="Talent: Brace For Impact", t="talent" },
  [386164]={ cn="天赋「战斗姿态」", en="Talent: Battle Stance", t="talent" },
  [386196]={ cn="天赋「狂暴姿态」", en="Talent: Berserker Stance", t="talent" },
  [387109]={ cn="天赋「Conflagration of Chaos」", en="Talent: Conflagration of Chaos", t="talent" },
  [388497]={ cn="天赋「Secret Infusion」", en="Talent: Secret Infusion", t="talent" },
  [389020]={ cn="天赋「Bulletstorm」", en="Talent: Bulletstorm", t="talent" },
  [390192]={ cn="天赋「Ragefire」", en="Talent: Ragefire", t="talent" },
  [390260]={ cn="天赋「Commander of the Dead」", en="Talent: Commander of the Dead", t="talent" },
  [390692]={ cn="天赋「Borrowed Time」", en="Talent: Borrowed Time", t="talent" },
  [390787]={ cn="天赋「Weal and Woe」", en="Talent: Weal and Woe", t="talent" },
  [390978]={ cn="天赋「Twist of Fate」", en="Talent: Twist of Fate", t="talent" },
  [391092]={ cn="天赋「Shattered Psyche」", en="Talent: Shattered Psyche", t="talent" },
  [391215]={ cn="天赋「Initiative」", en="Talent: Initiative", t="talent" },
  [391459]={ cn="天赋「Sanguine Ground」", en="Talent: Sanguine Ground", t="talent" },
  [391481]={ cn="天赋「Coagulopathy」", en="Talent: Coagulopathy", t="talent" },
  [391876]={ cn="天赋「Frantic Momentum」", en="Talent: Frantic Momentum", t="talent" },
  [392268]={ cn="天赋「Essence Burst」", en="Talent: Essence Burst", t="talent" },
  [392778]={ cn="天赋「Wild Strikes」", en="Talent: Wild Strikes", t="talent" },
  [392883]={ cn="天赋「Vivacious Vivification」", en="Talent: Vivacious Vivification", t="talent" },
  [393009]={ cn="天赋「Fel Flame Fortification」", en="Talent: Fel Flame Fortification", t="talent" },
  [393038]={ cn="天赋「Strength in Adversity」", en="Talent: Strength in Adversity", t="talent" },
  [393515]={ cn="天赋「Pretense of Instability」", en="Talent: Pretense of Instability", t="talent" },
  [393919]={ cn="天赋「Screams of the Void」", en="Talent: Screams of the Void", t="talent" },
  [394049]={ cn="天赋「Balance of All Things」", en="Talent: Balance of All Things", t="talent" },
  [394080]={ cn="天赋「Scent of Blood」", en="Talent: Scent of Blood", t="talent" },
  [394087]={ cn="天赋「Mayhem」", en="Talent: Mayhem", t="talent" },
  [394195]={ cn="天赋「Overflowing Energy」", en="Talent: Overflowing Energy", t="talent" },
  [395152]={ cn="天赋「黑檀之力」", en="Talent: Ebon Might", t="talent" },
  [395296]={ cn="天赋「Ebon Might」", en="Talent: Ebon Might", t="talent" },
  [399497]={ cn="天赋「Sheilun's Gift」", en="Talent: Sheilun's Gift", t="talent" },
  [399510]={ cn="天赋「Sheilun's Gift」", en="Talent: Sheilun's Gift", t="talent" },
  [400126]={ cn="天赋「Forestwalk」", en="Talent: Forestwalk", t="talent" },
  [405963]={ cn="天赋「Divine Image」", en="Talent: Divine Image", t="talent" },
  [407065]={ cn="天赋「Rush of Light」", en="Talent: Rush of Light", t="talent" },
  [408005]={ cn="天赋「Momentum Shift」", en="Talent: Momentum Shift", t="talent" },
  [410089]={ cn="天赋「Prescience」", en="Talent: Prescience", t="talent" },
  [410263]={ cn="天赋「Inferno's Blessing」", en="Talent: Inferno's Blessing", t="talent" },
  [410681]={ cn="天赋「Overflowing Maelstrom」", en="Talent: Overflowing Maelstrom", t="talent" },
  [411055]={ cn="天赋「Imminent Destruction」", en="Talent: Imminent Destruction", t="talent" },
  [414143]={ cn="天赋「Yu'lon's Grace」", en="Talent: Yu'lon's Grace", t="talent" },
  [417282]={ cn="天赋「Crashing Chaos」", en="Talent: Crashing Chaos", t="talent" },
  [429438]={ cn="天赋「Blooming Infusion」", en="Talent: Blooming Infusion", t="talent" },
  [431415]={ cn="天赋「Sun Sear」", en="Talent: Sun Sear", t="talent" },
  [431536]={ cn="天赋「Shake the Heavens」", en="Talent: Shake the Heavens", t="talent" },
  [431654]={ cn="天赋「Primacy」", en="Talent: Primacy", t="talent" },
  [431698]={ cn="天赋「Temporal Burst」", en="Talent: Temporal Burst", t="talent" },
  [432629]={ cn="天赋「Undisputed Ruling」", en="Talent: Undisputed Ruling", t="talent" },
  [433671]={ cn="天赋「Sanctification」", en="Talent: Sanctification", t="talent" },
  [433674]={ cn="天赋「Light's Deliverance」", en="Talent: Light's Deliverance", t="talent" },
  [438591]={ cn="天赋「Keep Your Feet on the Ground」", en="Talent: Keep Your Feet on the Ground", t="talent" },
  [440289]={ cn="天赋「Rune Carved Plates」", en="Talent: Rune Carved Plates", t="talent" },
  [440290]={ cn="天赋「Rune Carved Plates」", en="Talent: Rune Carved Plates", t="talent" },
  [440989]={ cn="天赋「Colossal Might」", en="Talent: Colossal Might", t="talent" },
  [441248]={ cn="天赋「Unrelenting Siege」", en="Talent: Unrelenting Siege", t="talent" },
  [441326]={ cn="天赋「Flawless Form」", en="Talent: Flawless Form", t="talent" },
  [443112]={ cn="天赋「Strength of the Black Ox」", en="Talent: Strength of the Black Ox", t="talent" },
  [443421]={ cn="天赋「Heart of the Jade Serpent」", en="Talent: Heart of the Jade Serpent", t="talent" },
  [443569]={ cn="天赋「Chi-Ji's Swiftness」", en="Talent: Chi-Ji's Swiftness", t="talent" },
  [445584]={ cn="装备「套装：处决者的锋刃战甲」", en="Item: 套装：处决者的锋刃战甲" },
  [445606]={ cn="天赋「Imminent Demise」", en="Talent: Imminent Demise", t="talent" },
  [447988]={ cn="天赋「Light of the Martyr」", en="Talent: Light of the Martyr", t="talent" },
  [448087]={ cn="天赋「Bestow Light」", en="Talent: Bestow Light", t="talent" },
  [449314]={ cn="天赋「Mana Cascade」", en="Talent: Mana Cascade", t="talent" },
  [449887]={ cn="天赋「Voidheart」", en="Talent: Voidheart", t="talent" },
  [450521]={ cn="天赋「Aspect of Harmony」", en="Talent: Aspect of Harmony", t="talent" },
  [451230]={ cn="天赋「Predictive Training」", en="Talent: Predictive Training", t="talent" },
  [451298]={ cn="天赋「Momentum Boost」", en="Talent: Momentum Boost", t="talent" },
  [451447]={ cn="天赋「Don't Look Back」", en="Talent: Don't Look Back", t="talent" },
  [451508]={ cn="天赋「Balanced Stratagem」", en="Talent: Balanced Stratagem", t="talent" },
  [452416]={ cn="天赋「Demonsurge」", en="Talent: Demonsurge", t="talent" },
  [453314]={ cn="天赋「Enduring Torment」", en="Talent: Enduring Torment", t="talent" },
  [453846]={ cn="天赋「Resonant Energy」", en="Talent: Resonant Energy", t="talent" },
  [454025]={ cn="天赋「Electroshock」", en="Talent: Electroshock", t="talent" },
  [454394]={ cn="天赋「Unlimited Power」", en="Talent: Unlimited Power", t="talent" },
  [455122]={ cn="天赋「Permafrost Lances」", en="Talent: Permafrost Lances", t="talent" },
  [456369]={ cn="天赋「Amplification Core」", en="Talent: Amplification Core", t="talent" },
  [456370]={ cn="天赋「Cryogenic Chamber」", en="Talent: Cryogenic Chamber", t="talent" },
  [460499]={ cn="天赋「Bloodied Blade」", en="Talent: Bloodied Blade", t="talent" },
  [460822]={ cn="天赋「Divine Guidance」", en="Talent: Divine Guidance", t="talent" },
  [461130]={ cn="天赋「Visceral Strength」", en="Talent: Visceral Strength", t="talent" },
  [461242]={ cn="天赋「Lively Totems」", en="Talent: Lively Totems", t="talent" },
  [461531]={ cn="天赋「Brainstorm」", en="Talent: Brainstorm", t="talent" },
  [462568]={ cn="天赋「Elemental Resistance」", en="Talent: Elemental Resistance", t="talent" },
  [470077]={ cn="天赋「Coalescing Water」", en="Talent: Coalescing Water", t="talent" },
  [471877]={ cn="天赋「Howl of the Pack Leader」", en="Talent: Howl of the Pack Leader", t="talent" },
  [1214909]={ cn="天赋「命运骨骰」", en="Talent: Roll the Bones", t="talent" },
  [1217607]={ cn="天赋「Void Metamorphosis」", en="Talent: Void Metamorphosis", t="talent" },
  [1227702]={ cn="天赋「Collapsing Star」", en="Talent: Collapsing Star", t="talent" },
  [1229746]={ cn="工艺装备特效「Arcanoweave Lining」(可选材料,镶在装备上)", en="Crafted embellishment: Arcanoweave Lining" },
  [1230916]={ cn="天赋「Killing Streak」", en="Talent: Killing Streak", t="talent" },
  [1232310]={ cn="天赋「Feast of Souls」", en="Talent: Feast of Souls", t="talent" },
  [1235193]={ cn="天赋「Holy Ray」", en="Talent: Holy Ray", t="talent" },
  [1241059]={ cn="天赋「天神灌注」", en="Talent: Celestial Infusion", t="talent" },
  [1241077]={ cn="天赋「Festering Scythe」", en="Talent: Festering Scythe", t="talent" },
  [1241410]={ cn="天赋「Hammer of Wrath」", en="Talent: Hammer of Wrath", t="talent" },
  [1241569]={ cn="天赋「Clawing Shadows」", en="Talent: Clawing Shadows", t="talent" },
  [1241715]={ cn="武器附魔「Acuity of the Ren'dorei」", en="Weapon enchant: Acuity of the Ren'dorei" },
  [1241761]={ cn="装备「附魔武器 - 加亚莱的精准」", en="Item: 附魔武器 - 加亚莱的精准" },
  [1242504]={ cn="天赋「Emptiness」", en="Talent: Emptiness", t="talent" },
  [1242974]={ cn="天赋「Arcane Salvo」", en="Talent: Arcane Salvo", t="talent" },
  [1244893]={ cn="天赋「Beacon of the Savior」", en="Talent: Beacon of the Savior", t="talent" },
  [1245369]={ cn="天赋「Beacon of the Savior」", en="Talent: Beacon of the Savior", t="talent" },
  [1248705]={ cn="天赋「Skyfire Heel」", en="Talent: Skyfire Heel", t="talent" },
  [1251877]={ cn="天赋「Gift of an Ancient Guardian」", en="Talent: Gift of an Ancient Guardian", t="talent" },
  [1252217]={ cn="天赋「Shadow Mend」", en="Talent: Shadow Mend", t="talent" },
  [1252415]={ cn="天赋「Crash Lightning」", en="Talent: Crash Lightning", t="talent" },
  [1253600]={ cn="守护德 S1 套装效果(赤红之月体系,泄怒气触发)", en="Guardian S1 tier set bonus (Red Moon system)" },
  [1256301]={ cn="天赋「Voidfall」", en="Talent: Voidfall", t="talent" },
  [1256322]={ cn="天赋「Voidfall」", en="Talent: Voidfall", t="talent" },
  [1256579]={ cn="天赋「Merithra's Blessing」", en="Talent: Merithra's Blessing", t="talent" },
  [1257350]={ cn="天赋「Fired Up」", en="Talent: Fired Up", t="talent" },
  [1259171]={ cn="天赋「Duplicate」", en="Talent: Duplicate", t="talent" },
  [1259486]={ cn="天赋「Zero In」", en="Talent: Zero In", t="talent" },
  [1260279]={ cn="天赋「Nightfall」", en="Talent: Nightfall", t="talent" },
  [1260459]={ cn="装备「Vaelgor's Final Stare」", en="Item: Vaelgor's Final Stare" },
  [1260565]={ cn="天赋「Spiritfont」", en="Talent: Spiritfont", t="talent" },
  [1260670]={ cn="天赋「Spiritfont」", en="Talent: Spiritfont", t="talent" },
  [1262766]={ cn="天赋「Benediction」", en="Talent: Benediction", t="talent" },
  [1263263]={ cn="天赋「Hand of Frost」", en="Talent: Hand of Frost", t="talent" },
  [1264050]={ cn="天赋「Born in Sunlight」", en="Talent: Born in Sunlight", t="talent" },
  [1264521]={ cn="天赋「Find Weakness」", en="Talent: Find Weakness", t="talent" },
  [1265389]={ cn="天赋「Implacable」", en="Talent: Implacable", t="talent" },
  [1265399]={ cn="天赋「Scent of Blood」", en="Talent: Scent of Blood", t="talent" },
  [1265406]={ cn="天赋「Bloodborne」", en="Talent: Bloodborne", t="talent" },
  [1265575]={ cn="天赋「Executioner's Wrath」", en="Talent: Executioner's Wrath", t="talent" },
  [1265871]={ cn="天赋「Azure Sweep」", en="Talent: Azure Sweep", t="talent" },
  [1266686]={ cn="装备「Gaze of the Alnseer」", en="Item: Gaze of the Alnseer" },
  [1266687]={ cn="装备「Gaze of the Alnseer」(饰品 Alnsight 的二段触发)", en="Item: Gaze of the Alnseer (second stage of Alnsight)" },
  [1268917]={ cn="天赋「Unholy Aura」", en="Talent: Unholy Aura", t="talent" },
  [1269349]={ cn="天赋「Berserk」", en="Talent: Berserk", t="talent" },
  [1269394]={ cn="天赋「Master of Warfare」", en="Talent: Master of Warfare", t="talent" },
  [1269879]={ cn="天赋「Mind's Eyes」", en="Talent: Mind's Eyes", t="talent" },
  [1270840]={ cn="天赋「Cut to the Bone」", en="Talent: Cut to the Bone", t="talent" },
  [1270990]={ cn="天赋「Potential Energy」", en="Talent: Potential Energy", t="talent" },
  [1276720]={ cn="天赋「Nature's Ally」", en="Talent: Nature's Ally", t="talent" },
  [1278009]={ cn="天赋「Phalanx」", en="Talent: Phalanx", t="talent" },
  [1279347]={ cn="天赋「Quick Draw」", en="Talent: Quick Draw", t="talent" },
}
