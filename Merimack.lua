--[[
  This behavior tree code was taken from our Zelda AI project for CMPS 148 at UCSC.
  It is for the most part unmodified, and comments are available for each function.
  Behavior tree code credited to https://gist.github.com/mrunderhill89/
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
	--[[local unitKeyValue = {}
	local unitList = {}
	if mission then
		for k,v in pairs(mission.unitlist) do
			local unit = ScenEdit_GetUnit({side=sideName, guid=v})
			if unit.group then
				if unitKeyValue[unit.group.lead] == nil then
					unitList[#unitList + 1] = unit.group.lead
					unitKeyValue[unit.group.lead] = ""
				end
			else
				if unitKeyValue[unit.guid] == nil then
					unitList[#unitList + 1] = unit.guid
					unitKeyValue[unit.guid] = ""
				end
			end
		end
	end
	return unitList]]--
	if mission then
		return mission.unitlist
	else 
		return {}
	end
end

function DetermineRoleFromLoadOutDatabase(loudoutId,defaultRole)
    local role = ScenEdit_GetKeyValue("lo_"..tostring(loudoutId))
    if role == nil or role == "" then
        return defaultRole
    else
        return role
    end
end

function DetermineThreatRangeByUnitDatabaseId(sideGuid,contactGuid)
    local side = VP_GetSide({guid=sideGuid})
    local contact = ScenEdit_GetContact({side=side.name, guid=contactGuid})
    local range = 0
    -- Loop Through EM Matches And Get First
    for k,v in pairs(contact.potentialmatches) do
        local foundRange = ScenEdit_GetKeyValue("thr_"..tostring(v.dbid))
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

function DetermineUnitsToAssign(sideName,missionGuid,totalRequiredUnits,unitGuidList)
    -- Local Values
    local mission = ScenEdit_GetMission(sideName,missionGuid)

    -- Check
    if mission then
	    -- Loop Through Mission Unit Lists And Unassign RTB Units
	    for k,v in pairs(mission.unitlist) do
	        local unit = ScenEdit_GetUnit({side=sideName, guid=v})
	        if unit then
		        if unit.unitstate == "RTB" then
		            local mockMission = ScenEdit_AddMission(sideName,"MOCK MISSION",'strike',{type='land'})
		            ScenEdit_AssignUnitToMission(unit.guid, mockMission.guid)            
	                ScenEdit_DeleteMission(sideName,mockMission.guid)
	                ScenEdit_SetUnit({side=sideName,guid=unit.guid,RTB="Yes"})
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
	        --[[totalRequiredUnits = totalRequiredUnits - 1
	        ScenEdit_AssignUnitToMission(v,mission.guid)]]--
	        local unit = ScenEdit_GetUnit({side=sideName, guid=v})

    		--ScenEdit_SpecialMessage("Stennis CSG", tostring(unit.readytime).."_"..unit.unitstate.."_"..unit.fuelstate)
	        if unit.unitstate ~= "RTB" and unit.unitstate ~= "RTB_Manual"  then
	            totalRequiredUnits = totalRequiredUnits - 1
	            ScenEdit_AssignUnitToMission(v,mission.guid)
	        end
	    end
    end
end

function DetermineEmconToUnits(sideShortKey,sideName,unitGuidList)
    local busyAEWInventory = GetBusyAirAEWInventory(sideShortKey)
    for k,v in pairs(unitGuidList) do
        local unit = ScenEdit_GetUnit({side=sideName, guid=v})
        for k1,v1 in pairs(busyAEWInventory) do
            local aewUnit = ScenEdit_GetUnit({side=sideName, guid=v1})
            if aewUnit.speed > 0 and aewUnit.altitude > 0 then
                if Tool_Range(v1,v) < 150 then
                	if unit.firingAt then
                    	if #unit.firingAt == 0 then
                        	ScenEdit_SetEMCON("Unit",v,"Radar=Passive")
                    	end
                	end
                else
                    ScenEdit_SetEMCON("Unit",v,"Radar=Active")
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
            return ProjectLatLong(MakeLatLong(contact.latitude,contact.longitude),bearing,range + 10)
        end
    end
    -- Return 
    return nil
end

function GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    -- Local Side And Mission
    local side = VP_GetSide({guid=sideGuid})
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
    local zones = GetGUID(shortSideKey.."_sam_ex_zone")
    -- Zone Reference Points
    local zoneReferencePoints = ScenEdit_GetReferencePoints({side=side.name, area=zones})

    -- Zone Reference Points
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
    local unit = ScenEdit_GetUnit({side=side.name, guid=unitGuid})
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
            return ProjectLatLong(contactPoint,bearing,currentRange + 30)
        end
    end
    -- Return nil
    return nil
end

function GetSAMAndShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    local contactPoint = GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    if contactPoint ~= nil then
        return contactPoint
    else
        contactPoint = GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
        if contactPoint ~= nil then
            return contactPoint
        else
            return GetEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
        end
    end
end

function GetAirAndShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid,airRange)
    local contactPoint = GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    if contactPoint ~= nil then
        return contactPoint
    else
        contactPoint = GetAirNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,unitGuid,airRange)
        if contactPoint ~= nil then
            return contactPoint
        else
            return GetEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
        end
    end
end

function GetAirAndSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid,airRange)
    local contactPoint = GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
    if contactPoint ~= nil then
        return contactPoint 
    else
        contactPoint = GetAirNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,unitGuid,airRange)
        if contactPoint ~= nil then
            return contactPoint
        else
            return GetEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
        end
    end
end

function GetAllNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid,airRange)
    local contactPoint = GetAirNoNavZoneThatContaintsUnit(sideGuid,shortSideKey,unitGuid,airRange)
    if contactPoint ~= nil then
        return contactPoint
    else
        contactPoint = GetSAMNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
        if contactPoint ~= nil then
            return contactPoint
        else
            contactPoint = GetShipNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
            if contactPoint ~= nil then
                return contactPoint
            else
                return GetEmergencyMissileNoNavZoneThatContainsUnit(sideGuid,shortSideKey,unitGuid)
            end
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Dedicated Fighter Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirFighterInventory(sideShortKey)
    return CombineTablesNew(GetGUID(sideShortKey.."_fig_free"),GetGUID(sideShortKey.."_sfig_free"))
end

function GetBusyAirFighterInventory(sideShortKey)
    return CombineTablesNew(GetGUID(sideShortKey.."_fig_busy"),GetGUID(sideShortKey.."_sfig_busy"))
end

--------------------------------------------------------------------------------------------------------------------------------
-- Get Stealth Fighter Inventory
--------------------------------------------------------------------------------------------------------------------------------
function GetFreeAirStealthInventory(sideShortKey)
    return GetGUID(sideShortKey.."_sfig_free")
end

function GetBusyAirStealthInventory(sideShortKey)
    return GetGUID(sideShortKey.."_sfig_busy")
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

function GetUnknownWeaponContacts(sideShortKey)
    return GetGUID(sideShortKey.."_weap_con_X")
end

function GetHostileWeaponContacts(sideShortKey)
    return GetGUID(sideShortKey.."_weap_con_H")
end

function GetUnknownLandContacts(sideShortKey)
    return GetGUID(sideShortKey.."_land_con_X")
end

function GetHostileLandContacts(sideShortKey)
    return GetGUID(sideShortKey.."_land_con_H")
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
    if #aoPoints < 4 or (currentTime - lastTime) > 15 * 60 then 
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

            -- Save Unit GUID
            AddGUID(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
        end
    end


    -- Loop Through Weapon Contacts
	if weaponContacts then
        for k, v in pairs(weaponContacts) do
            -- Local Values
            local contact = ScenEdit_GetContact({side=side.name, guid=v.guid})
            local unitType = "weap_con"

            --ScenEdit_SpecialMessage("Stennis CSG", contact.name.."_"..contact.type.."_"..contact.type_description)
            -- Save Unit GUID
            AddGUID(sideShortKey.."_"..unitType.."_"..contact.posture,contact.guid)
        end
    end


end

function ResetInventoriesAndContacts(sideShortKey)
    -- Reset Inventory And Contacts
    RemoveAllGUID(sideShortKey.."_non_unav")
    RemoveAllGUID(sideShortKey.."_def_hvt")
    RemoveAllGUID(sideShortKey.."_sfig_free")
    RemoveAllGUID(sideShortKey.."_sfig_busy")
    RemoveAllGUID(sideShortKey.."_fig_free")
    RemoveAllGUID(sideShortKey.."_fig_busy")
    RemoveAllGUID(sideShortKey.."_mul_free")
    RemoveAllGUID(sideShortKey.."_mul_busy")
    RemoveAllGUID(sideShortKey.."_atk_free")
    RemoveAllGUID(sideShortKey.."_atk_busy")
    RemoveAllGUID(sideShortKey.."_sead_free")
    RemoveAllGUID(sideShortKey.."_sead_busy")
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
    RemoveAllGUID(sideShortKey.."_weap_con_X")
    RemoveAllGUID(sideShortKey.."_weap_con_H")
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
    local missions = GetGUID(args.shortKey.."_rec_miss")
    local totalFreeInventory = GetTotalFreeReconAndStealthFighterInventory(args.shortKey)
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

    -- Create Mission
    local createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_rec_miss_"..tostring(missionNumber),"patrol",{type="naval",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true})
    ScenEdit_SetDoctrine({side=side.name,mission=createdMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb ="0",dive_on_threat="2"})
    ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Passive")

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,createdMission.guid,1,totalFreeInventory)

    -- Add Guid
    AddGUID(args.shortKey.."_rec_miss",createdMission.name)
    
    -- Return True
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Recon Doctrine Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function ReconDoctrineUpdateMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_rec_miss")
    local totalFreeBusyInventory = GetTotalFreeBusyReconAndStealthFighterInventory(args.shortKey)
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local missionNumber = 0
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    -- Time
    local currentTime = ScenEdit_CurrentTime()
    local lastTime = GetTimeStampForGUID(args.shortKey.."_rec_miss_ts")

    -- Check Total Is Zero
    if #totalFreeBusyInventory == 0 then -- or (currentTime - lastTime) < 1 * 60 then
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
        DetermineUnitsToAssign(side.name,updatedMission.guid,1,totalFreeBusyInventory)

        -- Find Contact Close To Unit And Evade
        if #updatedMission.unitlist > 0 then
            local supportUnit = ScenEdit_GetUnit({side=side.name, guid=updatedMission.unitlist[1]})
            local unitRetreatPoint = GetAllNoNavZoneThatContainsUnit(args.guid,args.shortKey,supportUnit.guid,100)

            -- SAM Retreat Point
            if unitRetreatPoint ~= nil and supportUnit.unitstate ~= "RTB" then
            	ScenEdit_SetDoctrine({side=side.name,unitname=supportUnit.name},{ignore_plotted_course = "no" })
                supportUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
                supportUnit.manualSpeed = "1100"
        	else
            	ScenEdit_SetDoctrine({side=side.name,unitname=supportUnit.name},{ignore_plotted_course = "yes" })
                supportUnit.manualSpeed = "OFF"
        	end
        end
    end

    -- Set Time
    SetTimeStampForGUID(args.shortKey.."_rec_miss_ts",ScenEdit_CurrentTime())

    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Create Air Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineCreateAirMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_aaw_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeInventory = GetTotalFreeAirFighterInventory(args.shortKey)
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local totalAirUnitsToAssign = GetHostileAirContactsStrength(args.shortKey)
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

    -- Create Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_aaw_miss_"..tostring(missionNumber),"patrol",{type="aaw",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=false,flightSize=2,useFlightSize=true})
    ScenEdit_SetDoctrine({side=side.name,mission=createdMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb ="1",dive_on_threat="2"})
    ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Passive")

    -- Round Up
    if totalAirUnitsToAssign % 2 == 1 then
    	totalAirUnitsToAssign = totalAirUnitsToAssign + 1
    end

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,createdMission.guid,totalAirUnitsToAssign,totalFreeInventory)

    -- Add Guid
    AddGUID(args.shortKey.."_aaw_miss",createdMission.name)

    -- Return True For Mission Created
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Update Air Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineUpdateAirMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_aaw_miss")
    local linkedMissions = GetGUID(args.shortKey.."_aaew_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeBusyInventory = GetTotalFreeBusyAirFighterInventory(args.shortKey)
    local currentTime = ScenEdit_CurrentTime()
    local lastTimeStamp = GetTimeStampForGUID(args.shortKey.."_aaw_miss_ts")
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local updatedMission = {}
    local linkedMission = {}
    local missionNumber = 1
    local totalAAWUnitsToAssign = GetHostileAirContactsStrength(args.shortKey)

    -- Condition Check
    if #missions == 0 then --or (currentTime - lastTimeStamp) < 1 * 60 then
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

    -- Round Up
    if totalAAWUnitsToAssign % 2 == 1 then
    	totalAAWUnitsToAssign = totalAAWUnitsToAssign + 1
    end

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,updatedMission.guid,totalAAWUnitsToAssign,totalFreeBusyInventory)

    -- Find Area And Retreat Point
    local missionUnits = GetGroupLeadsAndIndividualsFromMission(side.name,updatedMission.guid)
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetSAMAndShipNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid)

        -- Retreat Point
        if unitRetreatPoint ~= nil and missionUnit.unitstate ~= "RTB" then
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "no" })
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            missionUnit.manualSpeed = "1000"
        else
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "yes" })
            missionUnit.manualSpeed = "OFF"
        end
    end

    -- Determine EMCON
    DetermineEmconToUnits(args.shortKey,side.name,updatedMission.unitlist)

    -- Add Guid
    SetTimeStampForGUID(args.shortKey.."_aaw_miss_ts",tostring(ScenEdit_CurrentTime()))

    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Create Stealth Air Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineCreateStealthAirMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_saaw_miss")
    local linkedMissions = GetGUID(args.shortKey.."_aaw_miss")
    local totalFreeInventory = GetFreeAirStealthInventory(args.shortKey)
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local totalAirUnitsToAssign = GetHostileAirContactsStrength(args.shortKey)
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactCoordinates = {}
    local hostileContactBoundingBox = {}
    local createdMission = {}
    local linkedMission = {}
    local linkedMissionPoints = {}

    -- Condition Check
    if #missions > 0 or #linkedMissions == 0 or #totalFreeInventory == 0  then
        return false
    end

	-- Get Linked Mission
    linkedMission = ScenEdit_GetMission(side.name,linkedMissions[1])
    linkedMissionPoints = {linkedMission.name.."_rp_1",linkedMission.name.."_rp_2",linkedMission.name.."_rp_3",linkedMission.name.."_rp_4"}
    totalAirUnitsToAssign = math.ceil(#(linkedMission.unitlist)/4)

    -- Create Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_saaw_miss_"..tostring(missionNumber),"patrol",{type="aaw",zone=linkedMissionPoints})
    ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=false,flightSize=2,useFlightSize=true})
    ScenEdit_SetDoctrine({side=side.name,mission=createdMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb ="0"})
    ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Passive")

    -- Round Up
    if totalAirUnitsToAssign % 2 == 1 then
    	totalAirUnitsToAssign = totalAirUnitsToAssign + 1
    end

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,createdMission.guid,totalAirUnitsToAssign,totalFreeInventory)

    -- Add Guid And Add Time Stamp
    AddGUID(args.shortKey.."_saaw_miss",createdMission.name)

    -- Return True For Mission Created
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Update Stealth Air Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineUpdateStealthAirMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_saaw_miss")
    local linkedMissions = GetGUID(args.shortKey.."_aaw_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeBusyInventory = GetTotalFreeBusyAirStealthFighterInventory(args.shortKey)
    local currentTime = ScenEdit_CurrentTime()
    local lastTimeStamp = GetTimeStampForGUID(args.shortKey.."_saaw_miss_ts")
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local updatedMission = {}
    local linkedMission = {}
    local missionNumber = 1
    local totalAAWUnitsToAssign = GetHostileAirContactsStrength(args.shortKey)

    -- Condition Check
    if #missions == 0 then--or (currentTime - lastTimeStamp) < 1 * 60 then
        return false
    end

    --ScenEdit_SpecialMessage("Stennis CSG", "AttackDoctrineUpdateStealthAirMissionAction")

    -- Get Linked Mission
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    linkedMission = ScenEdit_GetMission(side.name,linkedMissions[1])
    totalAAWUnitsToAssign = math.ceil(#(linkedMission.unitlist)/4)

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,updatedMission.guid,1,totalFreeBusyInventory)

    -- Determine EMCON
    DetermineEmconToUnits(args.shortKey,side.name,updatedMission.unitlist)

    -- Find Area And Retreat Point
    local missionUnits = GetGroupLeadsAndIndividualsFromMission(side.name,updatedMission.guid)
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetAllNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,120)

        -- Retreat Point
        if unitRetreatPoint ~= nil and missionUnit.unitstate ~= "RTB" then
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "no" })
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            missionUnit.manualSpeed = "1000"
        else
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "yes" })
            missionUnit.manualSpeed = "OFF"
        end
    end

    -- Add Guid And Add Time Stamp
    SetTimeStampForGUID(args.shortKey.."_saaw_miss_ts",tostring(ScenEdit_CurrentTime()))

    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Create AEW Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineCreateAEWMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_aaew_miss")
    local linkedMissions = GetGUID(args.shortKey.."_aaw_miss")
    local totalFreeInventory = GetFreeAirAEWInventory(args.shortKey)
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactCoordinates = {}
    local hostileContactBoundingBox = {}
    local createdMission = {}
    local linkedMission = {}
    local linkedMissionPoints = {}

    -- Condition Check
    if #missions > 0 or #linkedMissions == 0 or #totalFreeInventory == 0 or GetHostileAirContactsStrength(args.shortKey) == 0 then
        return false
    end

	-- Get Linked Mission
    linkedMission = ScenEdit_GetMission(side.name,linkedMissions[1])
    linkedMissionPoints = {linkedMission.name.."_rp_1",linkedMission.name.."_rp_2",linkedMission.name.."_rp_3",linkedMission.name.."_rp_4"}

    -- Create Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_aaew_miss_"..tostring(missionNumber),"support",{zone=linkedMissionPoints})
    ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=false,flightSize=2,useFlightSize=false})
    ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Active")

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,createdMission.guid,1,totalFreeInventory)

    -- Add Guid And Add Time Stamp
    AddGUID(args.shortKey.."_aaew_miss",createdMission.name)

    -- Return True For Mission Created
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Update AEW Air Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineUpdateAEWAirMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_aaew_miss")
    local linkedMissions = GetGUID(args.shortKey.."_aaw_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeBusyInventory = GetTotalFreeBusyAEWInventory(args.shortKey)
    local currentTime = ScenEdit_CurrentTime()
    local lastTimeStamp = GetTimeStampForGUID(args.shortKey.."_aaew_miss_ts")
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local updatedMission = {}
    local linkedMission = {}
    local missionNumber = 1

    -- Condition Check
    if #missions == 0 then--or (currentTime - lastTimeStamp) < 2 * 60 then
        return false
    end

    -- Get Linked Mission
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    linkedMission = ScenEdit_GetMission(side.name,linkedMissions[1])

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,updatedMission.guid,1,totalFreeBusyInventory)

    -- Find Area And Retreat Point
    local missionUnits = GetGroupLeadsAndIndividualsFromMission(side.name,updatedMission.guid)
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetAllNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,180)

        -- Retreat Point
        if unitRetreatPoint ~= nil and missionUnit.unitstate ~= "RTB" then
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "no" })
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            missionUnit.manualSpeed = "1000"
        else
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "yes" })
            missionUnit.manualSpeed = "OFF"
        end
    end

    -- Add Guid And Add Time Stamp
    SetTimeStampForGUID(args.shortKey.."_aaew_miss_ts",tostring(ScenEdit_CurrentTime()))

    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Create Anti Surface Ship Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineCreateAntiSurfaceShipMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_asuw_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeInventory = GetFreeAirASuWInventory(args.shortKey)
    local totalHostileContacts = GetHostileSurfaceShipContacts(args.shortKey)
    local totalAirUnitsToAssign = GetHostileSurfaceShipContactsStrength(args.shortKey) * 4
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

    -- Create Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_asuw_miss_"..tostring(missionNumber),"patrol",{type="naval",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=false,flightSize=4,useFlightSize=true})
    ScenEdit_SetDoctrine({side=side.name,mission=createdMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb="1",fuel_state_rtb="2",dive_on_threat="2"})
    ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Active")

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,createdMission.guid,totalAirUnitsToAssign,totalFreeInventory)

    -- Add Guid And Add Time Stamp
    AddGUID(args.shortKey.."_asuw_miss",createdMission.name)

    -- Return True For Mission Created
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Update Anti Surface Ship Mission Action
--------------------------------------------------------------------------------------------------------------------------------
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

    -- Condition Check
    if #missions == 0 then--or (currentTime - lastTimeStamp) < 1 * 60 then
        return false
    end

    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)

    -- Update Every 5 Minutes Or Greater
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_asuw_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,updatedMission.guid,totalAAWUnitsToAssign,totalFreeBusyInventory)

    -- Find Area And Return Point
    local missionUnits = GetGroupLeadsAndIndividualsFromMission(side.name,updatedMission.guid)
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetAirAndSAMNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,100)

        -- Unit Retreat Point
        if unitRetreatPoint ~= nil and missionUnit.unitstate ~= "RTB" then
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "no" })
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            missionUnit.manualSpeed = "1000"
        else
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "yes" })
            missionUnit.manualSpeed = "OFF"
        end
    end

    -- Add Guid And Add Time Stamp
    SetTimeStampForGUID(args.shortKey.."_asuw_miss_ts",tostring(ScenEdit_CurrentTime()))

    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Create Sead Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineCreateSeadMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_sead_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeInventory = GetFreeAirSeadInventory(args.shortKey)
    local totalHostileContacts = GetHostileSAMContacts(args.shortKey)
    local totalAirUnitsToAssign = GetHostileSAMContactsStrength(args.shortKey) * 4
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactCoordinates = {}
    local hostileContactBoundingBox = {}
    local createdMission = {}

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

    -- Create Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_sead_miss_"..tostring(missionNumber),"patrol",{type="sead",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=false,flightSize=4,useFlightSize=true})
    ScenEdit_SetDoctrine({side=side.name,mission=createdMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb="1",fuel_state_rtb="2",dive_on_threat="2"})
    ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Passive")

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,createdMission.guid,totalAirUnitsToAssign,totalFreeInventory)

    -- Add Guid
    AddGUID(args.shortKey.."_sead_miss",createdMission.name)

    -- Return True For Mission Created
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Update Sead Mission Action
--------------------------------------------------------------------------------------------------------------------------------
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
    -- Times
    local currentTime = ScenEdit_CurrentTime()
    local lastTimeStamp = GetTimeStampForGUID(args.shortKey.."_sead_miss_ts")

    -- Condition Check
    if #missions == 0 then--or (currentTime - lastTimeStamp) < 1 * 60 then
        return false
    end

    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)

    -- Update Every 5 Minutes Or Greater
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_sead_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,updatedMission.guid,totalAAWUnitsToAssign,totalFreeBusyInventory)

    -- Find Area And Return Point
    local missionUnits = GetGroupLeadsAndIndividualsFromMission(side.name,updatedMission.guid)
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetAirAndShipNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,100)

        -- Set Retreat
        if unitRetreatPoint ~= nil and missionUnit.unitstate ~= "RTB" then
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "no" })
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            missionUnit.manualSpeed = "1000"
        else
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "yes" })
            missionUnit.manualSpeed = "OFF"
        end
    end

    -- Add Time Stamp
    SetTimeStampForGUID(args.shortKey.."_sead_miss_ts",tostring(ScenEdit_CurrentTime()))

    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Create Land Attack Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineCreateLandAttackMissionAction(args)
    -- Local Values
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_land_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeInventory = GetFreeAirAttackInventory(args.shortKey)
    local totalHostileContacts = GetHostileLandContacts(args.shortKey)
    local totalAirUnitsToAssign = GetHostileLandContactsStrength(args.shortKey) * 2
    local missionNumber = 1
    local rp1,rp2,rp3,rp4 = ""
    local hostileContactCoordinates = {}
    local hostileContactBoundingBox = {}
    local createdMission = {}

    -- Condition Check
    if #missions > 0 or #totalFreeInventory == 0 or GetHostileSAMContactsStrength(args.shortKey) == 0 then
        return false
    end

    -- Set Contact Bounding Box Variables
    hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,3)

    -- Set Reference Points
    rp1 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
    rp2 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
    rp3 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
    rp4 = ScenEdit_AddReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})

    -- Create Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_land_miss_"..tostring(missionNumber),"patrol",{type="land",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true,oneThirdRule=false,flightSize=2,useFlightSize=false})
    ScenEdit_SetDoctrine({side=side.name,mission=createdMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb="1",fuel_state_rtb="2",dive_on_threat="2"})
    ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Passive")

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,createdMission.guid,totalAirUnitsToAssign,totalFreeInventory)

    -- Add Guid
    AddGUID(args.shortKey.."_land_miss",createdMission.name)

    -- Return True For Mission Created
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Attack Doctrine Update Land Attack Mission Action
--------------------------------------------------------------------------------------------------------------------------------
function AttackDoctrineUpdateLandAttackMissionAction(args)
    -- Locals
    local side = VP_GetSide({guid=args.guid})
    local missions = GetGUID(args.shortKey.."_land_miss")
    local aoPoints = ScenEdit_GetReferencePoints({side=side.name, area={"AI-AO-1","AI-AO-2","AI-AO-3","AI-AO-4"}})
    local totalFreeBusyInventory = GetTotalFreeBusyAirAttackInventory(args.shortKey)
    local totalHostileContacts = GetHostileLandContacts(args.shortKey)
    local updatedMission = {}
    local missionNumber = 1
    local totalAAWUnitsToAssign = GetHostileLandContactsStrength(args.shortKey) * 2
    -- Times
    local currentTime = ScenEdit_CurrentTime()
    local lastTimeStamp = GetTimeStampForGUID(args.shortKey.."_land_miss_ts")

    -- Condition Check
    if #missions == 0 then--or (currentTime - lastTimeStamp) < 1 * 60 then
        return false
    end

    -- Take First One For Now
    updatedMission = ScenEdit_GetMission(side.name,missions[1])
    hostileContactBoundingBox = FindBoundingBoxForGivenContacts(side.name,totalHostileContacts,aoPoints,4)

    -- Update Every 5 Minutes Or Greater
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_1", lat=hostileContactBoundingBox[1].latitude, lon=hostileContactBoundingBox[1].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_2", lat=hostileContactBoundingBox[2].latitude, lon=hostileContactBoundingBox[2].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_3", lat=hostileContactBoundingBox[3].latitude, lon=hostileContactBoundingBox[3].longitude})
    ScenEdit_SetReferencePoint({side=side.name, name=args.shortKey.."_land_miss_"..tostring(missionNumber).."_rp_4", lat=hostileContactBoundingBox[4].latitude, lon=hostileContactBoundingBox[4].longitude})

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,updatedMission.guid,totalAAWUnitsToAssign,totalFreeBusyInventory)

    -- Find Area And Return Point
    local missionUnits = GetGroupLeadsAndIndividualsFromMission(side.name,updatedMission.guid)
    for k,v in pairs(missionUnits) do
        local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
        local unitRetreatPoint = GetAllNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,100)

		-- Set Retreat
        if unitRetreatPoint ~= nil and missionUnit.unitstate ~= "RTB" then
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "no" })
            missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
            missionUnit.manualSpeed = "1000"
        else
            ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "yes" })
            missionUnit.manualSpeed = "OFF"
        end
    end

    -- Add Time Stamp
    SetTimeStampForGUID(args.shortKey.."_land_miss_ts",tostring(ScenEdit_CurrentTime()))

    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Defend Doctrine Create Air Mission Action
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
    local totalAAWUnitsToAssign = 4

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

    -- Create Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_aaw_d_miss_"..unitToDefend.guid,"patrol",{type="aaw",zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetMission(side.name,createdMission.name,{checkOPA=false,checkWWR=true})
    ScenEdit_SetDoctrine({side=side.name,mission=createdMission.name},{automatic_evasion="yes",maintain_standoff="yes",ignore_emcon_while_under_attack="yes",weapon_state_planned="5001",weapon_state_rtb ="1",dive_on_threat="2"})
    ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Passive")

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,createdMission.guid,totalAAWUnitsToAssign,totalFreeInventory)

    -- Add Guid And Add Time Stamp
    AddGUID(args.shortKey.."_aaw_d_miss",createdMission.name)
    AddGUID(args.shortKey.."_def_hvt_cov",unitToDefend.guid)

    -- Return True For Mission Created
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Defend Doctrine Update Air Mission Action
--------------------------------------------------------------------------------------------------------------------------------
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
    local totalAAWUnitsToAssign = 2
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    -- Times
    local currentTime = ScenEdit_CurrentTime()
    local lastTimeStamp = GetTimeStampForGUID(args.shortKey.."_aaw_d_miss_ts")

    -- Condition Check
    if #missions == 0 then--or (currentTime - lastTimeStamp) < 10 * 60 then
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
                DetermineUnitsToAssign(side.name,updatedMission.guid,totalAAWUnitsToAssign,totalFreeBusyInventory)

                -- Determine EMCON
                DetermineEmconToUnits(args.shortKey,side.name,updatedMission.unitlist)
            end
        end
    end

    -- Add Time Stamp
    SetTimeStampForGUID(args.shortKey.."_aaw_d_miss_ts",tostring(ScenEdit_CurrentTime()))

    -- Return False
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Support Tanker Doctrine Create Mission Action
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

    -- Create Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_tan_sup_miss_"..unitToSupport.guid,"support",{zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Passive")

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,createdMission.guid,1,totalFreeInventory)

    -- Add Guid And Add Time Stamp
    AddGUID(args.shortKey.."_tan_sup_miss",createdMission.name)
    AddGUID(args.shortKey.."_def_tan_hvt_cov",unitToSupport.guid)

    -- Return True For Mission Created
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Support Tanker Doctrine Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
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
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local totalHostilesInZone = 0
    -- Times
    local currentTime = ScenEdit_CurrentTime()
    local lastTimeStamp = GetTimeStampForGUID(args.shortKey.."_tan_sup_miss_ts")

    -- Condition Check
    if #missions == 0 then --or (currentTime - lastTimeStamp) < 10 * 60 then
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
                -- Determine Units To Assign
                DetermineUnitsToAssign(side.name,updatedMission.guid,1,totalBusyFreeInventory)

                -- Find Contact Close To Unit And Retreat If Necessary
                local missionUnits = updatedMission.unitlist
                for k,v in pairs(missionUnits) do
                    local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
                    local unitRetreatPoint = GetAllNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,120)

                    -- Find Retreat Point
                    if unitRetreatPoint ~= nil and missionUnit.unitstate ~= "RTB" then
                        ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "no" })
                        missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
                        missionUnit.manualSpeed = "1000"
                    else
                        ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "yes" })
                        missionUnit.manualSpeed = "OFF"
                    end
                end
            end
        end
    end

    -- Add Time Stamp
    SetTimeStampForGUID(args.shortKey.."_tan_sup_miss_ts",tostring(ScenEdit_CurrentTime()))

    -- Return True
    return false
end

--------------------------------------------------------------------------------------------------------------------------------
-- Support AEW Doctrine Create Mission Action
--------------------------------------------------------------------------------------------------------------------------------
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

    -- Create Mission
    createdMission = ScenEdit_AddMission(side.name,args.shortKey.."_aew_sup_miss_"..unitToSupport.guid,"support",{zone={rp1.name,rp2.name,rp3.name,rp4.name}})
    ScenEdit_SetEMCON("Mission",createdMission.guid,"Radar=Active")

    -- Determine Units To Assign
    DetermineUnitsToAssign(side.name,createdMission.guid,1,totalFreeInventory)

    -- TODO Add EMCON

    -- Add Guid And Add Time Stamp
    AddGUID(args.shortKey.."_aew_sup_miss",createdMission.name)
    AddGUID(args.shortKey.."_def_aew_hvt_cov",unitToSupport.guid)

    -- Return True For Mission Created
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Support AEW Doctrine Update Mission Action
--------------------------------------------------------------------------------------------------------------------------------
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
    local totalHostileContacts = GetHostileAirContacts(args.shortKey)
    local totalHostilesInZone = 0
    -- Times
    local currentTime = ScenEdit_CurrentTime()
    local lastTimeStamp = GetTimeStampForGUID(args.shortKey.."_aew_sup_miss_ts")

    -- Condition Check
    if #missions == 0 then --or #totalBusyFreeInventory == 0 then--or (currentTime - lastTimeStamp) < 10 * 60 then
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
                -- Determine Units To Assign
                DetermineUnitsToAssign(side.name,updatedMission.guid,1,totalBusyFreeInventory)
                -- TODO Add Active EMCON

                -- Find Contact Close To Unit And Retreat If Necessary
                local missionUnits = updatedMission.unitlist
                for k,v in pairs(missionUnits) do
                    local missionUnit = ScenEdit_GetUnit({side=side.name, guid=v})
                    local unitRetreatPoint = GetAllNoNavZoneThatContainsUnit(args.guid,args.shortKey,missionUnit.guid,180)

        			-- Unit Retreat Point
                    if unitRetreatPoint ~= nil and missionUnit.unitstate ~= "RTB" then
                        ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "no" })
                        missionUnit.course={{lat=unitRetreatPoint.latitude,lon=unitRetreatPoint.longitude}}
                        missionUnit.manualSpeed = "1000"
                    else
                        ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "yes" })
                        missionUnit.manualSpeed = "OFF"
                    end
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
-- Monitor Create SAM No Nav Zones Action
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
    local noNavZoneRange = DetermineThreatRangeByUnitDatabaseId(args.guid,contact.guid)

    -- SAM Zone + Range
    local referencePoint = ScenEdit_AddReferencePoint({side=side.name,lat=contact.latitude,lon=contact.longitude,name=tostring(noNavZoneRange),highlighted="no"})
    AddGUID(args.shortKey.."_sam_ex_zone",referencePoint.guid)

    -- Return True
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Monitor Update SAM No Nav Zones Action
--------------------------------------------------------------------------------------------------------------------------------
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

    -- Condition Check
    if #zones == 0 or (currentTime - lastReconTimeStamp) < 3 * 60 then
       return false 
    end

    -- Set New Timestamp
    SetTimeStampForGUID(args.shortKey.."_sam_ex_zone_ts",currentTime)

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

            -- If RTB
        	if missionUnit.unitstate == "RTB" then
            	ScenEdit_SetDoctrine({side=side.name,unitname=missionUnit.name},{ignore_plotted_course = "yes" })
            	missionUnit.manualSpeed = "OFF"
        		break
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
-- Monitor Create Ship No Nav Zones Action
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
    local noNavZoneRange = DetermineThreatRangeByUnitDatabaseId(args.guid,contact.guid)
    
    -- Ship Zone + Range
    local referencePoint = ScenEdit_AddReferencePoint({side=side.name,lat=contact.latitude,lon=contact.longitude,name=tostring(noNavZoneRange),highlighted="no"})
    AddGUID(args.shortKey.."_ship_ex_zone",referencePoint.guid)

    -- Return True
    return true
end

--------------------------------------------------------------------------------------------------------------------------------
-- Monitor Update Ship No Nav Zones Action
--------------------------------------------------------------------------------------------------------------------------------
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

    -- Condition Check
    if #zones == 0 or (currentTime - lastReconTimeStamp) < 3 * 60 then
       return false 
    end

    -- Set New Timestamp
    SetTimeStampForGUID(args.shortKey.."_ship_ex_zone_ts",currentTime)

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
-------------------------------------------------------------------------------------------------------------------------------
function MonitorUpdateAirNoNavZonesAction(args)
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
function InitializeMerimackMonitorAI(sideName,options)
    -- Local Values
    local side = ScenEdit_GetSideOptions({side=sideName})
    local sideGuid = side.guid
    local shortSideKey = "a"..tostring(#commandMerimackAIArray + 1)
    local attributes = InitializeAIAttributes(options)

    -- Main Node Sequence
    local merimackSelector = BT:make(BT.select,sideGuid,shortSideKey,attributes)

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
    local attackDoctrineUpdateAirMissionBT = BT:make(AttackDoctrineUpdateAirMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateAirMissionBT = BT:make(AttackDoctrineCreateAirMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineUpdateStealthAirMissionBT = BT:make(AttackDoctrineUpdateStealthAirMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateStealthAirMissionBT = BT:make(AttackDoctrineCreateStealthAirMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateAEWMissionBT = BT:make(AttackDoctrineCreateAEWMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineUpdateAEWMissionBT = BT:make(AttackDoctrineUpdateAEWAirMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateAntiSurfaceShipMissionBT = BT:make(AttackDoctrineCreateAntiSurfaceShipMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineUpdateAntiSurfaceShipMissionBT = BT:make(AttackDoctrineUpdateAntiSurfaceShipMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateSeadMissionBT = BT:make(AttackDoctrineCreateSeadMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineUpdateSeadMissionBT = BT:make(AttackDoctrineUpdateSeadMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineCreateLandAttackMissionBT = BT:make(AttackDoctrineCreateLandAttackMissionAction,sideGuid,shortSideKey,attributes)
    local attackDoctrineUpdateLandAttackMissionBT = BT:make(AttackDoctrineUpdateLandAttackMissionAction,sideGuid,shortSideKey,attributes)

    -- Defend Doctrine BT
    local defendDoctrineUpdateAirMissionBT = BT:make(DefendDoctrineUpdateAirMissionAction,sideGuid,shortSideKey,attributes)
    local defendDoctrineCreateAirMissionBT = BT:make(DefendDoctrineCreateAirMissionAction,sideGuid,shortSideKey,attributes)

    -- Support Tanker Doctrine BT
    local supportTankerDoctrineUpdateMissionBT = BT:make(SupportTankerDoctrineCreateMissionAction,sideGuid,shortSideKey,attributes)
    local supportTankerDoctrineCreateMissionBT = BT:make(SupportTankerDoctrineUpdateMissionAction,sideGuid,shortSideKey,attributes)

    -- Support AEW Doctrine BT
    local supportAEWDoctrineUpdateMissionBT = BT:make(SupportAEWDoctrineCreateMissionAction,sideGuid,shortSideKey,attributes)
    local supportAEWDoctrineCreateMissionBT = BT:make(SupportAEWDoctrineUpdateMissionAction,sideGuid,shortSideKey,attributes)

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
    offensiveDoctrineSeletor:addChild(defendDoctrineSelector)

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
    attackDoctrineSelector:addChild(attackDoctrineUpdateStealthAirMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateStealthAirMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineUpdateAEWMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateAEWMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineUpdateAntiSurfaceShipMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateAntiSurfaceShipMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineUpdateSeadMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateSeadMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineUpdateLandAttackMissionBT)
    attackDoctrineSelector:addChild(attackDoctrineCreateLandAttackMissionBT)

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

    -- Add All AI's
    commandMerimackAIArray[#commandMerimackAIArray + 1] = merimackSelector
    commandMonitorAIArray[#commandMonitorAIArray + 1] = monitorSelector
end

function UpdateAI()
    -- Update Inventories And Update Merimack AI
    for k, v in pairs(commandMerimackAIArray) do
        UpdateAIInventories(v.guid,v.shortKey)
        UpdateAIAreaOfOperations(v.guid,v.shortKey)
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
InitializeMerimackMonitorAI("Stennis CSG",{preset="Grant",options={aggressive=5,defensive=5,cunning=5,direct=5,determined=5,reserved=5}})