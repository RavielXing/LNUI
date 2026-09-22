local _, GF = ...

GF.UserLetterDialog = {}
local Dialog = GF.UserLetterDialog

function Dialog:Hide()
	if self.frame then self.frame:Hide() end
end

function Dialog:RefreshLocale()
	if self.frame then
		GF.UsageGuideDialog:RefreshUserLetterFrame(self.frame)
	end
end

function Dialog:Show()
	if GF.EnsureBlizzardAddons and not GF.EnsureBlizzardAddons() then return false end
	local about = GF.UsageGuideDialog
	if not about or not about.CreateUserLetterFrame then return false end
	local f = self.frame
	if not f then
		f = about:CreateUserLetterFrame(function() self:Hide() end)
		self.frame = f
		f.readButton:SetScript("OnClick", function()
			if GF.UserLetter:MarkRead() then self:Hide() end
		end)
		f:HookScript("OnShow", function()
			if not self._shown then
				self._shown = true
				GF.UI.PlayUISound("pageTurn")
			end
		end)
		f:HookScript("OnHide", function()
			if self._shown then
				self._shown = nil
				GF.UI.PlayUISound("pageTurn")
			end
			if GF.UI.CancelSmoothWheelScrolling then
				GF.UI.CancelSmoothWheelScrolling(f.noticeScroll)
			end
		end)
	end
	about:RefreshUserLetterFrame(f)
	if GF.UI.CancelSmoothWheelScrolling then
		GF.UI.CancelSmoothWheelScrolling(f.noticeScroll)
	end
	f.noticeScroll:SetVerticalScroll(0)
	GF.UI.CenterOnUIParent(f, 0)
	f:Show()
	GF.UI.RaiseFrame(f)
	return true
end
