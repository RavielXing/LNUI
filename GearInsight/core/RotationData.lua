-- 自动生成(generate_rotation_lua.py ← build_rotation_teaching.py)，勿手改。
-- WCL 顶尖玩家循环参考：raid=团本M1 top5；mplus=冲分各本top2聚合。
-- core={ {spellID,每分钟次数}.. } watch={ {spellID,uptime%}.. } opener=前3名真实起手。
GearInsightRotation = {
  ["DEATHKNIGHT/BLOOD"] = {
    specID=250,
    raid={
      n=5, dur=415, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Trigdk", server="Frostmourne", region="US", seq={195292,48265,49028,46585,1297761,433895,434144,433895,434144,433895,434144,43265} },
        { player="Lambertdk", server="Zul'jin", region="US", seq={195292,43265,1297761,46585,49028,433895,434144,433895,434144,433895,434144,49998} },
        { player="Ravendár", server="Argent Dawn", region="EU", seq={195292,46585,43265,50842,195182,195182,49998,50842,206930,206930,49998,50842} },
      },
      core={ {49998,18.1},{206930,15.3},{433895,10.6},{50842,8.3},{43265,4.4},{195292,2.0},{195182,1.6},{55233,1.3},{48265,1.0},{48707,1.0},{1297761,0.7},{49028,0.7},{46585,0.5} }, -- Death Strike, Heart Strike, Vampiric Strike, Blood Boil, Death and Decay, Death's Caress, Marrowrend, Vampiric Blood, Death's Advance, Anti-Magic Shell, Voracious Heart of Ula'tek, Dancing Rune Weapon, Raise Dead
      watch={ {274009,96.9},{1310372,93.8},{463730,89.0},{1287772,83.6},{180612,75.6},{460499,75.2},{434034,71.2},{77535,67.7},{391459,65.0},{188290,65.0} }, -- Voracious, Blood Debt, Coagulating Blood, Rune of Critical Power, Recently Used Death Strike, Bloodied Blade, Blood-Soaked Ground, Blood Shield, Sanguine Ground, Death and Decay
      coach={ cn="怎么打：心脏打击攒符能，灵界打击按得极勤（顶尖19.8次/分）——但别空按，尽量接在吃了伤害之后，回血护盾才不浪费。血液沸腾保持疾病，枯萎凋零踩在脚下（顶尖覆盖73%）。骨盾低了用精髓分裂或死神的抚摩远程补。盯什么：血之护盾（顶尖覆盖95.5%）——盾掉了又要承伤时优先打一个灵界打击；脚下的枯萎凋零圈别走丢。", en="How to play: Heart Strike builds runic power; Death Strike gets pressed constantly (top players: 19.8/min) — but don't waste it, time it right after taking damage so the heal and shield count. Blood Boil keeps diseases up; stand in your Death and Decay (73% top uptime). Refresh bone shield with Marrowrend or Death's Caress at range. Watch: Blood Shield (95.5% top uptime) — if it drops with damage incoming, prioritize a Death Strike; don't drift out of your Death and Decay." },
    },
    mplus={
      n=8, dur=1763,
      core={ {49998,16.5},{206930,13.5},{433895,8.9},{50842,7.4},{43265,3.3},{195182,2.2},{55233,1.4},{195292,1.1},{49576,1.0},{48707,0.9},{48265,0.7},{49028,0.6},{46585,0.4} }, -- Death Strike, Heart Strike, Vampiric Strike, Blood Boil, Death and Decay, Marrowrend, Vampiric Blood, Death's Caress, Death Grip, Anti-Magic Shell, Death's Advance, Dancing Rune Weapon, Raise Dead
      watch={ {465,97.2},{433925,95.5},{219788,95.1},{391481,94.9},{1310372,94.0},{194879,92.0},{274009,90.3},{463730,74.3},{391459,66.6},{188290,66.6} }, -- Devotion Aura, Essence of the Blood Queen, Ossuary, Coagulopathy, Blood Debt, Icy Talons, Voracious, Coagulating Blood, Sanguine Ground, Death and Decay
      coach={ cn="怎么打：大秘境骨盾掉得飞快，精髓分裂要按得比团本勤得多——看到骨盾低于5层就补。拉怪先铺枯萎凋零再血液沸腾上疾病，灵界打击照旧留给大额承伤后。盯什么：骨盾层数是第一优先（顶尖玩家 骨盾增益 覆盖96%，意味着骨盾几乎从不掉光）；其次盯血之护盾，AOE 承伤期保持它在身上。", en="How to play: Bone Shield drains fast in Mythic+ — press Marrowrend far more than in raid, refreshing below 5 stacks. Open pulls with Death and Decay then Blood Boil for diseases; save Death Strike for after big damage. Watch: Bone Shield stacks first (top players keep Ossuary at 96%, meaning it never fully drops), then Blood Shield during AoE damage." },
    },
  },
  ["DEATHKNIGHT/FROST"] = {
    specID=251,
    raid={
      n=5, dur=410, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Baldmon", server="Kazzak", region="EU", seq={49184,47568,51271,439843,46585,1249658,279302,48265,49020,441424,49020,441426} },
        { player="Choiyena", server="Ravencrest", region="EU", seq={49576,47568,1297761,51271,439843,46585,1249658,49020,47568,441424,441426,49020} },
        { player="Skillydk", server="Area 52", region="US", seq={49184,47568,439843,1297761,1249658,51271,46585,279302,49020,47568,441424,49020} },
      },
      core={ {49020,14.8},{49143,13.8},{49184,8.9},{47568,4.2},{441424,3.5},{207230,3.4},{51271,1.2},{439843,1.2},{48265,1.1},{48707,1.0},{46585,0.7},{1297761,0.7},{279302,0.6},{1265384,0.6} }, -- Obliterate, Frost Strike, Howling Blast, Empower Rune Weapon, Exterminate, Frostscythe, Pillar of Frost, Reaper's Mark, Death's Advance, Anti-Magic Shell, Raise Dead, Voracious Heart of Ula'tek, Frostwyrm's Fury, Frostwyrm's Fury
      watch={ {194879,96.0},{1230916,91.7},{440289,90.8},{440290,88.7},{1287771,83.9},{456370,82.2},{1297365,67.9},{53365,67.1},{51124,56.7},{207203,56.2} }, -- Icy Talons, Killing Streak, Rune Carved Plates, Rune Carved Plates, Rune of Masterful Cunning, Cryogenic Chamber, Freezing Tempest, Unholy Strength, Killing Machine, Frost Shield
      coach={ cn="怎么打：湮灭是绝对主轴（顶尖23.8次/分），符能用冰霜打击泄掉防溢出，凛风冲击补缝。冰霜之柱和死神印记按 CD 对齐打爆发窗口（各1.4次/分=几乎每个 CD 都没浪费）。盯什么：符文和符能都别溢出——湮灭和冰霜打击的比例接近3:2，手不能停；爆发窗口内把资源全倾泻进去。", en="How to play: Obliterate is the absolute core (top players: 23.8/min); dump runic power with Frost Strike to avoid capping, fill gaps with Howling Blast. Line up Pillar of Frost and Reaper's Mark on cooldown for burst windows (1.4/min each = barely a wasted cooldown). Watch: never cap runes or runic power — the Obliterate-to-Frost-Strike ratio is roughly 3:2, so hands never stop; pour everything into your burst windows." },
    },
    mplus={
      n=8, dur=1751,
      core={ {49184,9.1},{49020,8.7},{207230,7.8},{49143,6.8},{194913,6.7},{47568,4.3},{441424,3.3},{439843,1.1},{51271,1.1},{48265,0.8},{48707,0.7},{46585,0.6},{1265384,0.5},{49576,0.5} }, -- Howling Blast, Obliterate, Frostscythe, Frost Strike, Glacial Advance, Empower Rune Weapon, Exterminate, Reaper's Mark, Pillar of Frost, Death's Advance, Anti-Magic Shell, Raise Dead, Frostwyrm's Fury, Death Grip
      watch={ {194879,91.5},{1230916,87.2},{440289,86.8},{456370,86.1},{440290,83.8},{1287771,78.3},{462568,73.0},{207400,72.9},{207203,72.7},{382024,65.7} }, -- Icy Talons, Killing Streak, Rune Carved Plates, Cryogenic Chamber, Rune Carved Plates, Rune of Masterful Cunning, Elemental Resistance, Ancestral Vigor, Frost Shield, Earthliving Weapon
      coach={ cn="怎么打：打群怪把湮灭换成冰霜之镰，凛风冲击照常吃触发，冰川突进对准一条线的怪放。单体目标（精英/boss）切回湮灭主键。盯什么：冰爪 攻速层（92.5%覆盖）——它靠持续输出维持，赶路或换怪群时断了会明显掉伤害，接战后第一时间把层数叠回来。", en="How to play: Swap Obliterate for Frostscythe on packs, keep Howling Blast for procs, and aim Glacial Advance down a line of enemies. Switch back to Obliterate on single elites and bosses. Watch: Icy Talons (92.5% uptime) — it's sustained by continuous attacks, drops during transitions, so rebuild stacks immediately on engagement." },
    },
  },
  ["DEATHKNIGHT/UNHOLY"] = {
    specID=252,
    raid={
      n=5, dur=413, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Shenroh", server="Zul'jin", region="US", seq={77575,85948,458128,1233448,1297761,42650,1247378,1247378,1242174,1242174,1242174,343294} },
        { player="Endzdekay", server="Sanguino", region="EU", seq={444347,77575,85948,458128,42650,1297761,1233448,1247378,343294,1242174,1242174,55090} },
        { player="郝睡觉了", server="罗宁", region="CN", seq={77575,85948,458128,42650,1297761,1247378,1233448,1242174,55090,55090,1242174,55090} },
      },
      core={ {55090,17.4},{47541,9.7},{1242174,7.4},{458128,3.0},{85948,3.0},{1247378,2.4},{343294,2.3},{1233448,1.3},{48707,1.0},{444347,0.9},{1297761,0.7},{77575,0.7},{42650,0.7} }, -- Scourge Strike, Death Coil, Necrotic Coil, Festering Scythe, Festering Strike, Putrefy, Soul Reaper, Dark Transformation, Anti-Magic Shell, Death Charge, Voracious Heart of Ula'tek, Outbreak, Army of the Dead
      watch={ {194879,96.7},{1241569,96.5},{1254252,94.9},{1241077,93.3},{1287771,86.4},{453773,84.7},{1229746,64.4},{390260,59.1},{81340,55.7},{51460,52.7} }, -- Icy Talons, Clawing Shadows, Lesser Ghoul, Festering Scythe, Rune of Masterful Cunning, Pact of the Apocalypse, Arcanoweave Insight, Commander of the Dead, Sudden Doom, Runic Corruption
      coach={ cn="怎么打：天灾打击按得远比其他键勤（顶尖23.5次/分），脓疮打击只为补脓疮（3.2次/分就够），凋零缠绕泄符能。黑暗突变按 CD（1.4次/分），灵魂收割留给斩杀段。盯什么：脓疮数量别清空也别溢出——天灾打击要有疮可爆；黑暗突变的石像鬼窗口内资源全倾泻。", en="How to play: Scourge Strike dwarfs every other button (top players: 23.5/min); Festering Strike exists only to apply wounds (3.2/min is enough), Death Coil dumps runic power. Dark Transformation on cooldown (1.4/min); save Soul Reaper for execute. Watch: wound count — never empty, never capped, Scourge Strike needs wounds to burst; dump all resources inside Dark Transformation windows." },
    },
    mplus={
      n=8, dur=1773,
      core={ {433895,13.0},{47541,6.3},{55090,6.0},{207317,4.8},{1242174,3.4},{1247378,3.1},{383269,2.9},{85948,2.7},{458128,2.7},{43265,1.4},{1233448,1.2},{48707,0.8},{48265,0.7},{1259633,0.6} }, -- Vampiric Strike, Death Coil, Scourge Strike, Epidemic, Necrotic Coil, Putrefy, Graveyard, Festering Strike, Festering Scythe, Death and Decay, Dark Transformation, Anti-Magic Shell, Death's Advance, Charge!
      watch={ {1242866,94.3},{1254252,94.2},{1241569,90.8},{433925,89.9},{194879,89.5},{1268917,89.3},{1242998,89.0},{1256576,86.7},{1241077,86.6},{434159,66.8} }, -- Raise Dead, Lesser Ghoul, Clawing Shadows, Essence of the Blood Queen, Icy Talons, Unholy Aura, Lesser Ghoul, Forbidden Sacrifice, Festering Scythe, Visceral Strength
      coach={ cn="怎么打：群怪用扩散代替凋零缠绕泄符能，灾殃坟茔丢进怪堆，天灾打击照常主键。进新怪群前留好符文，先脓疮打击铺脓疮再开打。盯什么：冰爪 攻速层（90%）别断；脓疮管理在 AOE 里更容易崩——多目标时盯紧主要目标的脓疮层数，别打空。", en="How to play: On packs, spend runic power on Epidemic instead of Death Coil, drop Graveyard into the pile, and keep Scourge Strike as your main button. Bank runes before each new pack so you can apply wounds with Festering Strike first. Watch: keep Icy Talons (90%) rolling; wound management collapses easily in AoE — track your primary target's wounds and never strike without them." },
    },
  },
  ["DEMONHUNTER/DEVAURER"] = {
    specID=1480,
    raid={
      n=5, dur=417, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Fiveblind", server="Twisting Nether", region="EU", seq={1223412,473662,1223412,1223412,1223412,473662,1226019,1223412,1223412,1223412,1226019,473662} },
        { player="Nathanail", server="Eredar", region="EU", seq={473662,1223412,1223412,1223412,473662,1223412,1223412,1223412,473662,1226019,1223412,1223412} },
        { player="Nepadh", server="Blackhand", region="EU", seq={1223412,1223412,473662,1223412,1223412,1223412,1223412,473662,1223412,1223412,1223412,473662} },
      },
      core={ {1217610,8.3},{473662,6.8},{1245453,6.0},{473728,5.8},{1226019,5.5},{198793,4.3},{1245470,3.4},{1245414,2.3},{1241937,2.2},{1245483,1.3},{1259431,1.2},{1245412,1.1},{1246167,0.7},{1250533,0.6} }, -- Devour, Consume, Cull, Void Ray, Reap, Vengeful Retreat, Reaper's Toll, Voidblade, Soul Immolation, Pierce the Veil, Predator's Wake, Voidblade, The Hunt, Freightrunner's Flask
      watch={ {372014,94.6},{1295057,91.6},{1245577,89.3},{1287772,86.9},{139,70.3},{1229746,61.5},{1297663,59.9},{1241759,57.9},{465,55.6},{453314,55.1} }, -- Visage, Tidal Insight, Soul Fragments, Rune of Critical Power, Renew, Arcanoweave Insight, Halazzi's Rite, Genius Insight, Devotion Aura, Enduring Torment
      coach={ cn="怎么打：Devour 是主填充（顶尖22次/分），吞噬回收灵魂碎片，虚空射线7.3次/分穿插。Collapsing Star 按 CD（3.8次/分），灵魂献祭是大 CD 对齐爆发。盯什么：灵魂碎片（顶尖覆盖97.3%=场上几乎永远有碎片可吃）——吞噬别让碎片烂在地上；Collapsing Star 窗口覆盖64%，窗口内输出全压进去。", en="How to play: Devour is your main filler (top players: 22/min), Consume harvests soul fragments, Void Ray weaves in at 7.3/min. Collapsing Star on cooldown (3.8/min); Soul Immolation is the big cooldown to align bursts with. Watch: soul fragments (97.3% top uptime = fragments are almost always available) — Consume them, don't let them rot; Collapsing Star windows cover 64% of the fight, stack your damage inside them." },
    },
    mplus={
      n=8, dur=1754,
      core={ {1217610,16.7},{473728,6.4},{473662,6.3},{1221150,3.4},{1241937,1.6},{131347,0.8},{198589,0.7},{1245453,0.7},{1250533,0.6},{1226019,0.5} }, -- Devour, Void Ray, Consume, Collapsing Star, Soul Immolation, Glide, Blur, Cull, Freightrunner's Flask, Reap
      watch={ {1232310,92.1},{1245577,89.2},{1287771,79.3},{1229746,67.8},{1256301,58.0},{1217607,56.3},{1297663,56.1},{1227702,55.9},{1242504,55.0},{1227338,49.5} }, -- Feast of Souls, Soul Fragments, Rune of Masterful Cunning, Arcanoweave Insight, Voidfall, Void Metamorphosis, Halazzi's Rite, Collapsing Star, Emptiness, Impending Apocalypse
      coach={ cn="怎么打：和团本同一套手法，吞蚀 主键、吞噬虚空射线穿插，坍缩之星 对准怪群中心放（大秘境里它更值钱）。疾影别只当保命技，按节奏用能平滑承伤。盯什么：灵魂盛宴 覆盖95.5%——灵魂碎片的回收别断，碎片在地上没吃等于白产。", en="How to play: Same hands as raid — Devour as the main button, Consume and Void Ray woven in, Collapsing Star aimed at pack centers (it's worth more here). Use Blur rhythmically, not just in emergencies. Watch: Feast of Souls sits at 95.5% — never break the soul fragment pickup loop; fragments left on the ground are wasted production." },
    },
  },
  ["DEMONHUNTER/HAVOC"] = {
    specID=577,
    raid={
      n=5, dur=407, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Ptheve", server="Onyxia", region="US", seq={383781,213243,232893,198013,370965,370966,258860,210152,210152,201427,198793,228537} },
        { player="Dauflo", server="Dalaran", region="EU", seq={427917,383781,198013,370965,370966,258860,210152,210152,201427,198793,228537,200166} },
        { player="Shadarek", server="Bleeding Hollow", region="US", seq={1297908,213243,232893,198013,370965,370966,258860,210152,210152,201427,198793,228537} },
      },
      core={ {201427,13.4},{162794,8.5},{210152,7.5},{198793,2.2},{198013,2.2},{232893,2.0},{258860,1.8},{188499,1.8},{258920,1.6},{195072,1.1},{370965,1.0},{452497,0.9},{185123,0.9},{198589,0.7} }, -- Annihilation, Chaos Strike, Death Sweep, Vengeful Retreat, Eye Beam, Felblade, Essence Break, Blade Dance, Immolation Aura, Fel Rush, The Hunt, Abyssal Gaze, Throw Glaive, Blur
      watch={ {390155,97.5},{465,96.5},{208628,94.9},{1287772,87.8},{139,85.4},{372014,79.7},{1229746,73.4},{1297663,62.0},{162264,60.5},{452416,51.4} }, -- Serrated Glaive, Devotion Aura, Exergy, Rune of Critical Power, Renew, Visage, Arcanoweave Insight, Halazzi's Rite, Metamorphosis, Demonsurge
      coach={ cn="怎么打：怒气喂混乱打击，变形期间它变成灭杀、刃舞变成死亡横扫——顶尖玩家一半时间在变形里（覆盖49.6%），所以灭杀次数反超混乱打击。眼棱和刃舞按 CD，邪能之刃补怒气，复仇回避当输出技主动按（2.4次/分）。盯什么：变形剩余时间——窗口内优先把眼棱、死亡横扫全打进去；怒气别溢出。", en="How to play: Fury feeds Chaos Strike; inside Metamorphosis it becomes Annihilation and Blade Dance becomes Death Sweep — top players spend half the fight transformed (49.6% uptime), which is why Annihilation counts exceed Chaos Strike. Eye Beam and Blade Dance on cooldown, Felblade refills fury, and Vengeful Retreat is pressed offensively (2.4/min). Watch: Metamorphosis time remaining — pack Eye Beam and Death Sweep inside the window; never cap fury." },
    },
    mplus={
      n=8, dur=1709,
      core={ {162794,8.9},{201427,8.7},{210152,6.0},{232893,2.8},{185123,2.3},{188499,2.0},{198793,2.0},{198013,1.8},{258920,1.7},{258860,1.5},{131347,0.9},{195072,0.9},{370965,0.8},{452497,0.7} }, -- Chaos Strike, Annihilation, Death Sweep, Felblade, Throw Glaive, Blade Dance, Vengeful Retreat, Eye Beam, Immolation Aura, Essence Break, Glide, Fel Rush, The Hunt, Abyssal Gaze
      watch={ {208628,86.6},{1287772,80.3},{453314,56.6},{1297663,55.0},{162264,43.5},{1229746,43.0},{452416,39.3},{258920,36.6},{390192,36.3},{389890,33.8} }, -- Exergy, Rune of Critical Power, Enduring Torment, Halazzi's Rite, Metamorphosis, Arcanoweave Insight, Demonsurge, Immolation Aura, Ragefire, Tactical Retreat
      coach={ cn="怎么打：主手法不变，多了高频投掷利刃——空档和远离怪的瞬间都用它补伤害。刃舞对准怪群放，眼棱扫一整排。复仇回避照常循环化使用，注意别把自己甩出怪群。盯什么：虚空浸染 覆盖96.9%是输出底线；刃舞放完看怪群存活，决定下一轮是续 AOE 还是转单体。", en="How to play: Same core hands, plus high-frequency Throw Glaive — fill every gap and ranged moment with it. Aim Blade Dance into packs and sweep full lines with Eye Beam. Keep cycling Vengeful Retreat, but don't launch yourself out of the pack. Watch: Void-Touched at 96.9% is your damage floor; after each Blade Dance, check pack health to decide between continuing AoE or swapping to single-target." },
    },
  },
  ["DEMONHUNTER/VENGEANCE"] = {
    specID=581,
    raid={
      n=5, dur=401, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Felvix", server="Sylvanas", region="EU", seq={346665,204157,203720,131347,213243,232893,258920,204255,225919,263642,225921,1236616} },
        { player="Slickezpz", server="Blackhand", region="EU", seq={204021,258920,1236616,390163,203720,225919,263642,225921,204255,204255,225919,263642} },
        { player="Bentwo", server="Zul'jin", region="US", seq={390163,204021,1236616,204255,204255,204255,225919,263642,225921,204255,225919,263642} },
      },
      core={ {263642,17.4},{228477,16.8},{203720,7.0},{258920,5.0},{247454,3.6},{187827,2.2},{204596,1.5},{204021,1.4},{232893,1.1},{212084,1.1},{390163,1.0},{204157,0.8},{198793,0.5} }, -- Fracture, Soul Cleave, Demon Spikes, Immolation Aura, Spirit Bomb, Metamorphosis, Sigil of Flame, Fiery Brand, Felblade, Fel Devastation, Sigil of Spite, Throw Glaive, Vengeful Retreat
      watch={ {212988,95.6},{1270547,92.1},{393009,74.3},{258920,72.4},{203981,68.0},{1241715,62.0},{1256301,52.0},{1229746,51.5},{187827,49.5},{372014,47.1} }, -- Painbringer, Seething Anger, Fel Flame Fortification, Immolation Aura, Soul Fragments, Might of the Void, Voidfall, Arcanoweave Insight, Metamorphosis, Visage
      coach={ cn="怎么打：破裂是产能主键（顶尖18.3次/分），攒碎片和怒气，灵魂裂劈和幽魂炸弹消耗。献祭光环按 CD 保持（覆盖74.6%），邪能之刃补缝。恶魔尖刺别屯着——顶尖覆盖87.6%，物理承伤期几乎常驻。盯什么：恶魔尖刺的层数和覆盖（87.6%是顶尖标准）；灵魂碎片数量，裂劈和幽魂炸弹要有碎片才值。", en="How to play: Fracture is your builder (top players: 18.3/min), generating fragments and fury; Soul Cleave and Spirit Bomb spend them. Keep Immolation Aura rolling on cooldown (74.6% uptime), Felblade fills gaps. Don't hoard Demon Spikes — top players hold 87.6% uptime, nearly permanent through physical damage. Watch: Demon Spikes charges and uptime (87.6% is the top-player bar); soul fragment count — Soul Cleave and Spirit Bomb only pay off with fragments banked." },
    },
    mplus={
      n=8, dur=1795,
      core={ {263642,16.2},{228477,16.0},{203720,6.5},{258920,4.7},{247454,3.2},{187827,2.1},{204596,1.7},{232893,1.7},{204021,1.2},{390163,0.9},{131347,0.9},{212084,0.8},{204157,0.5} }, -- Fracture, Soul Cleave, Demon Spikes, Immolation Aura, Spirit Bomb, Metamorphosis, Sigil of Flame, Felblade, Fiery Brand, Sigil of Spite, Glide, Fel Devastation, Throw Glaive
      watch={ {203819,96.2},{1270547,86.7},{1287774,85.0},{1265857,79.3},{393009,72.3},{203981,71.6},{258920,70.0},{1229746,53.6},{1256301,53.3},{187827,44.3} }, -- Demon Spikes, Seething Anger, Rune of Burning Haste, Revel in Pain, Fel Flame Fortification, Soul Fragments, Immolation Aura, Arcanoweave Insight, Voidfall, Metamorphosis
      coach={ cn="怎么打：破裂攒灵魂碎片、灵魂裂劈花掉——这对循环永远在转。幽魂炸弹在碎片≥4时放收益最高。恶魔尖刺别存着：看到物理怪抬手就按，顶尖玩家把它按到7次/分接近填充技。献祭光环 CD 好了就开。盯什么：自己脚下的碎片及时吸收；恶魔尖刺增益在承伤瞬间必须在线，掉了立刻补。", en="How to play: Fracture builds soul fragments, Soul Cleave spends them — that loop never stops. Spirit Bomb pays best at 4+ fragments. Don't bank Demon Spikes: press it as physical hits wind up — top players use it at 7/min, near filler frequency. Immolation Aura on cooldown. Watch: absorb your fragments promptly; Demon Spikes must be active the moment physical damage lands — reapply instantly if it drops." },
    },
  },
  ["DRUID/BALANCE"] = {
    specID=102,
    raid={
      n=5, dur=415, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Cotti", server="Tarren Mill", region="EU", seq={190984,1233272,8921,93402,93402,8921,93402,194153,202770,1293316,102560,191034} },
        { player="Recruitie", server="Illidan", region="US", seq={190984,93402,8921,8921,202770,1233272,194153,1236616,1250533,102560,191034,191034} },
        { player="阿揪揪", server="罗宁", region="CN", seq={190984,93402,8921,8921,1233272,194153,202770,1236616,102560,1293316,191034,191034} },
      },
      core={ {194153,14.2},{191034,12.6},{78674,6.4},{8921,5.3},{93402,3.7},{202770,2.5},{1233272,1.9},{102560,0.7},{22812,0.6},{1293316,0.6} }, -- Starfire, Starfall, Starsurge, Moonfire, Sunfire, Fury of Elune, Lunar Eclipse, Incarnation: Chosen of Elune, Barkskin, Empowering Venom
      watch={ {465,96.2},{1303480,95.9},{1287771,87.9},{191034,87.5},{372014,87.2},{279709,82.8},{343648,72.8},{48518,65.1},{1301768,65.1},{139,64.0} }, -- Devotion Aura, Orbit Breaker, Rune of Masterful Cunning, Starfall, Visage, Starlord, Solstice, Eclipse (Lunar), Akil'zon's Clarity, Renew
      coach={ cn="怎么打：愤怒持续填充推日蚀（顶尖23.9次/分），星能喂星涌术（13.8次/分），阳炎术和月火术全程不掉。星辰坠落在单体也按（7.7次/分，配合天赋收益），自然之力和艾露恩之怒按 CD。盯什么：星辰领主层数（顶尖覆盖85.3%）——星涌术打得勤它才常驻；日蚀窗口（太阳日蚀覆盖71.8%），窗口内愤怒伤害更高。", en="How to play: Wrath fills constantly to push Eclipse (top players: 23.9/min), Astral Power feeds Starsurge (13.8/min), and Sunfire plus Moonfire never drop. Starfall gets pressed even on single target (7.7/min with the right talents); Force of Nature and Fury of Elune on cooldown. Watch: Starlord stacks (85.3% top uptime) — frequent Starsurges keep it rolling; Eclipse windows (Solar at 71.8% uptime) where Wrath hits harder." },
    },
    mplus={
      n=8, dur=1760,
      core={ {194153,15.9},{191034,8.1},{78674,7.2},{8921,4.6},{93402,3.4},{202770,2.1},{1233272,1.7},{22812,0.6},{24858,0.5},{102560,0.5},{1293316,0.4} }, -- Starfire, Starfall, Starsurge, Moonfire, Sunfire, Fury of Elune, Lunar Eclipse, Barkskin, Moonkin Form, Incarnation: Chosen of Elune, Empowering Venom
      watch={ {465,97.5},{1303480,95.2},{378992,91.6},{24858,91.6},{279709,75.8},{48518,57.6},{1301768,57.6},{191034,45.2},{343648,41.8},{450346,40.6} }, -- Devotion Aura, Orbit Breaker, Lycara's Teachings, Moonkin Form, Starlord, Eclipse (Lunar), Akil'zon's Clarity, Starfall, Solstice, Dreamstate
      coach={ cn="怎么打：进怪群先把月火/阳炎甩到每个目标上（DOT 是隐形输出大头），然后星火术读条、星辰坠落保持常驻、星能给星涌术。艾露恩之怒 CD 好了对准怪群放。盯什么：星辰坠落的剩余时间——它快结束而怪还没死就续；保持枭兽形态别乱切（顶尖玩家94%时间在鸟里）。", en="How to play: Open packs by flinging Moonfire/Sunfire onto every target (DoTs are the hidden damage share), then channel Starfire, keep Starfall permanently down, and feed Astral Power to Starsurge. Fury of Elune on cooldown into packs. Watch: Starfall's remaining duration — recast if the pack will outlive it; stay in Moonkin Form (top players spend 94% of the run in it)." },
    },
  },
  ["DRUID/FERAL"] = {
    specID=103,
    mplus={
      n=8, dur=1782,
      core={ {106785,10.5},{5221,9.0},{1822,6.7},{22568,5.8},{441591,4.5},{285381,4.2},{5217,1.7},{1079,1.3},{1243807,1.1},{5487,1.0},{8936,1.0},{22812,0.6},{22842,0.4},{391528,0.4} }, -- Swipe, Shred, Rake, Ferocious Bite, Ravage, Primal Wrath, Tiger's Fury, Rip, Frantic Frenzy, Bear Form, Regrowth, Barkskin, Frenzied Regeneration, Convoke the Spirits
      watch={ {1263939,94.7},{378990,91.9},{768,91.9},{69369,83.3},{1287774,82.6},{207400,75.6},{1229746,68.2},{462568,67.3},{382024,67.0},{1241715,53.7} }, -- Unseen Predator's Craving, Lycara's Teachings, Cat Form, Predatory Swiftness, Rune of Burning Haste, Ancestral Vigor, Arcanoweave Insight, Elemental Resistance, Earthliving Weapon, Might of the Void
      coach={ cn="怎么打：群怪改用横扫攒星，终结技用原始之怒把割裂一次铺满全场；凶猛撕咬留给该死的优先目标。斜掠照常上。蹂躏 触发亮了优先按。盯什么：怪群里每个目标的割裂覆盖（原始之怒续）；保持猎豹形态（91%），治疗压力大也先确认再切熊。", en="How to play: On packs, build with Swipe and finish with Primal Wrath to blanket Rip across everything; save Ferocious Bite for priority kill targets. Keep Rake up as usual, and press Ravage procs when they light. Watch: Rip coverage on every pack member (re-spread via Primal Wrath); stay in Cat Form (91%) — verify before shifting bear even under pressure." },
    },
  },
  ["DRUID/GUARDIAN"] = {
    specID=104,
    raid={
      n=5, dur=408, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Gnomerender", server="Silvermoon", region="EU", seq={22812,1270292,204066,768,1293316,1236616,50334,77758,1252871,77758,192081,33917} },
        { player="大玥玥", server="贫瘠之地", region="CN", seq={77758,33917,1297761,1236616,1270292,204066,33917,77758,1252871,102558,1269658,77758} },
        { player="Skamenbear", server="Tarren Mill", region="EU", seq={1236616,1293316,1270292,204066,768,5487,102558,1269658,1252871,33917,192081,77758} },
      },
      core={ {192081,19.7},{33917,17.7},{77758,14.6},{6807,3.4},{213771,3.3},{22842,2.0},{1252871,1.8},{204066,1.4},{22812,1.2},{1269658,0.6},{102558,0.6},{16979,0.6},{768,0.5},{77761,0.4} }, -- Ironfur, Mangle, Thrash, Maul, Swipe, Frenzied Regeneration, Red Moon, Lunar Beam, Barkskin, Wild Guardian, Incarnation: Guardian of Ursoc, Wild Charge, Cat Form, Stampeding Roar
      watch={ {1251877,93.8},{192081,93.8},{1287772,87.6},{1253600,71.6},{382024,67.7},{1229746,65.7},{462568,59.3},{1241715,50.4},{156322,44.1},{1307922,35.3} }, -- Gift of an Ancient Guardian, Ironfur, Rune of Critical Power, Lunar Wrath, Earthliving Weapon, Arcanoweave Insight, Elemental Resistance, Might of the Void, Eternal Flame, Venomcursed Mastery
      coach={ cn="怎么打：裂伤 CD 好了必按（顶尖18.3次/分），痛击保持流血，怒气在进攻期喂摧折（10.8次/分）、承伤期喂铁鬃。明月普照和赤红之月按 CD（明月覆盖44.8%=几乎每次都站满圈）。盯什么：铁鬃层数——物理大伤害前提前叠；明月普照的圈，输出和减伤都要求你站在里面。", en="How to play: Mangle on cooldown always (top players: 18.3/min), Thrash keeps the bleed rolling, and rage goes to Raze when attacking (10.8/min) or Ironfur when tanking damage. Lunar Beam and Red Moon on cooldown (44.8% Lunar Beam uptime = standing in the full beam nearly every cast). Watch: Ironfur stacks — pre-stack before big physical hits; your Lunar Beam circle, since both damage and mitigation want you inside it." },
    },
    mplus={
      n=8, dur=1824,
      core={ {192081,25.2},{77758,15.4},{8921,13.7},{33917,12.8},{22842,2.4},{204066,1.3},{22812,1.2},{213771,0.5},{6807,0.5},{102558,0.5},{1269658,0.5},{61336,0.4},{99,0.3},{5487,0.3} }, -- Ironfur, Thrash, Moonfire, Mangle, Frenzied Regeneration, Lunar Beam, Barkskin, Swipe, Maul, Incarnation: Guardian of Ursoc, Wild Guardian, Survival Instincts, Incapacitating Roar, Bear Form
      watch={ {378991,96.1},{5487,96.1},{1251877,90.6},{192081,90.6},{1287774,84.1},{1295582,74.4},{1229746,64.5},{372505,58.6},{1241715,55.8},{213708,43.6} }, -- Lycara's Teachings, Bear Form, Gift of an Ancient Guardian, Ironfur, Rune of Burning Haste, Focus of Ula'tek, Arcanoweave Insight, Ursoc's Fury, Might of the Void, Galactic Guardian
      coach={ cn="怎么打：大秘境换打法——月火术见缝插针地按（顶尖玩家25次/分），痛击打 AOE，怒气几乎全喂铁鬃。铁鬃要按成肌肉记忆：物理怪群里有怒气就点，可以叠层。明月普照 CD 好了对怪群放。盯什么：自己身上的铁鬃图标——顶尖玩家覆盖91%，它就是你的硬度；掉了而怪还在打你，立刻补上。淤血 触发亮了裂伤免费，顺手按。", en="How to play: Mythic+ flips the playbook — weave Moonfire constantly (top players hit 25/min), Thrash for AoE, and feed nearly all rage into Ironfur. Make Ironfur muscle memory: in physical packs, press it whenever you have rage; it stacks. Lunar Beam on cooldown into packs. Watch: your own Ironfur icon — top players hold 91% uptime, and it IS your toughness; if it drops while mobs are hitting you, reapply now. Press free Mangles when Gore procs." },
    },
  },
  ["DRUID/RESTORATION"] = {
    specID=105,
    raid={
      n=5, dur=412, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Bdsanshisan", server="凤凰之神", region="CN", seq={774,774,48438,774,155777,774,132158,8936,774,22812,391528,155777} },
        { player="Lunchable", server="Blackmoore", region="EU", seq={8921,18562,155777,774,8921,5176,155777,774,774,768,1079,774} },
        { player="Lalon", server="Blackrock", region="EU", seq={774,18562,774,774,774,48438,8936,8936,8936,18562,155777,155777} },
      },
      core={ {8936,17.1},{774,14.9},{18562,5.5},{48438,4.2},{33763,3.1},{391528,1.0},{132158,1.0},{22812,0.7},{88423,0.7},{1291894,0.5},{740,0.4},{8921,0.4},{29166,0.3} }, -- Regrowth, Rejuvenation, Swiftmend, Wild Growth, Lifebloom, Convoke the Spirits, Nature's Swiftness, Barkskin, Nature's Cure, Soulcoiler Ritual Vessel, Tranquility, Moonfire, Innervate
      watch={ {207640,97.4},{1287774,87.8},{400126,84.6},{465,83.7},{1302255,83.5},{392360,72.8},{372014,62.8},{1241715,57.1},{1229746,55.7},{439530,53.8} }, -- Abundance, Rune of Burning Haste, Forestwalk, Devotion Aura, Genesis, Reforestation, Visage, Might of the Void, Arcanoweave Insight, Symbiotic Blooms
      coach={ cn="怎么打：治疗的关键是提前量——团队要吃伤害前3-5秒铺回春（顶尖20.5次/分），伤害落地野性成长跟上，单点掉血用愈合（17.5次/分）+迅捷治愈秒。生命绽放全程挂坦克。万灵之召留给最疼的轴。盯什么：DBM/团队时间轴比血条更重要——HOT 要先于伤害生效；迅捷治愈 CD（4.6次/分=转好就用），它是唯一的瞬发应急。", en="How to play: Healing is about lead time — blanket Rejuvenation 3-5 seconds before raid damage (top players: 20.5/min), follow with Wild Growth as it lands, and spot-heal with Regrowth (17.5/min) plus Swiftmend. Lifebloom lives on the tank. Save Convoke for the hardest hit. Watch: the fight timeline matters more than health bars — HoTs must tick before damage arrives; Swiftmend's cooldown (4.6/min = used on refresh), your only instant emergency button." },
    },
    mplus={
      n=8, dur=1681,
      core={ {774,14.3},{8936,6.7},{33763,4.5},{18562,4.4},{48438,2.7},{1822,2.2},{5221,1.3},{1079,1.2},{88423,0.7},{8921,0.7},{132158,0.6},{391528,0.6},{5487,0.4},{783,0.4} }, -- Rejuvenation, Regrowth, Lifebloom, Swiftmend, Wild Growth, Rake, Shred, Rip, Nature's Cure, Moonfire, Nature's Swiftness, Convoke the Spirits, Bear Form, Travel Form
      watch={ {207640,86.1},{378989,85.8},{1287774,78.8},{1302255,77.4},{1232585,76.5},{1229746,62.4},{400126,56.0},{1241762,55.2},{1266687,54.2},{1287665,39.9} }, -- Abundance, Lycara's Teachings, Rune of Burning Haste, Genesis, Well Fed, Arcanoweave Insight, Forestwalk, Frenzied Focus, Alnscorned Essence, Rune of Lingering
      coach={ cn="怎么打：治疗没压力时果断切猫输出（斜掠/撕碎/割裂），队伍要吃 AOE 前切回来铺回春+野性成长。生命绽放常驻坦克。诀窍是回春保持多个目标在跳——丰饶 层数（96%覆盖）会让愈合越来越便宜。盯什么：坦克血线趋势（不是瞬时值），以及自己回春的存量——它既是治疗也是 丰饶 的燃料。", en="How to play: When healing is light, swap to cat and deal damage (Rake/Shred/Rip); shift back before group damage to blanket Rejuvenation + Wild Growth. Keep Lifebloom on the tank. The trick: keep Rejuvenation ticking on several targets — Abundance stacks (96% uptime) make each Regrowth cheaper. Watch: the tank's health trend, and your live Rejuv count — it's both healing and Abundance fuel." },
    },
  },
  ["EVOKER/AUGMENTATION"] = {
    specID=1473,
    raid={
      n=5, dur=412, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Xephyris", server="Blackrock", region="EU", seq={431443,403631,395152,409311,370553,409311,396286,357208,404977,358267,358267,409311} },
        { player="Curris", server="Silvermoon", region="EU", seq={403631,371838,358267,395152,409311,406732,409311,370553,357208,1260459,396286,404977} },
        { player="Batchester", server="Stormreaver", region="EU", seq={431443,409311,409311,403631,395152,370553,357208,396286,404977,358267,1263768,409311} },
      },
      core={ {395160,16.3},{431443,8.2},{409311,6.5},{396286,5.6},{357208,4.5},{358267,2.8},{395152,1.8},{370553,0.9},{403631,0.7},{363916,0.6},{358733,0.5},{362969,0.4},{374227,0.4},{404977,0.4} }, -- Eruption, Chrono Flames, Prescience, Upheaval, Fire Breath, Hover, Ebon Might, Tip the Scales, Breath of Eons, Obsidian Scales, Glide, Azure Strike, Zephyr, Time Skip
      watch={ {395296,90.3},{1287772,86.3},{410263,81.8},{431654,68.9},{1229746,68.8},{382024,68.4},{462568,64.2},{408005,56.1},{372014,54.5},{358267,54.0} }, -- Ebon Might, Rune of Critical Power, Inferno's Blessing, Primacy, Arcanoweave Insight, Earthliving Weapon, Elemental Resistance, Momentum Shift, Visage, Hover
      coach={ cn="怎么打：增辉的输出就是队友的输出——黑檀之力按 CD 开（自身覆盖96.5%），先知先觉提前挂给爆发位（6.7次/分）。精华喂喷发（顶尖19.6次/分），地壳激变和火焰吐息按 CD，扭转天平配合大窗口瞬发满蓄力。盯什么：黑檀之力的剩余时间——它掉了你的全队增益就断了；先知先觉保持两个目标轮转不空档。", en="How to play: Augmentation's damage IS your allies' damage — Ebon Might on cooldown (96.5% self uptime), Prescience pre-applied to burst players (6.7/min). Essence feeds Eruption (top players: 19.6/min); Upheaval and Fire Breath on cooldown, with Tip the Scales for an instant max-empower during big windows. Watch: Ebon Might's remaining duration — if it drops, your raid-wide buff chain breaks; keep Prescience cycling on two targets with no gaps." },
    },
    mplus={
      n=8, dur=1834,
      core={ {395160,14.4},{431443,6.0},{409311,5.3},{396286,4.8},{357208,3.7},{358267,2.3},{395152,1.7},{358733,1.7},{370553,0.7},{362969,0.6},{363916,0.5},{403631,0.5},{404977,0.4},{355913,0.3} }, -- Eruption, Chrono Flames, Prescience, Upheaval, Fire Breath, Hover, Ebon Might, Glide, Tip the Scales, Azure Strike, Obsidian Scales, Breath of Eons, Time Skip, Emerald Blossom
      watch={ {465,96.8},{395296,81.5},{1287771,74.2},{431654,63.7},{1229746,63.4},{408005,51.4},{1259171,44.1},{358267,43.3},{372470,36.7},{431698,35.5} }, -- Devotion Aura, Ebon Might, Rune of Masterful Cunning, Primacy, Arcanoweave Insight, Momentum Shift, Duplicate, Hover, Scarlet Adaptation, Temporal Burst
      coach={ cn="怎么打：手法同团本——黑檀之力常驻、先知先觉轮转、喷发主键、吐息卡CD。五人本的额外要求：持续施法别停（不懈围攻 覆盖92%靠这个），赶路转场也尽量保持有东西在读条。盯什么：黑檀之力与队伍开怪节奏的对齐——在坦克拉下一波之前就把增益续好。", en="How to play: Same hands as raid — Ebon Might permanent, Prescience rotating, Eruption as the main button, breaths on cooldown. The five-man extra: never stop casting (Unrelenting Siege's 92% uptime depends on it), even through transitions. Watch: sync Ebon Might with pull rhythm — refresh it before the tank grabs the next pack." },
    },
  },
  ["EVOKER/DEVASTATION"] = {
    specID=1467,
    raid={
      n=5, dur=413, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Gilgvoker", server="Tichondrius", region="US", seq={361469,375087,390386,433874,1236616,370553,357208,359073,358267,356995,356995,356995} },
        { player="Fistlad", server="Stormreaver", region="US", seq={361469,433874,375087,370553,1236616,357208,359073,356995,356995,356995,356995,356995} },
        { player="Aphrokin", server="Zul'jin", region="US", seq={361469,433874,375087,1236616,370553,357208,356995,359073,362969,356995,356995,356995} },
      },
      core={ {356995,16.4},{359073,7.0},{357208,6.2},{361469,5.8},{358267,3.4},{433874,2.2},{1292321,2.2},{362969,1.7},{370553,0.6},{363916,0.6},{375087,0.6},{1293316,0.6} }, -- Disintegrate, Eternity Surge, Fire Breath, Living Flame, Hover, Deep Breath, Unbound Flame, Azure Strike, Tip the Scales, Obsidian Scales, Dragonrage, Empowering Venom
      watch={ {1295057,93.4},{1287772,85.8},{139,84.9},{375802,77.8},{1229746,75.8},{411055,68.5},{1297663,66.3},{358267,59.2},{1271783,47.1},{356995,47.0} }, -- Tidal Insight, Rune of Critical Power, Renew, Burnout, Arcanoweave Insight, Imminent Destruction, Halazzi's Rite, Hover, Rising Fury, Disintegrate
      coach={ cn="怎么打：裂解是核心引导（顶尖16.9次/分），打满别剪——它和永恒之涌、火焰吐息构成主轴。吐息类蓄力看场合：单体满蓄力收益最高。活化烈焰只是移动补缝（3.1次/分）。悬空保持施法机动（覆盖84.6%=顶尖几乎全程边飞边读条）。盯什么：精华别溢出——裂解要持续吃精华；燃尽触发（覆盖76.3%）让活化烈焰瞬发，移动轴前留着。", en="How to play: Disintegrate is your core channel (top players: 16.9/min) — let it finish, don't clip — alongside Eternity Surge and Fire Breath. Empower levels depend on context: max empower wins on single target. Living Flame is just a movement filler (3.1/min). Hover keeps you casting while mobile (84.6% uptime = top players basically fly and cast all fight). Watch: never cap essence — Disintegrate needs constant feeding; Burnout procs (76.3% uptime) make Living Flame instant, bank them for movement." },
    },
    mplus={
      n=8, dur=1718,
      core={ {356995,10.9},{359073,6.5},{357208,6.0},{361469,5.8},{357211,3.0},{433874,2.3},{358267,2.2},{1292321,1.7},{362969,1.6},{358733,1.5},{363916,0.5},{375087,0.4},{370553,0.4} }, -- Disintegrate, Eternity Surge, Fire Breath, Living Flame, Pyre, Deep Breath, Hover, Unbound Flame, Azure Strike, Glide, Obsidian Scales, Dragonrage, Tip the Scales
      watch={ {441248,91.0},{370454,84.6},{1287772,81.1},{411055,69.3},{1241715,54.1},{375802,53.1},{1271783,38.9},{358267,37.5},{1307922,33.6},{370901,33.6} }, -- Unrelenting Siege, Charged Blast, Rune of Critical Power, Imminent Destruction, Might of the Void, Burnout, Rising Fury, Hover, Venomcursed Mastery, Leaping Flames
      coach={ cn="怎么打：群怪把精华改喂葬火（对准怪堆丢），裂解留给精英和 boss；火焰吐息尽量蓄到能扫到整群怪的角度再放。悬空照常保持移动输出。盯什么：怪群数量——3个以上葬火，少了切回裂解；火焰吐息的覆盖角度比时机更重要。", en="How to play: On packs, feed Essence into Pyre (thrown at the pile) and reserve Disintegrate for elites and bosses; angle Fire Breath to sweep the whole pack before releasing. Hover keeps you casting through movement. Watch: target count — Pyre at 3+, back to Disintegrate below; Fire Breath's coverage angle matters more than its timing." },
    },
  },
  ["EVOKER/PRESERVATION"] = {
    specID=1468,
    raid={
      n=5, dur=415, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Drosn", server="Antonidas", region="EU", seq={355913,1265991,355913,1265991,370553,357208,364343,1265991,364343,364343,370537,355936} },
        { player="Nürokms", server="Blackhand", region="EU", seq={1291894,355913,1265991,370553,357208,355936,373861,355913,1265991,361469,364343,1265991} },
        { player="勺子教审判长", server="贫瘠之地", region="CN", seq={370553,357208,355936,373861,355913,1265991,357208,356995,361469,364343,1265991,364343} },
      },
      core={ {355913,13.1},{364343,8.2},{355936,5.5},{1256581,4.3},{357208,4.1},{373861,4.0},{361469,1.4},{358267,1.2},{370537,0.7},{358733,0.7},{366155,0.7},{363916,0.6},{1291894,0.6},{370553,0.6} }, -- Emerald Blossom, Echo, Dream Breath, Merithra's Blessing, Fire Breath, Temporal Anomaly, Living Flame, Hover, Stasis (Store), Glide, Reversion, Obsidian Scales, Soulcoiler Ritual Vessel, Tip the Scales
      watch={ {375583,92.7},{1287771,86.7},{362877,76.6},{139,66.5},{1229746,61.6},{1252487,60.8},{1241759,57.6},{1256579,56.9},{369299,49.5},{370901,44.4} }, -- Ancient Flame, Rune of Masterful Cunning, Temporal Compression, Renew, Arcanoweave Insight, Focused Hunt, Genius Insight, Merithra's Blessing, Essence Burst, Leaping Flames
      coach={ cn="怎么打：回响铺给即将吃伤害的人（顶尖11.1次/分），梦境吐息一口气把回响全部引爆成 HOT（8.1次/分）——这个组合就是奶龙的核心。翡翠之花补面板，时空畸体配合大伤害轴。火焰吐息别忘了打（1.3次/分），治疗间隙补输出。盯什么：团队时间轴——回响要在伤害前铺好；精华和蓝量管理，大轴前留满。", en="How to play: Echo goes on players about to take damage (top players: 11.1/min), then Dream Breath detonates every Echo into rolling HoTs (8.1/min) — that combo IS Preservation. Emerald Blossom patches the grid, Temporal Anomaly lines up with big damage events. Don't forget Fire Breath (1.3/min) for damage in healing gaps. Watch: the raid timeline — Echoes must be placed before damage lands; manage essence and mana so you enter big phases full." },
    },
    mplus={
      n=8, dur=1743,
      core={ {355913,8.0},{355936,6.0},{356995,5.8},{357208,5.6},{361469,5.3},{1256581,3.9},{373861,3.9},{358733,1.1},{358267,0.9},{364343,0.8},{360823,0.7},{363916,0.5},{370537,0.5},{370553,0.4} }, -- Emerald Blossom, Dream Breath, Disintegrate, Fire Breath, Living Flame, Merithra's Blessing, Temporal Anomaly, Glide, Hover, Echo, Naturalize, Obsidian Scales, Stasis (Store), Tip the Scales
      watch={ {372470,94.9},{375583,91.5},{1287774,78.9},{372014,77.5},{390148,77.4},{1256579,61.6},{443176,55.9},{369299,54.6},{362877,52.2},{1252488,32.3} }, -- Scarlet Adaptation, Ancient Flame, Rune of Burning Haste, Visage, Flow State, Merithra's Blessing, Lifespark, Essence Burst, Temporal Compression, Masterful Hunt
      coach={ cn="怎么打：没人掉血就打输出（裂解照常引导），队伍要承伤前回响铺好、梦境吐息引爆。进怪群前先丢时空畸体铺一层盾。逆转挂给持续掉血的目标。盯什么：坦克进怪的时机（提前铺盾），时光压缩 层数（86%覆盖）——保持施法别长时间挂机。", en="How to play: Deal damage when nobody's dropping (channel Disintegrate as normal); before group damage, spread Echoes and detonate with Dream Breath. Pre-shield with Temporal Anomaly before each pull, Reversion on targets taking sustained damage. Watch: the tank's pull timing for pre-shields, and Temporal Compression stacks (86%) — keep casting, don't idle." },
    },
  },
  ["HUNTER/BEASTMASTERY"] = {
    specID=253,
    raid={
      n=5, dur=417, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Ramwog", server="Area 52", region="US", seq={217200,34026,217200,19574,34026,217200,34026,217200,34026,193455,34026,193455} },
        { player="Matcheh", server="Mal'Ganis", region="US", seq={217200,217200,1236616,1250533,19574,34026,193455,217200,34026,193455,217200,34026} },
        { player="Tributroll", server="Sanguino", region="EU", seq={217200,1297761,19574,34026,217200,34026,217200,34026,193455,34026,193455,34026} },
      },
      core={ {34026,16.5},{193455,15.7},{217200,10.0},{1308188,5.8},{19574,1.9},{109304,0.6},{264735,0.6} }, -- Kill Command, Cobra Shot, Barbed Shot, Dire Beast, Bestial Wrath, Exhilaration, Survival of the Fittest
      watch={ {246152,89.8},{471877,89.7},{1287771,86.2},{459731,85.4},{139,72.0},{1229746,68.8},{1276720,61.7},{1297663,59.3},{465,59.3},{1306960,56.1} }, -- Barbed Shot, Howl of the Pack Leader, Rune of Masterful Cunning, Huntmaster's Call, Renew, Arcanoweave Insight, Nature's Ally, Halazzi's Rite, Devotion Aura, Dire Beast
      coach={ cn="怎么打：杀戮命令 CD 好了必按（顶尖19.1次/分），倒刺射击保持狂乱三层不断（11次/分），眼镜蛇射击泄集中值并给杀戮命令减 CD。狂野怒火按 CD 开（2次/分，覆盖50.6%）。盯什么：宠物狂乱的剩余时间——倒刺射击要在它掉之前接上；集中值别溢出也别打空，眼镜蛇射击的节奏跟着杀戮命令的 CD 走。", en="How to play: Kill Command on cooldown always (top players: 19.1/min), Barbed Shot keeps pet Frenzy at three stacks without dropping (11/min), and Cobra Shot dumps focus while reducing Kill Command's cooldown. Bestial Wrath on cooldown (2/min, 50.6% uptime). Watch: pet Frenzy's remaining duration — Barbed Shot must land before it falls; never cap or starve focus, pacing Cobra Shots around Kill Command's cooldown." },
    },
    mplus={
      n=8, dur=1782,
      core={ {34026,12.4},{193455,11.1},{217200,8.0},{1264359,4.2},{19574,1.7},{264735,0.6},{257284,0.4},{109304,0.3},{781,0.3} }, -- Kill Command, Cobra Shot, Barbed Shot, Wild Thrash, Bestial Wrath, Survival of the Fittest, Hunter's Mark, Exhilaration, Disengage
      watch={ {246152,84.7},{471877,81.9},{1287771,79.8},{268877,62.1},{1276720,59.6},{1229746,56.5},{1297663,56.0},{1299389,43.2},{19574,42.5},{471881,34.3} }, -- Barbed Shot, Howl of the Pack Leader, Rune of Masterful Cunning, Beast Cleave, Nature's Ally, Arcanoweave Insight, Halazzi's Rite, Cobra Fang, Bestial Wrath, Wyvern's Cry
      coach={ cn="怎么打：核心三键不变，群怪加狂野鞭笞（对准怪群）。倒刺射击在多目标时优先保证狂乱不断，再考虑分给副目标。盯什么：狂乱层数依然是第一位；宠物嚎叫增益（86%覆盖）的触发节奏——它亮的时候宠物伤害更高，杀戮命令尽量压在里面。", en="How to play: Same three-button core, adding Wild Thrash aimed into packs. With multiple targets, Barbed Shot first protects Frenzy uptime, then spreads. Watch: Frenzy stacks remain priority one; track Howl of the Pack Leader's rhythm (86% uptime) — pet damage spikes while it's up, so line Kill Commands into it." },
    },
  },
  ["HUNTER/MARKSMANSHIP"] = {
    specID=254,
    raid={
      n=5, dur=415, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Azortharion", server="Kazzak", region="EU", seq={19434,212431,212431,257044,19434,185358,1293316,288613,19434,185358,19434,185358} },
        { player="Qenjua", server="Sylvanas", region="EU", seq={19434,257044,19434,56641,185358,19434,56641,185358,19434,1297761,185358,19434} },
        { player="Imnotanorc", server="Tichondrius", region="US", seq={19434,212431,186257,212431,257044,260243,1297761,288613,19434,185358,19434,185358} },
      },
      core={ {19434,10.2},{185358,5.9},{56641,5.3},{257044,4.7},{212431,3.2},{257620,2.2},{53351,1.3},{260243,1.2},{1264949,0.6},{288613,0.6},{1297761,0.6},{109304,0.4},{264735,0.4} }, -- Aimed Shot, Arcane Shot, Steady Shot, Rapid Fire, Explosive Shot, Multi-Shot, Kill Shot, Volley, Moonlight Chakram, Trueshot, Voracious Heart of Ula'tek, Exhilaration, Survival of the Fittest
      watch={ {1253750,95.1},{139,86.6},{465,77.2},{389020,65.7},{1229746,65.3},{1307922,45.2},{1279347,33.3},{204090,33.2},{390677,32.8},{260242,24.8} }, -- Stargazer, Renew, Devotion Aura, Bulletstorm, Arcanoweave Insight, Venomcursed Mastery, Quick Draw, Bullseye, Inspiration, Precise Shots
      coach={ cn="怎么打：瞄准射击是核心炮（顶尖10.1次/分，两充能别屯满），黑蚀箭按节奏打（8.3次/分），精确射击触发用奥术射击消耗，稳固射击只在没事干时填充。急速射击按 CD（4.1次/分），百发百中对齐爆发轴。盯什么：弹幕风暴层数（覆盖86.1%）和精确射击触发（覆盖31.7%）——触发亮了优先消耗再继续读瞄准。", en="How to play: Aimed Shot is your cannon (top players: 10.1/min — don't sit on two charges), Black Arrow on rhythm (8.3/min), Precise Shots procs spent on Arcane Shot, and Steady Shot only as idle filler. Rapid Fire on cooldown (4.1/min), Trueshot aligned with burst windows. Watch: Bulletstorm stacks (86.1% uptime) and Precise Shots procs (31.7% uptime) — when lit, spend the proc before casting the next Aimed Shot." },
    },
    mplus={
      n=8, dur=1813,
      core={ {19434,7.9},{257620,7.6},{257044,4.2},{212431,3.2},{185358,3.0},{56641,3.0},{260243,1.1},{34477,0.6},{264735,0.6},{781,0.5},{288613,0.5},{1264949,0.5},{257284,0.4} }, -- Aimed Shot, Multi-Shot, Rapid Fire, Explosive Shot, Arcane Shot, Steady Shot, Volley, Misdirection, Survival of the Fittest, Disengage, Trueshot, Moonlight Chakram, Hunter's Mark
      watch={ {1253750,88.7},{1287772,80.2},{207400,74.0},{462568,66.3},{389020,65.8},{382024,64.5},{1229746,60.9},{257622,51.7},{204090,47.0},{451447,37.4} }, -- Stargazer, Rune of Critical Power, Ancestral Vigor, Elemental Resistance, Bulletstorm, Earthliving Weapon, Arcanoweave Insight, Trick Shots, Bullseye, Don't Look Back
      coach={ cn="怎么打：先多重射击挂上 戏法射击，再接瞄准射击/急速射击让它们跳弹打全群——顺序错了伤害差一截。黑蚀箭照 CD 用。盯什么：戏法射击 增益（覆盖40%，还有提升空间）——每轮 AOE 前确认它在身上；怪群剩血决定继续 AOE 还是转单体打优先目标。", en="How to play: Multi-Shot first to apply Trick Shots, THEN Aimed Shot/Rapid Fire so they ricochet across the pack — wrong order costs real damage. Black Arrow on cooldown. Watch: the Trick Shots buff (40% uptime — room to improve) — confirm it's up before each AoE burst; pack health decides whether to keep cleaving or swap to priority targets." },
    },
  },
  ["HUNTER/SURVIVAL"] = {
    specID=255,
    raid={
      n=5, dur=522, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="Naintrapable", server="Cho’gall", region="EU", seq={259495,1250533,190925,259489,1261193,259489,1253859,1250646,259489,259495,186270,186289} },
        { player="残锋猎影", server="死亡之翼", region="CN", seq={259489,1297761,1253859,1250646,259489,259495,1261193,259495,259489,186270,1262293,259489} },
        { player="Swx", server="Twisting Nether", region="EU", seq={259489,259495,186270,1250533,1236616,259489,1253859,1250646,259489,1261193,1262293,259489} },
      },
      core={ {259489,14.6},{186270,8.7},{259495,6.9},{1261193,1.3},{1250646,0.9},{190925,0.6},{264735,0.6},{1250533,0.6},{781,0.4},{186289,0.3} }, -- Kill Command, Raptor Strike, Wildfire Bomb, Boomstick, Takedown, Harpoon, Survival of the Fittest, Freightrunner's Flask, Disengage, Aspect of the Eagle
      watch={ {260249,93.4},{1287771,88.2},{471877,88.1},{260286,77.8},{1229746,74.6},{1241759,58.1},{471881,50.6},{1273155,41.1},{472640,37.0},{1292687,34.5} }, -- Bloodseeker, Rune of Masterful Cunning, Howl of the Pack Leader, Tip of the Spear, Arcanoweave Insight, Genius Insight, Wyvern's Cry, Raptor Swipe!, Hogstrider, Shrapnel Bomb
      coach={ cn="怎么打：杀戮命令产能（顶尖14.6次/分），猛禽一击泄集中值（10.6次/分），野火炸弹 CD 好了必丢（6.8次/分）。矛尖优势的逻辑贯穿全程：杀戮命令先按，下一发技能吃增伤（覆盖84.4%）。狩魂一击留斩杀段。盯什么：矛尖优势的窗口——它覆盖84.4%意味着顶尖玩家几乎每个技能都吃到增伤；野火炸弹充能别屯。", en="How to play: Kill Command generates (top players: 14.6/min), Raptor Strike spends focus (10.6/min), Wildfire Bomb thrown on cooldown (6.8/min). Tip of the Spear logic runs the whole fight: Kill Command first, next ability eats the damage bonus (84.4% uptime). Save Takedown for execute. Watch: Tip of the Spear windows — 84.4% uptime means top players buff nearly every ability; never sit on Wildfire Bomb charges." },
    },
    mplus={
      n=8, dur=1675,
      core={ {259489,13.0},{186270,7.8},{259495,5.9},{1261193,1.8},{1263768,1.7},{1250646,0.8},{264735,0.5},{257284,0.5},{1293316,0.4},{34477,0.4} }, -- Kill Command, Raptor Strike, Wildfire Bomb, Boomstick, Light's Blessing, Takedown, Survival of the Fittest, Hunter's Mark, Empowering Venom, Misdirection
      watch={ {259388,88.8},{260249,87.0},{471877,84.2},{207400,82.1},{1287771,77.0},{382024,76.3},{462568,73.1},{260286,72.7},{1229746,63.4},{1241759,52.6} }, -- Mongoose Fury, Bloodseeker, Howl of the Pack Leader, Ancestral Vigor, Rune of Masterful Cunning, Earthliving Weapon, Elemental Resistance, Tip of the Spear, Arcanoweave Insight, Genius Insight
      coach={ cn="怎么打：手法同团本——杀戮命令、猛禽一击、野火炸弹三件套，炸弹对准怪群丢。换怪群时保持近战在场，别在跑动中空转。盯什么：猫鼬狂怒 层数（91%覆盖）——它是输出地板，掉层重叠等于从头再来；优胜劣汰在大伤害前提前按。", en="How to play: Same hands as raid — Kill Command, Raptor Strike, Wildfire Bomb, with bombs aimed into packs. Keep melee uptime through pack swaps; don't idle while running. Watch: Mongoose Fury stacks (91% uptime) — they're your damage floor, and re-stacking from zero is starting over; press Survival of the Fittest ahead of big hits." },
    },
  },
  ["MAGE/ARCANE"] = {
    specID=62,
    raid={
      n=5, dur=416, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Lunym", server="Blackhand", region="EU", seq={365350,1236616,5143,1250533,44425,321507,5143,1295924,44425,5143,1295924,44425} },
        { player="Lavarcane", server="Twisting Nether", region="EU", seq={30451,153626,80353,30451,30451,30451,30451,30451,1236616,30451,30451,30451} },
        { player="Zheenm", server="Twisting Nether", region="EU", seq={153626,80353,30451,30451,30451,30451,30451,30451,30451,44425,153626,30451} },
      },
      core={ {5143,14.6},{44425,13.4},{1295924,5.2},{30451,4.1},{235450,1.7},{321507,1.2},{212653,1.0},{153626,0.7},{1250533,0.7},{365350,0.7} }, -- Arcane Missiles, Arcane Barrage, Prismatic Bolt, Arcane Blast, Prismatic Barrier, Touch of the Magi, Shimmer, Arcane Orb, Freightrunner's Flask, Arcane Surge
      watch={ {448604,93.8},{449322,92.8},{461531,88.1},{1287772,85.1},{1296930,79.4},{1242974,79.2},{263725,73.9},{139,66.1},{1297663,59.8},{394195,58.2} }, -- Spellfire Sphere, Mana Cascade, Brainstorm, Rune of Critical Power, Cumulative Power, Arcane Salvo, Clearcasting, Renew, Halazzi's Rite, Overflowing Energy
      coach={ cn="怎么打：奥术冲击堆四层魔力（顶尖26.9次/分，全场最高频按键），奥术弹幕只在魔力满+触发时泄（8.7次/分），奥术宝珠按 CD 补充能（7次/分）。爆发轴：奥术涌动+大法师之触全部对齐，窗口内倾泻。盯什么：净化魔杖/清晰预兆类触发（清晰预兆覆盖61.4%）——它决定弹幕时机；蓝量曲线，爆发轴外别把蓝烧穿。", en="How to play: Arcane Blast stacks four charges (top players: 26.9/min, your busiest button), Arcane Barrage only dumps at full charges plus procs (8.7/min), Arcane Orb on cooldown for charge refills (7/min). Burst: Arcane Surge and Touch of the Magi stacked together, everything poured into the window. Watch: Clearcasting procs (61.4% uptime) — they time your Barrages; your mana curve, never burning dry outside burst windows." },
    },
    mplus={
      n=8, dur=1705,
      core={ {5143,13.4},{44425,12.1},{1295924,4.7},{30451,3.8},{235450,1.4},{321507,1.1},{212653,1.0},{1250533,0.6},{365350,0.6},{153626,0.5},{55342,0.5},{342245,0.4},{342247,0.3} }, -- Arcane Missiles, Arcane Barrage, Prismatic Bolt, Arcane Blast, Prismatic Barrier, Touch of the Magi, Shimmer, Freightrunner's Flask, Arcane Surge, Arcane Orb, Mirror Image, Alter Time, Alter Time
      watch={ {465,97.1},{448604,94.5},{449322,87.5},{461531,82.3},{1287770,81.4},{1242974,74.4},{1296930,70.3},{263725,68.5},{394195,56.1},{1297663,54.6} }, -- Devotion Aura, Spellfire Sphere, Mana Cascade, Brainstorm, Rune of the Versatile Warrior, Arcane Salvo, Cumulative Power, Clearcasting, Overflowing Energy, Halazzi's Rite
      coach={ cn="怎么打：模型不变，但弹幕在群怪时更激进——多目标分裂收益高，层数没满也可以泄。大法师之触对齐怪群刚拉稳的时机开。盯什么：怪群数量驱动弹幕时机；奥术齐射 覆盖95.5%说明顶尖玩家施法几乎不停——你的目标也是零空转。", en="How to play: Same model, but Barrage gets aggressive on packs — its multi-target split pays off even below max charges. Open Touch of the Magi once the pull is grouped. Watch: let pack size drive Barrage timing; Arcane Salvo's 95.5% uptime shows top players never stop casting — zero downtime is the goal." },
    },
  },
  ["MAGE/FIRE"] = {
    specID=63,
    raid={
      n=5, dur=498, encId=3470, encCn="盘魂者内克扎莉", mNum=1,
      opener={
        { player="小鸟游小埋", server="伊利丹", region="CN", seq={11366,190319,108853,2948,11366,1236616,1260459,11366,108853,11366,108853,11366} },
        { player="Émptinêss", server="Sylvanas", region="EU", seq={133,108853,133,11366,11366,108853,11366,108853,11366,108853,133,11366} },
        { player="Hrslkks", server="ajeusyara", region="KR", seq={11366,108853,133,11366,11366,108853,11366,108853,11366,108853,11366,108853} },
      },
      core={ {11366,26.4},{108853,20.0},{133,10.0},{2948,7.6},{2120,2.5},{153561,1.7},{212653,1.1},{190319,1.0},{235313,0.7},{1250508,0.5},{1260459,0.5} }, -- Pyroblast, Fire Blast, Fireball, Scorch, Flamestrike, Meteor, Shimmer, Combustion, Blazing Barrier, Emberwing Heatwave, Nullsight
      watch={ {448604,95.9},{461531,93.0},{449314,92.9},{383395,81.0},{1229746,69.7},{383811,62.3},{1241715,56.0},{1257350,49.7},{382024,49.1},{269651,46.3} }, -- Spellfire Sphere, Brainstorm, Mana Cascade, Feel the Burn, Arcanoweave Insight, Fevered Incantation, Might of the Void, Fired Up, Earthliving Weapon, Pyroclasm
      coach={ cn="怎么打：火球术持续读条，攒出法术连击后火焰冲击转成瞬发炎爆打出去（顶尖炎爆31.1次/分、火焰冲击24.8次/分）——这个转化就是火法的全部。移动时用灼烧保持施法（9.7次/分）。燃烧是爆发窗口：开之前攒好火焰冲击充能，窗口内全部倾泻。流星对齐燃烧。盯什么：法术连击状态——亮了立刻转化别犹豫；火焰冲击充能数（燃烧期外别用光）。", en="How to play: Hard-cast Fireball; when Heating Up appears, Fire Blast converts it to Hot Streak for an instant Pyroblast (top players: 31.1 Pyroblasts and 24.8 Fire Blasts per minute) — that conversion IS Fire Mage. Scorch keeps you casting while moving (9.7/min). Combustion is your burst window: enter with Fire Blast charges banked and dump everything. Meteor aligns with Combustion. Watch: your Hot Streak indicator — convert immediately, no hesitation; Fire Blast charges (never empty outside Combustion)." },
    },
    mplus={
      n=7, dur=1664,
      core={ {108853,16.4},{11366,16.3},{2120,10.0},{133,7.0},{2948,3.4},{153561,1.4},{212653,1.3},{235313,1.3},{190319,0.8} }, -- Fire Blast, Pyroblast, Flamestrike, Fireball, Scorch, Meteor, Shimmer, Blazing Barrier, Combustion
      watch={ {465,97.0},{448604,95.6},{461531,82.2},{1287770,81.2},{449314,80.4},{383395,68.4},{383811,59.5},{1241715,56.5},{1257350,45.6},{269651,44.8} }, -- Devotion Aura, Spellfire Sphere, Brainstorm, Rune of the Versatile Warrior, Mana Cascade, Feel the Burn, Fevered Incantation, Might of the Void, Fired Up, Pyroclasm
      coach={ cn="怎么打：转化逻辑不变，但法术连击 在 3 个以上目标时转烈焰风暴而不是炎爆——丢在怪群脚下。灼烧照常处理移动。燃烧对齐大波怪群开。盯什么：目标数量决定转化去向（风暴/炎爆的切换阈值）；法火球 层数（95.7%覆盖）靠持续施法维持。", en="How to play: Same conversion logic, but at 3+ targets Hot Streak goes into Flamestrike at the pack's feet instead of Pyroblast. Scorch handles movement as usual; align Combustion with big pulls. Watch: target count decides the conversion target (your Flamestrike/Pyroblast threshold); Spellfire Sphere stacks (95.7%) live on continuous casting." },
    },
  },
  ["MAGE/FROST"] = {
    specID=64,
    raid={
      n=4, dur=415, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="beobsakkaesip", server="ajeusyara", region="KR", seq={116,44614,80353,1236616,1250533,205021,212653,30455,84714,30455,30455,205021} },
        { player="Choechoi", server="ajeusyara", region="KR", seq={116,44614,212653,30455,205021,30455,84714,30455,44614,30455,30455,30455} },
        { player="Fallen", server="Frostwolf", region="EU", seq={116,80353,44614,84714,30455,1236616,1250533,205021,30455,30455,205021,44614} },
      },
      core={ {30455,22.0},{44614,6.9},{199786,4.3},{116,3.9},{84714,1.9},{11426,1.8},{205021,1.6},{212653,1.1},{1250533,0.7},{414658,0.4} }, -- Ice Lance, Flurry, Glacial Spike, Frostbolt, Frozen Orb, Ice Barrier, Ray of Frost, Shimmer, Freightrunner's Flask, Ice Cold
      watch={ {205473,90.5},{1229746,75.2},{1263263,72.0},{382024,70.1},{462568,64.0},{394195,58.6},{461531,54.9},{1287665,51.5},{455122,46.5},{1307922,36.1} }, -- Icicles, Arcanoweave Insight, Hand of Frost, Earthliving Weapon, Elemental Resistance, Overflowing Energy, Brainstorm, Rune of Lingering, Permafrost Lances, Venomcursed Mastery
      coach={ cn="怎么打：冰枪术是消耗主力（顶尖26.7次/分），寒冰箭攒冰柱，攒满打冰川尖刺，冰风暴的寒冰指窗口把尖刺和冰枪打进去。寒冰宝珠和冰霜射线按 CD（各约2次/分）。盯什么：冰柱数量（覆盖92.5%=几乎一直有冰柱在手）——五根满了别浪费；冰风暴之后的连招顺序，尖刺要吃到碎裂加成。", en="How to play: Ice Lance is your spender (top players: 26.7/min), Frostbolt builds Icicles, Glacial Spike fires at five, and Flurry's shatter window carries the Spike and Ice Lances. Frozen Orb and Ray of Frost on cooldown (~2/min each). Watch: Icicle count (92.5% uptime = Icicles banked almost constantly) — don't waste at five; your post-Flurry sequence, the Spike must land inside shatter." },
    },
    mplus={
      n=8, dur=1678,
      core={ {30455,13.4},{44614,6.7},{199786,4.3},{11426,1.2},{205021,1.1},{212653,1.0},{84714,0.9},{1459,0.3} }, -- Ice Lance, Flurry, Glacial Spike, Ice Barrier, Ray of Frost, Shimmer, Frozen Orb, Arcane Intellect
      watch={ {465,96.0},{205473,91.0},{1287772,78.3},{461531,54.6},{394195,49.1},{1229746,38.8},{1287665,36.7},{44544,34.0},{1222865,27.0},{157128,26.1} }, -- Devotion Aura, Icicles, Rune of Critical Power, Brainstorm, Overflowing Energy, Arcanoweave Insight, Rune of Lingering, Fingers of Frost, Glacial Spike!, Saved by the Light
      coach={ cn="怎么打：寒冰宝珠开怪群（高产触发），冰枪术照常吃碎冰连发，单体逻辑对精英保留。寒冰护体进入常规循环——拉怪前先套盾。盯什么：宝珠在怪群中的滚动路径（蹭满目标）；冰指触发的消耗速度跟上产出，多目标下很容易溢出。", en="How to play: Open packs with Frozen Orb (high proc generation), chain Ice Lance on shatter as usual, keep single-target logic for elites. Ice Barrier joins the regular loop — shield up before pulls. Watch: Orb's roll path through the pack (graze everything); spend Fingers procs as fast as they generate — they overcap easily multi-target." },
    },
  },
  ["MONK/BREWMASTER"] = {
    specID=268,
    raid={
      n=5, dur=405, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Telleria", server="Sargeras", region="US", seq={132578,1236616,205523,123986,325153,124503,100780,119582,205523,124506,124503,1263438} },
        { player="Sunaris", server="Tichondrius", region="EU", seq={1297908,1236616,132578,205523,124503,115181,100780,121253,205523,124506,124503,115181} },
        { player="Öüäöä", server="Tarren Mill", region="EU", seq={121253,115181,1241059,119582,325153,440839,132578,124506,124503,119582,121253,115181} },
      },
      core={ {205523,11.5},{100780,10.7},{121253,10.1},{115181,8.7},{119582,6.9},{1241059,1.7},{109132,1.0},{325153,0.9},{322101,0.7},{132578,0.6},{322109,0.4},{123986,0.4},{115399,0.4} }, -- Blackout Kick, Tiger Palm, Keg Smash, Breath of Fire, Purifying Brew, Celestial Infusion, Roll, Exploding Keg, Expel Harm, Invoke Niuzao, the Black Ox, Touch of Death, Chi Burst, Black Ox Brew
      watch={ {1287770,88.8},{451508,75.3},{450521,68.4},{1270990,64.2},{1301477,63.9},{393515,60.2},{1241715,56.2},{1260619,54.9},{455071,52.1},{156322,51.1} }, -- Rune of the Versatile Warrior, Balanced Stratagem, Aspect of Harmony, Potential Energy, Hot Potato, Pretense of Instability, Might of the Void, Elevated Stagger, Ox Stance, Eternal Flame
      coach={ cn="怎么打：醉酿投 CD 好了必按（顶尖13.6次/分），火焰之息跟上（12.7次/分），猛虎掌和幻灭踢填充。活血酒看醉拳条按（7.8次/分）——重伤变中伤就喝，别屯满两充能。天神灌注按 CD。盯什么：醉拳承伤条的颜色——黄了就该考虑活血酒，红了必须喝；醉酿投的充能（13.6次/分=转好就按），它是输出和减伤的发动机。", en="How to play: Keg Smash on cooldown always (top players: 13.6/min), Breath of Fire follows (12.7/min), Tiger Palm and Blackout Kick fill. Purifying Brew reacts to your stagger bar (7.8/min) — purify at moderate, never sit on two charges. Celestial Infusion on cooldown. Watch: your stagger bar's color — yellow means consider purifying, red means purify now; Keg Smash charges (13.6/min = pressed on refresh), the engine behind both damage and mitigation." },
    },
    mplus={
      n=8, dur=1697,
      core={ {205523,11.2},{121253,11.2},{115181,10.9},{100780,10.7},{119582,6.7},{1241059,2.6},{109132,1.6},{123986,1.5},{115399,1.0},{116841,0.5},{115203,0.5},{132578,0.5},{119381,0.4},{322109,0.3} }, -- Blackout Kick, Keg Smash, Breath of Fire, Tiger Palm, Purifying Brew, Celestial Infusion, Roll, Chi Burst, Black Ox Brew, Tiger's Lust, Fortifying Brew, Invoke Niuzao, the Black Ox, Leg Sweep, Touch of Death
      watch={ {392883,96.8},{215479,96.3},{1264426,89.7},{383733,89.7},{1287770,82.7},{462568,82.1},{207400,81.8},{382024,74.6},{451508,70.9},{393515,69.0} }, -- Vivacious Vivification, Shuffle, Void-Touched, Training of Niuzao, Rune of the Versatile Warrior, Elemental Resistance, Ancestral Vigor, Earthliving Weapon, Balanced Stratagem, Pretense of Instability
      coach={ cn="怎么打：手法同团本，活血酒按得更勤。核心纪律：金钟罩必须近乎全程在线（顶尖玩家96.7%）——它靠醉酿投/幻灭踢 的循环自然维持，所以输出循环停了减伤也停。大波怪群进场前确认活血酒有充能。盯什么：金钟罩 剩余时间和活血酒充能数，这两个就是你的生死面板。", en="How to play: Same hands as raid, with Purifying Brew busier. Core discipline: Shuffle must stay near-permanent (top players 96.7%) — it's sustained by your Keg Smash/Blackout Kick loop, so stopping your rotation stops your mitigation. Enter big pulls with brew charges ready. Watch: Shuffle's remaining duration and brew charges — that's your life-or-death dashboard." },
    },
  },
  ["MONK/MISTWEAVER"] = {
    specID=270,
    raid={
      n=5, dur=413, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Soupherring", server="Sargeras", region="US", seq={117952,116680,115151,115151,116849,467307,115151,115294,1291894,467307,115151,322118} },
        { player="Aziriemist", server="Ravencrest", region="EU", seq={116849,116680,115151,115151,467307,115151,443028,467307,115151,467307,115294,115151} },
        { player="Eiven", server="Gordunni", region="EU", seq={117952,116849,116680,115151,115151,467307,115151,467307,1291894,115151,467307,100784} },
      },
      core={ {467307,15.0},{116670,14.3},{115151,11.3},{124682,9.5},{115294,3.2},{116680,2.8},{115175,1.4},{116849,1.2},{100784,1.0},{115450,0.7},{109132,0.6},{443028,0.6},{1291894,0.6},{322118,0.6} }, -- Rushing Wind Kick, Vivify, Renewing Mist, Enveloping Mist, Mana Tea, Thunder Focus Tea, Soothing Mist, Life Cocoon, Blackout Kick, Detox, Roll, Celestial Conduit, Soulcoiler Ritual Vessel, Invoke Yu'lon, the Jade Serpent
      watch={ {115867,94.4},{1287774,90.4},{139,77.8},{1244617,61.1},{1229746,59.1},{1241715,58.9},{443569,50.5},{1260670,47.1},{392883,46.9},{1260565,40.7} }, -- Mana Tea, Rune of Burning Haste, Renew, Void Glass, Arcanoweave Insight, Might of the Void, Chi-Ji's Swiftness, Spiritfont, Vivacious Vivification, Spiritfont
      coach={ cn="怎么打：复苏之雾按 CD 铺（顶尖10.5次/分），活血术吃它做群刷（15.6次/分），氤氲之雾给重点目标（9.6次/分）。雷光聚神茶强化下一个技能——配氤氲之雾或活血术看需求（2.8次/分）。疾风呼啸踢别停（10.9次/分），武僧的输出就是治疗。盯什么：复苏之雾在团队里的张数——活血术的溅射跟着它走；法力茶的窗口（覆盖97.4%=顶尖几乎全程在茶态省蓝）。", en="How to play: Renewing Mist on cooldown (top players: 10.5/min), Vivify rides it for group healing (15.6/min), Enveloping Mist for focus targets (9.6/min). Thunder Focus Tea empowers your next spell — pair with Enveloping or Vivify as needed (2.8/min). Keep Rushing Wind Kick going (10.9/min); a Mistweaver's damage IS healing. Watch: Renewing Mist count across the raid — Vivify cleave follows it; Mana Tea windows (97.4% uptime = top players basically live in discounted casts)." },
    },
    mplus={
      n=8, dur=1844,
      core={ {107428,14.8},{101546,8.4},{100780,6.5},{100784,5.3},{115151,3.6},{124682,2.7},{116680,2.2},{399491,1.7},{109132,1.2},{115294,1.1},{325197,0.7},{115450,0.7},{115175,0.5},{116849,0.4} }, -- Rising Sun Kick, Spinning Crane Kick, Tiger Palm, Blackout Kick, Renewing Mist, Enveloping Mist, Thunder Focus Tea, Sheilun's Gift, Roll, Mana Tea, Invoke Chi-Ji, the Red Crane, Detox, Soothing Mist, Life Cocoon
      watch={ {388500,97.4},{115867,96.7},{462854,95.2},{6673,93.4},{399510,88.5},{399497,88.0},{392883,85.5},{1287774,80.6},{1260565,73.0},{414143,65.5} }, -- Secret Infusion, Mana Tea, Skyfury, Battle Shout, Sheilun's Gift, Sheilun's Gift, Vivacious Vivification, Rune of Burning Haste, Spiritfont, Yu'lon's Grace
      coach={ cn="怎么打：没治疗压力就打输出连段（神鹤引项踢/旭日东升踢/猛虎掌），要奶的时候神龙之赐层数攒够直接灌，点名用氤氲之雾。这个玩法的核心是敢打——输出循环就是你的法力和治疗引擎。盯什么：神龙之赐的层数（对齐承伤波次释放）；坦克血线趋势，留一个反应窗口。", en="How to play: With no healing pressure, run your damage chain (Spinning Crane Kick / Rising Sun Kick / Tiger Palm); when healing is needed, dump banked Sheilun's Gift stacks and spot-heal with Enveloping Mist. The core skill is daring to fight — your damage loop IS your mana and healing engine. Watch: Sheilun's Gift stacks (release into damage waves) and the tank's health trend, keeping a reaction window." },
    },
  },
  ["MONK/WINDWALKER"] = {
    specID=269,
    raid={
      n=5, dur=402, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Sîp", server="Ravencrest", region="EU", seq={100780,123904,1297761,1249625,113656,101546,107428,152175,113656,101546,107428,100784} },
        { player="Xeoswhopper", server="Area 52", region="US", seq={117952,100780,1297761,1249625,123904,113656,107428,152175,100784,113656,101546,107428} },
        { player="Faradash", server="Eredar", region="EU", seq={100780,109132,123904,1297761,1249625,113656,101546,107428,152175,113656,101546,107428} },
      },
      core={ {100780,11.1},{107428,7.4},{100784,7.3},{113656,6.3},{101546,6.3},{467307,2.5},{152175,2.2},{109132,1.0},{1249625,0.9},{123904,0.7},{1297761,0.7},{443028,0.7},{122470,0.6},{116670,0.5} }, -- Tiger Palm, Rising Sun Kick, Blackout Kick, Fists of Fury, Spinning Crane Kick, Rushing Wind Kick, Whirling Dragon Punch, Roll, Zenith, Invoke Xuen, the White Tiger, Voracious Heart of Ula'tek, Celestial Conduit, Touch of Karma, Vivify
      watch={ {392883,92.8},{1287771,86.0},{202090,79.3},{139,75.7},{451298,71.9},{1229746,61.9},{1297663,60.3},{196742,46.7},{1297664,43.8},{443569,40.9} }, -- Vivacious Vivification, Rune of Masterful Cunning, Teachings of the Monastery, Renew, Momentum Boost, Arcanoweave Insight, Halazzi's Rite, Whirling Dragon Punch, Akil'zon's Rite, Chi-Ji's Swiftness
      coach={ cn="怎么打：猛虎掌产真气（顶尖10次/分），旭日东升踢 CD 好了必按（8.9次/分），幻灭踢消耗填充（9.2次/分），怒雷破按 CD 打满（6.2次/分）——记住连击规则：同一技能不连按两次。升龙霸转好就按（2次/分）。盯什么：连击序列别断——这是踏风的核心收益；动量提升（覆盖72.5%）和升龙霸的可用窗口（覆盖69.9%），亮了优先。", en="How to play: Tiger Palm builds chi (top players: 10/min), Rising Sun Kick on cooldown always (8.9/min), Blackout Kick spends as filler (9.2/min), Fists of Fury channeled fully on cooldown (6.2/min) — and remember the combo rule: never the same ability twice in a row. Whirling Dragon Punch on refresh (2/min). Watch: never break your combo chain — it's Windwalker's core payoff; Momentum Boost (72.5% uptime) and Whirling Dragon Punch availability (69.9%), press when lit." },
    },
    mplus={
      n=8, dur=1700,
      core={ {100780,9.6},{101546,8.1},{107428,6.2},{113656,5.6},{100784,4.8},{467307,2.1},{152175,1.9},{1272696,1.3},{109132,1.1},{1249625,0.7},{1297761,0.6},{443028,0.6},{123904,0.6},{322109,0.4} }, -- Tiger Palm, Spinning Crane Kick, Rising Sun Kick, Fists of Fury, Blackout Kick, Rushing Wind Kick, Whirling Dragon Punch, Zenith Stomp, Roll, Zenith, Voracious Heart of Ula'tek, Celestial Conduit, Invoke Xuen, the White Tiger, Touch of Death
      watch={ {196741,95.9},{392883,90.7},{1248705,86.8},{1459,85.8},{202090,76.3},{1229746,69.7},{414143,67.4},{451298,66.3},{1297663,56.2},{1297664,47.2} }, -- Hit Combo, Vivacious Vivification, Skyfire Heel, Arcane Intellect, Teachings of the Monastery, Arcanoweave Insight, Yu'lon's Grace, Momentum Boost, Halazzi's Rite, Akil'zon's Rite
      coach={ cn="怎么打：群怪把神鹤引项踢插进连击链，不重复的铁律照旧（连击增益 覆盖97.3%）。怒雷破对准怪群引导。换目标不影响连击——大胆切优先目标。盯什么：连击增益是否还在；怪群数量决定神鹤的出场频率，3 个以上就值得进链。", en="How to play: Slot Spinning Crane Kick into the combo chain on packs — the no-repeat rule still applies (Hit Combo at 97.3%). Channel Fists of Fury into the pack. Target swaps don't break your combo — swap to priority targets freely. Watch: that the combo buff stays up; pack size sets Crane Kick's frequency — worth chaining at 3+ targets." },
    },
  },
  ["PALADIN/HOLY"] = {
    specID=65,
    raid={
      n=5, dur=405, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Hopè", server="Stormreaver", region="EU", seq={275773,20473,415388,415388,20473,415388,156322,275773,20473,415388,415388,19750} },
        { player="Purepala", server="Blackhand", region="EU", seq={19750,20473,415388,415388,1291894,275773,20473,415388,415388,156322,19750,20473} },
        { player="Nilssoñ", server="Kazzak", region="EU", seq={275773,1291894,85222,20473,415388,415388,275773,20473,415388,415388,26573,20473} },
      },
      core={ {20473,13.1},{156322,11.3},{19750,10.5},{200025,3.6},{85222,2.9},{375576,1.8},{275773,1.7},{82326,0.9},{4987,0.8},{190784,0.7},{498,0.7},{1241413,0.7},{1291894,0.6},{31884,0.6} }, -- Holy Shock, Eternal Flame, Flash of Light, Beacon of Virtue, Light of Dawn, Divine Toll, Judgment, Holy Light, Cleanse, Divine Steed, Divine Protection, Hammer of Wrath, Soulcoiler Ritual Vessel, Avenging Wrath
      watch={ {1287771,87.4},{447988,77.3},{382024,72.2},{1229746,68.3},{448087,65.8},{462568,57.5},{1252487,54.3},{1317581,44.6},{54149,40.9},{156322,37.8} }, -- Rune of Masterful Cunning, Light of the Martyr, Earthliving Weapon, Arcanoweave Insight, Bestow Light, Elemental Resistance, Focused Hunt, Venomcursed Ascendance, Infusion of Light, Eternal Flame
      coach={ cn="怎么打：神圣震击 CD 好了必按（顶尖13.5次/分），圣能喂黎明之光群刷（13.5次/分），圣光闪现补单点（9.2次/分）。圣洁鸣钟按 CD（1.7次/分）一口气刷五个震击。审判别忘了打（1.6次/分），它给治疗增益。盯什么：圣能别溢出——震击转好前把存量花掉；殉道者之光（覆盖75.6%）这类增益的窗口，大轴前对齐复仇之怒。", en="How to play: Holy Shock on cooldown always (top players: 13.5/min), Holy Power feeds Light of Dawn for group healing (13.5/min), Flash of Light spot-heals (9.2/min). Divine Toll on cooldown (1.7/min) fires five Shocks at once. Don't skip Judgment (1.6/min) for its healing buff. Watch: never cap Holy Power — spend before Shock refreshes; buff windows like Light of the Martyr (75.6% uptime), and align Avenging Wrath with big damage events." },
    },
    mplus={
      n=8, dur=1763,
      core={ {19750,8.0},{415091,7.6},{20473,7.5},{85673,6.9},{275773,6.1},{82326,2.1},{1241413,1.5},{432459,1.0},{432472,0.9},{4987,0.7},{498,0.6},{190784,0.6},{31884,0.5},{1291894,0.4} }, -- Flash of Light, Shield of the Righteous, Holy Shock, Word of Glory, Judgment, Holy Light, Hammer of Wrath, Holy Bulwark, Sacred Weapon, Cleanse, Divine Protection, Divine Steed, Avenging Wrath, Soulcoiler Ritual Vessel
      watch={ {6673,93.8},{1264426,83.8},{460822,76.9},{432502,68.0},{1229746,59.1},{432496,53.2},{1241715,52.2},{432607,51.0},{54149,50.6},{1271436,45.0} }, -- Battle Shout, Void-Touched, Divine Guidance, Sacred Weapon, Arcanoweave Insight, Holy Bulwark, Might of the Void, Holy Bulwark, Infusion of Light, Masterwork: Weapon
      coach={ cn="怎么打：钥石里你是半个近战 DPS——没人掉血就贴怪打正义盾击和审判（它们产圣能、回法力），要奶的时候圣能转永恒之火/荣耀圣令。神圣震击照常卡 CD。盯什么：自己的站位（近战范围内才有完整体系）；坦克血线和圣能存量的联动——大伤害来临前留 3 圣能。", en="How to play: In keys you're half a melee DPS — when nobody's dropping, stay on the mobs with Shield of the Righteous and Judgment (they generate Holy Power), converting to Eternal Flame or Word of Glory when healing is needed. Holy Shock on cooldown as always. Watch: your positioning (the kit only works in melee range); link the tank's health to your Holy Power reserve — bank 3 before big hits." },
    },
  },
  ["PALADIN/PROTECTION"] = {
    specID=66,
    raid={
      n=5, dur=416, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Galdír", server="Twisting Nether", region="EU", seq={389539,1236616,1293316,1241413,375576,1241413,53600,432459,53600,1241413,31935,26573} },
        { player="Shieldboy", server="Sylvanas", region="EU", seq={275779,1236616,1293316,389539,375576,432472,53600,1241413,53600,1241413,31935,53600} },
        { player="Getterdin", server="Blackrock", region="EU", seq={432459,1236616,389539,375576,1293316,53600,1241413,1241413,53600,31935,204019,53600} },
      },
      core={ {53600,19.1},{204019,15.2},{275779,12.2},{1241413,6.8},{31935,6.2},{26573,4.5},{85673,3.4},{375576,1.0},{389539,1.0},{190784,0.9},{432459,0.7},{1293316,0.6},{432472,0.6},{31850,0.6} }, -- Shield of the Righteous, Blessed Hammer, Judgment, Hammer of Wrath, Avenger's Shield, Consecration, Word of Glory, Divine Toll, Sentinel, Divine Steed, Holy Bulwark, Empowering Venom, Sacred Weapon, Ardent Defender
      watch={ {327510,94.8},{1287772,85.9},{188370,85.1},{379017,82.3},{460822,81.6},{139,80.7},{1229746,74.3},{182104,64.4},{372014,64.4},{432502,63.2} }, -- Shining Light, Rune of Critical Power, Consecration, Faith's Armor, Divine Guidance, Renew, Arcanoweave Insight, Shining Light, Visage, Sacred Weapon
      coach={ cn="怎么打：正义盾击几乎常驻（顶尖22.8次/分，圣能全喂它），祝福之锤和审判转好就按（16.7和10.8次/分）维持产能，复仇者之盾按 CD，奉献别离脚下。掉血大了圣能转荣耀圣令。盯什么：正义盾击的剩余时间——物理承伤期不能断；闪耀之光的免费荣耀圣令触发（覆盖97.5%=顶尖从不浪费），白嫖的治疗记得用。", en="How to play: Shield of the Righteous stays near-permanent (top players: 22.8/min, all Holy Power feeds it), Blessed Hammer and Judgment on refresh (16.7 and 10.8/min) to keep generation rolling, Avenger's Shield on cooldown, and never leave your Consecration. Divert Holy Power to Word of Glory when health dips. Watch: Shield of the Righteous remaining duration — never let it drop during physical damage; free Word of Glory procs from Shining Light (97.5% uptime = top players never waste one)." },
    },
    mplus={
      n=8, dur=1770,
      core={ {53600,19.1},{204019,13.0},{275779,11.8},{31935,7.0},{1241413,6.0},{26573,5.0},{85673,2.4},{204079,1.4},{389539,0.8},{375576,0.8},{190784,0.8},{432459,0.6},{432472,0.6},{31850,0.6} }, -- Shield of the Righteous, Blessed Hammer, Judgment, Avenger's Shield, Hammer of Wrath, Consecration, Word of Glory, Final Stand, Sentinel, Divine Toll, Divine Steed, Holy Bulwark, Sacred Weapon, Ardent Defender
      watch={ {132403,94.6},{393038,93.9},{327510,92.9},{188370,83.5},{379017,83.4},{1287772,81.4},{460822,77.8},{182104,64.7},{1229746,61.8},{432502,58.8} }, -- Shield of the Righteous, Strength in Adversity, Shining Light, Consecration, Faith's Armor, Rune of Critical Power, Divine Guidance, Shining Light, Arcanoweave Insight, Sacred Weapon
      coach={ cn="怎么打：盾击覆盖纪律不变，多目标承伤下荣耀圣令按得更勤（自奶需求上来了）。拉怪时复仇者之盾开场、奉献落在怪群将要站定的位置。圣能在生存和输出间动态分——稳了才打输出。盯什么：盾击和奉献的双覆盖；法系怪群盾击挡不了法伤，提前规划保命 CD。", en="How to play: Same SotR discipline, with Word of Glory pressed more as multi-target damage raises self-healing needs. Open pulls with Avenger's Shield and drop Consecration where the pack will settle. Split Holy Power dynamically between survival and damage — damage only once stable. Watch: dual coverage of SotR and Consecration; SotR doesn't block spell damage, so plan defensives ahead for caster packs." },
    },
  },
  ["PALADIN/RETRIBUTION"] = {
    specID=70,
    raid={
      n=5, dur=416, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="原来是宗盛啊", server="死亡之翼", region="CN", seq={1236616,31884,24275,383328,408385,255937,408385,383328,53385,408385,408385,343527} },
        { player="Ezee", server="Frostmourne", region="US", seq={184575,408385,31884,1297761,1236616,343527,408385,255937,383328,408385,383328,408385} },
        { player="Yenvenger", server="Illidan", region="US", seq={383781,190784,184575,1236616,31884,343527,408385,255937,408385,383328,53385,408385} },
      },
      core={ {408385,42.4},{383328,20.9},{53385,8.7},{184575,7.1},{24275,5.9},{20271,4.9},{255937,1.9},{375576,1.0},{343527,1.0},{31884,1.0},{190784,0.7},{403876,0.6},{1297761,0.6},{156322,0.4} }, -- Crusading Strikes, Final Verdict, Divine Storm, Blade of Justice, Hammer of Wrath, Judgment, Wake of Ashes, Divine Toll, Execution Sentence, Avenging Wrath, Divine Steed, Divine Protection, Voracious Heart of Ula'tek, Eternal Flame
      watch={ {407065,91.8},{1305230,85.9},{1287771,85.0},{139,83.3},{1264050,42.4},{1241410,42.4},{31884,42.4},{1229746,37.9},{406086,28.4},{390677,22.4} }, -- Rush of Light, Divine Power, Rune of Masterful Cunning, Renew, Born in Sunlight, Hammer of Wrath, Avenging Wrath, Arcanoweave Insight, Art of War, Inspiration
      coach={ cn="怎么打：圣能产出靠公正之剑、审判、愤怒之锤转好就按（10.6、6.1、5.7次/分），最终审判是消耗主力（顶尖23.6次/分）。灰烬觉醒和圣洁鸣钟按 CD（各2.1次/分）。光之圣锤的窗口里优先打它（4.3次/分）。盯什么：圣能别溢出——三个产能键的 CD 错开按；光芒涌动（覆盖97.2%）说明顶尖玩家的资源循环从不停转。", en="How to play: Holy Power flows from Blade of Justice, Judgment, and Hammer of Wrath on refresh (10.6, 6.1, 5.7/min); Final Verdict is your main spender (top players: 23.6/min). Wake of Ashes and Divine Toll on cooldown (2.1/min each). Prioritize Hammer of Light inside its window (4.3/min). Watch: never cap Holy Power — stagger your three generators; Rush of Light at 97.2% uptime shows top players' resource loop never stalls." },
    },
    mplus={
      n=8, dur=1737,
      core={ {408385,45.9},{53385,13.3},{383328,12.7},{184575,5.7},{20271,5.3},{24275,4.2},{255937,1.7},{343527,0.8},{345228,0.8},{31884,0.8},{375576,0.8},{156322,0.6},{190784,0.5},{403876,0.5} }, -- Crusading Strikes, Divine Storm, Final Verdict, Blade of Justice, Judgment, Hammer of Wrath, Wake of Ashes, Execution Sentence, Gladiator's Badge, Avenging Wrath, Divine Toll, Eternal Flame, Divine Steed, Divine Protection
      watch={ {407065,86.8},{1287771,82.5},{1305230,80.3},{207400,71.9},{462568,68.2},{382024,65.8},{1229746,58.1},{1241762,51.1},{1296714,35.1},{1241410,31.6} }, -- Rush of Light, Rune of Masterful Cunning, Divine Power, Ancestral Vigor, Elemental Resistance, Earthliving Weapon, Arcanoweave Insight, Frenzied Focus, Faith in Ula'tek, Hammer of Wrath
      coach={ cn="怎么打：产能链不变，泄能键换成神圣风暴（2-3 个以上目标）；单体优先目标仍用最终审判。圣洁鸣钟丢进怪群一次性产能。盯什么：目标数量决定风暴/审判的切换；免费圣光之锤触发（95.5%覆盖）亮了立刻用，攒着就是亏。", en="How to play: Same builders; the spender becomes Divine Storm at 2-3+ targets, with Final Verdict kept for priority singles. Divine Toll into packs for a burst of Holy Power. Watch: target count drives the Storm/Verdict switch; spend free Hammer of Light procs from Light's Deliverance (95.5% uptime) immediately — sitting on them is pure loss." },
    },
  },
  ["PRIEST/DISCIPLINE"] = {
    specID=256,
    raid={
      n=5, dur=404, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Stopthecount", server="Thrall", region="US", seq={589,8092,10060,10060,47540,1253593,450215,450215,450215,47540,450215,450215} },
        { player="Clandon", server="Icecrown", region="US", seq={589,8092,47540,1253593,450215,450215,10060,10060,450215,450215,1253593,47540} },
        { player="tieka", server="ajeusyara", region="KR", seq={589,589,10060,10060,1291894,2061,194509,194509,472433,8092,47540,1253593} },
      },
      core={ {585,25.9},{47540,8.9},{1253593,6.4},{8092,4.3},{194509,4.0},{2061,2.7},{17,2.1},{10060,1.2},{121536,1.2},{589,0.9},{472433,0.7},{586,0.6},{527,0.6},{1291894,0.5} }, -- Smite, Penance, Void Shield, Mind Blast, Power Word: Radiance, Flash Heal, Power Word: Shield, Power Infusion, Angelic Feather, Shadow Word: Pain, Evangelism, Fade, Purify, Soulcoiler Ritual Vessel
      watch={ {1253725,84.5},{1287774,83.5},{450193,73.5},{465,62.0},{1241762,61.7},{1229746,61.6},{114255,59.6},{382024,58.2},{390692,51.5},{462568,50.4} }, -- Greater Smite, Rune of Burning Haste, Entropic Rift, Devotion Aura, Frenzied Focus, Arcanoweave Insight, Surge of Light, Earthliving Weapon, Borrowed Time, Elemental Resistance
      coach={ cn="怎么打：戒律的治疗走伤害——先铺救赎：团伤前真言术：盾+真言术：耀铺开（4.7和4.2次/分），然后惩击和苦修把救赎转成治疗（11.8和10次/分）。暗言术：灭和心灵震爆插缝。快速治疗只救急（6.9次/分）。盯什么：团队时间轴——救赎要在伤害前铺好，铺晚了惩击就白打；苦修的充能和触发窗口。", en="How to play: Discipline heals through damage — pre-spread Atonement with Power Word: Shield and Power Word: Radiance before raid damage (4.7 and 4.2/min), then Smite and Penance convert it to healing (11.8 and 10/min). Shadow Word: Death and Mind Blast weave in. Flash Heal is emergencies only (6.9/min). Watch: the raid timeline — Atonement must be out before damage hits or your Smites heal nothing; Penance charges and proc windows." },
    },
    mplus={
      n=8, dur=1755,
      core={ {47540,8.4},{585,7.8},{1253593,4.9},{17,4.0},{186263,4.0},{8092,2.8},{589,2.0},{194509,1.8},{32379,1.1},{586,1.0},{10060,0.9},{121536,0.7},{527,0.5},{472433,0.4} }, -- Penance, Smite, Void Shield, Power Word: Shield, Shadow Mend, Mind Blast, Shadow Word: Pain, Power Word: Radiance, Shadow Word: Death, Fade, Power Infusion, Angelic Feather, Purify, Evangelism
      watch={ {41635,57.7},{390692,56.8},{390978,55.8},{1241715,54.4},{193065,47.0},{1229746,46.1},{1235193,44.5},{390787,39.7},{390677,38.9},{1253593,34.3} }, -- Prayer of Mending, Borrowed Time, Twist of Fate, Might of the Void, Protective Light, Arcanoweave Insight, Holy Ray, Weal and Woe, Inspiration, Void Shield
      coach={ cn="怎么打：小怪阶段轻量维护——坦克挂盾、自己输出（惩击/苦修），大伤害前才完整铺救赎。暗影治愈 点名补。暗言术：灭在打断/补刀两用。盯什么：哪些伤害需要提前铺（看怪的读条和狂暴技能）；命运扭曲 触发期间多打两下，增伤不白给。", en="How to play: Light maintenance on trash — shield the tank, deal damage with Smite and Penance, saving full Atonement ramps for big hits. Shadow Mend for spot healing; Shadow Word: Death doubles for executes. Watch: which incoming abilities need a pre-ramp (read enemy cast bars and enrage timers); swing harder during Twist of Fate windows — free damage." },
    },
  },
  ["PRIEST/HOLY"] = {
    specID=257,
    raid={
      n=5, dur=415, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Groovi", server="Thrall", region="US", seq={14914,88625,33076,585,10060,10060,2050,585,33076,585,585,585} },
        { player="凌乱丶华丽", server="伊森利恩", region="CN", seq={585,14914,585,33076,33076,2050,585,585,2050,585,585,10060} },
        { player="Doting", server="Bleeding Hollow", region="US", seq={33076,10060,10060,1291894,64844,64843,64844,64844,64844,64844,33076,14914} },
      },
      core={ {1262763,13.2},{2061,9.9},{2050,8.5},{33076,7.2},{586,1.5},{121536,1.5},{14914,1.3},{585,1.0},{10060,1.0},{527,0.8},{200183,0.6},{88625,0.6},{1291894,0.6},{64843,0.4} }, -- Benediction, Flash Heal, Holy Word: Serenity, Prayer of Mending, Fade, Angelic Feather, Holy Fire, Smite, Power Infusion, Purify, Apotheosis, Holy Word: Chastise, Soulcoiler Ritual Vessel, Divine Hymn
      watch={ {193065,95.8},{1306118,90.6},{465,90.3},{139,77.1},{1229746,66.6},{1241715,60.0},{1262766,59.2},{1252487,48.5},{1305360,44.7},{382024,31.7} }, -- Protective Light, Renewed Vigor, Devotion Aura, Renew, Arcanoweave Insight, Might of the Void, Benediction, Focused Hunt, Soul Fang Alacrity, Earthliving Weapon
      coach={ cn="怎么打：治疗祷言是群刷主力（顶尖11.9次/分），圣言术：静秒单点（8次/分），愈合祷言丢 CD 让它自己跳（4.6次/分）。神圣词语的逻辑贯穿全程：祷言降静的 CD，互相喂。没人掉血就惩击（4.6次/分）。能量灌注给自己或爆发位。盯什么：圣言术的 CD 缩减循环别停；神圣身影（覆盖92.2%）的窗口，大轴对齐它。", en="How to play: Prayer of Healing is your group heal (top players: 11.9/min), Holy Word: Serenity nukes single targets (8/min), Prayer of Mending tossed on cooldown to bounce on its own (4.6/min). Holy Word logic runs everything: prayers reduce Serenity's cooldown, feeding each other. Nobody hurt? Smite (4.6/min). Power Infusion to yourself or a burst player. Watch: keep the Holy Word cooldown-reduction loop spinning; Divine Image windows (92.2% uptime), align big moments with it." },
    },
    mplus={
      n=8, dur=1797,
      core={ {33076,8.7},{1262763,7.9},{14914,6.8},{585,4.9},{2061,4.8},{2050,4.6},{88625,2.5},{132157,1.4},{586,1.2},{121536,1.0},{10060,0.9},{527,0.5},{1291894,0.5},{19236,0.4} }, -- Prayer of Mending, Benediction, Holy Fire, Smite, Flash Heal, Holy Word: Serenity, Holy Word: Chastise, Holy Nova, Fade, Angelic Feather, Power Infusion, Purify, Soulcoiler Ritual Vessel, Desperate Prayer
      watch={ {1306118,95.4},{193065,79.2},{139,78.0},{1262766,62.8},{41635,60.6},{1229746,54.7},{1241715,54.0},{390978,42.7},{372617,27.5},{390677,27.1} }, -- Renewed Vigor, Protective Light, Renew, Benediction, Prayer of Mending, Arcanoweave Insight, Might of the Void, Twist of Fate, Empyreal Blaze, Inspiration
      coach={ cn="怎么打：能打就打——神圣之火、惩击、圣言术：罚都参与输出，神圣新星在怪堆里放。治疗靠快速治疗点名加圣言术：静救急，恢复提前挂给坦克。盯什么：坦克身上的恢复别掉（79%覆盖，是常驻工具不是备选）；自己输出和治疗的切换时机——打着打着别忘了看血条。", en="How to play: Fight when you can — Holy Fire, Smite and Chastise all contribute, Holy Nova inside packs. Heal with Flash Heal spots and Holy Word: Serenity saves, keeping Renew rolling on the tank ahead of damage. Watch: Renew on the tank (79% uptime — it's a standard tool, not optional); your DPS-to-healing switch timing — don't get lost in the damage and miss a dropping bar." },
    },
  },
  ["PRIEST/SHADOW"] = {
    specID=258,
    raid={
      n=5, dur=419, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Oblivionis", server="伊瑟拉", region="CN", seq={589,1227280,341263,341263,120644,589,1242173,228260,341263,10060,1250533,10060} },
        { player="Liasia", server="Illidan", region="US", seq={228260,1227280,341263,341263,589,589,1227280,341263,341263,341263,120644,15286} },
        { player="Salmer", server="Stormrage", region="US", seq={228260,1227280,341263,589,341263,1236616,10060,1293316,15286,10060,589,1227280} },
      },
      core={ {335467,8.7},{15407,7.7},{1242173,6.8},{8092,6.3},{1227280,5.1},{589,4.1},{391403,4.0},{32379,1.3},{586,1.3},{10060,1.0},{120644,1.0},{2061,0.7},{228260,0.6},{15286,0.6} }, -- Shadow Word: Madness, Mind Flay, Void Volley, Mind Blast, Tentacle Slam, Shadow Word: Pain, Mind Flay: Insanity, Shadow Word: Death, Fade, Power Infusion, Halo, Flash Heal, Voidform, Vampiric Embrace
      watch={ {1287772,86.9},{373213,86.5},{373277,76.7},{391092,75.6},{372014,73.1},{232698,71.1},{393919,67.8},{139,63.8},{1297663,59.0},{1229746,58.7} }, -- Rune of Critical Power, Insidious Ire, Thing from Beyond, Shattered Psyche, Visage, Shadowform, Screams of the Void, Renew, Halazzi's Rite, Arcanoweave Insight
      coach={ cn="怎么打：吸血鬼之触和暗言术：痛全程不掉（1.8和2次/分=只在快掉时补），心灵震爆按 CD（顶尖11.6次/分），暗言术：癫是高频消耗（10.3次/分），精神鞭笞填充（9.6次/分）。触须猛击转好就按（4.1次/分）。盯什么：两个 DoT 的剩余时间——掉了一切收益归零；暗影形态覆盖75.1%说明顶尖玩家几乎不离开形态。", en="How to play: Vampiric Touch and Shadow Word: Pain never drop (1.8 and 2/min = refresh only near expiry), Mind Blast on cooldown (top players: 11.6/min), Shadow Word: Madness is your high-frequency spender (10.3/min), Mind Flay fills (9.6/min). Tentacle Slam on refresh (4.1/min). Watch: both DoTs' remaining time — everything scales off them; Shadowform at 75.1% uptime means top players almost never leave it." },
    },
    mplus={
      n=8, dur=1775,
      core={ {335467,8.1},{1242173,6.1},{8092,5.7},{15407,5.4},{589,5.0},{1227280,4.6},{263165,1.7},{32379,1.5},{586,1.4},{17,0.9},{10060,0.8},{2061,0.6},{228260,0.5},{15286,0.4} }, -- Shadow Word: Madness, Void Volley, Mind Blast, Mind Flay, Shadow Word: Pain, Tentacle Slam, Void Torrent, Shadow Word: Death, Fade, Power Word: Shield, Power Infusion, Flash Heal, Voidform, Vampiric Embrace
      watch={ {1295057,89.3},{1287772,83.2},{232698,78.7},{373277,77.7},{393919,63.2},{390978,61.5},{1229746,60.7},{449887,59.6},{377066,50.0},{1307922,37.8} }, -- Tidal Insight, Rune of Critical Power, Shadowform, Thing from Beyond, Screams of the Void, Twist of Fate, Arcanoweave Insight, Voidheart, Mental Fortitude, Venomcursed Mastery
      coach={ cn="怎么打：进怪群先把暗言术：痛甩到每个目标（多目标 DOT 是大头），然后癫、心灵震爆、鞭笞照常转。虚空洪流对准怪群引导。渐隐术按节奏脱仇恨。盯什么：每个怪身上的痛是否都在；触发出的虚空实体——它在打输出，尽量让它存活满时长。", en="How to play: Open packs by flinging Shadow Word: Pain onto every target (multi-DoTting is the bulk), then run Madness, Mind Blast and Mind Flay as usual. Channel Void Torrent into the pack; Fade rhythmically for threat. Watch: Pain's presence on every mob; your Thing from Beyond void spawns — they're dealing damage, so let them live out their full duration." },
    },
  },
  ["ROGUE/ASSASSINATION"] = {
    specID=259,
    raid={
      n=5, dur=417, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="贯一", server="死亡之翼", region="CN", seq={36554,703,27576,1329,1943,27576,1329,27576,1329,1297761,32645,452538} },
        { player="Wéze", server="Stormreaver", region="EU", seq={36554,703,27576,1329,1943,703,27576,1329,27576,1329,32645,452538} },
        { player="Lolaè", server="Ysondre", region="EU", seq={703,1295132,27576,1329,1943,27576,1329,27576,1329,32645,383781,360194} },
      },
      core={ {1329,19.1},{32645,10.4},{51723,5.3},{703,3.3},{1943,2.4},{1247227,1.6},{385627,1.0},{36554,0.7},{360194,0.6},{1966,0.6},{1856,0.6},{2983,0.4} }, -- Mutilate, Envenom, Fan of Knives, Garrote, Rupture, Crimson Tempest, Kingsbane, Shadowstep, Deathmark, Feint, Vanish, Sprint
      watch={ {1287772,83.2},{32645,75.9},{1264297,71.2},{1229746,63.9},{1297663,57.3},{1249093,56.1},{452923,51.1},{452917,50.0},{1307927,37.5},{1248971,33.1} }, -- Rune of Critical Power, Envenom, Cold Blood, Arcanoweave Insight, Halazzi's Rite, Fatebound Coin Flips, Fatebound Coin (Heads), Fatebound Coin (Tails), Venomcursed Haste, Lucky Coin
      coach={ cn="怎么打：毁伤攒连击点（顶尖21次/分），毒伤满星泄（16.6次/分，自身增益覆盖94.6%=几乎常驻），锁喉和割裂两个流血全程保持（3和2.3次/分=只补不抢）。君王之灾和死亡印记按 CD 对齐。盯什么：毒伤增益的剩余时间——它断了你的毒就软了；锁喉和割裂的倒计时，在潜伏窗口里刷出强化版。", en="How to play: Mutilate builds combo points (top players: 21/min), Envenom dumps at full points (16.6/min, with 94.6% buff uptime = nearly permanent), and Garrote plus Rupture stay up all fight (3 and 2.3/min = refresh, don't clip). Kingsbane and Deathmark aligned on cooldown. Watch: Envenom's buff timer — if it drops your poisons go soft; Garrote and Rupture countdowns, refreshing empowered versions from stealth windows." },
    },
    mplus={
      n=8, dur=1723,
      core={ {32645,12.2},{51723,10.3},{1329,6.6},{1247227,6.2},{703,2.7},{1943,2.2},{1966,1.7},{1298826,1.0},{385627,0.9},{36554,0.7},{57934,0.6},{2983,0.5},{383781,0.5},{185311,0.5} }, -- Envenom, Fan of Knives, Mutilate, Crimson Tempest, Garrote, Rupture, Feint, Thistle Tea, Kingsbane, Shadowstep, Tricks of the Trade, Sprint, Algeth'ar Puzzle, Crimson Vial
      watch={ {315496,97.4},{394080,88.9},{32645,74.6},{1248775,67.0},{1264297,63.7},{1229746,54.0},{457115,47.2},{457280,34.4},{1287665,24.4},{457273,20.9} }, -- Slice and Dice, Scent of Blood, Envenom, Unshakeable Drive, Cold Blood, Arcanoweave Insight, Momentum of Despair, Darkest Night, Rune of Lingering, Lingering Darkness
      coach={ cn="怎么打：群怪改刀扇攒星，终结技用猩红风暴铺群体流血（怪能活 6 秒以上才值）；优先目标照旧毁伤+毒伤。佯攻按进循环里——AOE 伤害高的本子它就是你的血条。盯什么：猩红风暴的覆盖与怪群剩余血量的匹配；切割照旧全程维持。", en="How to play: Build with Fan of Knives on packs and finish with Crimson Tempest for group bleeds (worth it if mobs live 6+ seconds); priority targets still get Mutilate + Envenom. Weave Feint into the loop — in heavy-AoE dungeons it's your health bar. Watch: match Crimson Tempest coverage against pack lifetime; Slice and Dice stays permanent as ever." },
    },
  },
  ["ROGUE/OUTLAW"] = {
    specID=260,
    raid={
      n=4, dur=410, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="食尘剑怨念物", server="罗宁", region="CN", seq={315496,381989,1236616,193315,193315,193315,315341,185763,185763,185763,193315,51690} },
        { player="Loktark", server="Stormreaver", region="US", seq={13750,315496,1214909,193315,1297761,315341,185763,185763,185763,51690,381989,2098} },
        { player="Pasquale", server="Sargeras", region="US", seq={315496,1214909,193315,381989,1250557,193315,1236616,193315,315341,193315,51690,2098} },
      },
      core={ {185763,24.4},{193315,16.3},{315341,10.4},{2098,8.8},{441776,2.5},{13877,1.8},{51690,1.7},{13750,1.6},{1966,1.5},{1214909,1.4},{2983,1.1},{381989,0.7} }, -- Pistol Shot, Sinister Strike, Between the Eyes, Dispatch, Coup de Grace, Blade Flurry, Killing Spree, Adrenaline Rush, Feint, Roll the Bones, Sprint, Keep It Rolling
      watch={ {315341,94.8},{441326,93.4},{455144,93.4},{1265931,90.2},{1287772,87.5},{1259486,86.3},{441786,75.0},{1229746,65.8},{1214909,62.9},{382024,58.9} }, -- Between the Eyes, Flawless Form, Acrobatic Strikes, Palmed Bullets, Rune of Critical Power, Zero In, Escalating Blade, Arcanoweave Insight, Roll the Bones, Earthliving Weapon
      coach={ cn="怎么打：影袭产星（顶尖17.8次/分），机会触发的手枪射击优先打（30.9次/分=全场最高频，说明触发极多），斩击满星泄（10.1次/分），正中眉心按 CD 保持增益（覆盖97.2%）。刀锋冲刺和冲动转好就按。盯什么：正中眉心的增益剩余时间（97.2%是顶尖标准，等于从不断）；机会触发——亮了手枪射击免费且更疼。", en="How to play: Sinister Strike builds (top players: 17.8/min), Opportunity-procced Pistol Shots take priority (30.9/min — your busiest button, that's how often it procs), Dispatch dumps at full points (10.1/min), Between the Eyes on cooldown for its buff (97.2% uptime). Blade Rush and Adrenaline Rush on refresh. Watch: Between the Eyes' buff timer (97.2% is the top-player bar — it never drops); Opportunity procs — a lit Pistol Shot is free and hits harder." },
    },
    mplus={
      n=8, dur=1697,
      core={ {185763,19.0},{193315,12.6},{315341,10.2},{2098,9.5},{13877,4.7},{271877,4.2},{441776,2.4},{1966,2.0},{2983,1.9},{51690,1.6},{13750,1.6},{1214909,1.6},{195457,1.3},{381989,0.6} }, -- Pistol Shot, Sinister Strike, Between the Eyes, Dispatch, Blade Flurry, Blade Rush, Coup de Grace, Feint, Sprint, Killing Spree, Adrenaline Rush, Roll the Bones, Grappling Hook, Keep It Rolling
      watch={ {315341,92.7},{441326,88.4},{1265931,86.4},{1287772,84.8},{1259486,80.9},{207400,75.5},{13877,71.8},{441786,68.8},{462568,68.6},{382024,67.0} }, -- Between the Eyes, Flawless Form, Palmed Bullets, Rune of Critical Power, Zero In, Ancestral Vigor, Blade Flurry, Escalating Blade, Elemental Resistance, Earthliving Weapon
      coach={ cn="怎么打：2 个以上目标开剑刃乱舞（它把你的单体连击转成 AOE），其余手法不变。嫁祸丢给坦克配合拉怪。佯攻照常进循环。盯什么：剑刃乱舞的开关状态（切单体记得关注收益）；嫁祸诀窍 当常驻增益维护（顶尖玩家覆盖96.8%）。", en="How to play: Open Blade Flurry at 2+ targets (it converts your single-target combo into AoE); everything else stays the same. Tricks of the Trade to the tank on pulls, Feint woven in as usual. Watch: Blade Flurry's toggle state (mind its value when swapping to single-target); maintain Tricks like a permanent buff — top players hold it at 96.8%." },
    },
  },
  ["ROGUE/SUBTLETY"] = {
    specID=261,
    raid={
      n=5, dur=413, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Parse", server="Tichondrius", region="US", seq={185438,196819,1856,185438,1236616,196819,1297761,121471,185313,426591,280719,282449} },
        { player="Achilees", server="Draenor", region="EU", seq={185438,196819,1856,185438,196819,121471,1297761,185313,426591,280719,282449,185438} },
        { player="Cerok", server="Sanguino", region="EU", seq={185438,196819,1856,185438,196819,121471,185313,1297761,426591,280719,282449,282449} },
      },
      core={ {196819,19.2},{53,9.9},{185438,7.0},{197835,4.0},{319175,3.2},{185313,3.1},{1966,1.3},{426591,1.2},{121471,0.7},{1297761,0.7},{185311,0.5},{1293340,0.4},{2983,0.3},{1856,0.3} }, -- Eviscerate, Backstab, Shadowstrike, Shuriken Storm, Black Powder, Shadow Dance, Feint, Goremaw's Bite, Shadow Blades, Voracious Heart of Ula'tek, Crimson Vial, Mark for Death, Sprint, Vanish
      watch={ {1264521,91.2},{1287774,88.6},{1248775,82.1},{385960,74.2},{1229746,61.1},{385727,56.6},{1297663,54.5},{386237,44.4},{112942,44.3},{185422,43.9} }, -- Find Weakness, Rune of Burning Haste, Unshakeable Drive, Lingering Shadow, Arcanoweave Insight, Silent Storm, Halazzi's Rite, Fade to Nothing, Shadow Focus, Shadow Dance
      coach={ cn="怎么打：背刺产星（顶尖10.8次/分），暗影之舞窗口里换暗影打击（9.7次/分），刺骨满星泄（19.1次/分）。暗影之舞转好就进（3.3次/分），暗影之刃对齐爆发。盯什么：弱点识破（覆盖86.2%）——它几乎常驻说明顶尖玩家的舞和暗影打击衔接没有空档；暗影技巧的能量回馈（覆盖95.3%），星和能量都别溢出。", en="How to play: Backstab builds (top players: 10.8/min), Shadowstrike replaces it inside Shadow Dance windows (9.7/min), Eviscerate dumps at full combo points (19.1/min). Shadow Dance on refresh (3.3/min), Shadow Blades aligned with burst. Watch: Find Weakness (86.2% uptime) — near-permanent coverage means top players chain Dance and Shadowstrike with no gaps; Shadow Techniques energy feedback (95.3% uptime), never cap points or energy." },
    },
    mplus={
      n=8, dur=1742,
      core={ {319175,11.0},{197835,10.9},{196819,10.7},{53,3.6},{185438,3.1},{185313,2.8},{1966,2.3},{426591,1.1},{57934,0.7},{1297761,0.6},{121471,0.6},{36554,0.6},{1784,0.4},{2983,0.4} }, -- Black Powder, Shuriken Storm, Eviscerate, Backstab, Shadowstrike, Shadow Dance, Feint, Goremaw's Bite, Tricks of the Trade, Voracious Heart of Ula'tek, Shadow Blades, Shadowstep, Stealth, Sprint
      watch={ {1459,90.1},{1264521,89.5},{1248775,83.6},{1287771,80.3},{385960,70.7},{207400,68.8},{457115,67.1},{462568,61.7},{382024,61.4},{1287665,57.9} }, -- Arcane Intellect, Find Weakness, Unshakeable Drive, Rune of Masterful Cunning, Lingering Shadow, Ancestral Vigor, Momentum of Despair, Elemental Resistance, Earthliving Weapon, Rune of Lingering
      coach={ cn="怎么打：群怪用袖剑风暴攒星、黑火药终结；单体优先目标仍走刺骨。舞照常高频开，对齐怪群密度最高的时刻。佯攻常态化。盯什么：黑火药/刺骨按目标数切换；舞窗口里优先把星花完——窗口外的终结技亏一截。", en="How to play: Build with Shuriken Storm and finish with Black Powder on packs; priority singles still get Eviscerate. Keep opening Dance at high frequency, aligned with peak pack density. Feint stays routine. Watch: switch Black Powder/Eviscerate by target count; dump combo points inside Dance windows — finishers outside them lose real value." },
    },
  },
  ["SHAMAN/ELEMENTAL"] = {
    specID=262,
    raid={
      n=5, dur=415, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="今晚吃什么呢", server="铜龙军团", region="CN", seq={32182,114050,1293316,1236616,443454,51505,188196,51505,188196,188196,51505,188196} },
        { player="Moneyshaman", server="Tichondrius", region="US", seq={191634,188196,188196,79206,1236616,1293316,443454,114050,51505,117014,51505,117014} },
        { player="污橙萨", server="白银之手", region="CN", seq={443454,1293316,114050,51505,188196,51505,188196,51505,188196,51505,117014,188196} },
      },
      core={ {188196,13.3},{51505,12.6},{117014,6.9},{188443,5.4},{188389,3.6},{443454,1.8},{191634,1.3},{2645,0.7},{79206,0.7},{1293316,0.6},{114050,0.6},{192063,0.4} }, -- Lightning Bolt, Lava Burst, Elemental Blast, Chain Lightning, Flame Shock, Ancestral Swiftness, Stormkeeper, Ghost Wolf, Spiritwalker's Grace, Empowering Venom, Ascendance, Gust of Wind
      watch={ {1287772,89.3},{395152,86.8},{173183,81.8},{118522,81.5},{173184,81.1},{447244,66.8},{139,44.8},{1307922,43.5},{372014,43.3},{1229746,38.2} }, -- Rune of Critical Power, Ebon Might, Elemental Blast: Haste, Elemental Blast: Critical Strike, Elemental Blast: Mastery, Call of the Ancestors, Renew, Venomcursed Mastery, Visage, Arcanoweave Insight
      coach={ cn="怎么打：闪电箭是主填充（顶尖19.1次/分），熔岩爆裂吃烈焰震击的触发按（11.6次/分），烈焰震击全程不掉（2.5次/分=只补）。漩涡值喂元素冲击（6次/分），Tempest 触发了优先打（3.8次/分）。风暴守护者按 CD。盯什么：烈焰震击的剩余时间——熔岩爆裂的触发全靠它；漩涡值别溢出，元素冲击转好就泄。", en="How to play: Lightning Bolt is your filler (top players: 19.1/min), Lava Burst rides Flame Shock procs (11.6/min), and Flame Shock never drops (2.5/min = refresh only). Maelstrom feeds Elemental Blast (6/min); a procced Tempest takes priority (3.8/min). Stormkeeper on cooldown. Watch: Flame Shock's remaining time — every Lava Burst proc depends on it; never cap Maelstrom, dump Elemental Blast on refresh." },
    },
    mplus={
      n=8, dur=1759,
      core={ {188443,9.6},{51505,8.4},{188196,5.7},{61882,5.7},{470057,5.6},{117014,3.5},{443454,1.6},{191634,1.2},{2645,0.6},{114050,0.4},{1293316,0.4},{108271,0.3},{79206,0.3} }, -- Chain Lightning, Lava Burst, Lightning Bolt, Earthquake, Voltaic Blaze, Elemental Blast, Ancestral Swiftness, Stormkeeper, Ghost Wolf, Ascendance, Empowering Venom, Astral Shift, Spiritwalker's Grace
      watch={ {1287771,82.5},{447244,64.0},{173183,58.4},{118522,58.0},{173184,55.2},{1297663,54.3},{1229746,42.6},{157128,39.6},{1241866,38.6},{1307922,35.4} }, -- Rune of Masterful Cunning, Call of the Ancestors, Elemental Blast: Haste, Elemental Blast: Critical Strike, Elemental Blast: Mastery, Halazzi's Rite, Arcanoweave Insight, Saved by the Light, Glistening Radiance, Venomcursed Mastery
      coach={ cn="怎么打：群怪改闪电链读条，漩涡值喂地震术（丢在怪群脚下、覆盖移动路径），熔岩爆裂留给挂了 烈焰震击 的优先目标。土元素常驻召唤——它是你的第二条命。盯什么：地震术的落点是否罩住怪群；目标数 2-3 个以上切闪电链，回到单体切回闪电箭。", en="How to play: Swap to Chain Lightning on packs and feed Maelstrom into Earthquake (placed under the pack, covering their path); Lava Burst goes to Flame-Shocked priority targets. Keep Earth Elemental summoned — it's your second life. Watch: Earthquake placement actually covering the pack; switch to Chain Lightning at 2-3+ targets and back to Lightning Bolt on singles." },
    },
  },
  ["SHAMAN/ENHANCEMENT"] = {
    specID=263,
    raid={
      n=5, dur=417, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Totemtickler", server="Ravencrest", region="EU", seq={470057,58875,187874,1297761,114051,452201,115356,469270,452201,115356,469270,188196} },
        { player="Drtomty", server="Blackhand", region="EU", seq={383781,470057,196884,196881,187874,1236616,114051,452201,115356,469270,188196,115356} },
        { player="Plumbous", server="Mal'Ganis", region="US", seq={188443,470057,196884,1293316,114051,196881,1236616,58875,469270,452201,115356,188196} },
      },
      core={ {17364,15.8},{188196,10.7},{469270,10.4},{187874,9.1},{115356,6.4},{452201,5.3},{470057,4.9},{188443,4.2},{60103,1.6},{2645,0.7},{114051,0.6},{58875,0.6},{8004,0.6} }, -- Stormstrike, Lightning Bolt, Doom Winds, Crash Lightning, Windstrike, Tempest, Voltaic Blaze, Chain Lightning, Lava Lash, Ghost Wolf, Ascendance, Spirit Walk, Healing Surge
      watch={ {382889,96.0},{1252415,94.2},{344179,91.2},{1287774,87.6},{454394,82.7},{1229746,76.7},{1295582,76.6},{1299991,68.2},{1241762,55.8},{1307922,40.8} }, -- Flurry, Crash Lightning, Maelstrom Weapon, Rune of Burning Haste, Unlimited Power, Arcanoweave Insight, Focus of Ula'tek, Short Circuit, Frenzied Focus, Venomcursed Mastery
      coach={ cn="怎么打：风暴打击和熔岩猛击转好就按（顶尖14.9和17次/分），毁灭闪电保持增益（7.2次/分），攒满漩涡武器层数后闪电箭泄（10.9次/分，覆盖86.8%=层数几乎不空）。末日之风和 Sundering 高频进轴（11和15.8次/分），Primordial Storm 窗口全力倾泻。盯什么：漩涡武器层数——满了立刻泄别浪费；热手触发（覆盖67.1%）让熔岩猛击免费且更疼。", en="How to play: Stormstrike and Lava Lash on refresh (top players: 14.9 and 17/min), Crash Lightning keeps its buff up (7.2/min), and Lightning Bolt dumps at max Maelstrom Weapon stacks (10.9/min, 86.8% uptime = stacks are never empty). Doom Winds and Sundering cycle in hard (11 and 15.8/min); pour everything into Primordial Storm windows. Watch: Maelstrom Weapon stacks — dump immediately at cap; Hot Hand procs (67.1% uptime) make Lava Lash free and harder-hitting." },
    },
    mplus={
      n=8, dur=1744,
      core={ {17364,14.8},{469270,9.5},{188443,9.2},{187874,8.7},{115356,4.6},{188196,4.5},{470057,4.4},{452201,4.4},{60103,1.6},{2645,0.5},{1293316,0.5},{114051,0.5},{108271,0.3} }, -- Stormstrike, Doom Winds, Chain Lightning, Crash Lightning, Windstrike, Lightning Bolt, Voltaic Blaze, Tempest, Lava Lash, Ghost Wolf, Empowering Venom, Ascendance, Astral Shift
      watch={ {410681,92.6},{382889,90.5},{1252415,87.9},{344179,86.9},{454394,76.1},{1229746,58.2},{1299991,55.8},{384451,32.6},{470466,31.3},{454025,31.1} }, -- Overflowing Maelstrom, Flurry, Crash Lightning, Maelstrom Weapon, Unlimited Power, Arcanoweave Insight, Short Circuit, Lightning Strikes, Stormblast, Electroshock
      coach={ cn="怎么打：先按毁灭闪电挂上 AOE 增益（没它你的群伤不成立），漩涡层改喂闪电链，风暴打击照常主键，风切插入。盯什么：毁灭闪电增益（84.7%覆盖）掉了先补它再继续；漩涡层在多目标下产得飞快——花的速度必须跟上，卡手就是亏。", en="How to play: Press Crash Lightning first to apply the AoE buff (without it your cleave doesn't function), route Maelstrom stacks into Chain Lightning, keep Stormstrike as the main button, weave Windstrike. Watch: the Crash Lightning buff (84.7% uptime) — if it drops, restore it before anything else; multi-target Maelstrom generation is torrential, so spend as fast as it builds." },
    },
  },
  ["SHAMAN/RESTORATION"] = {
    specID=264,
    raid={
      n=5, dur=414, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Jetskisham", server="Ravencrest", region="EU", seq={444995,378081,1064,61295,61295,77472,51505,188389,470411,51505,188196,61295} },
        { player="Meowtide", server="Sylvanas", region="EU", seq={51505,188389,470411,5394,1064,61295,444995,77472,51505,61295,51505,77472} },
        { player="Weakheals", server="Blackhand", region="EU", seq={61295,5394,1064,1291894,61295,77472,77472,1267068,1064,61295,77472,77472} },
      },
      core={ {1064,18.0},{61295,11.7},{77472,5.1},{5394,3.6},{444995,2.2},{1267068,1.8},{108287,1.7},{51505,1.5},{188389,1.2},{378081,1.0},{79206,0.7},{77130,0.6},{2645,0.5},{188196,0.4} }, -- Chain Heal, Riptide, Healing Wave, Healing Stream Totem, Surging Totem, Stormstream Totem, Totemic Projection, Lava Burst, Flame Shock, Nature's Swiftness, Spiritwalker's Grace, Purify Spirit, Ghost Wolf, Lightning Bolt
      watch={ {456369,93.5},{1307888,92.1},{1287772,85.1},{1229746,76.4},{382024,75.9},{53390,72.0},{462568,53.8},{470077,50.3},{1241715,50.1},{453407,32.9} }, -- Amplification Core, Healing Rain, Rune of Critical Power, Arcanoweave Insight, Earthliving Weapon, Tidal Waves, Elemental Resistance, Coalescing Water, Might of the Void, Whirling Water
      coach={ cn="怎么打：激流按 CD 铺（顶尖10.8次/分），治疗链是群刷主力（19次/分，吃激流的潮汐涌动增益），生命释放强化下一个技能（2.9次/分）。治疗之泉图腾和涌动图腾转好就放。治疗间隙打熔岩爆裂和烈焰震击（2.5和2.1次/分）。盯什么：潮汐涌动（覆盖81.5%）——治疗链要吃着它读；图腾的落点和剩余时间，大轴前提前摆。", en="How to play: Riptide on cooldown (top players: 10.8/min), Chain Heal is your group-heal workhorse (19/min, riding Riptide's Tidal Waves buff), Unleash Life empowers the next spell (2.9/min). Healing Stream and Surging Totems on refresh. Fill healing gaps with Lava Burst and Flame Shock (2.5 and 2.1/min). Watch: Tidal Waves (81.5% uptime) — Chain Heal wants to be cast under it; totem placement and remaining duration, pre-drop before big damage." },
    },
    mplus={
      n=8, dur=1836,
      core={ {61295,7.5},{1064,7.1},{77472,4.8},{5394,2.9},{188443,2.7},{444995,2.1},{51505,2.1},{73685,1.9},{188389,1.7},{108287,1.4},{1267068,1.2},{188196,0.8},{378081,0.8},{2645,0.7} }, -- Riptide, Chain Heal, Healing Wave, Healing Stream Totem, Chain Lightning, Surging Totem, Lava Burst, Unleash Life, Flame Shock, Totemic Projection, Stormstream Totem, Lightning Bolt, Nature's Swiftness, Ghost Wolf
      watch={ {456369,85.8},{1307888,85.6},{1287772,82.0},{207400,74.4},{53390,73.5},{462568,68.9},{382024,67.0},{1229746,63.7},{1241715,54.2},{470077,45.2} }, -- Amplification Core, Healing Rain, Rune of Critical Power, Ancestral Vigor, Tidal Waves, Elemental Resistance, Earthliving Weapon, Arcanoweave Insight, Might of the Void, Coalescing Water
      coach={ cn="怎么打：点名治疗为主——激流先手、治疗波跟上，治疗链留给群伤瞬间。没人掉血就打熔岩爆裂和 烈焰震击 参与输出。治疗之泉、涌动图腾在拉怪前预置。盯什么：坦克身上保持激流常驻；图腾的覆盖范围跟上队伍走位，落后了及时挪。", en="How to play: Spot healing leads — Riptide first, Healing Wave follows, Chain Heal saved for group damage moments. When bars are stable, contribute Lava Burst and Flame Shock. Pre-place Healing Stream and Surging Totem before pulls. Watch: keep Riptide rolling on the tank; make sure totem range follows the group's movement — relocate them when left behind." },
    },
  },
  ["WARLOCK/AFFLICTION"] = {
    specID=265,
    mplus={
      n=8, dur=1717,
      core={ {686,10.5},{27243,10.2},{980,8.3},{1259790,6.1},{48181,3.1},{1257052,1.2},{108416,0.8},{119910,0.6},{1293316,0.5},{172,0.4},{205180,0.4},{6789,0.3},{111400,0.3} }, -- Shadow Bolt, Seed of Corruption, Agony, Unstable Affliction, Haunt, Dark Harvest, Dark Pact, Spell Lock, Empowering Venom, Corruption, Summon Darkglare, Mortal Coil, Burning Rush
      watch={ {108366,83.8},{1305774,80.6},{1287772,79.2},{1229746,64.3},{48018,55.6},{1241715,54.1},{449793,38.6},{264571,35.0},{1295900,16.4},{205180,16.3} }, -- Soul Leech, Unstable Empowerment, Rune of Critical Power, Arcanoweave Insight, Demonic Circle, Might of the Void, Succulent Soul, Nightfall, Hasty Ritual, Summon Darkglare
      coach={ cn="怎么打：进怪群腐蚀之种先手（一发铺全场），痛楚和无常往主要目标上挂，吸取灵魂照常引导。黑暗契约按节奏保命。盯什么：种子的引爆目标选血厚的（保证炸得出来）；灵魂榨取护盾（84.7%覆盖）就是你的被动血条——DOT 不停它就不停。", en="How to play: Lead packs with Seed of Corruption (one cast blankets everything), hang Agony and UA on primary targets, channel Drain Soul as usual. Dark Pact rhythmically for survival. Watch: detonate Seeds off high-health targets (so they actually pop); your Soul Leech shield (84.7% uptime) is a passive health bar — it keeps flowing as long as your DoTs do." },
    },
  },
  ["WARLOCK/DEMONOLOGY"] = {
    specID=266,
    mplus={
      n=8, dur=1791,
      core={ {105174,12.7},{264178,9.3},{686,8.6},{196277,2.9},{104316,2.6},{434635,1.4},{265187,0.8},{108416,0.7},{111400,0.6},{1276452,0.4},{1293316,0.4},{385899,0.3} }, -- Hand of Gul'dan, Demonbolt, Shadow Bolt, Implosion, Call Dreadstalkers, Ruination, Summon Demonic Tyrant, Dark Pact, Burning Rush, Grimoire: Imp Lord, Empowering Venom, Soulburn
      watch={ {1295057,90.5},{1276623,86.0},{108366,84.5},{1287772,78.0},{1269879,67.2},{48018,65.9},{1269643,58.5},{1297663,56.6},{264173,55.2},{1229746,42.0} }, -- Tidal Insight, Singe Magic, Soul Leech, Rune of Critical Power, Mind's Eyes, Demonic Circle, Demonic Oculi, Halazzi's Rite, Demonic Core, Arcanoweave Insight
      coach={ cn="怎么打：手法同团本，多一个决策：怪群快死时内爆把小鬼炸成 AOE，怪群能活就攒着等暴君。古尔丹之手照常铺场。盯什么：怪群剩余存活时间（内爆/留暴君的分水岭）；小鬼的能量在衰减——犹豫太久它们自己就消失了，该炸就炸。", en="How to play: Same hands as raid, plus one decision: Implode your imps into AoE when the pack is about to die, or hold them for Tyrant if it'll live. Hand of Gul'dan keeps seeding as usual. Watch: pack lifetime is the Implosion-versus-Tyrant dividing line; imp energy decays — hesitate too long and they expire on their own, so detonate when the call is made." },
    },
  },
  ["WARLOCK/DESTRUCTION"] = {
    specID=267,
    raid={
      n=5, dur=417, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Eonjr", server="Frostmourne", region="US", seq={6353,1122,442726,116858,17962,116858,17962,116858,17877,116858,29722,17962} },
        { player="twidongi", server="ajeusyara", region="KR", seq={6353,1122,442726,1236616,116858,17962,116858,17962,116858,17877,116858,29722} },
        { player="Ayayawl", server="Blackhand", region="EU", seq={6353,17962,1122,442726,1293316,80240,116858,17962,116858,1236616,17962,116858} },
      },
      core={ {29722,11.5},{116858,11.2},{17877,10.5},{17962,8.4},{445468,3.6},{80240,1.7},{6353,1.2},{442726,1.0},{108416,0.9},{1122,0.7},{111400,0.7} }, -- Incinerate, Chaos Bolt, Shadowburn, Conflagrate, Wither, Havoc, Soul Fire, Malevolence, Dark Pact, Summon Infernal, Burning Rush
      watch={ {1265939,90.1},{1287772,86.7},{139,80.0},{108366,66.6},{372014,63.4},{442726,59.3},{382024,52.9},{1229746,52.5},{462568,46.6},{117828,42.4} }, -- Vision of Nihilam, Rune of Critical Power, Renew, Soul Leech, Visage, Malevolence, Earthliving Weapon, Arcanoweave Insight, Elemental Resistance, Backdraft
      coach={ cn="怎么打：烧尽攒碎片（顶尖16次/分），混乱之箭满碎片泄（10.8次/分），燃烧按 CD 给暴击触发（8.4次/分），暗影灼烧高频插缝（7.8次/分）。灵魂之火和 Malevolence 按 CD，召唤地狱火对齐爆发轴。盯什么：灵魂碎片别溢出——燃烧转好前把碎片花掉；混乱之箭尽量在增益窗口里打出去。", en="How to play: Incinerate builds shards (top players: 16/min), Chaos Bolt dumps at full shards (10.8/min), Conflagrate on cooldown for crit procs (8.4/min), Shadowburn weaves in often (7.8/min). Soul Fire and Malevolence on cooldown; Summon Infernal aligns with burst. Watch: never cap soul shards — spend before Conflagrate refreshes; land Chaos Bolts inside buff windows whenever possible." },
    },
    mplus={
      n=8, dur=1646,
      core={ {29722,9.4},{17877,8.8},{1244918,8.6},{17962,7.0},{116858,5.0},{5740,4.7},{348,2.0},{152108,1.3},{434635,1.2},{119910,0.9},{111400,0.8},{108416,0.7},{1250533,0.6},{1122,0.6} }, -- Incinerate, Shadowburn, Lake of Fire, Conflagrate, Chaos Bolt, Rain of Fire, Immolate, Cataclysm, Ruination, Spell Lock, Burning Rush, Dark Pact, Freightrunner's Flask, Summon Infernal
      watch={ {465,95.4},{108366,83.1},{1265939,80.7},{1287772,79.5},{1269643,79.0},{48018,62.6},{1269879,60.2},{1229746,43.3},{117828,42.7},{1307922,34.4} }, -- Devotion Aura, Soul Leech, Vision of Nihilam, Rune of Critical Power, Demonic Oculi, Demonic Circle, Mind's Eyes, Arcanoweave Insight, Backdraft, Venomcursed Mastery
      coach={ cn="怎么打：群怪灰烬改喂火焰之雨（怪群脚下连铺），大灾变一发把献祭铺满全场，混乱之箭只打必须死的优先目标。火焰之湖 维持。盯什么：火焰之雨的覆盖与怪群走位；3 个以上目标雨更值，回到单体马上切回混乱之箭——这条切换线打熟它。", en="How to play: On packs, pour embers into Rain of Fire (layered under the pack) and spread Immolate everywhere with one Cataclysm; Chaos Bolt only hits priority targets that must die. Keep Lake of Fire maintained. Watch: Rain of Fire's coverage versus pack movement; Rain wins at 3+ targets and Chaos Bolt takes over on singles — drill that switching line until it's automatic." },
    },
  },
  ["WARRIOR/ARMS"] = {
    specID=71,
    raid={
      n=5, dur=410, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Khawarr", server="Zul'jin", region="US", seq={384110,100,126664,845,107574,167105,1297761,281000,446035,12294,107570,12294} },
        { player="Jrbaj", server="Draenor", region="EU", seq={100,845,126664,167105,107574,1297761,281000,446035,12294,107570,12294,12294} },
        { player="Zitee", server="Kazzak", region="EU", seq={100,845,126664,167105,107574,1297761,281000,446035,12294,107570,12294,12294} },
      },
      core={ {12294,17.2},{281000,12.6},{7384,6.5},{1269383,6.2},{845,3.5},{1464,2.4},{167105,1.9},{446035,1.8},{107570,1.3},{107574,1.0},{260708,0.9},{23920,0.8},{100,0.7},{1297761,0.6} }, -- Mortal Strike, Execute, Overpower, Heroic Strike, Cleave, Slam, Colossus Smash, Bladestorm, Storm Bolt, Avatar, Sweeping Strikes, Spell Reflection, Charge, Voracious Heart of Ula'tek
      watch={ {386164,96.7},{1269394,95.6},{445584,95.0},{260708,93.9},{1287774,86.7},{445606,80.0},{392778,77.3},{1292058,74.9},{1300670,72.7},{1229746,56.4} }, -- Battle Stance, Master of Warfare, Executioner, Sweeping Strikes, Rune of Burning Haste, Imminent Demise, Wild Strikes, Heroic Might, Winding Up, Arcanoweave Insight
      coach={ cn="怎么打：致死打击 CD 好了必按（顶尖17.5次/分），压制喂它增伤（11.1次/分），斩杀段斩杀优先（11.7次/分=斩杀期占比很大）。巨人打击按 CD 开窗口（2.3次/分），窗口内把致死和斩杀全压进去。撕裂别掉（1.6次/分）。怒气多了英勇打击泄。盯什么：巨人打击的破甲窗口——你的爆发全在里面；处刑人（覆盖94%）说明斩杀段的节奏就是一切。", en="How to play: Mortal Strike on cooldown always (top players: 17.5/min), Overpower feeds it (11.1/min), Execute takes over in execute range (11.7/min — that phase is huge). Colossus Smash opens windows on cooldown (2.3/min); pack Mortal Strikes and Executes inside. Keep Rend up (1.6/min). Dump excess rage with Heroic Strike. Watch: the Colossus Smash armor-break window — all your burst lives there; Executioner at 94% uptime says execute-phase rhythm is everything." },
    },
    mplus={
      n=8, dur=1763,
      core={ {12294,14.2},{281000,12.0},{845,8.8},{7384,7.6},{1269383,2.2},{446035,1.8},{167105,1.6},{260708,1.5},{1464,1.0},{23920,0.9},{107574,0.8},{100,0.7},{107570,0.5} }, -- Mortal Strike, Execute, Cleave, Overpower, Heroic Strike, Bladestorm, Colossus Smash, Sweeping Strikes, Slam, Spell Reflection, Avatar, Charge, Storm Bolt
      watch={ {465,97.4},{1264426,97.2},{1269394,92.3},{1459,91.5},{445584,88.6},{260708,85.2},{1287774,82.9},{445606,76.2},{1292058,74.6},{392778,70.4} }, -- Devotion Aura, Void-Touched, Master of Warfare, Arcane Intellect, Executioner, Sweeping Strikes, Rune of Burning Haste, Imminent Demise, Heroic Might, Wild Strikes
      coach={ cn="怎么打：进怪群第一件事按横扫挂增益——挂上后你的致死打击和压制全变成范围技；增益快掉就续，AOE 期间绝不裸打。撕裂铺给会活久的目标。崩摧 CD 好了对怪群放。盯什么：横扫增益的剩余时间（它是 AOE 的开关）；怪群血量决定撕裂值不值得铺。", en="How to play: First button into any pack is Sweeping Strikes for its buff — once applied, your Mortal Strikes and Overpowers all cleave; refresh it before it falls and never swing without it during AoE. Rend goes on targets that will live. Demolish on cooldown into the pack. Watch: the Sweeping Strikes buff's remaining duration (it's the AoE switch); pack health decides whether Rend is worth spreading." },
    },
  },
  ["WARRIOR/FURY"] = {
    specID=72,
    mplus={
      n=8, dur=1835,
      core={ {184367,20.6},{190411,8.0},{85288,7.7},{5308,6.8},{335097,6.4},{335096,4.8},{23881,3.1},{1719,1.2},{385060,1.2},{446035,1.2},{23920,1.0},{100,0.7},{184364,0.3} }, -- Rampage, Whirlwind, Raging Blow, Execute, Crushing Blow, Bloodbath, Bloodthirst, Recklessness, Odyn's Fury, Bladestorm, Spell Reflection, Charge, Enraged Regeneration
      watch={ {335082,90.4},{1269349,89.0},{445584,88.2},{184362,86.9},{445606,80.0},{1287771,79.5},{392778,78.0},{383873,59.0},{85739,55.8},{1241759,55.6} }, -- Frenzy, Berserk, Executioner, Enrage, Imminent Demise, Rune of Masterful Cunning, Wild Strikes, Hack and Slash, Whirlwind, Genius Insight
      coach={ cn="怎么打：先按旋风斩挂顺劈增益（之后两次单体技能自动溅射），然后照常暴怒/嗜血/斩杀——记住每两次主力技能就要补一次旋风斩。鲁莽对齐怪群开。盯什么：旋风斩增益的剩余次数；激怒覆盖纪律不变（91.3%）——AOE 打得再欢，激怒断了都是白打。", en="How to play: Press Whirlwind first for its cleave buff (your next two single-target abilities splash automatically), then run Rampage/Bloodthirst/Execute as usual — remembering to re-Whirlwind every two main attacks. Recklessness aligned with packs. Watch: the Whirlwind buff's remaining charges; Enrage discipline is unchanged (91.3%) — however busy the AoE gets, swinging without Enrage is wasted effort." },
    },
  },
  ["WARRIOR/PROTECTION"] = {
    specID=73,
    raid={
      n=5, dur=415, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Chuckles", server="Mal'Ganis", region="US", seq={384110,57755,1160,1236616,107574,435222,2565,385952,23922,2565,23920,435222} },
        { player="Cranksmith", server="Mal'Ganis", region="US", seq={385954,1160,435222,107574,1236616,435222,2565,23922,435222,2565,23922,435222} },
        { player="Kelac", server="Shattered Halls", region="EU", seq={385954,6343,23922,190456,6572,107574,435222,1293316,1236616,1160,2565,435222} },
      },
      core={ {23922,15.9},{190456,15.8},{6572,8.1},{6343,7.5},{2565,5.2},{23920,2.2},{1160,1.9},{107574,1.2},{163201,1.0},{871,0.7},{202168,0.7},{100,0.4},{52174,0.4},{57755,0.4} }, -- Shield Slam, Ignore Pain, Revenge, Thunder Clap, Shield Block, Spell Reflection, Demoralizing Shout, Avatar, Execute, Shield Wall, Impending Victory, Charge, Heroic Leap, Heroic Throw
      watch={ {23922,94.8},{132404,90.2},{1287772,88.6},{392778,75.1},{1229746,70.6},{107574,59.5},{1278009,57.2},{438591,55.7},{190456,53.7},{224324,37.6} }, -- Shield Slam, Shield Block, Rune of Critical Power, Wild Strikes, Arcanoweave Insight, Avatar, Phalanx, Keep Your Feet on the Ground, Ignore Pain, Shield Slam!
      coach={ cn="怎么打：盾牌猛击 CD 好了必按（顶尖21.1次/分，输出和怒气都靠它），怒气优先喂无视苦痛保持吸收盾常驻（覆盖92.9%）；物理承伤期盾牌格挡必须在线（覆盖92.5%）——两层充能轮着用别同时烧光。复仇触发亮了免费按（10.1次/分）。挫志怒吼和天神下凡按 CD。盯什么：盾牌格挡的剩余时间和充能数；无视苦痛的吸收量余量。", en="How to play: Shield Slam on cooldown always (top players: 21.1/min — it drives both damage and rage), rage fed into Ignore Pain to keep the absorb shield standing (92.9% uptime); Shield Block must be active through physical damage (92.5% uptime) — cycle its two charges rather than burning both. Press free Revenge procs (10.1/min). Demoralizing Shout and Avatar on cooldown. Watch: Shield Block's duration and charges; how much Ignore Pain absorb remains." },
    },
    mplus={
      n=8, dur=1755,
      core={ {190456,16.2},{23922,16.2},{6343,10.8},{6572,9.2},{2565,5.5},{1160,2.1},{107574,1.1},{23920,1.0},{100,0.7},{57755,0.6},{46968,0.5},{202168,0.5},{163201,0.5},{871,0.5} }, -- Ignore Pain, Shield Slam, Thunder Clap, Revenge, Shield Block, Demoralizing Shout, Avatar, Spell Reflection, Charge, Heroic Throw, Shockwave, Impending Victory, Execute, Shield Wall
      watch={ {386486,97.4},{202602,95.8},{386029,94.5},{386208,91.9},{23922,89.7},{132404,88.2},{207400,80.6},{190456,75.9},{462568,75.1},{382024,71.0} }, -- Seeing Red, Into the Fray, Brace For Impact, Defensive Stance, Shield Slam, Shield Block, Ancestral Vigor, Ignore Pain, Elemental Resistance, Earthliving Weapon
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
