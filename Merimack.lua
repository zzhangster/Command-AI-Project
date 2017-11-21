--[[
  This behavior tree code was taken from our Zelda AI project for CMPS 148 at UCSC.
  It is for the most part unmodified, and comments are available for each function.
  Behavior tree code credited to Kevin Cameron
]]--
BT = {}
BT.__index = BT
BT.results = {success = "success", fail = "fail", wait = "wait", error = "error"}
local commandMerimackAIArray = {}
local commandMonitorAIArray = {}

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
function BT:make(action,guid,shortKey)
    local instance = {}
    setmetatable(instance, BT)
    instance.children = {}
    instance.guid = guid
    instance.shortKey = shortKey
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
function MakeLatLong(latitude,longitude)
    local instance = {}
    instance.latitude = latitude
    instance.longitude = longitude
    return instance
end

function MidPointCoordinate(lat1,lon1,lat2,lon2)
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
    --ScenEdit_SpecialMessage("Blue Force", ""..tostring(origin.latitude)..","..tostring(origin.longitude)..","..tostring(bearing)..","..tostring(range))
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
    --ScenEdit_SpecialMessage("Blue Force", ""..tostring(math.deg(endLatRads))..","..tostring(math.deg(endLonRads)))
    return MakeLatLong(math.deg(endLatRads),math.deg(endLonRads))
end

function FindBoundingBoxForGivenLocations(coordinates,padding)
    local west = 0.0
    local east = 0.0
    local north = 0.0
    local south = 0.0

    -- Assign Up to numberOfReconToAssign
    for lc = 1,#coordinates do
        local loc = coordinates[lc]

        --ScenEdit_SpecialMessage("Red Force", "Coordinate: "..loc.latitude.." "..loc.longitude)

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
    west = west - 2 * padding
    east = east + 2 * padding

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

function DetermineRoleFromLoadOutDatabase(loudoutId,defaultRole)
    local role = ScenEdit_GetKeyValue("lo_"..tostring(loudoutId))
    --ScenEdit_SpecialMessage("Blue Force","lo_"..tostring(loudoutId))
    if role == nil then
        return defaultRole
    else
        return role
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
-- Save GUID Functions
--------------------------------------------------------------------------------------------------------------------------------
function RemoveAllGUID(primaryKey)
    ScenEdit_SetKeyValue(primaryKey,"")
end

function GetGUID(primaryKey)
    local guidString = ScenEdit_GetKeyValue(primaryKey)
    if guidString == nil then
        guidString = ""
    end
    return Split(guidString,",")
end

function AddGUID(primaryKey,guid)
    local guidString = ScenEdit_GetKeyValue(primaryKey)
    if guidString == nil then
        guidString = guid
    else
        guidString = guidString..","..guid
    end
    ScenEdit_SetKeyValue(primaryKey,guidString)
end

function RemoveGUID(primaryKey,guid)
    local table = GetGUID(primaryKey)
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

function GUIDExists(primaryKey,guid)
    local table = GetGUID(primaryKey)
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
    --ScenEdit_SpecialMessage("Blue Force", "GetTimeStampForGUID - 1")
    if timeStamp == "" or timeStamp == nil then
        --ScenEdit_SpecialMessage("Blue Force", "GetTimeStampForGUID - 2")
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
    local hostileAirContacts = GetHostileAirContacts(shortSideKey)
    for k,v in pairs(hostileAirContacts) do
        local contact = ScenEdit_GetContact({side=side.name, guid=v})
        local currentRange = Tool_Range(contact.guid,unitGuid)
        if currentRange < range then
            local bearing = Tool_Bearing(contact.guid,unitGuid)
            return ProjectLatLong(MakeLatLong(contact.latitude,contact.longitude),bearing,range + 10)
        end
    end
    -- Return 
    return nil
end

function GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    -- Local Side And Mission
    local side = VP_GetSide({guid=sideGuid})
    local zones = GetGUID(shortSideKey.."_sam_ex_zone")
    -- Zone Reference Points
    local zoneReferencePoints = ScenEdit_GetReferencePoints({side=side.name, area=zones})
    for k,v in pairs(zoneReferencePoints) do
        local currentRange = Tool_Range({latitude=v.latitude,longitude=v.longitude},unitGuid)
        local desiredRange = tonumber(v.name)
        if currentRange < desiredRange then
            local contactPoint = MakeLatLong(v.latitude,v.longitude)
            local bearing = Tool_Bearing({latitude=contactPoint.latitude,longitude=contactPoint.longitude},unitGuid)
            return ProjectLatLong(contactPoint,bearing,tonumber(v.name)+10)
        end
    end
    -- Return False
    return nil
end

function GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    -- Local Side And Mission
    local side = VP_GetSide({guid=sideGuid})
    local zones = GetGUID(shortSideKey.."_ship_ex_zone")
    -- Zone Reference Points
    local zoneReferencePoints = ScenEdit_GetReferencePoints({side=side.name, area=zones})
    for k,v in pairs(zoneReferencePoints) do
        local currentRange = Tool_Range({latitude=v.latitude,longitude=v.longitude},unitGuid)
        local desiredRange = tonumber(v.name)
        if currentRange < desiredRange then
            local contactPoint = MakeLatLong(v.latitude,v.longitude)
            local bearing = Tool_Bearing({latitude=contactPoint.latitude,longitude=contactPoint.longitude},unitGuid)
            return ProjectLatLong(contactPoint,bearing,tonumber(v.name)+10)
        end
    end
    -- Return False
    return nil
end

function GetSAMAndShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    local contactPoint = GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    if contactPoint ~= nil then
        return contactPoint
    else
        contactPoint = GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
        return contactPoint
    end
end

function GetAirAndShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid,airRange)
    local contactPoint = GetAirNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,unitGuid,airRange)
    if contactPoint ~= nil then
        return contactPoint
    else
        contactPoint = GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
        return contactPoint
    end
end

function GetAirAndSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid,airRange)
    local contactPoint = GetAirNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,unitGuid,airRange)
    if contactPoint ~= nil then
        return contactPoint
    else
        contactPoint = GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
        return contactPoint
    end
end

function GetAllNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,unitGuid,airRange)
    local contactPoint = GetAirNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,unitGuid,airRange)
    if contactPoint ~= nil then
        return contactPoint
    else
        contactPoint = GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
        if contactPoint ~= nil then
            return contactPoint
        else
            contactPoint = GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
            return contactPoint
        end
    end
end
--------------------------------------------------------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------------------------------------------------------
function Split(s, sep)
    local fields = {}
    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated Fighter Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirFighterInventory(sideShortKey)
    return GetGUID(sideShortKey.."_fig_free")
end

function GetBusyAirFighterInventory(sideShortKey)
    return GetGUID(sideShortKey.."_fig_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Multirole AA Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirMultiroleInventory(sideShortKey)
    return GetGUID(sideShortKey.."_mul_free")
end

function GetBusyAirMultiroleInventory(sideShortKey)
    return GetGUID(sideShortKey.."_mul_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Attack Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirAttackInventory(sideShortKey)
    return GetGUID(sideShortKey.."_atk_free")
end

function GetBusyAirAttackInventory(sideShortKey)
    return GetGUID(sideShortKey.."_atk_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get SEAD Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirSeadInventory(sideShortKey)
    return GetGUID(sideShortKey.."_sead_free")
end

function GetBusyAirSeadInventory(sideShortKey)
    return GetGUID(sideShortKey.."_sead_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated AEW Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirAEWInventory(sideShortKey)
    return GetGUID(sideShortKey.."_aew_free")
end

function GetBusyAirAEWInventory(sideShortKey)
    return GetGUID(sideShortKey.."_aew_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated ASuW Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirASuWInventory(sideShortKey)
    return GetGUID(sideShortKey.."_asuw_free")
end

function GetBusyAirASuWInventory(sideShortKey)
    return GetGUID(sideShortKey.."_asuw_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated ASW Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirASWInventory(sideShortKey)
    return GetGUID(sideShortKey.."_asw_free")
end

function GetBusyAirASWInventory(sideShortKey)
    return GetGUID(sideShortKey.."_asw_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated Recon Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirReconInventory(sideShortKey)
    return GetGUID(sideShortKey.."_rec_free")
end

function GetBusyAirReconInventory(sideShortKey)
    return GetGUID(sideShortKey.."_rec_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated Tanker Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirTankerInventory(sideShortKey)
    return GetGUID(sideShortKey.."_tan_free")
end

function GetBusyAirTankerInventory(sideShortKey)
    return GetGUID(sideShortKey.."_tan_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated UAV Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirUAVInventory(sideShortKey)
    return GetGUID(sideShortKey.."_uav_free")
end

function GetBusyAirUAVInventory(sideShortKey)
    return GetGUID(sideShortKey.."_uav_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated UCAV Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirUCAVInventory(sideShortKey)
    return GetGUID(sideShortKey.."_ucav_free")
end

function GetBusyAirUCAVInventory(sideShortKey)
    return GetGUID(sideShortKey.."_ucav_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated Surface Ship Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeSurfaceShipInventory(sideShortKey)
    return GetGUID(sideShortKey.."_surf_free")
end

function GetBusySurfaceShipInventory(sideShortKey)
    return GetGUID(sideShortKey.."_surf_busy")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated Submarine Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeSubmarineInventory(sideShortKey)
    return GetGUID(sideShortKey.."_sub_free")
end

function GetBusySubmarineInventory(sideShortKey)
    return GetGUID(sideShortKey.."_sub_busy")
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
    return GetGUID(sideShortKey.."_air_con_X")
end

function GetHostileAirContacts(sideShortKey)
    return GetGUID(sideShortKey.."_air_con_H")
end

function GetUnknownSurfaceShipContacts(sideShortKey)
    return GetGUID(sideShortKey.."_surf_con_X")
end

function GetHostileSurfaceShipContacts(sideShortKey)
    return GetGUID(sideShortKey.."_surf_con_H")
end

function GetUnknownSubmarineContacts(sideShortKey)
    return GetGUID(sideShortKey.."_sub_con_X")
end

function GetHostileSubmarineContacts(sideShortKey)
    return GetGUID(sideShortKey.."_sub_con_H")
end

function GetUnknownBaseContacts(sideShortKey)
    return GetGUID(sideShortKey.."_base_con_X")
end

function GetHostileBaseContacts(sideShortKey)
    return GetGUID(sideShortKey.."_base_con_H")
end

function GetUnknownSAMContacts(sideShortKey)
    return GetGUID(sideShortKey.."_sam_con_X")
end

function GetHostileSAMContacts(sideShortKey)
    return GetGUID(sideShortKey.."_sam_con_H")
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

--------------------------------------------------------------------------------------------------------------------------------
-- Inventory Check
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

    -- Rest Inventories And Contacts
    ResetInventoriesAndContacts(sideShortKey)

    -- Loop Through Aircraft Inventory By Subtypes And Readiness
    if aircraftInventory then
        for k, v in pairs(aircraftInventory) do
            -- Local Values
            local unit = ScenEdit_GetUnit({side=side.name, guid=v.guid})
            local unitType = "non"
            local unitStatus = "unav"

            -- Get Status
            if unit.mission == nil and unit.loadoutdbid ~= nil and unit.loadoutdbid ~= 3 and unit.loadoutdbid ~= 4 then
                unitStatus = "free"
            elseif unit.mission ~= nil and unit.loadoutdbid ~= nil and unit.loadoutdbid ~= 3 and unit.loadoutdbid ~= 4 then
                unitStatus = "busy"
            end

            -- Fighter
            if unit.subtype == "2001" then
                unitType = "fig"
            -- Multirole
            elseif unit.subtype == "2002" then
                unitType = DetermineRoleFromLoadOutDatabase(unit.loadoutdbid,"mul")
            -- Attacker
            elseif unit.subtype == "3001" then
                unitType = "atk"
            -- SEAD
            elseif unit.subtype == "4001" then
                unitType = "sead"
            -- AEW
            elseif unit.subtype == "4002" then
                unitType = "aew"
            -- ASW
            elseif unit.subtype == "6002" then
                unitType = "asw"
            -- Recon
            elseif unit.subtype == "7003" then
                unitType = "rec"
            -- Tanker
            elseif unit.subtype == "8001" then
                unitType = "tan"
            -- UAV
            elseif unit.subtype == "8201" then
                unitType = "uav"
            -- UCAV
            elseif unit.subtype == "8002" then
                unitType = "ucav"
            end

            --ScenEdit_SpecialMessage("Blue Force", "Inventory - "..sideShortKey.."_"..unit.name.."_".."_"..unitType.."_"..unitStatus.."_"..unit.subtype)
            AddGUID(sideShortKey.."_"..unitType.."_"..unitStatus,unit.guid)
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
                AddGUID(sideShortKey.."_def_hvt",unit.guid)
            end

            -- Save Unit GUID
            AddGUID(sideShortKey.."_"..unitType.."_"..unitStatus,unit.guid)
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
            AddGUID(sideShortKey.."_"..unitType.."_"..unitStatus,unit.guid)
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

            --ScenEdit_SpecialMessage("Blue Force", unit.name.."_"..unit.subtype)

            -- Save Unit As HVT (Airport)
            if unit.subtype == "9001" then
                unitType = "base"
                AddGUID(sideShortKey.."_def_hvt",unit.guid)
            elseif unit.subtype == "5001" then
                unitType = "sam"
            end

            -- Save Unit GUID
            AddGUID(sideShortKey.."_"..unitType.."_"..unitStatus,unit.guid)
        end
    end

    -- Loop Through Aircraft Contacts
    if aircraftContacts then
        for k, v in pairs(aircraftContacts) do
            -- Local Values
            local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
            local unitType = "air_con"

            -- Save Unit GUID
            AddGUID(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
        end
    end

    -- Loop Through Aircraft Contacts
    if shipContacts then
        for k, v in pairs(shipContacts) do
            -- Local Values
            local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
            local unitType = "surf_con"

            -- Save Unit GUID
            AddGUID(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
        end
    end

    -- Loop Through Aircraft Contacts
    if submarineContacts then
        for k, v in pairs(submarineContacts) do
            -- Local Values
            local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
            local unitType = "sub_con"

            -- Save Unit GUID
            AddGUID(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
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

            --ScenEdit_SpecialMessage("Blue Force", sideShortKey.."_"..contact.type.."_"..contact.name.."_"..contact.type_description.."_"..contact.posture)
            -- Save Unit GUID
            AddGUID(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
        end
    end
end

function ResetInventoriesAndContacts(sideShortKey)
    -- Reset Inventory And Contacts
    RemoveAllGUID(sideShortKey.."_fig_free")
    RemoveAllGUID(sideShortKey.."_fig_busy")
    RemoveAllGUID(sideShortKey.."_mul_free")
    RemoveAllGUID(sideShortKey.."_mul_busy")
    RemoveAllGUID(sideShortKey.."_atk_free")
    RemoveAllGUID(sideShortKey.."_atk_busy")
    RemoveAllGUID(sideShortKey.."_aew_free")
    RemoveAllGUID(sideShortKey.."_aew_busy")
    RemoveAllGUID(sideShortKey.."_asw_free")
    RemoveAllGUID(sideShortKey.."_asw_busy")
    RemoveAllGUID(sideShortKey.."_asuw_free")
    RemoveAllGUID(sideShortKey.."_asuw_busy")
    RemoveAllGUID(sideShortKey.."_rec_free")
    RemoveAllGUID(sideShortKey.."_rec_busy")
    RemoveAllGUID(sideShortKey.."_tan_free")
    RemoveAllGUID(sideShortKey.."_tan_busy")
    RemoveAllGUID(sideShortKey.."_uav_free")
    RemoveAllGUID(sideShortKey.."_uav_busy")
    RemoveAllGUID(sideShortKey.."_ucav_free")
    RemoveAllGUID(sideShortKey.."_ucav_busy")
    RemoveAllGUID(sideShortKey.."_surf_free")
    RemoveAllGUID(sideShortKey.."_surf_busy")
    RemoveAllGUID(sideShortKey.."_sub_free")
    RemoveAllGUID(sideShortKey.."_sub_busy")
    RemoveAllGUID(sideShortKey.."_land_busy")
    RemoveAllGUID(sideShortKey.."_land_free")
    RemoveAllGUID(sideShortKey.."_base_busy")
    RemoveAllGUID(sideShortKey.."_base_free")
    RemoveAllGUID(sideShortKey.."_sam_busy")
    RemoveAllGUID(sideShortKey.."_sam_free")
    RemoveAllGUID(sideShortKey.."_air_con_X")
    RemoveAllGUID(sideShortKey.."_air_con_H")
    RemoveAllGUID(sideShortKey.."_surf_con_X")
    RemoveAllGUID(sideShortKey.."_surf_con_H")
    RemoveAllGUID(sideShortKey.."_sub_con_X")
    RemoveAllGUID(sideShortKey.."_sub_con_H")
    RemoveAllGUID(sideShortKey.."_land_con_X")
    RemoveAllGUID(sideShortKey.."_land_con_H")
    RemoveAllGUID(sideShortKey.."_base_con_X")
    RemoveAllGUID(sideShortKey.."_base_con_H")
    RemoveAllGUID(sideShortKey.."_sam_con_X")
    RemoveAllGUID(sideShortKey.."_sam_con_H")
end

--------------------------------------------------------------------------------------------------------------------------------
-- Behavior Tree Condition
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
-- Recon Doctrine Mission Actions
--------------------------------------------------------------------------------------------------------------------------------
function ReconDoctrineCreateMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local missions = GetGUID(args.shortKey.."_rec_miss")
    local totalFreeInventory = GetTotalFreeReconInventory(args.shortKey)
    local missionNumber = math.random(4)
    local rp1,rp2,rp3,rp4 = ""

    -- Limit To Four Missions, When 0 Contacts And Has Air Recon Inventory
    if #missions >= 4 or #totalFreeInventory == 0 or GetAllHostileContactStrength(args.shortKey) >= 10 then
        return false
    end

    -- Get A Non Repeating Number
    while GUIDExists(args.shortKey.."_rec_miss",args.shortKey.."_rec_miss_"..tostring(missionNumber)) do
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

    -- Create Recon Mission
    local reconMission = ScenEdit_AddMission(side.name,args.shortKey.."_rec_miss_"..tostring(missionNumber),"patrol",{type="naval",zone={rp1.name,rp2.name,rp3.name,rp4.name}})

    -- Assign Units To Recon Mission
    local totalReconUnitsToAssign = 1
    local numberOfReconToAssign = #totalFreeInventory

    -- Recon and Uav To Assign
    if numberOfReconToAssign > totalReconUnitsToAssign then
        numberOfReconToAssign = totalReconUnitsToAssign
    end

    -- Assign Up to numberOfReconToAssign
    for i = 1,numberOfReconToAssign do
        ScenEdit_AssignUnitToMission(totalFreeInventory[i],reconMission.guid)
    end

    -- Add Guid
    AddGUID(args.shortKey.."_rec_miss",reconMission.name)
    
    -- Return True
    return true
end

function ReconDoctrineUpdateMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_rec_miss")
    local totalFreeBusyInventory = GetTotalFreeBusyReconInventory(args.shortKey)
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local missionNumber = 0
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    -- Time
    local currentTime = ScenEdit_CurrentTime()
    local lastTime = GetTimeStampForGUID(args.shortKey.."_rec_miss_ts")

    -- Check Total Is Zero
    if #totalFreeBusyInventory == 0 or (currentTime - lastTime) < 3 * 60 then
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

        -- Find Contact Close To Unit And Evade
        if #updatedMission.unitlist > 0 then
            local supportUnit = ScenEdit_GetUnit({side=side.name, guid=updatedMission.unitlist[1]})
            local unitRetreatPoint = GetAllNoNavZoneThatContaintsUnit(args.guid,args.shortKey,supportUnit.guid,100)
            -- SAM Retreat Point
            if unitRetreatPoint ~= nil then
            	supportUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            	ScenEdit_SetDoctrine({side=side.name,unitname=supportUnit.name},{ignore_plotted_course = "no" })
        	else
            	ScenEdit_SetDoctrine({side=side.name,unitname=supportUnit.name},{ignore_plotted_course = "yes" })
        	end
        end

        -- Recon and Uav To Assign
        totalReconUnitsToAssign = totalReconUnitsToAssign - #updatedMission.unitlist
        if numberOfReconToAssign > totalReconUnitsToAssign then
            numberOfReconToAssign = totalReconUnitsToAssign
        end

        -- Assign Up to numberOfReconToAssign
        for i = 1,numberOfReconToAssign do
            ScenEdit_AssignUnitToMission(totalFreeBusyInventory[i],updatedMission.guid)
        end
    end

    -- Set Time
    SetTimeStampForGUID(args.shortKey.."_rec_miss_ts",ScenEdit_CurrentTime())

    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Mission Actions
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineCreateAirMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_aaw_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeInventory = GetTotalFreeAirFighterInventory(args.shortKey)
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local totalAirUnitsToAssign = GetHostileAirContactsStrength(args.shortKey)
    local numberOfAirToAssign = #totalFreeInventory
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactCoordinates = {}
    local hostileContactBoundingBox = {}
    local createdMission = {}

    -- Condition Check
    if #missions > 0 or #totalFreeInventory == 0 or GetHostileAirContactsStrength(args.shortKey) == 0 then
        return false
    end

    -- Set Contact Bounding Box Variables
    hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)

    -- Set Reference Points
    rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
    rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
    rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
    rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})

    -- Create Recon Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_aaw_miss_"..tostring(missionNumber),"patrol",{type="aaw",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true,activeEMCON=true,oneThirdRule=false,flightSize=2})

    -- Recon and Uav To Assign
    if numberOfAirToAssign > totalAirUnitsToAssign then
        numberOfAirToAssign = totalAirUnitsToAssign
    end

    -- Assign Up to numberOfAirToAssign
    for i = 1,numberOfAirToAssign do
        ScenEdit_AssignUnitToMission(totalFreeInventory[i],createdMission.guid)
    end

    -- Add Guid And Add Time Stamp
    AddGUID(args.shortKey.."_aaw_miss",createdMission.name)

    -- Return True For Mission Created
    return true
end

function AttackDoctrineUpdateAirMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_aaw_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeBusyInventory = GetTotalFreeBusyAirFighterInventory(args.shortKey)
    local currentTime = ScenEdit_CurrentTime()
    local lastTimeStamp = GetTimeStampForGUID(args.shortKey.."_aaw_miss_ts")
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local updatedMission = {}
    local missionNumber = 1
    local totalAAWUnitsToAssign = GetHostileAirContactsStrength(args.shortKey)
    local numberOfAAWToAssign = #totalFreeBusyInventory

    -- Condition Check
    if #totalFreeBusyInventory == 0 or #missions == 0 or (currentTime - lastTimeStamp) < 3 * 60 then
        return false
    end

    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)

    -- Update Coordinates
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aaw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})

    -- Recon and Uav To Assign
    totalAAWUnitsToAssign = totalAAWUnitsToAssign - #updatedMission.unitlist
    if numberOfAAWToAssign > totalAAWUnitsToAssign then
        numberOfAAWToAssign = totalAAWUnitsToAssign
    end

    -- Assign Up to numberOfReconToAssign
    for i = 1,numberOfAAWToAssign do
        ScenEdit_AssignUnitToMission(totalFreeBusyInventory[i],updatedMission.guid)
    end

    -- Find Area And Return Point
    local missionUnits = updatedMission.unitlist
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetSAMAndShipNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid)
        if unitRetreatPoint ~= nil then
        	ScenEdit_SpecialMessage("Blue Force", "AttackDoctrineUpdateAirMissionAction")
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "no" })
        else
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "yes" })
        end
    end

    -- Add Guid And Add Time Stamp
    SetTimeStampForGUID(args.shortKey.."_aaw_miss_ts",tostring(ScenEdit_CurrentTime()))

    -- Return False
    return false
end

function AttackDoctrineCreateAntiSurfaceShipMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_asuw_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeInventory = GetFreeAirASuWInventory(args.shortKey)
    local totalHostileContacts = GetHostileSurfaceShipContacts(args.shortKey)
    local totalAirUnitsToAssign = GetHostileSurfaceShipContactsStrength(args.shortKey) * 4
    local numberOfAirToAssign = #totalFreeInventory
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactCoordinates = {}
    local hostileContactBoundingBox = {}
    local createdMission = {}

    -- Condition Check
    if #missions > 0 or #totalFreeInventory == 0 or GetHostileSurfaceShipContactsStrength(args.shortKey) == 0 then
        return false
    end

    -- Set Contact Bounding Box Variables
    hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)

    -- Set Reference Points
    rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
    rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
    rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
    rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})

    -- Create Recon Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_asuw_miss_"..tostring(missionNumber),"patrol",{type="naval",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true,activeEMCON=true,oneThirdRule=false,flightSize=2})

    -- Recon and Uav To Assign
    if numberOfAirToAssign > totalAirUnitsToAssign then
        numberOfAirToAssign = totalAirUnitsToAssign
    end

    -- Assign Up to numberOfAirToAssign
    for i = 1,numberOfAirToAssign do
        ScenEdit_AssignUnitToMission(totalFreeInventory[i],createdMission.guid)
    end

    -- Add Guid And Add Time Stamp
    AddGUID(args.shortKey.."_asuw_miss",createdMission.name)

    -- Return True For Mission Created
    return true
end

function AttackDoctrineUpdateAntiSurfaceShipMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_asuw_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeBusyInventory = GetTotalFreeBusyAirAntiSurfaceInventory(args.shortKey)
    local currentTime = ScenEdit_CurrentTime()
    local lastTimeStamp = GetTimeStampForGUID(args.shortKey.."_asuw_miss_ts")
    local totalHostileContacts = GetHostileSurfaceShipContacts(args.shortKey)
    local updatedMission = {}
    local missionNumber = 1
    local totalAAWUnitsToAssign = GetHostileSurfaceShipContactsStrength(args.shortKey) * 4
    local numberOfAAWToAssign = #totalFreeBusyInventory

    -- Condition Check
    if #totalFreeBusyInventory == 0 or #missions == 0 or (currentTime - lastTimeStamp) < 5 * 60 then
        return false
    end

    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,4)

    -- Update Every 5 Minutes Or Greater
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})

    -- Recon and Uav To Assign
    totalAAWUnitsToAssign = totalAAWUnitsToAssign - #updatedMission.unitlist
    if numberOfAAWToAssign > totalAAWUnitsToAssign then
        numberOfAAWToAssign = totalAAWUnitsToAssign
    end

    -- Assign Up to numberOfReconToAssign
    for i = 1,numberOfAAWToAssign do
        ScenEdit_AssignUnitToMission(totalFreeBusyInventory[i],updatedMission.guid)
    end

    -- Find Area And Return Point
    local missionUnits = updatedMission.unitlist
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetAirAndSAMNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,80)
        if unitRetreatPoint ~= nil then
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "no" })
        else
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "yes" })
        end
    end

    -- Add Guid And Add Time Stamp
    SetTimeStampForGUID(args.shortKey.."_asuw_miss_ts",tostring(ScenEdit_CurrentTime()))

    -- Return False
    return false
end

function AttackDoctrineCreateSeadMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_sead_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeInventory = GetFreeAirSeadInventory(args.shortKey)
    local totalHostileContacts = GetHostileSAMContacts(args.shortKey)
    local totalAirUnitsToAssign = GetHostileSAMContactsStrength(args.shortKey) * 4
    local numberOfAirToAssign = #totalFreeInventory
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactCoordinates = {}
    local hostileContactBoundingBox = {}
    local createdMission = {}

    -- ScenEdit_SpecialMessage("Blue Force", "AttackDoctrineCreateSeadMissionAction")

    -- Condition Check
    if #missions > 0 or #totalFreeInventory == 0 or GetHostileSAMContactsStrength(args.shortKey) == 0 then
        return false
    end

    -- Set Contact Bounding Box Variables
    hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,4)

    -- Set Reference Points
    rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
    rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
    rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
    rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})

    -- Create Recon Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_sead_miss_"..tostring(missionNumber),"patrol",{type="sead",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true,activeEMCON=true,oneThirdRule=false,flightSize=2})

    -- Recon and Uav To Assign
    if numberOfAirToAssign > totalAirUnitsToAssign then
        numberOfAirToAssign = totalAirUnitsToAssign
    end

    -- Assign Up to numberOfAirToAssign
    for i = 1,numberOfAirToAssign do
        ScenEdit_AssignUnitToMission(totalFreeInventory[i],createdMission.guid)
    end

    -- Add Guid
    AddGUID(args.shortKey.."_sead_miss",createdMission.name)

    -- Return True For Mission Created
    return true
end

function AttackDoctrineUpdateSeadMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_sead_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeBusyInventory = GetTotalFreeBusyAirSeadInventory(args.shortKey)
    local totalHostileContacts = GetHostileSAMContacts(args.shortKey)
    local updatedMission = {}
    local missionNumber = 1
    local totalAAWUnitsToAssign = GetHostileSAMContactsStrength(args.shortKey) * 4
    local numberOfAAWToAssign = #totalFreeBusyInventory
    -- Times
    local currentTime = ScenEdit_CurrentTime()
    local lastTimeStamp = GetTimeStampForGUID(args.shortKey.."_sead_miss_ts")

    -- Condition Check
    if #totalFreeBusyInventory == 0 or #missions == 0 or (currentTime - lastTimeStamp) < 5 * 60 then
        return false
    end

    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,4)

    -- Update Every 5 Minutes Or Greater
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})

    -- Recon and Uav To Assign
    totalAAWUnitsToAssign = totalAAWUnitsToAssign - #updatedMission.unitlist
    if numberOfAAWToAssign > totalAAWUnitsToAssign then
        numberOfAAWToAssign = totalAAWUnitsToAssign
    end

    -- Assign Up to numberOfReconToAssign
    for i = 1,numberOfAAWToAssign do
        ScenEdit_AssignUnitToMission(totalFreeBusyInventory[i],updatedMission.guid)
    end

    -- Find Area And Return Point
    local missionUnits = updatedMission.unitlist
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetAirAndShipNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,80)
        if unitRetreatPoint ~= nil then
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "no" })
        else
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "yes" })
        end
    end

    -- Add Time Stamp
    SetTimeStampForGUID(args.shortKey.."_sead_miss_ts",tostring(ScenEdit_CurrentTime()))

    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Defend Doctrine Mission Actions
--------------------------------------------------------------------------------------------------------------------------------
function DefendDoctrineCreateAirMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_aaw_d_miss")
    local createdMission = {}
    -- Boxes And Coordinates
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local defenseBoundingBox = {}
    local rp1,rp2,rp3,rp4 = ""
    -- Inventory And HVT And Contacts
    local totalFreeInventory = GetTotalFreeAirFighterInventory(args.shortKey)
    local totalHVTs = GetGUID(args.shortKey.."_def_hvt")
    local coveredHVTs = GetGUID(args.shortKey.."_def_hvt_cov")
    local unitToDefend = nil
    local numberOfAAWToAssign = #totalFreeInventory
    local totalAAWUnitsToAssign = 2

    -- Condition Check - If Covered HVT Exceeds Total HVT, Then Do Not Create More Defense Missions, Also Check Total FREE Inventory
    if #coveredHVTs >= #totalHVTs or #totalFreeInventory == 0 then
        return false
    end

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
    if not unitToDefend then
        return false
    end
    
    -- Set Contact Bounding Box Variables
    defenseBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(unitToDefend.latitude,unitToDefend.longitude)},2.5)

    -- Set Reference Points
    rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_rp_1", lat=defenseBoundingBox[1].latitude, lon=defenseBoundingBox[1].longitude})
    rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_rp_2", lat=defenseBoundingBox[2].latitude, lon=defenseBoundingBox[2].longitude})
    rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_rp_3", lat=defenseBoundingBox[3].latitude, lon=defenseBoundingBox[3].longitude})
    rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aaw_d_miss_"..unitToDefend.guid.."_rp_4", lat=defenseBoundingBox[4].latitude, lon=defenseBoundingBox[4].longitude})

    -- Create Recon Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_aaw_d_miss_"..unitToDefend.guid,"patrol",{type="aaw",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true,activeEMCON=true})

    -- Recon and Uav To Assign
    if numberOfAAWToAssign > totalAAWUnitsToAssign then
        numberOfAAWToAssign = totalAAWUnitsToAssign
    end

    -- Assign Up to numberOfAirToAssign
    for i = 1,numberOfAAWToAssign do
        ScenEdit_AssignUnitToMission(totalFreeInventory[i],createdMission.guid)
    end

    -- Add Guid And Add Time Stamp
    AddGUID(args.shortKey.."_aaw_d_miss",createdMission.name)
    AddGUID(args.shortKey.."_def_hvt_cov",unitToDefend.guid)

    -- Return True For Mission Created
    return true
end

function DefendDoctrineUpdateAirMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_aaw_d_miss")
    local updatedMission = nil
    -- Boxes And Coordinates
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local rp1,rp2,rp3,rp4 = ""
    local defenseBoundingBox = {}
    -- Inventory And HVT And Contacts
    local totalFreeBusyInventory = GetTotalFreeBusyAirFighterInventory(args.shortKey)
    local totalHVTs = GetGUID(args.shortKey.."_def_hvt")
    local coveredHVTs = GetGUID(args.shortKey.."_def_hvt_cov")
    local numberOfAAWToAssign = #totalFreeBusyInventory
    local totalAAWUnitsToAssign = 2
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    -- Times
    local currentTime = ScenEdit_CurrentTime()
    local lastTimeStamp = GetTimeStampForGUID(args.shortKey.."_aaw_d_miss_ts")

    -- Condition Check
    if #missions == 0 or #totalFreeBusyInventory == 0 or (currentTime - lastTimeStamp) < 10 * 60 then
        return false
    end

    -- Loop Through Coverted HVTs Missions
    for k, v in pairs(coveredHVTs) do
        -- Local Covered HVT
        local coveredHVT = ScenEdit_GetUnit({side=side.name,guid=v})
        -- Check Condition
        if coveredHVT then
            -- Get Defense Mission
            updatedMission = ScenEdit_GetMission(side.name,args.shortKey.."_aaw_d_miss_"..coveredHVT.guid)

            -- Check Defense Mission
            if updatedMission then
                -- ScenEdit_SpecialMessage("Red Force", "DefendDoctrineUpdateMissionAction")

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
                
                -- Patrols To Assign
                totalAAWUnitsToAssign = totalAAWUnitsToAssign - #updatedMission.unitlist
                if numberOfAAWToAssign > totalAAWUnitsToAssign then
                    numberOfAAWToAssign = totalAAWUnitsToAssign
                end

                -- Assign Up to numberOfReconToAssign
                for i = 1,numberOfAAWToAssign do
                    ScenEdit_AssignUnitToMission(totalFreeBusyInventory[i],updatedMission.guid)
                end
            end
        end
    end

    -- Add Time Stamp
    SetTimeStampForGUID(args.shortKey.."_aaw_d_miss_ts",tostring(ScenEdit_CurrentTime()))

    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Support Doctrine Mission Actions
--------------------------------------------------------------------------------------------------------------------------------
function SupportTankerDoctrineCreateMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_tan_sup_miss")
    local createdMission = nil
    -- Boxes And Coordinates
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local rp1,rp2,rp3,rp4 = nil
    local supportBoundingBox = {}
    -- Inventory And HVT And Contacts
    local totalFreeInventory = GetFreeAirTankerInventory(args.shortKey)
    local totalHVTs = GetGUID(args.shortKey.."_def_hvt")
    local coveredHVTs = GetGUID(args.shortKey.."_def_tan_hvt_cov")
    local numberOfTankersToAssign = #totalFreeInventory
    local totalTankerSupportUnitsToAssign = 1
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local unitToSupport = nil

    -- Condition Check
    if #coveredHVTs >= #totalHVTs or #totalFreeInventory == 0 then
        return false
    end

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
    if not unitToSupport then
        return false
    end
    
    -- Set Contact Bounding Box Variables
    defenseBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(unitToSupport.latitude,unitToSupport.longitude)},1)

    -- Set Reference Points
    rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_tan_sup_miss_"..unitToSupport.guid.."_rp_1", lat=defenseBoundingBox[1].latitude, lon=defenseBoundingBox[1].longitude})
    rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_tan_sup_miss_"..unitToSupport.guid.."_rp_2", lat=defenseBoundingBox[2].latitude, lon=defenseBoundingBox[2].longitude})
    rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_tan_sup_miss_"..unitToSupport.guid.."_rp_3", lat=defenseBoundingBox[3].latitude, lon=defenseBoundingBox[3].longitude})
    rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_tan_sup_miss_"..unitToSupport.guid.."_rp_4", lat=defenseBoundingBox[4].latitude, lon=defenseBoundingBox[4].longitude})

    -- Create Recon Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_tan_sup_miss_"..unitToSupport.guid,"support",{zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetMission(side.name,createdMission.name,{activeEMCON=true})

    -- Recon and Uav To Assign
    if numberOfTankersToAssign > totalTankerSupportUnitsToAssign then
        numberOfTankersToAssign = totalTankerSupportUnitsToAssign
    end

    -- Assign Up to numberOfAirToAssign
    for i = 1,numberOfTankersToAssign do
        ScenEdit_AssignUnitToMission(totalFreeInventory[i],createdMission.guid)
    end

    -- Add Guid And Add Time Stamp
    AddGUID(args.shortKey.."_tan_sup_miss",createdMission.name)
    AddGUID(args.shortKey.."_def_tan_hvt_cov",unitToSupport.guid)

    -- Return True For Mission Created
    return true
end

function SupportTankerDoctrineUpdateMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_tan_sup_miss")
    local updatedMission = nil
    -- Boxes And Coordinates
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local rp1,rp2,rp3,rp4 = nil
    local supportBoundingBox = {}
    -- Inventory And HVT And Contacts
    local totalBusyFreeInventory = GetTotalFreeBusyTankerInventory(args.shortKey)
    local totalHVTs = GetGUID(args.shortKey.."_def_hvt")
    local coveredHVTs = GetGUID(args.shortKey.."_def_tan_hvt_cov")
    local numberOfTankersToAssign = #totalBusyFreeInventory
    local totalTankerSupportUnitsToAssign = 1
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local totalHostilesInZone = 0
    -- Times
    local currentTime = ScenEdit_CurrentTime()
    local lastTimeStamp = GetTimeStampForGUID(args.shortKey.."_tan_sup_miss_ts")

    -- Condition Check
    if #missions == 0 or #totalBusyFreeInventory == 0 or (currentTime - lastTimeStamp) < 10 * 60 then
        return false
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
                -- Set Contact Bounding Box Variables
                --defenseBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(coveredHVT.latitude,coveredHVT.longitude)},1)

                -- Find Contact Close To Unit And Retreat If Necessary
                local missionUnits = updatedMission.unitlist
                for k,v in pairs(missionUnits) do
                    local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
                    local unitRetreatPoint = GetAllNoNavZoneThatContaintsUnit(args.guid,args.shortKey,missionUnit.guid,120)
                    if unitRetreatPoint ~= nil then
                        missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
                        ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "no" })
                    else
                        ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "yes" })
                    end
                end

                -- Update Coordinates
                --rp1 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_tan_sup_miss_"..coveredHVT.guid.."_rp_1", lat=defenseBoundingBox[1].latitude, lon=defenseBoundingBox[1].longitude})
                --rp2 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_tan_sup_miss_"..coveredHVT.guid.."_rp_2", lat=defenseBoundingBox[2].latitude, lon=defenseBoundingBox[2].longitude})
                --rp3 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_tan_sup_miss_"..coveredHVT.guid.."_rp_3", lat=defenseBoundingBox[3].latitude, lon=defenseBoundingBox[3].longitude})
                --rp4 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_tan_sup_miss_"..coveredHVT.guid.."_rp_4", lat=defenseBoundingBox[4].latitude, lon=defenseBoundingBox[4].longitude})

                -- If There's Hostile Unassign
                totalTankerSupportUnitsToAssign = totalTankerSupportUnitsToAssign - #updatedMission.unitlist
                if numberOfTankersToAssign > totalTankerSupportUnitsToAssign then
                    numberOfTankersToAssign = totalTankerSupportUnitsToAssign
                end

                -- Assign Tankers
                for i = 1,numberOfTankersToAssign do
                    ScenEdit_AssignUnitToMission(totalBusyFreeInventory[i],updatedMission.guid)
                end
            end
        end
    end

    -- Add Time Stamp
    SetTimeStampForGUID(args.shortKey.."_tan_sup_miss_ts",tostring(ScenEdit_CurrentTime()))

    -- Return True
    return false
end

function SupportAEWDoctrineCreateMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_aew_sup_miss")
    local createdMission = nil
    -- Boxes And Coordinates
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local rp1,rp2,rp3,rp4 = nil
    local supportBoundingBox = {}
    -- Inventory And HVT And Contacts
    local totalFreeInventory = GetFreeAirAEWInventory(args.shortKey)
    local totalHVTs = GetGUID(args.shortKey.."_def_hvt")
    local coveredHVTs = GetGUID(args.shortKey.."_def_aew_hvt_cov")
    local numberOfAEWToAssign = #totalFreeInventory
    local totalAEWUnitsToAssign = 1
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local unitToSupport = nil

    -- Condition Check
    if #coveredHVTs >= #totalHVTs or #totalFreeInventory == 0 then
        return false
    end

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
    if not unitToSupport then
        return false
    end
    
    -- Set Contact Bounding Box Variables
    defenseBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(unitToSupport.latitude,unitToSupport.longitude)},1)

    -- Set Reference Points
    rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aew_sup_miss_"..unitToSupport.guid.."_rp_1", lat=defenseBoundingBox[1].latitude, lon=defenseBoundingBox[1].longitude})
    rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aew_sup_miss_"..unitToSupport.guid.."_rp_2", lat=defenseBoundingBox[2].latitude, lon=defenseBoundingBox[2].longitude})
    rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aew_sup_miss_"..unitToSupport.guid.."_rp_3", lat=defenseBoundingBox[3].latitude, lon=defenseBoundingBox[3].longitude})
    rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_aew_sup_miss_"..unitToSupport.guid.."_rp_4", lat=defenseBoundingBox[4].latitude, lon=defenseBoundingBox[4].longitude})

    -- Create Recon Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_aew_sup_miss_"..unitToSupport.guid,"support",{zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetMission(side.name,createdMission.name,{activeEMCON=true})

    -- Recon and Uav To Assign
    if numberOfAEWToAssign > totalAEWUnitsToAssign then
        numberOfAEWToAssign = totalAEWUnitsToAssign
    end

    -- Assign Up to numberOfAirToAssign
    for i = 1,numberOfAEWToAssign do
        local assignedUnit = ScenEdit_GetUnit({side=side.name, guid=totalFreeInventory[i]})
        ScenEdit_SetEMCON("Unit",assignedUnit.guid,"Radar=Active")
        ScenEdit_AssignUnitToMission(totalFreeInventory[i],createdMission.guid)
    end

    -- Add Guid And Add Time Stamp
    AddGUID(args.shortKey.."_aew_sup_miss",createdMission.name)
    AddGUID(args.shortKey.."_def_aew_hvt_cov",unitToSupport.guid)

    -- Return True For Mission Created
    return true
end

function SupportAEWDoctrineUpdateMissionAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_aew_sup_miss")
    local updatedMission = nil
    -- Boxes And Coordinates
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local rp1,rp2,rp3,rp4 = ""
    local supportBoundingBox = {}
    -- Inventory And HVT And Contacts
    local totalBusyFreeInventory = GetTotalFreeBusyAEWInventory(args.shortKey)
    local totalHVTs = GetGUID(args.shortKey.."_def_hvt")
    local coveredHVTs = GetGUID(args.shortKey.."_def_aew_hvt_cov")
    local numberOfAEWToAssign = #totalBusyFreeInventory
    local totalAEWSupportUnitsToAssign = 1
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local totalHostilesInZone = 0
    -- Times
    local currentTime = ScenEdit_CurrentTime()
    local lastTimeStamp = GetTimeStampForGUID(args.shortKey.."_aew_sup_miss_ts")

    -- Condition Check
    if #missions == 0 or #totalBusyFreeInventory == 0 or (currentTime - lastTimeStamp) < 10 * 60 then
        return false
    end

    -- Loop Through Coverted HVTs Missions
    for k, v in pairs(coveredHVTs) do
        -- Local Covered HVT
        local coveredHVT = ScenEdit_GetUnit({side=side.name,guid=v})
        -- Check Condition
        if coveredHVT then
            updatedMission = ScenEdit_GetMission(side.name,args.shortKey.."_aew_sup_miss_"..coveredHVT.guid)

            -- Check Defense Mission
            if updatedMission then
                -- Set Contact Bounding Box Variables
                --defenseBoundingBox = FindBoundingBoxForGivenLocations({MakeLatLong(coveredHVT.latitude,coveredHVT.longitude)},1)

                -- Find Contact Close To Unit And Retreat If Necessary
                local missionUnits = updatedMission.unitlist
                for k,v in pairs(missionUnits) do
                    local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
                    local unitRetreatPoint = GetAllNoNavZoneThatContaintsUnit(args.guid,args.shortKey,missionUnit.guid,120)
                    if unitRetreatPoint ~= nil then
                        missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
                        ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "no" })
                    else
                        ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "yes" })
                    end
                end

                -- Update Coordinates
                --rp1 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aew_sup_miss_"..coveredHVT.guid.."_rp_1", lat=defenseBoundingBox[1].latitude, lon=defenseBoundingBox[1].longitude})
                --rp2 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aew_sup_miss_"..coveredHVT.guid.."_rp_2", lat=defenseBoundingBox[2].latitude, lon=defenseBoundingBox[2].longitude})
                --rp3 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aew_sup_miss_"..coveredHVT.guid.."_rp_3", lat=defenseBoundingBox[3].latitude, lon=defenseBoundingBox[3].longitude})
                --rp4 = ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_aew_sup_miss_"..coveredHVT.guid.."_rp_4", lat=defenseBoundingBox[4].latitude, lon=defenseBoundingBox[4].longitude})

                -- Patrols To Assign
                totalAEWSupportUnitsToAssign = totalAEWSupportUnitsToAssign - #updatedMission.unitlist
                if numberOfAEWToAssign > totalAEWSupportUnitsToAssign then
                    numberOfAEWToAssign = totalAEWSupportUnitsToAssign
                end

                -- Assign AEW
                for i = 1,numberOfAEWToAssign do
                    local assignedUnit = ScenEdit_GetUnit({side=side.name, guid=totalBusyFreeInventory[i]})
        			ScenEdit_SetEMCON("Unit",assignedUnit.guid,"Radar=Active")
                    ScenEdit_AssignUnitToMission(totalBusyFreeInventory[i],updatedMission.guid)
                end
            end
        end
    end

    -- Add Time Stamp
    SetTimeStampForGUID(args.shortKey.."_aew_sup_miss_ts",tostring(ScenEdit_CurrentTime()))

    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Monitor SAM NoNav Zones Action
--------------------------------------------------------------------------------------------------------------------------------
function MonitorCreateSAMNoNavZonesAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local zones = GetGUID(args.shortKey.."_sam_ex_zone")
    -- Inventory And HVT And Contacts
    local totalHostileContacts = GetHostileSAMContacts(args.shortKey)
    -- Zones
    local noNavZoneBoundary = {}
    local zoneNumber = #zones + 1

    -- Condition Check
    if #zones >= 15 or #totalHostileContacts == 0 or #zones >= #totalHostileContacts then
       return false 
    end

    -- Get Contact
    local contact = ScenEdit_GetContact({side=side.name, guid=totalHostileContacts[#zones + 1]})
    local contactDefense = contact.missile_defence
    local noNavZoneRange = 10

    -- Create Exlusion Zone Based On Missile Defense
    if contactDefense < 2 then
        noNavZoneRange = 5
    elseif contactDefense < 5 then
        noNavZoneRange = 20
    elseif contactDefense < 10 then
        noNavZoneRange = 40
    elseif contactDefense < 20 then
        noNavZoneRange = 60
    end

    -- SAM Zone + Range
    local referencePoint = ScenEdit_AddReferencePoint({side=side.name,lat=contact.latitude,lon=contact.longitude,name=tostring(noNavZoneRange),highlighted="no"})
    AddGUID(args.shortKey.."_sam_ex_zone",referencePoint.guid)

    -- Return True
    return true
end

function MonitorUpdateSAMNoNavZonesAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local zones = GetGUID(args.shortKey.."_sam_ex_zone")
    -- Inventory And HVT And Contacts
    local totalHostileContacts = GetHostileSAMContacts(args.shortKey)
    -- Times
    local currentTime = ScenEdit_CurrentTime()
    local lastReconTimeStamp = GetTimeStampForGUID(args.shortKey.."_sam_ex_zone_ts")
    local zoneCounter = 1

    --ScenEdit_SpecialMessage("Blue Force", "MonitorUpdateSAMNoNavZonesAction 1 "..tostring(#zones))

    -- Condition Check
    if #zones == 0 or (currentTime - lastReconTimeStamp) < 10 * 60 then
       return false 
    end

    -- Set New Timestamp
    SetTimeStampForGUID(args.shortKey.."_sam_ex_zone_ts",currentTime)

    -- Key Value Pairs
    for k,v in pairs(zones) do
        local referencePoints = ScenEdit_GetReferencePoints({side=side.name,area={v}})
        local referencePoint = referencePoints[1]

        --ScenEdit_SpecialMessage("Blue Force", "MonitorUpdateSAMNoNavZonesAction 2 "..tostring(#zones))

        if zoneCounter > #totalHostileContacts then
            ScenEdit_SetReferencePoint({side=side.name, guid=v, newname="0", lat=0, long=0})
        else
            -- Get Contact
            local contact = ScenEdit_GetContact({side=side.name, guid=totalHostileContacts[zoneCounter]})
            local contactDefense = contact.missile_defence
            local noNavZoneRange = 10

            -- Create Exlusion Zone Based On Missile Defense
            if contactDefense < 2 then
                noNavZoneRange = 5
            elseif contactDefense < 5 then
                noNavZoneRange = 20
            elseif contactDefense < 10 then
                noNavZoneRange = 40
            elseif contactDefense < 20 then
                noNavZoneRange = 60
            end
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
-- Monitor Ship NoNav Zones Action
--------------------------------------------------------------------------------------------------------------------------------
function MonitorCreateShipNoNavZonesAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local zones = GetGUID(args.shortKey.."_ship_ex_zone")
    -- Inventory And HVT And Contacts
    local totalHostileContacts = GetHostileSurfaceShipContacts(args.shortKey)
    -- Zones
    local noNavZoneBoundary = {}
    local zoneNumber = #zones + 1

    -- Condition Check
    if #zones >= 15 or #totalHostileContacts == 0 or #zones >= #totalHostileContacts then
       return false 
    end

    -- Get Contact
    local contact = ScenEdit_GetContact({side=side.name, guid=totalHostileContacts[#zones + 1]})
    local contactDefense = contact.missile_defence
    local noNavZoneRange = 10

    -- Create Exlusion Zone Based On Missile Defense
    if contactDefense < 2 then
        noNavZoneRange = 30
    elseif contactDefense < 5 then
        noNavZoneRange = 60
    elseif contactDefense < 10 then
        noNavZoneRange = 90
    elseif contactDefense < 20 then
        noNavZoneRange = 120
    end
    
    -- Ship Zone + Range
    local referencePoint = ScenEdit_AddReferencePoint({side=side.name,lat=contact.latitude,lon=contact.longitude,name=tostring(noNavZoneRange),highlighted="no"})
    AddGUID(args.shortKey.."_ship_ex_zone",referencePoint.guid)

    -- Return True
    return true
end

function MonitorUpdateShipNoNavZonesAction(args)
    -- Local Side And Mission
    local side = VP_GetSide({guid=args.guid})
    local zones = GetGUID(args.shortKey.."_ship_ex_zone")
    -- Inventory And HVT And Contacts
    local totalHostileContacts = GetHostileSurfaceShipContacts(args.shortKey)
    -- Times
    local currentTime = ScenEdit_CurrentTime()
    local lastReconTimeStamp = GetTimeStampForGUID(args.shortKey.."_ship_ex_zone_ts")
    local zoneCounter = 1

    --ScenEdit_SpecialMessage("Blue Force", "MonitorUpdateSAMNoNavZonesAction 1 "..tostring(#zones))

    -- Condition Check
    if #zones == 0 or (currentTime - lastReconTimeStamp) < 10 * 60 then
       return false 
    end

    -- Set New Timestamp
    SetTimeStampForGUID(args.shortKey.."_ship_ex_zone_ts",currentTime)

    -- Key Value Pairs
    for k,v in pairs(zones) do
        local referencePoints = ScenEdit_GetReferencePoints({side=side.name,area={v}})
        local referencePoint = referencePoints[1]

        --ScenEdit_SpecialMessage("Blue Force", "MonitorUpdateSAMNoNavZonesAction 2 "..tostring(#zones))

        if zoneCounter > #totalHostileContacts then
            --ScenEdit_SpecialMessage("Blue Force","Change To 0")
            ScenEdit_SetReferencePoint({side=side.name, guid=v, newname="0", lat=0, long=0})
        else
            -- Get Contact
            local contact = ScenEdit_GetContact({side=side.name, guid=totalHostileContacts[zoneCounter]})
            local contactDefense = contact.missile_defence
            local noNavZoneRange = 10

            -- Create Exlusion Zone Based On Missile Defense
            if contactDefense < 2 then
                noNavZoneRange = 30
            elseif contactDefense < 5 then
                noNavZoneRange = 60
            elseif contactDefense < 10 then
                noNavZoneRange = 90
            elseif contactDefense < 20 then
                noNavZoneRange = 120
            end
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
-- Monitor Air NoNav Zones Action
--------------------------------------------------------------------------------------------------------------------------------
function MonitorCreateAirNoNavZonesAction(args)
    -- Return True
    return true
end

function MonitorUpdateAirNoNavZonesAction(args)
    -- Return True
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Initialize AI
--------------------------------------------------------------------------------------------------------------------------------
function InitializeMerimackMonitorAI(sideGuid,shortSideKey)
    -- Main Node Sequence
    local merimackSelector = BT:make(BT.select,sideGuid,shortSideKey)

    -- Doctrine Sequences
    local offensiveDoctrineSequence = BT:make(BT.sequence,sideGuid,shortSideKey)
    local defensiveDoctrineSequence = BT:make(BT.sequence,sideGuid,shortSideKey)

    -- Doctrine Sequences Children
    local offensiveDoctrineConditionalBT = BT:make(OffensiveConditionalCheck,sideGuid,shortSideKey)
    local defensiveDoctrineConditionalBT = BT:make(DefensiveConditionalCheck,sideGuid,shortSideKey)
    local offensiveDoctrineSeletor = BT:make(BT.select,sideGuid,shortSideKey)
    local defensiveDoctrineSeletor = BT:make(BT.select,sideGuid,shortSideKey)

    -- Sub Doctrine Sequences
    local reconDoctrineSelector = BT:make(BT.select,sideGuid,shortSideKey)
    local attackDoctrineSelector = BT:make(BT.select,sideGuid,shortSideKey)
    local defendDoctrineSelector = BT:make(BT.select,sideGuid,shortSideKey)
    local supportTankerDoctrineSelector = BT:make(BT.select,sideGuid,shortSideKey)
    local supportAEWDoctrineSelector = BT:make(BT.select,sideGuid,shortSideKey)

    -- Recon Doctrine BT
    local reconDoctrineUpdateMissionBT = BT:make(ReconDoctrineUpdateMissionAction,sideGuid,shortSideKey)
    local reconDoctrineCreateMissionBT = BT:make(ReconDoctrineCreateMissionAction,sideGuid,shortSideKey)

    -- Attack Doctrine BT
    local attackDoctrineUpdateAirMissionBT = BT:make(AttackDoctrineUpdateAirMissionAction,sideGuid,shortSideKey)
    local attackDoctrineCreateAirMissionBT = BT:make(AttackDoctrineCreateAirMissionAction,sideGuid,shortSideKey)
    local attackDoctrineCreateAntiSurfaceShipMissionBT = BT:make(AttackDoctrineCreateAntiSurfaceShipMissionAction,sideGuid,shortSideKey)
    local attackDoctrineUpdateAntiSurfaceShipMissionBT = BT:make(AttackDoctrineUpdateAntiSurfaceShipMissionAction,sideGuid,shortSideKey)
    local attackDoctrineCreateSeadMissionBT = BT:make(AttackDoctrineCreateSeadMissionAction,sideGuid,shortSideKey)
    local attackDoctrineUpdateSeadMissionBT = BT:make(AttackDoctrineUpdateSeadMissionAction,sideGuid,shortSideKey)

    -- Defend Doctrine BT
    local defendDoctrineUpdateAirMissionBT = BT:make(DefendDoctrineUpdateAirMissionAction,sideGuid,shortSideKey)
    local defendDoctrineCreateAirMissionBT = BT:make(DefendDoctrineCreateAirMissionAction,sideGuid,shortSideKey)

    -- Support Tanker Doctrine BT
    local supportTankerDoctrineUpdateMissionBT = BT:make(SupportTankerDoctrineCreateMissionAction,sideGuid,shortSideKey)
    local supportTankerDoctrineCreateMissionBT = BT:make(SupportTankerDoctrineUpdateMissionAction,sideGuid,shortSideKey)

    -- Support AEW Doctrine BT
    local supportAEWDoctrineUpdateMissionBT = BT:make(SupportAEWDoctrineCreateMissionAction,sideGuid,shortSideKey)
    local supportAEWDoctrineCreateMissionBT = BT:make(SupportAEWDoctrineUpdateMissionAction,sideGuid,shortSideKey)

    -- Build AI Tree
    merimackSelector:addChild(offensiveDoctrineSequence)
    merimackSelector:addChild(defensiveDoctrineSequence)

    -- Offensive and Defensive Sequence
    offensiveDoctrineSequence:addChild(offensiveDoctrineConditionalBT)
    offensiveDoctrineSequence:addChild(offensiveDoctrineSeletor)

    defensiveDoctrineSequence:addChild(defensiveDoctrineConditionalBT)
    defensiveDoctrineSequence:addChild(defensiveDoctrineSeletor)

    -- Offensive Selector
    offensiveDoctrineSeletor:addChild(reconDoctrineSelector)
    offensiveDoctrineSeletor:addChild(attackDoctrineSelector)
    offensiveDoctrineSeletor:addChild(supportAEWDoctrineSelector)
    offensiveDoctrineSeletor:addChild(supportTankerDoctrineSelector)

    -- Defensive Selector
    defensiveDoctrineSeletor:addChild(defendDoctrineSelector)
    defensiveDoctrineSeletor:addChild(reconDoctrineSelector)
    defensiveDoctrineSeletor:addChild(supportAEWDoctrineSelector)
    defensiveDoctrineSeletor:addChild(supportTankerDoctrineSelector)

    -- Recon Doctrine Sequence
    reconDoctrineSelector:addChild(reconDoctrineUpdateMissionBT)
    reconDoctrineSelector:addChild(reconDoctrineCreateMissionBT)

    -- Attack Doctrine Sequence
    attackDoctrineSelector:addChild(attackDoctrineUpdateAirMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateAirMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineUpdateAntiSurfaceShipMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateAntiSurfaceShipMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineUpdateSeadMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateSeadMissionBT)

    -- Defend Doctrine Sequence
    defendDoctrineSelector:addChild(defendDoctrineUpdateAirMissionBT)
    defendDoctrineSelector:addChild(defendDoctrineCreateAirMissionBT)

    -- Support Tanker Sequence
    supportTankerDoctrineSelector:addChild(supportTankerDoctrineUpdateMissionBT)
    supportTankerDoctrineSelector:addChild(supportTankerDoctrineCreateMissionBT)

    -- Support AEW Sequence
    supportAEWDoctrineSelector:addChild(supportAEWDoctrineUpdateMissionBT)
    supportAEWDoctrineSelector:addChild(supportAEWDoctrineCreateMissionBT)

    -- Setup Monitor AI
    local monitorSelector = BT:make(BT.select,sideGuid,shortSideKey)

    -- Monitor No Fly Zones BT
    local monitorSAMNoNavSelector = BT:make(BT.select,sideGuid,shortSideKey)
    local monitorUpdateSAMNoNavZonesBT = BT:make(MonitorUpdateSAMNoNavZonesAction,sideGuid,shortSideKey)
    local monitorCreateSAMNoNavZonesBT = BT:make(MonitorCreateSAMNoNavZonesAction,sideGuid,shortSideKey)
    
    local monitorShipNoNavSelector = BT:make(BT.select,sideGuid,shortSideKey)
    local monitorUpdateShipNoNavZonesBT = BT:make(MonitorUpdateShipNoNavZonesAction,sideGuid,shortSideKey)
    local monitorCreateShipNoNavZonesBT = BT:make(MonitorCreateShipNoNavZonesAction,sideGuid,shortSideKey)

    local monitorAirNoNavSelector = BT:make(BT.select,sideGuid,shortSideKey)
    local monitorUpdateAirNoNavZonesBT = BT:make(MonitorUpdateAirNoNavZonesAction,sideGuid,shortSideKey)
    local monitorCreateAirNoNavZonesBT = BT:make(MonitorCreateAirNoNavZonesAction,sideGuid,shortSideKey)

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

    -- Add All AI's
    commandMerimackAIArray[#commandMerimackAIArray + 1] = merimackSelector
    commandMonitorAIArray[#commandMonitorAIArray + 1] = monitorSelector
end

function UpdateAI()
    -- Update Inventories And Update Merimack AI
    for k, v in pairs(commandMerimackAIArray) do
        UpdateAIInventories(v.guid,v.shortKey)
        v:run()
    end

    -- Update Monitor AI
    for k, v in pairs(commandMonitorAIArray) do
        v:run()
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Global Call
--------------------------------------------------------------------------------------------------------------------------------
local sideOption = ScenEdit_GetSideOptions({side="Blue Force"})
InitializeMerimackMonitorAI(sideOption.guid,"a")