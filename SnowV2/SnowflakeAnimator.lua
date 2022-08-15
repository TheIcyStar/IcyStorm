-- // Internal Variables & Initialization --
local settings = {}
local snowflakeCollection = {}			  --SnowflakeObject[]
local availableSnowflakeIndexes = {}	  --Number[]
local imageTints						  --String[]
local fps, TotalLifetimeFrames, SpawnRate --Number, Number, Number

function Initialize()
	settings = GetSkinVariables({
		"UpdateRate",
		"NumSnowflakes",
		"SnowflakeAntiAlias",
		"TotalScreenAreaX",
		"TotalScreenAreaY",
		"Lifetime",
		"NumImageTints",
		"StartX",
		"EndX",
		"StartY",
		"EndY",
		"MinTransparency",
		"MaxTransparency",
		"MinSize",
		"MaxSize",
		"MinFallSpeed",
		"MaxFallSpeed",
		"MinSway",
		"MaxSway",
		"MinSwayTime",
		"MaxSwayTime",
		"WindType",
		"MinWindSpeed",
		"MaxWindSpeed",
		"RerollChance",
		"DebugMode"
	})
	for i=1,settings.NumSnowflakes do
		snowflakeCollection[i] = InitSnowflake(i)
		availableSnowflakeIndexes[i] = i
	end
	imageTints = GetImageTints(settings.NumImageTints)

	fps = 1000 / settings.UpdateRate
	TotalLifetimeFrames = fps * settings.Lifetime
	SpawnRate = math.ceil(TotalLifetimeFrames / settings.NumSnowflakes)

	print("[IcyStorm] Loaded!")
end


-- // Utility Functions --
-- These functions are commented with Luau-style typings for arguments and return values. Learn more here: https://luau-lang.org/typecheck

--Easing animation function
--time: how much time has to pass for the tweening to complete
--begin: starting value
--change: ending - starting
--duration: running time. How much time has passed *right now*
--`InOutQuad(Time: Number, begin: Number, change: Number, duration: Number): Number`
function InOutQuad(Time,begin,change,duration)
	Time = Time / duration * 2
	if Time < 1 then return change / 2 * math.pow(Time, 2) + begin end
	return -change / 2 * ((Time - 1) * (Time - 3) - 1) + begin
end

--Retrieves variables from the SKIN object
--`GetSkinVariables(variablesArray: String[]): {String[]: String | Number}`
function GetSkinVariables(variablesArray)
	local settingsList = {}
	for i,setting in pairs(variablesArray) do
		local result = tonumber(SKIN:GetVariable(setting))
		if not result then
			print("[IcyStorm ERROR] Missing '"..setting.."` variable from Snow.ini!")
		end
		settingsList[setting] = result
	end

	return settingsList
end


--Retrieves "ImageTintN" variables where N is 1 - N
--`GetImageTints(indexes: Number): String[]`
function GetImageTints(indexes)
	if indexes == 0 then
		return {}
	end

	local tints = {}
	for i=1, indexes do
		local result = SKIN:GetVariable("ImageTint"..i)
		if not result then
			print("[ERROR] Missing 'ImageTint"..i.."` variable from Snow.ini!")
		end
		table.insert(tints,result)
	end

	return tints
end




-- // Meter-related functions --

--Initialize the snowflake Object
--Use the return as a pseudo-definition of SnowflakeObject
--`InitSnowflake(snowflakeIndex: Number): SnowflakeObject`
function InitSnowflake(snowflakeIndex)
	local meter = SKIN:GetMeter("MeterSnowflake"..snowflakeIndex)
	if not meter then
		print("[IcyStorm ERROR] Missing `MeterSnowflake"..snowflakeIndex.."` in Snow.ini! Add it or change `NumSnowflakes`!")
	end
	return {
		meter = meter,
		index = snowflakeIndex,
		x = 0,
		y = 0,
		transparency = 0,
		fadeMultiplier = 1, --Added on top of transparency during near end of lifetime
		size = 0,
		tint = "255,255,255",
		spawnedAt = 0,
		fallSpeed = 0,
		sway = 0,
		swayTime = 0,
		swayInterval = 0,
		totalSway = 0, --The actual value that gets added to x position
		windSpeed = 0,
		totalWind = 0, --The actual value that gets added to x position
		alive = false,
	}
end

--Finds an unused snowflake,sets its initial values, and calls ApplySnowflake()
--`SpawnSnowflake(timer: number): nil
function SpawnSnowflake(timer)
	if #availableSnowflakeIndexes == 0 then
		print("[IcyStorm WARN] Ran out of measures to use during snowflake spawning! Change either SpawnRate or add snowflake meters!")
		return
	end

	--Setup
	local distance = (math.random(0,100))/100
	local spawningObj = snowflakeCollection[availableSnowflakeIndexes[1]]
	table.remove(availableSnowflakeIndexes, 1)

	--Calculate and apply properties
	spawningObj.x = math.random(settings.StartX, settings.EndX)
	spawningObj.y = math.random(settings.StartY, settings.EndY)
	spawningObj.alive = true
	spawningObj.size = settings.MinSize + (distance * (settings.MaxSize - settings.MinSize))
	spawningObj.spawnedAt = timer
	spawningObj.fallSpeed = settings.MinFallSpeed + (distance * (settings.MaxFallSpeed - settings.MinFallSpeed))
	spawningObj.sway = settings.MinSway + (distance * (settings.MaxSway - settings.MinSway))
	spawningObj.swayTime = math.floor(settings.MinSwayTime + (distance * (settings.MaxSwayTime - settings.MinSwayTime)))
	spawningObj.transparency = math.floor(settings.MinTransparency + (distance * (settings.MaxTransparency - settings.MinTransparency)))

	spawningObj.swayInterval = math.random(0, spawningObj.swayTime)
	spawningObj.totalSway = 0
	spawningObj.totalWind = 0
	spawningObj.fadeMultiplier = 1


	--Calculate wind
	if settings.WindType == 0 then
		spawningObj.windSpeed = settings.MinWindSpeed + (distance * (settings.MaxWindSpeed - settings.MinWindSpeed))
	else
		spawningObj.windSpeed = math.random(settings.MinWindSpeed*10, settings.MaxWindSpeed*10)/10
	end

	--Choose tint
	if #imageTints > 0 then
		spawningObj.tint = imageTints[math.random(1, #imageTints)]
	end

	--Finally, spawn the meter
	ApplySnowflake(timer, spawningObj, true)
	
end

--Changes and applies values to the snowflakeObject
--`UpdateSnowflake(timer: Number, SnowflakeObject: SnowflakeObject)--🤔: SnowflakeObject`
function UpdateSnowflake(timer, SnowflakeObject)
	if not SnowflakeObject.alive then return end

	--sway
	local newSwayPos
	if settings.MinSway ~= 0 and settings.MaxSway ~= 0 then
		if SnowflakeObject.swayInterval <= SnowflakeObject.swayTime/2 then
			newSwayPos = InOutQuad(
				SnowflakeObject.swayInterval,
				0,
				SnowflakeObject.sway,
				SnowflakeObject.swayTime / 2
			)
		else
			newSwayPos = InOutQuad(
				SnowflakeObject.swayInterval - (SnowflakeObject.swayTime / 2),
				SnowflakeObject.sway,
				-SnowflakeObject.sway,
				SnowflakeObject.swayTime / 2
			)
		end

		SnowflakeObject.swayInterval = (SnowflakeObject.swayInterval + 1) % SnowflakeObject.swayTime
	end
	SnowflakeObject.totalSway = math.floor(newSwayPos)

	--wind
	if settings.WindType == 1 then
		if timer % math.floor(fps/10) == 0 then
			if math.random(0,100) <= settings.RerollChance then
				SnowflakeObject.windSpeed = math.random(MinWindSpeed,MaxWindSpeed)
			end
		end
	end
	SnowflakeObject.totalWind = SnowflakeObject.totalWind + SnowflakeObject.windSpeed

	--calculate fade if nearing end of lifetime
	if (timer - SnowflakeObject.spawnedAt) > (TotalLifetimeFrames * 0.75) then
		local endingFrames = (timer - SnowflakeObject.spawnedAt)-(TotalLifetimeFrames*0.75)
		local fadeTime = TotalLifetimeFrames-(TotalLifetimeFrames*0.75)

		SnowflakeObject.fadeMultiplier = (fadeTime-endingFrames)/fadeTime
	end


	--Removal
	--On out of bounds
	if (SnowflakeObject.x > settings.TotalScreenAreaX or SnowflakeObject.y > settings.TotalScreenAreaY) and false then
		SnowflakeObject.alive = false
		table.insert(availableSnowflakeIndexes, SnowflakeObject.index)
	--On Lifetime
	elseif SnowflakeObject.spawnedAt + TotalLifetimeFrames <= timer then
		SnowflakeObject.alive = false
		table.insert(availableSnowflakeIndexes, SnowflakeObject.index)
	end

	return SnowflakeObject
end

--Sends Rainmeter calls to update the SnowflakeObject's meter
--`ApplySnowflake(timer: number, SnowflakeObject: SnowflakeObject, applySize: Bool?): nil`
function ApplySnowflake(timer, SnowflakeObject, applySize)
	if not SnowflakeObject.alive then return end

	--Calculate positions
	local calculatedX = math.floor(SnowflakeObject.x + SnowflakeObject.totalSway + SnowflakeObject.totalWind)
	local calculatedY = SnowflakeObject.y + (SnowflakeObject.fallSpeed * (timer - SnowflakeObject.spawnedAt))

	SnowflakeObject.meter:SetX(calculatedX)
	SnowflakeObject.meter:SetY(calculatedY)
	SKIN:Bang(
		"!SetOption",
		"MeterSnowflake"..SnowflakeObject.index,
		"ImageTint",
		SnowflakeObject.tint..","..(SnowflakeObject.transparency * SnowflakeObject.fadeMultiplier)
	)

	if applySize then
		-- SnowflakeObject.meter:SetW(SnowflakeObject.size) --Apparently :SetW() and :SetH() don't work at all 😓
		-- SnowflakeObject.meter:SetH(SnowflakeObject.size)
		SKIN:Bang("!SetOption","MeterSnowflake"..SnowflakeObject.index,"W",SnowflakeObject.size)
		SKIN:Bang("!SetOption","MeterSnowflake"..SnowflakeObject.index,"H",SnowflakeObject.size)

	end
end



-- // Main Update Funcion --

local timer = 0
function Update()
	--Spawn new snowflake based on SpawnRate
	if timer % SpawnRate == 0 then
		SpawnSnowflake(timer)
	end

	--Update and apply each snowflake
	for i,snowflakeObj in pairs(snowflakeCollection) do
		-- snowflakeCollection[i] = UpdateSnowflake(timer, snowflakeObj)
		UpdateSnowflake(timer, snowflakeObj)
		ApplySnowflake(timer, snowflakeObj)
	end

    --Manage timer
    timer = (timer + 1) % (SpawnRate * 100000)

	--Debug
	if settings.DebugMode == 0 then
		return
	elseif settings.DebugMode == 1 then
		print("[IcyStorm DEBUG] On screen: "..(#snowflakeCollection - #availableSnowflakeIndexes).." / Total: "..#snowflakeCollection)
	elseif settings.DebugMode == 2 then
		local obj = snowflakeCollection[1]
		print("[IcyStorm DEBUG] ["..obj.index.."] Pos: ("..obj.x..","..obj.y..") Alive:"..(obj.alive and "true" or "false").." Lifetime:"..(timer - obj.spawnedAt).." FallSpeed:"..obj.fallSpeed.." Sway:"..obj.sway.." swayTime:"..obj.swayTime.." SwayInterval:"..obj.swayInterval.." WindSpeed:"..obj.windSpeed.." TotalWind:"..obj.totalWind.." Tint:"..obj.tint)
	end
end