local _, addon = ...

addon.Options.Defaults = {
    profile = {
        ShowMinimapIcon = false,
        NumRows = 6,--lnui
        NumColumns = 3,--lnui
        Direction = 'Rows',
        Minimap = {
            hide = true -- not ShowMinimapIcon
        },
        ShowOptionsButton = true,
        ShowHideOption = true,
        RememberFilter = false,
        RememberSearch = false,
        RememberSearchBetweenVendors = false,
        BulkPurchase = {
            Enabled = false,--lnui
            ShowConfirm = false,--lnui
        },
        TokenBanner = {
            MoneyLabel = 'Icon',
            MoneyAbbreviate = 'None',
            ThousandsSeparator = 'Space',
            MoneyGoldOnly = false,
            MoneyColored = true,
	        CurrencyAbbreviate = 'None',
            Format = 'Both',
        }
    }
}