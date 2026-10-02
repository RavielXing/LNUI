local _, GF = ...
GF = GF.GF or GF

-- BrowseVirtualListAdapter is the page-specific identity boundary over GF's
-- one VirtualList implementation.  It does not create a second provider or
-- scroll state machine; it fixes the Browse identity field and rejects a
-- projection that could not be restored by identity after a rebuild.
local Adapter = {}
GF.BrowseVirtualListAdapter = Adapter

Adapter.IDENTITY_FIELD = "projectionKey"

local function virtualListOwner()
	local ui = GF.UI
	return ui and ui.VirtualList or nil
end

function Adapter.GetElementIdentity(element)
	return type(element) == "table"
		and element[Adapter.IDENTITY_FIELD] or nil
end

function Adapter.ValidateElements(elements)
	if type(elements) ~= "table" then
		return false, "elements-not-table"
	end
	local seen = {}
	for index = 1, #elements do
		local identity = Adapter.GetElementIdentity(elements[index])
		if identity == nil then
			return false, "missing-projection-identity", index
		end
		if seen[identity] then
			return false, "duplicate-projection-identity", index
		end
		seen[identity] = true
	end
	return true
end

function Adapter.SetElements(list, elements, options)
	local valid, reason, index = Adapter.ValidateElements(elements)
	if not valid then
		return nil, reason, index
	end
	local setElements = list and list._gfVirtualListSetElements
	if type(setElements) ~= "function" then
		return nil, "virtual-list-unavailable"
	end
	return setElements(list, elements, options)
end

function Adapter.Create(parent, options)
	local owner = virtualListOwner()
	if not owner or type(owner.Create) ~= "function" then
		return nil
	end
	local config = {}
	for key, value in pairs(type(options) == "table" and options or {}) do
		config[key] = value
	end
	config.assignedKey = Adapter.IDENTITY_FIELD
	local list = owner.Create(parent, config)
	if not list then
		return nil
	end
	local nativeSetElements = list.SetElements
	if type(nativeSetElements) ~= "function" then
		return nil
	end
	list.assignedKey = Adapter.IDENTITY_FIELD
	list._gfVirtualListSetElements = nativeSetElements
	list._gfBrowseVirtualListAdapter = Adapter
	list.SetElements = Adapter.SetElements
	list.GetElementIdentity = function(_, element)
		return Adapter.GetElementIdentity(element)
	end
	return list
end
