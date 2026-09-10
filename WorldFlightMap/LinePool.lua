-- ============================================================
-- LinePool.lua - WoW 12.1 Compatible
-- ============================================================
-- 12.x changes:
--   - CreateUnsecuredObjectPool / CreateUnsecuredTexturePool removed
--   - Use CreateObjectPool / CreateTexturePool instead (standard in 12.x)
--   - securecallfunction guards around frame:CreateLine to avoid
--     secret-value taint propagating into parent frame state
-- ============================================================

local LinePoolMixin = {}

local function LinePoolFactory(linePool)
    -- Use securecallfunction to avoid tainting the parent frame
    -- when creating Line objects on it.  In 12.x, CreateLine can
    -- propagate execution context onto the parent frame.
    local ok, line = pcall(securecallfunction, function()
        return linePool.parent:CreateLine(nil, linePool.layer, linePool.textureTemplate, linePool.subLayer)
    end)
    if ok and line then
        return line
    end
    -- Fallback: create directly (may taint but functional)
    return linePool.parent:CreateLine(nil, linePool.layer, linePool.textureTemplate, linePool.subLayer)
end

function LinePoolMixin:OnLoad(parent, layer, subLayer, textureTemplate, resetterFunc)
    self.parent = parent
    self.layer = layer
    self.subLayer = subLayer
    self.textureTemplate = textureTemplate
    self.resetterFunc = resetterFunc or Pool_HideAndClearAnchors

    -- 12.1: Use standard CreateObjectPool (CreateUnsecuredObjectPool removed in 12.x)
    self.pool = CreateObjectPool(
        function() return LinePoolFactory(self) end,
        function(pool, line)
            line:Hide()
            line:ClearAllPoints()
            if self.resetterFunc then
                self.resetterFunc(pool, line)
            end
        end
    )
end

function LinePoolMixin:Acquire()
    return self.pool:Acquire()
end

function LinePoolMixin:Release(line)
    self.pool:Release(line)
end

function LinePoolMixin:ReleaseAll()
    self.pool:ReleaseAll()
end

function LinePoolMixin:GetNumActive()
    return self.pool:GetNumActive()
end

function LinePoolMixin:EnumerateActive()
    return self.pool:EnumerateActive()
end

function CreateLinePool(parent, layer, subLayer, textureTemplate, resetterFunc)
    local linePool = CreateFromMixins(LinePoolMixin)
    linePool:OnLoad(parent, layer, subLayer, textureTemplate, resetterFunc)
    return linePool
end
