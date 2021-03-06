--[[
  This behavior tree code was taken from our Zelda AI project for CMPS 148 at UCSC.
  It is for the most part unmodified, and comments are available for each function.
  Behavior tree code credited to https://gist.github.com/mrunderhill89/
]]--
BT = {}
BT.__index = BT
BT.results = {success = "success", fail = "fail", wait = "wait", error = "error"}
local aresObserverAIArray = {}
local aresOrienterAIArray = {}
local aresDeciderAIArray = {}
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
-- Local Generic Memory
--------------------------------------------------------------------------------------------------------------------------------
function localMemoryResetAll()
    aresLocalMemory = {}
end

function localMemoryGetFromKey(primaryKey)
    if not aresLocalMemory["ares_generic_key"] then
        aresLocalMemory["ares_generic_key"] = {}
    end
    if not (aresLocalMemory["ares_generic_key"])[primaryKey] then
        (aresLocalMemory["ares_generic_key"])[primaryKey] = {}
    end
    return (aresLocalMemory["ares_generic_key"])[primaryKey]
end

function localMemoryAddToKey(primaryKey,value)
    local table = localMemoryGetFromKey(primaryKey)
    table[#table + 1] = value
end

function localMemoryRemoveFromKey(primaryKey)
    if aresLocalMemory["ares_generic_key"] then
        if (aresLocalMemory["ares_generic_key"])[primaryKey] then
            (aresLocalMemory["ares_generic_key"])[primaryKey] = {}
        end
    end
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
    aresLocalMemory["ares_inventory_key"] = {}
end

function localMemoryInventoryGetFromKey(primaryKey)
    if not aresLocalMemory["ares_inventory_key"] then
        aresLocalMemory["ares_inventory_key"] = {}
    end
    if not (aresLocalMemory["ares_inventory_key"])[primaryKey] then
        (aresLocalMemory["ares_inventory_key"])[primaryKey] = {}
    end
    return (aresLocalMemory["ares_inventory_key"])[primaryKey]
end

function localMemoryInventoryAddToKey(primaryKey,value)
    local table = localMemoryInventoryGetFromKey(primaryKey)
    table[#table + 1] = value
end

function localMemoryInventoryRemoveFromKey(primaryKey)
    if aresLocalMemory["ares_inventory_key"] then
        if (aresLocalMemory["ares_inventory_key"])[primaryKey] then
            (aresLocalMemory["ares_inventory_key"])[primaryKey] = {}
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

function localMemoryPrintAll()
    local printMessage = ""
    deepPrint(aresLocalMemory,printMessage)
end

function deepPrint(e,output)
    -- if e is a table, we should iterate over its elements
    if not type(e)=="string" and not type(e)=="number" then
        for k,v in pairs(e) do -- for every element in the table
            output = output.." { "..k.." : "
            output = output..deepPrint(v,output)       -- recursively repeat the same procedure
        end
        return output
    else -- if not, we can just print it
        return ""..tostring(e).." } "
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Local Contact Memory
--------------------------------------------------------------------------------------------------------------------------------
function localMemoryContactResetAll()
    aresLocalMemory["ares_contact_key"] = {}
end

function localMemoryContactGetFromKey(primaryKey)
    if not aresLocalMemory["ares_contact_key"] then
        aresLocalMemory["ares_contact_key"] = {}
    end
    if not (aresLocalMemory["ares_contact_key"])[primaryKey] then
        (aresLocalMemory["ares_contact_key"])[primaryKey] = {}
    end
    return (aresLocalMemory["ares_contact_key"])[primaryKey]
end

function localMemoryContactAddToKey(primaryKey,value)
    local table = localMemoryContactGetFromKey(primaryKey)
    table[#table + 1] = value
end

function localMemoryContactRemoveFromKey(primaryKey)
    if aresLocalMemory["ares_contact_key"] then
        if (aresLocalMemory["ares_contact_key"])[primaryKey] then
            (aresLocalMemory["ares_contact_key"])[primaryKey] = {}
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
-- Persistent Generic Memory
--------------------------------------------------------------------------------------------------------------------------------
function persistentMemoryGetForKey(primaryKey)
    local value = ScenEdit_GetKeyValue(primaryKey)
    if value == nil then
        value = ""
    end
    return split(value,",")
end

function persistentMemoryAddToKey(primaryKey,value)
    local valueString = ScenEdit_GetKeyValue(primaryKey)
    if valueString == nil then
        valueString = value
    else
        valueString = valueString..","..value
    end
    ScenEdit_SetKeyValue(primaryKey,valueString)
end

function persistentMemoryResetFromKey(primaryKey)
    ScenEdit_SetKeyValue(primaryKey,"")
end

function persistentMemoryRemoveFromKey(primaryKey,value)
    local table = persistentMemoryGetForKey(primaryKey)
    local valueString = nil
    for k, v in pairs(table) do
        if value ~= v then
            if valueString then
                valueString = valueString..","..v
            else
                valueString = v
            end
        end
    end
    ScenEdit_SetKeyValue(primaryKey,valueString)
end

function persistentMemoryValueExists(primaryKey,value)
    local table = persistentMemoryGetForKey(primaryKey)
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
    local timeStampEveryTen = getTimeStampForKey("GlobalTimeEveryTen")
    local timeStampEveryTwenty = getTimeStampForKey("GlobalTimeEveryTwenty")
    local timeStampEveryThirty = getTimeStampForKey("GlobalTimeEveryThirty")
    local timeStampEverySixty = getTimeStampForKey("GlobalTimeEverySixty")
    local timeStampEveryTwoMinutes = getTimeStampForKey("GlobalTimeEveryTwoMinutes")
    local timeStampEveryFiveMinutes = getTimeStampForKey("GlobalTimeEveryFiveMinutes")
    local timeStampEveryFifteenMinutes = getTimeStampForKey("GlobalTimeEveryFifteenMinutes")
    local currentTime = ScenEdit_CurrentTime()
    if timeStampEveryTen < currentTime then
        setTimeStampForKey("GlobalTimeEveryTen",tostring(currentTime + 10))
    end
    if timeStampEveryTwenty < currentTime then
        setTimeStampForKey("GlobalTimeEveryTwenty",tostring(currentTime + 20))
    end
    if timeStampEveryThirty < currentTime then
        setTimeStampForKey("GlobalTimeEveryThirty",tostring(currentTime + 30))
    end
    if timeStampEverySixty < currentTime then
        setTimeStampForKey("GlobalTimeEverySixty",tostring(currentTime + 60))
    end
    if timeStampEveryTwoMinutes < currentTime then
        setTimeStampForKey("GlobalTimeEveryTwoMinutes",tostring(currentTime + 120))
    end
    if timeStampEveryFiveMinutes < currentTime then
        setTimeStampForKey("GlobalTimeEveryFiveMinutes",tostring(currentTime + 300))
    end
    if timeStampEveryFifteenMinutes < currentTime then
        setTimeStampForKey("GlobalTimeEveryFifteenMinutes",tostring(currentTime + 900))
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
    local nextTime = getTimeStampForKey("GlobalTimeEveryTwenty")
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

function canUpdateEveryThirtySeconds()
    local nextTime = getTimeStampForKey("GlobalTimeEveryThirty")
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

function canUpdateEverySixtySeconds()
    local nextTime = getTimeStampForKey("GlobalTimeEverySixty")
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

function canUpdateEveryTwoMinutes()
    local nextTime = getTimeStampForKey("GlobalTimeEveryTwoMinutes")
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

function canUpdateEveryFiveMinutes()
    local nextTime = getTimeStampForKey("GlobalTimeEveryFiveMinutes")
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

function canUpdateEveryFifteenMinutes()
    local nextTime = getTimeStampForKey("GlobalTimeEveryFifteenMinutes")
    local currentTime = ScenEdit_CurrentTime()
    if nextTime < currentTime then
        return true
    else
        return false
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Generic Helper Functions
--------------------------------------------------------------------------------------------------------------------------------
function internationalDecimalConverter(value)
    if type(value) == "number" then
        return value
    else 
        local convert = string.gsub(value,",",".")
        return convert
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

function findBoundingBoxForGivenContacts(sideName,contacts,defaults,padding)
    local contactBoundingBox = findBoundingBoxForGivenLocations({makeLatLong(defaults[1].latitude,defaults[1].longitude),makeLatLong(defaults[2].latitude,defaults[2].longitude),makeLatLong(defaults[3].latitude,defaults[3].longitude),makeLatLong(defaults[4].latitude,defaults[4].longitude)},padding)
    local contactCoordinates = {}
    -- Looping
    for k, v in pairs(contacts) do
        local contact = ScenEdit_GetContact({side=sideName, guid=v})
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

function findBoundingBoxForGivenUnits(sideName,units,defaults,padding)
    local unitBoundingBox = findBoundingBoxForGivenLocations({makeLatLong(defaults[1].latitude,defaults[1].longitude),makeLatLong(defaults[2].latitude,defaults[2].longitude),makeLatLong(defaults[3].latitude,defaults[3].longitude),makeLatLong(defaults[4].latitude,defaults[4].longitude)},padding)
    local unitCoordinates = {}
    -- Looping
    for k, v in pairs(units) do
        local unit = ScenEdit_GetUnit({side=sideName, guid=v})
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
    local mission = ScenEdit_GetMission(sideName,missionGuid)
    local unitKeyValue = {}
    local missionUnits = {}
    if mission then
        for k,v in pairs(mission.unitlist) do
            local unit = ScenEdit_GetUnit({side=sideName, guid=v})
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

function getGroupLeadsFromMission(sideName,missionGuid)
    local mission = ScenEdit_GetMission(sideName,missionGuid)
    local unitKeyValue = {}
    local missionUnits = {}
    local groupGuids = {}
    if mission then
        for k,v in pairs(mission.unitlist) do
            local unit = ScenEdit_GetUnit({side=sideName, guid=v})
            if unit then
                -- IMPORTANT - Added Unitlist check, if unit is sinking and only unit in group, unit.group.lead will throw exception
                if unit.group and #unit.group.unitlist > 0 and unit.group.lead  then
                    if (unit.guid == unit.group.lead) then
                        missionUnits[#missionUnits + 1] = unit.guid
                    end
                else
                    missionUnits[#missionUnits + 1] = unit.guid
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

function determineUnitRTB(sideName,unitGuid)
    local unit = ScenEdit_GetUnit({side=sideName, guid=unitGuid})
    if unit then
        if unit.unitstate == "RTB" then
            return true
        else
            return false
        end
    end
end

function determineUnitBingo(sideName,unitGuid)
    local unit = ScenEdit_GetUnit({side=sideName, guid=unitGuid})
    if unit then
        if unit.fuelstate == "IsBingo" then
            return true
        else
            return false
        end
    end
end

function determineHVAByUnitDatabaseId(sideShortKey,unitGuid,unitDBID)
    local hva = ScenEdit_GetKeyValue("hv_"..tostring(unitDBID))
    if hva == "HV" then
        return true
    else
        return false
    end
end

function determineAndAddHVTByUnitDatabaseId(sideShortKey,unitGuid,unitDBID)
    local hva = ScenEdit_GetKeyValue("hv_"..tostring(unitDBID))
    if hva == "HV" then
        localMemoryAddToKey(sideShortKey.."_def_hvt",unitGuid)
    end
end

function determineThreatRangeByUnitDatabaseId(sideShortKey,sideGuid,contactGuid)
    local side = VP_GetSide({guid=sideGuid})
    local contact = ScenEdit_GetContact({side=side.name, guid=contactGuid})
    local threatRangeDecay = tonumber(ScenEdit_GetKeyValue(sideShortKey.."_threat_range_decay"))
    local range = 0
    if not contact then
        return 5
    end
    for k,v in pairs(contact.potentialmatches) do
        local foundRange = ScenEdit_GetKeyValue("thr_"..tostring(v.DBID))
        if foundRange ~= "" then
            range = tonumber(foundRange)
            break
        end
    end
    if range == 0 and contact.actualunitdbid then
        local foundRange = ScenEdit_GetKeyValue("thr_"..tostring(contact.actualunitdbid))
        if foundRange ~= "" then
            range = tonumber(foundRange)
        end
    end
    if range == 0 and contact.side then
        local unit = ScenEdit_GetUnit({side=contact.side.name, guid=contact.actualunitid})
        if unit then
            if unit.autodetectable then
                local foundRange = ScenEdit_GetKeyValue("thr_"..tostring(unit.dbid))
                if foundRange ~= "" then
                    range = tonumber(foundRange)
                end
            end
        end
    end
    if range == 0 then
        if contact.missile_defence <= 2 then
            range = 5
        elseif contact.missile_defence <= 5 then
            range = 20
        elseif contact.missile_defence <= 7 then
            range = 40
        elseif contact.missile_defence <= 20 then
            range = 80
        else 
            range = 130
        end
    end
    -- Return Range
    return range * threatRangeDecay
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Fighter Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeAirFighterInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_fig_free"] then
            return savedInventory[sideShortKey.."_fig_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusyAirFighterInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_fig_busy"] then
            return savedInventory[sideShortKey.."_fig_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Stealth Fighter Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeAirStealthInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_sfig_free"] then
            return savedInventory[sideShortKey.."_sfig_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusyAirStealthInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_sfig_busy"] then
            return savedInventory[sideShortKey.."_sfig_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Air Multirole Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeAirMultiroleInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_mul_free"] then
            return savedInventory[sideShortKey.."_mul_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusyAirMultiroleInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_mul_busy"] then
            return savedInventory[sideShortKey.."_mul_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Air Attack Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeAirAttackInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_atk_free"] then
            return savedInventory[sideShortKey.."_atk_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusyAirAttackInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_atk_busy"] then
            return savedInventory[sideShortKey.."_atk_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Air SEAD Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeAirSeadInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_sead_free"] then
            return savedInventory[sideShortKey.."_sead_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusyAirSeadInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_sead_busy"] then
            return savedInventory[sideShortKey.."_sead_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Air AEW Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeAirAEWInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_aew_free"] then
            return savedInventory[sideShortKey.."_aew_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusyAirAEWInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_aew_busy"] then
            return savedInventory[sideShortKey.."_aew_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Air ASuW Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeAirASuWInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_asuw_free"] then
            return savedInventory[sideShortKey.."_asuw_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusyAirASuWInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_asuw_busy"] then
            return savedInventory[sideShortKey.."_asuw_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Air ASW Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeAirASWInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_asw_free"] then
            return savedInventory[sideShortKey.."_asw_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusyAirASWInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_asw_busy"] then
            return savedInventory[sideShortKey.."_asw_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Air Recon Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeAirReconInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_rec_free"] then
            return savedInventory[sideShortKey.."_rec_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusyAirReconInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_rec_busy"] then
            return savedInventory[sideShortKey.."_rec_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Air Tanker Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeAirTankerInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_tan_free"] then
            return savedInventory[sideShortKey.."_tan_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusyAirTankerInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_tan_busy"] then
            return savedInventory[sideShortKey.."_tan_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Air UAV Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeAirUAVInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_uav_free"] then
            return savedInventory[sideShortKey.."_uav_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusyAirUAVInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_uav_busy"] then
            return savedInventory[sideShortKey.."_uav_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Air UCAV Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeAirUCAVInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_ucav_free"] then
            return savedInventory[sideShortKey.."_ucav_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusyAirUCAVInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_ucav_busy"] then
            return savedInventory[sideShortKey.."_ucav_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Surface Ship Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeSurfaceShipInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_ship_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_surf_free"] then
            return savedInventory[sideShortKey.."_surf_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusySurfaceShipInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_ship_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_surf_busy"] then
            return savedInventory[sideShortKey.."_surf_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Submarine Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeSubmarineInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_sub_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_sub_free"] then
            return savedInventory[sideShortKey.."_sub_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusySubmarineInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_sub_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_sub_busy"] then
            return savedInventory[sideShortKey.."_sub_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get SAM Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getFreeSAMInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_land_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_sam_free"] then
            return savedInventory[sideShortKey.."_sam_free"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getBusySAMInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_land_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_sam_busy"] then
            return savedInventory[sideShortKey.."_sam_busy"]
        else
            return {}
        end
    else 
        return {}
    end
end


--------------------------------------------------------------------------------------------------------------------------------
-- Get Total Inventory Strength
--------------------------------------------------------------------------------------------------------------------------------
function getAllInventoryStrength(sideShortKey)
    local totalStrength = #getFreeAirFighterInventory(sideShortKey)
    totalStrength = totalStrength + #getBusyAirFighterInventory(sideShortKey)
    totalStrength = totalStrength + #getFreeAirStealthInventory(sideShortKey)
    totalStrength = totalStrength + #getBusyAirStealthInventory(sideShortKey)
    totalStrength = totalStrength + #getFreeAirMultiroleInventory(sideShortKey)
    totalStrength = totalStrength + #getBusyAirMultiroleInventory(sideShortKey)
    totalStrength = totalStrength + #getFreeAirAttackInventory(sideShortKey)
    totalStrength = totalStrength + #getBusyAirAttackInventory(sideShortKey)
    totalStrength = totalStrength + #getFreeAirSeadInventory(sideShortKey)
    totalStrength = totalStrength + #getBusyAirSeadInventory(sideShortKey)
    totalStrength = totalStrength + #getFreeAirAEWInventory(sideShortKey)
    totalStrength = totalStrength + #getBusyAirAEWInventory(sideShortKey)
    totalStrength = totalStrength + #getFreeAirASuWInventory(sideShortKey)
    totalStrength = totalStrength + #getBusyAirASuWInventory(sideShortKey)
    totalStrength = totalStrength + #getFreeAirASWInventory(sideShortKey)
    totalStrength = totalStrength + #getBusyAirASWInventory(sideShortKey)
    totalStrength = totalStrength + #getFreeAirReconInventory(sideShortKey)
    totalStrength = totalStrength + #getBusyAirReconInventory(sideShortKey)
    totalStrength = totalStrength + #getFreeAirTankerInventory(sideShortKey)
    totalStrength = totalStrength + #getBusyAirTankerInventory(sideShortKey)
    totalStrength = totalStrength + #getFreeAirUAVInventory(sideShortKey)
    totalStrength = totalStrength + #getBusyAirUAVInventory(sideShortKey)
    totalStrength = totalStrength + #getFreeAirUCAVInventory(sideShortKey)
    totalStrength = totalStrength + #getBusyAirUCAVInventory(sideShortKey)
    return totalStrength
end

function getAllInventory(sideShortKey)
    local totalInventory = combineTablesNew(getFreeAirFighterInventory(sideShortKey),getBusyAirFighterInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getFreeAirStealthInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getBusyAirStealthInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getFreeAirMultiroleInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getBusyAirMultiroleInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getFreeAirAttackInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getBusyAirAttackInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getFreeAirSeadInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getBusyAirSeadInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getFreeAirAEWInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getBusyAirAEWInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getFreeAirASuWInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getBusyAirASuWInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getFreeAirASWInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getBusyAirASWInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getFreeAirReconInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getBusyAirReconInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getFreeAirTankerInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getBusyAirTankerInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getFreeAirUAVInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getBusyAirUAVInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getFreeAirUCAVInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getBusyAirUCAVInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getFreeSurfaceShipInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getBusySurfaceShipInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getFreeSubmarineInventory(sideShortKey))
    totalInventory = combineTables(totalInventory,getBusySubmarineInventory(sideShortKey))
    return totalInventory
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Contacts
--------------------------------------------------------------------------------------------------------------------------------
function getUnknownAirContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey.."_saved_air_contact")
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
    local savedContacts = localMemoryContactGetFromKey(sideShortKey.."_saved_air_contact")
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

function getUnknownSurfaceShipContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey.."_saved_ship_contact")
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
    local savedContacts = localMemoryContactGetFromKey(sideShortKey.."_saved_ship_contact")
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

function getUnknownSubmarineContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey.."_saved_sub_contact")
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
    local savedContacts = localMemoryContactGetFromKey(sideShortKey.."_saved_sub_contact")
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

function getUnknownSAMContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey.."_saved_land_contact")
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
    local savedContacts = localMemoryContactGetFromKey(sideShortKey.."_saved_land_contact")
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

function getUnknownLandContacts(sideShortKey)
    local savedContacts = localMemoryContactGetFromKey(sideShortKey.."_saved_land_contact")
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
    local savedContacts = localMemoryContactGetFromKey(sideShortKey.."_saved_land_contact")
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
    local savedContacts = localMemoryContactGetFromKey(sideShortKey.."_saved_weap_contact")
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
    local savedContacts = localMemoryContactGetFromKey(sideShortKey.."_saved_weap_contact")
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

function getAllHostileContacts(sideShortKey)
    local totalContacts = combineTablesNew(getHostileAirContacts(sideShortKey),getHostileSurfaceShipContacts(sideShortKey))
    totalContacts = combineTables(totalContacts,getHostileSubmarineContacts(sideShortKey))
    totalContacts = combineTables(totalContacts,getHostileSAMContacts(sideShortKey))
    totalContacts = combineTables(totalContacts,getHostileLandContacts(sideShortKey))
    return totalContacts
end


function getAllSubmarineContacts(sideShortKey)
    local totalContacts = combineTablesNew(getUnknownSubmarineContacts(sideShortKey),getHostileSubmarineContacts(sideShortKey))
    return totalContacts
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Contact Strength
--------------------------------------------------------------------------------------------------------------------------------
function getHostileAirContactsStrength(sideShortKey)
    return #getHostileAirContacts(sideShortKey)
end

function getHostileSurfaceShipContactsStrength(sideShortKey)
    return #getHostileSurfaceShipContacts(sideShortKey)
end

function getHostileSubmarineContactsStrength(sideShortKey)
    return #getHostileSubmarineContacts(sideShortKey)
end

function getHostileSAMContactsStrength(sideShortKey)
    return #getHostileSAMContacts(sideShortKey)
end

function getHostileLandContactsStrength(sideShortKey)
    return #getHostileLandContacts(sideShortKey)
end

function getAllHostileContactStrength(sideShortKey)
    local totalHostileStrength = #getHostileAirContacts(sideShortKey)
    totalHostileStrength = totalHostileStrength + #getHostileSurfaceShipContacts(sideShortKey)
    totalHostileStrength = totalHostileStrength + #getHostileSubmarineContacts(sideShortKey)
    return totalHostileStrength
end

--------------------------------------------------------------------------------------------------------------------------------
-- Reinforcement Requests Functions
--------------------------------------------------------------------------------------------------------------------------------
function addReinforcementRequest(sideShortKey,sideAttributes,sideName,missionName,quantity)
    --local determinedModifier = sideAttributes.determined * 2 / (sideAttributes.determined + sideAttributes.reserved)
    --quantity = math.ceil(quantity * determinedModifier)
    localMemoryAddToKey(sideShortKey.."_reinforce_request",{name=missionName,number=quantity})
end

function getReinforcementRequests(sideShortKey)
    local reinforceRequests = localMemoryGetFromKey(sideShortKey.."_reinforce_request")
    local returnRequests = {}
    for k,v in pairs(reinforceRequests) do
        returnRequests[tostring(v.name)] = v.number
    end
    return returnRequests
end

function clearReinforcementRequests(sideShortKey)
    localMemoryRemoveFromKey(sideShortKey.."_reinforce_request")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Allocate Unit Functions
--------------------------------------------------------------------------------------------------------------------------------
function addAllocatedUnit(sideShortKey,unitGuid)
    local allocatedUnits = localMemoryGetFromKey(sideShortKey.."_alloc_units")
    local allocatedUnitsTable = {}
    if #allocatedUnits == 1 then
        allocatedUnitsTable = allocatedUnits[1]
    end
    allocatedUnitsTable[unitGuid] = unitGuid
    localMemoryRemoveFromKey(sideShortKey.."_alloc_units")
    localMemoryAddToKey(sideShortKey.."_alloc_units",allocatedUnitsTable)
end

function getAllocatedUnitExists(sideShortKey,unitGuid)
    local allocatedUnits = localMemoryGetFromKey(sideShortKey.."_alloc_units")
    local allocatedUnitsTable = {}
    if #allocatedUnits == 1 then
        allocatedUnitsTable = allocatedUnits[1]
        if allocatedUnitsTable[unitGuid] then
            return true
        else
            return false
        end
    else
        return false
    end
end

function removeAllocatedUnit(sideShortKey)
    localMemoryRemoveFromKey(sideShortKey.."_alloc_units")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Determine Assign Functions
--------------------------------------------------------------------------------------------------------------------------------
function determineUnitsToUnAssign(sideShortKey,sideName,missionGuid)
    local mission = ScenEdit_GetMission(sideName,missionGuid)
    local missionUnits = getUnitsFromMission(sideName,missionGuid)
    if mission then
        for k,v in pairs(missionUnits) do
            local unit = ScenEdit_GetUnit({side=sideName, guid=v})
            if unit then
                if unit.speed == 0 and tostring(unit.readytime) ~= "0"  then
                    local mockMission = ScenEdit_AddMission(sideName,"MOCK MISSION",'strike',{type='land'})
                    ScenEdit_AssignUnitToMission(unit.guid, mockMission.guid)  
                    ScenEdit_DeleteMission(sideName,mockMission.guid) 
                else
                    addAllocatedUnit(sideShortKey,unit.guid)
                end
            end
        end        
    end
end

function determineUnitsToAssign(sideShortKey,sideName,missionGuid,totalRequiredUnits,unitGuidList)
    -- Local Values
    local mission = ScenEdit_GetMission(sideName,missionGuid)
    local missionUnits = getUnitsFromMission(sideName,missionGuid)
    local missionUnitsCount = #missionUnits
    local allocatedUnitsTable = localMemoryGetFromKey(sideShortKey.."_alloc_units")
    totalRequiredUnits = totalRequiredUnits - missionUnitsCount
    if mission then
        for k,v in pairs(unitGuidList) do
            if totalRequiredUnits <= 0 then
                break
            end
            local unit = ScenEdit_GetUnit({side=sideName, guid=v})
            if unit then
                if not getAllocatedUnitExists(sideShortKey,unit.guid) then
                    if (not determineUnitRTB(sideName,v) and unit.speed > 0) or (tostring(unit.readytime) == "0" and unit.speed == 0) then
                        totalRequiredUnits = totalRequiredUnits - 1
                        ScenEdit_AssignUnitToMission(v,mission.guid,false,false)
                        addAllocatedUnit(sideShortKey,unit.guid)
                    end
                end
            end
        end
        if totalRequiredUnits == 0 then
            return true
        else
            return false
        end
    end
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Determine Emcon Functions
--------------------------------------------------------------------------------------------------------------------------------
function determineEmconToAirUnits(sideShortKey,sideAttributes,sideName,unitGuidList)
    local busyAEWInventory = getBusyAirAEWInventory(sideShortKey)
    local emconChangeState = ScenEdit_GetKeyValue(sideShortKey.."_emcon_chg_state")
    if not canUpdateEveryThirtySeconds() then
        return
    end
    for k,v in pairs(unitGuidList) do
        local unit = ScenEdit_GetUnit({side=sideName, guid=v})
        -- Radar Emission Control
        if unit and unit.speed > 0 and not unit.firingAt then
            ScenEdit_SetEMCON("Unit",unit.guid,"Radar="..emconChangeState)
            for k1,v1 in pairs(busyAEWInventory) do
                local aewUnit = ScenEdit_GetUnit({side=sideName, guid=v1})
                if aewUnit and aewUnit.speed > 0 then
                    if Tool_Range(v1,v) < 160 then
                        ScenEdit_SetEMCON("Unit",unit.guid,"Radar=Passive")
                        break
                    end
                end
            end
        end
        -- Jammer Emission Control
        if unit then
            if unit.targetedBy and unit.firedOn then
                ScenEdit_SetEMCON("Unit",unit.guid,"OECM=Active")
            else
                ScenEdit_SetEMCON("Unit",unit.guid,"OECM=Passive")
            end
        end
    end
end

function determineEmconForSAMUnits(sideShortKey,sideAttributes,sideName,unitGuidList)
    if not canUpdateEveryThirtySeconds() then
        return
    end
    for k,v in pairs(unitGuidList) do
        local unit = ScenEdit_GetUnit({side=sideName, guid=v})
        -- Radar Emission Control
        if unit then
            if unit.speed > 0 then
                ScenEdit_SetEMCON("Unit",unit.guid,"Radar=Passive")
            else
                if unit.targetedBy and unit.firedOn then
                    ScenEdit_SetEMCON("Unit",unit.guid,"Radar=Passive")
                else
                    ScenEdit_SetEMCON("Unit",unit.guid,"Radar=Active")
                end
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Determine Unit Retreat Functions
--------------------------------------------------------------------------------------------------------------------------------
function determineUnitToRetreat(sideShortKey,sideGuid,sideAttributes,missionGuid,missionUnits,zoneType,retreatRange)
    local side = VP_GetSide({guid=sideGuid})
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name,guid=v})
        if missionUnit and missionUnit.speed > 0 and not determineUnitBingo(side.name,missionUnit.guid) and (missionUnit.targetedBy or missionUnit.firedOn) then
            local unitRetreatPoint = {}
            if zoneType == 0 then
                unitRetreatPoint = getAllNoNavZoneThatContainsUnit(sideGuid,sideShortKey,sideAttributes,missionUnit.guid,retreatRange)
            elseif zoneType == 1 then
                unitRetreatPoint = getSAMAndShipNoNavZoneThatContainsUnit(sideGuid,sideShortKey,sideAttributes,missionUnit.guid)
            elseif zoneType == 2 then
                unitRetreatPoint = getAirAndShipNoNavZoneThatContainsUnit(sideGuid,sideShortKey,sideAttributes,missionUnit.guid,retreatRange)
            elseif zoneType == 3 then
                unitRetreatPoint = getAirAndSAMNoNavZoneThatContainsUnit(sideGuid,sideShortKey,sideAttributes,missionUnit.guid,retreatRange)
            else
                unitRetreatPoint = nil
            end
            if unitRetreatPoint ~= nil then
                if missionUnit.group and missionUnit.group.unitlist then
                    for k1,v1 in pairs(missionUnit.group.unitlist) do
                        local subUnit = ScenEdit_GetUnit({side=side.name,guid=v1})
                        ScenEdit_SetDoctrine({side=side.name,guid=subUnit.guid},{ignore_plotted_course = "no" })
                        subUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
                        subUnit.manualSpeed = unitRetreatPoint.speed
                    end
                else 
                    ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "no" })
                    missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
                    missionUnit.manualSpeed = unitRetreatPoint.speed
                end
            else
                ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "yes" })
                missionUnit.manualSpeed = "OFF"
            end
        end
    end
end

function determineSurfaceUnitToRetreat(sideShortKey,sideGuid,sideAttributes,missionGuid,missionUnits,retreatRange)
    local side = VP_GetSide({guid=sideGuid})
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name,guid=v})
        if missionUnit then
            local unitRetreatPoint = getSubmarineNoNavZoneThatContainsUnit(sideGuid,sideShortKey,sideAttributes,missionUnit.guid,retreatRange)
            if unitRetreatPoint ~= nil then
                if missionUnit.group and missionUnit.group.unitlist then
                    for k1,v1 in pairs(missionUnit.group.unitlist) do
                        local subUnit = ScenEdit_GetUnit({side=side.name,guid=v1})
                        ScenEdit_SetDoctrine({side=side.name,guid=subUnit.guid},{ignore_plotted_course = "no" })
                        subUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
                        subUnit.manualSpeed = unitRetreatPoint.speed
                    end
                else 
                    ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "no" })
                    missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
                    missionUnit.manualSpeed = unitRetreatPoint.speed
                end
            else
                ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "yes" })
                missionUnit.manualSpeed = "OFF"
            end
        end
    end
end

function determineSubmarineUnitApproachSpeed(sideShortKey,sideGuid,sideAttributes,missionGuid,missionUnits)
    local side = VP_GetSide({guid=sideGuid})
    local unknownSubmarineContacts = getUnknownSubmarineContacts(sideShortKey)
    local unknownSurfaceShipContacts = getUnknownSurfaceShipContacts(sideShortKey)
    local hostileSubmarineContacts = getHostileSubmarineContacts(sideShortKey)
    local hostileSurfaceShipContacts = getHostileSurfaceShipContacts(sideShortKey)
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name,guid=v})
        local foundContact = nil
        local foundBearing = 0
        local foundRange = 0
        local foundSpeed = 0
        if missionUnit then
            -- Start Approach In Less Than 10 Nautical Miles
            if not foundContact then
                for k,v in pairs(unknownSubmarineContacts) do
                    local contact = ScenEdit_GetContact({side=side.name, guid=v})
                    if contact then
                        local currentRange = Tool_Range(missionUnit.guid,contact.guid)
                        if currentRange < 20 then
                            foundRange = Tool_Range(missionUnit.guid,contact.guid)
                            foundContact = contact
                            break
                        end
                    end
                end
            end
            if not foundContact then
                for k,v in pairs(unknownSurfaceShipContacts) do
                    local contact = ScenEdit_GetContact({side=side.name, guid=v})
                    if contact then
                        local currentRange = Tool_Range(missionUnit.guid,contact.guid)
                        if currentRange < 20 then
                            foundRange = Tool_Range(missionUnit.guid,contact.guid)
                            foundContact = contact
                            break
                        end
                    end
                end
            end
            if not foundContact then
                for k,v in pairs(hostileSubmarineContacts) do
                    local contact = ScenEdit_GetContact({side=side.name, guid=v})
                    if contact then
                        local currentRange = Tool_Range(missionUnit.guid,contact.guid)
                        if currentRange < 20 then
                            foundRange = Tool_Range(missionUnit.guid,contact.guid)
                            foundContact = contact
                            break
                        end
                    end
                end
            end
            if not foundContact then
                for k,v in pairs(hostileSurfaceShipContacts) do
                    local contact = ScenEdit_GetContact({side=side.name, guid=v})
                    if contact then
                        local currentRange = Tool_Range(missionUnit.guid,contact.guid)
                        if currentRange < 20 then
                            foundRange = Tool_Range(missionUnit.guid,contact.guid)
                            foundContact = contact
                            break
                        end
                    end
                end
            end
            -- Update Speed If Necessary
            if foundContact then
                if foundRange > 15 then
                    foundSpeed = 4
                elseif foundRange > 10 then
                    foundSpeed = 3
                elseif foundRange > 5 then
                    foundSpeed = 2
                else
                    foundSpeed = 1
                end
            else
                if missionUnit.altitude < -250 then
                    foundSpeed = 20
                elseif missionUnit.altitude < -120 then
                    foundSpeed = 10
                else
                    foundSpeed = 5
                end
            end
            missionUnit.manualSpeed = foundSpeed
        end
    end
end

function getAirNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,range)
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local hostileAirContacts = getHostileAirContacts(shortSideKey)
    local unknownAirContacts = getUnknownAirContacts(shortSideKey)
    local desiredRange = range
    if not unit and not canUpdateEveryThirtySeconds() then
        return nil
    end
    for k,v in pairs(hostileAirContacts) do
        local contact = ScenEdit_GetContact({side=side.name, guid=v})
        if contact then
            local currentRange = Tool_Range(contact.guid,unitGuid)
            if currentRange < desiredRange then
                local bearing = Tool_Bearing(contact.guid,unitGuid)
                local retreatLocation = projectLatLong(makeLatLong(contact.latitude,contact.longitude),bearing,desiredRange + 20)
                return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=2000}
            end
        end
    end
    for k,v in pairs(unknownAirContacts) do
        local contact = ScenEdit_GetContact({side=side.name, guid=v})
        if contact then
            local currentRange = Tool_Range(contact.guid,unitGuid)
            if currentRange < desiredRange then
                local bearing = Tool_Bearing(contact.guid,unitGuid)
                local retreatLocation = projectLatLong(makeLatLong(contact.latitude,contact.longitude),bearing,desiredRange + 20)
                return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=2000}
            end
        end
    end
    return nil
end

function getSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    local side = VP_GetSide({guid=sideGuid})
    local hostileSAMContacts = getHostileSAMContacts(shortSideKey)
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    if not unit and not canUpdateEveryThirtySeconds() then
        return nil
    end
    for k,v in pairs(hostileSAMContacts) do
        local contact = ScenEdit_GetContact({side=side.name, guid=v})
        if contact then
            local currentRange = Tool_Range(contact.guid,unitGuid)
            local desiredRange = determineThreatRangeByUnitDatabaseId(shortSideKey,side.guid,contact.guid)
            if currentRange < desiredRange then
                local bearing = Tool_Bearing(contact.guid,unitGuid)
                local retreatLocation = projectLatLong(makeLatLong(contact.latitude,contact.longitude),bearing,desiredRange + 20)
                return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=2000}
            end
        end
    end
    return nil
end

function getShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local hostileSurfaceShipContacts = getHostileSurfaceShipContacts(shortSideKey)
    if not unit and not canUpdateEveryThirtySeconds() then
        return nil
    end
    for k,v in pairs(hostileSurfaceShipContacts) do
        local contact = ScenEdit_GetContact({side=side.name, guid=v})
        if contact then
            local currentRange = Tool_Range(contact.guid,unitGuid)
            local desiredRange = determineThreatRangeByUnitDatabaseId(shortSideKey,side.guid,contact.guid)
            if currentRange < desiredRange then
                local bearing = Tool_Bearing(contact.guid,unitGuid)
                local retreatLocation = projectLatLong(makeLatLong(contact.latitude,contact.longitude),bearing,desiredRange + 20)
                return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=2000}
            end
        end
    end
    return nil
end

function getSubmarineNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,range)
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local hostileSubmarineContacts = getHostileSubmarineContacts(shortSideKey)
    local unknownSubmarineContacts = getUnknownSubmarineContacts(shortSideKey)
    if not unit and not canUpdateEveryFiveMinutes() then
        return nil
    end
    for k,v in pairs(hostileSubmarineContacts) do
        local contact = ScenEdit_GetContact({side=side.name, guid=v})
        if contact then
            local currentRange = Tool_Range(contact.guid,unitGuid)
            local desiredRange = range
            if currentRange < desiredRange then
                local bearing = Tool_Bearing(contact.guid,unitGuid)
                local retreatLocation = projectLatLong(makeLatLong(contact.latitude,contact.longitude),bearing,desiredRange + 12)
                return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=unit.speed}
            end
        end
    end
    for k,v in pairs(unknownSubmarineContacts) do
        local contact = ScenEdit_GetContact({side=side.name, guid=v})
        if contact then
            local currentRange = Tool_Range(contact.guid,unitGuid)
            local desiredRange = range
            if currentRange < desiredRange then
                local bearing = Tool_Bearing(contact.guid,unitGuid)
                local retreatLocation = projectLatLong(makeLatLong(contact.latitude,contact.longitude),bearing,desiredRange + 20)
                return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=unit.speed}
            end
        end
    end
    return nil
end

function getEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local hostileMissilesContacts = getHostileWeaponContacts(shortSideKey)
    if not unit and not canUpdateEveryTenSeconds() then
        return nil
    end
    --ScenEdit_SpecialMessage("Blue Force",deepPrint(unit.targetedBy))
    for k,v in pairs(hostileMissilesContacts) do
        local currentRange = Tool_Range(v,unitGuid)
        local contact = ScenEdit_GetContact({side=side.name, guid=v})
        if contact then
            local minDesiredRange = 8
            local maxDesiredRange = 60
            if currentRange > minDesiredRange and currentRange < maxDesiredRange then
                local contactPoint = makeLatLong(contact.latitude,contact.longitude)
                local bearing = Tool_Bearing({latitude=contactPoint.latitude,longitude=contactPoint.longitude},unitGuid)
                local retreatLocation = projectLatLong(contactPoint,bearing,maxDesiredRange + 20)
                return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=2000}
            end
        end
    end
    return nil
end

function getSAMAndShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    local contactPoint = getEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    if contactPoint then
        return contactPoint
    else
        contactPoint = getSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
        if contactPoint then
            return contactPoint
        else
            return getShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
        end
    end
end

function getAirAndShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,airRange)
    local contactPoint = getEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    if contactPoint then
        return contactPoint
    else
        contactPoint = getAirNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,airRange)
        if contactPoint then
            return contactPoint
        else
            return getShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
        end
    end
end

function getAirAndSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,airRange)
    local contactPoint = getEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    if contactPoint then
        return contactPoint 
    else
        contactPoint = getAirNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,airRange)
        if contactPoint then
            return contactPoint
        else
            return getSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
        end
    end
end

function getAllNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,airRange)
    local contactPoint = getEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    if contactPoint then
        return contactPoint
    else
        contactPoint = getAirNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,airRange)
        if contactPoint then
            return contactPoint
        else
            contactPoint = getSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
            if contactPoint then
                return contactPoint
            else
                return getShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Update Area of Operation Function
--------------------------------------------------------------------------------------------------------------------------------
function observerActionUpdateAIAreaOfOperations(args)
    local side = VP_GetSide({guid=args.guid})
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local coordinates = {}
    local boundingBox = {}
    if #aoPoints < 4 or canUpdateEverySixtySeconds() then 
        local hostileContacts = getAllHostileContacts(args.shortKey)
        local inventory = getAllInventory(args.shortKey)
        for k,v in pairs(hostileContacts) do
            local contact = ScenEdit_GetContact({side=side.name, guid=v})
            if contact then
                coordinates[#coordinates + 1] = makeLatLong(contact.latitude,contact.longitude)
            end
        end
        for k,v in pairs(inventory) do
            local unit = ScenEdit_GetUnit({side=side.name, guid=v})
            if unit then
                coordinates[#coordinates + 1] = makeLatLong(unit.latitude,unit.longitude)
            end
        end
        boundingBox = findBoundingBoxForGivenLocations(coordinates,3)
        for i = 1,#boundingBox do
            local referencePoint = ScenEdit_SetReferencePoint({side=side.name,name="AI-AO-"..tostring(i),lat=boundingBox[i].latitude,lon=boundingBox[i].longitude})
            if referencePoint == nil then
                ScenEdit_AddReferencePoint({side=side.name,name="AI-AO-"..tostring(i),lat=boundingBox[i].latitude,lon=boundingBox[i].longitude})
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Observer Functions
--------------------------------------------------------------------------------------------------------------------------------
function observerActionUpdateAIVariables(args)
    local sideShortKey = args.shortKey
    local hostileWeaponContacts = getHostileWeaponContacts(args.shortKey)
    if canUpdateEveryThirtySeconds() then
        -- Update Emcon Change State
        local emconChangeState = ScenEdit_GetKeyValue(sideShortKey.."_emcon_chg_state")
        if emconChangeState == "Active" then
            emconChangeState = "Passive"
        else 
            emconChangeState = "Active"
        end
        ScenEdit_SetKeyValue(sideShortKey.."_emcon_chg_state",emconChangeState)

        -- Update Threat Decay
        local threatRangeDecay = ScenEdit_GetKeyValue(sideShortKey.."_threat_range_decay")
        if threatRangeDecay == "" or #hostileWeaponContacts > 0 then
            threatRangeDecay = "1"
        else
            if threatRangeDecay == "0.04" then
                threatRangeDecay = "0.05"
            else
                threatRangeDecay = tostring(tonumber(threatRangeDecay) - 0.01)
            end
        end
        ScenEdit_SetKeyValue(sideShortKey.."_threat_range_decay",threatRangeDecay)
    end
end

function observerActionUpdateAirInventories(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    -- Check Inventory
    if canUpdateEverySixtySeconds() then
        local aircraftInventory = side:unitsBy("1")
        if aircraftInventory then
            local savedInventory = {}
            localMemoryInventoryRemoveFromKey(sideShortKey.."_saved_air_inventory")
            for k, v in pairs(aircraftInventory) do
                -- Local Values
                local unit = ScenEdit_GetUnit({side=side.name, guid=v.guid})
                local unitType = "atk"
                local unitStatus = "unav"
                -- Get Status
                if unit.mission == nil and unit.loadoutdbid ~= nil and unit.loadoutdbid ~= 3 and unit.loadoutdbid ~= 4 and tostring(unit.readytime) == "0" then
                    unitStatus = "free"
                elseif unit.mission ~= nil and unit.loadoutdbid ~= nil and unit.loadoutdbid ~= 3 and unit.loadoutdbid ~= 4 then
                    unitStatus = "busy"
                end
                -- Fighter
                if unit.subtype == "2001" then
                    unitType = determineRoleFromLoadOutDatabase(unit.loadoutdbid,"fig")
                -- Multirole
                elseif unit.subtype == "2002" then
                    unitType = determineRoleFromLoadOutDatabase(unit.loadoutdbid,"mul")
                -- Attacker
                elseif unit.subtype == "3001" then
                    unitType = determineRoleFromLoadOutDatabase(unit.loadoutdbid,"atk")
                -- SEAD
                elseif unit.subtype == "4001" then
                    unitType = determineRoleFromLoadOutDatabase(unit.loadoutdbid,"sead")
                -- AEW
                elseif unit.subtype == "4002" then
                    unitType = determineRoleFromLoadOutDatabase(unit.loadoutdbid,"aew")
                -- ASW
                elseif unit.subtype == "6001" or unit.subtype == "6002" then
                    unitType = determineRoleFromLoadOutDatabase(unit.loadoutdbid,"asw")
                -- Recon
                elseif unit.subtype == "7003" then
                    unitType = determineRoleFromLoadOutDatabase(unit.loadoutdbid,"rec")
                -- Tanker
                elseif unit.subtype == "8001" then
                    unitType = determineRoleFromLoadOutDatabase(unit.loadoutdbid,"tan")
                -- UAV
                elseif unit.subtype == "8201" then
                    unitType = determineRoleFromLoadOutDatabase(unit.loadoutdbid,"uav")
                -- UCAV
                elseif unit.subtype == "8002" then
                    unitType = determineRoleFromLoadOutDatabase(unit.loadoutdbid,"ucav")
                end
                -- Add To Memory
                local stringKey = sideShortKey.."_"..unitType.."_"..unitStatus
                local stringArray = savedInventory[stringKey]
                if not stringArray then
                    stringArray = {}
                end
                stringArray[#stringArray + 1] = unit.guid
                savedInventory[stringKey] = stringArray
                -- Print
                --ScenEdit_SpecialMessage("Blue Force",unit.name.." "..unit.subtype)
            end
            -- Save Memory Inventory And Time Stamp
            localMemoryInventoryAddToKey(sideShortKey.."_saved_air_inventory",savedInventory)
        end
    end
end

function observerActionUpdateSurfaceInventories(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    -- Check Time
    if canUpdateEverySixtySeconds() then
        local shipInventory = side:unitsBy("2")
        if shipInventory then
            local savedInventory = {}
            localMemoryInventoryRemoveFromKey(sideShortKey.."_saved_ship_inventory")
            for k, v in pairs(shipInventory) do
                -- Local Values
                local unit = ScenEdit_GetUnit({side=side.name, guid=v.guid})
                local unitType = "surf"
                local unitStatus = "busy"
                -- Check Status
                if unit.mission == nil then
                    unitStatus = "free"
                end 
                -- Add To Memory
                local stringKey = sideShortKey.."_"..unitType.."_"..unitStatus
                local stringArray = savedInventory[stringKey]
                if not stringArray then
                    stringArray = {}
                end
                stringArray[#stringArray + 1] = unit.guid
                savedInventory[stringKey] = stringArray
            end
            -- Save Memory Inventory And Time Stamp
            localMemoryInventoryAddToKey(sideShortKey.."_saved_ship_inventory",savedInventory)
        end
    end
end

function observerActionUpdateSubmarineInventories(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    -- Check Time
    if canUpdateEverySixtySeconds() then
        local submarineInventory = side:unitsBy("3")
        if submarineInventory then
            local savedInventory = {}
            localMemoryInventoryRemoveFromKey(sideShortKey.."_saved_sub_inventory")
            for k, v in pairs(submarineInventory) do
                -- Local Values
                local unit = ScenEdit_GetUnit({side=side.name, guid=v.guid})
                local unitType = "sub"
                local unitStatus = "busy"
                -- Check Status
                if unit.mission == nil then
                    unitStatus = "free"
                end
                -- Add To Memory
                local stringKey = sideShortKey.."_"..unitType.."_"..unitStatus
                local stringArray = savedInventory[stringKey]
                if not stringArray then
                    stringArray = {}
                end
                stringArray[#stringArray + 1] = unit.guid
                savedInventory[stringKey] = stringArray
            end
            -- Save Memory Inventory And Time Stamp
            localMemoryInventoryAddToKey(sideShortKey.."_saved_sub_inventory",savedInventory)
        end
    end
end

function observerActionUpdateLandInventories(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    -- Check Time
    if canUpdateEveryFiveMinutes() then
        local landInventory = side:unitsBy("4")
        -- Loop Through
        if landInventory then
            local savedInventory = {}
            localMemoryInventoryRemoveFromKey(sideShortKey.."_saved_land_inventory")
            -- Loop
            for k, v in pairs(landInventory) do
                -- Local Values
                local unit = ScenEdit_GetUnit({side=side.name, guid=v.guid})
                local unitType = "land"
                local unitStatus = "busy"
                -- Check Status
                if unit.mission == nil then
                    unitStatus = "free"
                end
                -- Save Unit As HVA (Airport)
                if unit.subtype == "9001" then
                    unitType = "base"
                elseif unit.subtype == "5001" then
                    unitType = "sam"
                end
                -- Add To Memory
                local stringKey = sideShortKey.."_"..unitType.."_"..unitStatus
                local stringArray = savedInventory[stringKey]
                if not stringArray then
                    stringArray = {}
                end
                stringArray[#stringArray + 1] = unit.guid
                savedInventory[stringKey] = stringArray
            end
            -- Save Memory Inventory And Time Stamp
            localMemoryInventoryAddToKey(sideShortKey.."_saved_land_inventory",savedInventory)
        end
    end
end

function observerActionUpdateHVAInventories(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    local shipInventory = side:unitsBy("2")
    local landInventory = side:unitsBy("4")
    -- Check Time
    if canUpdateEveryFiveMinutes() then
        -- Remove
        localMemoryRemoveFromKey(sideShortKey.."_def_hva")
        -- Check Ship Inventory
        if shipInventory then
            local savedInventory = {}
            for k, v in pairs(shipInventory) do
                -- Local Values
                local unit = ScenEdit_GetUnit({side=side.name, guid=v.guid})
                -- Save Unit As HVT (Carriers)
                if unit.subtype == "2001" or unit.subtype == "2008" then
                    localMemoryAddToKey(sideShortKey.."_def_hva",unit.guid)
                end
            end
        end
        if landInventory then
            local savedInventory = {}
            local savedDefHVT = {}
            for k, v in pairs(landInventory) do
                -- Local Values
                local unit = ScenEdit_GetUnit({side=side.name, guid=v.guid})
                -- Determine And Add HVA
                if determineHVAByUnitDatabaseId(sideShortKey,unit.guid,unit.dbid) then
                    local leadGuid = unit.guid
                    if unit.group then
                        leadGuid = unit.group.lead
                    end
                    if not savedDefHVT[leadGuid] then
                        localMemoryAddToKey(sideShortKey.."_def_hva",unit.guid)
                        savedDefHVT[leadGuid] = leadGuid
                    end
                end
            end
        end
    end
end

function observerActionUpdateAirContacts(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    -- Check Time
    if canUpdateEverySixtySeconds() then
        local aircraftContacts = side:contactsBy("1")
        localMemoryContactRemoveFromKey(sideShortKey.."_saved_air_contact")
        if aircraftContacts then
            local savedContacts = {}
            for k, v in pairs(aircraftContacts) do
                -- Local Values
                local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
                local unitType = "air_con"
                -- Add To Memory
                local stringKey = sideShortKey.."_"..unitType.."_"..contact.posture
                local stringArray = savedContacts[stringKey]
                if not stringArray then
                    stringArray = {}
                end
                stringArray[#stringArray + 1] = contact.guid
                savedContacts[stringKey] = stringArray
            end
            localMemoryContactAddToKey(sideShortKey.."_saved_air_contact",savedContacts)
        end
    end
end

function observerActionUpdateSurfaceContacts(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    if canUpdateEverySixtySeconds() then
        local shipContacts = side:contactsBy("2")
        localMemoryContactRemoveFromKey(sideShortKey.."_saved_ship_contact")
        if shipContacts then
            local savedContacts = {}
            for k, v in pairs(shipContacts) do
                -- Local Values
                local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
                local unitType = "surf_con"
                -- Add To Memory
                local stringKey = sideShortKey.."_"..unitType.."_"..contact.posture
                local stringArray = savedContacts[stringKey]
                if not stringArray then
                    stringArray = {}
                end
                stringArray[#stringArray + 1] = contact.guid
                savedContacts[stringKey] = stringArray
            end
            localMemoryContactAddToKey(sideShortKey.."_saved_ship_contact",savedContacts)
        end
    end
end

function observerActionUpdateSubmarineContacts(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    if canUpdateEverySixtySeconds() then
        local submarineContacts = side:contactsBy("3")
        localMemoryContactRemoveFromKey(sideShortKey.."_saved_sub_contact")
        if submarineContacts then
            local savedContacts = {}
            for k, v in pairs(submarineContacts) do
                -- Local Values
                local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
                local unitType = "sub_con"
                -- Add To Memory
                local stringKey = sideShortKey.."_"..unitType.."_"..contact.posture
                local stringArray = savedContacts[stringKey]
                if not stringArray then
                    stringArray = {}
                end
                stringArray[#stringArray + 1] = contact.guid
                savedContacts[stringKey] = stringArray
            end
            localMemoryContactAddToKey(sideShortKey.."_saved_sub_contact",savedContacts)
        end
    end
end

function observerActionUpdateLandContacts(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    if canUpdateEveryFiveMinutes() then
        local landContacts = side:contactsBy("4")
        localMemoryContactRemoveFromKey(sideShortKey.."_saved_land_contact")
        if landContacts then
            local savedContacts = {}
            for k, v in pairs(landContacts) do
                -- Local Values
                local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
                local unitType = "land_con"
                -- Check
                if string.find(contact.type_description,"SAM") then
                    unitType = "sam_con"
                end
                -- Add To Memory
                local stringKey = sideShortKey.."_"..unitType.."_"..contact.posture
                local stringArray = savedContacts[stringKey]
                if not stringArray then
                    stringArray = {}
                end
                stringArray[#stringArray + 1] = contact.guid
                savedContacts[stringKey] = stringArray
            end
            localMemoryContactAddToKey(sideShortKey.."_saved_land_contact",savedContacts)
        end
    end
end

function observerActionUpdateWeaponContacts(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    if canUpdateEveryTenSeconds() then
        local weaponContacts = side:contactsBy("6")
        localMemoryContactRemoveFromKey(sideShortKey.."_saved_weap_contact")
        if weaponContacts then
            local savedContacts = {}
            for k, v in pairs(weaponContacts) do
                -- Local Values
                local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
                local unitType = "weap_con"
                -- Filter Out By Weapon Speed
                if contact.speed then
                    if  contact.speed > 2000 then
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
            localMemoryContactAddToKey(sideShortKey.."_saved_weap_contact",savedContacts)
        end
    end
end

function resetAllInventoriesAndContacts()
    localMemoryInventoryResetAll()
    localMemoryContactResetAll()
end

--------------------------------------------------------------------------------------------------------------------------------
-- Decider Functions
--------------------------------------------------------------------------------------------------------------------------------
function deciderOffensiveCheck(args)
    -- Local Values
    local hostileStrength = getAllHostileContactStrength(args.shortKey)
    local inventoryStrength = getAllInventoryStrength(args.shortKey)
    --local aggressiveModifier = args.options.aggressive * 2 / (args.options.aggressive + args.options.defensive)
    -- Check
    if hostileStrength <= 0 then
        return false
    elseif hostileStrength <= inventoryStrength then--* aggressiveModifier then
        return true
    else
        return false
    end
end

function deciderDefensiveCheck(args)
    -- Local Values
    local hostileStrength = getAllHostileContactStrength(args.shortKey)
    local inventoryStrength = getAllInventoryStrength(args.shortKey)
    --local aggressiveModifier = args.options.aggressive * 2 / (args.options.aggressive + args.options.defensive)
    -- Check
    if hostileStrength <= 0 then
        return true
    elseif hostileStrength > inventoryStrength then--* aggressiveModifier then
        return true
    else
        return false
    end
end

function deciderNeutralReconCreateUpdateMission(args)
    local side = VP_GetSide({guid=args.guid})
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local missions = persistentMemoryGetForKey(args.shortKey.."_rec_miss") 
    local rp1,rp2,rp3,rp4 = ""
    if #missions < 4 then
        local missionNumber = math.random(4)
        while persistentMemoryValueExists(args.shortKey.."_rec_miss",args.shortKey.."_rec_miss_"..tostring(missionNumber)) do
            missionNumber = math.random(4)
        end
        if missionNumber == 1 then
            rp1rp2mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[2].latitude,aoPoints[2].longitude)
            rp1rp3mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
            rp1rp4mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
            rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=aoPoints[1].latitude, lon=aoPoints[1].longitude})
            rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=rp1rp2mid.latitude, lon=rp1rp2mid.longitude})
            rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
            rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=rp1rp4mid.latitude, lon=rp1rp4mid.longitude})
        elseif missionNumber == 2 then
            rp1rp2mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[2].latitude,aoPoints[2].longitude)
            rp2rp3mid = midPointCoordinate(aoPoints[2].latitude,aoPoints[2].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
            rp1rp3mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
            rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=rp1rp2mid.latitude, lon=rp1rp2mid.longitude})
            rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=aoPoints[2].latitude, lon=aoPoints[2].longitude})
            rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=rp2rp3mid.latitude, lon=rp2rp3mid.longitude})
            rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
        elseif missionNumber == 3 then
            rp1rp3mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
            rp2rp3mid = midPointCoordinate(aoPoints[2].latitude,aoPoints[2].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
            rp3rp4mid = midPointCoordinate(aoPoints[3].latitude,aoPoints[3].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
            rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
            rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=rp2rp3mid.latitude, lon=rp2rp3mid.longitude})
            rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=aoPoints[3].latitude, lon=aoPoints[3].longitude})
            rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=rp3rp4mid.latitude, lon=rp3rp4mid.longitude})
        else
            rp1rp4mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
            rp1rp3mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
            rp3rp4mid = midPointCoordinate(aoPoints[3].latitude,aoPoints[3].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
            rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=rp1rp4mid.latitude, lon=rp1rp4mid.longitude})
            rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
            rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=rp3rp4mid.latitude, lon=rp3rp4mid.longitude})
            rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=aoPoints[4].latitude, lon=aoPoints[4].longitude})
        end
        local createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_rec_miss_"..tostring(missionNumber),"patrol",{type="naval",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
        ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true})
        ScenEdit_SetDoctrine({side=side.name,mission=createdMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb ="0",dive_on_threat="2"})
        persistentMemoryAddToKey(args.shortKey.."_rec_miss",createdMission.name)
    else
        local missionNumber = 0
        for k, v in pairs(missions) do
            local updatedMission = ScenEdit_GetMission(side.name,v)
            local defensiveBoundingBox = {}
            local rp1,rp2,rp3,rp4 = ""
            local totalReconUnitsToAssign = 1
            missionNumber = missionNumber + 1
            if missionNumber == 1 then
                rp1rp2mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[2].latitude,aoPoints[2].longitude)
                rp1rp3mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
                rp1rp4mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=aoPoints[1].latitude, lon=aoPoints[1].longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=rp1rp2mid.latitude, lon=rp1rp2mid.longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=rp1rp4mid.latitude, lon=rp1rp4mid.longitude})
            elseif missionNumber == 2 then
                rp1rp2mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[2].latitude,aoPoints[2].longitude)
                rp2rp3mid = midPointCoordinate(aoPoints[2].latitude,aoPoints[2].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
                rp1rp3mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=rp1rp2mid.latitude, lon=rp1rp2mid.longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=aoPoints[2].latitude, lon=aoPoints[2].longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=rp2rp3mid.latitude, lon=rp2rp3mid.longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
            elseif missionNumber == 3 then
                rp1rp3mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
                rp2rp3mid = midPointCoordinate(aoPoints[2].latitude,aoPoints[2].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
                rp3rp4mid = midPointCoordinate(aoPoints[3].latitude,aoPoints[3].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=rp2rp3mid.latitude, lon=rp2rp3mid.longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=aoPoints[3].latitude, lon=aoPoints[3].longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=rp3rp4mid.latitude, lon=rp3rp4mid.longitude})
            else
                rp1rp4mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
                rp1rp3mid = midPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
                rp3rp4mid = midPointCoordinate(aoPoints[3].latitude,aoPoints[3].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=rp1rp4mid.latitude, lon=rp1rp4mid.longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=rp3rp4mid.latitude, lon=rp3rp4mid.longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=aoPoints[4].latitude, lon=aoPoints[4].longitude})
            end
            addReinforcementRequest(args.shortKey,args.options,side.name,updatedMission.name,1)
        end
    end
end

function deciderOffensiveAirCreateUpdateMission(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_aaw_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalHostileContacts = getHostileAirContacts(args.shortKey)
    local totalHVAs = localMemoryGetFromKey(args.shortKey.."_def_hva")
    local totalAirUnitsToAssign = getHostileAirContactsStrength(args.shortKey) * 3
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactBoundingBox = {}
    local createdUpdatedMission = {}
    if #missions == 0 then
        hostileContactBoundingBox = findBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)
        rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_aaw_miss_"..tostring(missionNumber),"patrol",{type="aaw",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
        ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=true,flightSize=2,useFlightSize=true})
        ScenEdit_SetDoctrine({side=side.name,mission=createdUpdatedMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb ="1"})
        persistentMemoryAddToKey(args.shortKey.."_aaw_miss",createdUpdatedMission.name)
    else
        if #totalHostileContacts > 0 then
            hostileContactBoundingBox = findBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)
        else
            hostileContactBoundingBox = findBoundingBoxForGivenUnits(side.name,totalHVAs,aoPoints,2)
        end
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})    
        createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
        if totalAirUnitsToAssign % 2 == 1 then
            totalAirUnitsToAssign = totalAirUnitsToAssign + 1
        end
        addReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,totalAirUnitsToAssign)
    end
end

function deciderOffensiveStealthAirCreateUpdateMission(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_saaw_miss")
    local linkedMissions = persistentMemoryGetForKey(args.shortKey.."_aaw_miss")
    local totalAirUnitsToAssign = 0
    local missionNumber = 1
    local createdUpdatedMission = {}
    local linkedMission = {}
    local linkedMissionPoints = {}
    local linkedMissionUnits = {}
    if #linkedMissions > 0 then
        linkedMission = ScenEdit_GetMission(side.name,linkedMissions[1])
        linkedMissionPoints = {linkedMission.name.."_rp_1",linkedMission.name.."_rp_2",linkedMission.name.."_rp_3",linkedMission.name.."_rp_4"}
        if #missions == 0 then
            createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_saaw_miss_"..tostring(missionNumber),"patrol",{type="aaw",zone=linkedMissionPoints})
            ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=true,flightSize=2,useFlightSize=true})
            ScenEdit_SetDoctrine({side=side.name,mission=createdUpdatedMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb ="0"})
            persistentMemoryAddToKey(args.shortKey.."_saaw_miss",createdUpdatedMission.name)
        else
            createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
            linkedMissionUnits = getUnitsFromMission(side.name,linkedMission.guid)   
            totalAirUnitsToAssign = math.floor(#linkedMissionUnits/4)
            if totalAirUnitsToAssign % 2 == 1 then
                totalAirUnitsToAssign = totalAirUnitsToAssign + 1
            end
            addReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,totalAirUnitsToAssign)
        end
    end
end

function deciderOffensiveAEWCreateUpdateMission(args)
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_aaew_miss")
    local linkedMissions = persistentMemoryGetForKey(args.shortKey.."_aaw_miss")
    local totalHVAs = localMemoryGetFromKey(args.shortKey.."_def_hva")
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local createdUpdatedMission = {}
    local linkedMission = {}
    local linkedMissionPoints = {}
    local linkedMissionCenterPoint = {}
    local patrolBoundingBox = {}
    if #linkedMissions > 0 then
        linkedMission = ScenEdit_GetMission(side.name,linkedMissions[1])
        linkedMissionPoints = ScenEdit_GetReferencePoints({side=side.name, area={linkedMission.name.."_rp_1",linkedMission.name.."_rp_2",linkedMission.name.."_rp_3",linkedMission.name.."_rp_4"}})
        linkedMissionCenterPoint = midPointCoordinate(linkedMissionPoints[1].latitude,linkedMissionPoints[1].longitude,linkedMissionPoints[3].latitude,linkedMissionPoints[3].longitude)
        patrolBoundingBox = findBoundingBoxForGivenLocations({makeLatLong(linkedMissionCenterPoint.latitude,linkedMissionCenterPoint.longitude)},0.5)
        if #missions == 0 then
            rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_1", lat=patrolBoundingBox[1].latitude, lon=patrolBoundingBox[1].longitude})
            rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_2", lat=patrolBoundingBox[2].latitude, lon=patrolBoundingBox[2].longitude})
            rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_3", lat=patrolBoundingBox[3].latitude, lon=patrolBoundingBox[3].longitude})
            rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_4", lat=patrolBoundingBox[4].latitude, lon=patrolBoundingBox[4].longitude})
            createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_aaew_miss_"..tostring(missionNumber),"support",{zone={rp1.name,rp2.name,rp3.name,rp4.name}})
            ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Active")
            persistentMemoryAddToKey(args.shortKey.."_aaew_miss",createdUpdatedMission.name)
        else
            createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
            if #createdUpdatedMission.unitlist > 0 then
                local hostUnit = (ScenEdit_GetUnit({side=side.name, guid=createdUpdatedMission.unitlist[1]})).base
                if hostUnit then
                    linkedMissionCenterPoint = midPointCoordinate(hostUnit.latitude,hostUnit.longitude,linkedMissionCenterPoint.latitude,linkedMissionCenterPoint.longitude)
                    patrolBoundingBox = findBoundingBoxForGivenLocations({makeLatLong(linkedMissionCenterPoint.latitude,linkedMissionCenterPoint.longitude)},0.5)
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_1", lat=patrolBoundingBox[1].latitude, lon=patrolBoundingBox[1].longitude})
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_2", lat=patrolBoundingBox[2].latitude, lon=patrolBoundingBox[2].longitude})
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_3", lat=patrolBoundingBox[3].latitude, lon=patrolBoundingBox[3].longitude})
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_4", lat=patrolBoundingBox[4].latitude, lon=patrolBoundingBox[4].longitude})
                    addReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,1)
                else
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_1", lat=patrolBoundingBox[1].latitude, lon=patrolBoundingBox[1].longitude})
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_2", lat=patrolBoundingBox[2].latitude, lon=patrolBoundingBox[2].longitude})
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_3", lat=patrolBoundingBox[3].latitude, lon=patrolBoundingBox[3].longitude})
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_4", lat=patrolBoundingBox[4].latitude, lon=patrolBoundingBox[4].longitude})
                    addReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,1)
                end
            else
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_1", lat=patrolBoundingBox[1].latitude, lon=patrolBoundingBox[1].longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_2", lat=patrolBoundingBox[2].latitude, lon=patrolBoundingBox[2].longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_3", lat=patrolBoundingBox[3].latitude, lon=patrolBoundingBox[3].longitude})
                ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_4", lat=patrolBoundingBox[4].latitude, lon=patrolBoundingBox[4].longitude})
                addReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,1)
            end
        end
    end
end

function deciderOffensiveTankerCreateUpdateMission(args)
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_atan_miss")
    local linkedMissions = persistentMemoryGetForKey(args.shortKey.."_aaw_miss")
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local createdUpdatedMission = {}
    local linkedMission = {}
    local linkedMissionPoints = {}
    local linkedMissionCenterPoint = {}
    local patrolBoundingBox = {}
    local linkedMissionUnits = {}
    local totalAirUnitsToAssign = 0
    if #linkedMissions > 0 then
        linkedMission = ScenEdit_GetMission(side.name,linkedMissions[1])
        linkedMissionPoints = ScenEdit_GetReferencePoints({side=side.name, area={linkedMission.name.."_rp_1",linkedMission.name.."_rp_2",linkedMission.name.."_rp_3",linkedMission.name.."_rp_4"}})
        linkedMissionCenterPoint = midPointCoordinate(linkedMissionPoints[1].latitude,linkedMissionPoints[1].longitude,linkedMissionPoints[3].latitude,linkedMissionPoints[3].longitude)
        patrolBoundingBox = findBoundingBoxForGivenLocations({makeLatLong(linkedMissionCenterPoint.latitude,linkedMissionCenterPoint.longitude)},1.0)
        if #missions == 0 then
            rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_1", lat=patrolBoundingBox[1].latitude, lon=patrolBoundingBox[1].longitude})
            rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_2", lat=patrolBoundingBox[2].latitude, lon=patrolBoundingBox[2].longitude})
            rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_3", lat=patrolBoundingBox[3].latitude, lon=patrolBoundingBox[3].longitude})
            rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_4", lat=patrolBoundingBox[4].latitude, lon=patrolBoundingBox[4].longitude})
            createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_atan_miss_"..tostring(missionNumber),"support",{zone={rp1.name,rp2.name,rp3.name,rp4.name}})
            ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=true,flightSize=1,useFlightSize=true})
            ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Passive")
            persistentMemoryAddToKey(args.shortKey.."_atan_miss",createdUpdatedMission.name)
        else
            createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_1", lat=patrolBoundingBox[1].latitude, lon=patrolBoundingBox[1].longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_2", lat=patrolBoundingBox[2].latitude, lon=patrolBoundingBox[2].longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_3", lat=patrolBoundingBox[3].latitude, lon=patrolBoundingBox[3].longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_4", lat=patrolBoundingBox[4].latitude, lon=patrolBoundingBox[4].longitude})
            linkedMissionUnits = getUnitsFromMission(side.name,linkedMission.guid)   
            totalAirUnitsToAssign = math.floor(#linkedMissionUnits/4)
            addReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,totalAirUnitsToAssign)
        end
    end
end

function deciderOffensiveAntiSurfaceShipCreateUpdateMission(args)
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_asuw_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalHostileContacts = getHostileSurfaceShipContacts(args.shortKey)
    local totalAirUnitsToAssign = getHostileSurfaceShipContactsStrength(args.shortKey) * 4
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local createdUpdatedMission = {}
    local hostileContactBoundingBox = {}
    if #missions == 0 then
        hostileContactBoundingBox = findBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)
        rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_asuw_miss_"..tostring(missionNumber),"patrol",{type="naval",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
        ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=false,flightSize=2,useFlightSize=true})
        ScenEdit_SetDoctrine({side=side.name,mission=createdUpdatedMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb="1",fuel_state_rtb="2",dive_on_threat="2"})
        ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Active")
        persistentMemoryAddToKey(args.shortKey.."_asuw_miss",createdUpdatedMission.name)
    else
        hostileContactBoundingBox = findBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)
        createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        addReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,totalAirUnitsToAssign)
    end
end

function deciderOffensiveAntiSubmarineCreateUpdateMission(args)
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_asw_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalContacts = getAllSubmarineContacts(args.shortKey)
    local totalAirUnitsToAssign = getHostileSubmarineContactsStrength(args.shortKey) * 3
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local createdUpdatedMission = {}
    local hostileContactBoundingBox = {}
    if #missions == 0 then
        hostileContactBoundingBox = findBoundingBoxForGivenContacts(side.name,totalContacts,aoPoints,1)
        rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_asw_miss_"..tostring(missionNumber),"patrol",{type="asw",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
        ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=true,flightSize=1,useFlightSize=true})
        ScenEdit_SetDoctrine({side=side.name,mission=createdUpdatedMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb="1",fuel_state_rtb="2",dive_on_threat="2"})
        ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Active")
        persistentMemoryAddToKey(args.shortKey.."_asw_miss",createdUpdatedMission.name)
    else
        hostileContactBoundingBox = findBoundingBoxForGivenContacts(side.name,totalContacts,aoPoints,1)
        createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        addReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,totalAirUnitsToAssign)
    end
end

function deciderOffensiveSeadCreateUpdateMission(args)
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_sead_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalHostileContacts = getHostileSAMContacts(args.shortKey)
    local totalAirUnitsToAssign = getHostileSAMContactsStrength(args.shortKey) * 4
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local createdUpdatedMission = {}
    if #missions == 0 then
        local hostileContactBoundingBox = findBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)
        rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_sead_miss_"..tostring(missionNumber),"patrol",{type="sead",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
        ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=false,flightSize=2,useFlightSize=true})
        ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Passive")
        persistentMemoryAddToKey(args.shortKey.."_sead_miss",createdUpdatedMission.name)
    else
        local hostileContactBoundingBox = findBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)
        createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        addReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,totalAirUnitsToAssign)
    end
end

function deciderOffensiveLandAttackCreateUpdateMission(args)
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_land_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalHostileContacts = getHostileLandContacts(args.shortKey)
    local totalAirUnitsToAssign = getHostileLandContactsStrength(args.shortKey) * 2
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local createdUpdatedMission = {}
    if #missions == 0 then
        local hostileContactBoundingBox = findBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)
        rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_land_miss_"..tostring(missionNumber),"patrol",{type="land",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
        ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=false,flightSize=2,useFlightSize=true})
        ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Passive")
        persistentMemoryAddToKey(args.shortKey.."_land_miss",createdUpdatedMission.name)
    else
        local hostileContactBoundingBox = findBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)
        createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        addReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,totalAirUnitsToAssign)
    end
end

function deciderDefensiveAirCreateUpdateMission(args)
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_aaw_d_miss")
    local createdMission = {}
    local updatedMission = {}
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local defenseBoundingBox = {}
    local prosecutionBoundingBox = {}
    local rp1,rp2,rp3,rp4 = ""
    local prp1,prp2,prp3,prp4 = ""
    local totalHostileContacts = getHostileAirContacts(args.shortKey)
    local totalUnknownContacts = getUnknownAirContacts(args.shortKey)
    local totalHVAs = localMemoryGetFromKey(args.shortKey.."_def_hva")
    local coveredHVAs = persistentMemoryGetForKey(args.shortKey.."_def_hva_cov")
    local unitToDefend = nil
    local totalAAWUnitsToAssign = 2
    if #coveredHVAs < #totalHVAs then
        -- Find Unit That Is Not Covered
        for k, v in pairs(totalHVAs) do
            local found = false
            for k2, v2 in pairs(coveredHVAs) do 
                if v == v2 then
                    found = true
                end
            end
            if not found then
                unitToDefend = ScenEdit_GetUnit({side=side.name, guid=v})
                break
            end
        end
        -- Check If No Unit To Defend
        if unitToDefend then
            -- Set Contact Bounding Box Variables
            defenseBoundingBox = findBoundingBoxForGivenLocations({makeLatLong(unitToDefend.latitude,unitToDefend.longitude)},1.5)
            prosecutionBoundingBox = findBoundingBoxForGivenLocations({makeLatLong(unitToDefend.latitude,unitToDefend.longitude)},2.5)
            -- Set Reference Points
            rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_rp_1", lat=defenseBoundingBox[1].latitude, lon=defenseBoundingBox[1].longitude})
            rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_rp_2", lat=defenseBoundingBox[2].latitude, lon=defenseBoundingBox[2].longitude})
            rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_rp_3", lat=defenseBoundingBox[3].latitude, lon=defenseBoundingBox[3].longitude})
            rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_rp_4", lat=defenseBoundingBox[4].latitude, lon=defenseBoundingBox[4].longitude})
            -- Set Prosecution Points
            prp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_prp_1", lat=prosecutionBoundingBox[1].latitude, lon=prosecutionBoundingBox[1].longitude})
            prp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_prp_2", lat=prosecutionBoundingBox[2].latitude, lon=prosecutionBoundingBox[2].longitude})
            prp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_prp_3", lat=prosecutionBoundingBox[3].latitude, lon=prosecutionBoundingBox[3].longitude})
            prp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_prp_4", lat=prosecutionBoundingBox[4].latitude, lon=prosecutionBoundingBox[4].longitude})
            -- Create Mission
            createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_aaw_d_miss_"..unitToDefend.guid,"patrol",{type="aaw",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
            ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=true,flightSize=2,useFlightSize=true})
            ScenEdit_SetDoctrine({side=side.name,mission=createdMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb ="1"})
            ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Passive")
            -- Add Guid And Add Time Stamp
            persistentMemoryAddToKey(args.shortKey.."_aaw_d_miss",createdMission.name)
            persistentMemoryAddToKey(args.shortKey.."_def_hva_cov",unitToDefend.guid)
        end
    end
    -- Update Mission
    for k, v in pairs(coveredHVAs) do
        -- Local Covered HVA
        local coveredHVA = ScenEdit_GetUnit({side=side.name,guid=v})
        -- Check Condition
        if coveredHVA then
            -- Get Defense Mission
            updatedMission = ScenEdit_GetMission(side.name,args.shortKey.."_aaw_d_miss_"..coveredHVA.guid)
            -- Check Defense Mission
            if updatedMission then
                -- Set Contact Bounding Box Variables
                defenseBoundingBox = findBoundingBoxForGivenLocations({makeLatLong(coveredHVA.latitude,coveredHVA.longitude)},1.5)
                prosecutionBoundingBox = findBoundingBoxForGivenLocations({makeLatLong(coveredHVA.latitude,coveredHVA.longitude)},2.5)
                -- Update Coordinates
                rp1 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_rp_1", lat=defenseBoundingBox[1].latitude, lon=defenseBoundingBox[1].longitude})
                rp2 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_rp_2", lat=defenseBoundingBox[2].latitude, lon=defenseBoundingBox[2].longitude})
                rp3 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_rp_3", lat=defenseBoundingBox[3].latitude, lon=defenseBoundingBox[3].longitude})
                rp4 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_rp_4", lat=defenseBoundingBox[4].latitude, lon=defenseBoundingBox[4].longitude})
                -- Update Coordinates
                prp1 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_prp_1", lat=prosecutionBoundingBox[1].latitude, lon=prosecutionBoundingBox[1].longitude})
                prp2 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_prp_2", lat=prosecutionBoundingBox[2].latitude, lon=prosecutionBoundingBox[2].longitude})
                prp3 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_prp_3", lat=prosecutionBoundingBox[3].latitude, lon=prosecutionBoundingBox[3].longitude})
                prp4 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_prp_4", lat=prosecutionBoundingBox[4].latitude, lon=prosecutionBoundingBox[4].longitude})
                -- Find Enemy Strength In Area
                local contactsInZone = 0
                for k1, v1 in pairs(totalHostileContacts) do
                    local contact = ScenEdit_GetContact({side=side.name, guid=v1})
                    if contact then
                        if contact:inArea({prp1.name,prp2.name,prp3.name,prp4.name}) then
                            contactsInZone = contactsInZone + 1
                        end
                    end
                end
                for k1, v1 in pairs(totalUnknownContacts) do
                    local contact = ScenEdit_GetContact({side=side.name, guid=v1})
                    if contact then
                        if contact:inArea({prp1.name,prp2.name,prp3.name,prp4.name}) then
                            contactsInZone = contactsInZone + 1
                        end
                    end
                end
                -- Check
                if contactsInZone > 0 then
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_rp_1", lat=prosecutionBoundingBox[1].latitude, lon=prosecutionBoundingBox[1].longitude})
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_rp_2", lat=prosecutionBoundingBox[2].latitude, lon=prosecutionBoundingBox[2].longitude})
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_rp_3", lat=prosecutionBoundingBox[3].latitude, lon=prosecutionBoundingBox[3].longitude})
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_rp_4", lat=prosecutionBoundingBox[4].latitude, lon=prosecutionBoundingBox[4].longitude})
                else
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_rp_1", lat=defenseBoundingBox[1].latitude, lon=defenseBoundingBox[1].longitude})
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_rp_2", lat=defenseBoundingBox[2].latitude, lon=defenseBoundingBox[2].longitude})
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_rp_3", lat=defenseBoundingBox[3].latitude, lon=defenseBoundingBox[3].longitude})
                    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVA.guid.."_rp_4", lat=defenseBoundingBox[4].latitude, lon=defenseBoundingBox[4].longitude})
                end
                -- Add Reinforcement Request
                addReinforcementRequest(args.shortKey,args.options,side.name,updatedMission.name,totalAAWUnitsToAssign + contactsInZone)
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Defensive Tanker Doctrine Create Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function deciderDefensiveTankerCreateUpdateMission(args)
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_tan_d_miss")
    local createdMission = nil
    local updatedMission = nil
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local rp1,rp2,rp3,rp4 = nil
    local supportBoundingBox = {}
    local totalHVAs = localMemoryGetFromKey(args.shortKey.."_def_hva")
    local coveredHVAs = persistentMemoryGetForKey(args.shortKey.."_def_tan_hva_cov")
    local unitToSupport = nil
    if #coveredHVAs < #totalHVAs then
        for k, v in pairs(totalHVAs) do
            local found = false
            for k2, v2 in pairs(coveredHVAs) do 
                if v == v2 then
                    found = true
                end
            end
            if not found then
                unitToSupport = ScenEdit_GetUnit({side=side.name, guid=v})
                break
            end
        end
        if unitToSupport then
            defenseBoundingBox = findBoundingBoxForGivenLocations({makeLatLong(unitToSupport.latitude,unitToSupport.longitude)},0.5)
            rp1 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_tan_d_miss_"..unitToSupport.guid.."_rp_1",lat=defenseBoundingBox[1].latitude,lon=defenseBoundingBox[1].longitude,relativeto=unitToSupport.guid})
            rp2 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_tan_d_miss_"..unitToSupport.guid.."_rp_2",lat=defenseBoundingBox[2].latitude,lon=defenseBoundingBox[2].longitude,relativeto=unitToSupport.guid})
            rp3 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_tan_d_miss_"..unitToSupport.guid.."_rp_3",lat=defenseBoundingBox[3].latitude,lon=defenseBoundingBox[3].longitude,relativeto=unitToSupport.guid})
            rp4 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_tan_d_miss_"..unitToSupport.guid.."_rp_4",lat=defenseBoundingBox[4].latitude,lon=defenseBoundingBox[4].longitude,relativeto=unitToSupport.guid})
            createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_tan_d_miss_"..unitToSupport.guid,"support",{zone={rp1.name,rp2.name,rp3.name,rp4.name}})
            ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Passive")
            persistentMemoryAddToKey(args.shortKey.."_tan_d_miss",createdMission.name)
            persistentMemoryAddToKey(args.shortKey.."_def_tan_hva_cov",unitToSupport.guid)
        end
    end
    for k, v in pairs(coveredHVAs) do
        local coveredHVA = ScenEdit_GetUnit({side=side.name,guid=v})
        if coveredHVA then
            updatedMission = ScenEdit_GetMission(side.name,args.shortKey.."_tan_d_miss_"..coveredHVA.guid)
            if updatedMission then
                addReinforcementRequest(args.shortKey,args.options,side.name,updatedMission.name,1)
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Defensive Anti Submarine Doctrine Create Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function deciderDefensiveAntiSubmarineCreateUpdateMission(args)
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_asw_d_miss")
    local createdMission = {}
    local updatedMission = {}
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local defenseBoundingBox = {}
    local prosecutionBoundingBox = {}
    local rp1,rp2,rp3,rp4 = ""
    local prp1,prp2,prp3,prp4 = ""
    local totalContacts = getAllSubmarineContacts(args.shortKey)
    local totalHVAs = localMemoryGetFromKey(args.shortKey.."_def_hva")
    local coveredHVAs = persistentMemoryGetForKey(args.shortKey.."_def_asw_hva_cov")
    local unitToSupport = nil
    local totalUnitsToAssign = 2
    if #coveredHVAs < #totalHVAs then
        for k, v in pairs(totalHVAs) do
            local found = false
            for k2, v2 in pairs(coveredHVAs) do 
                if v == v2 then
                    found = true
                end
            end
            if not found then
                unitToSupport = ScenEdit_GetUnit({side=side.name, guid=v})
                break
            end
        end
        if unitToSupport then
            defenseBoundingBox = findBoundingBoxForGivenLocations({makeLatLong(unitToSupport.latitude,unitToSupport.longitude)},0.5)
            rp1 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_asw_d_miss_"..unitToSupport.guid.."_rp_1",lat=defenseBoundingBox[1].latitude,lon=defenseBoundingBox[1].longitude,relativeto=unitToSupport.guid})
            rp2 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_asw_d_miss_"..unitToSupport.guid.."_rp_2",lat=defenseBoundingBox[2].latitude,lon=defenseBoundingBox[2].longitude,relativeto=unitToSupport.guid})
            rp3 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_asw_d_miss_"..unitToSupport.guid.."_rp_3",lat=defenseBoundingBox[3].latitude,lon=defenseBoundingBox[3].longitude,relativeto=unitToSupport.guid})
            rp4 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_asw_d_miss_"..unitToSupport.guid.."_rp_4",lat=defenseBoundingBox[4].latitude,lon=defenseBoundingBox[4].longitude,relativeto=unitToSupport.guid})
            createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_asw_d_miss_"..unitToSupport.guid,"patrol",{type="asw",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
            ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=true,flightSize=1,useFlightSize=true})
            ScenEdit_SetDoctrine({side=side.name,mission=createdMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb ="1"})
            ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Passive")
            persistentMemoryAddToKey(args.shortKey.."_asw_d_miss",createdMission.name)
            persistentMemoryAddToKey(args.shortKey.."_def_asw_hva_cov",unitToSupport.guid)
        end
    end
    for k, v in pairs(coveredHVAs) do
        local coveredHVA = ScenEdit_GetUnit({side=side.name,guid=v})
        if coveredHVA then
            updatedMission = ScenEdit_GetMission(side.name,args.shortKey.."_asw_d_miss_"..coveredHVA.guid)
            if updatedMission then
                addReinforcementRequest(args.shortKey,args.options,side.name,updatedMission.name,2)
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Defend AEW Doctrine Create Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function deciderDefensiveAEWCreateUpdateMission(args)
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_aew_d_miss")
    local createdMission = nil
    local updatedMission = nil
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local rp1,rp2,rp3,rp4 = nil
    local supportBoundingBox = {}
    local totalHVAs = localMemoryGetFromKey(args.shortKey.."_def_hva")
    local coveredHVAs = persistentMemoryGetForKey(args.shortKey.."_def_aew_hva_cov")
    local unitToSupport = nil
    if #coveredHVAs < #totalHVAs then
        for k, v in pairs(totalHVAs) do
            local found = false
            for k2, v2 in pairs(coveredHVAs) do 
                if v == v2 then
                    found = true
                end
            end
            if not found then
                unitToSupport = ScenEdit_GetUnit({side=side.name, guid=v})
                break
            end
        end
        if unitToSupport then
            defenseBoundingBox = findBoundingBoxForGivenLocations({makeLatLong(unitToSupport.latitude,unitToSupport.longitude)},0.5)
            rp1 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_aew_d_miss_"..unitToSupport.guid.."_rp_1",lat=defenseBoundingBox[1].latitude,lon=defenseBoundingBox[1].longitude,relativeto=unitToSupport.guid})
            rp2 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_aew_d_miss_"..unitToSupport.guid.."_rp_2",lat=defenseBoundingBox[2].latitude,lon=defenseBoundingBox[2].longitude,relativeto=unitToSupport.guid})
            rp3 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_aew_d_miss_"..unitToSupport.guid.."_rp_3",lat=defenseBoundingBox[3].latitude,lon=defenseBoundingBox[3].longitude,relativeto=unitToSupport.guid})
            rp4 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_aew_d_miss_"..unitToSupport.guid.."_rp_4",lat=defenseBoundingBox[4].latitude,lon=defenseBoundingBox[4].longitude,relativeto=unitToSupport.guid})
            createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_aew_d_miss_"..unitToSupport.guid,"support",{zone={rp1.name,rp2.name,rp3.name,rp4.name}})
            ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Active")
            persistentMemoryAddToKey(args.shortKey.."_aew_d_miss",createdMission.name)
            persistentMemoryAddToKey(args.shortKey.."_def_aew_hva_cov",unitToSupport.guid)
        end
    else
        for k, v in pairs(coveredHVAs) do
            local coveredHVA = ScenEdit_GetUnit({side=side.name,guid=v})
            if coveredHVA then
                updatedMission = ScenEdit_GetMission(side.name,args.shortKey.."_aew_d_miss_"..coveredHVA.guid)
                if updatedMission then
                    addReinforcementRequest(args.shortKey,args.options,side.name,updatedMission.name,1)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Decider Ship Doctrine Create Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function deciderNeutralShipCreateUpdateMission(args)
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_ship_sc_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactBoundingBox = {}
    local createdUpdatedMission = {}
    local allocatedUnits = {}
    if #missions == 0 then
        local freeShipInventory = getFreeSurfaceShipInventory(args.shortKey)
        for k,v in pairs(freeShipInventory) do
            local unit = ScenEdit_GetUnit({side=side.name, guid=v})
            local assignedGuid = v
            local boundingBox = {}
            if unit then
                if unit.group then
                    assignedGuid = unit.group.guid
                end
                if not allocatedUnits[assignedGuid] then
                    allocatedUnits[assignedGuid] = assignedGuid
                    boundingBox = findBoundingBoxForGivenLocations({makeLatLong(unit.latitude,unit.longitude)},1)
                    rp1 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_ship_sc_miss_"..tostring(missionNumber).."_rp_1",lat=boundingBox[1].latitude,lon=boundingBox[1].longitude,relativeto=unit.guid})
                    rp2 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_ship_sc_miss_"..tostring(missionNumber).."_rp_2",lat=boundingBox[2].latitude,lon=boundingBox[2].longitude,relativeto=unit.guid})
                    rp3 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_ship_sc_miss_"..tostring(missionNumber).."_rp_3",lat=boundingBox[3].latitude,lon=boundingBox[3].longitude,relativeto=unit.guid})
                    rp4 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_ship_sc_miss_"..tostring(missionNumber).."_rp_4",lat=boundingBox[4].latitude,lon=boundingBox[4].longitude,relativeto=unit.guid})
                    createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_ship_sc_miss_"..tostring(missionNumber),"patrol",{type="mixed",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
                    ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true})
                    ScenEdit_AssignUnitToMission(assignedGuid,createdUpdatedMission.guid)
                    missionNumber = missionNumber + 1
                    persistentMemoryAddToKey(args.shortKey.."_ship_sc_miss",createdUpdatedMission.name)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Decider Submarine Doctrine Create Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function deciderNeutralSubmarineCreateUpdateMission(args)
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_sub_sc_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactBoundingBox = {}
    local createdUpdatedMission = {}
    local allocatedUnits = {}
    if #missions == 0 then
        local freeShipInventory = getFreeSubmarineInventory(args.shortKey)
        for k,v in pairs(freeShipInventory) do
            local unit = ScenEdit_GetUnit({side=side.name, guid=v})
            local assignedGuid = v
            local boundingBox = {}
            if unit then
                if unit.group then
                    assignedGuid = unit.group.guid
                end
                if not allocatedUnits[assignedGuid] then
                    allocatedUnits[assignedGuid] = assignedGuid
                    boundingBox = findBoundingBoxForGivenLocations({makeLatLong(unit.latitude,unit.longitude)},1)
                    rp1 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_sub_sc_miss_"..tostring(missionNumber).."_rp_1",lat=boundingBox[1].latitude,lon=boundingBox[1].longitude,relativeto=unit.guid})
                    rp2 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_sub_sc_miss_"..tostring(missionNumber).."_rp_2",lat=boundingBox[2].latitude,lon=boundingBox[2].longitude,relativeto=unit.guid})
                    rp3 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_sub_sc_miss_"..tostring(missionNumber).."_rp_3",lat=boundingBox[3].latitude,lon=boundingBox[3].longitude,relativeto=unit.guid})
                    rp4 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_sub_sc_miss_"..tostring(missionNumber).."_rp_4",lat=boundingBox[4].latitude,lon=boundingBox[4].longitude,relativeto=unit.guid})
                    createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_sub_sc_miss_"..tostring(missionNumber),"patrol",{type="mixed",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
                    ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true,transitDepthSubmarine="-200",stationDepthSubmarine="-50",attackDepthSubmarine="-50"})
                    ScenEdit_AssignUnitToMission(assignedGuid,createdUpdatedMission.guid)
                    missionNumber = missionNumber + 1
                    persistentMemoryAddToKey(args.shortKey.."_sub_sc_miss",createdUpdatedMission.name)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Decider SAM Doctrine Create Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function deciderNeutralSAMCreateUpdateMission(args)
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_sam_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactBoundingBox = {}
    local createdUpdatedMission = {}
    local allocatedUnits = {}
    if #missions == 0 then
        local freeSAMInventory = getFreeSAMInventory(args.shortKey)
        for k,v in pairs(freeSAMInventory) do
            local unit = ScenEdit_GetUnit({side=side.name, guid=v})
            local assignedGuid = v
            local boundingBox = {}
            if unit then
                if unit.group then
                    assignedGuid = unit.group.guid
                end
                if not allocatedUnits[assignedGuid] then
                    allocatedUnits[assignedGuid] = assignedGuid
                    boundingBox = findBoundingBoxForGivenLocations({makeLatLong(unit.latitude,unit.longitude)},0.1)
                    rp1 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_sam_miss_"..tostring(missionNumber).."_rp_1",lat=boundingBox[1].latitude,lon=boundingBox[1].longitude})
                    rp2 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_sam_miss_"..tostring(missionNumber).."_rp_2",lat=boundingBox[2].latitude,lon=boundingBox[2].longitude})
                    rp3 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_sam_miss_"..tostring(missionNumber).."_rp_3",lat=boundingBox[3].latitude,lon=boundingBox[3].longitude})
                    rp4 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_sam_miss_"..tostring(missionNumber).."_rp_4",lat=boundingBox[4].latitude,lon=boundingBox[4].longitude})
                    createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_sam_miss_"..tostring(missionNumber),"patrol",{type="aaw",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
                    ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true})
                    ScenEdit_AssignUnitToMission(assignedGuid,createdUpdatedMission.guid)
                    missionNumber = missionNumber + 1
                    persistentMemoryAddToKey(args.shortKey.."_sam_miss",createdUpdatedMission.name)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Actor Update Air Reinforcement Request
--------------------------------------------------------------------------------------------------------------------------------
function actorUpdateAirReinforcementRequest(args)
    local side = VP_GetSide({guid=args.guid})
    local reconMissions = persistentMemoryGetForKey(args.shortKey.."_rec_miss")
    local airMissions = persistentMemoryGetForKey(args.shortKey.."_aaw_miss")
    local stealthAirMissions = persistentMemoryGetForKey(args.shortKey.."_saaw_miss")
    local aewMissions = persistentMemoryGetForKey(args.shortKey.."_aaew_miss")
    local tankerMissions = persistentMemoryGetForKey(args.shortKey.."_atan_miss")
    local antiSurfaceMissions = persistentMemoryGetForKey(args.shortKey.."_asuw_miss")
    local antiSubmarineMissions = persistentMemoryGetForKey(args.shortKey.."_asw_miss")
    local seadMissions = persistentMemoryGetForKey(args.shortKey.."_sead_miss")
    local landMissions = persistentMemoryGetForKey(args.shortKey.."_land_miss")
    local airDefenseMissions = persistentMemoryGetForKey(args.shortKey.."_aaw_d_miss")
    local tankerDefenseMissions = persistentMemoryGetForKey(args.shortKey.."_tan_d_miss")
    local aewDefenseMissions = persistentMemoryGetForKey(args.shortKey.."_aew_d_miss")
    local aswDefenseMissions = persistentMemoryGetForKey(args.shortKey.."_asw_d_miss")
    local reinforcementRequests = getReinforcementRequests(args.shortKey)
    if not canUpdateEverySixtySeconds() then
        return
    end
    for k,v in pairs(reconMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        if reinforceNumber then
            determineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            if not missionReinforced then
                reinforceInventory = getFreeAirReconInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getFreeAirUAVInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getFreeAirStealthInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getFreeAirSeadInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirReconInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirUAVInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirStealthInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirSeadInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end
    for k,v in pairs(airMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        if reinforceNumber then
            determineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            if not missionReinforced then
                reinforceInventory = getFreeAirFighterInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getFreeAirMultiroleInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirFighterInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirMultiroleInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end
    for k,v in pairs(stealthAirMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        if reinforceNumber then
            determineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            if not missionReinforced then
                reinforceInventory = getFreeAirStealthInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirStealthInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end
    for k,v in pairs(aewMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        if reinforceNumber then
            determineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            if not missionReinforced then
                reinforceInventory = getFreeAirAEWInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirAEWInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end
    for k,v in pairs(tankerMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        if reinforceNumber then
            determineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            if not missionReinforced then
                reinforceInventory = getFreeAirTankerInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirTankerInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end
    for k,v in pairs(antiSurfaceMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        if reinforceNumber then
            determineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            if not missionReinforced then
                reinforceInventory = getFreeAirASuWInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getFreeAirMultiroleInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirASuWInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirMultiroleInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end
    for k,v in pairs(landMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        if reinforceNumber then
            determineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            if not missionReinforced then
                reinforceInventory = getFreeAirAttackInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getFreeAirMultiroleInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirAttackInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirMultiroleInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end
    for k,v in pairs(seadMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        if reinforceNumber then
            determineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            if not missionReinforced then
                reinforceInventory = getFreeAirSeadInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getFreeAirAttackInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getFreeAirMultiroleInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirSeadInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirAttackInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirMultiroleInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end
    for k,v in pairs(antiSubmarineMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        if reinforceNumber then
            determineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            if not missionReinforced then
                reinforceInventory = getFreeAirASWInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirASWInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end
    for k,v in pairs(airDefenseMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        if reinforceNumber then
            determineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            if not missionReinforced then
                reinforceInventory = getFreeAirFighterInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getFreeAirStealthInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getFreeAirMultiroleInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirFighterInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirStealthInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirMultiroleInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end
    for k,v in pairs(aewDefenseMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        if reinforceNumber then
            determineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            if not missionReinforced then
                reinforceInventory = getFreeAirAEWInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirAEWInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end
    for k,v in pairs(tankerDefenseMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        if reinforceNumber then
            determineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            if not missionReinforced then
                reinforceInventory = getFreeAirTankerInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirTankerInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end
    for k,v in pairs(aswDefenseMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        if reinforceNumber then
            determineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            if not missionReinforced then
                reinforceInventory = getFreeAirASWInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            if not missionReinforced then
                reinforceInventory = getBusyAirASWInventory(args.shortKey)
                missionReinforced = determineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end
    removeAllocatedUnit(args.shortKey)
    clearReinforcementRequests(args.shortKey)
end

--------------------------------------------------------------------------------------------------------------------------------
-- Actor - Control EMCON And Movement
--------------------------------------------------------------------------------------------------------------------------------
function actorUpdateUnitsInReconMission(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_rec_miss")
    -- Check Total Is Zero
    if #missions == 0 then
        return
    end
    -- Loop Through Existing Missions
    for k,v in pairs(missions) do
        -- Local Values
        local updatedMission = ScenEdit_GetMission(side.name,v)
        -- Find Area And Retreat Point
        local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
        -- Determine Retreat
        determineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,80)
        -- Determine EMCON
        determineEmconToAirUnits(args.shortKey,args.options,side.name,missionUnits)
    end
end

function actorUpdateUnitsInOffensiveAirMission(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_aaw_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then
        return
    end
    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Retreat Point
    local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
    -- Determine Retreat
    determineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,1,70)
    -- Determine EMCON
    determineEmconToAirUnits(args.shortKey,args.options,side.name,missionUnits)
end

function actorUpdateUnitsInOffensiveStealthAirMission(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_saaw_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then
        return
    end
    -- Get Linked Mission
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Retreat Point
    local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
    -- Determine Unit To Retreat
    determineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,60)
    -- Determine EMCON
    determineEmconToAirUnits(args.shortKey,args.options,side.name,missionUnits)
end

function actorUpdateUnitsInOffensiveSeadMission(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_sead_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then
        return
    end
    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Return Point
    local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
    -- Determine Retreat
    determineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,2,70)
end

function actorUpdateUnitsInOffensiveLandMission(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_land_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then--or (currentTime - lastTimeStamp) < 1 * 60 then
        return
    end
    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Return Point
    local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
    -- Determine Retreat
    determineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,70)
end

function actorUpdateUnitsInOffensiveAntiShipMission(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_asuw_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then
        return
    end
    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Return Point
    local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
    -- Determine Retreat
    determineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,3,70)
    -- Determine EMCON
    determineEmconToAirUnits(args.shortKey,args.options,side.name,missionUnits)
end

function actorUpdateUnitsInOffensiveAntiSubmarineMission(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_asw_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then
        return
    end
    -- Take Missions
    for k,v in pairs(missions) do
        updatedMission = ScenEdit_GetMission(side.name,v)
        if updatedMission then
            -- Find Area And Return Point
            local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
            -- Determine Retreat
            determineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,70)
            -- Determine EMCON
            determineEmconToAirUnits(args.shortKey,args.options,side.name,missionUnits)
        end
    end
end

function actorUpdateUnitsInOffensiveAEWMission(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_aaew_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then
        return
    end
    -- Get Linked Mission
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Retreat Point
    local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
    -- Determine Retreat
    determineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,200)
end

function actorUpdateUnitsInOffensiveTankerMission(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_atan_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then
        return
    end
    -- Get Linked Mission
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Retreat Point
    local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
    -- Determine Retreat
    determineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,200)
end

function actorUpdateUnitsInNeutralShipMission(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_ship_sc_miss")
    local updatedMission = {}
    -- Check
    if not canUpdateEveryFiveMinutes() then
        return
    end
    -- Condition Check
    if #missions == 0 then
        return
    end
    -- Loop Through Coverted HVAs Missions
    for k, v in pairs(missions) do
        -- Updated Mission
        updatedMission = ScenEdit_GetMission(side.name,v)
        -- Check Defense Mission
        if updatedMission then
            -- Find Contact Close To Unit And Retreat If Necessary
            local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
            -- Determine Retreat
            determineSurfaceUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,10)
        end
    end
end

function actorUpdateUnitsInNeutralSubmarineMission(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_sub_sc_miss")
    local updatedMission = {}
    -- Check
    if not canUpdateEveryFiveMinutes() then
        return
    end
    -- Condition Check
    if #missions == 0 then
        return
    end
    -- Loop Through Coverted HVAs Missions
    for k, v in pairs(missions) do
        -- Updated Mission
        updatedMission = ScenEdit_GetMission(side.name,v)
        -- Check Defense Mission
        if updatedMission then
            -- Find Contact Close To Unit And Retreat If Necessary
            local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
            -- Determine Retreat
            determineSubmarineUnitApproachSpeed(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits)
        end
    end
end

function actorUpdateUnitsInNeutralSAMMission(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local freeSAMInventory = getFreeSAMInventory(args.shortKey)
    --local missions = persistentMemoryGetForKey(args.shortKey.."_sam_miss")
    --local updatedMission = {}
    -- Check
    if not canUpdateEveryThirtySeconds() then
        return
    end
    -- Condition Check
    --if #missions == 0 then
    --    return
    --end
    -- SAM Inventory
    determineEmconForSAMUnits(args.shortKey,args.options,side.name,freeSAMInventory)
    -- Set Doctrine
    ScenEdit_SetDoctrine({side=side.name,guid=subUnit.guid},{ignore_plotted_course = "no" })
    --[[for k, v in pairs(missions) do
        -- Updated Mission
        updatedMission = ScenEdit_GetMission(side.name,v)
        -- Check Defense Mission
        if updatedMission then
            -- Find Contact Close To Unit And Retreat If Necessary
            local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
            -- Determine Retreat
            determineEmconForSAMUnits(args.shortKey,args.options,side.name,missionUnits)
        end
    end]]--
end

function actorUpdateUnitsInDefensiveAirMission(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_aaw_d_miss")
    local updatedMission = nil
    -- Condition Check
    if #missions == 0 then
        return
    end
    -- Loop Through Coverted HVAs Missions
    for k, v in pairs(missions) do
        -- Get Defense Mission
        updatedMission = ScenEdit_GetMission(side.name,v)
        -- Check Defense Mission
        if updatedMission then
            -- Find Area And Return Point
            local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
            -- Determine Retreat
            determineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,1,100)
            -- Determine EMCON
            determineEmconToAirUnits(args.shortKey,args.options,side.name,missionUnits)
        end
    end
end

function actorUpdateUnitsInDefensiveAEWMission(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_aew_d_miss")
    local updatedMission = nil
    -- Condition Check
    if #missions == 0 then
        return
    end
    -- Loop Through Coverted HVAs Missions
    for k, v in pairs(missions) do
        -- Update Mission
        updatedMission = ScenEdit_GetMission(side.name,v)
        -- Check Defense Mission
        if updatedMission then
            -- Determine Units To Assign
            local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
            -- Determine Retreat
            determineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,200)
        end
    end
end

function actorUpdateUnitsInDefensiveTankerMission(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = persistentMemoryGetForKey(args.shortKey.."_tan_d_miss")
    local updatedMission = nil
    -- Condition Check
    if #missions == 0 then
        return
    end
    -- Loop Through Coverted HVAs Missions
    for k, v in pairs(missions) do
        -- Updated Mission
        updatedMission = ScenEdit_GetMission(side.name,v)
        -- Check Defense Mission
        if updatedMission then
            -- Find Contact Close To Unit And Retreat If Necessary
            local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
            -- Determine Retreat
            determineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,200)
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Initialize AI Attributes
--------------------------------------------------------------------------------------------------------------------------------
function initializeAIAttributes(options)
    -- Local AI Attributes
    local attributes = {aggressive = 5, defensive = 5, cunning = 5, direct = 5, determined = 5, reserved = 5}
    local preset = options.preset
    local userAttributes = options.options
    -- Load Presets
    if preset then
        if preset == "Leroy" then
            attributes.aggressive = 10
            attributes.defensive = 0
            attributes.cunning = 0
            attributes.direct = 10
            attributes.determined = 10
            attributes.reserved = 0
        elseif preset == "Grant" then
            attributes.aggressive = 8
            attributes.defensive = 2
            attributes.cunning = 4
            attributes.direct = 6
            attributes.determined = 6
            attributes.reserved = 4
        elseif preset == "Sherman" then
            attributes.aggressive = 6
            attributes.defensive = 4
            attributes.cunning = 8
            attributes.direct = 2
            attributes.determined = 6
            attributes.reserved = 4
        elseif preset == "Sheridan" then
            attributes.aggressive = 5
            attributes.defensive = 5
            attributes.cunning = 5
            attributes.direct = 5
            attributes.determined = 5
            attributes.reserved = 5
        elseif preset == "Longstreet" then
            attributes.aggressive = 4
            attributes.defensive = 6
            attributes.cunning = 5
            attributes.direct = 5
            attributes.determined = 5
            attributes.reserved = 5
        elseif preset == "Mcclellan" then
            attributes.aggressive = 2
            attributes.defensive = 8
            attributes.cunning = 4
            attributes.direct = 6
            attributes.determined = 8
            attributes.reserved = 2
        elseif preset == "Butler" then
            attributes.aggressive = 0
            attributes.defensive = 10
            attributes.cunning = 0
            attributes.direct = 10
            attributes.determined = 0
            attributes.reserved = 10
        end
    elseif userAttributes then
        -- Aggressive, Defensive Check
        local aggressive = attributes.aggressive
        local defensive = attributes.defensive
        local cunning = attributes.cunning
        local direct = attributes.direct
        local determined = attributes.determined
        local reserved = attributes.reserved
        -- Get Override User Values
        if userAttributes.aggressive then
            aggressive = userAttributes.aggressive
        end

        if userAttributes.defensive then
            defensive = userAttributes.defensive
        end
        if userAttributes.cunning then
            cunning = userAttributes.cunning
        end
        if userAttributes.direct then
            direct = userAttributes.direct
        end
        if userAttributes.determined then
            determined = userAttributes.determined
        end
        if userAttributes.reserved then
            reserved = userAttributes.reserved
        end
        -- Set Weight Back To Scale Of !0
        aggressive = math.floor((aggressive/(aggressive+defensive))*10) 
        defensive = 10 - aggressive
        cunning = math.floor((cunning/(cunning+direct))*10)
        direct = 10 - cunning
        determined = math.floor((determined/(determined+reserved))*10)
        reserved = 10 - determined
        -- Set User Attributes
        attributes.aggressive = aggressive
        attributes.defensive = defensive
        attributes.cunning = cunning
        attributes.direct = direct
        attributes.determined = determined
        attributes.reserved = reserved
    end
    -- Return
    return attributes
end

--------------------------------------------------------------------------------------------------------------------------------
-- Initialize AI
--------------------------------------------------------------------------------------------------------------------------------
function initializeAresAI(sideName,options)
    -- Local Values
    local side = ScenEdit_GetSideOptions({side=sideName})
    local sideGuid = side.guid
    local shortSideKey = "a"..tostring(#aresObserverAIArray + 1)
    local attributes = initializeAIAttributes(options)
    -- Ares OODA Selectors 
    local aresObserverBTMain = BT:make(BT.sequence,sideGuid,shortSideKey,attributes)
    local aresOrienterBTMain = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    local aresDeciderBTMain = BT:make(BT.sequence,sideGuid,shortSideKey,attributes)
    local aresActorBTMain = BT:make(BT.sequence,sideGuid,shortSideKey,attributes)
    ----------------------------------------------------------------------------------------------------------------------------
    -- Ares Observer
    ----------------------------------------------------------------------------------------------------------------------------
    local observerActionUpdateAIVariablesBT = BT:make(observerActionUpdateAIVariables,sideGuid,shortSideKey,attributes)
    local observerActionUpdateAirInventoriesBT = BT:make(observerActionUpdateAirInventories,sideGuid,shortSideKey,attributes)
    local observerActionUpdateSurfaceInventoriesBT = BT:make(observerActionUpdateSurfaceInventories,sideGuid,shortSideKey,attributes)
    local observerActionUpdateSubmarineInventoriesBT = BT:make(observerActionUpdateSubmarineInventories,sideGuid,shortSideKey,attributes)
    local observerActionUpdateLandInventoriesBT = BT:make(observerActionUpdateLandInventories,sideGuid,shortSideKey,attributes)
    local observerActionUpdateHVAInventoriesBT = BT:make(observerActionUpdateHVAInventories,sideGuid,shortSideKey,attributes)
    local observerActionUpdateAirContactsBT = BT:make(observerActionUpdateAirContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateSurfaceContactsBT = BT:make(observerActionUpdateSurfaceContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateSubmarineContactsBT = BT:make(observerActionUpdateSubmarineContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateLandContactsBT = BT:make(observerActionUpdateLandContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateWeaponContactsBT = BT:make(observerActionUpdateWeaponContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateAIAreaOfOperationsBT = BT:make(observerActionUpdateAIAreaOfOperations,sideGuid,shortSideKey,attributes)
    aresObserverBTMain:addChild(observerActionUpdateAIVariablesBT)
    aresObserverBTMain:addChild(observerActionUpdateAirInventoriesBT)
    aresObserverBTMain:addChild(observerActionUpdateSurfaceInventoriesBT)
    aresObserverBTMain:addChild(observerActionUpdateSubmarineInventoriesBT)
    aresObserverBTMain:addChild(observerActionUpdateLandInventoriesBT)
    aresObserverBTMain:addChild(observerActionUpdateHVAInventoriesBT)
    aresObserverBTMain:addChild(observerActionUpdateAirContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateSurfaceContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateSubmarineContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateLandContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateWeaponContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateAIAreaOfOperationsBT)
    ----------------------------------------------------------------------------------------------------------------------------
    -- Ares Decider
    ----------------------------------------------------------------------------------------------------------------------------
    local deciderDoctrineSelectorBT = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    local deciderAttackDoctrineSequenceBT = BT:make(BT.sequence,sideGuid,shortSideKey,attributes)
    local deciderDefendDoctrineSequenceBT = BT:make(BT.sequence,sideGuid,shortSideKey,attributes)
    -- Offensive Behavior Tree
    local deciderOffensiveCheckBT = BT:make(deciderOffensiveCheck,sideGuid,shortSideKey,attributes)
    local deciderNeutralReconCreateUpdateMissionBT = BT:make(deciderNeutralReconCreateUpdateMission,sideGuid,shortSideKey,attributes)
    local deciderOffensiveAirCreateUpdateMissionBT = BT:make(deciderOffensiveAirCreateUpdateMission,sideGuid,shortSideKey,attributes)
    local deciderOffensiveStealthAirCreateUpdateMissionBT = BT:make(deciderOffensiveStealthAirCreateUpdateMission,sideGuid,shortSideKey,attributes)
    local deciderOffensiveAEWCreateUpdateMissionBT = BT:make(deciderOffensiveAEWCreateUpdateMission,sideGuid,shortSideKey,attributes)
    local deciderOffensiveSeadCreateUpdateMissionBT = BT:make(deciderOffensiveSeadCreateUpdateMission,sideGuid,shortSideKey,attributes)
    local deciderOffensiveTankerCreateUpdateMissionBT = BT:make(deciderOffensiveTankerCreateUpdateMission,sideGuid,shortSideKey,attributes)
    local deciderOffensiveLandAttackCreateUpdateMissionBT = BT:make(deciderOffensiveLandAttackCreateUpdateMission,sideGuid,shortSideKey,attributes)
    local deciderOffensiveAntiSurfaceShipCreateUpdateMissionBT = BT:make(deciderOffensiveAntiSurfaceShipCreateUpdateMission,sideGuid,shortSideKey,attributes)
    local deciderOffensiveAntiSubmarineCreateUpdateMissionBT = BT:make(deciderOffensiveAntiSubmarineCreateUpdateMission,sideGuid,shortSideKey,attributes)
    -- Defensive Behavior Tree
    local deciderDefensiveCheckBT = BT:make(deciderDefensiveCheck,sideGuid,shortSideKey,attributes)
    local deciderDefensiveAirCreateUpdateMissionBT = BT:make(deciderDefensiveAirCreateUpdateMission,sideGuid,shortSideKey,attributes)
    local deciderDefensiveAEWCreateUpdateMissionBT = BT:make(deciderDefensiveAEWCreateUpdateMission,sideGuid,shortSideKey,attributes)
    local deciderDefensiveTankerCreateUpdateMissionBT = BT:make(deciderDefensiveTankerCreateUpdateMission,sideGuid,shortSideKey,attributes)
    local deciderDefensiveAntiSubmarineCreateUpdateMissionBT = BT:make(deciderDefensiveAntiSubmarineCreateUpdateMission,sideGuid,shortSideKey,attributes)
    -- Neutral Behavior Tree
    local deciderNeutralShipCreateUpdateMissionBT = BT:make(deciderNeutralShipCreateUpdateMission,sideGuid,shortSideKey,attributes)
    local deciderNeutralSubmarineCreateUpdateMissionBT = BT:make(deciderNeutralSubmarineCreateUpdateMission,sideGuid,shortSideKey,attributes)
    --local deciderNeutralSAMCreateUpdateMissionBT = BT:make(deciderNeutralSAMCreateUpdateMission,sideGuid,shortSideKey,attributes)
    -- Add Sequences
    aresDeciderBTMain:addChild(deciderDoctrineSelectorBT)
    deciderDoctrineSelectorBT:addChild(deciderAttackDoctrineSequenceBT)
    deciderDoctrineSelectorBT:addChild(deciderDefendDoctrineSequenceBT)
    -- Setup Attack Doctrine Sequence
    deciderAttackDoctrineSequenceBT:addChild(deciderOffensiveCheckBT)
    deciderAttackDoctrineSequenceBT:addChild(deciderNeutralReconCreateUpdateMissionBT)
    deciderAttackDoctrineSequenceBT:addChild(deciderOffensiveAirCreateUpdateMissionBT)
    deciderAttackDoctrineSequenceBT:addChild(deciderOffensiveStealthAirCreateUpdateMissionBT)
    deciderAttackDoctrineSequenceBT:addChild(deciderOffensiveAEWCreateUpdateMissionBT)
    deciderAttackDoctrineSequenceBT:addChild(deciderOffensiveTankerCreateUpdateMissionBT)
    deciderAttackDoctrineSequenceBT:addChild(deciderOffensiveSeadCreateUpdateMissionBT)
    deciderAttackDoctrineSequenceBT:addChild(deciderOffensiveLandAttackCreateUpdateMissionBT)
    deciderAttackDoctrineSequenceBT:addChild(deciderOffensiveAntiSurfaceShipCreateUpdateMissionBT)
    deciderAttackDoctrineSequenceBT:addChild(deciderOffensiveAntiSubmarineCreateUpdateMissionBT)
    deciderAttackDoctrineSequenceBT:addChild(deciderNeutralShipCreateUpdateMissionBT)
    deciderAttackDoctrineSequenceBT:addChild(deciderNeutralSubmarineCreateUpdateMissionBT)
    deciderAttackDoctrineSequenceBT:addChild(deciderNeutralSAMCreateUpdateMissionBT)
    -- Setup Defend Doctrine Sequence
    deciderDefendDoctrineSequenceBT:addChild(deciderDefensiveCheckBT)
    deciderDefendDoctrineSequenceBT:addChild(deciderNeutralReconCreateUpdateMissionBT)
    deciderDefendDoctrineSequenceBT:addChild(deciderDefensiveAirCreateUpdateMissionBT)
    deciderDefendDoctrineSequenceBT:addChild(deciderDefensiveAEWCreateUpdateMissionBT)
    deciderDefendDoctrineSequenceBT:addChild(deciderDefensiveTankerCreateUpdateMissionBT)
    deciderDefendDoctrineSequenceBT:addChild(deciderDefensiveAntiSubmarineCreateUpdateMissionBT)
    deciderDefendDoctrineSequenceBT:addChild(deciderNeutralShipCreateUpdateMissionBT)
    deciderDefendDoctrineSequenceBT:addChild(deciderNeutralSubmarineCreateUpdateMissionBT)
    --deciderDefendDoctrineSequenceBT:addChild(deciderNeutralSAMCreateUpdateMissionBT)
    ----------------------------------------------------------------------------------------------------------------------------
    -- Ares Actor
    ----------------------------------------------------------------------------------------------------------------------------
    local actorUpdateAirReinforcementRequestBT = BT:make(actorUpdateAirReinforcementRequest,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInReconMissionBT = BT:make(actorUpdateUnitsInReconMission,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInOffensiveAirMissionBT = BT:make(actorUpdateUnitsInOffensiveAirMission,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInOffensiveStealthAirMissionBT = BT:make(actorUpdateUnitsInOffensiveStealthAirMission,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInOffensiveSeadMissionBT = BT:make(actorUpdateUnitsInOffensiveSeadMission,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInOffensiveLandMissionBT = BT:make(actorUpdateUnitsInOffensiveLandMission,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInOffensiveAntiShipMissionBT = BT:make(actorUpdateUnitsInOffensiveAntiShipMission,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInOffensiveAntiSubmarineMissionBT = BT:make(actorUpdateUnitsInOffensiveAntiSubmarineMission,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInOffensiveAEWMissionBT = BT:make(actorUpdateUnitsInOffensiveAEWMission,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInOffensiveTankerMissionBT = BT:make(actorUpdateUnitsInOffensiveTankerMission,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInDefensiveAirMissionBT = BT:make(actorUpdateUnitsInDefensiveAirMission,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInDefensiveAEWMissionBT = BT:make(actorUpdateUnitsInDefensiveAEWMission,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInDefensiveTankerMissionBT = BT:make(actorUpdateUnitsInDefensiveTankerMission,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInNeutralShipMissionBT = BT:make(actorUpdateUnitsInNeutralShipMission,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInNeutralSubmarineMissionBT = BT:make(actorUpdateUnitsInNeutralSubmarineMission,sideGuid,shortSideKey,attributes)
    local actorUpdateUnitsInNeutralSAMMissionBT = BT:make(actorUpdateUnitsInNeutralSAMMission,sideGuid,shortSideKey,attributes)
    aresActorBTMain:addChild(actorUpdateAirReinforcementRequestBT)
    aresActorBTMain:addChild(actorUpdateUnitsInReconMissionBT)
    aresActorBTMain:addChild(actorUpdateUnitsInOffensiveAirMissionBT)
    aresActorBTMain:addChild(actorUpdateUnitsInOffensiveStealthAirMissionBT)
    aresActorBTMain:addChild(actorUpdateUnitsInOffensiveSeadMissionBT)
    aresActorBTMain:addChild(actorUpdateUnitsInOffensiveLandMissionBT)
    aresActorBTMain:addChild(actorUpdateUnitsInOffensiveAntiShipMissionBT)
    aresActorBTMain:addChild(actorUpdateUnitsInOffensiveAntiSubmarineMissionBT)
    aresActorBTMain:addChild(actorUpdateUnitsInOffensiveAEWMissionBT)
    aresActorBTMain:addChild(actorUpdateUnitsInOffensiveTankerMissionBT)
    aresActorBTMain:addChild(actorUpdateUnitsInDefensiveAirMissionBT)
    aresActorBTMain:addChild(actorUpdateUnitsInDefensiveAEWMissionBT)
    aresActorBTMain:addChild(actorUpdateUnitsInDefensiveTankerMissionBT)
    aresActorBTMain:addChild(actorUpdateUnitsInNeutralShipMissionBT)
    aresActorBTMain:addChild(actorUpdateUnitsInNeutralSubmarineMissionBT)
    --aresActorBTMain:addChild(actorUpdateUnitsInNeutralSAMMissionBT)
    ----------------------------------------------------------------------------------------------------------------------------
    -- Save
    ----------------------------------------------------------------------------------------------------------------------------
    aresObserverAIArray[#aresObserverAIArray + 1] = aresObserverBTMain
    aresOrienterAIArray[#aresOrienterAIArray + 1] = aresOrienterBTMain
    aresDeciderAIArray[#aresDeciderAIArray + 1] = aresDeciderBTMain
    aresActorAIArray[#aresActorAIArray + 1] = aresActorBTMain
end

function updateAresAI()
    -- Run Observer
    for k, v in pairs(aresObserverAIArray) do
        v:run()
    end
    -- Run Orienter
    if canUpdateEveryTwoMinutes() then
        for k, v in pairs(aresOrienterAIArray) do
            v:run()
        end
    end
    -- Run Decider
    if canUpdateEveryTwoMinutes() then
        for k, v in pairs(aresDeciderAIArray) do
            v:run()
        end
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
initializeAresAI("Red Force",{preset="Sheridan"})