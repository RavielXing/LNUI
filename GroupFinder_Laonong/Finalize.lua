local _, Addon = ...
local GF = Addon.GF
local directory = Addon.Directory
if GF and directory and type(directory.Init) == "function"
	and type(directory.FindMembers) == "function"
	and type(directory.GetApplicantDisplayType) == "function"
then
	-- Publish only after the complete implementation has loaded successfully.
	GF.LaonongFanDirectory = directory
	GF.LaonongModule.ready = true
end
