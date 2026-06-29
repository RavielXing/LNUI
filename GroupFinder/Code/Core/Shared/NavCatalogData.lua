-- GroupFinder navigation catalog static ID table.
--
-- 【数据来源】暴雪正式服公开 DB2 表 GroupFinderActivity
--   导出站点: https://wago.tools/db2/GroupFinderActivity
--   由 插件 配套脚本本地拉取 CSV 后自动生成
--   副本/团本/地下堡名称在运行时由游戏内 C_LFGList API 获取；本文件仅含 groupID / activityID / listFilters
--
-- 【范围】地下城、团本：全资料片归档；地下堡：仅 legacy 资料片（当前资料片走游戏内 API）
-- 自动生成: 2026-06-18 09:31:21  build=12.0.7.68235 rows=1308

local _, GF = ...

GF.NAV_CATALOG = {
  ["dungeon"] = {
    ["baseFilters"] = 196,
    ["preferredFilters"] = 4,
    ["categoryID"] = 2,
    ["expansions"] = {
      {
        ["expansionIndex"] = 11,
        ["instances"] = {
          {
            ["listFilters"] = 101,
            ["groupID"] = 370
          },
          {
            ["listFilters"] = 165,
            ["groupID"] = 382,
            ["activityID"] = 1699
          },
          {
            ["listFilters"] = 165,
            ["groupID"] = 392,
            ["activityID"] = 1721
          },
          {
            ["listFilters"] = 165,
            ["groupID"] = 396,
            ["activityID"] = 1749
          },
          {
            ["listFilters"] = 165,
            ["groupID"] = 398,
            ["activityID"] = 1754
          },
          {
            ["listFilters"] = 101,
            ["groupID"] = 399
          },
          {
            ["listFilters"] = 101,
            ["groupID"] = 400
          },
          {
            ["listFilters"] = 101,
            ["groupID"] = 401
          }
        },
      },
      {
        ["expansionIndex"] = 10,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 322
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 323
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 324
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 325
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 326
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 327
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 328
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 329
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 371
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 381
          }
        },
      },
      {
        ["expansionIndex"] = 9,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 302
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 303
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 304
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 305
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 306
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 307
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 308
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 309
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 315
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 316
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 317
          }
        },
      },
      {
        ["expansionIndex"] = 8,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 259
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 260
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 261
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 262
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 263
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 264
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 265
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 266
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 272
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 280
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 281
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 309
          }
        },
      },
      {
        ["expansionIndex"] = 7,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 136
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 137
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 138
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 139
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 140
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 141
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 142
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 143
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 144
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 145
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 146
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 253
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 256
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 257
          }
        },
      },
      {
        ["expansionIndex"] = 6,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 111
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 112
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 113
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 114
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 115
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 116
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 117
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 118
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 119
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 120
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 121
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 125
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 127
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 128
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 129
          },
          {
            ["listFilters"] = 69,
            ["groupID"] = 133
          }
        },
      },
      {
        ["expansionIndex"] = 5,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 6
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 7
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 8
          },
          {
            ["listFilters"] = 70,
            ["groupID"] = 9
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 10
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 11
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 12
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 13
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 109
          }
        },
      },
      {
        ["expansionIndex"] = 4,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 18
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 30
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 31
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 61
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 62
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 63
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 64
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 65
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 66
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 84
          }
        },
      },
      {
        ["expansionIndex"] = 3,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 5
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 19
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 54
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 55
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 56
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 57
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 58
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 59
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 60
          },
          {
            ["activityID"] = 150,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 151,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 152,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 153,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 154,
            ["listFilters"] = 134
          }
        },
      },
      {
        ["expansionIndex"] = 2,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 38
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 39
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 40
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 41
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 42
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 43
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 44
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 45
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 46
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 47
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 48
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 49
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 50
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 51
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 52
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 53
          }
        },
      },
      {
        ["expansionIndex"] = 1,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 20
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 21
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 22
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 23
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 24
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 25
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 26
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 27
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 28
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 29
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 32
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 33
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 34
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 35
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 36
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 37
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 44
          }
        },
      },
      {
        ["expansionIndex"] = 0,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 5
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 18
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 19
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 30
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 31
          },
          {
            ["activityID"] = 50,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 52,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 54,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 55,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 56,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 57,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 58,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 59,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 60,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 61,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 62,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 63,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 64,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 65,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 66,
            ["listFilters"] = 134
          }
        },
      }
    },
  },
  ["delve"] = {
    ["baseFilters"] = 4,
    ["preferredFilters"] = 4,
    ["categoryID"] = 121,
    ["expansions"] = {
      {
        ["expansionIndex"] = 10,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 331
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 332
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 333
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 334
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 335
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 336
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 337
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 338
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 339
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 340
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 341
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 342
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 343
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 373
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 374
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 375
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 394
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 395
          }
        },
      }
    },
  },
  ["raid"] = {
    ["baseFilters"] = 5,
    ["preferredFilters"] = 4,
    ["categoryID"] = 3,
    ["expansions"] = {
      {
        ["expansionIndex"] = 11,
        ["instances"] = {
          {
            ["listFilters"] = 165,
            ["groupID"] = 402
          },
          {
            ["listFilters"] = 165,
            ["groupID"] = 403
          },
          {
            ["listFilters"] = 165,
            ["groupID"] = 404
          },
          {
            ["listFilters"] = 165,
            ["groupID"] = 422
          },
          {
            ["activityID"] = 1735,
            ["listFilters"] = 165
          },
          {
            ["activityID"] = 1968,
            ["listFilters"] = 165
          }
        },
      },
      {
        ["expansionIndex"] = 10,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 362
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 377
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 378
          },
          {
            ["activityID"] = 1289,
            ["listFilters"] = 134
          }
        },
      },
      {
        ["expansionIndex"] = 9,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 310
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 313
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 319
          },
          {
            ["activityID"] = 1146,
            ["listFilters"] = 134
          }
        },
      },
      {
        ["expansionIndex"] = 8,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 267
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 271
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 282
          },
          {
            ["activityID"] = 723,
            ["listFilters"] = 134
          }
        },
      },
      {
        ["expansionIndex"] = 7,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 135
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 251
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 252
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 254
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 255
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 258
          },
          {
            ["activityID"] = 657,
            ["listFilters"] = 134
          }
        },
      },
      {
        ["expansionIndex"] = 6,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 122
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 123
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 126
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 131
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 132
          },
          {
            ["activityID"] = 458,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 1674,
            ["listFilters"] = 134
          }
        },
      },
      {
        ["expansionIndex"] = 5,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 14
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 15
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 110
          },
          {
            ["activityID"] = 398,
            ["listFilters"] = 134
          }
        },
      },
      {
        ["expansionIndex"] = 4,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 1
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 80
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 81
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 82
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 83
          },
          {
            ["activityID"] = 397,
            ["listFilters"] = 134
          }
        },
      },
      {
        ["expansionIndex"] = 3,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 75
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 76
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 77
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 78
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 79
          }
        },
      },
      {
        ["expansionIndex"] = 2,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 16
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 17
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 73
          },
          {
            ["listFilters"] = 134,
            ["groupID"] = 74
          },
          {
            ["activityID"] = 303,
            ["listFilters"] = 134
          }
        },
      },
      {
        ["expansionIndex"] = 1,
        ["instances"] = {
          {
            ["activityID"] = 45,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 296,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 297,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 298,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 299,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 300,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 301,
            ["listFilters"] = 134
          }
        },
      },
      {
        ["expansionIndex"] = 0,
        ["instances"] = {
          {
            ["listFilters"] = 134,
            ["groupID"] = 372
          },
          {
            ["activityID"] = 9,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 293,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 294,
            ["listFilters"] = 134
          },
          {
            ["activityID"] = 295,
            ["listFilters"] = 134
          }
        },
      }
    },
  }
}

return GF.NAV_CATALOG
