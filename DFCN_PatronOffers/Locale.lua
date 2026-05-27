local _, T = ...

local C, z, V, K = GetLocale(), nil
V =
    C == "zhCN" and { -- 7/7 (100%)
      "可用：", "未找到匹配的订单。", "发布人/剩余时间/总收入：", "你制造/提供：", "你获得：", "你的成本：", "你的利润："
    } or nil

K = V and {
      "Available:", "No matching patron orders available.", "Patron/Time/Total Reward:", "You craft/provide:", "You receive:", "Cost:", "Profit:"
}

local L = K and {}
for i=1,K and #K or 0 do
	L[K[i]] = V[i]
end

T.L = L or nil