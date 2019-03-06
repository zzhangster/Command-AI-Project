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

--------------------------------------------------------------------------------------------------------------------------------
-- Generic Helper Functions
--------------------------------------------------------------------------------------------------------------------------------
function makeWaypoint(latitude, longitude, altitude, speed, followPlottedPath, overrideAltitude)
    local ignorePath = "yes"
    if followPlottedPath then
        ignorePath = "no"
    end
    return {lat=latitude,lon=longitude,alt=altitude,manualSpeed=speed,ignorePlottedPath=ignorePath,overrideAltitude=overrideAltitude}
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

function heightToHorizon(distance)
    return math.sqrt((6371000 * 6371000) + (distance * distance)) - 6371000
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

function getGroupLeadsFromMission(sideName,missionGuid,unitType,activeUnits)
    local mission = ScenEdit_GetMission(sideName,missionGuid)
    local unitKeyValue = {}
    local missionUnits = {}
    local groupGuids = {}
    if mission then
        for k,v in pairs(mission.unitlist) do
            local unit = ScenEdit_GetUnit({side=sideName, guid=v})
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
-- Get Air Inventory By Role
--------------------------------------------------------------------------------------------------------------------------------
function getAirReconInventory(sideShortKey)
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
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
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
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
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
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
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
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
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
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
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
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
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
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
    local savedInventory = localMemoryInventoryGetFromKey(sideShortKey.."_saved_air_inventory")
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

--------------------------------------------------------------------------------------------------------------------------------
-- Determine Unit Retreat Functions
--------------------------------------------------------------------------------------------------------------------------------
function determineAirUnitToRetreatByRole(sideShortKey,sideGuid,sideAttributes,unitGuid,unitRole) 
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name,guid=unitGuid})
    if unit and not determineUnitBingo(side.name,unit.guid) and (unit.targetedBy or unit.firedOn or #unit.ascontact > 0) then
        -- Find Unit Retreat Point
        local unitRetreatPointArray = {}
        -- Determine Retreat Type By Role
        if unitRole == "aaw" then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,60,{"missiles","sams","ships"})
        elseif unitRole == "ag-asuw" then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,80,{"missiles"})
        elseif unitRole == "ag" then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,60,{"missiles","planes","ships"})
        elseif unitRole == "asuw" then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,80,{"missiles","planes"})
        elseif unitRole == "support" then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,200,{"missiles","planes","sams","ships"})
        elseif unitRole == "asw" then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,80,{"missiles","planes","sams","ships"})
        elseif unitRole == "recon" then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,60,{"missiles","planes","sams","ships"})
        elseif unitRole == "sead" then
            unitRetreatPointArray = determineRetreatPoint(sideGuid,sideShortKey,sideAttributes,unit.guid,60,{"missiles","planes"})
        else
            unitRetreatPointArray = nil
        end
        -- Set Unit Retreat Point
        if unitRetreatPointArray then
			--ScenEdit_SpecialMessage("PRC","determineAirUnitToRetreatByRole - "..unitRetreatPoint.latitude.." "..unitRetreatPoint.longitude)
			--{latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=2000}
            --if unit.group and unit.group.unitlist then
            --   for k1,v1 in pairs(unit.group.unitlist) do
            --        local subUnit = ScenEdit_GetUnit({side=side.name,guid=v1})
            --        ScenEdit_SetDoctrine({side=side.name,guid=subUnit.guid},{ignore_plotted_course = "no" })
            --        subUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            --        subUnit.manualSpeed = unitRetreatPoint.speed
            --    end
            --else 
            --    ScenEdit_SetDoctrine({side=side.name,guid=unit.guid},{ignore_plotted_course = "no" })
            --    unit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            --    unit.manualSpeed = unitRetreatPoint.speed
            --end
            unit.manualAltitude = unitRetreatPointArray[1].overrideAltitude
            ScenEdit_SetDoctrine({side=side.name,guid=unit.guid},{ignore_plotted_course = unitRetreatPointArray[1].ignorePlottedPath })
            unit.course = unitRetreatPointArray
            unit.manualSpeed = unitRetreatPointArray[1].manualSpeed
        else
            unit.manualAltitude = false
            ScenEdit_SetDoctrine({side=side.name,guid=unit.guid},{ignore_plotted_course = "yes" })
            unit.manualSpeed = "OFF"
        end
    end
end

function determineRetreatPoint(sideGuid,shortSideKey,sideAttributes,unitGuid,range,avoidanceTypes)
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local desiredRange = range
    -- Loop Through Avoidance Types
    for i = 1, #avoidanceTypes do
        local retreatPointArray  = nil
        if avoidanceTypes[i] == "planes" then
            retreatPointArray = getRetreatPathForAirNoNavZone(sideGuid,shortSideKey,sideAttributes,unitGuid,range)
        elseif avoidanceTypes[i] == "ships" then
            retreatPointArray = getRetreatPathForShipNoNavZone(sideGuid,shortSideKey,sideAttributes,unitGuid)
        elseif avoidanceTypes[i] == "sams" then
            retreatPointArray = getRetreatPathForSAMNoNavZone(sideGuid,shortSideKey,sideAttributes,unitGuid)
        elseif avoidanceTypes[i] == "missiles" then
            retreatPointArray = getRetreatPathForEmergencyMissileNoNavZone(sideGuid,shortSideKey,sideAttributes,unitGuid)
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

function getRetreatPathForAirNoNavZone(sideGuid,shortSideKey,sideAttributes,unitGuid,range)
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local hostileAirContacts = getHostileAirContacts(shortSideKey)
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
                local retreatLocation = projectLatLong(makeLatLong(unit.latitude,unit.longitude),bearing,20)
                return {makeWaypoint(retreatLocation.latitude,retreatLocation.longitude,unit.altitude,2000,true,false)}
            end
        end
    end
    return nil
end

function getRetreatPathForShipNoNavZone(sideGuid,shortSideKey,sideAttributes,unitGuid)
    -- Variables
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local hostileShipContacts = getHostileSurfaceShipContacts(shortSideKey)
    local minDesiredRange = 8
    local maxDesiredRange = 200
	local distanceToShip = 10000
	local contact = nil
	-- Check Update
    if not unit and not canUpdateEverySixtySeconds() then
        return nil
    end
	-- Find Shortest Range Missile
	for k,v in pairs(hostileShipContacts) do
        local currentContact = ScenEdit_GetContact({side=side.name, guid=v})
		if currentContact then
			local distanceToCurrentShip = Tool_Range(v,unitGuid)
			if distanceToCurrentShip < distanceToShip then
                distanceToShip = distanceToCurrentShip
				contact = currentContact
			end
		end
	end
	-- Find Checks
	if not contact then
        return nil
    elseif distanceToShip < 25 then
        -- Emergency Evasion
        local contactPoint = makeLatLong(contact.latitude,contact.longitude)
        local bearing = Tool_Bearing({latitude=contactPoint.latitude,longitude=contactPoint.longitude},unitGuid)
        local retreatLocation = projectLatLong(makeLatLong(unit.latitude, unit.longitude),bearing,20)
        return {makeWaypoint(retreatLocation.latitude,retreatLocation.longitude,30,2000,true,true)}
    elseif distanceToShip < maxDesiredRange then
        if #unit.course > 0 then
            local waypoint = unit.course[#unit.course]
            return {makeWaypoint(waypoint.latitude,waypoint.longitude,heightToHorizon(distanceToShip),unit.speed,false,true)}
        else
            return {makeWaypoint(unit.latitude,unit.longitude,heightToHorizon(distanceToShip),unit.speed,false,true)}
        end
    end
    -- Catch All Return
    return nil
end

function getRetreatPathForSAMNoNavZone(sideGuid,shortSideKey,sideAttributes,unitGuid)
    -- Variables
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local hostileSAMContacts = getHostileSAMContacts(shortSideKey)
    local minDesiredRange = 8
    local maxDesiredRange = 200
	local distanceToSAM = 10000
	local contact = nil
	-- Check Update
    if not unit and not canUpdateEverySixtySeconds() then
        return nil
    end
	-- Find Shortest Range Missile
	for k,v in pairs(hostileSAMContacts) do
        local currentContact = ScenEdit_GetContact({side=side.name, guid=v})
		if currentContact then
			local distanceToCurrentSAM = Tool_Range(v,unitGuid)
			if distanceToCurrentSAM < distanceToSAM then
                distanceToSAM = distanceToCurrentSAM
				contact = currentContact
			end
		end
	end
	-- Find Checks
	if not contact then
        return nil
    elseif distanceToSAM < 25 then
        -- Emergency Evasion
        local contactPoint = makeLatLong(contact.latitude,contact.longitude)
        local bearing = Tool_Bearing({latitude=contactPoint.latitude,longitude=contactPoint.longitude},unitGuid)
        local retreatLocation = projectLatLong(makeLatLong(unit.latitude, unit.longitude),bearing,20)
        return {makeWaypoint(retreatLocation.latitude,retreatLocation.longitude,30,2000,true,true)}
    elseif distanceToSAM < maxDesiredRange then
        if #unit.course > 0 then
            local waypoint = unit.course[#unit.course]
            return {makeWaypoint(waypoint.latitude,waypoint.longitude,heightToHorizon(distanceToSAM),unit.speed,false,true)}
        else
            return {makeWaypoint(unit.latitude,unit.longitude,heightToHorizon(distanceToSAM),unit.speed,false,true)}
        end
    end
    -- Catch All Return
    return nil
end

function getRetreatPathForEmergencyMissileNoNavZone(sideGuid,shortSideKey,sideAttributes,unitGuid)
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local hostileMissilesContacts = getHostileWeaponContacts(shortSideKey)
    local minDesiredRange = 8
    local maxDesiredRange = 60
	local distanceToMissile = 10000
	local contact = nil
	-- Check Update
    if not unit and not canUpdateEveryTenSeconds() then
        return nil
    end
	-- Check Fired on
    if not unit.targetedBy and not unit.firedOn then
		return nil
	end
	-- Find Shortest Range Missile
	for k,v in pairs(hostileMissilesContacts) do
        local currentContact = ScenEdit_GetContact({side=side.name, guid=v})
		if currentContact then
			local distanceToCurrentMissile = Tool_Range(v,unitGuid)
			if distanceToCurrentMissile < distanceToMissile then
				distanceToMissile = distanceToCurrentMissile
				contact = currentContact
			end
		end
	end
	-- (latitude, longitude, altitude, speed, followPlottedPath, overrideAltitude)
	-- Find Checks
	if not contact then
		return nil
	elseif distanceToMissile < 25 then
		-- Emergency Evasion
		local contactPoint = makeLatLong(contact.latitude,contact.longitude)
		local bearing = Tool_Bearing({latitude=contactPoint.latitude,longitude=contactPoint.longitude},unitGuid) - 1
        local retreatLocation = projectLatLong(makeLatLong(unit.latitude, unit.longitude),bearing,20)
        return {makeWaypoint(retreatLocation.latitude,retreatLocation.longitude,30,2000,true,true)}
	elseif distanceToMissile < maxDesiredRange then
		-- Check If Attacking Enemy And Break At Last Minute
		local isFiringAt = false
		local isFiringAtRange = 100000
		if unit.firingAt then
			for k1,v1 in pairs(unit.firingAt) do
				local targetRange = Tool_Range(v1,unitGuid)
				if targetRange < isFiringAtRange then
					isFiringAt = true
					isFiringAtRange = targetRange
				end
			end
		end
		if isFiringAt then
			if distanceToMissile < 0.75 * isFiringAtRange then
				local contactPoint = makeLatLong(contact.latitude,contact.longitude)
				local bearing = Tool_Bearing({latitude=contactPoint.latitude,longitude=contactPoint.longitude},unitGuid) - 1
                local retreatLocation = projectLatLong(makeLatLong(unit.latitude, unit.longitude),bearing,20)
                return {makeWaypoint(retreatLocation.latitude,retreatLocation.longitude,30,2000,true,true)}
			end
		else
			local contactPoint = makeLatLong(contact.latitude,contact.longitude)
			local bearing = Tool_Bearing({latitude=contactPoint.latitude,longitude=contactPoint.longitude},unitGuid) - 1
			local retreatLocation = projectLatLong(makeLatLong(unit.latitude, unit.longitude),bearing,20)
            return {makeWaypoint(retreatLocation.latitude,retreatLocation.longitude,30,2000,true,true)}
		end
    end
    -- Catch All Return
    return nil
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

function observerActionUpdateMissions(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    -- Check Every Five Minutes For New Missions
    if canUpdateEveryFiveMinutes() then
        -- Loop Through Aircraft Inventory And Then Find Their Missions (Can't Get List Of Missions Currently)
        local aircraftInventory = side:unitsBy("1")
        if aircraftInventory then
            local savedMissions = {}
            localMemoryRemoveFromKey(sideShortKey.."_saved_missions")
            for k, v in pairs(aircraftInventory) do
                -- Local Values
                local unit = ScenEdit_GetUnit({side=side.name, guid=v.guid})
                -- Check Mission Exits And Save In Key Value Pairs (Remove Duplication)
                if unit.mission and unit.mission.isactive and unit.speed > 0 then
					if not savedMissions[unit.mission.guid] then
						savedMissions[unit.mission.guid] = unit.mission.guid
						-- Save Missions And Time Stamp
						localMemoryAddToKey(sideShortKey.."_saved_missions",unit.mission.guid)
					end
                end
            end
        end
    end
end

function observerActionUpdateMissionInventories(args)
    -- Local Variables
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
	local sideUnitDuplicateKey = {}
    -- Check Every Five Minutes To Update Inventories
    if canUpdateEverySixtySeconds() then
        local savedMissions = localMemoryGetFromKey(sideShortKey.."_saved_missions")
        local savedInventory = {}
        localMemoryInventoryRemoveFromKey(sideShortKey.."_saved_air_inventory")
		--ScenEdit_SpecialMessage("PRC","observerActionUpdateMissions")
		--ScenEdit_SpecialMessage("PRC",deepPrint(aircraftInventory,""))
		--ScenEdit_SpecialMessage("PRC",v)
		--ScenEdit_SpecialMessage("PRC",deepPrint(mission,""))
        -- Loop Through Missions
        for k, v in pairs(savedMissions) do
            local mission = ScenEdit_GetMission(side.name,v)
			--ScenEdit_SpecialMessage("PRC",deepPrint(mission,""))
            if mission.isactive then
				-- Get Group Lead And Individual Units
                local missionRole = mission.subtype
				local missionUnits = getGroupLeadsFromMission(side.name,mission.guid,"Aircraft",true)
				-- Loop Through Units And Determine Unit Role
				for i = 1, #missionUnits do
                    local unit = ScenEdit_GetUnit({side=side.name, guid=missionUnits[i]})
                    local unitRole = "support"
                    if unit and unit.type == "Aircraft" then
                        local loadout = ScenEdit_GetLoadout({UnitName=unit.guid, LoadoutID=0})
						if loadout then
                            if loadout.roles["role"] == 2001 or loadout.roles["role"] == 2002 or loadout.roles["role"] == 2003 or loadout.roles["role"] == 2004 then
                                unitRole = "aaw"
                            elseif loadout.roles["role"] == 3001 or loadout.roles["role"] == 3002 or loadout.roles["role"] == 3005 then
                                unitRole = "ag-asuw"
                            elseif loadout.roles["role"] == 3101 or loadout.roles["role"] == 3102 or loadout.roles["role"] == 3105 then
                                unitRole = "ag"
                            elseif loadout.roles["role"] == 3201 or loadout.roles["role"] == 3202 or loadout.roles["role"] == 3205 then
                                unitRole = "asuw"
                            elseif loadout.roles["role"] == 4001 or loadout.roles["role"] == 4002 or loadout.roles["role"] == 4003 or loadout.roles["role"] == 4004 or loadout.roles["role"] == 4101 then
                                unitRole = "support"
                            elseif loadout.roles["role"] == 6001 or loadout.roles["role"] == 6002 then
                                unitRole = "asw"
                            elseif loadout.roles["role"] == 7001 or loadout.roles["role"] == 7002 or loadout.roles["role"] == 7003 or loadout.roles["role"] == 7004 or loadout.roles["role"] == 7005 then
                                unitRole = "recon"
                            elseif loadout.roles["role"] == 3003 or loadout.roles["role"] == 3004 or loadout.roles["role"] == 3103 or loadout.roles["role"] == 3104 or loadout.roles["role"] == 3203 or loadout.roles["role"] == 3204 then
                                unitRole = "sead"
                            end
                        end
						-- Compare Mission Role Vs Unit Role (Mission Role Takes Precedent In Certain Conditions)
						if missionRole == "AAW Patrol" or missionRole == "Air Intercept" then
							-- No Override - Units Will Retain Their Respective Role
						elseif missionRole == "ASuW Patrol Naval" or missionRole == "Sea Control Patrol" or missionRole == "ASuW Patrol Mixed" or missionRole == "Naval ASuW Strike" then
							if unitRole == "ag-asuw" or unitRole == "ag" or unitRole == "asuw" or unitRole == "sead" then
								unitRole = "aswu"
							end
						elseif missionRole == "ASW Patrol" or missionRole == "ASW Strike" then
							-- No Override - Units Will Retain Their Respective Role
						elseif missionRole == "ASuW Patrol Ground" or missionRole == "Land Strike" then
							if unitRole == "ag-asuw" or unitRole == "ag" then
								unitRole = "ag"
							end
						elseif missionRole == "SEAD Patrol" then
							if unitRole == "ag-asuw" or unitRole == "ag" then
								unitRole = "sead"
							end
						elseif missionRole == "Ferry" then
							unitRole = "support"
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
        localMemoryInventoryAddToKey(sideShortKey.."_saved_air_inventory",savedInventory)
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
-- Actor - Control EMCON And Movement
--------------------------------------------------------------------------------------------------------------------------------
function actorUpdateReconUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    -- Get Recon Units
    local reconUnits = getAirReconInventory(sideShortKey)
    for i = 1, #reconUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,reconUnits[i],"recon") 
	end
	
	-- 
    -- 
    --local missions = persistentMemoryGetForKey(args.shortKey.."_rec_miss")
    -- Check Total Is Zero
    --if #missions == 0 then
    --    return
    --end
    -- Loop Through Existing Missions
    --for k,v in pairs(missions) do
        -- Local Values
      --  local updatedMission = ScenEdit_GetMission(side.name,v)
        -- Find Area And Retreat Point
        --local missionUnits = getGroupLeadsFromMission(side.name,updatedMission.guid)
        -- Determine Retreat
        --determineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,80)
        -- Determine EMCON
        -- determineEmconToAirUnits(args.shortKey,args.options,side.name,missionUnits)
    --end
end

function actorUpdateAAWUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    -- Get AAW Units
    local aawUnits = getAirAawInventory(sideShortKey)
    for i = 1, #aawUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,aawUnits[i],"aaw")
	end
end

function actorUpdateAGUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    -- Get AG Units
    local agUnits = getAirAgInventory(sideShortKey)
    for i = 1, #agUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,agUnits[i],"ag")
	end
end

function actorUpdateAGAsuWUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    -- Get AG-ASUW Units
    local agAsuwUnits = getAirAgAsuwInventory(sideShortKey)
    for i = 1, #agAsuwUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,agAsuwUnits[i],"ag-asuw")
	end
end

function actorUpdateAsuWUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    -- Get ASUW Units
    local asuwUnits = getAirAsuwInventory(sideShortKey)
    for i = 1, #asuwUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,asuwUnits[i],"ag-asuw")
	end
end

function actorUpdateASWUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    -- Get ASUW Units
    local asuwUnits = getAirAsuwInventory(sideShortKey)
    for i = 1, #asuwUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,asuwUnits[i],"asuw")
	end
end

function actorUpdateSeadUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    -- Get SEAD Units
    local seadUnits = getAirSeadInventory(sideShortKey)
    for i = 1, #seadUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,seadUnits[i],"sead")
	end
end

function actorUpdateSupportUnits(args)
    -- Locals
    local sideShortKey = args.shortKey
    local side = VP_GetSide({guid=args.guid})
    -- Get Support Units
    local supportUnits = getAirSupportInventory(sideShortKey)
    for i = 1, #supportUnits do
		determineAirUnitToRetreatByRole(args.shortKey,args.guid,args.options,supportUnits[i],"support")
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
    local observerActionUpdateAIVariablesBT = BT:make(observerActionUpdateAIVariables,sideGuid,shortSideKey,attributes)
    local observerActionUpdateMissionsBT = BT:make(observerActionUpdateMissions,sideGuid,shortSideKey,attributes)
    local observerActionUpdateMissionInventoriesBT = BT:make(observerActionUpdateMissionInventories,sideGuid,shortSideKey,attributes)
    local observerActionUpdateAirContactsBT = BT:make(observerActionUpdateAirContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateSurfaceContactsBT = BT:make(observerActionUpdateSurfaceContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateSubmarineContactsBT = BT:make(observerActionUpdateSubmarineContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateLandContactsBT = BT:make(observerActionUpdateLandContacts,sideGuid,shortSideKey,attributes)
    local observerActionUpdateWeaponContactsBT = BT:make(observerActionUpdateWeaponContacts,sideGuid,shortSideKey,attributes)
    -- Add Observers
    aresObserverBTMain:addChild(observerActionUpdateAIVariablesBT)
    aresObserverBTMain:addChild(observerActionUpdateMissionsBT)
    aresObserverBTMain:addChild(observerActionUpdateMissionInventoriesBT)
    aresObserverBTMain:addChild(observerActionUpdateAirContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateSurfaceContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateSubmarineContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateLandContactsBT)
    aresObserverBTMain:addChild(observerActionUpdateWeaponContactsBT)
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
    -- Add Actors
    aresActorBTMain:addChild(actorUpdateReconUnitsBT)
    aresActorBTMain:addChild(actorUpdateAAWUnitsBT)
    aresActorBTMain:addChild(actorUpdateAGUnitsBT)
    aresActorBTMain:addChild(actorUpdateAGAsuWUnitsBT)
    aresActorBTMain:addChild(actorUpdateAsuWUnitsBT)
    aresActorBTMain:addChild(actorUpdateASWUnitsBT)
    aresActorBTMain:addChild(actorUpdateSeadUnitsBT)
    aresActorBTMain:addChild(actorUpdateSupportUnitsBT)
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
initializeAresAI("PRC")