local LibBlzSettings = LibStub("LibBlzSettings-1.0")

CDDSettingsEditboxButtonControlMixin = CreateFromMixins(SettingsListElementMixin);

function CDDSettingsEditboxButtonControlMixin:OnLoad()
    SettingsListElementMixin.OnLoad(self);

    self.Editbox = CreateFrame("EditBox", nil, self, "InputBoxTemplate")

    Mixin(self.Editbox, DefaultTooltipMixin)
    DefaultTooltipMixin.OnLoad(self.Editbox)
    self.tooltipXOffset = 0

    self.Editbox:SetPoint("LEFT", self, "CENTER", -80, 0)
    self.Editbox:SetSize(200, 26)
    self.Editbox:SetAutoFocus(false)

    self.Editbox.Left:SetHeight(26)
    self.Editbox.Right:SetHeight(26)
    self.Editbox.Middle:SetHeight(26)

    self.Editbox:SetScript("OnEnable", function (editbox)
        editbox:SetTextColor(1, 1, 1)
    end)

    self.Editbox:SetScript("OnDisable", function (editbox)
        editbox:SetTextColor(0.5, 0.5, 0.5)
    end)

    self.Editbox:SetScript("OnEnterPressed", EditBox_ClearFocus)    -- 回车清楚焦点
    self.Editbox:SetScript("OnEscapePressed", EditBox_ClearFocus)   -- ESC清除焦点

    Mixin(self.Editbox, DefaultTooltipMixin)
    
    self.Button = CreateFrame("Button", nil, self, "UIPanelButtonTemplate");
    self.Button:SetSize(100, 26);
    self.Button:SetPoint("LEFT", self.Editbox, "RIGHT", 5, 0);
    
    Mixin(self.Button, DefaultTooltipMixin);
    DefaultTooltipMixin.OnLoad(self.Button);
end

function CDDSettingsEditboxButtonControlMixin:Init(initializer)
    SettingsListElementMixin.Init(self, initializer);

    local setting = initializer.data.setting;
    local editboxLabel = initializer.data.editboxLabel or initializer.data.name;
    local editboxTooltip = initializer.data.editboxTooltip or initializer.data.tooltip;

    local initEditboxTooltip = GenerateClosure(Settings.InitTooltip, editboxLabel, editboxTooltip);
    self.Editbox:SetTooltipFunc(initEditboxTooltip)
    self.Editbox:SetText(setting and setting:GetValue() or "")
    if setting then
        self.Editbox:SetScript("OnTextChanged", function(editbox, userInput)
            if userInput and not IMECandidatesFrame:IsShown() then  -- 限制: 用户输入/输入法框体未显示
                self:OnEditboxValueChanged(editbox:GetText())
            end
        end)
        local function OnEditboxSettingValueChanged(o, setting, value)
            self.Editbox:SetText(value)
        end
        self.cbrHandles:SetOnValueChangedCallback(setting:GetVariable(), OnEditboxSettingValueChanged)
    end
    
    self.Button:SetText(initializer.data.buttonText);
    self.Button:SetScript("OnClick", function()
        initializer.data.OnButtonClick(self)
    end);

    self:EvaluateState()
end

function CDDSettingsEditboxButtonControlMixin:OnEditboxValueChanged(value)
    local initializer = self:GetElementData();
    local setting = initializer.data.setting;
    setting:SetValue(value);
end

function CDDSettingsEditboxButtonControlMixin:Release()
    self.Editbox:SetScript("OnTextChanged", nil)
    self.Button:SetScript("OnClick", nil);
    SettingsListElementMixin.Release(self);
end

function CDDSettingsEditboxAndButtonBuildFunction(addOnName, category, layout, dataTbl, database)
    local setting
    if dataTbl.key then
        setting = LibBlzSettings.RegisterSetting(addOnName, category, dataTbl, database, Settings.VarType.String, dataTbl.name)
    end
     local data = {
        key = dataTbl.key,
        name = dataTbl.name,
        tooltip = dataTbl.tooltip,
        setting = setting,
        editboxLabel = dataTbl.editboxLabel,
        editboxTooltip = dataTbl.editboxTooltip,
        buttonText = dataTbl.button.buttonText,
        OnButtonClick = dataTbl.button.OnButtonClick
    }
    local initializer = Settings.CreateSettingInitializer("CDDSettingsEditboxButtonControlTemplate", data)
    if dataTbl.canSearch or dataTbl.canSearch == nil then
        initializer:AddSearchTags(dataTbl.name)
    end
    layout:AddInitializer(initializer)
    return setting, initializer
end

LibBlzSettings.RegisterControl("CDD_EDITBOX_AND_BUTTON", function (addOnName, category, layout, dataTbl, database)
    return CDDSettingsEditboxAndButtonBuildFunction(addOnName, category, layout, dataTbl, database)
end, nil, nil)

CDDSettingsListSectionLabelMixin = CreateFromMixins();

function CDDSettingsListSectionLabelMixin:Init(initializer)
    local data = initializer:GetData();
    self.Title:SetText(data.name);
    self.Title:SetWidth(self:GetWidth() - 7)
end

LibBlzSettings.RegisterControl("CDD_LABEL", function (addOnName, category, layout, dataTbl, database)
    local initializer = Settings.CreateSettingInitializer("CDDSettingsListSectionLabelTemplate", dataTbl)

    if dataTbl.canSearch or dataTbl.canSearch == nil then
        initializer:AddSearchTags(dataTbl.name)
    end

    layout:AddInitializer(initializer)

    return _, initializer
end, nil, nil)

LibBlzSettings.RegisterControl("CDD_LABEL3", function (addOnName, category, layout, dataTbl, database)
    local initializer = Settings.CreateSettingInitializer("CDDSettingsListSectionLabel3Template", dataTbl)

    if dataTbl.canSearch or dataTbl.canSearch == nil then
        initializer:AddSearchTags(dataTbl.name)
    end

    layout:AddInitializer(initializer)

    return _, initializer
end, nil, nil)
