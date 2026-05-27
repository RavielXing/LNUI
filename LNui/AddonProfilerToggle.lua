U1PLUG["AddonProfilerToggle"] = function()
-- 禁用addonProfiler 可用/dump C_AddOnProfiler.IsEnabled()检查
-- 下面下面两行11.1.5已经失效
-- C_CVar.RegisterCVar('addonProfilerEnabled', '1')
-- C_CVar.SetCVar('addonProfilerEnabled', '0')
C_AddOnProfiler.IsEnabled = function()
    return false
end
end