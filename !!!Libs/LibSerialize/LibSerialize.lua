local MAJOR, MINOR = "LibSerialize", 5
local LibSerialize
if LibStub then
    LibSerialize = LibStub:NewLibrary(MAJOR, MINOR)
    if not LibSerialize then return end -- This version is already loaded.
else
    LibSerialize = {}
end

local SERIALIZATION_VERSION = 1
local DESERIALIZATION_VERSION = 2

local assert = assert
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status
local coroutine_yield = coroutine.yield
local error = error
local getmetatable = getmetatable
local ipairs = ipairs
local math_floor = math.floor
local math_huge = math.huge
local math_max = math.max
local math_modf = math.modf
local pairs = pairs
local pcall = pcall
local print = print
local select = select
local setmetatable = setmetatable
local string_byte = string.byte
local string_char = string.char
local string_sub = string.sub
local table_concat = table.concat
local table_insert = table.insert
local table_sort = table.sort
local tonumber = tonumber
local tostring = tostring
local type = type

-- Compatibility shim to allow the library to work on Lua 5.4
local unpack = unpack or table.unpack
local frexp = math.frexp or function(num)
    if num == math_huge then return num end
    local fraction, exponent = num, 0
    if fraction ~= 0 then
        while fraction >= 1 do
            fraction = fraction / 2
            exponent = exponent + 1
        end
        while fraction < 0.5 do
            fraction = fraction * 2
            exponent = exponent - 1
        end
    end
    return fraction, exponent
end
local ldexp = math.ldexp or function(m, e)
    return m * 2 ^ e
end

if require and _ENV then
    _ENV = setmetatable({}, {
        __newindex = function(t, k, v)
            assert(false, "Attempt to write to global variable: " .. k)
        end,
        __index = function(t, k)
            assert(false, "Attempt to read global variable: " .. k)
        end
    })
end


--[[---------------------------------------------------------------------------
    Library defaults.
--]]---------------------------------------------------------------------------

local defaultYieldCheck = function(self)
    self._currentObjectCount = self._currentObjectCount or 0
    if self._currentObjectCount > 4096 then
        self._currentObjectCount = 0
        return true
    end
    self._currentObjectCount = self._currentObjectCount + 1
end
local defaultSerializeOptions = {
    errorOnUnserializableType = true,
    stable = false,
    filter = nil,
    writer = nil,
    async = false,
    yieldCheck = defaultYieldCheck,
}
local defaultAsyncOptions = {
    async = true,
}
local defaultDeserializeOptions = {
    async = false,
    yieldCheck = defaultYieldCheck,
}

local canSerializeFnOptions = {
    errorOnUnserializableType = false
}

local function GetRequiredBytes(value)
    if value < 256 then return 1 end
    if value < 65536 then return 2 end
    if value < 16777216 then return 3 end
    error("Object limit exceeded")
end

local function GetRequiredBytesNumber(value)
    if value < 256 then return 1 end
    if value < 65536 then return 2 end
    if value < 16777216 then return 3 end
    if value < 4294967296 then return 4 end
    return 7
end

local function GetValueByKey(object, key)
    return object[key]
end

local function GetValueByKeyOrDefault(object, key, default)
    local ok, value = pcall(GetValueByKey, object, key)

    if not ok or value == nil then
        return default
    else
        return value
    end
end

-- Returns whether the value (a number) is NaN.
local function IsNaN(value)
    -- With floating point optimizations enabled all comparisons involving
    -- NaNs will return true. Without them, these will both return false.
    return (value < 0) == (value >= 0)
end

-- Returns whether the value (a number) is finite, as opposed to being a
-- NaN or infinity.
local function IsFinite(value)
    return value > -math_huge and value < math_huge and not IsNaN(value)
end

-- Returns whether the value (a number) is fractional,
-- as opposed to a whole number.
local function IsFractional(value)
    local _, fract = math_modf(value)
    return fract ~= 0
end

-- Returns whether the value (a number) needs to be represented as a floating
-- point number due to either being fractional or non-finite.
local function IsFloatingPoint(value)
    return IsFractional(value) or not IsFinite(value)
end

-- Returns true if the given table key is an integer that can reside in the
-- array section of a table (keys 1 through arrayCount).
local function IsArrayKey(k, arrayCount)
    return type(k) == "number" and k >= 1 and k <= arrayCount and not IsFloatingPoint(k)
end

-- Portable no-op function that does absolutely nothing, and pushes no returns
-- onto the stack.
local function Noop()
end

-- Sort compare function which is used to sort table keys to ensure that the
-- serialization of maps is stable. We arbitrarily put strings first, then
-- numbers, and finally booleans.
local function StableKeySort(a, b)
    local aType = type(a)
    local bType = type(b)
    -- Put strings first
    if aType == "string" and bType == "string" then
        return a < b
    elseif aType == "string" then
        return true
    elseif bType == "string" then
        return false
    end
    -- Put numbers next
    if aType == "number" and bType == "number" then
        return a < b
    elseif aType == "number" then
        return true
    elseif bType == "number" then
        return false
    end
    -- Put booleans last
    if aType == "boolean" and bType == "boolean" then
        return (a and 1 or 0) < (b and 1 or 0)
    else
        error(("Unhandled sort type(s): %s, %s"):format(aType, bType))
    end
end

local DebugPrint = function(...)
    print(...)
end

local function Writer_WriteString(self, str)
    if self.opts.async and self.opts.yieldCheck(self.asyncScratch) then
        coroutine_yield()
    end

    self.writeString(self.writer, str)
end

local function Writer_FlushWriter(self)
    return self.flushWriter(self.writer)
end

-- Functions for a writer that will lazily construct a string over multiple writes.
local function BufferedWriter_WriteString(self, str)
    self.bufferSize = self.bufferSize + 1
    self.buffer[self.bufferSize] = str
end

local function BufferedWriter_FlushBuffer(self)
    local flushed = table_concat(self.buffer, "", 1, self.bufferSize)
    self.bufferSize = 0
    return flushed
end

local function CreateWriter(opts)

    local object = {
        opts = opts,
        asyncScratch = opts.async and {} or nil,
    }

    local writeString = GetValueByKeyOrDefault(opts.writer, "WriteString", nil)

    if writeString == nil then
        -- Configure the object for the BufferedWriter approach.
        object.writer = object
        object.buffer = {}
        object.bufferSize = 0
        object.writeString = BufferedWriter_WriteString
        object.flushWriter = BufferedWriter_FlushBuffer
    else
        object.writer = opts.writer
        object.writeString = writeString
        object.flushWriter = GetValueByKeyOrDefault(opts.writer, "Flush", Noop)
    end

    return object, Writer_WriteString, Writer_FlushWriter
end

-- Generic reader functions that defer their work to previously defined helpers.
local function Reader_ReadBytes(self, bytelen)
    if self.opts.async and self.opts.yieldCheck(self.asyncScratch) then
        coroutine_yield()
    end

    local result = self.readBytes(self.input, self.nextPos, self.nextPos + bytelen - 1)
    self.nextPos = self.nextPos + bytelen
    return result
end

local function Reader_AtEnd(self)
    return self.atEnd(self.input, self.nextPos)
end

local function GenericReader_AtEnd(input, offset)
    return offset > #input
end

local function CreateReader(input, opts)

    local object = {
        input = input,
        nextPos = 1,
        opts = opts,
        asyncScratch = opts.async and {} or nil,
        readBytes = GetValueByKeyOrDefault(input, "ReadBytes", string_sub),
        atEnd = GetValueByKeyOrDefault(input, "AtEnd", GenericReader_AtEnd),
    }

    return object, Reader_ReadBytes, Reader_AtEnd
end

local function FloatToString(n)
    if IsNaN(n) then -- nan
        return string_char(0xFF, 0xF8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
    end

    local sign = 0
    if n < 0.0 then
        sign = 0x80
        n = -n
    end
    local mant, expo = frexp(n)

    -- If n is infinity, mant will be infinity inside WoW, but NaN elsewhere.
    if (mant == math_huge or IsNaN(mant)) or expo > 0x400 then
        if sign == 0 then -- inf
            return string_char(0x7F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
        else -- -inf
            return string_char(0xFF, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
        end
    elseif (mant == 0.0 and expo == 0) or expo < -0x3FE then -- zero
        return string_char(sign, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
    else
        expo = expo + 0x3FE
        mant = math_floor((mant * 2.0 - 1.0) * ldexp(0.5, 53))
        return string_char(sign + math_floor(expo / 0x10),
                           (expo % 0x10) * 0x10 + math_floor(mant / 281474976710656),
                           math_floor(mant / 1099511627776) % 256,
                           math_floor(mant / 4294967296) % 256,
                           math_floor(mant / 16777216) % 256,
                           math_floor(mant / 65536) % 256,
                           math_floor(mant / 256) % 256,
                           mant % 256)
    end
end

local function StringToFloat(str)
    local b1, b2, b3, b4, b5, b6, b7, b8 = string_byte(str, 1, 8)
    local sign = b1 > 0x7F
    local expo = (b1 % 0x80) * 0x10 + math_floor(b2 / 0x10)
    local mant = ((((((b2 % 0x10) * 256 + b3) * 256 + b4) * 256 + b5) * 256 + b6) * 256 + b7) * 256 + b8
    if sign then
        sign = -1
    else
        sign = 1
    end
    local n
    if mant == 0 and expo == 0 then
        n = sign * 0.0
    elseif expo == 0x7FF then
        if mant == 0 then
            n = sign * math_huge
        else
            n = 0.0/0.0
        end
    else
        n = sign * ldexp(1.0 + mant / 4503599627370496.0, expo - 0x3FF)
    end
    return n
end

local function IntToString(n, required)
    if required == 1 then
        return string_char(n)
    elseif required == 2 then
        return string_char(math_floor(n / 256),
                           n % 256)
    elseif required == 3 then
        return string_char(math_floor(n / 65536),
                           math_floor(n / 256) % 256,
                           n % 256)
    elseif required == 4 then
        return string_char(math_floor(n / 16777216),
                           math_floor(n / 65536) % 256,
                           math_floor(n / 256) % 256,
                           n % 256)
    elseif required == 7 then
        return string_char(math_floor(n / 281474976710656) % 256,
                           math_floor(n / 1099511627776) % 256,
                           math_floor(n / 4294967296) % 256,
                           math_floor(n / 16777216) % 256,
                           math_floor(n / 65536) % 256,
                           math_floor(n / 256) % 256,
                           n % 256)
    end

    error("Invalid required bytes: " .. required)
end

local function StringToInt(str, required)
    if required == 1 then
        return string_byte(str)
    elseif required == 2 then
        local b1, b2 = string_byte(str, 1, 2)
        return b1 * 256 + b2
    elseif required == 3 then
        local b1, b2, b3 = string_byte(str, 1, 3)
        return (b1 * 256 + b2) * 256 + b3
    elseif required == 4 then
        local b1, b2, b3, b4 = string_byte(str, 1, 4)
        return ((b1 * 256 + b2) * 256 + b3) * 256 + b4
    elseif required == 7 then
        local b1, b2, b3, b4, b5, b6, b7, b8 = 0, string_byte(str, 1, 7)
        return ((((((b1 * 256 + b2) * 256 + b3) * 256 + b4) * 256 + b5) * 256 + b6) * 256 + b7) * 256 + b8
    end

    error("Invalid required bytes: " .. required)
end

local LibSerializeInt = {}

local function CreateSerializer(opts, ...)
    local ser = {}

    -- Copy the state from LibSerializeInt.
    for k, v in pairs(LibSerializeInt) do
        ser[k] = v
    end

    -- Initialize string/table reference storage.
    ser._stringRefs = {}
    ser._tableRefs = {}

    -- Create a combined options table, starting with the defaults
    -- and then overwriting any user-supplied keys.
    ser._opts = {}
    for k, v in pairs(defaultSerializeOptions) do
        ser._opts[k] = v
    end
    for k, v in pairs(opts) do
        ser._opts[k] = v
    end

    -- Create the writer.
    ser._writer, ser._writeString, ser._flushWriter = CreateWriter(ser._opts)

    -- If the input was passed to this function, stash it away.
    if select("#", ...) ~= 0 then
        ser._input = {...}
        ser._inputLen = select("#", ...)
    end

    return ser
end

local function Serialize(ser, ...)
    -- If the input was previously stashed away, use that instead.
    if ser._input then
        assert(select("#", ...) == 0, "Input args should only be passed one way")
        local input = ser._input
        ser._input = nil
        return Serialize(ser, unpack(input, 1, ser._inputLen))
    end

    ser:_WriteByte(SERIALIZATION_VERSION)

    for i = 1, select("#", ...) do
        local input = select(i, ...)
        if not ser:_WriteObject(input) then
            -- An unserializable object was passed as an argument.
            -- Write nil into its slot so that we deserialize a
            -- consistent number of objects from the resulting string.
            ser:_WriteObject(nil)
        end
    end

    return ser._flushWriter(ser._writer)
end

local function CheckSerializationProgress(thread, co_success, result)
    if not co_success then
        return error(result)
    elseif coroutine_status(thread) ~= 'dead' then
        return false
    else
        return true, result
    end
end

local function CreateDeserializer(input, opts)
    local deser = {}

    -- Copy the state from LibSerializeInt.
    for k, v in pairs(LibSerializeInt) do
        deser[k] = v
    end

    -- Initialize string/table reference storage.
    deser._stringRefs = {}
    deser._tableRefs = {}

    -- Create a combined options table, starting with the defaults
    -- and then overwriting any user-supplied keys.
    deser._opts = {}
    for k, v in pairs(defaultDeserializeOptions) do
        deser._opts[k] = v
    end
    for k, v in pairs(opts) do
        deser._opts[k] = v
    end

    -- Create the reader.
    deser._reader, deser._readBytes, deser._readerAtEnd = CreateReader(input, deser._opts)

    return deser
end

local function Deserialize(deser)
    -- Since there's only one compression version currently,
    -- no extra work needs to be done to decode the data.
    local version = deser:_ReadByte()
    assert(version <= DESERIALIZATION_VERSION, "Unknown serialization version!")

    -- Since the objects we read may be nil, we need to explicitly
    -- track the number of results and assign by index so that we
    -- can call unpack() successfully at the end.
    local output = {}
    local outputSize = 0

    while not deser._readerAtEnd(deser._reader) do
        outputSize = outputSize + 1
        output[outputSize] = deser:_ReadObject()
    end

    return unpack(output, 1, outputSize)
end

local function CheckDeserializationProgress(thread, co_success, ...)
    if not co_success then
        return true, false, ...
    elseif coroutine_status(thread) ~= "dead" then
        return false
    else
        return true, true, ...
    end
end

function LibSerializeInt:_AddReference(refs, value)
    local ref = #refs + 1
    refs[ref] = value
    refs[value] = ref
end

function LibSerializeInt:_ReadObject()
    local value = self:_ReadByte()

    if value % 2 == 1 then
        -- Number embedded in the top 7 bits.
        local num = (value - 1) / 2
        -- DebugPrint("Found embedded number (1byte):", value, num)
        return num
    end

    if value % 4 == 2 then
        -- Type with embedded count. Extract both.
        -- The type is in bits 3-4, count in 5-8.
        local typ = (value - 2) / 4
        local count = (typ - typ % 4) / 4
        typ = typ % 4
        -- DebugPrint("Found type with embedded count:", value, typ, count)
        return self._EmbeddedReaderTable[typ](self, count)
    end

    if value % 8 == 4 then
        -- Number embedded in the top 4 bits, plus an additional byte's worth (so 12 bits).
        -- If bit 4 is set, the number is negative.
        local packed = self:_ReadByte() * 256 + value
        local num
        if value % 16 == 12 then
            num = -(packed - 12) / 16
        else
            num = (packed - 4) / 16
        end
        -- DebugPrint("Found embedded number (2bytes):", value, packed, num)
        return num
    end

    -- Otherwise, the type index is embedded in the upper 5 bits.
    local typ = value / 8
    -- DebugPrint("Found type:", value, typ)
    return self._ReaderTable[typ](self)
end

function LibSerializeInt:_ReadTable(entryCount, value)
    -- DebugPrint("Extracting keys/values for table:", entryCount)

    if value == nil then
        value = {}
        self:_AddReference(self._tableRefs, value)
    end

    for _ = 1, entryCount do
        local k, v = self:_ReadPair(self._ReadObject)
        value[k] = v
    end

    return value
end

function LibSerializeInt:_ReadArray(entryCount, value)
    -- DebugPrint("Extracting values for array:", entryCount)

    if value == nil then
        value = {}
        self:_AddReference(self._tableRefs, value)
    end

    for i = 1, entryCount do
        value[i] = self:_ReadObject()
    end

    return value
end

function LibSerializeInt:_ReadMixed(arrayCount, mapCount)
    -- DebugPrint("Extracting values for mixed table:", arrayCount, mapCount)

    local value = {}
    self:_AddReference(self._tableRefs, value)

    self:_ReadArray(arrayCount, value)
    self:_ReadTable(mapCount, value)

    return value
end

function LibSerializeInt:_ReadString(len)
    -- DebugPrint("Reading string,", len)

    local value = self._readBytes(self._reader, len)
    if len > 2 then
        self:_AddReference(self._stringRefs, value)
    end
    return value
end

function LibSerializeInt:_ReadByte()
    -- DebugPrint("Reading byte")

    return self:_ReadInt(1)
end

function LibSerializeInt:_ReadInt(required)
    -- DebugPrint("Reading int", required)

    return StringToInt(self._readBytes(self._reader, required), required)
end

function LibSerializeInt:_ReadPair(fn, ...)
    local first = fn(self, ...)
    local second = fn(self, ...)
    return first, second
end

local embeddedIndexShift = 4
local embeddedCountShift = 16
LibSerializeInt._EmbeddedIndex = {
    STRING = 0,
    TABLE = 1,
    ARRAY = 2,
    MIXED = 3,
}
LibSerializeInt._EmbeddedReaderTable = {
    [LibSerializeInt._EmbeddedIndex.STRING] = function(self, c) return self:_ReadString(c) end,
    [LibSerializeInt._EmbeddedIndex.TABLE] =  function(self, c) return self:_ReadTable(c) end,
    [LibSerializeInt._EmbeddedIndex.ARRAY] =  function(self, c) return self:_ReadArray(c) end,
    -- For MIXED, the 4-bit count contains two 2-bit counts that are one less than the true count.
    [LibSerializeInt._EmbeddedIndex.MIXED] =  function(self, c) return self:_ReadMixed((c % 4) + 1, math_floor(c / 4) + 1) end,
}

local readerIndexShift = 8
LibSerializeInt._ReaderIndex = {
    NIL = 0,

    NUM_16_POS = 1,
    NUM_16_NEG = 2,
    NUM_24_POS = 3,
    NUM_24_NEG = 4,
    NUM_32_POS = 5,
    NUM_32_NEG = 6,
    NUM_64_POS = 7,
    NUM_64_NEG = 8,
    NUM_FLOAT = 9,
    NUM_FLOATSTR_POS = 10,
    NUM_FLOATSTR_NEG = 11,

    BOOL_T = 12,
    BOOL_F = 13,

    STR_8 = 14,
    STR_16 = 15,
    STR_24 = 16,

    TABLE_8 = 17,
    TABLE_16 = 18,
    TABLE_24 = 19,

    ARRAY_8 = 20,
    ARRAY_16 = 21,
    ARRAY_24 = 22,

    MIXED_8 = 23,
    MIXED_16 = 24,
    MIXED_24 = 25,

    STRINGREF_8 = 26,
    STRINGREF_16 = 27,
    STRINGREF_24 = 28,

    TABLEREF_8 = 29,
    TABLEREF_16 = 30,
    TABLEREF_24 = 31,
}
LibSerializeInt._ReaderTable = {
    -- Nil
    [LibSerializeInt._ReaderIndex.NIL]  = function(self) return nil end,

    -- Numbers (ones requiring <=12 bits are handled separately)
    [LibSerializeInt._ReaderIndex.NUM_16_POS] = function(self) return self:_ReadInt(2) end,
    [LibSerializeInt._ReaderIndex.NUM_16_NEG] = function(self) return -self:_ReadInt(2) end,
    [LibSerializeInt._ReaderIndex.NUM_24_POS] = function(self) return self:_ReadInt(3) end,
    [LibSerializeInt._ReaderIndex.NUM_24_NEG] = function(self) return -self:_ReadInt(3) end,
    [LibSerializeInt._ReaderIndex.NUM_32_POS] = function(self) return self:_ReadInt(4) end,
    [LibSerializeInt._ReaderIndex.NUM_32_NEG] = function(self) return -self:_ReadInt(4) end,
    [LibSerializeInt._ReaderIndex.NUM_64_POS] = function(self) return self:_ReadInt(7) end,
    [LibSerializeInt._ReaderIndex.NUM_64_NEG] = function(self) return -self:_ReadInt(7) end,
    [LibSerializeInt._ReaderIndex.NUM_FLOAT]  = function(self) return StringToFloat(self._readBytes(self._reader, 8)) end,
    [LibSerializeInt._ReaderIndex.NUM_FLOATSTR_POS]  = function(self) return tonumber(self._readBytes(self._reader, self:_ReadByte())) end,
    [LibSerializeInt._ReaderIndex.NUM_FLOATSTR_NEG]  = function(self) return -tonumber(self._readBytes(self._reader, self:_ReadByte())) end,

    -- Booleans
    [LibSerializeInt._ReaderIndex.BOOL_T] = function(self) return true end,
    [LibSerializeInt._ReaderIndex.BOOL_F] = function(self) return false end,

    -- Strings (encoded as size + buffer)
    [LibSerializeInt._ReaderIndex.STR_8]  = function(self) return self:_ReadString(self:_ReadByte()) end,
    [LibSerializeInt._ReaderIndex.STR_16] = function(self) return self:_ReadString(self:_ReadInt(2)) end,
    [LibSerializeInt._ReaderIndex.STR_24] = function(self) return self:_ReadString(self:_ReadInt(3)) end,

    -- Tables (encoded as count + key/value pairs)
    [LibSerializeInt._ReaderIndex.TABLE_8]  = function(self) return self:_ReadTable(self:_ReadByte()) end,
    [LibSerializeInt._ReaderIndex.TABLE_16] = function(self) return self:_ReadTable(self:_ReadInt(2)) end,
    [LibSerializeInt._ReaderIndex.TABLE_24] = function(self) return self:_ReadTable(self:_ReadInt(3)) end,

    -- Arrays (encoded as count + values)
    [LibSerializeInt._ReaderIndex.ARRAY_8]  = function(self) return self:_ReadArray(self:_ReadByte()) end,
    [LibSerializeInt._ReaderIndex.ARRAY_16] = function(self) return self:_ReadArray(self:_ReadInt(2)) end,
    [LibSerializeInt._ReaderIndex.ARRAY_24] = function(self) return self:_ReadArray(self:_ReadInt(3)) end,

    -- Mixed arrays/maps (encoded as arrayCount + mapCount + arrayValues + key/value pairs)
    [LibSerializeInt._ReaderIndex.MIXED_8]  = function(self) return self:_ReadMixed(self:_ReadPair(self._ReadByte)) end,
    [LibSerializeInt._ReaderIndex.MIXED_16] = function(self) return self:_ReadMixed(self:_ReadPair(self._ReadInt, 2)) end,
    [LibSerializeInt._ReaderIndex.MIXED_24] = function(self) return self:_ReadMixed(self:_ReadPair(self._ReadInt, 3)) end,

    -- Previously referenced strings
    [LibSerializeInt._ReaderIndex.STRINGREF_8]  = function(self) return self._stringRefs[self:_ReadByte()] end,
    [LibSerializeInt._ReaderIndex.STRINGREF_16] = function(self) return self._stringRefs[self:_ReadInt(2)] end,
    [LibSerializeInt._ReaderIndex.STRINGREF_24] = function(self) return self._stringRefs[self:_ReadInt(3)] end,

    -- Previously referenced tables
    [LibSerializeInt._ReaderIndex.TABLEREF_8]  = function(self) return self._tableRefs[self:_ReadByte()] end,
    [LibSerializeInt._ReaderIndex.TABLEREF_16] = function(self) return self._tableRefs[self:_ReadInt(2)] end,
    [LibSerializeInt._ReaderIndex.TABLEREF_24] = function(self) return self._tableRefs[self:_ReadInt(3)] end,
}

function LibSerializeInt:_GetWriteFn(obj)
    local typ = type(obj)
    local writeFn = self._WriterTable[typ]
    if not writeFn and self._opts.errorOnUnserializableType then
        error(("Unhandled type: %s"):format(typ))
    end

    return writeFn
end

function LibSerializeInt:_CanSerialize(...)
    for i = 1, select("#", ...) do
        local obj = select(i, ...)
        local writeFn = self:_GetWriteFn(obj)
        if not writeFn then
            return false
        end
    end

    return true
end

function LibSerializeInt:_ShouldSerialize(t, k, v, filterFn)
    return (not self._opts.filter or self._opts.filter(t, k, v)) and
           (not filterFn or filterFn(t, k, v)) and
           self:_CanSerialize(k, v)
end

function LibSerializeInt:_WriteObject(obj)
    local writeFn = self:_GetWriteFn(obj)
    if not writeFn then
        return false
    end

    writeFn(self, obj)
    return true
end

function LibSerializeInt:_WriteByte(value)
    self:_WriteInt(value, 1)
end

function LibSerializeInt:_WriteInt(n, threshold)
    self._writeString(self._writer, IntToString(n, threshold))
end

local numberIndices = {
    [2] = LibSerializeInt._ReaderIndex.NUM_16_POS,
    [3] = LibSerializeInt._ReaderIndex.NUM_24_POS,
    [4] = LibSerializeInt._ReaderIndex.NUM_32_POS,
    [7] = LibSerializeInt._ReaderIndex.NUM_64_POS,
}
local stringIndices = {
    [1] = LibSerializeInt._ReaderIndex.STR_8,
    [2] = LibSerializeInt._ReaderIndex.STR_16,
    [3] = LibSerializeInt._ReaderIndex.STR_24,
}
local tableIndices = {
    [1] = LibSerializeInt._ReaderIndex.TABLE_8,
    [2] = LibSerializeInt._ReaderIndex.TABLE_16,
    [3] = LibSerializeInt._ReaderIndex.TABLE_24,
}
local arrayIndices = {
    [1] = LibSerializeInt._ReaderIndex.ARRAY_8,
    [2] = LibSerializeInt._ReaderIndex.ARRAY_16,
    [3] = LibSerializeInt._ReaderIndex.ARRAY_24,
}
local mixedIndices = {
    [1] = LibSerializeInt._ReaderIndex.MIXED_8,
    [2] = LibSerializeInt._ReaderIndex.MIXED_16,
    [3] = LibSerializeInt._ReaderIndex.MIXED_24,
}
local stringRefIndices = {
    [1] = LibSerializeInt._ReaderIndex.STRINGREF_8,
    [2] = LibSerializeInt._ReaderIndex.STRINGREF_16,
    [3] = LibSerializeInt._ReaderIndex.STRINGREF_24,
}
local tableRefIndices = {
    [1] = LibSerializeInt._ReaderIndex.TABLEREF_8,
    [2] = LibSerializeInt._ReaderIndex.TABLEREF_16,
    [3] = LibSerializeInt._ReaderIndex.TABLEREF_24,
}

LibSerializeInt._WriterTable = {
    ["nil"] = function(self)
        -- DebugPrint("Serializing nil")
        self:_WriteByte(readerIndexShift * self._ReaderIndex.NIL)
    end,
    ["number"] = function(self, num)
        if IsFloatingPoint(num) then
            local sign = 0
            local numAbs = num
            if num < 0 then
                sign = readerIndexShift
                numAbs = -num
            end
            local asString = tostring(numAbs)
            if #asString < 7 and tonumber(asString) == numAbs and IsFinite(numAbs) then
                self:_WriteByte(sign + readerIndexShift * self._ReaderIndex.NUM_FLOATSTR_POS)
                self:_WriteByte(#asString, 1)
                self._writeString(self._writer, asString)
            else
                self:_WriteByte(readerIndexShift * self._ReaderIndex.NUM_FLOAT)
                self._writeString(self._writer, FloatToString(num))
            end
        elseif num > -4096 and num < 4096 then
            -- The type byte supports two modes by which a number can be embedded:
            -- A 1-byte mode for 7-bit numbers, and a 2-byte mode for 12-bit numbers.
            if num >= 0 and num < 128 then
                -- DebugPrint("Serializing embedded number (1byte):", num)
                self:_WriteByte(num * 2 + 1)
            else
                -- DebugPrint("Serializing embedded number (2bytes):", num)
                local sign = 0
                if num < 0 then
                    sign = 8
                    num = -num
                end
                num = num * 16 + sign + 4
                local upper, lower = math_floor(num / 256), num % 256
                self:_WriteByte(lower)
                self:_WriteByte(upper)
            end
        else
            -- DebugPrint("Serializing number:", num)
            local sign = 0
            if num < 0 then
                num = -num
                sign = readerIndexShift
            end
            local required = GetRequiredBytesNumber(num)
            self:_WriteByte(sign + readerIndexShift * numberIndices[required])
            self:_WriteInt(num, required)
        end
    end,
    ["boolean"] = function(self, bool)
        -- DebugPrint("Serializing bool:", bool)
        self:_WriteByte(readerIndexShift * (bool and self._ReaderIndex.BOOL_T or self._ReaderIndex.BOOL_F))
    end,
    ["string"] = function(self, str)
        local ref = self._stringRefs[str]
        if ref then
            -- DebugPrint("Serializing string ref:", str)
            local required = GetRequiredBytes(ref)
            self:_WriteByte(readerIndexShift * stringRefIndices[required])
            self:_WriteInt(self._stringRefs[str], required)
        else
            local len = #str
            if len < 16 then
                self:_WriteByte(embeddedCountShift * len + embeddedIndexShift * self._EmbeddedIndex.STRING + 2)
            else
                local required = GetRequiredBytes(len)
                self:_WriteByte(readerIndexShift * stringIndices[required])
                self:_WriteInt(len, required)
            end

            self._writeString(self._writer, str)
            if len > 2 then
                self:_AddReference(self._stringRefs, str)
            end
        end
    end,
    ["table"] = function(self, tab)
        local ref = self._tableRefs[tab]
        if ref then
            -- DebugPrint("Serializing table ref:", tab)
            local required = GetRequiredBytes(ref)
            self:_WriteByte(readerIndexShift * tableRefIndices[required])
            self:_WriteInt(self._tableRefs[tab], required)
        else
            self:_AddReference(self._tableRefs, tab)

            local filter
            local mt = getmetatable(tab)
            if mt and type(mt) == "table" and mt.__LibSerialize then
                filter = mt.__LibSerialize.filter
            end

            local arrayCount, serializableArrayCount = 0, 0
            local entireArraySerializable = true
            local totalArraySerializable = 0
            for i, v in ipairs(tab) do
                arrayCount = i
                if self:_ShouldSerialize(tab, i, v, filter) then
                    totalArraySerializable = totalArraySerializable + 1
                    if entireArraySerializable then
                        serializableArrayCount = i
                    end
                else
                    entireArraySerializable = false
                end
            end

            if arrayCount - totalArraySerializable > totalArraySerializable - serializableArrayCount then
                arrayCount = serializableArrayCount
                entireArraySerializable = true
            end

            local mapCount = 0
            local entireMapSerializable = true
            for k, v in pairs(tab) do
                if not IsArrayKey(k, arrayCount) then
                    if self:_ShouldSerialize(tab, k, v, filter) then
                        mapCount = mapCount + 1
                    else
                        entireMapSerializable = false
                    end
                end
            end

            if mapCount == 0 then
                -- The table is an array. We can avoid writing the keys.
                if arrayCount < 16 then
                    self:_WriteByte(embeddedCountShift * arrayCount + embeddedIndexShift * self._EmbeddedIndex.ARRAY + 2)
                else
                    local required = GetRequiredBytes(arrayCount)
                    self:_WriteByte(readerIndexShift * arrayIndices[required])
                    self:_WriteInt(arrayCount, required)
                end

                for i = 1, arrayCount do
                    local v = tab[i]
                    if entireArraySerializable or self:_ShouldSerialize(tab, i, v, filter) then
                        self:_WriteObject(v)
                    else
                        self:_WriteObject(nil)
                    end
                end
            elseif arrayCount ~= 0 then

                if mapCount < 5 and arrayCount < 5 then
                    local combined = (mapCount - 1) * 4 + arrayCount - 1
                    self:_WriteByte(embeddedCountShift * combined + embeddedIndexShift * self._EmbeddedIndex.MIXED + 2)
                else
                    local required = math_max(GetRequiredBytes(mapCount), GetRequiredBytes(arrayCount))
                    self:_WriteByte(readerIndexShift * mixedIndices[required])
                    self:_WriteInt(arrayCount, required)
                    self:_WriteInt(mapCount, required)
                end

                for i = 1, arrayCount do
                    local v = tab[i]
                    if entireArraySerializable or self:_ShouldSerialize(tab, i, v, filter) then
                        self:_WriteObject(v)
                    else
                        self:_WriteObject(nil)
                    end
                end

                local mapCountWritten = 0
                if self._opts.stable then
                    local mapKeys = {}
                    for k, v in pairs(tab) do
                        if not IsArrayKey(k, arrayCount) and (entireMapSerializable or self:_ShouldSerialize(tab, k, v, filter)) then
                            table_insert(mapKeys, k)
                        end
                    end
                    table_sort(mapKeys, StableKeySort)
                    for _, k in ipairs(mapKeys) do
                        self:_WriteObject(k)
                        self:_WriteObject(tab[k])
                        mapCountWritten = mapCountWritten + 1
                    end
                else
                    for k, v in pairs(tab) do
                        -- Exclude keys that have already been written via the previous loop.
                        if not IsArrayKey(k, arrayCount) and (entireMapSerializable or self:_ShouldSerialize(tab, k, v, filter)) then
                            self:_WriteObject(k)
                            self:_WriteObject(v)
                            mapCountWritten = mapCountWritten + 1
                        end
                    end
                end
                assert(mapCount == mapCountWritten)
            else
                if mapCount < 16 then
                    self:_WriteByte(embeddedCountShift * mapCount + embeddedIndexShift * self._EmbeddedIndex.TABLE + 2)
                else
                    local required = GetRequiredBytes(mapCount)
                    self:_WriteByte(readerIndexShift * tableIndices[required])
                    self:_WriteInt(mapCount, required)
                end

                if self._opts.stable then
                    local mapKeys = {}
                    for k, v in pairs(tab) do
                        if entireMapSerializable or self:_ShouldSerialize(tab, k, v, filter) then
                            table_insert(mapKeys, k)
                        end
                    end
                    table_sort(mapKeys, StableKeySort)
                    for _, k in ipairs(mapKeys) do
                        self:_WriteObject(k)
                        self:_WriteObject(tab[k])
                    end
                else
                    for k, v in pairs(tab) do
                        if entireMapSerializable or self:_ShouldSerialize(tab, k, v, filter) then
                            self:_WriteObject(k)
                            self:_WriteObject(v)
                        end
                    end
                end
            end
        end
    end,
}

local serializeTester = CreateSerializer(canSerializeFnOptions)

function LibSerialize:IsSerializableType(...)
    return serializeTester:_CanSerialize(canSerializeFnOptions, ...)
end

function LibSerialize:SerializeEx(opts, ...)
    opts = opts or defaultSerializeOptions

    if opts.async then
        local ser = CreateSerializer(opts, ...)
        local thread = coroutine_create(Serialize)
        local inputSize = select("#", ...)
        local input = {...}

        -- return coroutine handler
        return function()
            return CheckSerializationProgress(thread, coroutine_resume(thread, ser))
        end
    else
        return Serialize(CreateSerializer(opts), ...)
    end
end

function LibSerialize:Serialize(...)
    return self:SerializeEx(defaultSerializeOptions, ...)
end

function LibSerialize:SerializeAsync(...)
    return self:SerializeEx(defaultAsyncOptions, ...)
end

function LibSerialize:SerializeAsyncEx(opts, ...)
    opts = opts or defaultAsyncOptions
    opts.async = true
    return self:SerializeEx(opts, ...)
end

function LibSerialize:DeserializeValue(input, opts)
    opts = opts or defaultDeserializeOptions
    local deser = CreateDeserializer(input, opts)

    if opts.async then
        local thread = coroutine_create(Deserialize)
        return function()
            return CheckDeserializationProgress(thread, coroutine_resume(thread, deser))
        end
    else
        return Deserialize(deser)
    end
end

function LibSerialize:Deserialize(input)
    return pcall(self.DeserializeValue, self, input)
end

function LibSerialize:DeserializeAsync(input, opts)
    opts = opts or defaultAsyncOptions
    opts.async = true
    return self:DeserializeValue(input, opts)
end

return LibSerialize
