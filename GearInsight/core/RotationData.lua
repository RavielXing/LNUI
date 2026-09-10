-- 自动生成(generate_rotation_lua.py ← build_rotation_teaching.py)，勿手改。
-- WCL 顶尖玩家循环参考：raid=团本M1 top5；mplus=冲分各本top2聚合。
-- core={ {spellID,每分钟次数}.. } watch={ {spellID,uptime%}.. } opener=前3名真实起手。
GearInsightRotation = {
  ["DEATHKNIGHT/BLOOD"] = {
    specID=250,
    raid={
      n=5, dur=411, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Relixdk", server="Blackrock", region="EU", seq={195292,1297761,46585,49028,1236616,433895,433895,433895,433895,49998,49998,50842,433895,433895,433895} },
        { player="Innocence", server="夜空之歌", region="TW", seq={195292,43265,1297761,46585,49028,1236616,50842,433895,433895,433895,433895,49998,433895,433895,49998} },
        { player="Shørken", server="Tarren Mill", region="EU", seq={1236616,49028,50842,50842,433895,433895,433895,433895,433895,43265,49998,49998,50842,433895,433895} },
      },
      core={ {49998,17.5},{206930,15.0},{433895,9.5},{50842,8.0},{43265,3.0},{195182,2.0},{55233,1.3},{195292,1.2},{48265,1.1},{48707,0.9},{49028,0.7},{46585,0.6} }, -- Death Strike, Heart Strike, Vampiric Strike, Blood Boil, Death and Decay, Marrowrend, Vampiric Blood, Death's Caress, Death's Advance, Anti-Magic Shell, Dancing Rune Weapon, Raise Dead
      watch={ {194879,96.9},{274009,96.2},{1310372,92.0},{463730,89.9},{180612,74.6},{460499,72.6},{77535,68.3},{374585,61.8},{391459,60.7},{188290,60.7} }, -- Icy Talons, Voracious, Blood Debt, Coagulating Blood, Recently Used Death Strike, Bloodied Blade, Blood Shield, Rune Mastery, Sanguine Ground, Death and Decay
    },
    mplus={
      n=8, dur=1776,
      core={ {49998,17.2},{206930,14.1},{433895,9.5},{50842,8.5},{43265,3.9},{195182,2.1},{55233,1.8},{49576,1.2},{48707,1.0},{48265,0.8},{49028,0.6},{195292,0.6},{49039,0.5},{46585,0.4} }, -- Death Strike, Heart Strike, Vampiric Strike, Blood Boil, Death and Decay, Marrowrend, Vampiric Blood, Death Grip, Anti-Magic Shell, Death's Advance, Dancing Rune Weapon, Death's Caress, Lichborne, Raise Dead
      watch={ {433925,97.0},{391481,96.3},{219788,95.5},{1310372,94.5},{194879,94.5},{274009,93.1},{188290,74.2},{434034,74.2},{391459,74.2},{463730,74.1} }, -- Essence of the Blood Queen, Coagulopathy, Ossuary, Blood Debt, Icy Talons, Voracious, Death and Decay, Blood-Soaked Ground, Sanguine Ground, Coagulating Blood
    },
  },
  ["DEATHKNIGHT/FROST"] = {
    specID=251,
    raid={
      n=5, dur=402, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Heran", server="无尽之海", region="CN", seq={439843,47568,1249658,51271,1297761,46585,49020,47568,49020,441424,279302,441426,49020,441424,49020} },
        { player="kuwaaaang", server="ajeusyara", region="KR", seq={47568,1297761,46585,51271,439843,1249658,49020,441424,279302,441426,49020,441424,49020,441426,49020} },
        { player="Flako", server="Blackrock", region="EU", seq={47568,439843,49020,51271,1249658,1297761,441424,49020,441426,279302,49020,441424,49020,441426,49020} },
      },
      core={ {49020,20.6},{49143,15.5},{49184,9.2},{47568,4.5},{441424,3.9},{439843,1.3},{51271,1.3},{48707,1.0},{48265,0.9},{46585,0.7},{1265384,0.7},{1249658,0.7},{279302,0.7},{194913,0.7} }, -- Obliterate, Frost Strike, Howling Blast, Empower Rune Weapon, Exterminate, Reaper's Mark, Pillar of Frost, Anti-Magic Shell, Death's Advance, Raise Dead, Frostwyrm's Fury, Breath of Sindragosa, Frostwyrm's Fury, Glacial Advance
      watch={ {1230916,94.6},{440289,94.3},{440290,90.2},{456370,82.5},{1297365,73.5},{53365,72.8},{207203,59.7},{51124,59.2},{374585,54.7},{1233152,54.7} }, -- Killing Streak, Rune Carved Plates, Rune Carved Plates, Cryogenic Chamber, Freezing Tempest, Unholy Strength, Frost Shield, Killing Machine, Rune Mastery, Remorseless Winter
    },
    mplus={
      n=8, dur=1743,
      core={ {49184,8.8},{49020,8.8},{207230,8.0},{194913,7.1},{49143,6.7},{47568,4.2},{441424,3.4},{51271,1.1},{439843,1.1},{48265,0.8},{48707,0.7},{46585,0.6},{279302,0.5},{49998,0.5} }, -- Howling Blast, Obliterate, Frostscythe, Glacial Advance, Frost Strike, Empower Rune Weapon, Exterminate, Pillar of Frost, Reaper's Mark, Death's Advance, Anti-Magic Shell, Raise Dead, Frostwyrm's Fury, Death Strike
      watch={ {194879,92.4},{1230916,88.0},{440289,87.1},{456370,86.0},{440290,84.1},{207203,75.1},{1297365,62.3},{53365,62.1},{51124,52.4},{374585,48.0} }, -- Icy Talons, Killing Streak, Rune Carved Plates, Cryogenic Chamber, Rune Carved Plates, Frost Shield, Freezing Tempest, Unholy Strength, Killing Machine, Rune Mastery
    },
  },
  ["DEATHKNIGHT/UNHOLY"] = {
    specID=252,
    raid={
      n=5, dur=403, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Xequella", server="Twisting Nether", region="EU", seq={77575,85948,458128,1233448,1297761,42650,1247378,1242174,343294,1242174,1247378,1242174,55090,1242174,55090} },
        { player="Drnatedk", server="Sargeras", region="US", seq={444347,77575,85948,458128,1297761,42650,1233448,1242174,1247378,1247378,1242174,55090,55090,55090,1242174} },
        { player="Smolbreather", server="Tarren Mill", region="EU", seq={444347,77575,85948,458128,1297761,42650,1233448,1247378,1242174,1247378,1242174,55090,55090,343294,1242174} },
      },
      core={ {55090,18.6},{47541,10.7},{1242174,8.0},{85948,3.0},{458128,3.0},{1247378,2.5},{343294,2.0},{1233448,1.3},{444347,1.0},{48707,1.0},{77575,0.9},{42650,0.7} }, -- Scourge Strike, Death Coil, Necrotic Coil, Festering Strike, Festering Scythe, Putrefy, Soul Reaper, Dark Transformation, Death Charge, Anti-Magic Shell, Outbreak, Army of the Dead
      watch={ {1241569,97.0},{194879,96.7},{1241077,95.8},{1254252,92.6},{453773,83.2},{390260,64.1},{51460,56.3},{1235391,49.0},{374585,48.2},{81340,48.2} }, -- Clawing Shadows, Icy Talons, Festering Scythe, Lesser Ghoul, Pact of the Apocalypse, Commander of the Dead, Runic Corruption, Dark Transformation, Rune Mastery, Sudden Doom
    },
    mplus={
      n=8, dur=1803,
      core={ {433895,14.1},{55090,6.4},{207317,5.8},{47541,5.4},{1242174,3.6},{383269,3.1},{1247378,3.0},{85948,2.8},{458128,2.8},{43265,1.5},{1233448,1.2},{48707,0.8},{48265,0.8},{42650,0.6} }, -- Vampiric Strike, Scourge Strike, Epidemic, Death Coil, Necrotic Coil, Graveyard, Putrefy, Festering Strike, Festering Scythe, Death and Decay, Dark Transformation, Anti-Magic Shell, Death's Advance, Army of the Dead
      watch={ {1254252,93.0},{1241569,90.0},{1268917,89.6},{433925,89.4},{194879,89.1},{1242866,89.1},{1242998,88.2},{1241077,88.0},{1256576,87.7},{434159,68.9} }, -- Lesser Ghoul, Clawing Shadows, Unholy Aura, Essence of the Blood Queen, Icy Talons, Raise Dead, Lesser Ghoul, Festering Scythe, Forbidden Sacrifice, Visceral Strength
    },
  },
  ["DEMONHUNTER/DEVAURER"] = {
    specID=1480,
    raid={
      n=5, dur=416, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Omogucitelj", server="Zenedar", region="EU", seq={473662,473662,1226019,1241937,1226019,473728,1245414,1245412,198793,1246167,1246169,1250533,1245453,1245470} },
        { player="dobereuman", server="ajeusyara", region="KR", seq={473662,473662,1226019,473662,473662,1241937,1226019,473728,1245414} },
        { player="Nïzn", server="Twisting Nether", region="EU", seq={473662,473662,473662,1226019,1226019,1241937,473728,1245414,1245412,1239123} },
      },
      core={ {1217610,8.2},{473662,7.6},{1245453,6.4},{473728,6.2},{1226019,5.5},{198793,3.7},{1245470,3.6},{1245414,2.4},{1241937,2.3},{1245483,1.2},{1245412,1.2},{1259431,1.2},{1246167,0.6},{1239123,0.6} }, -- Devour, Consume, Cull, Void Ray, Reap, Vengeful Retreat, Reaper's Toll, Voidblade, Soul Immolation, Pierce the Veil, Voidblade, Predator's Wake, The Hunt, Hungering Slash
      watch={ {1245577,89.0},{453314,56.3},{1225789,53.5},{1217607,44.0},{1227702,40.8},{1246160,31.7},{1241937,29.5},{473728,23.7},{1244235,22.7},{1238495,20.1} }, -- Soul Fragments, Enduring Torment, Void Metamorphosis, Void Metamorphosis, Collapsing Star, Voidsurge, Soul Immolation, Void Ray, Rolling Torment, Moment of Craving
    },
    mplus={
      n=8, dur=1634,
      core={ {1217610,16.7},{473662,6.7},{473728,6.3},{1221150,3.4},{1241937,1.6},{198589,0.6},{1245453,0.4},{1226019,0.4},{131347,0.4} }, -- Devour, Consume, Void Ray, Collapsing Star, Soul Immolation, Blur, Cull, Reap, Glide
      watch={ {1232310,92.4},{1245577,89.1},{1256301,56.9},{1217607,55.5},{1227702,55.2},{1242504,54.7},{1256322,49.3},{1227338,48.9},{1225789,42.7},{1256302,28.8} }, -- Feast of Souls, Soul Fragments, Voidfall, Void Metamorphosis, Collapsing Star, Emptiness, Voidfall, Impending Apocalypse, Void Metamorphosis, Voidfall
    },
  },
  ["DEMONHUNTER/HAVOC"] = {
    specID=577,
    raid={
      n=5, dur=408, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Hawwkdh", server="Stormrage", region="US", seq={185123,427917,1297761,198013,370965,370966,201427,213243,232893,258860,210152,210152,198793,200166,210152} },
        { player="Mynostalgia", server="Proudmoore", region="US", seq={1297761,213243,232893,198013,370965,370966,258860,201427,210152,228537,210152,198793,200166,210152,201427} },
        { player="Pichapaloma", server="Zul'jin", region="EU", seq={185123,258920,427917,1297908,198013,370965,370966,258860,210152,210152,201427,198793,201427,228537,200166} },
      },
      core={ {162794,11.0},{201427,10.5},{210152,7.3},{198793,2.3},{198013,2.2},{232893,2.0},{258860,1.9},{258920,1.6},{188499,1.6},{370965,1.0},{185123,0.7},{198589,0.7},{200166,0.6},{195072,0.6} }, -- Chaos Strike, Annihilation, Death Sweep, Vengeful Retreat, Eye Beam, Felblade, Essence Break, Immolation Aura, Blade Dance, The Hunt, Throw Glaive, Blur, Metamorphosis, Fel Rush
      watch={ {208628,95.6},{453314,51.0},{162264,50.5},{452416,47.0},{390192,41.7},{258920,40.7},{343312,38.9},{389890,38.3},{428361,31.4},{391215,31.0} }, -- Exergy, Enduring Torment, Metamorphosis, Demonsurge, Ragefire, Immolation Aura, Furious Gaze, Tactical Retreat, Ragefire, Initiative
    },
    mplus={
      n=8, dur=1805,
      core={ {162794,8.8},{201427,8.1},{210152,6.0},{232893,2.4},{185123,2.2},{198793,2.1},{188499,2.0},{198013,1.9},{258920,1.7},{258860,1.4},{131347,1.1},{195072,1.1},{370965,0.8},{452497,0.7} }, -- Chaos Strike, Annihilation, Death Sweep, Felblade, Throw Glaive, Vengeful Retreat, Blade Dance, Eye Beam, Immolation Aura, Essence Break, Glide, Fel Rush, The Hunt, Abyssal Gaze
      watch={ {208628,86.8},{453314,56.7},{162264,43.3},{452416,41.2},{258920,38.7},{390192,37.7},{389890,34.7},{343312,33.6},{391215,31.7},{427912,25.1} }, -- Exergy, Enduring Torment, Metamorphosis, Demonsurge, Immolation Aura, Ragefire, Tactical Retreat, Furious Gaze, Initiative, Immolation Aura
    },
  },
  ["DEMONHUNTER/VENGEANCE"] = {
    specID=581,
    raid={
      n=5, dur=407, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Avade", server="Illidan", region="US", seq={390163,204021,1236616,203720,225919,263642,225921,1297761,225919,263642,225921,247454,228477,187827,225919} },
        { player="Felvix", server="Sylvanas", region="EU", seq={346665,204157,203720,131347,213243,232893,258920,225919,263642,225921,1236616,204596,204021,271107,390163} },
        { player="Slickezpz", server="Blackhand", region="EU", seq={204021,258920,1236616,390163,203720,225919,263642,225921,225919,263642,225921,247454,212084,225919,263642} },
      },
      core={ {263642,17.4},{228477,16.5},{203720,5.8},{258920,4.8},{247454,3.6},{187827,2.2},{204596,1.7},{204021,1.4},{212084,1.1},{390163,1.0},{232893,0.8},{204157,0.7} }, -- Fracture, Soul Cleave, Demon Spikes, Immolation Aura, Spirit Bomb, Metamorphosis, Sigil of Flame, Fiery Brand, Fel Devastation, Sigil of Spite, Felblade, Throw Glaive
      watch={ {1270547,90.8},{258920,72.4},{393009,70.8},{203981,66.2},{1256301,54.0},{187827,48.5},{1256322,44.6},{439530,36.1},{207771,35.4},{1287978,30.3} }, -- Seething Anger, Immolation Aura, Fel Flame Fortification, Soul Fragments, Voidfall, Metamorphosis, Voidfall, Symbiotic Blooms, Fiery Brand, Rune of Lynxlike Reflexes
    },
    mplus={
      n=8, dur=1705,
      core={ {228477,16.8},{263642,16.7},{203720,6.8},{258920,4.7},{247454,3.1},{187827,2.0},{204596,1.5},{131347,1.5},{204021,1.2},{212084,1.0},{204157,0.9},{390163,0.8},{232893,0.5} }, -- Soul Cleave, Fracture, Demon Spikes, Immolation Aura, Spirit Bomb, Metamorphosis, Sigil of Flame, Glide, Fiery Brand, Fel Devastation, Throw Glaive, Sigil of Spite, Felblade
      watch={ {203819,96.3},{212988,93.8},{1270547,87.8},{203981,70.3},{393009,69.7},{258920,69.6},{1256301,55.1},{187827,43.4},{207771,41.6},{1256322,40.7} }, -- Demon Spikes, Painbringer, Seething Anger, Soul Fragments, Fel Flame Fortification, Immolation Aura, Voidfall, Metamorphosis, Fiery Brand, Voidfall
    },
  },
  ["DRUID/BALANCE"] = {
    specID=102,
    raid={
      n=5, dur=384, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Yasa", server="Zirkel des Cenarius", region="EU", seq={93402,8921,8921,202770,1236616,1293316,102560,194153,191034,194153,194153,191034,194153,194153,194153} },
        { player="Froupi", server="Twisting Nether", region="EU", seq={8921,93402,93402,202770,1293316,102560,194153,194153,191034,194153,191034,194153,194153,194153,191034} },
        { player="Rotí", server="Tarren Mill", region="EU", seq={190984,8921,93402,1233272,194153,194153,202770,102560,1293316,191034,194153,194153,8921,191034,194153} },
      },
      core={ {194153,15.5},{191034,12.7},{8921,6.8},{78674,6.1},{93402,3.6},{202770,2.4},{1233272,1.9},{22812,0.9},{102560,0.7},{24858,0.5} }, -- Starfire, Starfall, Moonfire, Starsurge, Sunfire, Fury of Elune, Lunar Eclipse, Barkskin, Incarnation: Chosen of Elune, Moonkin Form
      watch={ {1303480,96.6},{191034,88.5},{279709,86.1},{343648,71.3},{48518,66.6},{1301768,66.6},{394050,40.8},{202770,31.4},{393763,26.2},{1263382,25.7} }, -- Orbit Breaker, Starfall, Starlord, Solstice, Eclipse (Lunar), Akil'zon's Clarity, Balance of All Things, Fury of Elune, Umbral Embrace, Ascendant Stars
    },
    mplus={
      n=8, dur=1769,
      core={ {194153,15.3},{191034,9.4},{78674,7.6},{8921,4.6},{93402,3.3},{202770,2.2},{1233272,1.8},{22812,0.6},{102560,0.5},{24858,0.4} }, -- Starfire, Starfall, Starsurge, Moonfire, Sunfire, Fury of Elune, Lunar Eclipse, Barkskin, Incarnation: Chosen of Elune, Moonkin Form
      watch={ {1303480,95.2},{378992,94.2},{24858,94.2},{279709,81.4},{48518,62.2},{1301768,62.2},{191034,55.7},{343648,44.3},{450346,38.9},{394050,38.7} }, -- Orbit Breaker, Lycara's Teachings, Moonkin Form, Starlord, Eclipse (Lunar), Akil'zon's Clarity, Starfall, Solstice, Dreamstate, Balance of All Things
    },
  },
  ["DRUID/FERAL"] = {
    specID=103,
    raid={
      n=5, dur=410, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Bigbloom", server="Illidan", region="US", seq={1822,106951,5217,1293316,1236616,274837,1079,5221,22568,391528,22568,22568,1822,22568,5221} },
        { player="Akhissa", server="Gordunni", region="EU", seq={5217,1822,106951,1293316,1236616,274837,1079,1850,155625,49376,1079,1822,22568,391528,1079} },
        { player="一般不吃人", server="血色十字军", region="CN", seq={1822,155625,1822,1297761,106951,5217,1079,155625,49376,1079,274837,22568,1822,22568,5221} },
      },
      core={ {5221,13.3},{22568,11.2},{1822,6.7},{155625,6.3},{1079,4.6},{8936,2.3},{5217,1.9},{274837,1.9},{391528,0.6},{106951,0.6},{22812,0.6} }, -- Shred, Ferocious Bite, Rake, Moonfire, Rip, Regrowth, Tiger's Fury, Feral Frenzy, Convoke the Spirits, Berserk, Barkskin
      watch={ {69369,90.5},{135700,53.0},{1301600,49.4},{5217,46.4},{391876,46.0},{449646,24.9},{106951,23.1},{405069,23.1},{431415,21.1},{391873,21.1} }, -- Predatory Swiftness, Clearcasting, Halazzi's Fury, Tiger's Fury, Frantic Momentum, Savage Fury, Berserk, Overflowing Power, Sun Sear, Tiger's Tenacity
    },
    mplus={
      n=8, dur=1755,
      core={ {106785,12.1},{22568,7.4},{5221,7.0},{1822,5.8},{441591,5.2},{285381,4.3},{5217,1.7},{1243807,1.1},{1079,1.0},{22812,0.7},{5487,0.6},{102547,0.6},{102543,0.6},{22842,0.4} }, -- Swipe, Ferocious Bite, Shred, Rake, Ravage, Primal Wrath, Tiger's Fury, Frantic Frenzy, Rip, Barkskin, Bear Form, Prowl, Incarnation: Avatar of Ashamane, Frenzied Regeneration
      watch={ {1263939,96.6},{378990,95.6},{768,95.6},{69369,86.2},{441825,58.2},{1301600,53.1},{391876,51.4},{5217,42.2},{135700,34.8},{102543,30.5} }, -- Unseen Predator's Craving, Lycara's Teachings, Cat Form, Predatory Swiftness, Killing Strikes, Halazzi's Fury, Frantic Momentum, Tiger's Fury, Clearcasting, Incarnation: Avatar of Ashamane
    },
  },
  ["DRUID/GUARDIAN"] = {
    specID=104,
    raid={
      n=5, dur=399, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Denerocxd", server="Twisting Nether", region="EU", seq={77758,1293316,102558,77758,1269658,1236616,6807,77758,33917,77758,192081,33917,192081,77758,192081} },
        { player="Gnomerender", server="Silvermoon", region="EU", seq={22812,1270292,204066,768,1293316,1236616,50334,77758,1252871,77758,192081,33917,192081,77758,33917} },
        { player="Ahrilia", server="Stormrage", region="US", seq={1270292,204066,1252871,77758,192081,33917,22812,33917,1236616,768,1250533,102558,1269658,77758,33917} },
      },
      core={ {192081,20.9},{33917,19.5},{77758,14.6},{213771,5.3},{6807,2.5},{1252871,1.8},{22812,1.4},{204066,1.3},{22842,1.2},{1269658,0.6},{102558,0.6},{1822,0.5},{61336,0.4} }, -- Ironfur, Mangle, Thrash, Swipe, Maul, Red Moon, Barkskin, Lunar Beam, Frenzied Regeneration, Wild Guardian, Incarnation: Guardian of Ursoc, Rake, Survival Instincts
      watch={ {1251877,93.8},{192081,93.8},{1253600,70.9},{1307881,49.3},{102558,34.0},{1308647,31.7},{22812,30.1},{204066,24.8} }, -- Gift of an Ancient Guardian, Ironfur, Lunar Wrath, Gory Fur, Incarnation: Guardian of Ursoc, Answered Calling, Barkskin, Lunar Beam
    },
    mplus={
      n=8, dur=1794,
      core={ {192081,25.9},{77758,16.0},{8921,13.7},{33917,13.0},{22842,2.5},{204066,1.3},{22812,1.2},{102558,0.5},{1269658,0.5},{213771,0.4},{61336,0.3},{6807,0.3},{5487,0.3} }, -- Ironfur, Thrash, Moonfire, Mangle, Frenzied Regeneration, Lunar Beam, Barkskin, Incarnation: Guardian of Ursoc, Wild Guardian, Swipe, Survival Instincts, Maul, Bear Form
      watch={ {378991,95.8},{5487,95.8},{1251877,92.4},{192081,92.4},{372505,60.7},{213708,48.9},{93622,37.3},{102558,32.4},{1308647,32.2},{1308176,29.8} }, -- Lycara's Teachings, Bear Form, Gift of an Ancient Guardian, Ironfur, Ursoc's Fury, Galactic Guardian, Gore, Incarnation: Guardian of Ursoc, Answered Calling, Dream Conduit
    },
  },
  ["DRUID/RESTORATION"] = {
    specID=105,
    raid={
      n=5, dur=425, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="咕咕丶哒", server="回音山", region="CN", seq={5176,5176,774,774,5176,774,33763,774,774,8936,774,774,5176,18562,774} },
        { player="赤血丨二月", server="罗宁", region="CN", seq={33763,774,8936,774,48438,197626,33763,774,18562,774,5176,197626,5176,774,8936} },
        { player="Mewgordita", server="Sargeras", region="US", seq={774,774,8936,8936,774,18562,774,48438,33763,391528,197626,18562,774,8936,8936} },
      },
      core={ {774,17.1},{8936,13.2},{18562,5.5},{48438,4.1},{33763,3.4},{132158,1.0},{391528,1.0},{88423,0.7},{5176,0.5},{22812,0.5} }, -- Rejuvenation, Regrowth, Swiftmend, Wild Growth, Lifebloom, Nature's Swiftness, Convoke the Spirits, Nature's Cure, Wrath, Barkskin
      watch={ {439888,96.7},{207640,96.3},{1302255,84.2},{400126,78.0},{392360,74.3},{439530,56.7},{16870,23.8},{117679,21.0},{33891,20.4} }, -- Root Network, Abundance, Genesis, Forestwalk, Reforestation, Symbiotic Blooms, Clearcasting, Incarnation, Incarnation: Tree of Life
    },
    mplus={
      n=8, dur=1744,
      core={ {774,9.9},{8936,7.4},{18562,4.6},{33763,4.2},{48438,3.1},{1822,2.9},{5221,2.7},{1079,1.3},{88423,0.8},{8921,0.7},{391528,0.7},{22812,0.5},{132158,0.5},{783,0.3} }, -- Rejuvenation, Regrowth, Swiftmend, Lifebloom, Wild Growth, Rake, Shred, Rip, Nature's Cure, Moonfire, Convoke the Spirits, Barkskin, Nature's Swiftness, Travel Form
      watch={ {378989,77.1},{1302255,73.4},{207640,63.6},{400126,49.4},{439530,47.1},{16870,37.1},{768,19.9},{378990,19.9} }, -- Lycara's Teachings, Genesis, Abundance, Forestwalk, Symbiotic Blooms, Clearcasting, Cat Form, Lycara's Teachings
    },
  },
  ["EVOKER/AUGMENTATION"] = {
    specID=1473,
    raid={
      n=5, dur=368, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Evook", server="Tichondrius", region="US", seq={431443,403631,409311,395152,409311,370553,357208,396286,1297908,404977,409311,409311,357208,396286,395160} },
        { player="yeongneungteonjongyeongneung", server="ajeusyara", region="KR", seq={409311,358733,403631,395152,370553,357208,396286,409311,404977,395152,409311,409311,357208,395160,395160} },
        { player="Olbahamut", server="Tarren Mill", region="EU", seq={431443,409311,409311,358267,403631,370553,357208,396286,404977,395152,357208,409311,396286,395160,395160} },
      },
      core={ {395160,17.3},{431443,9.5},{409311,6.4},{396286,5.7},{357208,4.2},{358267,3.1},{395152,2.1},{370553,0.9},{403631,0.7},{363916,0.7},{404977,0.5},{362969,0.5},{374968,0.3} }, -- Eruption, Chrono Flames, Prescience, Upheaval, Fire Breath, Hover, Ebon Might, Tip the Scales, Breath of Eons, Obsidian Scales, Time Skip, Azure Strike, Time Spiral
      watch={ {410263,80.3},{431654,68.4},{358267,67.1},{408005,57.8},{1259171,51.5},{431698,40.8},{372470,39.0},{392268,38.0},{1297728,37.0},{370901,34.6} }, -- Inferno's Blessing, Primacy, Hover, Momentum Shift, Duplicate, Temporal Burst, Scarlet Adaptation, Essence Burst, Magnified Fate, Leaping Flames
    },
    mplus={
      n=8, dur=1918,
      core={ {395160,15.0},{431443,6.0},{409311,5.3},{396286,4.9},{357208,3.8},{358267,2.4},{395152,1.7},{358733,1.1},{362969,0.7},{370553,0.7},{363916,0.6},{403631,0.5},{404977,0.4} }, -- Eruption, Chrono Flames, Prescience, Upheaval, Fire Breath, Hover, Ebon Might, Glide, Azure Strike, Tip the Scales, Obsidian Scales, Breath of Eons, Time Skip
      watch={ {431654,63.5},{408005,50.5},{358267,45.1},{1259171,43.2},{431698,35.9},{370901,33.8},{1297728,33.1},{392268,32.2},{459574,16.2},{413984,15.4} }, -- Primacy, Momentum Shift, Hover, Duplicate, Temporal Burst, Leaping Flames, Magnified Fate, Essence Burst, Imminent Destruction, Shifting Sands
    },
  },
  ["EVOKER/DEVASTATION"] = {
    specID=1467,
    raid={
      n=5, dur=401, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Gilgvoker", server="Tichondrius", region="US", seq={361469,433874,390386,375087,1236616,370553,357208,359073,358267,356995,356995,356995,356995,356995,361469} },
        { player="Dragonsoulsi", server="Area 52", region="US", seq={361469,433874,375087,1236616,370553,357208,359073,1293316,356995,356995,356995,356995,361469,356995,361469} },
        { player="hakwonpashunsudaemawang", server="ajeusyara", region="KR", seq={361469,433874,375087,357208,359073,356995,356995,356995,356995,358267,361469,356995,433874,356995,357208} },
      },
      core={ {356995,16.7},{359073,6.9},{357208,6.4},{361469,5.5},{358267,4.2},{433874,2.4},{1292321,1.9},{375087,0.6},{363916,0.5},{370553,0.5},{358733,0.4},{374227,0.3} }, -- Disintegrate, Eternity Surge, Fire Breath, Living Flame, Hover, Deep Breath, Unbound Flame, Dragonrage, Obsidian Scales, Tip the Scales, Glide, Zephyr
      watch={ {358267,74.4},{375802,73.7},{411055,71.4},{356995,48.4},{1271783,44.3},{372470,40.9},{1292323,40.5},{376850,39.0},{370901,37.0},{359618,31.1} }, -- Hover, Burnout, Imminent Destruction, Disintegrate, Rising Fury, Scarlet Adaptation, Unbound Flame, Power Swell, Leaping Flames, Essence Burst
    },
    mplus={
      n=8, dur=1751,
      core={ {356995,10.7},{359073,6.3},{357208,6.0},{361469,5.5},{357211,2.8},{433874,2.2},{358267,2.1},{358733,1.8},{1292321,1.7},{362969,1.0},{370553,0.4},{375087,0.4},{363916,0.4} }, -- Disintegrate, Eternity Surge, Fire Breath, Living Flame, Pyre, Deep Breath, Hover, Glide, Unbound Flame, Azure Strike, Tip the Scales, Dragonrage, Obsidian Scales
      watch={ {441248,91.0},{370454,85.3},{411055,66.1},{375802,55.4},{1271783,38.8},{376850,37.8},{370901,37.6},{1292323,36.5},{358267,35.0},{436336,33.6} }, -- Unrelenting Siege, Charged Blast, Imminent Destruction, Burnout, Rising Fury, Power Swell, Leaping Flames, Unbound Flame, Hover, Mass Disintegrate
    },
  },
  ["EVOKER/PRESERVATION"] = {
    specID=1468,
    raid={
      n=5, dur=405, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="大搅拌者", server="贫瘠之地", region="CN", seq={370553,357208,361469,355913,1265980,356995,360995,361195,355913,370537,355936,355936,373861,1265980,356995} },
        { player="Drosn", server="Antonidas", region="EU", seq={355913,355913,370553,357208,364343,364343,364343,370537,355936,355936,373861,355913,357208,364343,364343} },
        { player="Kirinari", server="Revushchiy ford", region="EU", seq={370553,357208,355913,361469,355913,364343,364343,1256581,355913,361469,1291894,357208,355913,370537,355936} },
      },
      core={ {355913,11.3},{364343,10.1},{355936,5.5},{1256581,4.7},{373861,4.0},{357208,3.7},{361469,1.9},{358267,1.0},{370537,0.7},{360823,0.6},{370553,0.6},{363916,0.6},{370564,0.6},{1291894,0.6} }, -- Emerald Blossom, Echo, Dream Breath, Merithra's Blessing, Temporal Anomaly, Fire Breath, Living Flame, Hover, Stasis (Store), Naturalize, Tip the Scales, Obsidian Scales, Stasis (Release), Soulcoiler Ritual Vessel
      watch={ {375583,94.9},{362877,82.5},{1256579,59.4},{369299,53.1},{370901,43.6},{370562,16.2},{1242747,15.9} }, -- Ancient Flame, Temporal Compression, Merithra's Blessing, Essence Burst, Leaping Flames, Stasis, Inner Flame
    },
    mplus={
      n=8, dur=1749,
      core={ {356995,8.6},{355913,7.0},{355936,6.0},{357208,5.2},{361469,4.9},{373861,3.9},{1256581,3.8},{364343,1.8},{358733,1.2},{358267,1.2},{360823,0.5},{370553,0.5},{363916,0.5},{370537,0.5} }, -- Disintegrate, Emerald Blossom, Dream Breath, Fire Breath, Living Flame, Temporal Anomaly, Merithra's Blessing, Echo, Glide, Hover, Naturalize, Tip the Scales, Obsidian Scales, Stasis (Store)
      watch={ {372470,95.6},{375583,90.3},{443176,71.4},{1256579,61.7},{362877,58.6},{369299,49.8},{373267,30.3},{370901,21.7},{1252486,20.2},{356995,18.5} }, -- Scarlet Adaptation, Ancient Flame, Lifespark, Merithra's Blessing, Temporal Compression, Essence Burst, Lifebind, Leaping Flames, Hasty Hunt, Disintegrate
    },
  },
  ["HUNTER/BEASTMASTERY"] = {
    specID=253,
    raid={
      n=5, dur=405, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="一直很安静丨", server="克尔苏加德", region="CN", seq={217200,1297761,217200,19574,34026,217200,34026,1308188,193455,34026,217200,34026,193455,34026,1308188} },
        { player="崔莱蒂", server="红龙军团", region="CN", seq={1297761,217200,217200,19574,34026,217200,34026,193455,34026,1308188,217200,34026,193455,34026,217200} },
        { player="Welkinwild", server="Illidan", region="US", seq={217200,217200,19574,1293316,34026,217200,34026,193455,34026,217200,34026,193455,34026,1308188,217200} },
      },
      core={ {34026,17.7},{193455,16.0},{217200,10.9},{1308188,6.7},{19574,1.9},{1263768,1.9},{257284,0.8},{264735,0.5},{109304,0.3} }, -- Kill Command, Cobra Shot, Barbed Shot, Dire Beast, Bestial Wrath, Light's Blessing, Hunter's Mark, Survival of the Fittest, Exhilaration
      watch={ {246152,95.6},{471877,88.0},{459731,85.4},{1276720,64.0},{1306960,63.6},{19574,46.8},{471881,42.5},{1299389,42.0},{1265063,31.5},{1297761,22.0} }, -- Barbed Shot, Howl of the Pack Leader, Huntmaster's Call, Nature's Ally, Dire Beast, Bestial Wrath, Wyvern's Cry, Cobra Fang, Bloody Frenzy, Voracious Heart of Ula'tek
    },
    mplus={
      n=8, dur=1717,
      core={ {34026,11.8},{193455,11.3},{217200,8.2},{1264359,4.1},{19574,1.7},{264735,0.5},{781,0.4},{109304,0.3},{257284,0.3} }, -- Kill Command, Cobra Shot, Barbed Shot, Wild Thrash, Bestial Wrath, Survival of the Fittest, Disengage, Exhilaration, Hunter's Mark
      watch={ {246152,87.0},{471877,84.7},{268877,62.3},{1276720,61.5},{1299389,43.3},{19574,43.2},{471881,34.1},{1306960,17.3} }, -- Barbed Shot, Howl of the Pack Leader, Beast Cleave, Nature's Ally, Cobra Fang, Bestial Wrath, Wyvern's Cry, Dire Beast
    },
  },
  ["HUNTER/MARKSMANSHIP"] = {
    specID=254,
    raid={
      n=5, dur=403, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Survi", server="Stormrage", region="US", seq={19434,212431,212431,288613,1297761,257044,19434,185358,19434,185358,19434,185358,257044,19434,1264949} },
        { player="Patchmyprey", server="Draenor", region="EU", seq={19434,212431,212431,288613,271107,257044,19434,185358,19434,185358,19434,257044,19434,185358,260243} },
        { player="Imnotanorc", server="Tichondrius", region="US", seq={19434,260243,212431,212431,1297761,288613,257044,19434,185358,19434,185358,19434,185358,56641,19434} },
      },
      core={ {19434,10.4},{56641,6.1},{257044,4.9},{185358,3.8},{212431,3.5},{257620,3.1},{260243,1.2},{53351,1.1},{264735,0.7},{1264949,0.6},{288613,0.6},{109304,0.4},{186257,0.3} }, -- Aimed Shot, Steady Shot, Rapid Fire, Arcane Shot, Explosive Shot, Multi-Shot, Volley, Kill Shot, Survival of the Fittest, Moonlight Chakram, Trueshot, Exhilaration, Aspect of the Cheetah
      watch={ {1253750,94.6},{389020,66.7},{1279347,34.3},{204090,33.2},{260242,28.4},{451447,18.1},{1297761,17.4},{288613,16.2},{1305376,15.2} }, -- Stargazer, Bulletstorm, Quick Draw, Bullseye, Precise Shots, Don't Look Back, Voracious Heart of Ula'tek, Trueshot, Devoured Strength
    },
    mplus={
      n=8, dur=1684,
      core={ {19434,8.1},{257620,7.6},{257044,3.9},{56641,3.3},{212431,3.2},{185358,2.9},{260243,1.1},{264735,0.5},{34477,0.5},{1264949,0.4},{257284,0.4},{781,0.4},{288613,0.4} }, -- Aimed Shot, Multi-Shot, Rapid Fire, Steady Shot, Explosive Shot, Arcane Shot, Volley, Survival of the Fittest, Misdirection, Moonlight Chakram, Hunter's Mark, Disengage, Trueshot
      watch={ {1253750,88.0},{257622,51.4},{389020,48.3},{204090,48.2},{451447,38.1},{1279347,26.6},{260242,22.0} }, -- Stargazer, Trick Shots, Bulletstorm, Bullseye, Don't Look Back, Quick Draw, Precise Shots
    },
  },
  ["HUNTER/SURVIVAL"] = {
    specID=255,
    raid={
      n=5, dur=410, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Leaku", server="Illidan", region="US", seq={259495,1250533,186270,1262293,186270,1261193,1253859,1250646,259495,259489,1262293,259495,259489,186270,1264949} },
        { player="Graysurv", server="Velen", region="US", seq={259495,190925,259489,186270,1262293,186270,1261193,1297761,1253859,1250646,259495,1264949,259489,259495,1262293} },
        { player="Tayu", server="Throk'Feroth", region="EU", seq={259495,1297761,1250646,1253859,259495,1261193,259489,186270,1262293,259489,186270,259495,259489,259495,1264949} },
      },
      core={ {259489,13.5},{186270,8.9},{259495,8.4},{1261193,1.2},{1250646,1.0},{1264949,1.0},{264735,0.6} }, -- Kill Command, Raptor Strike, Wildfire Bomb, Boomstick, Takedown, Moonlight Chakram, Survival of the Fittest
      watch={ {1253750,94.6},{259388,93.5},{260286,75.5},{1273155,49.4},{1292687,42.1},{1254180,36.9},{439530,25.9},{451447,19.2},{1250646,16.6} }, -- Stargazer, Mongoose Fury, Tip of the Spear, Raptor Swipe!, Shrapnel Bomb, Xathuux's Last Roar, Symbiotic Blooms, Don't Look Back, Takedown
    },
    mplus={
      n=8, dur=1737,
    },
  },
  ["MAGE/ARCANE"] = {
    specID=62,
    raid={
      n=5, dur=407, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="呈宝法", server="伊森利恩", region="CN", seq={365350,80353,1236616,1250533,5143,44425,321507,5143,1295924,44425,5143,1295924,44425,5143,44425} },
        { player="小沐曾雪菜", server="无尽之海", region="CN", seq={365350,80353,5143,1250533,1236616,44425,321507,5143,5143,44425,153626,153626,30451,5143,30451} },
        { player="Màzz", server="Area 52", region="US", seq={365350,1250533,5143,44425,321507,5143,5143,30451,44425,1295924,44425,5143,30451,30451,30451} },
      },
      core={ {5143,14.4},{44425,13.4},{1295924,5.5},{30451,4.4},{212653,1.3},{321507,1.3},{235450,1.2},{365350,0.7} }, -- Arcane Missiles, Arcane Barrage, Prismatic Bolt, Arcane Blast, Shimmer, Touch of the Magi, Prismatic Barrier, Arcane Surge
      watch={ {448604,93.8},{449322,89.8},{461531,89.3},{263725,80.2},{1242974,79.4},{1296930,77.4},{1295942,56.5},{394195,51.6},{256374,35.4},{1277009,28.7} }, -- Spellfire Sphere, Mana Cascade, Brainstorm, Clearcasting, Arcane Salvo, Cumulative Power, Prismatic Bolt!, Overflowing Energy, Entropic Embrace, Overpowered Missiles
    },
    mplus={
      n=8, dur=1807,
      core={ {5143,13.6},{44425,12.1},{1295924,4.6},{30451,4.3},{235450,1.4},{321507,1.2},{212653,1.1},{1449,0.6},{365350,0.6},{153626,0.5},{55342,0.4},{342245,0.3} }, -- Arcane Missiles, Arcane Barrage, Prismatic Bolt, Arcane Blast, Prismatic Barrier, Touch of the Magi, Shimmer, Arcane Explosion, Arcane Surge, Arcane Orb, Mirror Image, Alter Time
      watch={ {448604,95.2},{449322,87.0},{461531,83.0},{1242974,76.2},{1296930,71.3},{263725,69.3},{394195,54.6},{1295942,50.7},{1277009,23.1},{449336,18.8} }, -- Spellfire Sphere, Mana Cascade, Brainstorm, Arcane Salvo, Cumulative Power, Clearcasting, Overflowing Energy, Prismatic Bolt!, Overpowered Missiles, Merely a Setback
    },
  },
  ["MAGE/FIRE"] = {
    specID=63,
    raid={
      n=5, dur=403, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Hrslkks", server="ajeusyara", region="KR", seq={11366,80353,108853,133,11366,11366,108853,11366,108853,11366,108853,11366,153561,1293316,1236616} },
        { player="小鸟游小埋", server="伊利丹", region="CN", seq={11366,1236616,108853,133,11366,11366,153561,190319,108853,11366,11366,1250508,11366,108853,11366} },
        { player="Shimon", server="ajeusyara", region="KR", seq={11366,108853,133,11366,11366,108853,11366,108853,11366,108853,11366,108853,11366,108853,11366} },
      },
      core={ {11366,29.8},{108853,20.3},{2948,7.6},{133,6.4},{153561,1.8},{212653,1.1},{235313,1.1},{190319,1.0} }, -- Pyroblast, Fire Blast, Scorch, Fireball, Meteor, Shimmer, Blazing Barrier, Combustion
      watch={ {448604,94.0},{449314,93.2},{461531,92.9},{383395,78.0},{383811,61.7},{269651,54.3},{1257350,53.4},{394195,43.4},{48107,30.1},{383637,24.8} }, -- Spellfire Sphere, Mana Cascade, Brainstorm, Feel the Burn, Fevered Incantation, Pyroclasm, Fired Up, Overflowing Energy, Heating Up, Fiery Rush
    },
    mplus={
      n=8, dur=1670,
      core={ {108853,14.5},{11366,12.8},{2120,10.7},{133,5.9},{2948,4.6},{153561,1.5},{235313,1.3},{212653,0.8},{190319,0.8} }, -- Fire Blast, Pyroblast, Flamestrike, Fireball, Scorch, Meteor, Blazing Barrier, Shimmer, Combustion
      watch={ {448604,95.6},{461531,83.3},{449314,82.6},{1287770,76.2},{383395,60.1},{383811,53.4},{269651,46.0},{1257350,45.7},{48107,32.0},{48108,26.1} }, -- Spellfire Sphere, Brainstorm, Mana Cascade, Rune of the Versatile Warrior, Feel the Burn, Fevered Incantation, Pyroclasm, Fired Up, Heating Up, Hot Streak!
    },
  },
  ["MAGE/FROST"] = {
    specID=64,
    raid={
      n=5, dur=388, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Choechoi", server="ajeusyara", region="KR", seq={116,44614,1236616,212653,1250533,205021,30455,30455,84714,44614,30455,205021,30455,30455,30455} },
        { player="Kevybaby", server="Frostmourne", region="US", seq={116,44614,80353,1250533,205021,30455,84714,30455,44614,30455,30455,205021,30455,30455,199786} },
        { player="Terstroik", server="Sanguino", region="EU", seq={116,44614,80353,1250533,205021,30455,84714,30455,44614,30455,30455,30455,199786,44614,30455} },
      },
      core={ {30455,22.1},{44614,7.3},{116,4.8},{199786,4.3},{84714,1.9},{205021,1.7},{212653,1.5},{11426,1.1},{414658,0.3} }, -- Ice Lance, Flurry, Frostbolt, Glacial Spike, Frozen Orb, Ray of Frost, Shimmer, Ice Barrier, Ice Cold
      watch={ {205473,89.8},{1263263,77.7},{461531,54.1},{394195,53.2},{455122,47.7},{1305360,47.6},{44544,35.4},{1222865,27.6},{1247908,27.4},{1250533,16.3} }, -- Icicles, Hand of Frost, Brainstorm, Overflowing Energy, Permafrost Lances, Soul Fang Alacrity, Fingers of Frost, Glacial Spike!, Splinterstorm, Freightrunner's Flask
    },
    mplus={
      n=8, dur=1725,
      core={ {30455,12.6},{431044,11.3},{44614,7.3},{199786,4.6},{11426,1.6},{205021,1.1},{153595,1.1},{212653,1.0},{84714,0.9} }, -- Ice Lance, Frostfire Bolt, Flurry, Glacial Spike, Ice Barrier, Ray of Frost, Comet Storm, Shimmer, Frozen Orb
      watch={ {205473,89.6},{461531,55.6},{394195,44.9},{431177,41.2},{44544,37.3},{1222865,27.4},{455122,22.7},{1247778,21.3},{1252486,18.1},{1247730,17.1} }, -- Icicles, Brainstorm, Overflowing Energy, Frostfire Empowerment, Fingers of Frost, Glacial Spike!, Permafrost Lances, Comet Storm!, Hasty Hunt, Thermal Void
    },
  },
  ["MONK/BREWMASTER"] = {
    specID=268,
    raid={
      n=5, dur=396, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Obstruction", server="ajeusyara", region="KR", seq={123986,121253,132578,115181,121253,115181,121253,115181,325153,121253,119582,115181,119582,205523,121253} },
        { player="Grootwalker", server="Eredar", region="EU", seq={121253,132578,1236616,115181,205523,100780,121253,115181,205523,100780,121253,115181,205523,100780,121253} },
        { player="Telleria", server="Sargeras", region="US", seq={121253,132578,1236616,205523,123986,325153,100780,205523,115181,119582,100780,121253,205523,115181,100780} },
      },
      core={ {121253,10.9},{205523,10.9},{115181,10.5},{100780,10.5},{119582,6.0},{1241059,1.9},{123986,1.4},{109132,1.3},{325153,0.9},{322101,0.9},{115399,0.7},{132578,0.6},{116841,0.4},{322109,0.3} }, -- Keg Smash, Blackout Kick, Breath of Fire, Tiger Palm, Purifying Brew, Celestial Infusion, Chi Burst, Roll, Exploding Keg, Expel Harm, Black Ox Brew, Invoke Niuzao, the Black Ox, Tiger's Lust, Touch of Death
      watch={ {1287770,84.8},{101643,72.8},{1301477,71.0},{450521,70.5},{1270990,68.9},{451508,67.1},{455071,63.1},{393515,62.3},{1260619,55.7},{195630,51.1} }, -- Rune of the Versatile Warrior, Transcendence, Hot Potato, Aspect of Harmony, Potential Energy, Balanced Stratagem, Ox Stance, Pretense of Instability, Elevated Stagger, Elusive Brawler
    },
    mplus={
      n=8, dur=1705,
      core={ {100780,11.2},{205523,10.9},{121253,10.7},{115181,10.2},{119582,8.1},{1241059,2.4},{109132,1.4},{123986,1.2},{115399,0.9},{322109,0.4},{116841,0.4},{132578,0.4},{115203,0.3} }, -- Tiger Palm, Blackout Kick, Keg Smash, Breath of Fire, Purifying Brew, Celestial Infusion, Roll, Chi Burst, Black Ox Brew, Touch of Death, Tiger's Lust, Invoke Niuzao, the Black Ox, Fortifying Brew
      watch={ {215479,96.4},{392883,96.0},{383733,90.1},{1287770,82.5},{393515,72.0},{451508,71.6},{450521,65.8},{414143,64.0},{383800,62.4},{1270990,62.3} }, -- Shuffle, Vivacious Vivification, Training of Niuzao, Rune of the Versatile Warrior, Pretense of Instability, Balanced Stratagem, Aspect of Harmony, Yu'lon's Grace, Counterstrike, Potential Energy
    },
  },
  ["MONK/MISTWEAVER"] = {
    specID=270,
    raid={
      n=5, dur=419, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="angaesangja", server="ajeusyara", region="KR", seq={467307,115175,124682,124682,116849,124682,124682,467307,115151,115151,115151,1291894,116680,115294,115175} },
        { player="Eiven", server="Gordunni", region="EU", seq={116849,116680,115151,115151,467307,1291894,115151,467307,115151,124682,467307,100784,100780,100784,467307} },
        { player="Disasterqt", server="Ravencrest", region="EU", seq={116849,116680,115151,115151,467307,1291894,115151,467307,115294,124682,115151,467307,124682,467307,115294} },
      },
      core={ {116670,14.0},{467307,13.6},{115151,9.7},{124682,9.3},{115294,2.7},{116680,2.7},{115175,2.4},{116849,1.1},{109132,0.7},{322118,0.6},{115450,0.6},{1291894,0.6},{443028,0.6},{115203,0.4} }, -- Vivify, Rushing Wind Kick, Renewing Mist, Enveloping Mist, Mana Tea, Thunder Focus Tea, Soothing Mist, Life Cocoon, Roll, Invoke Yu'lon, the Jade Serpent, Detox, Soulcoiler Ritual Vessel, Celestial Conduit, Fortifying Brew
      watch={ {115867,97.3},{1244617,61.8},{443569,55.5},{392883,47.1},{1260670,45.7},{443421,35.4},{414143,32.4},{1260565,32.1},{443112,28.1},{443576,25.1} }, -- Mana Tea, Void Glass, Chi-Ji's Swiftness, Vivacious Vivification, Spiritfont, Heart of the Jade Serpent, Yu'lon's Grace, Spiritfont, Strength of the Black Ox, Serpent Stance
    },
    mplus={
      n=8, dur=1777,
      core={ {107428,16.2},{101546,8.0},{100784,6.2},{100780,6.2},{124682,2.9},{116680,2.2},{115151,2.0},{399491,1.3},{109132,1.1},{115175,1.1},{115294,0.9},{325197,0.7},{115450,0.6},{116849,0.5} }, -- Rising Sun Kick, Spinning Crane Kick, Blackout Kick, Tiger Palm, Enveloping Mist, Thunder Focus Tea, Renewing Mist, Sheilun's Gift, Roll, Soothing Mist, Mana Tea, Invoke Chi-Ji, the Red Crane, Detox, Life Cocoon
      watch={ {115867,96.2},{399510,89.3},{399497,89.2},{392883,86.9},{414143,72.8},{1260565,65.9},{1244617,54.0},{202090,47.1},{443112,42.8},{1260670,33.2} }, -- Mana Tea, Sheilun's Gift, Sheilun's Gift, Vivacious Vivification, Yu'lon's Grace, Spiritfont, Void Glass, Teachings of the Monastery, Strength of the Black Ox, Spiritfont
    },
  },
  ["MONK/WINDWALKER"] = {
    specID=269,
    raid={
      n=5, dur=367, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Lây", server="Twisting Nether", region="EU", seq={109132,100780,123904,1297761,1249625,113656,107428,152175,113656,101546,107428,100784,113656,101546,443028} },
        { player="Styphi", server="Illidan", region="US", seq={100780,1250533,123904,1249625,113656,107428,152175,113656,101546,393056,107428,100784,467307,113656,101546} },
        { player="Sîp", server="Ravencrest", region="EU", seq={100780,123904,1297761,1249625,113656,101546,107428,152175,113656,101546,107428,100784,113656,467307,100780} },
      },
      core={ {100780,11.0},{100784,7.8},{107428,7.6},{101546,6.9},{113656,6.4},{467307,2.7},{152175,2.3},{1249625,0.9},{123904,0.7},{443028,0.7},{443591,0.7},{109132,0.6},{122470,0.6},{116841,0.5} }, -- Tiger Palm, Blackout Kick, Rising Sun Kick, Spinning Crane Kick, Fists of Fury, Rushing Wind Kick, Whirling Dragon Punch, Zenith, Invoke Xuen, the White Tiger, Celestial Conduit, Unity Within, Roll, Touch of Karma, Tiger's Lust
      watch={ {451298,74.4},{202090,73.3},{196742,47.3},{443569,42.3},{1297033,31.2},{129914,29.1},{1249625,28.2},{414143,27.0},{443574,25.5},{443575,25.4} }, -- Momentum Boost, Teachings of the Monastery, Whirling Dragon Punch, Chi-Ji's Swiftness, Unbroken Rhythm, Combat Wisdom, Zenith, Yu'lon's Grace, Ox Stance, Tiger Stance
    },
    mplus={
      n=8, dur=1748,
      core={ {100780,9.6},{101546,8.6},{107428,5.9},{113656,5.6},{100784,4.8},{467307,2.0},{152175,1.9},{1272696,1.6},{109132,1.0},{1249625,0.8},{123904,0.6},{443028,0.6},{122470,0.4},{322109,0.3} }, -- Tiger Palm, Spinning Crane Kick, Rising Sun Kick, Fists of Fury, Blackout Kick, Rushing Wind Kick, Whirling Dragon Punch, Zenith Stomp, Roll, Zenith, Invoke Xuen, the White Tiger, Celestial Conduit, Touch of Karma, Touch of Death
      watch={ {196741,97.1},{392883,88.8},{1248705,86.8},{202090,77.8},{414143,69.6},{451298,67.2},{129914,39.5},{196742,37.0},{443569,34.8},{116768,34.3} }, -- Hit Combo, Vivacious Vivification, Skyfire Heel, Teachings of the Monastery, Yu'lon's Grace, Momentum Boost, Combat Wisdom, Whirling Dragon Punch, Chi-Ji's Swiftness, Blackout Kick!
    },
  },
  ["PALADIN/HOLY"] = {
    specID=65,
    raid={
      n=5, dur=409, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="kwangkwangseong", server="ajeusyara", region="KR", seq={275773,20473,20473,156322,1291894,20473,275773,275773,20473,20473,275773,31884,156322,20473,20473} },
        { player="Deesee", server="Tarren Mill", region="EU", seq={1291894,1236616,31884,200025,375576,85222,85222,20473,20473,85222,1241413,19750,19750,20473,85222} },
        { player="Deepressed", server="Blackhand", region="EU", seq={275773,1291894,20473,275773,85222,20473,275773,85222,20473,275773,20473,85222,20473,275773,20473} },
      },
      core={ {20473,14.0},{156322,13.5},{19750,9.0},{200025,3.6},{275773,2.8},{375576,1.7},{85222,1.3},{190784,0.9},{1241413,0.7},{498,0.7},{4987,0.7},{1291894,0.6},{31884,0.6} }, -- Holy Shock, Eternal Flame, Flash of Light, Beacon of Virtue, Judgment, Divine Toll, Light of Dawn, Divine Steed, Hammer of Wrath, Divine Protection, Cleanse, Soulcoiler Ritual Vessel, Avenging Wrath
      watch={ {447988,86.3},{448087,72.7},{54149,46.6},{1241410,25.5},{1264050,25.3},{31884,25.3},{431415,17.4} }, -- Light of the Martyr, Bestow Light, Infusion of Light, Hammer of Wrath, Born in Sunlight, Avenging Wrath, Sun Sear
    },
    mplus={
      n=8, dur=1812,
      core={ {20473,9.2},{156322,8.4},{415091,6.6},{275773,6.2},{19750,5.7},{200025,2.4},{1241413,1.7},{82326,1.5},{375576,1.2},{4987,0.7},{498,0.6},{31884,0.5},{190784,0.5},{1291894,0.4} }, -- Holy Shock, Eternal Flame, Shield of the Righteous, Judgment, Flash of Light, Beacon of Virtue, Hammer of Wrath, Holy Light, Divine Toll, Cleanse, Divine Protection, Avenging Wrath, Divine Steed, Soulcoiler Ritual Vessel
      watch={ {54149,45.7},{1264050,19.4},{1241410,18.9},{31884,18.9},{223819,18.4} }, -- Infusion of Light, Born in Sunlight, Hammer of Wrath, Avenging Wrath, Divine Purpose
    },
  },
  ["PALADIN/PROTECTION"] = {
    specID=66,
    raid={
      n=5, dur=402, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Chaddopala", server="Ysondre", region="EU", seq={31935,1236616,389539,1293316,375576,53600,1241413,1241413,432459,432472,1241413,53600,26573,204019,204019} },
        { player="Denerocx", server="Twisting Nether", region="EU", seq={389539,375576,1236616,53600,1241413,53600,31935,53600,1241413,1241413,31935,53600,204019,53600,1241413} },
        { player="Vivipld", server="Sylvanas", region="EU", seq={31935,26573,1297908,275779,1236616,389539,375576,53600,53600,1241413,31935,53600,1241413,204019,53600} },
      },
      core={ {53600,17.8},{204019,13.5},{275779,11.3},{31935,6.7},{1241413,6.0},{26573,4.9},{85673,2.7},{389539,1.0},{375576,1.0},{190784,0.8},{31850,0.7},{432472,0.6},{432459,0.6},{86659,0.4} }, -- Shield of the Righteous, Blessed Hammer, Judgment, Avenger's Shield, Hammer of Wrath, Consecration, Word of Glory, Sentinel, Divine Toll, Divine Steed, Ardent Defender, Sacred Weapon, Holy Bulwark, Guardian of Ancient Kings
      watch={ {132403,92.3},{327510,91.9},{188370,86.9},{379017,79.4},{460822,75.9},{182104,67.3},{432496,33.9},{386652,32.7},{1277026,30.4},{389539,30.4} }, -- Shield of the Righteous, Shining Light, Consecration, Faith's Armor, Divine Guidance, Shining Light, Holy Bulwark, Bulwark of Righteous Fury, Hammer of Wrath, Sentinel
    },
    mplus={
      n=8, dur=1779,
      core={ {53600,19.1},{204019,13.1},{275779,10.9},{31935,7.4},{1241413,5.7},{26573,4.0},{85673,2.5},{204079,1.0},{190784,0.9},{389539,0.9},{375576,0.8},{31850,0.7},{432472,0.6},{432459,0.6} }, -- Shield of the Righteous, Blessed Hammer, Judgment, Avenger's Shield, Hammer of Wrath, Consecration, Word of Glory, Final Stand, Divine Steed, Sentinel, Divine Toll, Ardent Defender, Sacred Weapon, Holy Bulwark
      watch={ {132403,95.3},{393038,94.2},{327510,93.3},{379017,81.9},{460822,80.7},{188370,79.2},{182104,66.3},{378412,31.6},{432496,30.5},{85416,28.6} }, -- Shield of the Righteous, Strength in Adversity, Shining Light, Faith's Armor, Divine Guidance, Consecration, Shining Light, Light of the Titans, Holy Bulwark, Grand Crusader
    },
  },
  ["PALADIN/RETRIBUTION"] = {
    specID=70,
    raid={
      n=5, dur=412, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="choego", server="ajeusyara", region="KR", seq={184575,190784,1297761,31884,343527,408385,408385,383328,408385,255937,383328,408385,53385,408385,375576} },
        { player="wipungdaengdaeng", server="ajeusyara", region="KR", seq={184575,1236616,1293316,408385,343527,31884,255937,408385,383328,408385,383328,408385,383328,53385,408385} },
        { player="Imlk", server="Illidan", region="US", seq={184575,1297761,31884,255937,408385,408385,383328,408385,383328,343527,408385,375576,383328,408385,24275} },
      },
      core={ {408385,39.9},{383328,18.0},{53385,10.3},{184575,6.5},{24275,5.5},{20271,5.2},{255937,1.9},{375576,1.0},{31884,1.0},{343527,1.0},{190784,0.9},{403876,0.9} }, -- Crusading Strikes, Final Verdict, Divine Storm, Blade of Justice, Hammer of Wrath, Judgment, Wake of Ashes, Divine Toll, Avenging Wrath, Execution Sentence, Divine Steed, Divine Protection
      watch={ {407065,90.9},{1305230,83.5},{1241410,40.4},{31884,40.4},{1264050,40.4},{406086,27.6},{1252818,25.0},{1297761,17.9},{408458,17.7},{1234189,16.8} }, -- Rush of Light, Divine Power, Hammer of Wrath, Avenging Wrath, Born in Sunlight, Art of War, Akil'zon's Cry of Victory, Voracious Heart of Ula'tek, Divine Purpose, Execution Sentence
    },
    mplus={
      n=8, dur=1752,
      core={ {408385,45.1},{53385,12.7},{383328,12.3},{184575,6.2},{20271,5.2},{24275,4.2},{255937,1.7},{375576,0.8},{343527,0.8},{345228,0.8},{31884,0.8},{156322,0.5},{403876,0.5},{190784,0.5} }, -- Crusading Strikes, Divine Storm, Final Verdict, Blade of Justice, Judgment, Hammer of Wrath, Wake of Ashes, Divine Toll, Execution Sentence, Gladiator's Badge, Avenging Wrath, Eternal Flame, Divine Protection, Divine Steed
      watch={ {407065,88.8},{1305230,79.9},{1241410,32.1},{31884,32.1},{1264050,31.7},{406086,22.8},{345228,19.6},{431522,17.9},{408458,17.8} }, -- Rush of Light, Divine Power, Hammer of Wrath, Avenging Wrath, Born in Sunlight, Art of War, Gladiator's Badge, Dawnlight, Divine Purpose
    },
  },
  ["PRIEST/DISCIPLINE"] = {
    specID=256,
    raid={
      n=5, dur=407, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="马玲", server="菲拉斯", region="CN", seq={589,10060,10060,194509,8092,47540,1253593,450215,450215,450215,47540,450215,1253593,450215,450215} },
        { player="Niofea", server="Draenor", region="EU", seq={585,589,8092,47540,1253593,450215,1295885,450215,450215,450215,47540,10060,10060,1253593,450215} },
        { player="Mheeveon", server="Proudmoore", region="US", seq={589,10060,10060,8092,1253593,47540,450215,450215,17,450215,450215,47540,450215,450215,1253593} },
      },
      core={ {585,24.1},{47540,9.0},{1253593,6.5},{8092,4.3},{194509,4.0},{2061,3.2},{17,2.2},{1295885,1.6},{10060,1.2},{586,1.0},{589,0.9},{527,0.7},{472433,0.7},{121536,0.6} }, -- Smite, Penance, Void Shield, Mind Blast, Power Word: Radiance, Flash Heal, Power Word: Shield, Hex Lord's Doom, Power Infusion, Fade, Shadow Word: Pain, Purify, Evangelism, Angelic Feather
      watch={ {1307470,91.4},{1253725,81.2},{450193,74.5},{1295885,74.0},{1241762,63.5},{390692,57.7},{114255,53.6},{193065,48.4},{1305360,45.6},{1235193,45.5} }, -- Hex Lord's Doom, Greater Smite, Entropic Rift, Hex Lord's Doom, Frenzied Focus, Borrowed Time, Surge of Light, Protective Light, Soul Fang Alacrity, Holy Ray
    },
    mplus={
      n=8, dur=1767,
      core={ {585,12.1},{47540,8.9},{1253593,5.2},{186263,4.8},{8092,3.0},{17,1.8},{589,1.5},{194509,1.5},{32379,1.2},{586,1.0},{10060,0.8},{121536,0.8},{472433,0.5},{527,0.5} }, -- Smite, Penance, Void Shield, Shadow Mend, Mind Blast, Power Word: Shield, Shadow Word: Pain, Power Word: Radiance, Shadow Word: Death, Fade, Power Infusion, Angelic Feather, Evangelism, Purify
      watch={ {472433,57.4},{390978,53.9},{193065,53.4},{390787,51.6},{390692,48.5},{1235193,46.8},{1253593,35.8},{114255,32.6},{1253591,29.6},{198069,22.3} }, -- Evangelism, Twist of Fate, Protective Light, Weal and Woe, Borrowed Time, Holy Ray, Void Shield, Surge of Light, Master the Darkness, Power of the Dark Side
    },
  },
  ["PRIEST/HOLY"] = {
    specID=257,
    raid={
      n=5, dur=415, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="muhoheubhilking", server="ajeusyara", region="KR", seq={2061,2061,33076,586,19236,2050,1262763,1291894,2061,2061,33076,2061,2061,121536,2050} },
        { player="Vikt", server="白银之手", region="CN", seq={14914,585,33076,2050,585,33076,585,585,2050,585,33076,1250533,200183,2050,1262763} },
        { player="Ragrappy", server="Stormreaver", region="US", seq={14914,10060,10060,1291894,2050,33076,1262763,33076,2050,1262763,2061,2061,33076,2061,1262763} },
      },
      core={ {1262763,14.4},{2061,9.0},{2050,8.4},{33076,7.0},{586,1.6},{121536,1.3},{585,1.2},{10060,1.1},{527,0.7},{1291894,0.7},{19236,0.6},{200183,0.6},{64843,0.4} }, -- Benediction, Flash Heal, Holy Word: Serenity, Prayer of Mending, Fade, Angelic Feather, Smite, Power Infusion, Purify, Soulcoiler Ritual Vessel, Desperate Prayer, Apotheosis, Divine Hymn
      watch={ {193065,97.0},{1262766,62.9},{200183,30.6},{586,26.4},{390978,15.6} }, -- Protective Light, Benediction, Apotheosis, Fade, Twist of Fate
    },
    mplus={
      n=8, dur=1831,
      core={ {33076,8.4},{1262763,8.3},{14914,7.0},{2050,5.1},{2061,4.6},{585,3.2},{88625,2.4},{586,1.3},{121536,1.2},{10060,0.9},{527,0.5},{1291894,0.5},{132157,0.5},{200183,0.4} }, -- Prayer of Mending, Benediction, Holy Fire, Holy Word: Serenity, Flash Heal, Smite, Holy Word: Chastise, Fade, Angelic Feather, Power Infusion, Purify, Soulcoiler Ritual Vessel, Holy Nova, Apotheosis
      watch={ {1306118,96.8},{193065,83.9},{1262766,62.2},{390978,46.2},{372617,25.6},{586,21.3},{200183,17.0} }, -- Renewed Vigor, Protective Light, Benediction, Twist of Fate, Empyreal Blaze, Fade, Apotheosis
    },
  },
  ["PRIEST/SHADOW"] = {
    specID=258,
    raid={
      n=5, dur=374, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Grendini", server="Kazzak", region="EU", seq={8092,1227280,589,589,120644,1242173,228260,15286,10060,10060,65008,335467,8092,1227280,391403} },
        { player="Oblivionis", server="伊瑟拉", region="CN", seq={8092,1227280,589,589,120644,1242173,228260,10060,1250533,10060,15286,391403,8092,1227280,335467} },
        { player="Snowgigarat", server="Stormrage", region="US", seq={8092,1227280,589,589,1242173,120644,228260,15286,1250533,10060,10060,1227280,8092,335467,391403} },
      },
      core={ {335467,8.8},{15407,6.9},{1242173,6.6},{8092,6.4},{1227280,5.0},{391403,4.1},{589,3.8},{586,1.2},{34914,1.2},{32379,1.0},{120644,1.0},{17,1.0},{10060,1.0},{121536,0.9} }, -- Shadow Word: Madness, Mind Flay, Void Volley, Mind Blast, Tentacle Slam, Mind Flay: Insanity, Shadow Word: Pain, Fade, Vampiric Touch, Shadow Word: Death, Halo, Power Word: Shield, Power Infusion, Angelic Feather
      watch={ {373213,88.0},{373277,72.4},{391092,70.5},{232698,70.4},{393919,69.0},{390978,51.8},{454002,50.4},{453850,41.4},{194249,29.0},{453113,25.9} }, -- Insidious Ire, Thing from Beyond, Shattered Psyche, Shadowform, Screams of the Void, Twist of Fate, Sustained Potency, Resonant Energy, Voidform, Power Surge
    },
    mplus={
      n=8, dur=1758,
      core={ {335467,8.3},{1242173,6.2},{15407,5.8},{8092,5.7},{589,5.0},{1227280,4.6},{586,1.7},{263165,1.7},{32379,1.2},{17,1.1},{10060,0.9},{2061,0.6},{15286,0.4},{228260,0.4} }, -- Shadow Word: Madness, Void Volley, Mind Flay, Mind Blast, Shadow Word: Pain, Tentacle Slam, Fade, Void Torrent, Shadow Word: Death, Power Word: Shield, Power Infusion, Flash Heal, Vampiric Embrace, Voidform
      watch={ {373213,81.2},{232698,78.7},{373277,78.0},{393919,64.6},{449887,59.4},{390978,59.2},{377066,51.8},{450193,36.6},{586,28.4},{375981,27.1} }, -- Insidious Ire, Shadowform, Thing from Beyond, Screams of the Void, Voidheart, Twist of Fate, Mental Fortitude, Entropic Rift, Fade, Shadowy Insight
    },
  },
  ["ROGUE/ASSASSINATION"] = {
    specID=259,
    raid={
      n=5, dur=410, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Uwucutegirl", server="Silvermoon", region="EU", seq={703,51723,1943,703,27576,1329,27576,1329,32645,1297761,360194,385627,1856,32645,27576} },
        { player="gaejongmin", server="ajeusyara", region="KR", seq={703,27576,1329,1943,27576,1329,27576,1329,32645,1297761,360194,385627,32645,1856,703} },
        { player="Tenrakú", server="Illidan", region="US", seq={703,27576,1329,1943,27576,1329,27576,1329,32645,272071,1297761,360194,385627,32645,27576} },
      },
      core={ {1329,20.2},{32645,12.3},{703,3.0},{1943,2.4},{51723,1.6},{1247227,1.5},{1966,1.0},{385627,1.0},{36554,0.7},{360194,0.6},{1856,0.6},{381623,0.6},{185311,0.4},{2983,0.4} }, -- Mutilate, Envenom, Garrote, Rupture, Fan of Knives, Crimson Tempest, Feint, Kingsbane, Shadowstep, Deathmark, Vanish, Thistle Tea, Crimson Vial, Sprint
      watch={ {32645,82.7},{1264297,68.3},{452923,59.4},{1249093,54.1},{452917,42.3},{1248971,36.4},{1250331,29.4},{394095,23.3},{385627,23.3},{1297761,18.9} }, -- Envenom, Cold Blood, Fatebound Coin (Heads), Fatebound Coin Flips, Fatebound Coin (Tails), Lucky Coin, Regicide's Reward, Kingsbane, Kingsbane, Voracious Heart of Ula'tek
    },
    mplus={
      n=8, dur=1762,
      core={ {32645,12.8},{51723,9.9},{1329,6.4},{1247227,6.3},{703,2.7},{1943,2.3},{1966,2.2},{1298826,1.0},{385627,0.9},{185311,0.7},{57934,0.5},{36554,0.5},{360194,0.5},{1856,0.4} }, -- Envenom, Fan of Knives, Mutilate, Crimson Tempest, Garrote, Rupture, Feint, Thistle Tea, Kingsbane, Crimson Vial, Tricks of the Trade, Shadowstep, Deathmark, Vanish
      watch={ {315496,96.7},{394080,88.2},{32645,76.8},{1264297,64.5},{452923,48.8},{1249093,47.7},{452917,42.3},{1248971,34.8},{1966,21.2},{394095,20.1} }, -- Slice and Dice, Scent of Blood, Envenom, Cold Blood, Fatebound Coin (Heads), Fatebound Coin Flips, Fatebound Coin (Tails), Lucky Coin, Feint, Kingsbane
    },
  },
  ["ROGUE/OUTLAW"] = {
    specID=260,
    raid={
      n=5, dur=412, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Slythr", server="Area 52", region="US", seq={13750,1214909,381989,1236616,315341,193315,51690,315341,1277933,185763,185763,185763,315341,193315,315341} },
        { player="千丶一", server="白银之手", region="CN", seq={2983,193315,2098,13750,1297761,1214909,1236616,381989,315341,193315,51690,1277933,315341,193315,315341} },
        { player="边缘之锋", server="奥尔加隆", region="CN", seq={13750,1214909,1236616,315341,51690,2098,193315,193315,315341,1277933,185763,185763,185763,193315,315341} },
      },
      core={ {185763,27.2},{193315,16.2},{315341,12.3},{2098,10.0},{441776,2.8},{13877,2.1},{51690,1.9},{13750,1.8},{2983,1.6},{1214909,1.5},{1966,1.0},{195457,0.8},{381989,0.7},{31224,0.3} }, -- Pistol Shot, Sinister Strike, Between the Eyes, Dispatch, Coup de Grace, Blade Flurry, Killing Spree, Adrenaline Rush, Sprint, Roll the Bones, Feint, Grappling Hook, Keep It Rolling, Cloak of Shadows
      watch={ {455144,96.7},{441326,93.2},{1265931,91.8},{1259486,82.6},{441786,71.1},{1214909,60.9},{195627,60.0},{1214937,51.9},{13750,46.0},{256171,45.4} }, -- Acrobatic Strikes, Flawless Form, Palmed Bullets, Zero In, Escalating Blade, Roll the Bones, Opportunity, Jackpot, Adrenaline Rush, Loaded Dice
    },
    mplus={
      n=8, dur=1795,
      core={ {185763,20.5},{193315,12.8},{315341,11.0},{2098,9.4},{13877,4.5},{271877,3.8},{441776,2.6},{1966,2.2},{2983,2.0},{51690,1.7},{13750,1.7},{1214909,1.4},{195457,0.8},{381989,0.7} }, -- Pistol Shot, Sinister Strike, Between the Eyes, Dispatch, Blade Flurry, Blade Rush, Coup de Grace, Feint, Sprint, Killing Spree, Adrenaline Rush, Roll the Bones, Grappling Hook, Keep It Rolling
      watch={ {315341,93.5},{455144,89.1},{441326,88.9},{1265931,88.5},{1287770,81.9},{441786,70.0},{13877,67.7},{1214909,59.9},{256171,51.5},{195627,50.5} }, -- Between the Eyes, Acrobatic Strikes, Flawless Form, Palmed Bullets, Rune of the Versatile Warrior, Escalating Blade, Blade Flurry, Roll the Bones, Loaded Dice, Opportunity
    },
  },
  ["ROGUE/SUBTLETY"] = {
    specID=261,
    raid={
      n=5, dur=402, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Jskr", server="Outland", region="EU", seq={185438,196819,1856,185438,426591,196819,185313,212743,197835,1236616,1297761,121471,280719,282449,282449} },
        { player="Parse", server="Tichondrius", region="US", seq={1234969,185438,196819,1297761,121471,185313,426591,280719,282449,185438,282449,196819,185438,196819,196819} },
        { player="贯一", server="死亡之翼", region="CN", seq={185438,196819,1856,185438,196819,1297761,121471,185313,426591,196819,280719,282449,185438,282449,196819} },
      },
      core={ {196819,20.0},{53,9.6},{185438,7.6},{197835,4.9},{319175,3.5},{185313,3.1},{1966,1.2},{426591,1.2},{121471,0.7},{185311,0.6},{1293340,0.4},{1856,0.4} }, -- Eviscerate, Backstab, Shadowstrike, Shuriken Storm, Black Powder, Shadow Dance, Feint, Goremaw's Bite, Shadow Blades, Crimson Vial, Mark for Death, Vanish
      watch={ {196911,96.6},{1264521,94.8},{1248775,84.6},{385960,74.7},{385727,58.7},{112942,45.9},{185422,45.6},{386237,44.5},{457280,36.6},{457115,34.5} }, -- Shadow Techniques, Find Weakness, Unshakeable Drive, Lingering Shadow, Silent Storm, Shadow Focus, Shadow Dance, Fade to Nothing, Darkest Night, Momentum of Despair
    },
    mplus={
      n=8, dur=1692,
      core={ {197835,11.6},{319175,11.4},{196819,11.4},{53,3.7},{185313,2.8},{185438,2.7},{1966,2.4},{426591,1.1},{121471,0.6},{57934,0.5},{36554,0.5},{1784,0.3},{2983,0.3} }, -- Shuriken Storm, Black Powder, Eviscerate, Backstab, Shadow Dance, Shadowstrike, Feint, Goremaw's Bite, Shadow Blades, Tricks of the Trade, Shadowstep, Stealth, Sprint
      watch={ {1264521,89.4},{1248775,84.3},{385960,72.0},{457115,69.4},{428488,45.9},{386237,43.2},{112942,42.9},{1264297,39.8},{185422,37.9},{457280,35.0} }, -- Find Weakness, Unshakeable Drive, Lingering Shadow, Momentum of Despair, Exhilarating Execution, Fade to Nothing, Shadow Focus, Cold Blood, Shadow Dance, Darkest Night
    },
  },
  ["SHAMAN/ELEMENTAL"] = {
    specID=262,
    raid={
      n=5, dur=401, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="今晚吃什么呢", server="铜龙军团", region="CN", seq={191634,32182,114050,1293316,1236616,443454,51505,188196,51505,188196,51505,117014,51505,188196,188196} },
        { player="Divesham", server="Emerald Dream", region="US", seq={51505,114050,1293316,1236616,443454,51505,188196,51505,188196,51505,117014,188196,51505,188196,188196} },
        { player="小奈电下", server="无尽之海", region="CN", seq={191634,443454,1250533,1236616,114050,188196,188196,51505,188196,51505,117014,188196,51505,188196,51505} },
      },
      core={ {188196,14.2},{51505,12.4},{117014,7.2},{188389,3.9},{188443,3.9},{443454,1.9},{191634,1.3},{79206,0.7},{2645,0.6},{114050,0.5},{108271,0.3} }, -- Lightning Bolt, Lava Burst, Elemental Blast, Flame Shock, Chain Lightning, Ancestral Swiftness, Stormkeeper, Spiritwalker's Grace, Ghost Wolf, Ascendance, Astral Shift
      watch={ {173184,84.7},{173183,84.6},{118522,83.4},{447244,68.5},{260734,37.0},{263806,24.4},{79206,23.5},{77762,19.6},{1239091,17.6},{1292300,17.3} }, -- Elemental Blast: Mastery, Elemental Blast: Haste, Elemental Blast: Critical Strike, Call of the Ancestors, Master of the Elements, Wind Gust, Spiritwalker's Grace, Lava Surge, Lesser Weapon, Brittle Torga Totem
    },
    mplus={
      n=8, dur=1775,
      core={ {188443,9.3},{51505,8.8},{61882,6.2},{470057,5.5},{188196,5.1},{117014,3.6},{443454,1.7},{191634,1.3},{2645,0.5},{114050,0.4},{79206,0.4},{108271,0.3} }, -- Chain Lightning, Lava Burst, Earthquake, Voltaic Blaze, Lightning Bolt, Elemental Blast, Ancestral Swiftness, Stormkeeper, Ghost Wolf, Ascendance, Spiritwalker's Grace, Astral Shift
      watch={ {447244,67.0},{173184,59.6},{118522,59.1},{173183,58.8},{77762,31.0},{260734,27.7},{1259491,27.1},{355634,25.4},{263806,18.2},{1292300,18.0} }, -- Call of the Ancestors, Elemental Blast: Mastery, Elemental Blast: Critical Strike, Elemental Blast: Haste, Lava Surge, Master of the Elements, Purging Flames, Windveil, Wind Gust, Brittle Torga Totem
    },
  },
  ["SHAMAN/ENHANCEMENT"] = {
    specID=263,
    raid={
      n=5, dur=419, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Werdup", server="Sunstrider", region="EU", seq={470057,2825,17364,17364,188196,17364,187874,114051,1297761,452201,115356,469270,188196,115356,469270} },
        { player="Totemtickler", server="Ravencrest", region="EU", seq={470057,58875,187874,1297761,114051,452201,115356,469270,452201,115356,469270,188196,115356,469270,188196} },
        { player="Smargenrog", server="Burning Blade", region="US", seq={470057,17364,1297761,114051,452201,115356,469270,452201,115356,469270,187874,469270,188196,187874,469270} },
      },
      core={ {17364,15.0},{188196,10.6},{469270,10.1},{187874,9.3},{115356,5.5},{470057,5.4},{452201,4.9},{188443,3.9},{60103,1.6},{2645,0.7},{8004,0.7},{114051,0.6},{108271,0.4} }, -- Stormstrike, Lightning Bolt, Doom Winds, Crash Lightning, Windstrike, Voltaic Blaze, Tempest, Chain Lightning, Lava Lash, Ghost Wolf, Healing Surge, Ascendance, Astral Shift
      watch={ {410681,97.4},{382889,97.1},{1252415,93.2},{344179,85.8},{454394,81.7},{1299991,68.7},{455089,43.2},{470466,36.2},{454025,34.2},{201846,32.1} }, -- Overflowing Maelstrom, Flurry, Crash Lightning, Maelstrom Weapon, Unlimited Power, Short Circuit, Storm Swell, Stormblast, Electroshock, Stormsurge
    },
    mplus={
      n=8, dur=1716,
      core={ {17364,14.3},{469270,9.8},{187874,9.0},{188443,8.5},{470057,4.7},{452201,4.6},{115356,4.4},{188196,4.1},{60103,1.6},{2645,0.5},{114051,0.5},{108271,0.3} }, -- Stormstrike, Doom Winds, Crash Lightning, Chain Lightning, Voltaic Blaze, Tempest, Windstrike, Lightning Bolt, Lava Lash, Ghost Wolf, Ascendance, Astral Shift
      watch={ {410681,95.2},{382889,92.0},{1252415,88.6},{344179,86.5},{454394,79.4},{1299991,57.4},{384451,36.5},{470466,33.2},{454025,32.1},{198300,29.4} }, -- Overflowing Maelstrom, Flurry, Crash Lightning, Maelstrom Weapon, Unlimited Power, Short Circuit, Lightning Strikes, Stormblast, Electroshock, Converging Storms
    },
  },
  ["SHAMAN/RESTORATION"] = {
    specID=264,
    raid={
      n=5, dur=413, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Sliskéh", server="Tarren Mill", region="EU", seq={61295,61295,444995,1291894,61295,188389,470411,1267068,1064,5394,1064,188196,61295,188196,188196} },
        { player="eolgulijjeoeobing", server="ajeusyara", region="KR", seq={32182,61295,188389,470411,51505,61295,77472,77472,77472,61295,77472,51505,444995,61295,77472} },
        { player="Scynical", server="Proudmoore", region="US", seq={444995,5394,1064,61295,188389,470411,51505,51505,188196,188196,61295,61295,5394,1064,188196} },
      },
      core={ {1064,17.4},{61295,11.5},{77472,3.6},{5394,3.6},{444995,2.2},{1267068,1.7},{108287,1.5},{378081,1.0},{77130,0.9},{2645,0.9},{51505,0.8},{188389,0.6},{188196,0.6},{79206,0.5} }, -- Chain Heal, Riptide, Healing Wave, Healing Stream Totem, Surging Totem, Stormstream Totem, Totemic Projection, Nature's Swiftness, Purify Spirit, Ghost Wolf, Lava Burst, Flame Shock, Lightning Bolt, Spiritwalker's Grace
      watch={ {456369,91.8},{1307888,90.2},{53390,68.6},{453407,57.4},{470077,51.8},{114052,21.7},{453409,15.8} }, -- Amplification Core, Healing Rain, Tidal Waves, Whirling Water, Coalescing Water, Ascendance, Whirling Air
    },
    mplus={
      n=8, dur=1794,
      core={ {61295,8.1},{1064,8.0},{77472,4.7},{5394,2.8},{188443,2.3},{51505,2.2},{73685,2.1},{444995,2.0},{108287,1.6},{188389,1.5},{1267068,1.4},{378081,0.9},{2645,0.7},{188196,0.6} }, -- Riptide, Chain Heal, Healing Wave, Healing Stream Totem, Chain Lightning, Lava Burst, Unleash Life, Surging Totem, Totemic Projection, Flame Shock, Stormstream Totem, Nature's Swiftness, Ghost Wolf, Lightning Bolt
      watch={ {456369,82.8},{1307888,81.9},{53390,69.9},{470077,46.2},{453407,37.5},{453409,21.9},{453406,20.4},{1267089,18.9},{77762,16.4} }, -- Amplification Core, Healing Rain, Tidal Waves, Coalescing Water, Whirling Water, Whirling Air, Whirling Earth, Stormstream Totem, Lava Surge
    },
  },
  ["WARLOCK/AFFLICTION"] = {
    specID=265,
    raid={
      n=5, dur=405, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Kwrhimom", server="Zul'jin", region="US", seq={980,445468,445468,1259790,1257052,1295275,1236616,205180,442726,1259790,1259790,1259790,1259790,1261153,980} },
        { player="Pfw", server="Mal'Ganis", region="US", seq={48181,980,445468,445468,442726,1236616,1250508,1257052,205180,1259790,1259790,1259790,1259790,1259790,1259790} },
        { player="Maddino", server="Ragnaros", region="EU", seq={980,445468,445468,48181,1257052,442726,1293316,1236616,205180,1259790,1259790,1259790,1259790,1259790,1259790} },
      },
      core={ {1259790,16.5},{980,11.7},{686,10.1},{48181,3.2},{1261153,2.5},{445468,1.3},{1257052,1.3},{442726,1.0},{111400,0.9},{108416,0.6},{205180,0.6},{6789,0.4},{385899,0.3} }, -- Unstable Affliction, Agony, Shadow Bolt, Haunt, Malefic Grasp, Wither, Dark Harvest, Malevolence, Burning Rush, Dark Pact, Summon Darkglare, Mortal Coil, Soulburn
      watch={ {1261125,87.6},{1305774,82.9},{108366,65.0},{442726,51.5},{264571,23.4},{205180,21.9},{1260269,18.1} }, -- Cascading Calamity, Unstable Empowerment, Soul Leech, Malevolence, Nightfall, Summon Darkglare, Shard Instability
    },
    mplus={
      n=8, dur=1703,
      core={ {27243,11.0},{686,9.7},{980,7.1},{1259790,5.8},{48181,3.1},{1261153,2.1},{1257052,1.2},{108416,0.7},{1714,0.5},{172,0.4},{205180,0.4} }, -- Seed of Corruption, Shadow Bolt, Agony, Unstable Affliction, Haunt, Malefic Grasp, Dark Harvest, Dark Pact, Curse of Tongues, Corruption, Summon Darkglare
      watch={ {108446,96.6},{1261125,88.7},{108366,82.3},{1305774,80.1},{48018,61.8},{264571,37.0},{449793,36.3},{205180,17.4},{1269042,17.0} }, -- Soul Link, Cascading Calamity, Soul Leech, Unstable Empowerment, Demonic Circle, Nightfall, Succulent Soul, Summon Darkglare, Manifested Demonic Soul
    },
  },
  ["WARLOCK/DEMONOLOGY"] = {
    specID=266,
    raid={
      n=5, dur=410, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="埃索达尔", server="冰风岗", region="CN", seq={264178,104316,265187,1276452,686,1293316,1236616,105174,686,105174,686,196277,686,686,105174} },
        { player="Zabl", server="Sargeras", region="US", seq={264178,1276452,104316,686,265187,1236616,1250533,105174,105174,686,196277,686,686,686,105174} },
        { player="Jimmbosoul", server="Kazzak", region="EU", seq={264178,1276452,686,104316,265187,1236616,1250533,105174,105174,686,196277,686,108416,105174,686} },
      },
      core={ {105174,14.2},{264178,10.2},{686,9.7},{196277,3.1},{104316,2.9},{434635,1.5},{265187,1.0},{108416,0.6},{1276452,0.6},{111400,0.6} }, -- Hand of Gul'dan, Demonbolt, Shadow Bolt, Implosion, Call Dreadstalkers, Ruination, Summon Demonic Tyrant, Dark Pact, Grimoire: Imp Lord, Burning Rush
      watch={ {1281559,97.4},{1276623,92.5},{264173,73.9},{1269879,71.9},{108366,69.8},{1269643,61.9},{1276166,40.0},{456323,32.8},{265187,32.8},{1276767,32.8} }, -- Hellbent Commander, Singe Magic, Demonic Core, Mind's Eyes, Soul Leech, Demonic Oculi, Dominion of Argus, Abyssal Dominion, Summon Demonic Tyrant, Tyrant's Oblation
    },
    mplus={
      n=8, dur=1745,
      core={ {105174,13.0},{264178,9.2},{686,8.4},{196277,3.0},{104316,2.7},{1263768,1.6},{434635,1.4},{265187,0.9},{119910,0.8},{385899,0.7},{108416,0.7},{1276452,0.5},{111400,0.4},{1714,0.4} }, -- Hand of Gul'dan, Demonbolt, Shadow Bolt, Implosion, Call Dreadstalkers, Light's Blessing, Ruination, Summon Demonic Tyrant, Spell Lock, Soulburn, Dark Pact, Grimoire: Imp Lord, Burning Rush, Curse of Tongues
      watch={ {1276623,85.5},{108366,83.7},{264173,68.9},{1269879,66.9},{48018,58.0},{1269643,57.1},{1276166,35.2},{265187,28.2},{456323,28.2},{1276767,28.2} }, -- Singe Magic, Soul Leech, Demonic Core, Mind's Eyes, Demonic Circle, Demonic Oculi, Dominion of Argus, Summon Demonic Tyrant, Abyssal Dominion, Tyrant's Oblation
    },
  },
  ["WARLOCK/DESTRUCTION"] = {
    specID=267,
    raid={
      n=5, dur=409, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="埃索达尔", server="冰风岗", region="CN", seq={17962,229837,1122,442726,1236616,1250533,116858,116858,17962,116858,29722,17962,116858,29722,116858} },
        { player="Kiralock", server="Tarren Mill", region="EU", seq={29722,445468,445468,1122,1250533,442726,80240,1236616,17962,116858,116858,17962,116858,6353,17877} },
        { player="一之猫", server="凤凰之神", region="CN", seq={6353,1122,1293316,1236616,442726,116858,17962,116858,17962,116858,29722,116858,17962,116858,17877} },
      },
      core={ {116858,11.1},{29722,10.8},{17877,10.1},{17962,8.4},{445468,4.1},{80240,1.8},{6353,1.2},{442726,1.0},{1122,0.7},{108416,0.7},{111400,0.6} }, -- Chaos Bolt, Incinerate, Shadowburn, Conflagrate, Wither, Havoc, Soul Fire, Malevolence, Summon Infernal, Dark Pact, Burning Rush
      watch={ {1265939,89.6},{108366,70.0},{442726,58.6},{117828,45.1},{417282,39.8},{111685,36.6},{266030,26.7},{387263,24.4},{1250533,18.2},{1292300,15.9} }, -- Vision of Nihilam, Soul Leech, Malevolence, Backdraft, Crashing Chaos, Summon Infernal, Reverse Entropy, Flashpoint, Freightrunner's Flask, Brittle Torga Totem
    },
    mplus={
      n=8, dur=1781,
      core={ {29722,10.6},{17877,9.4},{1244918,8.6},{17962,7.1},{116858,4.8},{5740,4.3},{348,2.1},{152108,1.4},{434635,1.2},{108416,0.6},{1122,0.6},{1714,0.6},{111400,0.5},{385899,0.4} }, -- Incinerate, Shadowburn, Lake of Fire, Conflagrate, Chaos Bolt, Rain of Fire, Immolate, Cataclysm, Ruination, Dark Pact, Summon Infernal, Curse of Tongues, Burning Rush, Soulburn
      watch={ {1265939,85.1},{108366,82.3},{1269643,81.4},{48018,78.2},{1269879,60.9},{117828,41.8},{394087,31.7},{266030,30.0},{266087,29.8},{111685,29.1} }, -- Vision of Nihilam, Soul Leech, Demonic Oculi, Demonic Circle, Mind's Eyes, Backdraft, Mayhem, Reverse Entropy, Rain of Chaos, Summon Infernal
    },
  },
  ["WARRIOR/ARMS"] = {
    specID=71,
    raid={
      n=5, dur=398, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Camsu", server="Tarren Mill", region="EU", seq={100,845,126664,107574,167105,281000,446035,12294,107570,12294,12294,12294,12294,7384,7384} },
        { player="Khawarr", server="Zul'jin", region="US", seq={100,845,126664,1297761,167105,107574,281000,446035,12294,107570,12294,12294,12294,12294,7384} },
        { player="Sotaxwar", server="Tarren Mill", region="EU", seq={100,845,126664,167105,107574,1236616,281000,446035,12294,12294,12294,12294,12294,7384,1269383} },
      },
      core={ {12294,18.2},{281000,12.6},{7384,7.2},{1269383,6.5},{845,3.1},{1464,2.4},{167105,1.9},{446035,1.8},{107570,1.4},{260708,1.2},{23920,1.1},{107574,1.0},{100,0.7},{202168,0.4} }, -- Mortal Strike, Execute, Overpower, Heroic Strike, Cleave, Slam, Colossus Smash, Bladestorm, Storm Bolt, Sweeping Strikes, Spell Reflection, Avatar, Charge, Impending Victory
      watch={ {386164,97.4},{1269394,97.2},{260708,96.7},{1292058,81.2},{445606,81.0},{392778,77.3},{1300670,75.2},{456120,52.4},{386633,39.9},{52437,36.5} }, -- Battle Stance, Master of Warfare, Sweeping Strikes, Heroic Might, Imminent Demise, Wild Strikes, Winding Up, Opportunist, Executioner's Precision, Sudden Death
    },
    mplus={
      n=8, dur=1800,
      core={ {12294,14.3},{281000,11.1},{845,8.4},{7384,7.5},{1269383,2.4},{446035,1.7},{167105,1.6},{260708,1.5},{1464,1.2},{23920,1.1},{100,0.8},{107574,0.8},{107570,0.6},{386164,0.5} }, -- Mortal Strike, Execute, Cleave, Overpower, Heroic Strike, Bladestorm, Colossus Smash, Sweeping Strikes, Slam, Spell Reflection, Charge, Avatar, Storm Bolt, Battle Stance
      watch={ {386164,94.3},{1269394,92.0},{445584,90.0},{260708,85.7},{445606,79.3},{1292058,75.4},{392778,72.8},{1300670,67.3},{334783,61.7},{386633,52.0} }, -- Battle Stance, Master of Warfare, Executioner, Sweeping Strikes, Imminent Demise, Heroic Might, Wild Strikes, Winding Up, Collateral Damage, Executioner's Precision
    },
  },
  ["WARRIOR/FURY"] = {
    specID=72,
    raid={
      n=5, dur=409, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Noxiv", server="Zul'jin", region="US", seq={100,23881,126664,1719,1297761,385059,385060,385061,385062,385061,184367,1236616,184367,446035,335096} },
        { player="Kratos", server="Vashj", region="EU", seq={1236616,1719,1297761,100,184367,126664,446035,335096,335096,184367,335097,184367,335097,184367,335097} },
        { player="Nekowarr", server="Silvermoon", region="EU", seq={1719,1297761,100,1236616,184367,126664,385059,385060,385061,385062,385061,446035,335096,335096,184367} },
      },
      core={ {184367,22.8},{85288,10.9},{280735,7.8},{335097,7.1},{335096,5.6},{190411,4.3},{23881,2.9},{446035,1.4},{1719,1.3},{385060,1.2},{23920,1.2},{100,0.7},{202168,0.7} }, -- Rampage, Raging Blow, Execute, Crushing Blow, Bloodbath, Whirlwind, Bloodthirst, Bladestorm, Recklessness, Odyn's Fury, Spell Reflection, Charge, Impending Victory
      watch={ {445584,96.4},{184362,93.1},{392778,88.4},{445606,83.4},{383873,58.0},{1719,52.2},{1265560,52.2},{1265406,50.7},{1265575,47.6},{52437,32.4} }, -- Executioner, Enrage, Wild Strikes, Imminent Demise, Hack and Slash, Recklessness, Surge of Adrenaline, Bloodborne, Executioner's Wrath, Sudden Death
    },
    mplus={
      n=8, dur=1767,
      core={ {184367,21.2},{85288,8.3},{190411,8.2},{5308,7.0},{335097,6.6},{335096,4.8},{23881,3.1},{446035,1.2},{1719,1.2},{385060,1.2},{23920,1.0},{100,0.6},{386196,0.4},{184364,0.3} }, -- Rampage, Raging Blow, Whirlwind, Execute, Crushing Blow, Bloodbath, Bloodthirst, Bladestorm, Recklessness, Odyn's Fury, Spell Reflection, Charge, Berserker Stance, Enraged Regeneration
      watch={ {386196,96.3},{335082,92.0},{445584,90.9},{1269349,90.8},{184362,88.8},{445606,85.5},{392778,77.9},{383873,58.4},{85739,54.1},{1265406,52.1} }, -- Berserker Stance, Frenzy, Executioner, Berserk, Enrage, Imminent Demise, Wild Strikes, Hack and Slash, Whirlwind, Bloodborne
    },
  },
  ["WARRIOR/PROTECTION"] = {
    specID=73,
    raid={
      n=5, dur=414, encId=3445, encCn="陵寝哨兵", mNum=2,
      opener={
        { player="Chuckles", server="Mal'Ganis", region="US", seq={384110,57755,1160,385952,1236616,107574,435222,2565,1293316,23922,2565,435222,23922,190456,6343} },
        { player="Guthezzo", server="Area 52", region="US", seq={107574,385954,1160,2565,435222,190456,23922,435222,23922,2565,435222,6572,190456,23922,23922} },
        { player="Shawestruck", server="Blackhand", region="EU", seq={385952,385954,6343,107574,435222,2565,1160,435222,2565,23922,435222,190456,6343,6343,23922} },
      },
      core={ {23922,16.4},{190456,12.7},{6572,11.9},{6343,8.6},{2565,5.6},{1160,1.9},{23920,1.6},{107574,1.2},{163201,1.0},{871,0.7},{100,0.6},{202168,0.6},{57755,0.4},{52174,0.4} }, -- Shield Slam, Ignore Pain, Revenge, Thunder Clap, Shield Block, Demoralizing Shout, Spell Reflection, Avatar, Execute, Shield Wall, Charge, Impending Victory, Heroic Throw, Heroic Leap
      watch={ {23922,96.2},{132404,90.3},{392778,73.2},{107574,64.8},{438591,59.1},{1278009,54.1},{190456,53.7},{224324,39.6},{1234772,39.0},{435615,30.0} }, -- Shield Slam, Shield Block, Wild Strikes, Avatar, Keep Your Feet on the Ground, Phalanx, Ignore Pain, Shield Slam!, Best Served Cold, Thunder Blast
    },
    mplus={
      n=8, dur=1729,
      core={ {23922,15.5},{190456,14.7},{6572,11.7},{6343,10.5},{2565,5.3},{1160,1.9},{163201,1.4},{23920,1.0},{107574,1.0},{100,0.8},{46968,0.6},{57755,0.6},{871,0.6},{202168,0.4} }, -- Shield Slam, Ignore Pain, Revenge, Thunder Clap, Shield Block, Demoralizing Shout, Execute, Spell Reflection, Avatar, Charge, Shockwave, Heroic Throw, Shield Wall, Impending Victory
      watch={ {386208,96.8},{202602,96.2},{386029,94.6},{23922,91.2},{132404,85.4},{392778,72.5},{190456,69.9},{1241762,54.7},{1278009,50.8},{107574,43.8} }, -- Defensive Stance, Into the Fray, Brace For Impact, Shield Slam, Shield Block, Wild Strikes, Ignore Pain, Frenzied Focus, Phalanx, Avatar
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
