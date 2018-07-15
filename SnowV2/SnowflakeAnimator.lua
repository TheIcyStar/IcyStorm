--[[
   |--------------------------------------------|
   |	   TheIcyStar's snowing script			|
   |	 	    Realistic  version				|
   |--------------------------------------------|
   	BTC: 14KNUpohrrMH4sEhcUkBJ9iERjmKGGAHiJ	
	
	Part of IcyStorm V2
	
	All variables are in Snow.ini
	Does not support dynamic variables - Because of performance optimizations.	(well, if you make an UpdateVariables() function, I guess that could work. I'm not doing that though.)
	
	How this works:
	On Initialize, 
		get all variables
		make a table of meters availible to use
	On update,
		for every particle on screen:
			Grab the particle's data (distance, wind speed, location, etc)
			if Wind needs rerolling, reroll wind
			calculate sway
			SET X
			SET Y
			Update stored values
			check for particle removal
				if the lifetime is about to end, start fading
				if the lifetime is reached, remove particle
				if the particle reached the screen's bounds, remove particle
		When it's time to add a particle
			calculate all variables based on one "Distance" variable (makes this entire thing feel WAAAAY less flat.)
			Calculate value wind that will be used
			store generated variables and put particle into "snowflakesInUse"
			
	Things to note:
	The spawning rate is based on a particle's lifetime. I can NOT get the spawnrate to be proportional to the time a particle gets to the bottom of the screen
	because of the randomness involved of the particle's speeds.
		
--]]

local particleTable = {}

local snowflakesInUse = {}
local snowflakesAvailible = {}
local snowflakeData = {}
local tints = {}
local tintsActive = false
local windActive = false
--Maybe this will fix some errors?
--local SpawnRate = 1000

--[[ easing function
-- t = time == how much time has to pass for the tweening to complete
-- b = begin == starting value
-- c = change == ending - beginning
-- d = duration == running time. How much time has passed *right now*
--Icy's note: function found on github, line 54-61: https://github.com/EmmanuelOga/easing/blob/master/lib/easing.lua
--			  swap Time and duration, or you'll be getting infinity whem all you need is a ten. took me a day of pain to figure out
--]]
function InOutQuad (Time,begin,change,duration)
	Time = Time / duration * 2
	if Time < 1 then return change / 2 * math.pow(Time, 2) + begin end
	return -change / 2 * ((Time - 1) * (Time - 3) - 1) + begin
end
--]]

--Aquires variables and skins on refresh
function Initialize()
	UpdateRate = tonumber(SKIN:GetVariable("UpdateRate"))
	NumSnowflakes = tonumber(SKIN:GetVariable("NumSnowflakes"))
	Lifetime = tonumber(SKIN:GetVariable("Lifetime"))
	WorkAreaX = tonumber(SKIN:GetVariable("TotalScreenAreaX"))
	WorkAreaY = tonumber(SKIN:GetVariable("TotalScreenAreaY"))
	NumImageTints = tonumber(SKIN:GetVariable("NumImageTints"))
	if NumImageTints ~= 0 then
		for i=1,NumImageTints do
			tints[i] = SKIN:GetVariable("ImageTint"..i)
		end
		tintsActive = true
	end
	MinRot = tonumber(SKIN:GetVariable("MinRot"))
	MaxRot = tonumber(SKIN:GetVariable("MaxRot"))
	StartX = tonumber(SKIN:GetVariable("StartX"))
	EndX = tonumber(SKIN:GetVariable("EndX"))
	StartY = tonumber(SKIN:GetVariable("StartY"))
	EndY = tonumber(SKIN:GetVariable("EndY"))
	MinTransparency = tonumber(SKIN:GetVariable("MinTransparency"))
	MaxTransparency = tonumber(SKIN:GetVariable("MaxTransparency"))
	MinSize = tonumber(SKIN:GetVariable("MinSize"))
	MaxSize = tonumber(SKIN:GetVariable("MaxSize"))
	MinFallSpeed = tonumber(SKIN:GetVariable("MinFallSpeed"))
	MaxFallSpeed = tonumber(SKIN:GetVariable("MaxFallSpeed"))
	MinSway = tonumber(SKIN:GetVariable("MinSway"))
	MaxSway = tonumber(SKIN:GetVariable("MaxSway"))
	MinSwayTime = tonumber(SKIN:GetVariable("MinSwayTime"))
	MaxSwayTime = tonumber(SKIN:GetVariable("MaxSwayTime"))
	DampSwayNum = tonumber(SKIN:GetVariable("DampSway"))
	if DampSwayNum ~= 0 then
		DampActive = true
	end
	MinWindSpeed = tonumber(SKIN:GetVariable("MinWindSpeed"))
	MaxWindSpeed = tonumber(SKIN:GetVariable("MaxWindSpeed"))
	if MinWindSpeed ~= MaxWindSpeed then
		windActive = true
	elseif MinWindSpeed == MaxWindSpeed and MinWindSpeed ~= 0 then
		windActive = true
		WindStable = true
	end
	WindType = tonumber(SKIN:GetVariable("WindType"))
	RerollChance = tonumber(SKIN:GetVariable("RerollChance"))
	DebugMode = tonumber(SKIN:GetVariable("DebugMode"))
	
	--Acquires Meters, creates snowflake objects
	for i=1,NumSnowflakes do
		local newMeter = {
			["meter"] = SKIN:GetMeter("MeterSnowflake"..i),
			["name"] = "MeterSnowflake"..i, --old version of this had the script get the name EVERY time it worked with a flake. Oof.
			["distance"] = 0,
			["size"] = 0,
			["tint"] = "0",
			["fallSpeed"] = 0,
			["sway"] = 0,
			["swayTime"] = 0,
			["swayInterval"] = 0,
			["windSpeed"] = 0,
			["totalWind"] = 0,
			["lifeFrames"] = 0,
			["StartingX"] = 0,
			["Transparency"] = 0,
			["X"] = 0,
			["Y"] = 0,
			--["isActive"] = false, --probably not needed, just gonna use a separate table to get list of usable particles
		}
		
		ParticleTable[i] = newMeter
		snowflakesAvailible[i] = newMeter
		if not ParticleTable[i] then
			print("ERROR! Snowflake meter number "..i.." not found! Check names or adjust the variable NumSnowflakes")
		end
	end
	
	--Variables used for timing and other things
	fps = 1000/UpdateRate
	TotalLifetimeFrames = Lifetime*fps
	SpawnRate = math.ceil(TotalLifetimeFrames/NumSnowflakes)--it's fine to set spawnrate to another value. However, this script can only spawn how many snowflakes are available to use.
end


local timer = 1 --used for snowflake spawn delays
function Update()
	--================--
	--snowflake moving--
	--================--
	for i,v in pairs(snowflakesInUse) do
		--[[
			local meterName = meter:GetName()
			local x = snowflakeData[meterName.."X"]
			local y = snowflakeData[meterName.."Y"]
			local StartingX = snowflakeData[meterName.."StartingX"]
			local LifeFrames = snowflakeData[meterName.."LifeFrames"]
			local FallSpeed = snowflakeData[meterName.."FallSpeed"]
			local Sway = snowflakeData[meterName.."Sway"]
			local SwayTime = snowflakeData[meterName.."SwayTime"]
			local SwayInterval = snowflakeData[meterName.."SwayInterval"]
			local WindSpeed = snowflakeData[meterName.."WindSpeed"]
			local TotalWind = snowflakeData[meterName.."TotalWind"]
		--]]
		
		--wind rerolls 10 times per second
		if WindType == 1 then
			if timer%math.floor(fps/10) == 0 then
				local roll = math.random(0,100)
				if roll <= RerollChance then
					v.WindSpeed = math.random(MinWindSpeed,MaxWindSpeed)
				end
			end
		end
		
		--sway
		local SwayPos = 0 --temp
		if MinSway ~= 0 and MaxSway ~= 0 then
			--OH MAN I AM NOT GOOD WITH MATHEMATIC PLS TO HELP
			if v.swayInterval <= v.SwayTime/2 then
				SwayPos = InOutQuad(v.swayInterval, v.startingX+v.sway, -v.sway*2, v.swayTime/2)
			else
				SwayPos = InOutQuad(v.swayInterval-(v.swayTime/2), v.startingX-v.sway, v.sway*2, v.swayTime/2)
			end
			
			v.swayInterval = (v.swayInterval + 1) % v.SwayTime --resetting sway interval, efficiently.
		end
		SwayPos = math.floor(SwayPos)
		--wind
		if windActive then
			v.totalWind = v.totalWind + v.windSpeed
		end
		
		--TODO: Move the SetX and SetYs to after the removal checks to save resources
		--(x value calculation)
		v.X = math.floor(v.X + w.swayPos + v.totalWind)
		v.meter:SetX(v.X)
		
		--(y value calculation)
		v.Y = v.Y + v.FallSpeed
		v.meter:SetY(v.Y)
		
		--removal based on screen size 
		if v.Y > WorkAreaY or v.X > WorkAreaX*2 then
			table.remove(snowflakesInUse,i)
			snowflakesAvailible[#snowflakesAvailible+1] = v.meter
			
		--removal based on lifetime
		--lifeframes = current duration of particle's life in frames
		--TotalLifetimeFrames = when the particle dies
		elseif v.lifeFrames >= totalLifetimeFrames then
			table.remove(snowflakesInUse,i)
			snowflakesAvailible[#snowflakesAvailible+1] = v.meter
			
		elseif v.lifeFrames > (TotalLifetimeFrames*0.85) then --fade out
			--anti mess
			local Life = (v.lifeFrames - (TotalLifetimeFrames*0.75))
			local Teim = (TotalLifetimeFrames - (TotalLifetimeFrames*0.75))
			--
			local transparency = ((Teim-Life)/Teim)*256-1
			
			if tintsActive then
				SKIN:Bang("!SetOption",meterName,"ImageTint",v.tint..","..transparency)
			else
				SKIN:Bang("!SetOption",meterName,"ImageTint","255,255,255,"..transparency)
			end
			
			v.lifeFrames = v.LifeFrames + 1
		else
			v.lifeFrames = v.LifeFrames + 1
		end --you know what? I really don't like how this removal system works. I can't really calculate the correct spawnrate based on the random intervals of snowflakes reaching
		    --the bottom of the screen. I have to find some crappy balance between having slow snowflakes fading out in the middle of the screen and the unused number of snowflakes.
		
		--[debug
		if DebugMode ~= 0 then --3 less calculations from this. woooow so helpfulll /s
			
			if DebugMode == 1 then
				print("OnScreen: "..#snowflakesInUse.."/ Availible: "..NumSnowflakes)
			elseif DebugMode == 2 then
				if meterObj = particleTable[1] then
					print("X:"..meterObj.X.." Y:"..meterObj.Y.." LifeFrames:"..meterObj.lifeFrames.." FallSpeed:"..meterObj.fallSpeed.." Sway:"..meterObj.sway.." TimeToSway:"..meterObj.swayTime.." SwayInterval:"..meterObj.swayInterval.." WindSpeed:"..meterObj.windSpeed.." TotalWind:"..meterObj.totalWind)
				end	
			elseif DebugMode == 3 then
				print("OnScreen: "..#snowflakesInUse.."/ Availible: "..NumSnowflakes.." SpawnRateInFrames:"..SpawnRate.." TotalLifetimeFrames"..TotalLifetimeFrames.." FPS:"..1000/UpdateRate)
			end
		end
		--]]
		
	end
	
	
	
	--==================--
	--Snowflake spawning--
	--==================--
	if timer%SpawnRate == 0 then
		if #snowflakesAvailible ~= 0 then
			local meterObj = snowflakesAvailible[1]
			table.remove(snowflakesAvailible,1)
			
			--Settings values based on distance
			meterObj.distance = (math.random(0,100))/100 --distance is linear, what would happen if these values were logarithmic?
			meterObj.size = MinSize+(meterObj.distance*(MaxSize-MinSize))
			meterObj.fallSpeed = MinFallSpeed+(meterObj.distance*(MaxFallSpeed-MinFallSpeed))
			meterObj.sway = MinSway+(meterObj.distance*(MaxSway-MinSway))
			meterObj.swayTime = MinSwayTime+(meterObj.distance*(MaxSwayTime-MinSwayTime))
			meterObj.transparency = math.floor(MinTransparency+(Distance*(MaxTransparency-MinTransparency)))
			
			--wind speed logic
			local newWindSpeed = 0
			if windActive then
				if WindStable then
					newWindSpeed = MinWindSpeed
				else
					if WindType == 0 then --default wind (variation only on distance)
						newWindSpeed = MinWindSpeed+(Distance*(MaxWindSpeed-MinWindSpeed))
					elseif WindType == 2 then --wind 2 (random variation only calculated once)
						if MaxWindSpeed > MinWindSpeed then
							newWindSpeed = math.random(MinWindSpeed*10,MaxWindSpeed*10)/10 --adding these tens because someone might like decimals.
						elseif MaxWindSpeed < MinWindSpeed then
							newWindSpeed = math.random(MaxWindSpeed*10,MinWindSpeed*10)/10
						end
					end
				end --what if I have a proper random wind + distance formula? I wonder how that would look like
			end
			
			meterObj.windSpeed = newWindSpeed
			
			
			--X and Y spawning position values
			meterObj.X = math.random(StartX,EndX)
			meterObj.startingX = meterObj.X
			meterObj.Y = math.random(StartY,EndY)
			
			
			--transparency and image tints
			if meterObj.transparency < 0 then
				meterObj.transparency = 0
			elseif meterObj.transparency > 255 then
				meterObj.transparency = 255
			end

			if tintsActive then
				local ActiveTint = tints[math.random(1,#tints)]
				SKIN:Bang("!SetOption", meterObj.name, "ImageTint", ActiveTint..","..Transparency)
				meterObj.tint = ActiveTint
			else
				SKIN:Bang("!SetOption", meterObj.name, "ImageTint", "255,255,255,"..Transparency)
			end
			
			--rest of the values
			SKIN:Bang('[!SetOption "'..meterObj.name..' "W" "'..meterObj.size..'"][!SetOption "'..meterObj.name..'" "H" "'..meterObj.size..'"]')
			meter:SetX(x)
			meter:SetY(y)
			snowflakesInUse[#snowflakesInUse+1] = meter
			
		else
			print("Tried to spawn a snowflake, but failed due to lack of snowflakesAvailible ! Change either SpawnRate or add snowflake meters!")
		end
	end
	
	--timer stuff
	timer = (timer + 1) % (SpawnRate*100000) --don't want to eventually have an overflow (if that can happen... better safe than sorry?)
end














