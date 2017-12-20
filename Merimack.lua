--[[
  This behavior tree code was taken from our Zelda AI project for CMPS 148 at UCSC.
  It is for the most part unmodified, and comments are available for each function.
  Behavior tree code credited to https://gist.github.com/mrunderhill89/
]]--
BT = {}
BT.__index = BT
BT.results = {success = "success", fail = "fail", wait = "wait", error = "error"}
local commandMerrimackAIArray = {} -- Create And Update Missions
local commandMonitorAIArray = {} -- Create Threat Checker
local commandHamptonAIArray = {} -- Micro Management
local commandCumberlandAIArray = {} -- Priority Unit Assignment
local commandMemory = {}

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
-- Generic Helper Functions
--------------------------------------------------------------------------------------------------------------------------------
function InternationalDecimalConverter(value)
    if type(value) == "number" then
        return value
    else 
        local convert = string.gsub(value,",",".")
        return convert
    end
end

function MakeLatLong(latitude,longitude)
    local instance = {}
    instance.latitude = InternationalDecimalConverter(latitude)
    instance.longitude = InternationalDecimalConverter(longitude)
    return instance
end

function MidPointCoordinate(lat1,lon1,lat2,lon2)
    -- Internationalize
    lat1 = InternationalDecimalConverter(lat1)
    lon1 = InternationalDecimalConverter(lon1)
    lat2 = InternationalDecimalConverter(lat2)
    lon2 = InternationalDecimalConverter(lon2)

    -- Local
    local dLon = math.rad(lon2 - lon1)
    
    -- Convert to radians
    lat1 = math.rad(lat1)
    lat2 = math.rad(lat2)
    lon1 = math.rad(lon1)
    
    local Bx = math.cos(lat2) * math.cos(dLon)
    local By = math.cos(lat2) * math.sin(dLon)
    local lat3 = math.atan2(math.sin(lat1) + math.sin(lat2), math.sqrt((math.cos(lat1) + Bx) * (math.cos(lat1) + Bx) + By * By))
    local lon3 = lon1 + math.atan2(By, math.cos(lat1) + Bx)
    
    -- Print out in degrees
    return MakeLatLong(math.deg(lat3),math.deg(lon3))
end

function ProjectLatLong(origin,bearing,range)
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
    return MakeLatLong(math.deg(endLatRads),math.deg(endLonRads))
end

function FindBoundingBoxForGivenLocations(coordinates,padding)
    local west = 0.0
    local east = 0.0
    local north = 0.0
    local south = 0.0

    -- Condiation Check
    if coordinates == nil or #coordinates == 0 then
        padding = 0
    end

    -- Assign Up to numberOfReconToAssign
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

    --Adding Padding
    north = north + padding
    south = south - padding
    west = west - padding
    east = east + padding

    --Return In Format
    return {MakeLatLong(north,west),MakeLatLong(north,east),MakeLatLong(south,east),MakeLatLong(south,west)}
end

function FindBoundingBoxForGivenContacts(sideName,contacts,defaults,padding)
    -- Local Variables
    local contactBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(defaults[1].latitude,defaults[1].longitude),MakeLatLong(defaults[2].latitude,defaults[2].longitude),MakeLatLong(defaults[3].latitude,defaults[3].longitude),MakeLatLong(defaults[4].latitude,defaults[4].longitude)},padding)
    local contactCoordinates = {}

    for k, v in pairs(contacts) do
        local contact = ScenEdit_GetContact({side=sideName, guid=v})
        contactCoordinates[#contactCoordinates + 1] = MakeLatLong(contact.latitude,contact.longitude)
    end
    
    -- Get Hostile Contact Bounding Box
    if #contactCoordinates > 0 then
        contactBoundingBox = FindBoundingBoxForGivenLocations(contactCoordinates,padding)
    end

    -- Return Bounding Box
    return contactBoundingBox
end

function CombineTablesNew(table1,table2)
    local combinedTable = {}

    for k, v in pairs(table1) do
        combinedTable[#combinedTable + 1] = v
    end
    
    for k, v in pairs(table2) do
        combinedTable[#combinedTable + 1] = v
    end

    return combinedTable
end

function CombineTables(table1,table2)
    for k, v in pairs(table2) do
        table1[#table1 + 1] = v
    end
    return table1
end

function Split(s, sep)
    local fields = {}
    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

function GetGroupLeadsAndIndividualsFromMission(sideName,missionGuid)
    local mission = ScenEdit_GetMission(sideName,missionGuid)
    local unitKeyValue = {}
    local missionUnits = {}
    if mission then
        for k,v in pairs(mission.unitlist) do
            local unit = ScenEdit_GetUnit({side=sideName, guid=v})
            if unitKeyValue[unit.guid] == nil then
                missionUnits[#missionUnits + 1] = unit.guid
                unitKeyValue[unit.guid] = ""
            end
        end
        ScenEdit_SpecialMessage("Blue Force", "GetGroupLeadsAndIndividualsFromMission: "..mission.name.." "..tostring(#missionUnits))
    end
    return missionUnits
end

function DetermineRoleFromLoadOutDatabase(loudoutId,defaultRole)
    local role = ScenEdit_GetKeyValue("lo_"..tostring(loudoutId))
    if role == nil or role == "" then
        return defaultRole
    else
        return role
    end
end

function DetermineUnitRTB(sideName,unitGuid)
    local unit = ScenEdit_GetUnit({side=sideName, guid=unitGuid})
    if unit then
        if string.match(unit.unitstate, "RTB") then
            return true
        else
            return false
        end
    end
    
end

function DetermineThreatRangeByUnitDatabaseId(sideGuid,contactGuid)
    local side = VP_GetSide({guid=sideGuid})
    local contact = ScenEdit_GetContact({side=side.name, guid=contactGuid})
    local range = 0
    -- Loop Through EM Matches And Get First
    for k,v in pairs(contact.potentialmatches) do
        local foundRange = ScenEdit_GetKeyValue("thr_"..tostring(v.DBID))
        if foundRange ~= "" then
            range = tonumber(foundRange)
            break
        end
    end
    -- If Range Is Zero Determine By Default Air Defence Values
    if range == 0 then
        -- Create Exlusion Zone Based On Missile Defense
        if contact.missile_defence < 2 then
            range = 5
        elseif contact.missile_defence < 5 then
            range = 20
        elseif contact.missile_defence < 7 then
            range = 40
        elseif contact.missile_defence < 20 then
            range = 80
        else 
            range = 130
        end
    end
    -- Return Range
    return range
end

function DetermineUnitsToAssign(sideShortKey,sideName,missionGuid,totalRequiredUnits,unitGuidList)
    -- Local Values
    local mission = ScenEdit_GetMission(sideName,missionGuid)
    -- Check
    if mission then
        -- Loop Through Mission Unit Lists And Unassign RTB Units
        for k,v in pairs(mission.unitlist) do
            local unit = ScenEdit_GetUnit({side=sideName, guid=v})
            if unit then
                if unit.speed == 0 and tostring(unit.readytime) ~= 0  then
                    local mockMission = ScenEdit_AddMission(sideName,"MOCK MISSION",'strike',{type='land'})
                    ScenEdit_AssignUnitToMission(unit.guid, mockMission.guid)            
                    ScenEdit_DeleteMission(sideName,mockMission.guid)
                end
            end
        end
        -- Get Units Left To Assign
        totalRequiredUnits = totalRequiredUnits - #mission.unitlist
        -- Assign Up to Total Required Units
        for k,v in pairs(unitGuidList) do
            -- Condition Check
            if totalRequiredUnits <= 0 then
                break
            end
            -- Check Unit And Assign
            local unit = ScenEdit_GetUnit({side=sideName, guid=v})
            -- Check If Unit Has Already Been Allocated In This Cycle
            if not MemoryGUIDExists(sideShortKey.."_alloc_units",unit.guid) then
                if (not DetermineUnitRTB(sideName,v) and unit.speed > 0) or (tostring(unit.readytime) == "0" and unit.speed == 0) then
                    totalRequiredUnits = totalRequiredUnits - 1
                    ScenEdit_AssignUnitToMission(v,mission.guid)
                    MemoryAddGUIDToKey(sideShortKey.."_alloc_units",unit.guid)
                end
            end
        end
    end
end

function DetermineEmconToUnits(sideShortKey,sideName,unitGuidList)
    local busyAEWInventory = GetBusyAirAEWInventory(sideShortKey)
    for k,v in pairs(unitGuidList) do
        local unit = ScenEdit_GetUnit({side=sideName, guid=v})
        ScenEdit_SetEMCON("Unit",v,"Radar=Active")  
        for k1,v1 in pairs(busyAEWInventory) do
            local aewUnit = ScenEdit_GetUnit({side=sideName, guid=v1})
            if aewUnit.speed > 0 and aewUnit.altitude > 0 then
                if Tool_Range(v1,v) < 150 then
                    ScenEdit_SetEMCON("Unit",v,"Radar=Passive")
                end
            end
        end      
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Constant GUID Functions
--------------------------------------------------------------------------------------------------------------------------------
function GetGlobalConstant()
    local globalConstant = ScenEdit_GetKeyValue("CONST_GLOBAL_VALUE")
    if globalConstant == nil then
        globalConstant = "0"
    end
    globalConstant = tostring(tonumber(globalConstant) + 1)
    ScenEdit_SetKeyValue("CONST_GLOBAL_VALUE",globalConstant)
    return tonumber(globalConstant)
end
--------------------------------------------------------------------------------------------------------------------------------
-- Save GUID In Memory Functions
--------------------------------------------------------------------------------------------------------------------------------
function MemoryRemoveAllGUIDsFromKey(primaryKey)
    --ScenEdit_SpecialMessage("Blue Force", " - MemoryRemoveAllGUIDsFromKey "..primaryKey)
    commandMemory[primaryKey] = nil
end

function MemoryGetGUIDFromKey(primaryKey)
    --ScenEdit_SpecialMessage("Blue Force", " - MemoryGetGUIDFromKey "..primaryKey)
    local table = commandMemory[primaryKey]
    if table then
        return table
    else
        return {}
    end
end

function MemoryAddGUIDToKey(primaryKey,guid)
    --ScenEdit_SpecialMessage("Blue Force", " - MemoryAddGUIDToKey "..primaryKey)
    local table = commandMemory[primaryKey]
    if not table then
        table = {}
    end
    table[#table + 1] = guid
    commandMemory[primaryKey] = table
end

function MemoryGUIDExists(primaryKey,guid)
    --ScenEdit_SpecialMessage("Blue Force", " - PersistentGUIDExists "..primaryKey)
    local table = MemoryGetGUIDFromKey(primaryKey)
    for k, v in pairs(table) do
        if guid == v then
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Save GUID Persistent Functions
--------------------------------------------------------------------------------------------------------------------------------
function PersistentRemoveAllGUID(primaryKey)
    --ScenEdit_SpecialMessage("Blue Force", " - PersistentRemoveAllGUID "..primaryKey)
    ScenEdit_SetKeyValue(primaryKey,"")
end

function PersistentGetGUID(primaryKey)
    --ScenEdit_SpecialMessage("Blue Force", " - PersistentGetGUID "..primaryKey)
    local guidString = ScenEdit_GetKeyValue(primaryKey)
    if guidString == nil then
        guidString = ""
    end
    return Split(guidString,",")
end

function PersistentAddGUID(primaryKey,guid)
    --ScenEdit_SpecialMessage("Blue Force", " - PersistentAddGUID "..primaryKey)
    local guidString = ScenEdit_GetKeyValue(primaryKey)
    if guidString == nil then
        guidString = guid
    else
        guidString = guidString..","..guid
    end
    ScenEdit_SetKeyValue(primaryKey,guidString)
end

function PersistentRemoveGUID(primaryKey,guid)
    --ScenEdit_SpecialMessage("Blue Force", " - PersistentRemoveGUID "..primaryKey)
    local table = PersistentGetGUID(primaryKey)
    local guidString = nil
    for k, v in pairs(table) do
        if guid ~= v then
            if guidString then
                guidString = guidString..","..v
            else
                guidString = v
            end
        end
    end
    ScenEdit_SetKeyValue(primaryKey,guidString)
end

function PersistentGUIDExists(primaryKey,guid)
    --ScenEdit_SpecialMessage("Blue Force", " - PersistentGUIDExists "..primaryKey)
    local table = PersistentGetGUID(primaryKey)
    for k, v in pairs(table) do
        if guid == v then
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Timestamp Functions
--------------------------------------------------------------------------------------------------------------------------------
function GetTimeStampForGUID(primaryKey)
    local timeStamp = ScenEdit_GetKeyValue(primaryKey)
    if timeStamp == "" or timeStamp == nil then
        ScenEdit_SetKeyValue(primaryKey,tostring(ScenEdit_CurrentTime()))
        timeStamp = ScenEdit_GetKeyValue(primaryKey)
    end
    return tonumber(timeStamp)
end

function SetTimeStampForGUID(primaryKey,time)
    ScenEdit_SetKeyValue(primaryKey,tostring(time))
end

--------------------------------------------------------------------------------------------------------------------------------
-- Determine If Unit Is In Zone - Returned Desired Retreat Point
--------------------------------------------------------------------------------------------------------------------------------
function GetAirNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,unitGuid,range)
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local hostileAirContacts = GetHostileAirContacts(shortSideKey)

    -- Zone Reference Points
    for k,v in pairs(hostileAirContacts) do
        local contact = ScenEdit_GetContact({side=side.name, guid=v})
        local currentRange = Tool_Range(contact.guid,unitGuid)
        if currentRange < range then
            local bearing = Tool_Bearing(contact.guid,unitGuid)
            local retreatLocation = ProjectLatLong(MakeLatLong(contact.latitude,contact.longitude),bearing,range + 30)
            return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=1001}
        end
    end
    -- Return 
    return nil
end

function GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    -- Local Side And Mission
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local zones = PersistentGetGUID(shortSideKey.."_sam_ex_zone")
    -- Zone Reference Points
    local zoneReferencePoints = ScenEdit_GetReferencePoints({side=side.name, area=zones})

    -- Zone Reference Points
    for k,v in pairs(zoneReferencePoints) do
        local currentRange = Tool_Range({latitude=v.latitude,longitude=v.longitude},unitGuid)
        local desiredRange = tonumber(v.name)
        if currentRange < desiredRange then
            local contactPoint = MakeLatLong(v.latitude,v.longitude)
            local bearing = Tool_Bearing({latitude=contactPoint.latitude,longitude=contactPoint.longitude},unitGuid)
            local retreatLocation = ProjectLatLong(contactPoint,bearing,tonumber(v.name)+30)
            return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=1002}
        end
    end
    -- Return False
    return nil
end

function GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    -- Local Side And Mission
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local zones = PersistentGetGUID(shortSideKey.."_ship_ex_zone")

    -- Zone Reference Points
    local zoneReferencePoints = ScenEdit_GetReferencePoints({side=side.name, area=zones})
    for k,v in pairs(zoneReferencePoints) do
        local currentRange = Tool_Range({latitude=v.latitude,longitude=v.longitude},unitGuid)
        local desiredRange = tonumber(v.name)
        if currentRange < desiredRange then
            local contactPoint = MakeLatLong(v.latitude,v.longitude)
            local bearing = Tool_Bearing({latitude=contactPoint.latitude,longitude=contactPoint.longitude},unitGuid)
            local retreatLocation = ProjectLatLong(contactPoint,bearing,tonumber(v.name)+30)
            return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=1003}
        end
    end
    -- Return nil
    return nil
end

function GetEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    -- Local Side And Mission
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local hostileMissilesContacts = GetHostileWeaponContacts(shortSideKey)
    -- Check Unit Fired On (Performance Check)
    --[[if #unit.firedOn > 0 then
        
    end]]--
    --[[if unit.firedOn then
        if #unit.firedOn > 0 then
        end
    end]]--
    for k,v in pairs(hostileMissilesContacts) do
        local currentRange = Tool_Range(v,unitGuid)
        local contact = ScenEdit_GetContact({side=side.name, guid=v})
        -- Check Between 20 and 80
        if currentRange > 20 and currentRange < 100 then
            --ScenEdit_SpecialMessage("Stennis CSG", "GetEmergencyMissileNoNavZoneThatContainsUnit")
            local contactPoint = MakeLatLong(contact.latitude,contact.longitude)
            local bearing = Tool_Bearing({latitude=contactPoint.latitude,longitude=contactPoint.longitude},unitGuid)
            local retreatLocation = ProjectLatLong(contactPoint,bearing,currentRange + 30)
            return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=2000}
        end
    end
    -- Return nil
    return nil
end

function GetSAMAndShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    local contactPoint = GetEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    if contactPoint ~= nil then
        return contactPoint
    else
        contactPoint = GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
        if contactPoint ~= nil then
            return contactPoint
        else
            return GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
        end
    end
end

function GetAirAndShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid,airRange)
    local contactPoint = GetEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    if contactPoint ~= nil then
        return contactPoint
    else
        contactPoint = GetAirNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,unitGuid,airRange)
        if contactPoint ~= nil then
            return contactPoint
        else
            return GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
        end
    end
end

function GetAirAndSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid,airRange)
    local contactPoint = GetEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    if contactPoint ~= nil then
        return contactPoint 
    else
        contactPoint = GetAirNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,unitGuid,airRange)
        if contactPoint ~= nil then
            return contactPoint
        else
            return GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
        end
    end
end

function GetAllNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid,airRange)
    local contactPoint = GetEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    if contactPoint ~= nil then
        return contactPoint
    else
        contactPoint = GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
        if contactPoint ~= nil then
            return contactPoint
        else
            contactPoint = GetAirNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,unitGuid,airRange)
            if contactPoint ~= nil then
                return contactPoint
            else
                return GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated Fighter Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirFighterInventory(sideShortKey)
    return CombineTablesNew(MemoryGetGUIDFromKey(sideShortKey.."_fig_free"),MemoryGetGUIDFromKey(sideShortKey.."_sfig_free"))
end

function GetBusyAirFighterInventory(sideShortKey)
    return CombineTablesNew(MemoryGetGUIDFromKey(sideShortKey.."_fig_busy"),MemoryGetGUIDFromKey(sideShortKey.."_sfig_busy"))
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Stealth Fighter Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirStealthInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_sfig_free")
end

function GetBusyAirStealthInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_sfig_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Multirole AA Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirMultiroleInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_mul_free")
end

function GetBusyAirMultiroleInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_mul_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Attack Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirAttackInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_atk_free")
end

function GetBusyAirAttackInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_atk_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get SEAD Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirSeadInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_sead_free")
end

function GetBusyAirSeadInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_sead_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated AEW Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirAEWInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_aew_free")
end

function GetBusyAirAEWInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_aew_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated ASuW Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirASuWInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_asuw_free")
end

function GetBusyAirASuWInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_asuw_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated ASW Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirASWInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_asw_free")
end

function GetBusyAirASWInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_asw_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated Recon Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirReconInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_rec_free")
end

function GetBusyAirReconInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_rec_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated Tanker Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirTankerInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_tan_free")
end

function GetBusyAirTankerInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_tan_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated UAV Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirUAVInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_uav_free")
end

function GetBusyAirUAVInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_uav_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated UCAV Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirUCAVInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_ucav_free")
end

function GetBusyAirUCAVInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_ucav_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated Surface Ship Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeSurfaceShipInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_surf_free")
end

function GetBusySurfaceShipInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_surf_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated Submarine Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeSubmarineInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_sub_free")
end

function GetBusySubmarineInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_sub_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Total Free Recon Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetTotalFreeReconInventory(sideShortKey)
    return CombineTablesNew(GetFreeAirReconInventory(sideShortKey),GetFreeAirUAVInventory(sideShortKey))
end

function GetTotalBusyReconInventory(sideShortKey)
    return CombineTablesNew(GetBusyAirReconInventory(sideShortKey),GetBusyAirUAVInventory(sideShortKey))
end

function GetTotalFreeBusyReconInventory(sideShortKey)
    return CombineTables(GetTotalFreeReconInventory(sideShortKey),GetTotalBusyReconInventory(sideShortKey))
end

function GetTotalFreeReconAndStealthFighterInventory(sideShortKey)
    return CombineTables(GetTotalFreeReconInventory(sideShortKey),GetFreeAirStealthInventory(sideShortKey))
end

function GetTotalFreeBusyReconAndStealthFighterInventory(sideShortKey)
    return CombineTables(GetTotalFreeBusyReconInventory(sideShortKey),GetTotalFreeBusyAirStealthFighterInventory(sideShortKey))
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Total Air Superiority Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetTotalFreeAirFighterInventory(sideShortKey)
    return CombineTablesNew(GetFreeAirFighterInventory(sideShortKey),GetFreeAirMultiroleInventory(sideShortKey))
end

function GetTotalBusyAirFighterInventory(sideShortKey)
    return CombineTablesNew(GetBusyAirFighterInventory(sideShortKey),GetBusyAirMultiroleInventory(sideShortKey))
end

function GetTotalFreeBusyAirFighterInventory(sideShortKey)
    return CombineTablesNew(GetTotalFreeAirFighterInventory(sideShortKey),GetTotalBusyAirFighterInventory(sideShortKey))
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Total Air Stealth Fighter Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetTotalFreeBusyAirStealthFighterInventory(sideShortKey)
    return CombineTablesNew(GetFreeAirStealthInventory(sideShortKey),GetBusyAirStealthInventory(sideShortKey))
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Total Air Anti-surface Ship Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetTotalFreeAirAntiSurfaceInventory(sideShortKey)
    return CombineTablesNew(GetFreeAirASuWInventory(sideShortKey),GetFreeAirMultiroleInventory(sideShortKey))
end

function GetTotalBusyAirAntiSurfaceInventory(sideShortKey)
    return CombineTablesNew(GetBusyAirASuWInventory(sideShortKey),GetBusyAirMultiroleInventory(sideShortKey))
end

function GetTotalFreeBusyAirAntiSurfaceInventory(sideShortKey)
    return CombineTablesNew(GetTotalFreeAirAntiSurfaceInventory(sideShortKey),GetTotalBusyAirAntiSurfaceInventory(sideShortKey))
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Total Air Sead Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetTotalFreeAirSeadInventory(sideShortKey)
    return CombineTablesNew(GetFreeAirSeadInventory(sideShortKey),GetFreeAirMultiroleInventory(sideShortKey))
end

function GetTotalBusyAirSeadInventory(sideShortKey)
    return CombineTablesNew(GetBusyAirSeadInventory(sideShortKey),GetBusyAirMultiroleInventory(sideShortKey))
end

function GetTotalFreeBusyAirSeadInventory(sideShortKey)
    return CombineTablesNew(GetTotalFreeAirSeadInventory(sideShortKey),GetTotalBusyAirSeadInventory(sideShortKey))
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Total Air Attack Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetTotalFreeAirAttackInventory(sideShortKey)
    return CombineTablesNew(GetFreeAirAttackInventory(sideShortKey),GetFreeAirMultiroleInventory(sideShortKey))
end

function GetTotalBusyAirAttackInventory(sideShortKey)
    return CombineTablesNew(GetBusyAirAttackInventory(sideShortKey),GetBusyAirMultiroleInventory(sideShortKey))
end

function GetTotalFreeBusyAirAttackInventory(sideShortKey)
    return CombineTablesNew(GetTotalFreeAirAttackInventory(sideShortKey),GetTotalBusyAirAttackInventory(sideShortKey))
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Total Air Tanker Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetTotalFreeBusyTankerInventory(sideShortKey)
    return CombineTablesNew(GetFreeAirTankerInventory(sideShortKey),GetBusyAirTankerInventory(sideShortKey))
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Total Air AEW Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetTotalFreeBusyAEWInventory(sideShortKey)
    return CombineTablesNew(GetFreeAirAEWInventory(sideShortKey),GetBusyAirAEWInventory(sideShortKey))
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get All Inventory
-------------------------------------------------------------------------------------------------------------------------------
function GetTotalInventory(sideShortKey)
    local totalInventory = CombineTablesNew(GetTotalFreeBusyReconInventory(sideShortKey),GetTotalFreeBusyAirFighterInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetTotalFreeBusyAirAntiSurfaceInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetTotalFreeBusyAirAttackInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetTotalFreeBusyTankerInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetTotalFreeBusyAEWInventory(sideShortKey))
    return totalInventory
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Total Inventory Strength
--------------------------------------------------------------------------------------------------------------------------------
function GetAllInventoryStrength(sideShortKey)
    local totalStrength = #GetTotalFreeBusyReconInventory(sideShortKey)
    totalStrength = totalStrength + #GetTotalFreeBusyAirFighterInventory(sideShortKey)
    totalStrength = totalStrength + #GetTotalFreeBusyAirAntiSurfaceInventory(sideShortKey)
    totalStrength = totalStrength + #GetTotalFreeBusyTankerInventory(sideShortKey)
    totalStrength = totalStrength + #GetTotalFreeBusyAEWInventory(sideShortKey)
    return totalStrength
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Contacts
--------------------------------------------------------------------------------------------------------------------------------
function GetUnknownAirContacts(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_air_con_X")
end

function GetHostileAirContacts(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_air_con_H")
end

function GetUnknownSurfaceShipContacts(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_surf_con_X")
end

function GetHostileSurfaceShipContacts(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_surf_con_H")
end

function GetUnknownSubmarineContacts(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_sub_con_X")
end

function GetHostileSubmarineContacts(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_sub_con_H")
end

function GetUnknownBaseContacts(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_base_con_X")
end

function GetHostileBaseContacts(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_base_con_H")
end

function GetUnknownSAMContacts(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_sam_con_X")
end

function GetHostileSAMContacts(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_sam_con_H")
end

function GetUnknownWeaponContacts(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_weap_con_X")
end

function GetHostileWeaponContacts(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_weap_con_H")
end

function GetUnknownLandContacts(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_land_con_X")
end

function GetHostileLandContacts(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_land_con_H")
end

function GetTotalHostileContacts(sideShortKey)
    local totalContacts = CombineTablesNew(GetHostileAirContacts(sideShortKey),GetHostileSurfaceShipContacts(sideShortKey))
    totalContacts = CombineTables(totalContacts,GetHostileSubmarineContacts(sideShortKey))
    totalContacts = CombineTables(totalContacts,GetHostileBaseContacts(sideShortKey))
    totalContacts = CombineTables(totalContacts,GetHostileSAMContacts(sideShortKey))
    totalContacts = CombineTables(totalContacts,GetHostileLandContacts(sideShortKey))
    return totalContacts
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Contact Strength
--------------------------------------------------------------------------------------------------------------------------------
function GetAllHostileContactStrength(sideShortKey)
    local totalHostileStrength = #GetHostileAirContacts(sideShortKey)
    totalHostileStrength = totalHostileStrength + #GetHostileSurfaceShipContacts(sideShortKey)
    totalHostileStrength = totalHostileStrength + #GetHostileSubmarineContacts(sideShortKey)
    return totalHostileStrength
end

function GetHostileAirContactsStrength(sideShortKey)
    return #GetHostileAirContacts(sideShortKey)
end

function GetHostileSurfaceShipContactsStrength(sideShortKey)
    return #GetHostileSurfaceShipContacts(sideShortKey)
end

function GetHostileSAMContactsStrength(sideShortKey)
    return #GetHostileSAMContacts(sideShortKey)
end

function GetHostileLandContactsStrength(sideShortKey)
    return #GetHostileLandContacts(sideShortKey)
end

--------------------------------------------------------------------------------------------------------------------------------
-- Area of Operation Functions
--------------------------------------------------------------------------------------------------------------------------------
function UpdateAIAreaOfOperations(sideGUID,sideShortKey)
    -- Local Values
    local side = VP_GetSide({guid=sideGUID})
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local coordinates = {}
    local boundingBox = {}
    local currentTime = ScenEdit_CurrentTime()
    local lastTime = GetTimeStampForGUID(sideShortKey.."_ao_recalc_ts")
    
    -- Area Of Operation Points Check And Create Area Of Operation Points
    if #aoPoints < 4 or (currentTime - lastTime) > 5 * 60 then 
        -- Set Contact Bounding Box Variables
        local hostileContacts = GetTotalHostileContacts(sideShortKey)
        local inventory = GetTotalInventory(sideShortKey)

        -- Loop and Get Coordinates
        for k,v in pairs(hostileContacts) do
            local contact = ScenEdit_GetContact({side=side.name, guid=v})
            coordinates[#coordinates + 1] = MakeLatLong(contact.latitude,contact.longitude)
        end

        for k,v in pairs(inventory) do
            local unit = ScenEdit_GetUnit({side=side.name, guid=v})
            coordinates[#coordinates + 1] = MakeLatLong(unit.latitude,unit.longitude)
        end

        -- Create Defense Bounding Box
        boundingBox = FindBoundingBoxForGivenLocations(coordinates,3)

        -- Create Area of Operations Zone
        for i = 1,#boundingBox do
            local referencePoint = ScenEdit_SetReferencePoint({side=side.name, name="AI-AO-"..tostring(i), lat=boundingBox[i].latitude, lon=boundingBox[i].longitude})
            if referencePoint == nil then
                ScenEdit_AddReferencePoint({side=side.name, name="AI-AO-"..tostring(i), lat=boundingBox[i].latitude, lon=boundingBox[i].longitude})
            end
        end
        
        -- Set Time Stamp To Recalculate
        SetTimeStampForGUID(sideShortKey.."_ao_recalc_ts",ScenEdit_CurrentTime())
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Inventory Functions
--------------------------------------------------------------------------------------------------------------------------------
function UpdateAIInventories(sideGUID,sideShortKey)
    -- Local Variables
    local side = VP_GetSide({guid=sideGUID})
    local aircraftInventory = side:unitsBy("1")
    local shipInventory = side:unitsBy("2")
    local submarineInventory = side:unitsBy("3")
    local landInventory = side:unitsBy("4")
    local aircraftContacts = side:contactsBy("1")
    local shipContacts = side:contactsBy("2")
    local submarineContacts = side:contactsBy("3")
    local landContacts = side:contactsBy("4")
    local weaponContacts = side:contactsBy("6")

    -- Rest Inventories And Contacts
    ResetInventoriesAndContacts(sideShortKey)

    -- Loop Through Aircraft Inventory By Subtypes And Readiness
    if aircraftInventory then
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
            else 
                break
            end

            -- Fighter
            if unit.subtype == "2001" then
                unitType = DetermineRoleFromLoadOutDatabase(unit.loadoutdbid,"fig")
            -- Multirole
            elseif unit.subtype == "2002" then
                unitType = DetermineRoleFromLoadOutDatabase(unit.loadoutdbid,"mul")
            -- Attacker
            elseif unit.subtype == "3001" then
                unitType = DetermineRoleFromLoadOutDatabase(unit.loadoutdbid,"atk")
            -- SEAD
            elseif unit.subtype == "4001" then
                unitType = DetermineRoleFromLoadOutDatabase(unit.loadoutdbid,"sead")
            -- AEW
            elseif unit.subtype == "4002" then
                unitType = DetermineRoleFromLoadOutDatabase(unit.loadoutdbid,"aew")
            -- ASW
            elseif unit.subtype == "6002" then
                unitType = DetermineRoleFromLoadOutDatabase(unit.loadoutdbid,"asw")
            -- Recon
            elseif unit.subtype == "7003" then
                unitType = DetermineRoleFromLoadOutDatabase(unit.loadoutdbid,"rec")
            -- Tanker
            elseif unit.subtype == "8001" then
                unitType = DetermineRoleFromLoadOutDatabase(unit.loadoutdbid,"tan")
            -- UAV
            elseif unit.subtype == "8201" then
                unitType = DetermineRoleFromLoadOutDatabase(unit.loadoutdbid,"uav")
            -- UCAV
            elseif unit.subtype == "8002" then
                unitType = DetermineRoleFromLoadOutDatabase(unit.loadoutdbid,"ucav")
            end

            MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..unitStatus,unit.guid)
        end
    end

    -- Loop Through Surface Ship Inventory
    if shipInventory then
        for k, v in pairs(shipInventory) do
            -- Local Values
            local unit = ScenEdit_GetUnit({side=side.name, guid=v.guid})
            local unitType = "surf"
            local unitStatus = "busy"

            -- Check Status
            if unit.mission == nil then
                unitStatus = "free"
            end

            -- Save Unit As HVT (Carriers)
            if unit.subtype == "2001" or unit.subtype == "2008"then
                MemoryAddGUIDToKey(sideShortKey.."_def_hvt",unit.guid)
            end

            -- Save Unit GUID
            MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..unitStatus,unit.guid)
        end
    end

    -- Loop Through Submarine Inventory
    if submarineInventory then
        for k, v in pairs(submarineInventory) do
            -- Local Values
            local unit = ScenEdit_GetUnit({side=side.name, guid=v.guid})
            local unitType = "sub"
            local unitStatus = "busy"

            -- Check Status
            if unit.mission == nil then
                unitStatus = "free"
            end

            -- Save Unit GUID
            MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..unitStatus,unit.guid)
        end
    end

    -- Loop Through Land Inventory
    if landInventory then
        for k, v in pairs(landInventory) do
            -- Local Values
            local unit = ScenEdit_GetUnit({side=side.name, guid=v.guid})
            local unitType = "land"
            local unitStatus = "busy"

            -- Check Status
            if unit.mission == nil then
                unitStatus = "free"
            end

            -- Save Unit As HVT (Airport)
            if unit.subtype == "9001" then
                unitType = "base"
                MemoryAddGUIDToKey(sideShortKey.."_def_hvt",unit.guid)
            elseif unit.subtype == "5001" then
                unitType = "sam"
            end

            -- Save Unit GUID
            MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..unitStatus,unit.guid)
        end
    end

    -- Loop Through Aircraft Contacts
    if aircraftContacts then
        for k, v in pairs(aircraftContacts) do
            -- Local Values
            local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
            local unitType = "air_con"

            -- Save Unit GUID
            MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
        end
    end

    -- Loop Through Aircraft Contacts
    if shipContacts then
        for k, v in pairs(shipContacts) do
            -- Local Values
            local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
            local unitType = "surf_con"

            -- Save Unit GUID
            MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
        end
    end

    -- Loop Through Aircraft Contacts
    if submarineContacts then
        for k, v in pairs(submarineContacts) do
            -- Local Values
            local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
            local unitType = "sub_con"

            -- Save Unit GUID
            MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
        end
    end

    -- Loop Through Land Contacts
    if landContacts then
        for k, v in pairs(landContacts) do
            -- Local Values
            local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
            local unitType = "land_con"

            -- Check
            if string.find(contact.type_description,"SAM") then
                unitType = "sam_con"
            end

            -- Save Unit GUID
            MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
        end
    end

    -- Loop Through Weapon Contacts
    if weaponContacts then
        for k, v in pairs(weaponContacts) do
            -- Local Values
            local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
            local unitType = "weap_con"

            -- Filter Out By Weapon Speed
            if contact.speed then
                if  contact.speed < 1500 then
                    break
                end
            end
            -- Save Unit GUID
            MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
        end
    end
end

function ResetInventoriesAndContacts(sideShortKey)
    -- Memory Clean
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_non_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_non_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_non_unav")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_def_hvt")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_sfig_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_sfig_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_fig_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_fig_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_mul_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_mul_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_atk_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_atk_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_sead_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_sead_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_aew_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_aew_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_asw_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_asw_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_asuw_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_asuw_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_rec_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_rec_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_tan_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_tan_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_uav_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_uav_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_ucav_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_ucav_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_surf_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_surf_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_sub_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_sub_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_land_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_land_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_base_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_base_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_sam_busy")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_sam_free")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_air_con_X")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_air_con_H")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_surf_con_X")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_surf_con_H")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_sub_con_X")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_sub_con_H")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_land_con_X")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_land_con_H")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_base_con_X")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_base_con_H")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_sam_con_X")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_sam_con_H")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_weap_con_X")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_weap_con_H")
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_alloc_units")

end

--------------------------------------------------------------------------------------------------------------------------------
-- Offensive Conditional Check
--------------------------------------------------------------------------------------------------------------------------------
function OffensiveConditionalCheck(args)
    --return false
    if GetAllHostileContactStrength(args.shortKey) <= GetAllInventoryStrength(args.shortKey) then
        --ScenEdit_SpecialMessage("Neutral", "OffensiveConditionalCheck - True")
        return true
    else
        --ScenEdit_SpecialMessage("Neutral", "OffensiveConditionalCheck - False")
        return false
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Defensive Conditional Check
--------------------------------------------------------------------------------------------------------------------------------
function DefensiveConditionalCheck(args)
    --return true
    if GetAllHostileContactStrength(args.shortKey) > GetAllInventoryStrength(args.shortKey) then
        --ScenEdit_SpecialMessage("Neutral", "DefensiveConditionalCheck - True")
        return true
    else
        --ScenEdit_SpecialMessage("Neutral", "DefensiveConditionalCheck - False")
        return false
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Recon Doctrine Create Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function ReconDoctrineCreateMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local missions = PersistentGetGUID(args.shortKey.."_rec_miss")
    local totalFreeInventory = GetTotalFreeReconAndStealthFighterInventory(args.shortKey)
    local missionNumber = math.random(4)
    local rp1,rp2,rp3,rp4 = ""
    -- Limit To Four Missions, When 0 Contacts And Has Air Recon Inventory
    if #missions >= 4 or #totalFreeInventory == 0 or GetAllHostileContactStrength(args.shortKey) >= 10 then
        return false
    end
    ScenEdit_SpecialMessage("Blue Force", args.shortKey.."ReconDoctrineCreateMissionAction")
    -- Get A Non Repeating Number
    while PersistentGUIDExists(args.shortKey.."_rec_miss",args.shortKey.."_rec_miss_"..tostring(missionNumber)) do
        missionNumber = math.random(4)
    end
    -- Set Reference Points
    if missionNumber == 1 then
        rp1rp2mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[2].latitude,aoPoints[2].longitude)
        rp1rp3mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
        rp1rp4mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
        rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=aoPoints[1].latitude, lon=aoPoints[1].longitude})
        rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=rp1rp2mid.latitude, lon=rp1rp2mid.longitude})
        rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
        rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=rp1rp4mid.latitude, lon=rp1rp4mid.longitude})
    elseif missionNumber == 2 then
        rp1rp2mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[2].latitude,aoPoints[2].longitude)
        rp2rp3mid = MidPointCoordinate(aoPoints[2].latitude,aoPoints[2].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
        rp1rp3mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
        rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=rp1rp2mid.latitude, lon=rp1rp2mid.longitude})
        rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=aoPoints[2].latitude, lon=aoPoints[2].longitude})
        rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=rp2rp3mid.latitude, lon=rp2rp3mid.longitude})
        rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
    elseif missionNumber == 3 then
        rp1rp3mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
        rp2rp3mid = MidPointCoordinate(aoPoints[2].latitude,aoPoints[2].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
        rp3rp4mid = MidPointCoordinate(aoPoints[3].latitude,aoPoints[3].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
        rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
        rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=rp2rp3mid.latitude, lon=rp2rp3mid.longitude})
        rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=aoPoints[3].latitude, lon=aoPoints[3].longitude})
        rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=rp3rp4mid.latitude, lon=rp3rp4mid.longitude})
    else
        rp1rp4mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
        rp1rp3mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
        rp3rp4mid = MidPointCoordinate(aoPoints[3].latitude,aoPoints[3].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
        rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=rp1rp4mid.latitude, lon=rp1rp4mid.longitude})
        rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
        rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=rp3rp4mid.latitude, lon=rp3rp4mid.longitude})
        rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=aoPoints[4].latitude, lon=aoPoints[4].longitude})
    end
    -- Create Mission
    local createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_rec_miss_"..tostring(missionNumber),"patrol",{type="naval",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true})
    ScenEdit_SetDoctrine({side=side.name,mission=createdMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb ="0",dive_on_threat="2"})
    --ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Passive")
    -- Determine Units To Assign
    DetermineUnitsToAssign(args.shortKey,side.name,createdMission.guid,1,totalFreeInventory)
    -- Add Guid
    PersistentAddGUID(args.shortKey.."_rec_miss",createdMission.name)
    -- Return True
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Recon Doctrine Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function ReconDoctrineUpdateMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_rec_miss")
    local totalFreeBusyInventory = GetTotalFreeBusyReconAndStealthFighterInventory(args.shortKey)
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local missionNumber = 0
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    -- Check Total Is Zero
    if #missions == 0 then
        return false
    end
    -- Loop Through Existing Missions
    for k, v in pairs(missions) do
        -- Local Values
        local updatedMission = ScenEdit_GetMission(side.name,v)
        local defensiveBoundingBox = {}
        local rp1,rp2,rp3,rp4 = ""
        -- Assign Units To Recon Mission
        local totalReconUnitsToAssign = 1
        local numberOfReconToAssign = #totalFreeBusyInventory
        missionNumber = missionNumber + 1
        -- Update Reference Points (AO Change)
        if missionNumber == 1 then
            rp1rp2mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[2].latitude,aoPoints[2].longitude)
            rp1rp3mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
            rp1rp4mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=aoPoints[1].latitude, lon=aoPoints[1].longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=rp1rp2mid.latitude, lon=rp1rp2mid.longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=rp1rp4mid.latitude, lon=rp1rp4mid.longitude})
        elseif missionNumber == 2 then
            rp1rp2mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[2].latitude,aoPoints[2].longitude)
            rp2rp3mid = MidPointCoordinate(aoPoints[2].latitude,aoPoints[2].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
            rp1rp3mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=rp1rp2mid.latitude, lon=rp1rp2mid.longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=aoPoints[2].latitude, lon=aoPoints[2].longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=rp2rp3mid.latitude, lon=rp2rp3mid.longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
        elseif missionNumber == 3 then
            rp1rp3mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
            rp2rp3mid = MidPointCoordinate(aoPoints[2].latitude,aoPoints[2].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
            rp3rp4mid = MidPointCoordinate(aoPoints[3].latitude,aoPoints[3].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=rp2rp3mid.latitude, lon=rp2rp3mid.longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=aoPoints[3].latitude, lon=aoPoints[3].longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=rp3rp4mid.latitude, lon=rp3rp4mid.longitude})
        else
            rp1rp4mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
            rp1rp3mid = MidPointCoordinate(aoPoints[1].latitude,aoPoints[1].longitude,aoPoints[3].latitude,aoPoints[3].longitude)
            rp3rp4mid = MidPointCoordinate(aoPoints[3].latitude,aoPoints[3].longitude,aoPoints[4].latitude,aoPoints[4].longitude)
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_1", lat=rp1rp4mid.latitude, lon=rp1rp4mid.longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_2", lat=rp1rp3mid.latitude, lon=rp1rp3mid.longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_3", lat=rp3rp4mid.latitude, lon=rp3rp4mid.longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_recon_miss_"..tostring(missionNumber).."_rp_4", lat=aoPoints[4].latitude, lon=aoPoints[4].longitude})
        end
        -- Determine Units To Assign
        DetermineUnitsToAssign(args.shortKey,side.name,updatedMission.guid,1,totalFreeBusyInventory)
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Create Update Air Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineCreateUpdateAirMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_aaw_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeInventory = GetTotalFreeAirFighterInventory(args.shortKey)
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local totalAirUnitsToAssign = GetHostileAirContactsStrength(args.shortKey) * 3
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactBoundingBox = {}
    local createdUpdatedMission = {}
    -- Condition Check
    hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)
    -- Create Mission
    if #missions == 0 then
        -- Add Reference Points
        rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        -- Created Mission
        createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_aaw_miss_"..tostring(missionNumber),"patrol",{type="aaw",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
        ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=true,flightSize=2,useFlightSize=true})
        ScenEdit_SetDoctrine({side=side.name,mission=createdUpdatedMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb ="1",dive_on_threat="2"})
        -- Add Guid
        PersistentAddGUID(args.shortKey.."_aaw_miss",createdUpdatedMission.name)
    else
        -- Set Reference Points
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})    
        -- Updated Mission
        createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
        -- Round Up
        if totalAirUnitsToAssign % 2 == 1 then
            totalAirUnitsToAssign = totalAirUnitsToAssign + 1
        end
        -- Determine Units To Assign
        DetermineUnitsToAssign(args.shortKey,side.name,createdUpdatedMission.guid,totalAirUnitsToAssign,totalFreeInventory)
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Create Update Stealth Air Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineCreateUpdateStealthAirMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_saaw_miss")
    local linkedMissions = PersistentGetGUID(args.shortKey.."_aaw_miss")
    local totalFreeInventory = GetFreeAirStealthInventory(args.shortKey)
    local totalAirUnitsToAssign = GetHostileAirContactsStrength(args.shortKey)
    local missionNumber = 1
    local createdUpdatedMission = {}
    local linkedMission = {}
    local linkedMissionPoints = {}
    -- Condition Check
    if #linkedMissions > 0 then
        -- Get Linked Mission
        linkedMission = ScenEdit_GetMission(side.name,linkedMissions[1])
        linkedMissionPoints = {linkedMission.name.."_rp_1",linkedMission.name.."_rp_2",linkedMission.name.."_rp_3",linkedMission.name.."_rp_4"}
        -- Add Missions
        if #missions == 0 then
            -- Create Mission
            createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_saaw_miss_"..tostring(missionNumber),"patrol",{type="aaw",zone=linkedMissionPoints})
            ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=true,flightSize=2,useFlightSize=true})
            ScenEdit_SetDoctrine({side=side.name,mission=createdUpdatedMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb ="0"})
            --ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Passive")
            -- Add Guid And Add Time Stamp
            PersistentAddGUID(args.shortKey.."_saaw_miss",createdUpdatedMission.name)
        else
            -- Updated Mission
            createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
            -- Total Units        
            totalAirUnitsToAssign = math.floor(#(linkedMission.unitlist)/4)
            -- Round Up
            if totalAirUnitsToAssign % 2 == 1 then
                totalAirUnitsToAssign = totalAirUnitsToAssign + 1
            end
            -- Determine Units To Assign
            DetermineUnitsToAssign(args.shortKey,side.name,createdUpdatedMission.guid,totalAirUnitsToAssign,totalFreeInventory)
        end
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Create Update AEW Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineCreateUpdateAEWMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_aaew_miss")
    local linkedMissions = PersistentGetGUID(args.shortKey.."_aaw_miss")
    local totalFreeInventory = GetFreeAirAEWInventory(args.shortKey)
    local totalFreeBusyInventory = GetTotalFreeBusyAEWInventory(args.shortKey)
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local createdUpdatedMission = {}
    local linkedMission = {}
    local linkedMissionPoints = {}
    local linkedMissionCenterPoint = {}
    local patrolBoundingBox = {}
    -- Condition Check
    if #linkedMissions > 0 then
        -- Get Linked Mission
        linkedMission = ScenEdit_GetMission(side.name,linkedMissions[1])
        linkedMissionPoints = ScenEdit_GetReferencePoints({side=side.name, area={linkedMission.name.."_rp_1",linkedMission.name.."_rp_2",linkedMission.name.."_rp_3",linkedMission.name.."_rp_4"}})
        linkedMissionCenterPoint = MidPointCoordinate(linkedMissionPoints[1].latitude,linkedMissionPoints[1].longitude,linkedMissionPoints[3].latitude,linkedMissionPoints[3].longitude)
        patrolBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(linkedMissionCenterPoint.latitude,linkedMissionCenterPoint.longitude)},1.0)
        -- Add Missions
        if #missions == 0 then
            -- Set Reference Points
            rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_1", lat=patrolBoundingBox[1].latitude, lon=patrolBoundingBox[1].longitude})
            rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_2", lat=patrolBoundingBox[2].latitude, lon=patrolBoundingBox[2].longitude})
            rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_3", lat=patrolBoundingBox[3].latitude, lon=patrolBoundingBox[3].longitude})
            rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_4", lat=patrolBoundingBox[4].latitude, lon=patrolBoundingBox[4].longitude})
            -- Create Mission
            createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_aaew_miss_"..tostring(missionNumber),"support",{zone={rp1.name,rp2.name,rp3.name,rp4.name}})
            ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Active")
            -- Add Guid And Add Time Stamp
            PersistentAddGUID(args.shortKey.."_aaew_miss",createdUpdatedMission.name)
        else
            -- Get Linked Mission
            createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
            -- Set Reference Points
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_1", lat=patrolBoundingBox[1].latitude, lon=patrolBoundingBox[1].longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_2", lat=patrolBoundingBox[2].latitude, lon=patrolBoundingBox[2].longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_3", lat=patrolBoundingBox[3].latitude, lon=patrolBoundingBox[3].longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaew_miss_"..tostring(missionNumber).."_rp_4", lat=patrolBoundingBox[4].latitude, lon=patrolBoundingBox[4].longitude})
            -- Determine Units To Assign
            DetermineUnitsToAssign(args.shortKey,side.name,createdUpdatedMission.guid,1,totalFreeBusyInventory)
        end
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Create Update Anti Surface Ship Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineCreateUpdateAntiSurfaceShipMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_asuw_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeInventory = GetFreeAirASuWInventory(args.shortKey)
    local totalFreeBusyInventory = GetTotalFreeBusyAirAntiSurfaceInventory(args.shortKey)
    local totalHostileContacts = GetHostileSurfaceShipContacts(args.shortKey)
    local totalAirUnitsToAssign = GetHostileSurfaceShipContactsStrength(args.shortKey) * 4
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)
    local createdUpdatedMission = {}
    -- Condition Check
    if #missions == 0 then
        -- Set Reference Points
        rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        -- Create Mission
        createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_asuw_miss_"..tostring(missionNumber),"patrol",{type="naval",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
        ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=false,flightSize=2,useFlightSize=true})
        ScenEdit_SetDoctrine({side=side.name,mission=createdUpdatedMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb="1",fuel_state_rtb="2",dive_on_threat="2"})
        --ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Active")
        -- Add Guid And Add Time Stamp
        PersistentAddGUID(args.shortKey.."_asuw_miss",createdUpdatedMission.name)
    else
        -- Take First One For Now
        createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
        -- Set Coordinates
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        -- Determine Units To Assign
        DetermineUnitsToAssign(args.shortKey,side.name,createdUpdatedMission.guid,totalAirUnitsToAssign,totalFreeBusyInventory)
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Create Update Sead Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineCreateUpdateSeadMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_sead_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeBusyInventory = GetTotalFreeBusyAirSeadInventory(args.shortKey)
    local totalHostileContacts = GetHostileSAMContacts(args.shortKey)
    local totalAirUnitsToAssign = GetHostileSAMContactsStrength(args.shortKey) * 4
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,4)
    local createdUpdatedMission = {}
    -- Condition Check
    if #missions == 0 then
        -- Set Reference Points
        rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        -- Create Mission
        createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_sead_miss_"..tostring(missionNumber),"patrol",{type="sead",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
        ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=false,flightSize=2,useFlightSize=true})
        --ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Passive")
        -- Add Guid
        PersistentAddGUID(args.shortKey.."_sead_miss",createdUpdatedMission.name)
    else
        -- Take First One For Now
        createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
        -- Update Every 5 Minutes Or Greater
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        -- Determine Units To Assign
        DetermineUnitsToAssign(args.shortKey,side.name,createdUpdatedMission.guid,totalAirUnitsToAssign,totalFreeBusyInventory)
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Create Update Land Attack Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineCreateUpdateLandAttackMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_land_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeBusyInventory = GetTotalFreeBusyAirAttackInventory(args.shortKey)
    local totalHostileContacts = GetHostileLandContacts(args.shortKey)
    local totalAirUnitsToAssign = GetHostileLandContactsStrength(args.shortKey) * 2
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)
    local createdUpdatedMission = {}
    -- Condition Check
    if #missions == 0 then
        -- Set Reference Points
        rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        -- Create Mission
        createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_land_miss_"..tostring(missionNumber),"patrol",{type="land",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
        ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=false,flightSize=2,useFlightSize=true})
        --ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Passive")
        -- Add Guid
        PersistentAddGUID(args.shortKey.."_land_miss",createdUpdatedMission.name)
    else
        -- Take First One For Now
        createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
        -- Update Every 5 Minutes Or Greater
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
        ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})
        -- Determine Units To Assign
        DetermineUnitsToAssign(args.shortKey,side.name,createdUpdatedMission.guid,totalAirUnitsToAssign,totalFreeBusyInventory)
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Defend Doctrine Create Update Air Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function DefendDoctrineCreateUpdateAirMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_aaw_d_miss")
    local createdMission = {}
    local updatedMission = {}
    -- Boxes And Coordinates
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local defenseBoundingBox = {}
    local rp1,rp2,rp3,rp4 = ""
    -- Inventory And HVT And Contacts
    local totalFreeInventory = GetTotalFreeAirFighterInventory(args.shortKey)
    local totalFreeBusyInventory = GetTotalFreeBusyAirFighterInventory(args.shortKey)
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local totalHVTs = MemoryGetGUIDFromKey(args.shortKey.."_def_hvt")
    local coveredHVTs = PersistentGetGUID(args.shortKey.."_def_hvt_cov")
    local unitToDefend = nil
    local totalAAWUnitsToAssign = 4
    -- Condition Check
    if #coveredHVTs < #totalHVTs then
        -- Find Unit That Is Not Covered
        for k, v in pairs(totalHVTs) do
            local found = false
            for k2, v2 in pairs(coveredHVTs) do 
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
            defenseBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(unitToDefend.latitude,unitToDefend.longitude)},2.5)
            -- Set Reference Points
            rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_rp_1", lat=defenseBoundingBox[1].latitude, lon=defenseBoundingBox[1].longitude})
            rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_rp_2", lat=defenseBoundingBox[2].latitude, lon=defenseBoundingBox[2].longitude})
            rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_rp_3", lat=defenseBoundingBox[3].latitude, lon=defenseBoundingBox[3].longitude})
            rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_rp_4", lat=defenseBoundingBox[4].latitude, lon=defenseBoundingBox[4].longitude})
            -- Create Mission
            createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_aaw_d_miss_"..unitToDefend.guid,"patrol",{type="aaw",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
            ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=false,flightSize=2,useFlightSize=true})
            ScenEdit_SetDoctrine({side=side.name,mission=createdMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb ="1",dive_on_threat="2"})
            --ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Passive")
            -- Add Guid And Add Time Stamp
            PersistentAddGUID(args.shortKey.."_aaw_d_miss",createdMission.name)
            PersistentAddGUID(args.shortKey.."_def_hvt_cov",unitToDefend.guid)
        end
    end
    -- Update Mission
    for k, v in pairs(coveredHVTs) do
        -- Local Covered HVT
        local coveredHVT = ScenEdit_GetUnit({side=side.name,guid=v})
        -- Check Condition
        if coveredHVT then
            -- Get Defense Mission
            updatedMission = ScenEdit_GetMission(side.name,args.shortKey.."_aaw_d_miss_"..coveredHVT.guid)
            -- Check Defense Mission
            if updatedMission then
                -- Set Contact Bounding Box Variables
                defenseBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(coveredHVT.latitude,coveredHVT.longitude)},2.5)
                -- Update Coordinates
                rp1 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVT.guid.."_rp_1", lat=defenseBoundingBox[1].latitude, lon=defenseBoundingBox[1].longitude})
                rp2 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVT.guid.."_rp_2", lat=defenseBoundingBox[2].latitude, lon=defenseBoundingBox[2].longitude})
                rp3 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVT.guid.."_rp_3", lat=defenseBoundingBox[3].latitude, lon=defenseBoundingBox[3].longitude})
                rp4 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..coveredHVT.guid.."_rp_4", lat=defenseBoundingBox[4].latitude, lon=defenseBoundingBox[4].longitude})
                -- Find Enemy Strength In Area
                for k1, v1 in pairs(totalHostileContacts) do
                    local contact = ScenEdit_GetContact({side=side.name, guid=v1})
                    if contact:inArea({rp1.name,rp2.name,rp3.name,rp4.name}) then
                        totalAAWUnitsToAssign = totalAAWUnitsToAssign + 1
                    end
                end
                -- Determine Units To Assign
                DetermineUnitsToAssign(args.shortKey,side.name,updatedMission.guid,totalAAWUnitsToAssign,totalFreeBusyInventory)
            end
        end
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Support Tanker Doctrine Create Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function SupportTankerDoctrineCreateUpdateMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_tan_sup_miss")
    local createdMission = nil
    local updatedMission = nil
    -- Boxes And Coordinates
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local rp1,rp2,rp3,rp4 = nil
    local supportBoundingBox = {}
    -- Inventory And HVT And Contacts
    local totalFreeInventory = GetFreeAirTankerInventory(args.shortKey)
    local totalBusyFreeInventory = GetTotalFreeBusyTankerInventory(args.shortKey)
    local totalHVTs = MemoryGetGUIDFromKey(args.shortKey.."_def_hvt")
    local coveredHVTs = PersistentGetGUID(args.shortKey.."_def_tan_hvt_cov")
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local unitToSupport = nil
    -- Condition Check
    if #coveredHVTs < #totalHVTs then
        -- Find Unit That Is Not Covered
        for k, v in pairs(totalHVTs) do
            local found = false
            for k2, v2 in pairs(coveredHVTs) do 
                if v == v2 then
                    found = true
                end
            end
            if not found then
                unitToSupport = ScenEdit_GetUnit({side=side.name, guid=v})
                break
            end
        end
        -- Check If No Unit To Defend
        if unitToSupport then
            -- Set Contact Bounding Box Variables
            defenseBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(unitToSupport.latitude,unitToSupport.longitude)},1)
            -- Set Reference Points
            rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_tan_sup_miss_"..unitToSupport.guid.."_rp_1", lat=defenseBoundingBox[1].latitude, lon=defenseBoundingBox[1].longitude})
            rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_tan_sup_miss_"..unitToSupport.guid.."_rp_2", lat=defenseBoundingBox[2].latitude, lon=defenseBoundingBox[2].longitude})
            rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_tan_sup_miss_"..unitToSupport.guid.."_rp_3", lat=defenseBoundingBox[3].latitude, lon=defenseBoundingBox[3].longitude})
            rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_tan_sup_miss_"..unitToSupport.guid.."_rp_4", lat=defenseBoundingBox[4].latitude, lon=defenseBoundingBox[4].longitude})
            -- Create Mission
            createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_tan_sup_miss_"..unitToSupport.guid,"support",{zone={rp1.name,rp2.name,rp3.name,rp4.name}})
            ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Passive")
            -- Add Guid And Add Time Stamp
            PersistentAddGUID(args.shortKey.."_tan_sup_miss",createdMission.name)
            PersistentAddGUID(args.shortKey.."_def_tan_hvt_cov",unitToSupport.guid)
        end
    end
    -- Loop Through Coverted HVTs Missions
    for k, v in pairs(coveredHVTs) do
        -- Local Covered HVT
        local coveredHVT = ScenEdit_GetUnit({side=side.name,guid=v})
        -- Check Condition
        if coveredHVT then
            -- Updated Mission
            updatedMission = ScenEdit_GetMission(side.name,args.shortKey.."_tan_sup_miss_"..coveredHVT.guid)
            -- Check Defense Mission
            if updatedMission then
                -- Determine Units To Assign
                DetermineUnitsToAssign(args.shortKey,side.name,updatedMission.guid,1,totalBusyFreeInventory)
            end
        end
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Support AEW Doctrine Create Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function SupportAEWDoctrineCreateUpdateMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_aew_sup_miss")
    local createdMission = nil
    local updatedMission = nil
    -- Boxes And Coordinates
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local rp1,rp2,rp3,rp4 = nil
    local supportBoundingBox = {}
    -- Inventory And HVT And Contacts
    local totalFreeInventory = GetFreeAirAEWInventory(args.shortKey)
    local totalBusyFreeInventory = GetTotalFreeBusyAEWInventory(args.shortKey)
    local totalHVTs = MemoryGetGUIDFromKey(args.shortKey.."_def_hvt")
    local coveredHVTs = PersistentGetGUID(args.shortKey.."_def_aew_hvt_cov")
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local unitToSupport = nil
    -- Condition Check
    if #coveredHVTs < #totalHVTs then
        -- Find Unit That Is Not Covered
        for k, v in pairs(totalHVTs) do
            local found = false
            for k2, v2 in pairs(coveredHVTs) do 
                if v == v2 then
                    found = true
                end
            end
            if not found then
                unitToSupport = ScenEdit_GetUnit({side=side.name, guid=v})
                break
            end
        end
        -- Check If No Unit To Defend
        if unitToSupport then
            -- Set Contact Bounding Box Variables
            defenseBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(unitToSupport.latitude,unitToSupport.longitude)},1)
            -- Set Reference Points
            rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aew_sup_miss_"..unitToSupport.guid.."_rp_1", lat=defenseBoundingBox[1].latitude, lon=defenseBoundingBox[1].longitude})
            rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aew_sup_miss_"..unitToSupport.guid.."_rp_2", lat=defenseBoundingBox[2].latitude, lon=defenseBoundingBox[2].longitude})
            rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aew_sup_miss_"..unitToSupport.guid.."_rp_3", lat=defenseBoundingBox[3].latitude, lon=defenseBoundingBox[3].longitude})
            rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aew_sup_miss_"..unitToSupport.guid.."_rp_4", lat=defenseBoundingBox[4].latitude, lon=defenseBoundingBox[4].longitude})
            -- Create Mission
            createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_aew_sup_miss_"..unitToSupport.guid,"support",{zone={rp1.name,rp2.name,rp3.name,rp4.name}})
            ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Active")
            -- Add Guid And Add Time Stamp
            PersistentAddGUID(args.shortKey.."_aew_sup_miss",createdMission.name)
            PersistentAddGUID(args.shortKey.."_def_aew_hvt_cov",unitToSupport.guid)
        end
    else
        -- Loop Through Coverted HVTs Missions
        for k, v in pairs(coveredHVTs) do
            -- Local Covered HVT
            local coveredHVT = ScenEdit_GetUnit({side=side.name,guid=v})
            -- Check Condition
            if coveredHVT then
                updatedMission = ScenEdit_GetMission(side.name,args.shortKey.."_aew_sup_miss_"..coveredHVT.guid)
                -- Check Defense Mission
                if updatedMission then
                    -- Determine Units To Assign
                    DetermineUnitsToAssign(args.shortKey,side.name,updatedMission.guid,1,totalBusyFreeInventory)
                end
            end
        end
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Monitor Create SAM No Nav Zones Action
--------------------------------------------------------------------------------------------------------------------------------
function MonitorCreateSAMNoNavZonesAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local zones = PersistentGetGUID(args.shortKey.."_sam_ex_zone")
    -- Inventory And HVT And Contacts
    local totalHostileContacts = GetHostileSAMContacts(args.shortKey)
    -- Zones
    local noNavZoneBoundary = {}
    local zoneNumber = #zones + 1
    -- Condition Check
    if #zones >= 25 or #totalHostileContacts == 0 or #zones >= #totalHostileContacts then
       return false 
    end
    -- Get Contact
    local contact = ScenEdit_GetContact({side=side.name, guid=totalHostileContacts[#zones + 1]})
    local noNavZoneRange = DetermineThreatRangeByUnitDatabaseId(args.guid,contact.guid)
    -- SAM Zone + Range
    local referencePoint = ScenEdit_AddReferencePoint({side=side.name,lat=contact.latitude,lon=contact.longitude,name=tostring(noNavZoneRange),highlighted="no"})
    PersistentAddGUID(args.shortKey.."_sam_ex_zone",referencePoint.guid)
    -- Return True
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Monitor Update SAM No Nav Zones Action
--------------------------------------------------------------------------------------------------------------------------------
function MonitorUpdateSAMNoNavZonesAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local zones = PersistentGetGUID(args.shortKey.."_sam_ex_zone")
    -- Inventory And HVT And Contacts
    local totalHostileContacts = GetHostileSAMContacts(args.shortKey)
    local zoneCounter = 1
    -- Condition Check
    if #zones == 0 then
       return false 
    end
    -- Key Value Pairs
    for k,v in pairs(zones) do
        local referencePoints = ScenEdit_GetReferencePoints({side=side.name,area={v}})
        local referencePoint = referencePoints[1]

        if zoneCounter > #totalHostileContacts then
            ScenEdit_SetReferencePoint({side=side.name, guid=v, newname="0", lat=0, long=0})
        else
            -- Get Contact
            local contact = ScenEdit_GetContact({side=side.name, guid=totalHostileContacts[zoneCounter]})
            local noNavZoneRange = DetermineThreatRangeByUnitDatabaseId(args.guid,contact.guid)

            -- Set To New Value
            ScenEdit_SetReferencePoint({side=side.name,guid=v,newname=tostring(noNavZoneRange),lat=contact.latitude,lon=contact.longitude})
        end
        -- Update Zone Counter
        zoneCounter = zoneCounter + 1
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Monitor Create Ship No Nav Zones Action
--------------------------------------------------------------------------------------------------------------------------------
function MonitorCreateShipNoNavZonesAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local zones = PersistentGetGUID(args.shortKey.."_ship_ex_zone")
    -- Inventory And HVT And Contacts
    local totalHostileContacts = GetHostileSurfaceShipContacts(args.shortKey)
    -- Zones
    local noNavZoneBoundary = {}
    local zoneNumber = #zones + 1
    -- Condition Check
    if #zones >= 25 or #totalHostileContacts == 0 or #zones >= #totalHostileContacts then
       return false 
    end
    -- Get Contact
    local contact = ScenEdit_GetContact({side=side.name, guid=totalHostileContacts[#zones + 1]})
    local noNavZoneRange = DetermineThreatRangeByUnitDatabaseId(args.guid,contact.guid)
    -- Ship Zone + Range
    local referencePoint = ScenEdit_AddReferencePoint({side=side.name,lat=contact.latitude,lon=contact.longitude,name=tostring(noNavZoneRange),highlighted="no"})
    PersistentAddGUID(args.shortKey.."_ship_ex_zone",referencePoint.guid)
    -- Return True
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Monitor Update Ship No Nav Zones Action
--------------------------------------------------------------------------------------------------------------------------------
function MonitorUpdateShipNoNavZonesAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local zones = PersistentGetGUID(args.shortKey.."_ship_ex_zone")
    -- Inventory And HVT And Contacts
    local totalHostileContacts = GetHostileSurfaceShipContacts(args.shortKey)
    local zoneCounter = 1
    -- Condition Check
    if #zones == 0 then
       return false 
    end
    -- Key Value Pairs
    for k,v in pairs(zones) do
        local referencePoints = ScenEdit_GetReferencePoints({side=side.name,area={v}})
        local referencePoint = referencePoints[1]

        if zoneCounter > #totalHostileContacts then
            ScenEdit_SetReferencePoint({side=side.name, guid=v, newname="0", lat=0, long=0})
        else
            -- Get Contact
            local contact = ScenEdit_GetContact({side=side.name, guid=totalHostileContacts[zoneCounter]})
            local noNavZoneRange = DetermineThreatRangeByUnitDatabaseId(args.guid,contact.guid)
            -- Set To New Value
            ScenEdit_SetReferencePoint({side=side.name,guid=v,newname=tostring(noNavZoneRange),lat=contact.latitude,lon=contact.longitude})
        end
        -- Update Zone Counter
        zoneCounter = zoneCounter + 1
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Monitor Create Air No Nav Zones Action
--------------------------------------------------------------------------------------------------------------------------------
function MonitorCreateAirNoNavZonesAction(args)
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Monitor Update Air No Nav Zones Action
--------------------------------------------------------------------------------------------------------------------------------
function MonitorUpdateAirNoNavZonesAction(args)
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Hampton Micromanage Unit Actions
--------------------------------------------------------------------------------------------------------------------------------
function HamptonUpdateUnitsInReconMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_rec_miss")
    -- Check Total Is Zero
    if #missions == 0 then
        return false
    end
    -- Loop Through Existing Missions
    for k, v in pairs(missions) do
        -- Local Values
        local updatedMission = ScenEdit_GetMission(side.name,v)
        -- Find Contact Close To Unit And Evade
        if #updatedMission.unitlist > 0 then
            local missionUnit = ScenEdit_GetUnit({side=side.name, guid=updatedMission.unitlist[1]})
            local unitRetreatPoint = GetAllNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,70)
            -- SAM Retreat Point
            if unitRetreatPoint ~= nil and not DetermineUnitRTB(side.name,missionUnit.guid) then
                ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "no" })
                missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
                missionUnit.manualSpeed = unitRetreatPoint.speed
            else
                ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "yes" })
                missionUnit.manualSpeed = "OFF"
            end
        end
    end
    -- Return False
    return false
end

function HamptonUpdateUnitsInOffensiveAirMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_aaw_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then
        return false
    end
    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Retreat Point
    local missionUnits = GetGroupLeadsAndIndividualsFromMission(side.name,updatedMission.guid)
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetSAMAndShipNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid)
        -- Retreat Point
        if unitRetreatPoint ~= nil and not DetermineUnitRTB(side.name,missionUnit.guid) then
            ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "no" })
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            missionUnit.manualSpeed = unitRetreatPoint.speed
        else
            ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "yes" })
            missionUnit.manualSpeed = "OFF"
        end
    end
    -- Determine EMCON
    DetermineEmconToUnits(args.shortKey,side.name,updatedMission.unitlist)
    -- Return False
    return false
end

function HamptonUpdateUnitsInOffensiveStealthAirMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_saaw_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then
        return false
    end
    -- Get Linked Mission
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Retreat Point
    local missionUnits = GetGroupLeadsAndIndividualsFromMission(side.name,updatedMission.guid)
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetAllNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,70)
        -- Retreat Point
        if unitRetreatPoint ~= nil and not DetermineUnitRTB(side.name,missionUnit.guid) then
            ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "no" })
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            missionUnit.manualSpeed = unitRetreatPoint.speed
        else
            ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "yes" })
            missionUnit.manualSpeed = "OFF"
        end
    end
    -- Determine EMCON
    DetermineEmconToUnits(args.shortKey,side.name,updatedMission.unitlist)
    -- Return False
    return false
end

function HamptonUpdateUnitsInOffensiveSeadMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_sead_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then--or (currentTime - lastTimeStamp) < 1 * 60 then
        return false
    end
    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Return Point
    local missionUnits = GetGroupLeadsAndIndividualsFromMission(side.name,updatedMission.guid)
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetAirAndShipNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,70)
        -- Set Retreat
        if unitRetreatPoint ~= nil and not DetermineUnitRTB(side.name,missionUnit.guid) then
            ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "no" })
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            missionUnit.manualSpeed = unitRetreatPoint.speed
        else
            ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "yes" })
            missionUnit.manualSpeed = "OFF"
        end
    end
    -- Return False
    return false
end

function HamptonUpdateUnitsInOffensiveLandMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_land_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then--or (currentTime - lastTimeStamp) < 1 * 60 then
        return false
    end
    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Return Point
    local missionUnits = GetGroupLeadsAndIndividualsFromMission(side.name,updatedMission.guid)
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetAllNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,70)
        -- Set Retreat
        if unitRetreatPoint ~= nil and not DetermineUnitRTB(side.name,missionUnit.guid) then
            ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "no" })
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            missionUnit.manualSpeed = unitRetreatPoint.speed
        else
            ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "yes" })
            missionUnit.manualSpeed = "OFF"
        end
    end
    -- Return False
    return false
end

function HamptonUpdateUnitsInOffensiveAntiShipMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_asuw_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then
        return false
    end
    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Return Point
    local missionUnits = GetGroupLeadsAndIndividualsFromMission(side.name,updatedMission.guid)
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetAirAndSAMNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,70)
        -- Unit Retreat Point
        if unitRetreatPoint ~= nil and not DetermineUnitRTB(side.name,missionUnit.guid) then
            ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "no" })
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            missionUnit.manualSpeed = unitRetreatPoint.speed
        else
            ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "yes" })
            missionUnit.manualSpeed = "OFF"
        end
    end
    -- Return False
    return false
end

function HamptonUpdateUnitsInOffensiveAEWMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_aaew_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then
        return false
    end
    -- Get Linked Mission
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Retreat Point
    local missionUnits = GetGroupLeadsAndIndividualsFromMission(side.name,updatedMission.guid)
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetAllNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,150)
        -- Retreat Point
        if unitRetreatPoint ~= nil and not DetermineUnitRTB(side.name,missionUnit.guid) then
            ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "no" })
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            missionUnit.manualSpeed = unitRetreatPoint.speed
        else
            ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "yes" })
            missionUnit.manualSpeed = "OFF"
        end
    end
    -- Return False
    return false
end

function HamptonUpdateUnitsInSupportAEWMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_aew_sup_miss")
    local updatedMission = nil
    -- Condition Check
    if #missions == 0 then
        return false
    end
    -- Loop Through Coverted HVTs Missions
    for k, v in pairs(missions) do
        -- Update Mission
        updatedMission = ScenEdit_GetMission(side.name,v)
        -- Check Defense Mission
        if updatedMission then
            -- Determine Units To Assign
            local missionUnits = updatedMission.unitlist
            for k1,v1 in pairs(missionUnits) do
                local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v1})
                local unitRetreatPoint = GetAllNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,150)
                -- Unit Retreat Point
                if unitRetreatPoint ~= nil and not DetermineUnitRTB(side.name,missionUnit.guid) then
                    ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "no" })
                    missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
                    missionUnit.manualSpeed = unitRetreatPoint.speed
                else
                    ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "yes" })
                    missionUnit.manualSpeed = "OFF"
                end
            end
        end
    end
    -- Return False
    return false
end

function HamptonUpdateUnitsInSupportTankerMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_tan_sup_miss")
    local updatedMission = nil
    -- Condition Check
    if #missions == 0 then
        return false
    end
    -- Loop Through Coverted HVTs Missions
    for k, v in pairs(missions) do
        -- Updated Mission
        updatedMission = ScenEdit_GetMission(side.name,v)
        -- Check Defense Mission
        if updatedMission then
            -- Find Contact Close To Unit And Retreat If Necessary
            local missionUnits = updatedMission.unitlist
            for k1,v1 in pairs(missionUnits) do
                local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v1})
                local unitRetreatPoint = GetAllNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,150)
                -- Find Retreat Point
                if unitRetreatPoint ~= nil and not DetermineUnitRTB(side.name,missionUnit.guid) then
                    ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "no" })
                    missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
                    missionUnit.manualSpeed = unitRetreatPoint.speed
                else
                    ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "yes" })
                    missionUnit.manualSpeed = "OFF"
                end
            end
        end
    end
    -- Return True
    return false
end

function HamptonUpdateUnitsInDefensiveAirMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_aaw_d_miss")
    local updatedMission = nil
    -- Condition Check
    if #missions == 0 then
        return false
    end
    -- Loop Through Coverted HVTs Missions
    for k, v in pairs(missions) do
        -- Get Defense Mission
        updatedMission = ScenEdit_GetMission(side.name,v)
        -- Check Defense Mission
        if updatedMission then
            -- Find Area And Return Point
            local missionUnits = GetGroupLeadsAndIndividualsFromMission(side.name,updatedMission.guid)
            for k1,v1 in pairs(missionUnits) do
                local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v1})
                local unitRetreatPoint = GetSAMAndShipNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid)
                -- Set Retreat
                if unitRetreatPoint ~= nil and not DetermineUnitRTB(side.name,missionUnit.guid) then
                    ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "no" })
                    missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
                    missionUnit.manualSpeed = unitRetreatPoint.speed
                else
                    ScenEdit_SetDoctrine({side=side.name,guid=missionUnit.guid},{ignore_plotted_course = "yes" })
                    missionUnit.manualSpeed = "OFF"
                end
            end
            -- Determine EMCON
            DetermineEmconToUnits(args.shortKey,side.name,updatedMission.unitlist)
        end
    end
    -- Return False
    return false
end
--------------------------------------------------------------------------------------------------------------------------------
-- Initialize AI Attributes
--------------------------------------------------------------------------------------------------------------------------------
function InitializeAIAttributes(options)
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
function InitializeMerrimackMonitorAI(sideName,options)
    -- Local Values
    local side = ScenEdit_GetSideOptions({side=sideName})
    local sideGuid = side.guid
    local shortSideKey = "a"..tostring(#commandMerrimackAIArray + 1)
    local attributes = InitializeAIAttributes(options)


    -- Main Node Sequence
    local merrimackSelector = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    -- Doctrine Sequences
    local offensiveDoctrineSequence = BT:make(BT.sequence,sideGuid,shortSideKey,attributes)
    local defensiveDoctrineSequence = BT:make(BT.sequence,sideGuid,shortSideKey,attributes)
    -- Doctrine Sequences Children
    local offensiveDoctrineConditionalBT = BT:make(OffensiveConditionalCheck,sideGuid,shortSideKey,attributes)
    local defensiveDoctrineConditionalBT = BT:make(DefensiveConditionalCheck,sideGuid,shortSideKey,attributes)
    local offensiveDoctrineSeletor = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    local defensiveDoctrineSeletor = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    -- Sub Doctrine Sequences
    local reconDoctrineSelector = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    local attackDoctrineSelector = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    local defendDoctrineSelector = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    local supportTankerDoctrineSelector = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    local supportAEWDoctrineSelector = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    -- Recon Doctrine BT
    local reconDoctrineUpdateMissionBT = BT:make(ReconDoctrineUpdateMissionAction,sideGuid,shortSideKey,attributes)
    local reconDoctrineCreateMissionBT = BT:make(ReconDoctrineCreateMissionAction,sideGuid,shortSideKey,attributes)
    -- Attack Doctrine BT
    local attackDoctrineCreateUpdateAirMissionBT = BT:make(AttackDoctrineCreateUpdateAirMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateUpdateStealthAirMissionBT = BT:make(AttackDoctrineCreateUpdateStealthAirMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateUpdateAEWMissionBT = BT:make(AttackDoctrineCreateUpdateAEWMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateUpdateAntiSurfaceShipMissionBT = BT:make(AttackDoctrineCreateUpdateAntiSurfaceShipMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateUpdateSeadMissionBT = BT:make(AttackDoctrineCreateUpdateSeadMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateUpdateLandAttackMissionBT = BT:make(AttackDoctrineCreateUpdateLandAttackMissionAction,sideGuid,shortSideKey,attributes)
    -- Defend Doctrine BT
    local defendDoctrineCreateUpdateAirMissionBT = BT:make(DefendDoctrineCreateUpdateAirMissionAction,sideGuid,shortSideKey,attributes)
    -- Support Tanker Doctrine BT
    local supportTankerDoctrineCreateUpdateMissionBT = BT:make(SupportTankerDoctrineCreateUpdateMissionAction,sideGuid,shortSideKey,attributes)
    -- Support AEW Doctrine BT
    local supportAEWDoctrineCreateUpdateMissionBT = BT:make(SupportAEWDoctrineCreateUpdateMissionAction,sideGuid,shortSideKey,attributes)
    -- Build AI Tree
    merrimackSelector:addChild(offensiveDoctrineSequence)
    merrimackSelector:addChild(defensiveDoctrineSequence)
    -- Offensive and Defensive Sequence
    offensiveDoctrineSequence:addChild(offensiveDoctrineConditionalBT)
    offensiveDoctrineSequence:addChild(offensiveDoctrineSeletor)
    defensiveDoctrineSequence:addChild(defensiveDoctrineConditionalBT)
    defensiveDoctrineSequence:addChild(defensiveDoctrineSeletor)
    -- Offensive Selector
    offensiveDoctrineSeletor:addChild(supportAEWDoctrineSelector)
    offensiveDoctrineSeletor:addChild(supportTankerDoctrineSelector)
    offensiveDoctrineSeletor:addChild(reconDoctrineSelector)
    offensiveDoctrineSeletor:addChild(attackDoctrineSelector)
    offensiveDoctrineSeletor:addChild(defendDoctrineSelector)
    -- Defensive Selector
    defensiveDoctrineSeletor:addChild(supportAEWDoctrineSelector)
    defensiveDoctrineSeletor:addChild(supportTankerDoctrineSelector)
    defensiveDoctrineSeletor:addChild(reconDoctrineSelector)
    defensiveDoctrineSeletor:addChild(defendDoctrineSelector)
    -- Recon Doctrine Sequence
    reconDoctrineSelector:addChild(reconDoctrineUpdateMissionBT)
    reconDoctrineSelector:addChild(reconDoctrineCreateMissionBT)
    -- Attack Doctrine Sequence
    attackDoctrineSelector:addChild(attackDoctrineCreateUpdateAirMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateUpdateStealthAirMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateUpdateAEWMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateUpdateAntiSurfaceShipMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateUpdateSeadMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateUpdateLandAttackMissionBT)
    -- Defend Doctrine Sequence
    defendDoctrineSelector:addChild(defendDoctrineCreateUpdateAirMissionBT)
    -- Support Tanker Sequence
    supportTankerDoctrineSelector:addChild(supportTankerDoctrineCreateUpdateMissionBT)
    -- Support AEW Sequence
    supportAEWDoctrineSelector:addChild(supportAEWDoctrineCreateUpdateMissionBT)


    -- Setup Monitor AI
    local monitorSelector = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    -- Monitor No Fly Zones BT
    local monitorSAMNoNavSelector = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    local monitorUpdateSAMNoNavZonesBT = BT:make(MonitorUpdateSAMNoNavZonesAction,sideGuid,shortSideKey,attributes)
    local monitorCreateSAMNoNavZonesBT = BT:make(MonitorCreateSAMNoNavZonesAction,sideGuid,shortSideKey,attributes)
    local monitorShipNoNavSelector = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    local monitorUpdateShipNoNavZonesBT = BT:make(MonitorUpdateShipNoNavZonesAction,sideGuid,shortSideKey,attributes)
    local monitorCreateShipNoNavZonesBT = BT:make(MonitorCreateShipNoNavZonesAction,sideGuid,shortSideKey,attributes)
    local monitorAirNoNavSelector = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    local monitorUpdateAirNoNavZonesBT = BT:make(MonitorUpdateAirNoNavZonesAction,sideGuid,shortSideKey,attributes)
    local monitorCreateAirNoNavZonesBT = BT:make(MonitorCreateAirNoNavZonesAction,sideGuid,shortSideKey,attributes)
    -- Setup Monitor
    monitorSelector:addChild(monitorSAMNoNavSelector)
    monitorSelector:addChild(monitorShipNoNavSelector)
    monitorSelector:addChild(monitorAirNoNavSelector)
    monitorSAMNoNavSelector:addChild(monitorUpdateSAMNoNavZonesBT)
    monitorSAMNoNavSelector:addChild(monitorCreateSAMNoNavZonesBT)
    monitorShipNoNavSelector:addChild(monitorUpdateShipNoNavZonesBT)
    monitorShipNoNavSelector:addChild(monitorCreateShipNoNavZonesBT)
    monitorAirNoNavSelector:addChild(monitorUpdateAirNoNavZonesBT)
    monitorAirNoNavSelector:addChild(monitorCreateAirNoNavZonesBT)


    -- Setup Hampton AI
    local hamptonSelector = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    local hamptonUpdateReconBT = BT:make(HamptonUpdateUnitsInReconMissionAction,sideGuid,shortSideKey,attributes)
    local hamptonUpdateOffAirBT = BT:make(HamptonUpdateUnitsInOffensiveAirMissionAction,sideGuid,shortSideKey,attributes)
    local hamptonUpdateOffStealthAirBT = BT:make(HamptonUpdateUnitsInOffensiveStealthAirMissionAction,sideGuid,shortSideKey,attributes)
    local hamptonUpdateOffAEWBT = BT:make(HamptonUpdateUnitsInOffensiveAEWMissionAction,sideGuid,shortSideKey,attributes)
    local hamptonUpdateOffAntiSurfBT = BT:make(HamptonUpdateUnitsInOffensiveAntiShipMissionAction,sideGuid,shortSideKey,attributes)
    local hamptonUpdateOffSeadBT = BT:make(HamptonUpdateUnitsInOffensiveSeadMissionAction,sideGuid,shortSideKey,attributes)
    local hamptonUpdateOffLandBT = BT:make(HamptonUpdateUnitsInOffensiveLandMissionAction,sideGuid,shortSideKey,attributes)
    local hamptonUpdateDefAirBT = BT:make(HamptonUpdateUnitsInDefensiveAirMissionAction,sideGuid,shortSideKey,attributes)
    local hamptonUpdateSupTankerBT = BT:make(HamptonUpdateUnitsInSupportTankerMissionAction,sideGuid,shortSideKey,attributes)
    local hamptonUpdateSupAEWBT = BT:make(HamptonUpdateUnitsInSupportAEWMissionAction,sideGuid,shortSideKey,attributes)


    -- Setup Hampton
    hamptonSelector:addChild(hamptonUpdateReconBT)
    hamptonSelector:addChild(hamptonUpdateOffAirBT)
    hamptonSelector:addChild(hamptonUpdateOffStealthAirBT)
    hamptonSelector:addChild(hamptonUpdateOffAEWBT)
    hamptonSelector:addChild(hamptonUpdateOffAntiSurfBT)
    hamptonSelector:addChild(hamptonUpdateOffSeadBT)
    hamptonSelector:addChild(hamptonUpdateOffLandBT)
    hamptonSelector:addChild(hamptonUpdateDefAirBT)
    hamptonSelector:addChild(hamptonUpdateSupTankerBT)
    hamptonSelector:addChild(hamptonUpdateSupAEWBT)


    -- Add All AI's
    commandMerrimackAIArray[#commandMerrimackAIArray + 1] = merrimackSelector
    commandMonitorAIArray[#commandMonitorAIArray + 1] = monitorSelector
    commandHamptonAIArray[#commandHamptonAIArray + 1] = hamptonSelector
end

function UpdateAI()
    -- Update Inventories And Update Merrimack AI
    for k, v in pairs(commandMerrimackAIArray) do
        UpdateAIInventories(v.guid,v.shortKey)
        UpdateAIAreaOfOperations(v.guid,v.shortKey)
        v:run()
    end
    -- Update Monitor AI
    for k, v in pairs(commandMonitorAIArray) do
        v:run()
    end
    -- Update Hampton AI
    for k, v in pairs(commandHamptonAIArray) do
        v:run()
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Global Call
--------------------------------------------------------------------------------------------------------------------------------
InitializeMerrimackMonitorAI("Blue Force",{preset="Grant",options={aggressive=5,defensive=5,cunning=5,direct=5,determined=5,reserved=5}})
InitializeMerrimackMonitorAI("Red Force",{preset="Grant",options={aggressive=5,defensive=5,cunning=5,direct=5,determined=5,reserved=5}})