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

function getGroupLeadFromUnit(sideName,unitGuid)
    local unit = ScenEdit_GetUnit({side=sideName, guid=unitGuid})
    if unit then
        if unit.group and unit.group.lead then
            return unit.group.lead
        else
            return unit.guid
        end
    else
        return nil
    end
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
-- Get Air Inventory
--------------------------------------------------------------------------------------------------------------------------------
function getActiveAirAttackInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_air_atk_active"] then
            return savedInventory[sideShortKey.."_atk_active"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getActiveAirSupportInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_air_sup_active"] then
            return savedInventory[sideShortKey.."_sup_active"]
        else
            return {}
        end
    else 
        return {}
    end
end

function getActiveAirDroneInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_air_drone_active"] then
            return savedInventory[sideShortKey.."_drone_active"]
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
function getActiveSurfaceShipInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_ship_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_surf_active"] then
            return savedInventory[sideShortKey.."_surf_active"]
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
function getActiveSubmarineInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_sub_inventory")
    if #savedInventory > 0 then
        savedInventory = savedInventory[1]
        if savedInventory[sideShortKey.."_sub_active"] then
            return savedInventory[sideShortKey.."_sub_active"]
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
                -- Check Status, Only Active and Flying and Is Part of Mission and not RTB or Bingo
                if unit.mission and unit.speed > 0 and unit.unitstate ~= "RTB" and unit.fuelstate ~= "IsBingo" then
                    local unitType = "atk"
                    local unitStatus = "active"
                    -- Fighter
                    if unit.subtype == "2001" or unit.subtype == "2002" or unit.subtype == "3001" or unit.subtype == "4001" or unit.subtype == "6001" or unit.subtype == "6002" or unit.subtype == "7003" then
                        unitType = "atk"
                    elseif unit.subtype == "4002" or unit.subtype == "8001" then
                        unitType = "sup"
                    elseif unit.subtype == "8201" or unit.subtype == "8002" then
                        unitType = "drone"
                    end
                    -- Add To Memory
                    local stringKey = sideShortKey.."_air_"..unitType.."_"..unitStatus
                    local stringArray = savedInventory[stringKey]
                    if not stringArray then
                        stringArray = {}
                    end
                    stringArray[#stringArray + 1] = unit.guid
                    savedInventory[stringKey] = stringArray
                end
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
                if unit.mission then
                    local unitType = "surf"
                    local unitStatus = "active"
                    -- Add To Memory
                    local stringKey = sideShortKey.."_"..unitType.."_"..unitStatus
                    local stringArray = savedInventory[stringKey]
                    if not stringArray then
                        stringArray = {}
                    end
                    stringArray[#stringArray + 1] = unit.guid
                    savedInventory[stringKey] = stringArray
                end
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
                if unit.mission then
                    local unitType = "sub"
                    local unitStatus = "active"
                    -- Add To Memory
                    local stringKey = sideShortKey.."_"..unitType.."_"..unitStatus
                    local stringArray = savedInventory[stringKey]
                    if not stringArray then
                        stringArray = {}
                    end
                    stringArray[#stringArray + 1] = unit.guid
                    savedInventory[stringKey] = stringArray
                end
            end
            -- Save Memory Inventory And Time Stamp
            localMemoryInventoryAddToKey(sideShortKey.."_saved_sub_inventory",savedInventory)
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
-- Initialize AI
--------------------------------------------------------------------------------------------------------------------------------
function initializeAresAILite(sideName,options)
    -- Local Values
    local side = ScenEdit_GetSideOptions({side=sideName})
    local sideGuid = side.guid
    local shortSideKey = "a"..tostring(#aresObserverAIArray + 1)
    -- Ares OODA Selectors 
    local aresObserverBTMain = BT:make(BT.sequence,sideGuid,shortSideKey,attributes)
    local aresActorBTMain = BT:make(BT.sequence,sideGuid,shortSideKey,attributes)
    ----------------------------------------------------------------------------------------------------------------------------
    -- Ares Observer
    ----------------------------------------------------------------------------------------------------------------------------
    local observerActionUpdateAIVariablesBT = BT:make(observerActionUpdateAIVariables,sideGuid,shortSideKey,attributes)
    local observerActionUpdateAirInventoriesBT = BT:make(observerActionUpdateAirInventories,sideGuid,shortSideKey,attributes)
    local observerActionUpdateSurfaceInventoriesBT = BT:make(observerActionUpdateSurfaceInventories,sideGuid,shortSideKey,attributes)
    local observerActionUpdateSubmarineInventoriesBT = BT:make(observerActionUpdateSubmarineInventories,sideGuid,shortSideKey,attributes)
    local observerActionUpdateAirContactsBT = BT:make(observerActionUpdateAirContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateSurfaceContactsBT = BT:make(observerActionUpdateSurfaceContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateSubmarineContactsBT = BT:make(observerActionUpdateSubmarineContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateWeaponContactsBT = BT:make(observerActionUpdateWeaponContacts,sideGuid,shortSideKey,attributes)
    aresObserverBTMain:addChild(observerActionUpdateAIVariablesBT)
    aresObserverBTMain:addChild(observerActionUpdateAirInventoriesBT)
    aresObserverBTMain:addChild(observerActionUpdateSurfaceInventoriesBT)
    aresObserverBTMain:addChild(observerActionUpdateSubmarineInventoriesBT)
    aresObserverBTMain:addChild(observerActionUpdateAirContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateSurfaceContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateSubmarineContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateWeaponContactsBT)
    ----------------------------------------------------------------------------------------------------------------------------
    -- Ares Actor
    ----------------------------------------------------------------------------------------------------------------------------
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
initializeAresAILite("Red Force",{preset="Sheridan"})