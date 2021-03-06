--[[
  This behavior tree code was taken from our Zelda AI project for CMPS 148 at UCSC.
  It is for the most part unmodified, and comments are available for each function.
  Behavior tree code credited to https://gist.github.com/mrunderhill89/
]]--
BT = {}
BT.__index = BT
BT.results = {success = "success", fail = "fail", wait = "wait", error = "error"}
local aresObserverAIArray = {}
local aresActorAIArray = {}
local aresLocalMemory = {}

--[[
    Wrap function values to our results list so that we can use functions
    not tuned to our behavior tree
]]--
function BT:wrap(value)
    --If it's already a member of the results list, return it
    for k,v in pairs(BT.results) do
        if (value == k) then
            return v
        end
        if (value == v) then
            return v
        end
    end
    --If it's false, return fail
    if (value == false) then
        return BT.results.fail
    end
    --If it's anything else, return success
    return BT.results.success
end

--[[
    Creates a new behavior tree node.
    Lua makes it possible to change the type of a node
    just by replacing a function on a per-instance basis,
    making it easy to create new node types while only having to use
    one class. Just specify what run function you want the node to use, and 
    it should work just fine.
--]]
function BT:make(action,guid,shortKey,options)
    local instance = {}
    setmetatable(instance, BT)
    instance.children = {}
    instance.guid = guid
    instance.shortKey = shortKey
    instance.options = options
    --Ideally, actions should return a value from the results enum above and take a single table for arguments
    --Though you should be able to use void and boolean functions, as well.
    instance.run = action
    assert(type(instance.run) == "function", "Behavior tree node needs a run function, got "..type(instance.run).." instead.")
    return instance
end

--[[
    Adds a child to the behavior tree, and set the child's parent.
--]]
function BT:addChild(child)
    table.insert(self.children, child)
end

--[[
    Iterate through the node's children in a loop.
    Halt and return fail if any child fails.
    Otherwise, return success when done.
]]--
function BT:sequence(args)
    for k,v in ipairs(self.children) do
        if (BT:wrap(v:run(args)) == BT.results.fail) then
            return BT.results.fail
        end
    end
    return BT.results.success
end

--[[
    Iterate through the node's children in a loop.
    Halt and return success if any child succeeds.
    Otherwise, return fail when done.
]]--
function BT:select(args)
    for k,v in ipairs(self.children) do
        if (BT:wrap(v:run(args)) == BT.results.success) then
            return BT.results.success
        end
    end
    return BT.results.fail
end

--[[
    Time-sliced version of BT:sequence.
    Needs to be run multiple times (like in a loop) to be effective, but
    doesn't lock up the computer while running.
    
    When finished iterating, it will return either success or fail.
    If not finished, it will return wait.
    
    The index will NOT advance if the current child returns wait, which means
    a child node may be run more than once until it returns a definitive success or fail.
    This lets us chain together multiple time-sliced selectors or sequencers together.
]]--
function BT:slicesequence(args)
    if (self.current == nil) then
        self.current = 1
    else
        local child = self.children[self.current]
        if (child == nil) then
            self.current = 1
            return BT.results.success
        end
        local result = BT:wrap(child:run(args))
        if (result == BT.results.fail) then
            self.current = 1
            return BT.results.fail
        end
        if (result == BT.results.success) then
            self.current = self.current + 1
        end
    end
    return BT.results.wait
end

--[[
    Time-sliced version of BT:select.
    When finished iterating, it will return either success or fail.
    If not finished, it will return wait.
]]--
function BT:sliceselect(args)
    if (self.current == nil) then
        self.current = 1
    else
        local child = self.children[self.current]
        if (child == nil) then
            self.current = 1
            return BT.results.fail
        end
        local result = BT:wrap(child:run(args))
        if (result == BT.results.success) then
            self.current = 1
            return BT.results.success 
        end
        if (result == BT.results.fail) then
            self.current = self.current + 1
        end
    end
    return BT.results.wait
end

--[[
    Simply returns success if its child fails,
    or fail if the child succeeds. Any other result (like wait) is unmodified.
    
    Defaults to success if has no children or its child has
    no run function.
]]--
function BT:invert(args)
    if (self.children[1] == nil) then
        return BT.results.success 
    end
    local result = BT:wrap(self.children[1]:run(args))
    if (result == BT.results.success) then
        return BT.results.fail 
    end
    if (result == BT.results.fail) then
        return BT.results.success 
    end
    return result
end

--[[
    Continuously runs its child until it fails.
]]--
function BT:repeatUntilFail(args)
    while (BT:wrap(children[1]:run(args)) ~= BT.results.fail) do
    end
    return BT.results.success
end

--[[
    Continuously returns wait until its child fails.
    Effectively a time-sliced version of BT:repeatUntilFail.
]]--
function BT:waitUntilFail(args)
    if (BT:wrap(children[1]:run(args)) == BT.results.fail) then
            return BT.results.success
    end
    return BT.results.wait
end

function BT:limit(args)
    if (self.limit == nil) then
        self.limit = 1
        if (self.count == nil) then
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------------------------------------------------------------
-- Unit Roles
local GLOBAL_ROLE_AAW = "aaw"
local GLOBAL_ROLE_AG_ASUW = "ag-asuw"
local GLOBAL_ROLE_AG = "ag"
local GLOBAL_ROLE_ASUW = "asuw"
local GLOBAL_ROLE_SUPPORT = "support"
local GLOBAL_ROLE_ASW = "asw"
local GLOBAL_ROLE_RECON = "recon"
local GLOBAL_ROLE_SEAD = "sead"
local GLOBAL_ROLE_RTB = "rtb"
-- Types
local GLOBAL_TYPE_MISSILES = "missiles"
local GLOBAL_TYPE_PLANES = "planes"
local GLOBAL_TYPE_SAMS = "sams"
local GLOBAL_TYPE_SHIPS = "ships"
local GLOBAL_TYPE_SHIPS_AND_SAMS = "ships_sams"
local GLOBAL_TYPE_DATUM = "datum"
-- Memory Keys
local GLOBAL_ARES_GENERIC_KEY = "ares_generic_key"
local GLOBAL_ARES_INVENTORY_KEY = "ares_inventory_key"
local GLOBAL_ARES_CONTACT_KEY = "ares_contact_key"
local GLOBAL_SAVED_AIR_INVENTORY_KEY = "_saved_air_inventory"
local GLOBAL_SAVED_AIR_CONTACT_KEY = "_saved_air_contact"
local GLOBAL_SAVED_SHIP_CONTACT_KEY = "_saved_ship_contact"
local GLOBAL_SAVED_SUB_CONTACT_KEY = "_saved_sub_contact"
local GLOBAL_SAVED_LAND_CONTACT_KEY = "_saved_land_contact"
local GLOBAL_SAVED_WEAP_CONTACT_KEY = "_saved_weap_contact"
local GLOBAL_SAVED_DATUM_CONTACT_KEY = "_saved_datum_contact"
local GLOBAL_SAVED_MISSIONS_KEY = "_saved_missions"
local GLOBAL_SAVED_MISSIONS_TARGET_ZONES_KEY = "_saved_missions_target_zones"
-- Time Values
local GLOBAL_TIME_EVERY_TWO_SECONDS = "GlobalTimeEveryTwo"
local GLOBAL_TIME_EVERY_FIVE_SECONDS = "GlobalTimeEveryFive"
local GLOBAL_TIME_EVERY_TEN_SECONDS = "GlobalTimeEveryTen"
local GLOBAL_TIME_EVERY_TWENTY_SECONDS = "GlobalTimeEveryTwenty"
local GLOBAL_TIME_EVERY_THIRTY_SECONDS = "GlobalTimeEveryThirty"
local GLOBAL_TIME_EVERY_SIXTY_SECONDS = "GlobalTimeEverySixty"
local GLOBAL_TIME_EVERY_TWO_MINUTES = "GlobalTimeEveryTwoMinutes"
local GLOBAL_TIME_EVERY_FIVE_MINUTES = "GlobalTimeEveryFiveMinutes"
local GLOBAL_TIME_EVERY_TEN_MINUTES = "GlobalTimeEveryTenMinutes"
-- Misc Values
local GLOBAL_OFF = "OFF"
local GLOBAL_ROLE = "role"
-- Throttle Values
local GLOBAL_THROTTLE_STOP = "Stop"
local GLOBAL_THROTTLE_CREEP = "Creep"
local GLOBAL_THROTTLE_CRUISE = "Cruise"
local GLOBAL_THROTTLE_FULL = "Full"
local GLOBAL_THROTTLE_FLANK = "Flank"
local GLOBAL_THROTTLE_LOITER = "Cruise"
local GLOBAL_THROTTLE_MILITARY = "Full"
local GLOBAL_THROTTLE_AFTERBURNER = "Flank"
-- Unit States
local GLOBAL_UNIT_STATE_RTB = "RTB"
local GLOBAL_UNIT_STATE_IS_BINGO = "IsBingo"
local GLOBAL_UNIT_STATE_ENGAGED_OFFENSIVE = "EngagedOffensive"
--------------------------------------------------------------------------------------------------------------------------------
-- Local Generic Memory
--------------------------------------------------------------------------------------------------------------------------------
function localMemoryResetAll()
    aresLocalMemory = {}
end

function localMemoryGetFromKey(primaryKey)
    if not aresLocalMemory[GLOBAL_ARES_GENERIC_KEY] then
        aresLocalMemory[GLOBAL_ARES_GENERIC_KEY] = {}
    end
    if not (aresLocalMemory[GLOBAL_ARES_GENERIC_KEY])[primaryKey] then
        (aresLocalMemory[GLOBAL_ARES_GENERIC_KEY])[primaryKey] = {}
    end
    return (aresLocalMemory[GLOBAL_ARES_GENERIC_KEY])[primaryKey]
end

function localMemoryAddToKey(primaryKey,value)
    local table = localMemoryGetFromKey(primaryKey)
    table[#table + 1] = value
end

function localMemoryRemoveFromKey(primaryKey)
    if aresLocalMemory[GLOBAL_ARES_GENERIC_KEY] then
        if (aresLocalMemory[GLOBAL_ARES_GENERIC_KEY])[primaryKey] then
            (aresLocalMemory[GLOBAL_ARES_GENERIC_KEY])[primaryKey] = nil
        end
    end
	--collectgarbage("collect")
	--ScenEdit_SpecialMessage("Blue Force", ""..collectgarbage("count"))
end

function localMemoryExistForKey(primaryKey,value)
    local table = localMemoryGetFromKey(primaryKey)
    for k, v in pairs(table) do
        if value == v then
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Local Inventory Memory
--------------------------------------------------------------------------------------------------------------------------------
function localMemoryInventoryResetAll()
    aresLocalMemory[GLOBAL_ARES_INVENTORY_KEY] = {}
end

function localMemoryInventoryGetFromKey(primaryKey)
    if not aresLocalMemory[GLOBAL_ARES_INVENTORY_KEY] then
        aresLocalMemory[GLOBAL_ARES_INVENTORY_KEY] = {}
    end
    if not (aresLocalMemory[GLOBAL_ARES_INVENTORY_KEY])[primaryKey] then
        (aresLocalMemory[GLOBAL_ARES_INVENTORY_KEY])[primaryKey] = {}
    end
    return (aresLocalMemory[GLOBAL_ARES_INVENTORY_KEY])[primaryKey]
end

function localMemoryInventoryAddToKey(primaryKey,value)
    local table = localMemoryInventoryGetFromKey(primaryKey)
    table[#table + 1] = value
end

function localMemoryInventoryRemoveFromKey(primaryKey)
    if aresLocalMemory[GLOBAL_ARES_INVENTORY_KEY] then
        if (aresLocalMemory[GLOBAL_ARES_INVENTORY_KEY])[primaryKey] then
            (aresLocalMemory[GLOBAL_ARES_INVENTORY_KEY])[primaryKey] = {}
        end
    end
end

function localMemoryInventoryExistForKey(primaryKey,value)
    local table = localMemoryInventoryGetFromKey(primaryKey)
    for k, v in pairs(table) do
        if value == v then
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Local Memory Tracker
--------------------------------------------------------------------------------------------------------------------------------
function AresGetSide(guid)
	local key = guid
    if aresLocalMemory[key] then
		--ScenEdit_SpecialMessage("Blue Force", "AresGetSide - Local")
        return aresLocalMemory[key]
    else
        local side = VP_GetSide({guid=guid})
        aresLocalMemory[key] = side
        return side
    end
end

function AresGetUnit(sideName,guid)
	local key = guid
    if aresLocalMemory[key] then
		--ScenEdit_SpecialMessage("Blue Force", "AresGetUnit - Local")
        return aresLocalMemory[key]
    else
        local unit = ScenEdit_GetUnit({side=sideName, guid=guid})
        aresLocalMemory[key] = unit
        return unit
    end
end

function AresGetMission(sideName,guid)
	local key = guid
    if aresLocalMemory[key] then
		--ScenEdit_SpecialMessage("Blue Force", "AresGetMission - Local")
        return aresLocalMemory[key]
    else
        local mission = ScenEdit_GetMission(sideName,guid)
        aresLocalMemory[key] = mission
        return mission
    end
end

function AresGetLoadout(guid,loadout)
	local key = guid.."_loadout_"..loadout
    if aresLocalMemory[key] then
		--ScenEdit_SpecialMessage("Blue Force", "AresGetLoadout - Local")
        return aresLocalMemory[key]
    else
        local loadout = ScenEdit_GetLoadout({UnitName=guid, LoadoutID=loadout})
        aresLocalMemory[key] = loadout
        return loadout
    end
end

function AresGetContact(sideName,guid)
	local key = guid
    if aresLocalMemory[key] then
		--ScenEdit_SpecialMessage("Blue Force", "AresGetContact - Local")
        return aresLocalMemory[key]
    else
        local contact = ScenEdit_GetContact({side=sideName, guid=guid})
        aresLocalMemory[key] = contact
        return contact
    end
end

function localMemoryPrintAll()
    local printMessage = tprint(aresLocalMemory)
	ScenEdit_SpecialMessage("Blue Force", printMessage)
end

function deepPrint(e,output)
    -- if e is a table, we should iterate over its elements
    if not type(e)=="string" and not type(e)=="number" then
        for k,v in ipairs(e) do -- for every element in the table
            output = output.." { "..k.." : "
            output = output..deepPrint(v,output)       -- recursively repeat the same procedure
        end
        return output
    else -- if not, we can just print it
        return ""..tostring(e).." } "
    end
end

function tprint (tbl, indent)
  if not indent then indent = 0 end
  local toprint = string.rep(" ", indent) .. "{\r\n"
  indent = indent + 2 
  for k, v in pairs(tbl) do
    toprint = toprint .. string.rep(" ", indent)
    if (type(k) == "number") then
      toprint = toprint .. "[" .. k .. "] = "
    elseif (type(k) == "string") then
      toprint = toprint  .. k ..  "= "   
    end
    if (type(v) == "number") then
      toprint = toprint .. v .. ",\r\n"
    elseif (type(v) == "string") then
      toprint = toprint .. "\"" .. v .. "\",\r\n"
    elseif (type(v) == "table") then
      toprint = toprint .. tprint(v, indent + 2) .. ",\r\n"
    else
      toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
    end
  end
  toprint = toprint .. string.rep(" ", indent-2) .. "}"
  return toprint
end

--------------------------------------------------------------------------------------------------------------------------------
-- Local Contact Memory
--------------------------------------------------------------------------------------------------------------------------------
function localMemoryContactResetAll()
    aresLocalMemory[GLOBAL_ARES_CONTACT_KEY] = {}
end

function localMemoryContactGetFromKey(primaryKey)
    if not aresLocalMemory[GLOBAL_ARES_CONTACT_KEY] then
        aresLocalMemory[GLOBAL_ARES_CONTACT_KEY] = {}
    end
    if not (aresLocalMemory[GLOBAL_ARES_CONTACT_KEY])[primaryKey] then
        (aresLocalMemory[GLOBAL_ARES_CONTACT_KEY])[primaryKey] = {}
    end
    return (aresLocalMemory[GLOBAL_ARES_CONTACT_KEY])[primaryKey]
end

function localMemoryContactAddToKey(primaryKey,value)
    local table = localMemoryContactGetFromKey(primaryKey)
    table[#table + 1] = value
end

function localMemoryContactRemoveFromKey(primaryKey)
    if aresLocalMemory[GLOBAL_ARES_CONTACT_KEY] then
        if (aresLocalMemory[GLOBAL_ARES_CONTACT_KEY])[primaryKey] then
            (aresLocalMemory[GLOBAL_ARES_CONTACT_KEY])[primaryKey] = {}
        end
    end
end

function localMemoryContactExistForKey(primaryKey,value)
    local table = localMemoryContactGetFromKey(primaryKey)
    for k, v in pairs(table) do
        if value == v then
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Combine Tables
--------------------------------------------------------------------------------------------------------------------------------
function combineTablesNew(table1,table2)
    local combinedTable = {}
    for k, v in pairs(table1) do
        combinedTable[#combinedTable + 1] = v
    end
    for k, v in pairs(table2) do
        combinedTable[#combinedTable + 1] = v
    end
    return combinedTable
end

function combineTables(table1,table2)
    for k, v in pairs(table2) do
        table1[#table1 + 1] = v
    end
    return table1
end

--------------------------------------------------------------------------------------------------------------------------------
-- Timestamp Functions
--------------------------------------------------------------------------------------------------------------------------------
function getTimeStampForKey(primaryKey)
    local timeStamp = ScenEdit_GetKeyValue(primaryKey)
    if timeStamp == "" or timeStamp == nil then
        ScenEdit_SetKeyValue(primaryKey,tostring(ScenEdit_CurrentTime()))
        timeStamp = ScenEdit_GetKeyValue(primaryKey)
    end
    return tonumber(timeStamp)
end

function setTimeStampForKey(primaryKey,time)
    ScenEdit_SetKeyValue(primaryKey,time)
end

function updateAITimes()
    local timeStampEveryTwo = getTimeStampForKey(GLOBAL_TIME_EVERY_TWO_SECONDS)
    local timeStampEveryFive = getTimeStampForKey(GLOBAL_TIME_EVERY_FIVE_SECONDS)
    local timeStampEveryTen = getTimeStampForKey(GLOBAL_TIME_EVERY_TEN_SECONDS)
    local timeStampEveryTwenty = getTimeStampForKey(GLOBAL_TIME_EVERY_TWENTY_SECONDS)
    local timeStampEveryThirty = getTimeStampForKey(GLOBAL_TIME_EVERY_THIRTY_SECONDS)
    local timeStampEverySixty = getTimeStampForKey(GLOBAL_TIME_EVERY_SIXTY_SECONDS)
    local timeStampEveryTwoMinutes = getTimeStampForKey(GLOBAL_TIME_EVERY_TWO_MINUTES)
    local timeStampEveryFiveMinutes = getTimeStampForKey(GLOBAL_TIME_EVERY_FIVE_MINUTES)
    local timeStampEveryTenMinutes = getTimeStampForKey(GLOBAL_TIME_EVERY_TEN_MINUTES)
    local currentTime = ScenEdit_CurrentTime()
    if timeStampEveryTwo < currentTime then
        setTimeStampForKey(GLOBAL_TIME_EVERY_TWO_SECONDS,tostring(currentTime + 2))
    end
    if timeStampEveryFive < currentTime then
        setTimeStampForKey(GLOBAL_TIME_EVERY_FIVE_SECONDS,tostring(currentTime + 5))
    end
    if timeStampEveryTen < currentTime then
        setTimeStampForKey(GLOBAL_TIME_EVERY_TEN_SECONDS,tostring(currentTime + 10))
    end
    if timeStampEveryTwenty < currentTime then
        setTimeStampForKey(GLOBAL_TIME_EVERY_TWENTY_SECONDS,tostring(currentTime + 20))
    end
    if timeStampEveryThirty < currentTime then
        setTimeStampForKey(GLOBAL_TIME_EVERY_THIRTY_SECONDS,tostring(currentTime + 30))
    end
    if timeStampEverySixty < currentTime then
        setTimeStampForKey(GLOBAL_TIME_EVERY_SIXTY_SECONDS,tostring(currentTime + 60))
    end
    if timeStampEveryTwoMinutes < currentTime then
        setTimeStampForKey(GLOBAL_TIME_EVERY_TWO_MINUTES,tostring(currentTime + 120))
    end
    if timeStampEveryFiveMinutes < currentTime then
        setTimeStampForKey(GLOBAL_TIME_EVERY_FIVE_MINUTES,tostring(currentTime + 300))
    end
    if timeStampEveryTenMinutes < currentTime then
        setTimeStampForKey(GLOBAL_TIME_EVERY_TEN_MINUTES,tostring(currentTime + 600))
    end
end

function canUpdateEveryTwoSecond()
    local nextTime = getTimeStampForKey(GLOBAL_TIME_EVERY_TWO_SECONDS)
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

function canUpdateEveryFiveSeconds()
    local nextTime = getTimeStampForKey(GLOBAL_TIME_EVERY_FIVE_SECONDS)
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

function canUpdateEveryTenSeconds()
    local nextTime = getTimeStampForKey("GlobalTimeEveryTen")
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

function canUpdateEveryTwentySeconds()
    local nextTime = getTimeStampForKey(GLOBAL_TIME_EVERY_TWENTY_SECONDS)
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

function canUpdateEveryThirtySeconds()
    local nextTime = getTimeStampForKey(GLOBAL_TIME_EVERY_THIRTY_SECONDS)
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

function canUpdateEverySixtySeconds()
    local nextTime = getTimeStampForKey(GLOBAL_TIME_EVERY_SIXTY_SECONDS)
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

function canUpdateEveryTwoMinutes()
    local nextTime = getTimeStampForKey(GLOBAL_TIME_EVERY_TWO_MINUTES)
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

function canUpdateEveryFiveMinutes()
    local nextTime = getTimeStampForKey(GLOBAL_TIME_EVERY_FIVE_MINUTES)
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

function canUpdateEveryTenMinutes()
    local nextTime = getTimeStampForKey(GLOBAL_TIME_EVERY_TEN_MINUTES)
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

function oscillateEveryMinuteGate()
    local averageTime = getTimeStampForKey(GLOBAL_TIME_EVERY_SIXTY_SECONDS) - 30
    local currentTime = ScenEdit_CurrentTime()
	if  currentTime > averageTime then
		return true
	else
		return false
	end
end

function oscillateEveryTwoMinutesGate()
    local averageTime = getTimeStampForKey(GLOBAL_TIME_EVERY_TWO_MINUTES) - 45
    local currentTime = ScenEdit_CurrentTime()
	if  currentTime > averageTime then
		return true
	else
		return false
	end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Generic Helper Functions
--------------------------------------------------------------------------------------------------------------------------------
function makeWaypoint(latitude, longitude, altitude, throttle, followPlottedPath, overrideAltitude, overrideCoordinates)
    local ignorePath = true
    if followPlottedPath then
        ignorePath = false
    end
    return {lat=latitude,lon=longitude,alt=altitude,manualThrottle=throttle,ignorePlottedPath=ignorePath,overrideAltitude=overrideAltitude,overrideCoordinates=overrideCoordinates}
end

function internationalDecimalConverter(value)
    if type(value) == "number" then
        return value
    else 
        local convert = string.gsub(value,",",".")
        return convert
    end
end

function distanceToHorizon(height) 
    return 6371000 * math.acos(6371000/(6371000 + height))
end

function heightToHorizon(distance,role,engaged)
	if role == GLOBAL_ROLE_AAW then
        return heightToHorizonUnderRadarApproach(distance,engaged,false)
    elseif role == GLOBAL_ROLE_AG_ASUW or role == GLOBAL_ROLE_ASUW or role == GLOBAL_ROLE_SEAD then
        return heightToHorizonOverRadarApproach(distance,engaged,true)
    elseif role == GLOBAL_ROLE_SUPPORT then
		return heightToHorizonSupportRadarApproach(distance,engaged,true)
	else
        return heightToHorizonUnderRadarApproach(distance,engaged,false)
    end
end

function heightToHorizonSupportRadarApproach(distance,engaged,popup)
	-- Determine Height
	local height = 0
	if distance > 200 then
		return GLOBAL_OFF
	elseif distance > 180 then
		height = 10000
	elseif distance > 160 then
		height = 10000
	elseif distance > 140 then
		height = 10000
	elseif distance > 120 then
		height = 10000
	elseif distance > 100 then
		height = 2000
	elseif distance > 80 then
		height = 1000
	elseif distance > 60 then
		height = 500
	elseif distance > 40 then
        height = 120
	elseif distance > 20 then
		height = 65
	else
		height = 30
	end
	return height
end

function heightToHorizonOverRadarApproach(distance,engaged,popup)
	-- Determine Height
	local height = 0
	if distance > 300 then
		return GLOBAL_OFF
	elseif distance > 200 then
		height = 10000
	elseif distance > 180 then
		height = 7000
	elseif distance > 160 then
		height = 6000
	elseif distance > 140 then
		height = 5000
	elseif distance > 120 then
		height = 4000
	elseif distance > 100 then
		height = 2000
	elseif distance > 80 then
		height = 1000
	elseif distance > 60 then
		height = 500
	elseif distance > 40 then
        height = 120
	elseif distance > 20 then
		height = 65
	else
		height = 30
	end
	-- Check Engaged
	if popup and engaged and height < 4000 then
		if oscillateEveryMinuteGate() then
			return height
		else
			return GLOBAL_OFF
		end
	else
		return height
	end
end

function heightToHorizonUnderRadarApproach(distance,engaged,popup)
	-- Determine Height
	local height = 0
	if distance > 300 then
		return GLOBAL_OFF
	elseif distance > 200 then
		height = 9000
	elseif distance > 180 then
		height = 6000
	elseif distance > 160 then
		height = 5000
	elseif distance > 140 then
		height = 4000
	elseif distance > 120 then
		height = 3000
	elseif distance > 100 then
		height = 1500
	elseif distance > 80 then
		height = 750
	elseif distance > 60 then
		height = 300
	elseif distance > 50 then
		height = 200
	elseif distance > 40 then
        height = 100
	elseif distance > 20 then
		height = 65
	else
		height = 30
	end
	-- Check Engaged
	if popup and engaged and height < 4000 then
		if oscillateEveryMinuteGate() then
			return height
		else
			return GLOBAL_OFF
		end
	else
		return height
	end
end

function makeLatLong(latitude,longitude)
    local instance = {}
    instance.latitude = internationalDecimalConverter(latitude)
    instance.longitude = internationalDecimalConverter(longitude)
    return instance
end

function midPointCoordinate(lat1,lon1,lat2,lon2)
    lat1 = internationalDecimalConverter(lat1)
    lon1 = internationalDecimalConverter(lon1)
    lat2 = internationalDecimalConverter(lat2)
    lon2 = internationalDecimalConverter(lon2)
    local dLon = math.rad(lon2 - lon1)
    lat1 = math.rad(lat1)
    lat2 = math.rad(lat2)
    lon1 = math.rad(lon1)
    local Bx = math.cos(lat2) * math.cos(dLon)
    local By = math.cos(lat2) * math.sin(dLon)
    local lat3 = math.atan2(math.sin(lat1) + math.sin(lat2), math.sqrt((math.cos(lat1) + Bx) * (math.cos(lat1) + Bx) + By * By))
    local lon3 = lon1 + math.atan2(By, math.cos(lat1) + Bx)
    return makeLatLong(math.deg(lat3),math.deg(lon3))
end

function projectLatLong(origin,bearing,range)
    local radiusEarthKilometres = 3440
    local initialBearingRadians = math.rad(bearing)
    local distRatio = range / radiusEarthKilometres
    local distRatioSine = math.sin(distRatio)
    local distRatioCosine = math.cos(distRatio)
    local startLatRad = math.rad(origin.latitude)
    local startLonRad = math.rad(origin.longitude)
    local startLatCos = math.cos(startLatRad)
    local startLatSin = math.sin(startLatRad)
    local endLatRads = math.asin((startLatSin * distRatioCosine) + (startLatCos * distRatioSine * math.cos(initialBearingRadians)))
    local endLonRads = startLonRad + math.atan2(math.sin(initialBearingRadians) * distRatioSine * startLatCos, distRatioCosine - startLatSin * math.sin(endLatRads))
    return makeLatLong(math.deg(endLatRads),math.deg(endLonRads))
end

function findBoundingBoxForGivenLocations(coordinates,padding)
    local west = 0.0
    local east = 0.0
    local north = 0.0
    local south = 0.0
    if coordinates == nil or #coordinates == 0 then
        padding = 0
    end
    for lc = 1,#coordinates do
        local loc = coordinates[lc]
        if lc == 1 then
            north = loc.latitude
            south = loc.latitude
            west = loc.longitude
            east = loc.longitude
        else
            if loc.latitude > north then
                north = loc.latitude
            elseif loc.latitude < south then
                south = loc.latitude
            end

            if loc.longitude < west then
                west = loc.longitude
            elseif (loc.longitude > east) then
                east = loc.longitude
            end
        end
    end
    north = north + padding
    south = south - padding
    west = west - padding
    east = east + padding
    return {makeLatLong(north,west),makeLatLong(north,east),makeLatLong(south,east),makeLatLong(south,west)}
end

function findBoundingBoxForGivenContacts(sideName,contacts,padding)
    local contactBoundingBox = {}
	local contactCoordinates = {}
    -- Looping
    for k, v in pairs(contacts) do
        local contact = AresGetContact(sideName,v)
        if contact then
            contactCoordinates[#contactCoordinates + 1] = makeLatLong(contact.latitude,contact.longitude)
        end
    end
    -- Get Hostile Contact Bounding Box
    if #contactCoordinates > 0 then
        contactBoundingBox = findBoundingBoxForGivenLocations(contactCoordinates,padding)
    end
    -- Return Bounding Box
    return contactBoundingBox
end

function findBoundingBoxForGivenUnits(sideName,units,padding)
    local unitBoundingBox = {}
	local unitCoordinates = {}
    -- Looping
    for k, v in pairs(units) do
        local unit = AresGetUnit(sideName,v)
        if unit then
            unitCoordinates[#unitCoordinates + 1] = makeLatLong(unit.latitude,unit.longitude)
        end
    end
    -- Get Unit Bounding Box
    if #unitCoordinates > 0 then
        unitBoundingBox = findBoundingBoxForGivenLocations(unitCoordinates,padding)
    end
    -- Return Bounding Box
    return unitBoundingBox
end

function split(s, sep)
    local fields = {}
    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

function getUnitsFromMission(sideName,missionGuid)
    local mission = AresGetMission(sideName,missionGuid)
    local unitKeyValue = {}
    local missionUnits = {}
    if mission then
        for k,v in pairs(mission.unitlist) do
            local unit = AresGetUnit(sideName,v)
            if unit then
                if unitKeyValue[unit.guid] == nil then
                    missionUnits[#missionUnits + 1] = unit.guid
                    unitKeyValue[unit.guid] = ""
                end
            end
        end
    end
    return missionUnits
end

function getGroupLeadsFromMission(sideName,missionGuid,unitType,activeUnits)
    local mission = AresGetMission(sideName,missionGuid)
    local unitKeyValue = {}
    local missionUnits = {}
    local groupGuids = {}
    if mission then
        for k,v in pairs(mission.unitlist) do
            local unit = AresGetUnit(sideName,v)
            -- Filter By Type
			if unit and unit.type == unitType then
				-- Check Only Active
				if activeUnits then
					-- Check Base Exists
					if unit.base then
						if unit.base.altitude ~= unit.altitude or unit.base.longitude ~= unit.longitude or unit.base.latitude ~= unit.latitude then
							if unit.group and #unit.group.unitlist > 0 and unit.group.lead  then
								if (unit.guid == unit.group.lead and not unitKeyValue[unit.guid]) then
									unitKeyValue[unit.guid] = unit.guid
									missionUnits[#missionUnits + 1] = unit.guid
								end
							else
								unitKeyValue[unit.guid] = unit.guid
								missionUnits[#missionUnits + 1] = unit.guid
							end
						end
					else
						-- IMPORTANT - Added Unitlist check, if unit is sinking and only unit in group, unit.group.lead will throw exception
						if unit.group and #unit.group.unitlist > 0 and unit.group.lead  then
							if (unit.guid == unit.group.lead and not unitKeyValue[unit.guid]) then
								unitKeyValue[unit.guid] = unit.guid
								missionUnits[#missionUnits + 1] = unit.guid
							end
						else
							unitKeyValue[unit.guid] = unit.guid
							missionUnits[#missionUnits + 1] = unit.guid
						end
					end
				else
					-- IMPORTANT - Added Unitlist check, if unit is sinking and only unit in group, unit.group.lead will throw exception
					if unit.group and #unit.group.unitlist > 0 and unit.group.lead  then
						if (unit.guid == unit.group.lead and not unitKeyValue[unit.guid]) then
							unitKeyValue[unit.guid] = unit.guid
							missionUnits[#missionUnits + 1] = unit.guid
						end
					else
						unitKeyValue[unit.guid] = unit.guid
						missionUnits[#missionUnits + 1] = unit.guid
					end
				end
            end
        end
    end
    return missionUnits
end

--------------------------------------------------------------------------------------------------------------------------------
-- Determine Helper Functions
--------------------------------------------------------------------------------------------------------------------------------
function determineRoleFromLoadOutDatabase(loudoutId,defaultRole)
    local role = ScenEdit_GetKeyValue("lo_"..tostring(loudoutId))
    if role == nil or role == "" then
        return defaultRole
    else
        return role
    end
end

function determineUnitRTB(unit)
    if unit then
        if unit.unitstate == GLOBAL_UNIT_STATE_RTB then
            return true
        else
            return false
        end
    end
	return false
end

function determineUnitBingo(unit)
    if unit then
        if unit.fuelstate == GLOBAL_UNIT_STATE_IS_BINGO then
            return true
        else
            return false
        end
    end
	return false
end

function determineUnitOffensive(unit)
	if unit.group and #unit.group.unitlist > 0 and unit.group.lead then
		for k1,v1 in pairs(unit.group.unitlist) do
			local subUnit = AresGetUnit(sideName,v1)
			if subUnit.unitstate == GLOBAL_UNIT_STATE_ENGAGED_OFFENSIVE then
				return true
			end
        end
		return false
	else
        if unit.unitstate == GLOBAL_UNIT_STATE_ENGAGED_OFFENSIVE then
            return true
        else
            return false
        end
	end
	return false
end

function determineUnitIsTargtedOrFiredOn(unit)
	local targetedOrFiredOn = false
	if unit.group and #unit.group.unitlist > 0 then
		for k1,v1 in pairs(unit.group.unitlist) do
			local subUnit = AresGetUnit(sideName,v1)
			targetedOrFiredOn = targetedOrFiredOn or (unit.targetedBy or unit.firedOn)
        end
		return targetedOrFiredOn
	else
		return (unit.targetedBy or unit.firedOn)
	end
end

function determineUnitIsFiredOn(unit)
	local firedOn = false
	if unit.group and #unit.group.unitlist > 0 then
		for k1,v1 in pairs(unit.group.unitlist) do
			local subUnit = AresGetUnit(sideName,v1)
			firedOn = firedOn or subUnit.firedOn
        end
		return firedOn
	else
		return firedOn or unit.firedOn
	end
end

function determineUnitRetreatCoordinate(unit,contact,allowPivot,factorBase)
    if contact then
        -- Get Generic Bearing And Retreat Position
		local retreatRange = 15
		local normalizeRange = 10
        local bearing = Tool_Bearing(contact.guid,unit.guid)
        local retreatLocation = projectLatLong(makeLatLong(unit.latitude,unit.longitude),bearing,retreatRange)
        local range = Tool_Range(contact.guid,unit.guid)
        -- Allow Pivot
        if allowPivot and contact.heading and contact.latitude and contact.longitude then
            local headerLocation = projectLatLong(makeLatLong(contact.latitude,contact.longitude),contact.heading,range)
            local headerBearing = Tool_Bearing({latitude=headerLocation.latitude,longitude=headerLocation.longitude},unit.guid)
			local pivotRange = 0
			if range < 20 then
				pivotRange = 15
			elseif range < 100 then
				pivotRange = 5
			end
            retreatLocation = projectLatLong(makeLatLong(retreatLocation.latitude,retreatLocation.longitude),headerBearing,pivotRange)
        end
        -- Factor Base
        if factorBase and unit.base then
            local baseBearing = Tool_Bearing(unit.guid,unit.base.guid)
            retreatLocation = projectLatLong(makeLatLong(retreatLocation.latitude,retreatLocation.longitude),baseBearing,retreatRange*2)
        end
		-- Normalize range
		bearing = Tool_Bearing(unit.guid,{latitude=retreatLocation.latitude,longitude=retreatLocation.longitude})
		retreatLocation = projectLatLong(makeLatLong(unit.latitude,unit.longitude),bearing,normalizeRange)
        -- Return
        return retreatLocation
    else
        -- Default Return
        return projectLatLong(makeLatLong(unit.latitude,unit.longitude),unit.heading,normalizeRange)
    end
end

function determineUnitInMissionTarget(sideShortKey,unit)
	if unit and unit.mission then
		local targetZone = getMissionTargetZone(sideShortKey,unit.mission.guid)
		if targetZone then
			local targetRange = Tool_Range(unit.guid,{latitude=targetZone.latitude,longitude=targetZone.longitude})
			if targetRange <= targetZone.range then
				return true
			else
				return false
			end
		else
			return false
		end
	else
		return false
	end
end

function determineUnitToMissionTarget(unit)
	local range = 1000
	if unit and unit.mission then
		if #unit.mission.targetlist > 0 then
			for k,v in pairs(unit.mission.targetlist) do
				local targetRange = Tool_Range(unit.guid,v)
				if targetRange < range then
					range = targetRange
				end
			end
			return range
		else
			return range
		end
	else
		return range
	end
end

function getMissionTargetZone(sideShortKey,missionGuid)
    local targetZones = localMemoryGetFromKey(sideShortKey..GLOBAL_SAVED_MISSIONS_TARGET_ZONES_KEY)
	if targetZones and #targetZones > 0 then
		return (targetZones[1])[missionGuid]
	else
		return nil
	end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Air Inventory By Role
--------------------------------------------------------------------------------------------------------------------------------
function getAirReconInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey..GLOBAL_SAVED_AIR_INVENTORY_KEY)
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_recon"] then
            return savedInventory[sideShortKey.."_recon"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getAirAawInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey..GLOBAL_SAVED_AIR_INVENTORY_KEY)
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_aaw"] then
            return savedInventory[sideShortKey.."_aaw"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getAirSeadInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey..GLOBAL_SAVED_AIR_INVENTORY_KEY)
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_sead"] then
            return savedInventory[sideShortKey.."_sead"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getAirAsuwInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey..GLOBAL_SAVED_AIR_INVENTORY_KEY)
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_asuw"] then
            return savedInventory[sideShortKey.."_asuw"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getAirAgInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey..GLOBAL_SAVED_AIR_INVENTORY_KEY)
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_ag"] then
            return savedInventory[sideShortKey.."_ag"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getAirAgAsuwInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey..GLOBAL_SAVED_AIR_INVENTORY_KEY)
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_ag-asuw"] then
            return savedInventory[sideShortKey.."_ag-asuw"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getAirAswInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey..GLOBAL_SAVED_AIR_INVENTORY_KEY)
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_asw"] then
            return savedInventory[sideShortKey.."_asw"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getAirSupportInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey..GLOBAL_SAVED_AIR_INVENTORY_KEY)
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_support"] then
            return savedInventory[sideShortKey.."_support"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getAirRTBInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey..GLOBAL_SAVED_AIR_INVENTORY_KEY)
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_rtb"] then
            return savedInventory[sideShortKey.."_rtb"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Contacts
--------------------------------------------------------------------------------------------------------------------------------
function getUnknownAirContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_AIR_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_air_con_X"] then
            return savedContacts[sideShortKey.."_air_con_X"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getHostileAirContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_AIR_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_air_con_H"] then
            return savedContacts[sideShortKey.."_air_con_H"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getAllAirContacts(sideShortKey) 
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_AIR_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_air_con_H_X"] then
            return savedContacts[sideShortKey.."_air_con_H_X"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getUnknownSurfaceShipContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_SHIP_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_surf_con_X"] then
            return savedContacts[sideShortKey.."_surf_con_X"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getHostileSurfaceShipContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_SHIP_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_surf_con_H"] then
            return savedContacts[sideShortKey.."_surf_con_H"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getAllSurfaceShipContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_SHIP_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_surf_con_H_X"] then
            return savedContacts[sideShortKey.."_surf_con_H_X"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getUnknownSubmarineContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_SUB_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_sub_con_X"] then
            return savedContacts[sideShortKey.."_sub_con_X"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getHostileSubmarineContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_SUB_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_sub_con_H"] then
            return savedContacts[sideShortKey.."_sub_con_H"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getAllSubmarineContacts(sideShortKey) 
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_SUB_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_sub_con_H_X"] then
            return savedContacts[sideShortKey.."_sub_con_H_X"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getUnknownSAMContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_LAND_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_sam_con_X"] then
            return savedContacts[sideShortKey.."_sam_con_X"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getHostileSAMContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_LAND_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_sam_con_H"] then
            return savedContacts[sideShortKey.."_sam_con_H"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getAllSAMContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_LAND_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_sam_con_H_X"] then
            return savedContacts[sideShortKey.."_sam_con_H_X"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getUnknownLandContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_LAND_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_land_con_X"] then
            return savedContacts[sideShortKey.."_land_con_X"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getHostileLandContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_LAND_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_land_con_H"] then
            return savedContacts[sideShortKey.."_land_con_H"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getUnknownWeaponContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_WEAP_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_weap_con_X"] then
            return savedContacts[sideShortKey.."_weap_con_X"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getHostileWeaponContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_WEAP_CONTACT_KEY)
    if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        if savedContacts[sideShortKey.."_weap_con_H"] then
            return savedContacts[sideShortKey.."_weap_con_H"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getDatumContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey..GLOBAL_SAVED_DATUM_CONTACT_KEY)
	if #savedContacts > 0 then
        savedContacts = savedContacts[1]
        return savedContacts
    else 
        return {}
    end
end

function getAllSurfaceShipAndSAMContacts(sideShortKey)
    return combineTablesNew(getAllSubmarineContacts(sideShortKey),getAllSAMContacts(sideShortKey))
end

--------------------------------------------------------------------------------------------------------------------------------
-- Determine Unit Retreat Functions
--------------------------------------------------------------------------------------------------------------------------------
function determineAirUnitToRetreatByRole(sideShortKey,sideGuid,sideAttributes,unitGuid,unitRole) 
    local side = AresGetSide(sideGuid)
    local unit = AresGetUnit(side.name,unitGuid)
    if unit and determineUnitIsTargtedOrFiredOn(unit) then
        -- Find Unit Retreat Point
        local unitRetreatPointArray = nil
        -- Determine Retreat Type By Role
        if unitRole == GLOBAL_ROLE_AAW then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,unitRole,{{type=GLOBAL_TYPE_MISSILES,range=60,dive=true},{type=GLOBAL_TYPE_SHIPS_AND_SAMS,range=30,dive=true}})
        elseif unitRole == GLOBAL_ROLE_AG_ASUW then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,unitRole,{{type=GLOBAL_TYPE_MISSILES,range=60,dive=true},{type=GLOBAL_TYPE_SHIPS_AND_SAMS,range=0,dive=true}})
        elseif unitRole == GLOBAL_ROLE_AG then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,unitRole,{{type=GLOBAL_TYPE_MISSILES,range=60,dive=true},{type=GLOBAL_TYPE_PLANES,range=40,dive=false},{type=GLOBAL_TYPE_SHIPS,range=30,dive=true},{type=GLOBAL_TYPE_SAMS,range=0,dive=true}})
        elseif unitRole == GLOBAL_ROLE_ASUW then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,unitRole,{{type=GLOBAL_TYPE_MISSILES,range=80,dive=true},{type=GLOBAL_TYPE_PLANES,range=40,dive=false},{type=GLOBAL_TYPE_SAMS,range=30,dive=true},{type=GLOBAL_TYPE_SHIPS,range=0,dive=true}})
        elseif unitRole == GLOBAL_ROLE_SUPPORT then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,unitRole,{{type=GLOBAL_TYPE_MISSILES,range=150,dive=true},{type=GLOBAL_TYPE_PLANES,range=150,dive=false},{type=GLOBAL_TYPE_SHIPS_AND_SAMS,range=150,dive=false}})
        elseif unitRole == GLOBAL_ROLE_ASW then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,unitRole,{{type=GLOBAL_TYPE_MISSILES,range=60,dive=true},{type=GLOBAL_TYPE_PLANES,range=40,dive=false},{type=GLOBAL_TYPE_SHIPS_AND_SAMS,range=30,dive=false}})
        elseif unitRole == GLOBAL_ROLE_RECON then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,unitRole,{{type=GLOBAL_TYPE_MISSILES,range=60,dive=true},{type=GLOBAL_TYPE_PLANES,range=40,dive=false},{type=GLOBAL_TYPE_SHIPS_AND_SAMS,range=30,dive=false}})
        elseif unitRole == GLOBAL_ROLE_SEAD then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,unitRole,{{type=GLOBAL_TYPE_MISSILES,range=60,dive=true},{type=GLOBAL_TYPE_PLANES,range=40,dive=false},{type=GLOBAL_TYPE_SHIPS_AND_SAMS,range=0,dive=false}})
		elseif unitRole == GLOBAL_ROLE_RTB then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,unitRole,{{type=GLOBAL_TYPE_MISSILES,range=60,dive=true},{type=GLOBAL_TYPE_PLANES,range=40,dive=false},{type=GLOBAL_TYPE_SHIPS_AND_SAMS,range=30,dive=false}})
        else
            unitRetreatPointArray = nil
        end

        -- Set Unit Retreat Point
        if unitRetreatPointArray then
            if unit.group and unit.group.unitlist then
               for k1,v1 in pairs(unit.group.unitlist) do
                    local subUnit = AresGetUnit(side.name,v1)
					ScenEdit_SetDoctrine({side=side.name,guid=subUnit.guid},{ignore_plotted_course = unitRetreatPointArray[1].ignorePlottedPath})
					subUnit.manualAltitude = unitRetreatPointArray[1].alt
					subUnit.manualThrottle = unitRetreatPointArray[1].manualThrottle
					if unitRetreatPointArray[1].overrideCoordinates then
						subUnit.course = unitRetreatPointArray
					end
               end
            else 
				ScenEdit_SetDoctrine({side=side.name,guid=unit.guid},{ignore_plotted_course = unitRetreatPointArray[1].ignorePlottedPath})
				unit.manualAltitude = unitRetreatPointArray[1].alt
				unit.manualThrottle = unitRetreatPointArray[1].manualThrottle
				if unitRetreatPointArray[1].overrideCoordinates then
					unit.course = unitRetreatPointArray
				end
            end
        else
			ScenEdit_SetDoctrine({side=side.name,guid=unit.guid},{ignore_plotted_course = true })
			unit.manualAltitude = GLOBAL_OFF
			unit.manualThrottle = GLOBAL_OFF
        end
    end
end

function determineRetreatPoint(sideGuid,shortSideKey,sideAttributes,unitGuid,unitRole,avoidanceTypes)
    local side = AresGetSide(sideGuid)
    local unit = AresGetUnit(side.name,unitGuid)
    for i = 1, #avoidanceTypes do
        local retreatPointArray  = nil
        if avoidanceTypes[i].type == GLOBAL_TYPE_PLANES then
            retreatPointArray = getRetreatPathForAirNoNavZone(sideGuid,shortSideKey,sideAttributes,unitGuid,unitRole,avoidanceTypes[i].range)
        elseif avoidanceTypes[i].type == GLOBAL_TYPE_SHIPS then
            retreatPointArray = getRetreatPathForGenericNoNavZone(sideGuid,shortSideKey,sideAttributes,getAllSurfaceShipContacts(shortSideKey),unitGuid,unitRole,avoidanceTypes[i].range,avoidanceTypes[i].dive)
        elseif avoidanceTypes[i].type == GLOBAL_TYPE_SAMS then
            retreatPointArray = getRetreatPathForGenericNoNavZone(sideGuid,shortSideKey,sideAttributes,getAllSAMContacts(shortSideKey),unitGuid,unitRole,avoidanceTypes[i].range,avoidanceTypes[i].dive)
        elseif avoidanceTypes[i].type == GLOBAL_TYPE_SHIPS_AND_SAMS then
            retreatPointArray = getRetreatPathForGenericNoNavZone(sideGuid,shortSideKey,sideAttributes,getAllSurfaceShipAndSAMContacts(shortSideKey),unitGuid,unitRole,avoidanceTypes[i].range,avoidanceTypes[i].dive)
        elseif avoidanceTypes[i].type == GLOBAL_TYPE_MISSILES then
            retreatPointArray = getRetreatPathForEmergencyMissileNoNavZone(sideGuid,shortSideKey,sideAttributes,unitGuid,unitRole)
        elseif avoidanceTypes[i].type == GLOBAL_TYPE_DATUM then
            retreatPointArray = getRetreatPathForDatumNoNavZone(sideGuid,shortSideKey,sideAttributes,unitGuid,unitRole)
		else
            retreatPointArray = nil
        end
        -- Return First Valid One
        if retreatPointArray then
            return retreatPointArray 
        end
    end
    -- Catch All Return
    return nil
end

function getRetreatPathForAirNoNavZone(sideGuid,shortSideKey,sideAttributes,unitGuid,unitRole,range)
    local side = AresGetSide(sideGuid)
    local unit = AresGetUnit(side.name,unitGuid)
    local hostileAirContacts = getAllAirContacts(shortSideKey)
    local desiredRange = range
    if not unit and not canUpdateEveryTwentySeconds() then
        return nil
    end
    for k,v in pairs(hostileAirContacts) do
        local contact = AresGetContact(side.name,v)
        if contact then
            local currentRange = Tool_Range(contact.guid,unitGuid)
            if currentRange < desiredRange then
                local retreatLocation = determineUnitRetreatCoordinate(unit,contact,false,determineUnitRTB(unit))
                return {makeWaypoint(retreatLocation.latitude,retreatLocation.longitude,unit.altitude,GLOBAL_THROTTLE_AFTERBURNER,true,false,true)}
            end
        end
    end
    return nil
end

function getRetreatPathForGenericNoNavZone(sideGuid,shortSideKey,sideAttributes,contacts,unitGuid,unitRole,range,dive)
    -- Variables
    local side = AresGetSide(sideGuid)
    local unit = AresGetUnit(side.name,unitGuid)
    local hostileContacts = contacts
    local minDesiredRange = range
    local maxDesiredRange = 200
	local distanceToContact = 10000
	local contact = nil
	
	-- Check Update
    if not unit and not canUpdateEveryTwentySeconds() then
        return nil
    end
	-- Get To Mission Range
	if determineUnitOffensive(unit) and determineUnitInMissionTarget(shortSideKey,unit) then
		return nil
	end
	-- Find Shortest Range Missile
	for k,v in pairs(hostileContacts) do
        local currentContact = AresGetContact(side.name,v)
		if currentContact then
			local distanceToCurrentContact = Tool_Range(v,unitGuid)
			if distanceToCurrentContact < distanceToContact then
                distanceToContact = distanceToCurrentContact
				contact = currentContact
			end
		end
	end
	-- Find Checks
	if not contact then
        return nil
    elseif distanceToContact < minDesiredRange then
        -- Emergency Evasion
		local diveHeight = 30
		if not dive then
			diveHeight = heightToHorizon(distanceToContact,unitRole,determineUnitOffensive(unit))
		end
        local retreatLocation = determineUnitRetreatCoordinate(unit,contact,false,determineUnitRTB(unit))
        return {makeWaypoint(retreatLocation.latitude,retreatLocation.longitude,diveHeight,GLOBAL_THROTTLE_AFTERBURNER,true,true,true)}
    elseif distanceToContact < maxDesiredRange then
        if #unit.course > 0 then
            local waypoint = unit.course[#unit.course]
            return {makeWaypoint(waypoint.latitude,waypoint.longitude,heightToHorizon(distanceToContact,unitRole,determineUnitOffensive(unit)),GLOBAL_THROTTLE_CRUISE,false,true,false)}
        else
            return {makeWaypoint(unit.latitude,unit.longitude,heightToHorizon(distanceToContact,unitRole,determineUnitOffensive(unit)),GLOBAL_THROTTLE_CRUISE,false,true,false)}
        end
    end
    -- Catch All Return
    return nil
end

function getRetreatPathForEmergencyMissileNoNavZone(sideGuid,shortSideKey,sideAttributes,unitGuid,unitRole)
    local side = AresGetSide(sideGuid)
    local unit = AresGetUnit(side.name,unitGuid)
    local hostileMissilesContacts = getHostileWeaponContacts(shortSideKey)
    local minDesiredRange = 8
    local maxDesiredRange = 60
	local distanceToMissile = 10000
	local contact = nil
	-- Check Update
    if not unit and not canUpdateEveryTwoSecond() then
        return nil
    end

	-- Check Fired on
    if not determineUnitIsFiredOn(unit) then
		return nil
    end
    
	-- Get To Mission Range
	if determineUnitOffensive(unit) and determineUnitInMissionTarget(shortSideKey,unit) then
		return nil
    end
    
	-- Find Shortest Range Missile
	for k,v in pairs(hostileMissilesContacts) do
        local currentContact = AresGetContact(side.name,v)
		if currentContact then
			local distanceToCurrentMissile = Tool_Range(v,unitGuid)
			if distanceToCurrentMissile < distanceToMissile then
				distanceToMissile = distanceToCurrentMissile
				contact = currentContact
			end
		end
    end
    
	-- Find Checks
	if not contact then
		return nil
	elseif distanceToMissile < 20 then
		local retreatLocation = determineUnitRetreatCoordinate(unit,contact,true,false)
        return {makeWaypoint(retreatLocation.latitude,retreatLocation.longitude,30,GLOBAL_THROTTLE_AFTERBURNER,true,true,true)}
	elseif distanceToMissile < 100 then
		local retreatLocation = determineUnitRetreatCoordinate(unit,contact,false,false)
		local testing = {makeWaypoint(retreatLocation.latitude,retreatLocation.longitude,heightToHorizon(distanceToMissile,unitRole,determineUnitOffensive(unit)),GLOBAL_THROTTLE_AFTERBURNER,true,true,true)}
		return testing
	else
		return nil
	end
end

function getRetreatPathForDatumNoNavZone(sideGuid,shortSideKey,sideAttributes,unitGuid,unitRole)
    -- Variables
    local side = AresGetSide(sideGuid)
    local unit = AresGetUnit(side.name,unitGuid)
    local datumContacts = getDatumContacts(shortSideKey)
    local maxDesiredRange = 200
    local distanceToDatum = 10000
    
	-- Check Update
    if not unit and not canUpdateEverySixtySeconds() then
        return nil
    end

	-- Get To Mission Range
	if determineUnitOffensive(unit) and determineUnitInMissionTarget(shortSideKey,unit) then
		return nil
    end
    
	-- Find Shortest Range
	for i = 1, #datumContacts do
		local distanceToCurrentDatum = Tool_Range(datumContacts[i],unitGuid)
		if distanceToCurrentDatum < distanceToDatum then
			distanceToDatum = distanceToCurrentDatum
		end
    end
    
	-- Find Checks
	if distanceToDatum < maxDesiredRange then
        if #unit.course > 0 then
            local waypoint = unit.course[#unit.course]
            return {makeWaypoint(waypoint.latitude,waypoint.longitude,heightToHorizon(distanceToDatum,unitRole,determineUnitOffensive(unit)),unit.throttle,false,true,false)}
        else
            return {makeWaypoint(unit.latitude,unit.longitude,heightToHorizon(distanceToDatum,unitRole,determineUnitOffensive(unit)),unit.throttle,false,true,false)}
        end
    end

    -- Catch All Return
    return nil
end

--------------------------------------------------------------------------------------------------------------------------------
-- Observer Functions
--------------------------------------------------------------------------------------------------------------------------------
function observerActionUpdateMissions(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = AresGetSide(args.guid)
    -- Check Every Five Minutes For New Missions
    if canUpdateEveryTenMinutes() then
        -- Loop Through Aircraft Inventory And Then Find Their Missions (Can't Get List Of Missions Currently)
		local aircraftInventory = side:unitsBy("1")
        if aircraftInventory then
            local savedMissions = {}
            localMemoryRemoveFromKey(sideShortKey..GLOBAL_SAVED_MISSIONS_KEY)
            for k, v in pairs(aircraftInventory) do
                -- Local Values
                local unit = AresGetUnit(side.name,v.guid)
                -- Check Mission Exits And Save In Key Value Pairs (Remove Duplication)
                if unit.mission and unit.mission.isactive and unit.speed > 0 and string.match(unit.mission.name, "<Ares>") then
					if not savedMissions[unit.mission.guid] then
						savedMissions[unit.mission.guid] = unit.mission.guid
						-- Save Missions And Time Stamp
						localMemoryAddToKey(sideShortKey..GLOBAL_SAVED_MISSIONS_KEY,unit.mission.guid)
					end
                end
            end
        end
    end
end

function observerActionUpdateMissionInventories(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = AresGetSide(args.guid)
	local sideUnitDuplicateKey = {}
    -- Check Every Five Minutes To Update Inventories
    if canUpdateEverySixtySeconds() then
        local savedMissions = localMemoryGetFromKey(sideShortKey..GLOBAL_SAVED_MISSIONS_KEY)
        local savedInventory = {}
        localMemoryInventoryRemoveFromKey(sideShortKey..GLOBAL_SAVED_AIR_INVENTORY_KEY)
        -- Loop Through Missions
        for k, v in pairs(savedMissions) do
            local mission = AresGetMission(side.name,v)
            if mission.isactive then
				-- Get Group Lead And Individual Units
                local missionRole = mission.subtype
				local missionUnits = getGroupLeadsFromMission(side.name,mission.guid,"Aircraft",true)
				-- Loop Through Units And Determine Unit Role
				for i = 1, #missionUnits do
                    local unit = AresGetUnit(side.name,missionUnits[i])
                    local unitRole = GLOBAL_ROLE_SUPPORT
                    if unit and unit.type == "Aircraft" then
						-- Check Airplane role
                        local loadout = AresGetLoadout(unit.guid,0)
						if loadout then
                            if loadout.roles[GLOBAL_ROLE] == 2001 or loadout.roles[GLOBAL_ROLE] == 2002 or loadout.roles[GLOBAL_ROLE] == 2003 or loadout.roles[GLOBAL_ROLE] == 2004 then
                                unitRole = GLOBAL_ROLE_AAW
                            elseif loadout.roles[GLOBAL_ROLE] == 3001 or loadout.roles[GLOBAL_ROLE] == 3002 or loadout.roles[GLOBAL_ROLE] == 3005 then
                                unitRole = GLOBAL_ROLE_AG_ASUW
                            elseif loadout.roles[GLOBAL_ROLE] == 3101 or loadout.roles[GLOBAL_ROLE] == 3102 or loadout.roles[GLOBAL_ROLE] == 3105 then
                                unitRole = GLOBAL_ROLE_AG
                            elseif loadout.roles[GLOBAL_ROLE] == 3201 or loadout.roles[GLOBAL_ROLE] == 3202 or loadout.roles[GLOBAL_ROLE] == 3205 then
                                unitRole = GLOBAL_ROLE_ASUW
                            elseif loadout.roles[GLOBAL_ROLE] == 4001 or loadout.roles[GLOBAL_ROLE] == 4002 or loadout.roles[GLOBAL_ROLE] == 4003 or loadout.roles[GLOBAL_ROLE] == 4004 or loadout.roles[GLOBAL_ROLE] == 4101 then
                                unitRole = GLOBAL_ROLE_SUPPORT
                            elseif loadout.roles[GLOBAL_ROLE] == 6001 or loadout.roles[GLOBAL_ROLE] == 6002 then
                                unitRole = GLOBAL_ROLE_ASW
                            elseif loadout.roles[GLOBAL_ROLE] == 7001 or loadout.roles[GLOBAL_ROLE] == 7002 or loadout.roles[GLOBAL_ROLE] == 7003 or loadout.roles[GLOBAL_ROLE] == 7004 or loadout.roles[GLOBAL_ROLE] == 7005 then
                                unitRole = GLOBAL_ROLE_RECON
                            elseif loadout.roles[GLOBAL_ROLE] == 3003 or loadout.roles[GLOBAL_ROLE] == 3004 or loadout.roles[GLOBAL_ROLE] == 3103 or loadout.roles[GLOBAL_ROLE] == 3104 or loadout.roles[GLOBAL_ROLE] == 3203 or loadout.roles[GLOBAL_ROLE] == 3204 then
                                unitRole = GLOBAL_ROLE_SEAD
                            end
                        end
						-- Compare Mission Role Vs Unit Role (Mission Role Takes Precedent In Certain Conditions)
						if determineUnitRTB(unit) or determineUnitBingo(unit) then
							unitRole = GLOBAL_ROLE_RTB
						elseif missionRole == "AAW Patrol" or missionRole == "Air Intercept" then
							-- No Override - Units Will Retain Their Respective Role
						elseif missionRole == "ASuW Patrol (Naval)" or missionRole == "Sea Control Patrol" or missionRole == "ASuW Patrol Mixed" or missionRole == "Naval ASuW Strike" then
							if unitRole == GLOBAL_ROLE_AG_ASUW or unitRole == GLOBAL_ROLE_AG or unitRole == GLOBAL_ROLE_ASUW or unitRole == GLOBAL_ROLE_SEAD then
								unitRole = GLOBAL_ROLE_ASUW
							end
						elseif missionRole == "ASW Patrol" or missionRole == "ASW Strike" then
							-- No Override - Units Will Retain Their Respective Role
						elseif missionRole == "ASuW Patrol Ground" or missionRole == "Land Strike" then
							if unitRole == GLOBAL_ROLE_AG_ASUW or unitRole == GLOBAL_ROLE_AG then
								unitRole = GLOBAL_ROLE_AG
							end
						elseif missionRole == "SEAD Patrol" then
							if unitRole == GLOBAL_ROLE_AG_ASUW or unitRole == GLOBAL_ROLE_AG then
								unitRole = GLOBAL_ROLE_SEAD
							end
						elseif missionRole == "Ferry" then
							unitRole = GLOBAL_ROLE_SUPPORT
						end
						-- Add To Memory
						local stringKey = sideShortKey.."_"..unitRole
						local stringArray = savedInventory[stringKey]
						if not stringArray then
							stringArray = {}
						end
						-- Increment Add Save
						stringArray[#stringArray + 1] = unit.guid
						savedInventory[stringKey] = stringArray
				   end
				end
            end
        end
        -- Save Memory Inventory And Time Stamp
        localMemoryInventoryAddToKey(sideShortKey..GLOBAL_SAVED_AIR_INVENTORY_KEY,savedInventory)
    end
end

function observerActionUpdateMissionTargetZones(args)
-- Local Variables
    local sideShortKey = args.shortKey
    local side = AresGetSide(args.guid)
	local sideUnitDuplicateKey = {}
    -- Check Every Five Minutes To Update Inventories
    if canUpdateEveryTenMinutes() then
        local savedMissions = localMemoryGetFromKey(sideShortKey..GLOBAL_SAVED_MISSIONS_KEY)
        local targetZonesInventory = {}
        localMemoryRemoveFromKey(sideShortKey..GLOBAL_SAVED_MISSIONS_TARGET_ZONES_KEY)
        -- Loop Through Missions
        for k, v in pairs(savedMissions) do
            local mission = AresGetMission(side.name,v)
            if mission.isactive and #mission.targetlist > 0 then
				-- Update Mission Targetlist Zone
				local missionTargetBox = findBoundingBoxForGivenUnits(side.name,mission.targetlist,0)
				local midPointCoordinate = midPointCoordinate(missionTargetBox[1].latitude,missionTargetBox[1].longitude,missionTargetBox[3].latitude,missionTargetBox[3].longitude)
				local range = 0
				-- Loop
				for i = 1, #missionTargetBox do
					local currentRange = Tool_Range({latitude=midPointCoordinate.latitude, longitude=midPointCoordinate.longitude}, {latitude=missionTargetBox[i].latitude, longitude=missionTargetBox[i].longitude})
					if currentRange > range then
						range = currentRange
					end
				end
				-- Target Zone
				targetZonesInventory[mission.guid] = {latitude=midPointCoordinate.latitude, longitude=midPointCoordinate.longitude, range=(range + 40)}
            end
        end
        -- Save Memory Inventory And Time Stamp
        localMemoryAddToKey(sideShortKey..GLOBAL_SAVED_MISSIONS_TARGET_ZONES_KEY,targetZonesInventory)
    end
end

function observerActionUpdateAirContacts(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = AresGetSide(args.guid)
    -- Check Time
    if canUpdateEveryTwoMinutes() then
        local aircraftContacts = side:contactsBy("1")
        localMemoryContactRemoveFromKey(sideShortKey..GLOBAL_SAVED_AIR_CONTACT_KEY)
        if aircraftContacts then
            local savedContacts = {}
            for k, v in pairs(aircraftContacts) do
                -- Local Values
                local contact = AresGetContact(side.name,v.guid)
                local unitType = "air_con"
                -- Add To Memory
                local stringKey = sideShortKey.."_"..unitType.."_"..contact.posture
                local stringArray = savedContacts[stringKey]
                if not stringArray then
                    stringArray = {}
                end
                stringArray[#stringArray + 1] = contact.guid
                savedContacts[stringKey] = stringArray
                -- Add Hostile And Unknown Together In Memory
                if contact.posture == "X" or contact.posture == "H" then
                    stringKey = sideShortKey.."_"..unitType.."_H_X"
                    stringArray = savedContacts[stringKey]
                    if not stringArray then
                        stringArray = {}
                    end
                    stringArray[#stringArray + 1] = contact.guid
                    savedContacts[stringKey] = stringArray
                end
            end
            localMemoryContactAddToKey(sideShortKey..GLOBAL_SAVED_AIR_CONTACT_KEY,savedContacts)
        end
    end
end

function observerActionUpdateSurfaceContacts(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = AresGetSide(args.guid)
	local testing = 0
    if canUpdateEveryTwoMinutes() then
        local shipContacts = side:contactsBy("2")
        localMemoryContactRemoveFromKey(sideShortKey..GLOBAL_SAVED_SHIP_CONTACT_KEY)
        if shipContacts then
            local savedContacts = {}
            for k, v in pairs(shipContacts) do
                -- Local Values
                local contact = AresGetContact(side.name,v.guid)
                local unitType = "surf_con"
                -- Add To Memory
                local stringKey = sideShortKey.."_"..unitType.."_"..contact.posture
                local stringArray = savedContacts[stringKey]
                if not stringArray then
                    stringArray = {}
                end
                stringArray[#stringArray + 1] = contact.guid
                savedContacts[stringKey] = stringArray
                -- Add Hostile And Unknown Together In Memory
                if contact.posture == "X" or contact.posture == "H" then
					testing = testing + 1
                    stringKey = sideShortKey.."_"..unitType.."_H_X"
                    stringArray = savedContacts[stringKey]
                    if not stringArray then
                        stringArray = {}
                    end
                    stringArray[#stringArray + 1] = contact.guid
                    savedContacts[stringKey] = stringArray
                end
            end
            localMemoryContactAddToKey(sideShortKey..GLOBAL_SAVED_SHIP_CONTACT_KEY,savedContacts)
        end
    end
end

function observerActionUpdateSubmarineContacts(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = AresGetSide(args.guid)
    if canUpdateEveryTwoMinutes() then
        local submarineContacts = side:contactsBy("3")
        localMemoryContactRemoveFromKey(sideShortKey..GLOBAL_SAVED_SUB_CONTACT_KEY)
        if submarineContacts then
            local savedContacts = {}
            for k, v in pairs(submarineContacts) do
                -- Local Values
                local contact = AresGetContact(side.name,v.guid)
                local unitType = "sub_con"
                -- Add To Memory
                local stringKey = sideShortKey.."_"..unitType.."_"..contact.posture
                local stringArray = savedContacts[stringKey]
                if not stringArray then
                    stringArray = {}
                end
                stringArray[#stringArray + 1] = contact.guid
                savedContacts[stringKey] = stringArray
                -- Add Hostile And Unknown Together In Memory
                if contact.posture == "X" or contact.posture == "H" then
                    stringKey = sideShortKey.."_"..unitType.."_H_X"
                    stringArray = savedContacts[stringKey]
                    if not stringArray then
                        stringArray = {}
                    end
                    stringArray[#stringArray + 1] = contact.guid
                    savedContacts[stringKey] = stringArray
                end
            end
            localMemoryContactAddToKey(sideShortKey..GLOBAL_SAVED_SUB_CONTACT_KEY,savedContacts)
        end
    end
end

function observerActionUpdateLandContacts(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = AresGetSide(args.guid)
    if canUpdateEveryTwoMinutes() then
        local landContacts = side:contactsBy("4")
        localMemoryContactRemoveFromKey(sideShortKey..GLOBAL_SAVED_LAND_CONTACT_KEY)
		--local printString = ""
        if landContacts then
            local savedContacts = {}
            for k, v in pairs(landContacts) do
                -- Local Values
                local contact = AresGetContact(side.name,v.guid)
                local unitType = "land_con"
                -- Check
                if string.find(contact.type_description,"SAM") or contact.emissions or string.find(contact.type_description,"Unknown mobile land unit") then 
                    unitType = "sam_con"
                    -- Add To Memory
                    local stringKey = sideShortKey.."_"..unitType.."_"..contact.posture
                    local stringArray = savedContacts[stringKey]
                    if not stringArray then
                        stringArray = {}
                    end
                    stringArray[#stringArray + 1] = contact.guid
                    savedContacts[stringKey] = stringArray
                    -- Add Hostile And Unknown Together In Memory
                    if contact.posture == "X" or contact.posture == "H" then
                        stringKey = sideShortKey.."_"..unitType.."_H_X"
                        stringArray = savedContacts[stringKey]
                        if not stringArray then
                            stringArray = {}
                        end
                        stringArray[#stringArray + 1] = contact.guid
                        savedContacts[stringKey] = stringArray
                    end
                end
            end
            localMemoryContactAddToKey(sideShortKey..GLOBAL_SAVED_LAND_CONTACT_KEY,savedContacts)
        end
    end
end

function observerActionUpdateWeaponContacts(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = AresGetSide(args.guid)
    if canUpdateEveryFiveSeconds() then
        local weaponContacts = side:contactsBy("6")
        localMemoryContactRemoveFromKey(sideShortKey..GLOBAL_SAVED_WEAP_CONTACT_KEY)
        if weaponContacts then
            local savedContacts = {}
            for k, v in pairs(weaponContacts) do
                -- Local Values
                local contact = AresGetContact(side.name,v.guid)
                local unitType = "weap_con"
                -- Filter Out By Weapon Speed
                if contact.speed then
                    if  contact.speed > 1400 then
                        -- Add To Memory
                        local stringKey = sideShortKey.."_"..unitType.."_"..contact.posture
                        local stringArray = savedContacts[stringKey]
                        if not stringArray then
                            stringArray = {}
                        end
                        stringArray[#stringArray + 1] = contact.guid
                        savedContacts[stringKey] = stringArray
                    end
                else 
                    -- Add To Memory
                    local stringKey = sideShortKey.."_"..unitType.."_"..contact.posture
                    local stringArray = savedContacts[stringKey]
                    if not stringArray then
                        stringArray = {}
                    end
                    stringArray[#stringArray + 1] = contact.guid
                    savedContacts[stringKey] = stringArray
                end
            end
            localMemoryContactAddToKey(sideShortKey..GLOBAL_SAVED_WEAP_CONTACT_KEY,savedContacts)
        end
    end
end

function observerActionUpdateDatumContacts(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = AresGetSide(args.guid)
    if canUpdateEveryFiveSeconds() then
		-- Local Datums
		local datumContacts = getDatumContacts(sideShortKey)
		local weaponContacts = getHostileWeaponContacts(sideShortKey)
		local savedContacts = {}
		localMemoryContactRemoveFromKey(sideShortKey..GLOBAL_SAVED_DATUM_CONTACT_KEY)
		-- Loop Alert Datums
		for i = 1, #weaponContacts do
			local contact = AresGetContact(side.name,v.weaponContacts[i])
			local inside = false
			if contact then
				for j = 1, #datumContacts do 
					if Tool_Range({latitude=contact.latitude, longitude=contact.longitude}, datumContacts[j]) <= 100 then
						-- Update Item
						datumContacts[j] = {latitude=contact.latitude, longitude=contact.longitude, timeStamp=(ScenEdit_CurrentTime() + 1800)}
						inside = true
						break
					end
				end
				if not inside then
					-- Add New Item
					datumContacts[#datumContacts + 1] = {latitude=contact.latitude, longitude=contact.longitude, timeStamp=(ScenEdit_CurrentTime() + 1800)}
				end
			end
		end
		-- Remove Outdated Timestamps
		for i = 1, #datumContacts do
			if ScenEdit_CurrentTime() <= datumContacts[i].timeStamp then
				savedContacts[#savedContacts + 1] = datumContacts[i]
			end
		end
        localMemoryContactAddToKey(sideShortKey..GLOBAL_SAVED_DATUM_CONTACT_KEY,savedContacts)
    end
end

function observerActionUpdateTestMemory(args)
    if canUpdateEveryFiveMinutes() then
		localMemoryPrintAll()
	end
end

function resetAllInventoriesAndContacts()
    localMemoryInventoryResetAll()
    localMemoryContactResetAll()
end

--------------------------------------------------------------------------------------------------------------------------------
-- Actor - Control EMCON And Movement
--------------------------------------------------------------------------------------------------------------------------------
function actorUpdateReconUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    -- Get Recon Units
    local reconUnits = getAirReconInventory(sideShortKey)
    for i = 1, #reconUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,reconUnits[i],GLOBAL_ROLE_RECON) 
	end
end

function actorUpdateAAWUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    -- Get AAW Units
    local aawUnits = getAirAawInventory(sideShortKey)
    for i = 1, #aawUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,aawUnits[i],GLOBAL_ROLE_AAW)
	end
end

function actorUpdateAGUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    -- Get AG Units
    local agUnits = getAirAgInventory(sideShortKey)
    for i = 1, #agUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,agUnits[i],GLOBAL_ROLE_AG)
	end
end

function actorUpdateAGAsuWUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    -- Get AG-ASUW Units
    local agAsuwUnits = getAirAgAsuwInventory(sideShortKey)
    for i = 1, #agAsuwUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,agAsuwUnits[i],GLOBAL_ROLE_AG_ASUW)
	end
end

function actorUpdateAsuWUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    -- Get ASUW Units
    local asuwUnits = getAirAsuwInventory(sideShortKey)
    for i = 1, #asuwUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,asuwUnits[i],GLOBAL_ROLE_ASUW)
	end
end

function actorUpdateASWUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    -- Get ASUW Units
    local asuwUnits = getAirAswInventory(sideShortKey)
    for i = 1, #asuwUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,asuwUnits[i],GLOBAL_ROLE_ASW)
	end
end

function actorUpdateSeadUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    -- Get SEAD Units
    local seadUnits = getAirSeadInventory(sideShortKey)
    for i = 1, #seadUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,seadUnits[i],GLOBAL_ROLE_SEAD)
	end
end

function actorUpdateSupportUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    -- Get Support Units
    local supportUnits = getAirSupportInventory(sideShortKey)
    for i = 1, #supportUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,supportUnits[i],GLOBAL_ROLE_SUPPORT)
	end
end

function actorUpdateRTBUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    -- Get Support Units
    local rtbUnits = getAirRTBInventory(sideShortKey)
    for i = 1, #rtbUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,rtbUnits[i],GLOBAL_ROLE_RTB)
	end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Initialize AI
--------------------------------------------------------------------------------------------------------------------------------
function initializeAresAI(sideName)
    -- Local Values
    local side = ScenEdit_GetSideOptions({side=sideName})
    local sideGuid = side.guid
    local shortSideKey = "a"..tostring(#aresObserverAIArray + 1)
    local attributes = {}
    -- Ares OA Selectors 
    local aresObserverBTMain = BT:make(BT.sequence,sideGuid,shortSideKey,attributes)
    local aresActorBTMain = BT:make(BT.sequence,sideGuid,shortSideKey,attributes)
    ----------------------------------------------------------------------------------------------------------------------------
    -- Ares Observer
    ----------------------------------------------------------------------------------------------------------------------------
    local observerActionUpdateMissionsBT = BT:make(observerActionUpdateMissions,sideGuid,shortSideKey,attributes)
	local observerActionUpdateMissionTargetZonesBT = BT:make(observerActionUpdateMissionTargetZones,sideGuid,shortSideKey,attributes)
    local observerActionUpdateMissionInventoriesBT = BT:make(observerActionUpdateMissionInventories,sideGuid,shortSideKey,attributes)
    local observerActionUpdateAirContactsBT = BT:make(observerActionUpdateAirContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateSurfaceContactsBT = BT:make(observerActionUpdateSurfaceContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateSubmarineContactsBT = BT:make(observerActionUpdateSubmarineContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateLandContactsBT = BT:make(observerActionUpdateLandContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateWeaponContactsBT = BT:make(observerActionUpdateWeaponContacts,sideGuid,shortSideKey,attributes)
	--local observerActionUpdateDatumContactsBT = BT:make(observerActionUpdateDatumContacts,sideGuid,shortSideKey,attributes)
	--[[local observerActionUpdateTestMemoryBT = BT:make(observerActionUpdateTestMemory,sideGuid,shortSideKey,attributes)]]--
	
    -- Add Observers
    aresObserverBTMain:addChild(observerActionUpdateMissionsBT)
	aresObserverBTMain:addChild(observerActionUpdateMissionTargetZonesBT)
    aresObserverBTMain:addChild(observerActionUpdateMissionInventoriesBT)
    aresObserverBTMain:addChild(observerActionUpdateAirContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateSurfaceContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateSubmarineContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateLandContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateWeaponContactsBT)
    --[[--aresObserverBTMain:addChild(observerActionUpdateDatumContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateTestMemoryBT)]]--
    ----------------------------------------------------------------------------------------------------------------------------
    -- Ares Actor
    ----------------------------------------------------------------------------------------------------------------------------
    local actorUpdateReconUnitsBT = BT:make(actorUpdateReconUnits,sideGuid,shortSideKey,attributes)
    local actorUpdateAAWUnitsBT = BT:make(actorUpdateAAWUnits,sideGuid,shortSideKey,attributes)
    local actorUpdateAGUnitsBT = BT:make(actorUpdateAGUnits,sideGuid,shortSideKey,attributes)
    local actorUpdateAGAsuWUnitsBT = BT:make(actorUpdateAGAsuWUnits,sideGuid,shortSideKey,attributes)
    local actorUpdateAsuWUnitsBT = BT:make(actorUpdateAsuWUnits,sideGuid,shortSideKey,attributes)
    local actorUpdateASWUnitsBT = BT:make(actorUpdateASWUnits,sideGuid,shortSideKey,attributes)
    local actorUpdateSeadUnitsBT = BT:make(actorUpdateSeadUnits,sideGuid,shortSideKey,attributes)
    local actorUpdateSupportUnitsBT = BT:make(actorUpdateSupportUnits,sideGuid,shortSideKey,attributes)
	local actorUpdateRTBUnitsBT = BT:make(actorUpdateRTBUnits,sideGuid,shortSideKey,attributes)
    -- Add Actors
    aresActorBTMain:addChild(actorUpdateReconUnitsBT)
    aresActorBTMain:addChild(actorUpdateAAWUnitsBT)
    aresActorBTMain:addChild(actorUpdateAGUnitsBT)
    aresActorBTMain:addChild(actorUpdateAGAsuWUnitsBT)
    aresActorBTMain:addChild(actorUpdateAsuWUnitsBT)
    aresActorBTMain:addChild(actorUpdateASWUnitsBT)
    aresActorBTMain:addChild(actorUpdateSeadUnitsBT)
    aresActorBTMain:addChild(actorUpdateSupportUnitsBT)
    aresActorBTMain:addChild(actorUpdateRTBUnitsBT)
    ----------------------------------------------------------------------------------------------------------------------------
    -- Save
    ----------------------------------------------------------------------------------------------------------------------------
    aresObserverAIArray[#aresObserverAIArray + 1] = aresObserverBTMain
    aresActorAIArray[#aresActorAIArray + 1] = aresActorBTMain
end

function updateAresAI()
    -- Run Observer
    for k, v in pairs(aresObserverAIArray) do
        v:run()
    end
    -- Run Actor
    for k, v in pairs(aresActorAIArray) do
        v:run()
    end
    -- Update Times
    updateAITimes()
end

--------------------------------------------------------------------------------------------------------------------------------
-- Global Call
--------------------------------------------------------------------------------------------------------------------------------
initializeAresAI("Blue Force")