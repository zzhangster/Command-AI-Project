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
function MemoryReset()
    commandMemory = {}
end

function MemoryRemoveAllGUIDsFromKey(primaryKey)
    commandMemory[primaryKey] = {}
end

function MemoryGetGUIDFromKey(primaryKey)
    local table = commandMemory[primaryKey]
    if table then
        return table
    else
        return {}
    end
end

function MemoryAddGUIDToKey(primaryKey,guid)
    local table = commandMemory[primaryKey]
    if not table then
        table = {}
    end
    table[#table + 1] = guid
    commandMemory[primaryKey] = table
end

function MemoryGUIDExists(primaryKey,guid)
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
    ScenEdit_SetKeyValue(primaryKey,"")
end

function PersistentGetGUID(primaryKey)
    local guidString = ScenEdit_GetKeyValue(primaryKey)
    if guidString == nil then
        guidString = ""
    end
    return Split(guidString,",")
end

function PersistentAddGUID(primaryKey,guid)
    local guidString = ScenEdit_GetKeyValue(primaryKey)
    if guidString == nil then
        guidString = guid
    else
        guidString = guidString..","..guid
    end
    ScenEdit_SetKeyValue(primaryKey,guidString)
end

function PersistentRemoveGUID(primaryKey,guid)
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
    local table = PersistentGetGUID(primaryKey)
    for k, v in pairs(table) do
        if guid == v then
            return true
        end
    end
    return false
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

function Split(s, sep)
    local fields = {}
    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

function GetUnitsFromMission(sideName,missionGuid)
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

function DetermineHVAByUnitDatabaseId(sideShortKey,unitGuid,unitDBID)
    local hva = ScenEdit_GetKeyValue("hv_"..tostring(unitDBID))
    if hva == "HV" then
        return true
    else
        return false
    end
end

function DetermineAndAddHVTByUnitDatabaseId(sideShortKey,unitGuid,unitDBID)
    local hva = ScenEdit_GetKeyValue("hv_"..tostring(unitDBID))
    if hva == "HV" then
        MemoryAddGUIDToKey(sideShortKey.."_def_hvt",unitGuid)
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
    -- Check Auto Detectable Unit And Find Range Again
    if range == 0 and contact.side then
        local unit = ScenEdit_GetUnit({side=contact.side.name, guid=contact.actualunitid})
        if unit.autodetectable then
            local foundRange = ScenEdit_GetKeyValue("thr_"..tostring(unit.dbid))
            if foundRange ~= "" then
                range = tonumber(foundRange)
            end
        end
    end
    -- If Range Is Zero Determine By Default Air Defence Values
    if range == 0 then
        -- Create Exlusion Zone Based On Missile Defense
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
    return range
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated Fighter Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirFighterInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_fig_free")
end

function GetBusyAirFighterInventory(sideShortKey)
    return MemoryGetGUIDFromKey(sideShortKey.."_fig_busy")
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
-- Get Total Inventory Strength
--------------------------------------------------------------------------------------------------------------------------------
function GetAllInventoryStrength(sideShortKey)
    local totalStrength = #GetFreeAirFighterInventory(sideShortKey)
    totalStrength = totalStrength + #GetBusyAirFighterInventory(sideShortKey)
    totalStrength = totalStrength + #GetFreeAirStealthInventory(sideShortKey)
    totalStrength = totalStrength + #GetBusyAirStealthInventory(sideShortKey)
    totalStrength = totalStrength + #GetFreeAirMultiroleInventory(sideShortKey)
    totalStrength = totalStrength + #GetBusyAirMultiroleInventory(sideShortKey)
    totalStrength = totalStrength + #GetFreeAirAttackInventory(sideShortKey)
    totalStrength = totalStrength + #GetBusyAirAttackInventory(sideShortKey)
    totalStrength = totalStrength + #GetFreeAirSeadInventory(sideShortKey)
    totalStrength = totalStrength + #GetBusyAirSeadInventory(sideShortKey)
    totalStrength = totalStrength + #GetFreeAirAEWInventory(sideShortKey)
    totalStrength = totalStrength + #GetBusyAirAEWInventory(sideShortKey)
    totalStrength = totalStrength + #GetFreeAirASuWInventory(sideShortKey)
    totalStrength = totalStrength + #GetBusyAirASuWInventory(sideShortKey)
    totalStrength = totalStrength + #GetFreeAirASWInventory(sideShortKey)
    totalStrength = totalStrength + #GetBusyAirASWInventory(sideShortKey)
    totalStrength = totalStrength + #GetFreeAirReconInventory(sideShortKey)
    totalStrength = totalStrength + #GetBusyAirReconInventory(sideShortKey)
    totalStrength = totalStrength + #GetFreeAirTankerInventory(sideShortKey)
    totalStrength = totalStrength + #GetBusyAirTankerInventory(sideShortKey)
    totalStrength = totalStrength + #GetFreeAirUAVInventory(sideShortKey)
    totalStrength = totalStrength + #GetBusyAirUAVInventory(sideShortKey)
    totalStrength = totalStrength + #GetFreeAirUCAVInventory(sideShortKey)
    totalStrength = totalStrength + #GetBusyAirUCAVInventory(sideShortKey)
    return totalStrength
end

function GetAllInventory(sideShortKey)
    local totalInventory = CombineTablesNew(GetFreeAirFighterInventory(sideShortKey),GetBusyAirFighterInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetFreeAirStealthInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetBusyAirStealthInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetFreeAirMultiroleInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetBusyAirMultiroleInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetFreeAirAttackInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetBusyAirAttackInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetFreeAirSeadInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetBusyAirSeadInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetFreeAirAEWInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetBusyAirAEWInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetFreeAirASuWInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetBusyAirASuWInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetFreeAirASWInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetBusyAirASWInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetFreeAirReconInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetBusyAirReconInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetFreeAirTankerInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetBusyAirTankerInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetFreeAirUAVInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetBusyAirUAVInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetFreeAirUCAVInventory(sideShortKey))
    totalInventory = CombineTables(totalInventory,GetBusyAirUCAVInventory(sideShortKey))
    return totalInventory
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

function GetAllHostileContacts(sideShortKey)
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

function GetAllHostileContactStrength(sideShortKey)
    local totalHostileStrength = #GetHostileAirContacts(sideShortKey)
    totalHostileStrength = totalHostileStrength + #GetHostileSurfaceShipContacts(sideShortKey)
    totalHostileStrength = totalHostileStrength + #GetHostileSubmarineContacts(sideShortKey)
    return totalHostileStrength
end

--------------------------------------------------------------------------------------------------------------------------------
-- Reinforcement Requests And Others
--------------------------------------------------------------------------------------------------------------------------------
function AddReinforcementRequest(sideShortKey,sideAttributes,sideName,missionName,quantity)
    local determinedModifier = sideAttributes.determined * 2 / (sideAttributes.determined + sideAttributes.reserved)
    quantity = math.ceil(quantity * determinedModifier)
    MemoryAddGUIDToKey(sideShortKey.."_reinforce_request",{name=missionName,number=quantity})
end

function GetReinforcementRequests(sideShortKey)
    local reinforceRequests = MemoryGetGUIDFromKey(sideShortKey.."_reinforce_request")
    local returnRequests = {}
    -- Loop And Determine 
    for k,v in pairs(reinforceRequests) do
        returnRequests[tostring(v.name)] = v.number
    end
    return returnRequests
end

function AddAllocatedUnit(sideShortKey,unitGuid)
    local allocatedUnits = MemoryGetGUIDFromKey(sideShortKey.."_alloc_units")
    local allocatedUnitsTable = {}
    if #allocatedUnits == 1 then
        allocatedUnitsTable = allocatedUnits[1]
    end
    allocatedUnitsTable[unitGuid] = unitGuid
    MemoryRemoveAllGUIDsFromKey(sideShortKey.."_alloc_units")
    MemoryAddGUIDToKey(sideShortKey.."_alloc_units",allocatedUnitsTable)
end

function GetAllocatedUnitExists(sideShortKey,unitGuid)
    local allocatedUnits = MemoryGetGUIDFromKey(sideShortKey.."_alloc_units")
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

function DetermineUnitsToUnAssign(sideShortKey,sideName,missionGuid)
    -- Local Values
    local mission = ScenEdit_GetMission(sideName,missionGuid)
    local missionUnits = GetUnitsFromMission(sideName,missionGuid)
    -- Check
    if mission then
        -- Loop Through Mission Unit Lists And Unassign RTB Units
        for k,v in pairs(missionUnits) do
            local unit = ScenEdit_GetUnit({side=sideName, guid=v})
            if unit then
                if unit.speed == 0 and tostring(unit.readytime) ~= "0"  then
                    local mockMission = ScenEdit_AddMission(sideName,"MOCK MISSION",'strike',{type='land'})
                    ScenEdit_AssignUnitToMission(unit.guid, mockMission.guid)  
                    ScenEdit_DeleteMission(sideName,mockMission.guid) 
                else
                    -- Save Unit
                    AddAllocatedUnit(sideShortKey,unit.guid)
                end
            end
        end        
    end
end

function DetermineUnitsToAssign(sideShortKey,sideName,missionGuid,totalRequiredUnits,unitGuidList)
    -- Local Values
    local mission = ScenEdit_GetMission(sideName,missionGuid)
    local missionUnits = GetUnitsFromMission(sideName,missionGuid)
    local missionUnitsCount = #missionUnits
    local allocatedUnitsTable = MemoryGetGUIDFromKey(sideShortKey.."_alloc_units")
    totalRequiredUnits = totalRequiredUnits - missionUnitsCount
    -- Check
    if mission then
        -- Assign Up to Total Required Units
        for k,v in pairs(unitGuidList) do
            -- Condition Check
            if totalRequiredUnits <= 0 then
                break
            end
            -- Check Unit And Assign
            local unit = ScenEdit_GetUnit({side=sideName, guid=v})
            -- Check If Unit Has Already Been Allocated In This Cycle
            if not GetAllocatedUnitExists(sideShortKey,unit.guid) then
                if (not DetermineUnitRTB(sideName,v) and unit.speed > 0) or (tostring(unit.readytime) == "0" and unit.speed == 0) then
                    -- Assign Unit
                    totalRequiredUnits = totalRequiredUnits - 1
                    ScenEdit_AssignUnitToMission(v,mission.guid)
                    -- Save Unit
                    AddAllocatedUnit(sideShortKey,unit.guid)
                end
            end
        end
        -- Return
        if totalRequiredUnits == 0 then
            return true
        else
            return false
        end
    end
    -- Return false
    return false
end

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

function DetermineEmconToUnits(sideShortKey,sideAttributes,sideName,unitGuidList)
    -- Local Values
    local busyAEWInventory = GetBusyAirAEWInventory(sideShortKey)
    local cunningModifier = sideAttributes.cunning * 2 / (sideAttributes.direct + sideAttributes.cunning)
    local emconChangeState = ScenEdit_GetKeyValue(sideShortKey.."_emcon_chg_st")
    local emconChangeTime = GetTimeStampForGUID(sideShortKey.."_emcon_chg")
    local currentTime = ScenEdit_CurrentTime ()
    -- Loop
    for k,v in pairs(unitGuidList) do
        local unit = ScenEdit_GetUnit({side=sideName, guid=v})
        -- Determine Unit Firing At
        if not unit.firingAt then
            -- Check
            if cunningModifier > 0.75 then
                -- Determine Active Or Deactivate Cycle
                if (emconChangeTime - currentTime) <= 0 then
                    if emconChangeState == "" or emconChangeState == "Active" then
                        ScenEdit_SetKeyValue(sideShortKey.."_emcon_chg_st","Passive")
                    else 
                        ScenEdit_SetKeyValue(sideShortKey.."_emcon_chg_st","Active")
                    end
                    ScenEdit_SetEMCON("Unit",v,"Radar="..emconChangeState)
                    SetTimeStampForGUID(sideShortKey.."_emcon_chg",tostring(currentTime + 30))
                end
            else
                ScenEdit_SetEMCON("Unit",v,"Radar=Active")
            end
            -- Check
            if cunningModifier > 1.25 then
                for k1,v1 in pairs(busyAEWInventory) do
                    local aewUnit = ScenEdit_GetUnit({side=sideName, guid=v1})
                    if aewUnit.speed > 0 and aewUnit.altitude > 0 then
                        if Tool_Range(v1,v) < 200 then
                            ScenEdit_SetEMCON("Unit",v,"Radar=Passive")
                        end
                    end
                end
            end
        end
    end
end

function DetermineUnitToRetreat(sideShortKey,sideGuid,sideAttributes,missionGuid,unitGuidList,zoneType,retreatRange)
    -- Local Values
    local side = VP_GetSide({guid=sideGuid})
    local missionUnits = GetUnitsFromMission(side.name,missionGuid)
    -- Loop Unit Guid List
    for k,v in pairs(unitGuidList) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = {}
        -- Check By Type
        if zoneType == 0 then
            unitRetreatPoint = GetAllNoNavZoneThatContainsUnit(sideGuid,sideShortKey,sideAttributes,missionUnit.guid,retreatRange)
        elseif zoneType == 1 then
            unitRetreatPoint = GetSAMAndShipNoNavZoneThatContainsUnit(sideGuid,sideShortKey,sideAttributes,missionUnit.guid)
        elseif zoneType == 2 then
            unitRetreatPoint = GetAirAndShipNoNavZoneThatContainsUnit(sideGuid,sideShortKey,sideAttributes,missionUnit.guid,retreatRange)
        elseif zoneType == 3 then
            unitRetreatPoint = GetAirAndSAMNoNavZoneThatContainsUnit(sideGuid,sideShortKey,sideAttributes,missionUnit.guid,retreatRange)
        else
            unitRetreatPoint = nil
        end
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

end

--------------------------------------------------------------------------------------------------------------------------------
-- Determine If Unit Is In Zone - Returned Desired Retreat Point
--------------------------------------------------------------------------------------------------------------------------------
function GetAirNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,range)
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local hostileAirContacts = GetHostileAirContacts(shortSideKey)
    local unknownAirContacts = GetUnknownAirContacts(shortSideKey)
    local reservedModifier = sideAttributes.reserved * 2 / (sideAttributes.determined + sideAttributes.reserved)
    local desiredRange = range * reservedModifier
    -- Check Hostile Contacts Points
    for k,v in pairs(hostileAirContacts) do
        local contact = ScenEdit_GetContact({side=side.name, guid=v})
        local currentRange = Tool_Range(contact.guid,unitGuid)
        if currentRange < desiredRange then
            local bearing = Tool_Bearing(contact.guid,unitGuid)
            local retreatLocation = ProjectLatLong(MakeLatLong(contact.latitude,contact.longitude),bearing,desiredRange + 20)
            return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=2000}
        end
    end
    -- Check Unknown Contacts Points
    for k,v in pairs(unknownAirContacts) do
        local contact = ScenEdit_GetContact({side=side.name, guid=v})
        local currentRange = Tool_Range(contact.guid,unitGuid)
        if currentRange < desiredRange then
            local bearing = Tool_Bearing(contact.guid,unitGuid)
            local retreatLocation = ProjectLatLong(MakeLatLong(contact.latitude,contact.longitude),bearing,desiredRange + 20)
            return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=2000}
        end
    end
    -- Return nil
    return nil
end

function GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    -- Local Side And Mission
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local zones = PersistentGetGUID(shortSideKey.."_sam_ex_zone")
    local reservedModifier = sideAttributes.reserved * 2 / (sideAttributes.determined + sideAttributes.reserved)
    -- Zone Reference Points
    local zoneReferencePoints = ScenEdit_GetReferencePoints({side=side.name, area=zones})
    -- Zone Reference Points
    for k,v in pairs(zoneReferencePoints) do
        local currentRange = Tool_Range({latitude=v.latitude,longitude=v.longitude},unitGuid)
        local desiredRange = tonumber(v.name) * reservedModifier
        if currentRange < desiredRange then
            local contactPoint = MakeLatLong(v.latitude,v.longitude)
            local bearing = Tool_Bearing({latitude=contactPoint.latitude,longitude=contactPoint.longitude},unitGuid)
            local retreatLocation = ProjectLatLong(contactPoint,bearing,desiredRange+30)
            return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=600}
        end
    end
    -- Return nil
    return nil
end

function GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    -- Local Side And Mission
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local zones = PersistentGetGUID(shortSideKey.."_ship_ex_zone")
    local reservedModifier = sideAttributes.reserved * 2 / (sideAttributes.determined + sideAttributes.reserved)
    -- Zone Reference Points
    local zoneReferencePoints = ScenEdit_GetReferencePoints({side=side.name, area=zones})
    for k,v in pairs(zoneReferencePoints) do
        local currentRange = Tool_Range({latitude=v.latitude,longitude=v.longitude},unitGuid)
        local desiredRange = tonumber(v.name) * reservedModifier
        if currentRange < desiredRange then
            local contactPoint = MakeLatLong(v.latitude,v.longitude)
            local bearing = Tool_Bearing({latitude=contactPoint.latitude,longitude=contactPoint.longitude},unitGuid)
            local retreatLocation = ProjectLatLong(contactPoint,bearing,desiredRange+30)
            return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=600}
        end
    end
    -- Return nil
    return nil
end

function GetEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    -- Local Side And Mission
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local hostileMissilesContacts = GetHostileWeaponContacts(shortSideKey)
    local reservedModifier = sideAttributes.reserved * 2 / (sideAttributes.determined + sideAttributes.reserved)
    -- Loop Through Contacts
    for k,v in pairs(hostileMissilesContacts) do
        local currentRange = Tool_Range(v,unitGuid)
        local contact = ScenEdit_GetContact({side=side.name, guid=v})
        local minDesiredRange = 12 * reservedModifier
        local maxDesiredRange = 70 * reservedModifier
        -- Desire Range Check
        if currentRange > minDesiredRange and currentRange < maxDesiredRange then
            local contactPoint = MakeLatLong(contact.latitude,contact.longitude)
            local bearing = Tool_Bearing({latitude=contactPoint.latitude,longitude=contactPoint.longitude},unitGuid)
            local retreatLocation = ProjectLatLong(contactPoint,bearing,maxDesiredRange + 20)
            return {latitude=retreatLocation.latitude,longitude=retreatLocation.longitude,speed=2000}
        end
    end
    -- Return nil
    return nil
end

function GetSAMAndShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    local contactPoint = GetEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    if contactPoint ~= nil then
        return contactPoint
    else
        contactPoint = GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
        if contactPoint ~= nil then
            return contactPoint
        else
            return GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
        end
    end
end

function GetAirAndShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,airRange)
    local contactPoint = GetEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    if contactPoint ~= nil then
        return contactPoint
    else
        contactPoint = GetAirNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,airRange)
        if contactPoint ~= nil then
            return contactPoint
        else
            return GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
        end
    end
end

function GetAirAndSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,airRange)
    local contactPoint = GetEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    if contactPoint ~= nil then
        return contactPoint 
    else
        contactPoint = GetAirNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,airRange)
        if contactPoint ~= nil then
            return contactPoint
        else
            return GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
        end
    end
end

function GetAllNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,airRange)
    local contactPoint = GetEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
    if contactPoint ~= nil then
        return contactPoint
    else
        contactPoint = GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
        if contactPoint ~= nil then
            return contactPoint
        else
            contactPoint = GetAirNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid,airRange)
            if contactPoint ~= nil then
                return contactPoint
            else
                return GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,sideAttributes,unitGuid)
            end
        end
    end
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
    if #aoPoints < 4 or (currentTime - lastTime) > 8 * 60 then 
        -- Set Contact Bounding Box Variables
        local hostileContacts = GetAllHostileContacts(sideShortKey)
        local inventory = GetAllInventory(sideShortKey)
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
    local currentTime = ScenEdit_CurrentTime()
    -- Loop Through Aircraft Inventory By Subtypes And Readiness
    if aircraftInventory then
        --ScenEdit_SpecialMessage("South Korea", tostring(#aircraftInventory))
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
            -- Add To Memory
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
                MemoryAddGUIDToKey(sideShortKey.."_def_hva",unit.guid)
            end
            -- Add To Memory
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
            -- Save Unit As HVA (Airport)
            if unit.subtype == "9001" then
                unitType = "base"
            elseif unit.subtype == "5001" then
                unitType = "sam"
            end
            -- Determine And Add HVA
            if DetermineHVAByUnitDatabaseId(sideShortKey,unit.guid,unit.dbid) then
                MemoryAddGUIDToKey(sideShortKey.."_def_hva",unit.guid)
            end
            -- Save Unit GUID
            MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..unitStatus,unit.guid)
        end
    end
    -- Loop Through Aircraft Contacts
    local previousTime = GetTimeStampForGUID(sideShortKey.."_air_con_ts")
    if (currentTime - previousTime) > 60 or currentTime == previousTime then 
        if aircraftContacts then
            for k, v in pairs(aircraftContacts) do
                -- Local Values
                local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
                local unitType = "air_con"
                -- Save Unit GUID
                MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
            end
        end
        SetTimeStampForGUID(sideShortKey.."_air_con_ts",currentTime)
    end
    -- Loop Through Ship Contacts
    previousTime = GetTimeStampForGUID(sideShortKey.."_ship_con_ts")
    if (currentTime - previousTime) > 60 or currentTime == previousTime then 
        if shipContacts then
            for k, v in pairs(shipContacts) do
                -- Local Values
                local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
                local unitType = "surf_con"
                -- Save Unit GUID
                MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
            end
        end
        SetTimeStampForGUID(sideShortKey.."_ship_con_ts",currentTime)
    end
    -- Loop Through Submarine Contacts
    previousTime = GetTimeStampForGUID(sideShortKey.."_sub_con_ts")
    if (currentTime - previousTime) > 60 or currentTime == previousTime then 
        if submarineContacts then
            for k, v in pairs(submarineContacts) do
                -- Local Values
                local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
                local unitType = "sub_con"
                -- Save Unit GUID
                MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
            end
        end
        SetTimeStampForGUID(sideShortKey.."_sub_con_ts",currentTime)
    end
    -- Loop Through Land Contacts
    previousTime = GetTimeStampForGUID(sideShortKey.."_land_con_ts")
    if (currentTime - previousTime) > 5 * 60 or currentTime == previousTime then 
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
        SetTimeStampForGUID(sideShortKey.."_land_con_ts",currentTime)
    end
    -- Loop Through Weapon Contacts
    if weaponContacts then
        for k, v in pairs(weaponContacts) do
            -- Local Values
            local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
            local unitType = "weap_con"
            -- Filter Out By Weapon Speed
            if contact.speed then
                if  contact.speed > 2000 then
                    -- Save Unit GUID For Greater Than 2000
                    MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
                end
            else 
                -- Save Unit GUID For Unknown Speed
                MemoryAddGUIDToKey(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
            end
        end
    end
end

function ResetAllInventoriesAndContacts()
    -- Memory Clean
    MemoryReset()
end

--------------------------------------------------------------------------------------------------------------------------------
-- Offensive Conditional Check
--------------------------------------------------------------------------------------------------------------------------------
function OffensiveConditionalCheck(args)
    -- Local Values
    local hostileStrength = GetAllHostileContactStrength(args.shortKey)
    local inventoryStrength = GetAllInventoryStrength(args.shortKey)
    local aggressiveModifier = args.options.aggressive * 2 / (args.options.aggressive + args.options.defensive)
    -- Check
    if hostileStrength <= 0 then
        return false
    elseif hostileStrength <= inventoryStrength * aggressiveModifier then
        return true
    else
        return false
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Defensive Conditional Check
--------------------------------------------------------------------------------------------------------------------------------
function DefensiveConditionalCheck(args)
    -- Local Values
    local hostileStrength = GetAllHostileContactStrength(args.shortKey)
    local inventoryStrength = GetAllInventoryStrength(args.shortKey)
    local aggressiveModifier = args.options.aggressive * 2 / (args.options.aggressive + args.options.defensive)
    -- Check
    if hostileStrength <= 0 then
        return true
    elseif hostileStrength > inventoryStrength * aggressiveModifier then
        return true
    else
        return false
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Recon Doctrine Create Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function ReconDoctrineCreateUpdateMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local missions = PersistentGetGUID(args.shortKey.."_rec_miss")
    local rp1,rp2,rp3,rp4 = ""
    -- Limit To Four Missions, When 0 Contacts And Has Air Recon Inventory
    if #missions < 4 then
        local missionNumber = math.random(4)
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
        -- Add Guid
        PersistentAddGUID(args.shortKey.."_rec_miss",createdMission.name)
    else
        -- Loop Through Existing Missions
        local missionNumber = 0
        for k, v in pairs(missions) do
            -- Local Values
            local updatedMission = ScenEdit_GetMission(side.name,v)
            local defensiveBoundingBox = {}
            local rp1,rp2,rp3,rp4 = ""
            -- Assign Units To Recon Mission
            local totalReconUnitsToAssign = 1
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
            -- Add Reinforcement Request
            AddReinforcementRequest(args.shortKey,args.options,side.name,updatedMission.name,1)
        end
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
        ScenEdit_SetDoctrine({side=side.name,mission=createdUpdatedMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb ="1"})
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
        -- Add Reinforcement Request
        AddReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,totalAirUnitsToAssign)
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
    local totalAirUnitsToAssign = 0
    local missionNumber = 1
    local createdUpdatedMission = {}
    local linkedMission = {}
    local linkedMissionPoints = {}
    local linkedMissionUnits = {}
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
            -- Add Mission
            PersistentAddGUID(args.shortKey.."_saaw_miss",createdUpdatedMission.name)
        else
            -- Updated Mission
            createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
            -- Total Units
            linkedMissionUnits = GetUnitsFromMission(side.name,linkedMission.guid)   
            totalAirUnitsToAssign = math.floor(#linkedMissionUnits/4)
            -- Round Up
            if totalAirUnitsToAssign % 2 == 1 then
                totalAirUnitsToAssign = totalAirUnitsToAssign + 1
            end
            -- Add Reinforcement Request
            AddReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,totalAirUnitsToAssign)
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
            -- Add Reinforcement Request
            AddReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,1)
        end
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Create Update Tanker Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineCreateUpdateTankerMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_atan_miss")
    local linkedMissions = PersistentGetGUID(args.shortKey.."_aaw_miss")
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local createdUpdatedMission = {}
    local linkedMission = {}
    local linkedMissionPoints = {}
    local linkedMissionCenterPoint = {}
    local patrolBoundingBox = {}
    local linkedMissionUnits = {}
    local totalAirUnitsToAssign = 0
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
            rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_1", lat=patrolBoundingBox[1].latitude, lon=patrolBoundingBox[1].longitude})
            rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_2", lat=patrolBoundingBox[2].latitude, lon=patrolBoundingBox[2].longitude})
            rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_3", lat=patrolBoundingBox[3].latitude, lon=patrolBoundingBox[3].longitude})
            rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_4", lat=patrolBoundingBox[4].latitude, lon=patrolBoundingBox[4].longitude})
            -- Create Mission
            createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_atan_miss_"..tostring(missionNumber),"support",{zone={rp1.name,rp2.name,rp3.name,rp4.name}})
            ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=true,flightSize=1,useFlightSize=true})
            ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Passive")
            -- Add Guid And Add Time Stamp
            PersistentAddGUID(args.shortKey.."_atan_miss",createdUpdatedMission.name)
        else
            -- Get Linked Mission
            createdUpdatedMission = ScenEdit_GetMission(side.name,missions[1])
            -- Set Reference Points
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_1", lat=patrolBoundingBox[1].latitude, lon=patrolBoundingBox[1].longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_2", lat=patrolBoundingBox[2].latitude, lon=patrolBoundingBox[2].longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_3", lat=patrolBoundingBox[3].latitude, lon=patrolBoundingBox[3].longitude})
            ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_atan_miss_"..tostring(missionNumber).."_rp_4", lat=patrolBoundingBox[4].latitude, lon=patrolBoundingBox[4].longitude})
            -- Total Units
            linkedMissionUnits = GetUnitsFromMission(side.name,linkedMission.guid)   
            totalAirUnitsToAssign = math.floor(#linkedMissionUnits/4)
            -- Add Reinforcement Request
            AddReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,totalAirUnitsToAssign)
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
        ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Active")
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
        -- Add Reinforcement Request
        AddReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,totalAirUnitsToAssign)
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
    local totalHostileContacts = GetHostileSAMContacts(args.shortKey)
    local totalAirUnitsToAssign = GetHostileSAMContactsStrength(args.shortKey) * 4
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)
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
        ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Passive")
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
        -- Add Reinforcement Request
        AddReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,totalAirUnitsToAssign)
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
        ScenEdit_SetEMCON("Mission",createdUpdatedMission.guid,"Radar=Passive")
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
        -- Add Reinforcement Request
        AddReinforcementRequest(args.shortKey,args.options,side.name,createdUpdatedMission.name,totalAirUnitsToAssign)
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
    local prosecutionBoundingBox = {}
    local rp1,rp2,rp3,rp4 = ""
    local prp1,prp2,prp3,prp4 = ""
    -- Inventory And HVA And Contacts
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local totalUnknownContacts = GetUnknownAirContacts(args.shortKey)
    local totalHVAs = MemoryGetGUIDFromKey(args.shortKey.."_def_hva")
    local coveredHVAs = PersistentGetGUID(args.shortKey.."_def_hva_cov")
    local unitToDefend = nil
    local totalAAWUnitsToAssign = 2
    -- Condition Check
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
            defenseBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(unitToDefend.latitude,unitToDefend.longitude)},1.5)
            prosecutionBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(unitToDefend.latitude,unitToDefend.longitude)},2.5)
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
            PersistentAddGUID(args.shortKey.."_aaw_d_miss",createdMission.name)
            PersistentAddGUID(args.shortKey.."_def_hva_cov",unitToDefend.guid)
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
                defenseBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(coveredHVA.latitude,coveredHVA.longitude)},1.5)
                prosecutionBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(coveredHVA.latitude,coveredHVA.longitude)},2.5)
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
                    if contact:inArea({prp1.name,prp2.name,prp3.name,prp4.name}) then
                        contactsInZone = contactsInZone + 1
                    end
                end
                for k1, v1 in pairs(totalUnknownContacts) do
                    local contact = ScenEdit_GetContact({side=side.name, guid=v1})
                    if contact:inArea({prp1.name,prp2.name,prp3.name,prp4.name}) then
                        contactsInZone = contactsInZone + 1
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
                AddReinforcementRequest(args.shortKey,args.options,side.name,updatedMission.name,totalAAWUnitsToAssign + contactsInZone)
            end
        end
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Defensive Tanker Doctrine Create Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function DefendTankerDoctrineCreateUpdateMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_tan_d_miss")
    local createdMission = nil
    local updatedMission = nil
    -- Boxes And Coordinates
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local rp1,rp2,rp3,rp4 = nil
    local supportBoundingBox = {}
    -- Inventory And HVA And Contacts
    local totalHVAs = MemoryGetGUIDFromKey(args.shortKey.."_def_hva")
    local coveredHVAs = PersistentGetGUID(args.shortKey.."_def_tan_hva_cov")
    local unitToSupport = nil
    -- Condition Check
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
                unitToSupport = ScenEdit_GetUnit({side=side.name, guid=v})
                break
            end
        end
        -- Check If No Unit To Defend
        if unitToSupport then
            -- Set Contact Bounding Box Variables
            defenseBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(unitToSupport.latitude,unitToSupport.longitude)},0.5)
            -- Set Reference Points
            rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_tan_d_miss_"..unitToSupport.guid.."_rp_1", lat=defenseBoundingBox[1].latitude, lon=defenseBoundingBox[1].longitude})
            rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_tan_d_miss_"..unitToSupport.guid.."_rp_2", lat=defenseBoundingBox[2].latitude, lon=defenseBoundingBox[2].longitude})
            rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_tan_d_miss_"..unitToSupport.guid.."_rp_3", lat=defenseBoundingBox[3].latitude, lon=defenseBoundingBox[3].longitude})
            rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_tan_d_miss_"..unitToSupport.guid.."_rp_4", lat=defenseBoundingBox[4].latitude, lon=defenseBoundingBox[4].longitude})
            -- Create Mission
            createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_tan_d_miss_"..unitToSupport.guid,"support",{zone={rp1.name,rp2.name,rp3.name,rp4.name}})
            ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Passive")
            -- Add Guid And Add Time Stamp
            PersistentAddGUID(args.shortKey.."_tan_d_miss",createdMission.name)
            PersistentAddGUID(args.shortKey.."_def_tan_hva_cov",unitToSupport.guid)
        end
    end
    -- Loop Through Coverted HVAs Missions
    for k, v in pairs(coveredHVAs) do
        -- Local Covered HVA
        local coveredHVA = ScenEdit_GetUnit({side=side.name,guid=v})
        -- Check Condition
        if coveredHVA then
            -- Updated Mission
            updatedMission = ScenEdit_GetMission(side.name,args.shortKey.."_tan_d_miss_"..coveredHVA.guid)
            -- Check Defense Mission
            if updatedMission then
                -- Add Reinforcement Request
                AddReinforcementRequest(args.shortKey,args.options,side.name,updatedMission.name,1)
            end
        end
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Defend AEW Doctrine Create Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function DefendAEWDoctrineCreateUpdateMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_aew_d_miss")
    local createdMission = nil
    local updatedMission = nil
    -- Boxes And Coordinates
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local rp1,rp2,rp3,rp4 = nil
    local supportBoundingBox = {}
    -- Inventory And HVA And Contacts
    local totalHVAs = MemoryGetGUIDFromKey(args.shortKey.."_def_hva")
    local coveredHVAs = PersistentGetGUID(args.shortKey.."_def_aew_hva_cov")
    local unitToSupport = nil
    -- Condition Check
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
                unitToSupport = ScenEdit_GetUnit({side=side.name, guid=v})
                break
            end
        end
        -- Check If No Unit To Defend
        if unitToSupport then
            -- Set Contact Bounding Box Variables
            defenseBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(unitToSupport.latitude,unitToSupport.longitude)},0.5)
            -- Set Reference Points
            rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aew_d_miss_"..unitToSupport.guid.."_rp_1", lat=defenseBoundingBox[1].latitude, lon=defenseBoundingBox[1].longitude})
            rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aew_d_miss_"..unitToSupport.guid.."_rp_2", lat=defenseBoundingBox[2].latitude, lon=defenseBoundingBox[2].longitude})
            rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aew_d_miss_"..unitToSupport.guid.."_rp_3", lat=defenseBoundingBox[3].latitude, lon=defenseBoundingBox[3].longitude})
            rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aew_d_miss_"..unitToSupport.guid.."_rp_4", lat=defenseBoundingBox[4].latitude, lon=defenseBoundingBox[4].longitude})
            -- Create Mission
            createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_aew_d_miss_"..unitToSupport.guid,"support",{zone={rp1.name,rp2.name,rp3.name,rp4.name}})
            ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Active")
            -- Add Guid And Add Time Stamp
            PersistentAddGUID(args.shortKey.."_aew_d_miss",createdMission.name)
            PersistentAddGUID(args.shortKey.."_def_aew_hva_cov",unitToSupport.guid)
        end
    else
        -- Loop Through Coverted HVAs Missions
        for k, v in pairs(coveredHVAs) do
            -- Local Covered HVA
            local coveredHVA = ScenEdit_GetUnit({side=side.name,guid=v})
            -- Check Condition
            if coveredHVA then
                updatedMission = ScenEdit_GetMission(side.name,args.shortKey.."_aew_d_miss_"..coveredHVA.guid)
                -- Check Defense Mission
                if updatedMission then
                    -- Add Reinforcement Request
                    AddReinforcementRequest(args.shortKey,args.options,side.name,updatedMission.name,1)
                end
            end
        end
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Neutral Ship Doctrine Create Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function NeutralShipDoctrineCreateUpdateMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_ship_sc_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactBoundingBox = {}
    local createdUpdatedMission = {}
    local allocatedUnits = {}
    -- Create Mission
    if #missions == 0 then
        -- Check
        local freeShipInventory = GetFreeSurfaceShipInventory(args.shortKey)
        -- Loop And Create Missions
        for k,v in pairs(freeShipInventory) do
            local unit = ScenEdit_GetUnit({side=side.name, guid=v})
            local assignedGuid = v
            local boundingBox = {}
            -- Assigned Guid
            if unit.group then
                assignedGuid = unit.group.guid
            end
            -- Not Found Create Mission
            if not allocatedUnits[assignedGuid] then
                -- Allocated Unit
                allocatedUnits[assignedGuid] = assignedGuid
                -- Create Defense Bounding Box
                boundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(unit.latitude,unit.longitude)},1)
                -- Add Reference Points
                rp1 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_ship_sc_miss_"..tostring(missionNumber).."_rp_1",lat=boundingBox[1].latitude,lon=boundingBox[1].longitude,relativeto=unit.guid})
                rp2 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_ship_sc_miss_"..tostring(missionNumber).."_rp_2",lat=boundingBox[2].latitude,lon=boundingBox[2].longitude,relativeto=unit.guid})
                rp3 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_ship_sc_miss_"..tostring(missionNumber).."_rp_3",lat=boundingBox[3].latitude,lon=boundingBox[3].longitude,relativeto=unit.guid})
                rp4 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_ship_sc_miss_"..tostring(missionNumber).."_rp_4",lat=boundingBox[4].latitude,lon=boundingBox[4].longitude,relativeto=unit.guid})
                -- Created Mission
                createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_ship_sc_miss_"..tostring(missionNumber),"patrol",{type="mixed",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
                ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true})
                -- Assign Units
                ScenEdit_AssignUnitToMission(assignedGuid,createdUpdatedMission.guid)
                -- Increment
                missionNumber = missionNumber + 1
                -- Add Guid
                PersistentAddGUID(args.shortKey.."_ship_sc_miss",createdUpdatedMission.name)
            end
        end
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Neutral Submarine Doctrine Create Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function NeutralSubmarineDoctrineCreateUpdateMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_sub_sc_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactBoundingBox = {}
    local createdUpdatedMission = {}
    local allocatedUnits = {}
    -- Create Mission
    if #missions == 0 then
        -- Check
        local freeShipInventory = GetFreeSubmarineInventory(args.shortKey)
        -- Loop And Create Missions
        for k,v in pairs(freeShipInventory) do
            local unit = ScenEdit_GetUnit({side=side.name, guid=v})
            local assignedGuid = v
            local boundingBox = {}
            -- Assigned Guid
            if unit.group then
                assignedGuid = unit.group.guid
            end
            -- Not Found Create Mission
            if not allocatedUnits[assignedGuid] then
                -- Allocated Unit
                allocatedUnits[assignedGuid] = assignedGuid
                -- Create Defense Bounding Box
                boundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(unit.latitude,unit.longitude)},1)
                -- Add Reference Points
                rp1 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_sub_sc_miss_"..tostring(missionNumber).."_rp_1",lat=boundingBox[1].latitude,lon=boundingBox[1].longitude,relativeto=unit.guid})
                rp2 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_sub_sc_miss_"..tostring(missionNumber).."_rp_2",lat=boundingBox[2].latitude,lon=boundingBox[2].longitude,relativeto=unit.guid})
                rp3 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_sub_sc_miss_"..tostring(missionNumber).."_rp_3",lat=boundingBox[3].latitude,lon=boundingBox[3].longitude,relativeto=unit.guid})
                rp4 = ScenEdit_AddReferencePoint({side=side.name,name=args.shortKey.."_sub_sc_miss_"..tostring(missionNumber).."_rp_4",lat=boundingBox[4].latitude,lon=boundingBox[4].longitude,relativeto=unit.guid})
                -- Created Mission
                createdUpdatedMission = ScenEdit_AddMission(side.name,args.shortKey.."_sub_sc_miss_"..tostring(missionNumber),"patrol",{type="mixed",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
                ScenEdit_SetMission(side.name,createdUpdatedMission.name,{checkOPA=false,checkWWR=true})
                -- Assign Units
                ScenEdit_AssignUnitToMission(assignedGuid,createdUpdatedMission.guid)
                -- Increment
                missionNumber = missionNumber + 1
                -- Add Guid
                PersistentAddGUID(args.shortKey.."_sub_sc_miss",createdUpdatedMission.name)
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
    -- Inventory And HVA And Contacts
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
    -- Inventory And HVA And Contacts
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
        -- Zone Counter Check
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
    -- Inventory And HVA And Contacts
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
    -- Inventory And HVA And Contacts
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
        -- Zone Counter Check
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
-- Hampton - Retreat Positions And EMCON
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
    for k,v in pairs(missions) do
        -- Local Values
        local updatedMission = ScenEdit_GetMission(side.name,v)
        local missionUnits = GetUnitsFromMission(side.name,updatedMission.guid)
        -- Determine Retreat
        DetermineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,100)
        -- Determine EMCON
        DetermineEmconToUnits(args.shortKey,args.options,side.name,missionUnits)
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
    local missionUnits = GetUnitsFromMission(side.name,updatedMission.guid)
    -- Determine Retreat
    DetermineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,1,100)
    -- Determine EMCON
    DetermineEmconToUnits(args.shortKey,args.options,side.name,missionUnits)
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
    local missionUnits = GetUnitsFromMission(side.name,updatedMission.guid)
    -- Determine Unit To Retreat
    DetermineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,70)
    -- Determine EMCON
    DetermineEmconToUnits(args.shortKey,args.options,side.name,missionUnits)
    -- Return False
    return false
end

function HamptonUpdateUnitsInOffensiveSeadMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_sead_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then
        return false
    end
    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Return Point
    local missionUnits = GetUnitsFromMission(side.name,updatedMission.guid)
    -- Determine Retreat
    DetermineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,2,70)
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
    local missionUnits = GetUnitsFromMission(side.name,updatedMission.guid)
    -- Determine Retreat
    DetermineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,70)
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
    local missionUnits = GetUnitsFromMission(side.name,updatedMission.guid)
    -- Determine Retreat
    DetermineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,3,70)
    -- Determine EMCON
    DetermineEmconToUnits(args.shortKey,args.options,side.name,missionUnits)
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
    local missionUnits = GetUnitsFromMission(side.name,updatedMission.guid)
    -- Determine Retreat
    DetermineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,200)
    -- Return False
    return false
end

function HamptonUpdateUnitsInOffensiveTankerMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_atan_miss")
    local updatedMission = {}
    -- Condition Check
    if #missions == 0 then
        return false
    end
    -- Get Linked Mission
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    -- Find Area And Retreat Point
    local missionUnits = GetUnitsFromMission(side.name,updatedMission.guid)
    -- Determine Retreat
    DetermineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,200)
    -- Return False
    return false
end

function HamptonUpdateUnitsInSupportAEWMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_aew_d_miss")
    local updatedMission = nil
    -- Condition Check
    if #missions == 0 then
        return false
    end
    -- Loop Through Coverted HVAs Missions
    for k, v in pairs(missions) do
        -- Update Mission
        updatedMission = ScenEdit_GetMission(side.name,v)
        -- Check Defense Mission
        if updatedMission then
            -- Determine Units To Assign
            local missionUnits = updatedMission.unitlist
            -- Determine Retreat
            DetermineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,200)
        end
    end
    -- Return False
    return false
end

function HamptonUpdateUnitsInSupportTankerMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = PersistentGetGUID(args.shortKey.."_tan_d_miss")
    local updatedMission = nil
    -- Condition Check
    if #missions == 0 then
        return false
    end
    -- Loop Through Coverted HVAs Missions
    for k, v in pairs(missions) do
        -- Updated Mission
        updatedMission = ScenEdit_GetMission(side.name,v)
        -- Check Defense Mission
        if updatedMission then
            -- Find Contact Close To Unit And Retreat If Necessary
            local missionUnits = updatedMission.unitlist
            -- Determine Retreat
            DetermineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,0,200)
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
    -- Loop Through Coverted HVAs Missions
    for k, v in pairs(missions) do
        -- Get Defense Mission
        updatedMission = ScenEdit_GetMission(side.name,v)
        -- Check Defense Mission
        if updatedMission then
            -- Find Area And Return Point
            local missionUnits = GetUnitsFromMission(side.name,updatedMission.guid)
            -- Determine Retreat
            DetermineUnitToRetreat(args.shortKey,args.guid,args.options,updatedMission.guid,missionUnits,1,100)
            -- Determine EMCON
            DetermineEmconToUnits(args.shortKey,args.options,side.name,missionUnits)
        end
    end
    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Cumberland - Air Reinforcement Requests Actions
--------------------------------------------------------------------------------------------------------------------------------
function CumberlandUpdateAirReinforcementRequestsAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local reconMissions = PersistentGetGUID(args.shortKey.."_rec_miss")
    local airMissions = PersistentGetGUID(args.shortKey.."_aaw_miss")
    local stealthAirMissions = PersistentGetGUID(args.shortKey.."_saaw_miss")
    local aewMissions = PersistentGetGUID(args.shortKey.."_aaew_miss")
    local tankerMissions = PersistentGetGUID(args.shortKey.."_atan_miss")
    local antiSurfaceMissions = PersistentGetGUID(args.shortKey.."_asuw_miss")
    local seadMissions = PersistentGetGUID(args.shortKey.."_sead_miss")
    local landMissions = PersistentGetGUID(args.shortKey.."_land_miss")
    local airDefenseMissions = PersistentGetGUID(args.shortKey.."_aaw_d_miss")
    local tankerDefenseMissions = PersistentGetGUID(args.shortKey.."_tan_d_miss")
    local aewDefenseMissions = PersistentGetGUID(args.shortKey.."_aew_d_miss")
    -- Local Reinforcements Requests
    local reinforcementRequests = GetReinforcementRequests(args.shortKey)
    local determinedModifier = args.options.determined * 2 / (args.options.determined + args.options.reserved)

    -- Reinforce Recon Missions
    for k,v in pairs(reconMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        -- Determine If There Is An Reinforcement Request
        if reinforceNumber then
            -- Unassign Units
            DetermineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            -- Reinforce With Free Recon Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirReconInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Free UAV Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirUAVInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Free Stealth Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirStealthInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Free Sead Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirSeadInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Recon Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirReconInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy UAV Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirUAVInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Stealth Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirStealthInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Sead Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirSeadInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end

    -- Reinforce Air Missions
    for k,v in pairs(airMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        -- Determine If There Is An Reinforcement Request
        if reinforceNumber then
            -- Unassign Units
            DetermineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            -- Reinforce With Free Fighter Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirFighterInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Free Multirole Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirMultiroleInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Fighter Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirFighterInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Multirole Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirMultiroleInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end

    -- Reinforce Air Stealth Missions
    for k,v in pairs(stealthAirMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        -- Determine If There Is An Reinforcement Request
        if reinforceNumber then
            -- Unassign Units
            DetermineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            -- Reinforce With Free Stealth Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirStealthInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Stealth Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirStealthInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end

    -- Reinforce Air AEW Missions
    for k,v in pairs(aewMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        -- Determine If There Is An Reinforcement Request
        if reinforceNumber then
            -- Unassign Units
            DetermineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            -- Reinforce With Free AEW Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirAEWInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy AEW Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirAEWInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end

    -- Reinforce Air Tanker Missions
    for k,v in pairs(tankerMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        -- Determine If There Is An Reinforcement Request
        if reinforceNumber then
            -- Unassign Units
            DetermineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            -- Reinforce With Free Tanker Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirTankerInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Tanker Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirTankerInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end

    -- Reinforce Air Anti-Surface Missions
    for k,v in pairs(antiSurfaceMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        -- Determine If There Is An Reinforcement Request
        if reinforceNumber then
            -- Unassign Units
            DetermineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            -- Reinforce With Free ASUW Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirASuWInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Free ASUW Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirMultiroleInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy ASUW Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirASuWInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy ASUW Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirMultiroleInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end

    -- Reinforce Air Attack Missions
    for k,v in pairs(landMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        -- Determine If There Is An Reinforcement Request
        if reinforceNumber then
            -- Unassign Units
            DetermineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            -- Reinforce With Free Atk Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirAttackInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Free Multirole Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirMultiroleInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Atk Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirAttackInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Multirole Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirMultiroleInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end

    -- Reinforce Air SEAD Missions
    for k,v in pairs(seadMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        -- Determine If There Is An Reinforcement Request
        if reinforceNumber then
            -- Unassign Units
            DetermineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            -- Reinforce With Free Sead Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirSeadInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Free Atk Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirAttackInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Free Multirole Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirMultiroleInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Sead Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirSeadInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Atk Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirAttackInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Multirole Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirMultiroleInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end

    

    -- Reinforce Air Defensive Missions
    for k,v in pairs(airDefenseMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        -- Determine If There Is An Reinforcement Request
        if reinforceNumber then
            -- Unassign Units
            DetermineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            -- Reinforce With Free Fighter Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirFighterInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Free Stealth Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirStealthInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Free Multirole Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirMultiroleInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Fighter Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirFighterInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Stealth Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirStealthInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Multirole Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirMultiroleInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end

    -- Reinforce Air Defensive AEW Missions
    for k,v in pairs(aewDefenseMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        -- Determine If There Is An Reinforcement Request
        if reinforceNumber then
            -- Unassign Units
            DetermineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            -- Reinforce With Free AEW Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirAEWInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy AEW Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirAEWInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
        end
    end

    -- Reinforce Air Defensive Tanker Missions
    for k,v in pairs(tankerDefenseMissions) do
        local mission = ScenEdit_GetMission(side.name,v)
        local reinforceNumber = reinforcementRequests[v]
        local missionReinforced = false
        local reinforceInventory = {}
        -- Determine If There Is An Reinforcement Request
        if reinforceNumber then
            -- Unassign Units
            DetermineUnitsToUnAssign(args.shortKey,side.name,mission.guid)
            -- Reinforce With Free Tanker Units
            if not missionReinforced then
                reinforceInventory = GetFreeAirTankerInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
            -- Reinforce With Busy Tanker Units
            if not missionReinforced then
                reinforceInventory = GetBusyAirTankerInventory(args.shortKey)
                missionReinforced = DetermineUnitsToAssign(args.shortKey,side.name,mission.guid,reinforceNumber,reinforceInventory)
            end
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
    ----------------------------------------------------------------------------------------------------------------------------
    -- Merrimack Selector
    ----------------------------------------------------------------------------------------------------------------------------
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
    -- Recon Doctrine BT
    local reconDoctrineCreateUpdateMissionBT = BT:make(ReconDoctrineCreateUpdateMissionAction,sideGuid,shortSideKey,attributes)
    -- Attack Doctrine BT
    local attackDoctrineCreateUpdateAirMissionBT = BT:make(AttackDoctrineCreateUpdateAirMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateUpdateStealthAirMissionBT = BT:make(AttackDoctrineCreateUpdateStealthAirMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateUpdateAEWMissionBT = BT:make(AttackDoctrineCreateUpdateAEWMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateUpdateTankerMissionBT = BT:make(AttackDoctrineCreateUpdateTankerMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateUpdateAntiSurfaceShipMissionBT = BT:make(AttackDoctrineCreateUpdateAntiSurfaceShipMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateUpdateSeadMissionBT = BT:make(AttackDoctrineCreateUpdateSeadMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateUpdateLandAttackMissionBT = BT:make(AttackDoctrineCreateUpdateLandAttackMissionAction,sideGuid,shortSideKey,attributes)
    -- Defend Doctrine BT
    local defendDoctrineCreateUpdateAirMissionBT = BT:make(DefendDoctrineCreateUpdateAirMissionAction,sideGuid,shortSideKey,attributes)
    local defendTankerDoctrineCreateUpdateMissionBT = BT:make(DefendTankerDoctrineCreateUpdateMissionAction,sideGuid,shortSideKey,attributes)
    local defendAEWDoctrineCreateUpdateMissionBT = BT:make(DefendAEWDoctrineCreateUpdateMissionAction,sideGuid,shortSideKey,attributes)
    -- Neutral Doctrine BT
    local neutralShipDoctrineCreateUpdateMissionBT = BT:make(NeutralShipDoctrineCreateUpdateMissionAction,sideGuid,shortSideKey,attributes)
    local neutralSubmarineDoctrineCreateUpdateMissionBT = BT:make(NeutralSubmarineDoctrineCreateUpdateMissionAction,sideGuid,shortSideKey,attributes)

    -- Build AI Tree
    merrimackSelector:addChild(offensiveDoctrineSequence)
    merrimackSelector:addChild(defensiveDoctrineSequence)
    -- Offensive and Defensive Sequence
    offensiveDoctrineSequence:addChild(offensiveDoctrineConditionalBT)
    offensiveDoctrineSequence:addChild(offensiveDoctrineSeletor)
    defensiveDoctrineSequence:addChild(defensiveDoctrineConditionalBT)
    defensiveDoctrineSequence:addChild(defensiveDoctrineSeletor)
    -- Offensive Selector
    offensiveDoctrineSeletor:addChild(reconDoctrineSelector)
    offensiveDoctrineSeletor:addChild(attackDoctrineSelector)
    -- Defensive Selector
    defensiveDoctrineSeletor:addChild(reconDoctrineSelector)
    defensiveDoctrineSeletor:addChild(defendDoctrineSelector)
    -- Recon Doctrine Sequence
    reconDoctrineSelector:addChild(reconDoctrineCreateUpdateMissionBT)
    -- Attack Doctrine Sequence
    attackDoctrineSelector:addChild(attackDoctrineCreateUpdateAirMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateUpdateStealthAirMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateUpdateAEWMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateUpdateTankerMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateUpdateAntiSurfaceShipMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateUpdateSeadMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateUpdateLandAttackMissionBT)
    attackDoctrineSelector:addChild(neutralShipDoctrineCreateUpdateMissionBT)
    attackDoctrineSelector:addChild(neutralSubmarineDoctrineCreateUpdateMissionBT)
    -- Defend Doctrine Sequence
    defendDoctrineSelector:addChild(defendDoctrineCreateUpdateAirMissionBT)
    defendDoctrineSelector:addChild(defendTankerDoctrineCreateUpdateMissionBT)
    defendDoctrineSelector:addChild(defendAEWDoctrineCreateUpdateMissionBT)
    defendDoctrineSelector:addChild(neutralShipDoctrineCreateUpdateMissionBT)
    defendDoctrineSelector:addChild(neutralSubmarineDoctrineCreateUpdateMissionBT)
    ----------------------------------------------------------------------------------------------------------------------------
    -- Monitor Selector
    ----------------------------------------------------------------------------------------------------------------------------
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
    ----------------------------------------------------------------------------------------------------------------------------
    -- Hampton Selector
    ----------------------------------------------------------------------------------------------------------------------------
    local hamptonSelector = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    local hamptonUpdateReconBT = BT:make(HamptonUpdateUnitsInReconMissionAction,sideGuid,shortSideKey,attributes)
    local hamptonUpdateOffAirBT = BT:make(HamptonUpdateUnitsInOffensiveAirMissionAction,sideGuid,shortSideKey,attributes)
    local hamptonUpdateOffStealthAirBT = BT:make(HamptonUpdateUnitsInOffensiveStealthAirMissionAction,sideGuid,shortSideKey,attributes)
    local hamptonUpdateOffAEWBT = BT:make(HamptonUpdateUnitsInOffensiveAEWMissionAction,sideGuid,shortSideKey,attributes)
    local hamptonUpdateOffTankerBT = BT:make(HamptonUpdateUnitsInOffensiveTankerMissionAction,sideGuid,shortSideKey,attributes)
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
    hamptonSelector:addChild(hamptonUpdateOffTankerBT)
    hamptonSelector:addChild(hamptonUpdateOffAntiSurfBT)
    hamptonSelector:addChild(hamptonUpdateOffSeadBT)
    hamptonSelector:addChild(hamptonUpdateOffLandBT)
    hamptonSelector:addChild(hamptonUpdateDefAirBT)
    hamptonSelector:addChild(hamptonUpdateSupTankerBT)
    hamptonSelector:addChild(hamptonUpdateSupAEWBT)
    ----------------------------------------------------------------------------------------------------------------------------
    -- Cumberland Selector
    ----------------------------------------------------------------------------------------------------------------------------
    local cumberlandSelector = BT:make(BT.select,sideGuid,shortSideKey,attributes)
    local cumberlandUpdateAirReinforceRequestsBT = BT:make(CumberlandUpdateAirReinforcementRequestsAction,sideGuid,shortSideKey,attributes)
    -- Setup Hampton
    cumberlandSelector:addChild(cumberlandUpdateAirReinforceRequestsBT)
    ----------------------------------------------------------------------------------------------------------------------------
    -- Add To Arrays
    ----------------------------------------------------------------------------------------------------------------------------
    commandMerrimackAIArray[#commandMerrimackAIArray + 1] = merrimackSelector
    commandMonitorAIArray[#commandMonitorAIArray + 1] = monitorSelector
    commandHamptonAIArray[#commandHamptonAIArray + 1] = hamptonSelector
    commandCumberlandAIArray[#commandCumberlandAIArray + 1] = cumberlandSelector
end

function UpdateAI()
    -- Reset All Inventories
    ResetAllInventoriesAndContacts()
    -- Update Inventories And Update Merrimack AI
    for k, v in pairs(commandMerrimackAIArray) do
        UpdateAIInventories(v.guid,v.shortKey)
        -- Update AO
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
    -- Update Cumberland AI
    for k, v in pairs(commandCumberlandAIArray) do
        v:run()
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Global Call
--------------------------------------------------------------------------------------------------------------------------------
InitializeMerrimackMonitorAI("South Korea",{preset="Sheridan"})