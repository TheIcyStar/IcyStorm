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
			store generated variables and put particle into "SnowflakesInUse"
			
	Things to note:
	The spawning rate is based on a particle's lifetime. I can NOT get the spawnrate to be proportional to the time a particle gets to the bottom of the screen
	because of the randomness involved of the particle's speeds.
		
--]]
local SnowflakesAvailible = {}
local SnowflakesInUse = {}
local SnowflakeData = {}
local Tints = {}
local TintsActive = false
local WindActive = false
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
			Tints[i] = SKIN:GetVariable("ImageTint"..i)
		end
		TintsActive = true
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
		WindActive = true
	elseif MinWindSpeed == MaxWindSpeed and MinWindSpeed ~= 0 then
		WindActive = true
		WindStable = true
	end
	WindType = tonumber(SKIN:GetVariable("WindType"))
	RerollChance = tonumber(SKIN:GetVariable("RerollChance"))
	DebugMode = tonumber(SKIN:GetVariable("DebugMode"))
	
	--Aquires Meters
	for i=1,NumSnowflakes do
		local meter = SKIN:GetMeter("MeterSnowflake"..i)
		SnowflakesAvailible[i] = meter
		if not SnowflakesAvailible[i] then
			print("ERROR! Snowflake meter number "..i.." not found! Change names or adjust the variable NumSnowflakes")
		end
	end
	
	--Variables used for timing and other things
	fps = 1000/UpdateRate
	TotalLifetimeFrames = Lifetime*fps
	SpawnRate = math.ceil(TotalLifetimeFrames/NumSnowflakes)--it's fine to set spawnrate to another value. However, this script can only spawn how many snowflakes are availible to use.
end


local timer = 1 --used for snowflake spawn delays
function Update()
	--================--
	--snowflake moving--
	--================--
	for i=1,#SnowflakesInUse do
		local meter = SnowflakesInUse[i]
		if meter then
			local meterName = meter:GetName()
			local x = SnowflakeData[meterName.."X"]
			local y = SnowflakeData[meterName.."Y"]
			local StartingX = SnowflakeData[meterName.."StartingX"]
			local LifeFrames = SnowflakeData[meterName.."LifeFrames"]
			local FallSpeed = SnowflakeData[meterName.."FallSpeed"]
			local Sway = SnowflakeData[meterName.."Sway"]
			local SwayTime = SnowflakeData[meterName.."SwayTime"]
			local SwayInterval = SnowflakeData[meterName.."SwayInterval"]
			local WindSpeed = SnowflakeData[meterName.."WindSpeed"]
			local TotalWind = SnowflakeData[meterName.."TotalWind"]
			
			--wind rerolls 10 times per second
			if WindType == 1 then
				if timer%math.floor(fps/10) == 0 then
					local roll = math.random(0,100)
					if roll <= RerollChance then
						WindSpeed = math.random(MinWindSpeed,MaxWindSpeed)
					end
				end
			end
			
			--sway
			local SwayPos = 0 --temp
			if MinSway ~= 0 and MaxSway ~= 0 then
				--OH MAN I AM NOT GOOD WITH MATHEMATIC PLS TO HELP
				if SwayInterval <= SwayTime/2 then
					SwayPos = InOutQuad(SwayInterval,StartingX+Sway,-Sway*2,SwayTime/2)
				else
					SwayPos = InOutQuad(SwayInterval-(SwayTime/2),StartingX-Sway,Sway*2,SwayTime/2)
				end
				
				if SwayInterval < SwayTime then --resetting sway interval
					SwayInterval = SwayInterval + 1
				else
					SwayInterval = 0
				end
				SnowflakeData[meterName.."SwayInterval"] = SwayInterval
			end
			SwayPos = math.floor(SwayPos)
			--wind
			if WindActive then
				TotalWind = TotalWind + WindSpeed
			end
			
			--(x value calculation)
			x=math.floor(x+SwayPos+TotalWind)
			meter:SetX(x)
	--		SnowflakeData[meterName.."X"]
			
			--(y value calculation)
			y = y + FallSpeed
			meter:SetY(y)
			SnowflakeData[meterName.."Y"] = y
			
			--stored value updating
			SnowflakeData[meterName.."SwayInterval"] = SwayInterval
			SnowflakeData[meterName.."TotalWind"] = TotalWind
			
			--removal based on screen size 
			if y > WorkAreaY or x > WorkAreaX*2 then
				table.remove(SnowflakesInUse,i)
				SnowflakesAvailible[#SnowflakesAvailible+1] = meter
				
			--[removal based on lifetime
			--lifeframes = current duration of particle's life in frames
			--TotalLifetimeFrames = when the particle dies
			elseif LifeFrames >= TotalLifetimeFrames then
				table.remove(SnowflakesInUse,i)
				SnowflakesAvailible[#SnowflakesAvailible+1] = meter
				
			elseif LifeFrames > (TotalLifetimeFrames*0.85) then --fade out
				--anti mess
				local Life = (LifeFrames-(TotalLifetimeFrames*0.75))
				local Teim = (TotalLifetimeFrames-(TotalLifetimeFrames*0.75))
				--
				local transparency = ((Teim-Life)/Teim)*256-1
				
				if TintsActive then
					SKIN:Bang("!SetOption",meterName,"ImageTint",SnowflakeData[meterName.."Tint"]..","..transparency)
				else
					SKIN:Bang("!SetOption",meterName,"ImageTint","255,255,255,"..transparency)
				end
				
				SnowflakeData[meterName.."LifeFrames"] = LifeFrames + 1
			else
				SnowflakeData[meterName.."LifeFrames"] = LifeFrames + 1
			end --you know what? I really don't like how this removal system works. I can't really calculate the correct spawnrate based on the random intervals of snowflakes reaching
			--]]--the bottom of the screen. I have to find some crappy ballance between having slow snowflakes fading out in the middle of the screen and the unused numebr of snowflakes.
			
			--[debug
			if DebugMode ~= 0 then --3 less calculations from this. woooow so helpfulll /s
				
				if DebugMode == 1 then
					print("OnScreen: "..#SnowflakesInUse.."/ Availible: "..NumSnowflakes)
				elseif DebugMode == 2 then
					if meterName == "MeterSnowflake1" then
						print("X:"..x.." Y:"..y.." LifeFrames:"..LifeFrames.." FallSpeed:"..FallSpeed.." Sway:"..Sway.." TimeToSway:"..SwayTime.." SwayInterval:"..SwayInterval.." WindSpeed:"..WindSpeed.." TotalWind:"..TotalWind)
					end	
				elseif DebugMode == 3 then
					print("OnScreen: "..#SnowflakesInUse.."/ Availible: "..NumSnowflakes.." SpawnRateInFrames:"..SpawnRate.." TotalLifetimeFrames"..TotalLifetimeFrames.." FPS:"..1000/UpdateRate)
				end
			end
			--]]
			
		end
	end
	
	
	
	--==================--
	--Snowflake spawning--
	--==================--
	if timer%SpawnRate == 0 then
		if #SnowflakesAvailible ~= 0 then
			local meter = SnowflakesAvailible[1]
			local meterName = meter:GetName()
			table.remove(SnowflakesAvailible,1)
			local x = 0 -- two temporary --
			local y = 0	--    values     --
			
			--Calculating values based on distance
			local Distance = (math.random(0,100))/100 --distance is linear, what would happen if these values were logarithmic?
			local Size = MinSize+(Distance*(MaxSize-MinSize))
			local FallSpeed = MinFallSpeed+(Distance*(MaxFallSpeed-MinFallSpeed))
			local Sway = MinSway+(Distance*(MaxSway-MinSway))
			local SwayTime = MinSwayTime+(Distance*(MaxSwayTime-MinSwayTime))
			local Transparency = math.floor(MinTransparency+(Distance*(MaxTransparency-MinTransparency)))
			
			--wind speed logic
			local WindSpeed = 0 --I should really learn how to not to use these temp values
			if WindActive then
				if WindStable then
					WindSpeed = MinWindSpeed
				else
					if WindType == 0 then --default wind (variation only on distance)
						WindSpeed = MinWindSpeed+(Distance*(MaxWindSpeed-MinWindSpeed))
					elseif WindType == 2 then --wind 2 (random variation only calculated once)
						if MaxWindSpeed > MinWindSpeed then
							WindSpeed = math.random(MinWindSpeed*10,MaxWindSpeed*10)/10 --adding these tens because someone might like decimals.
						elseif MaxWindSpeed < MinWindSpeed then
							WindSpeed = math.random(MaxWindSpeed*10,MinWindSpeed*10)/10
						end
					end
				end --what if I have a proper random wind + distance formula? I wonder how that would look like
			end	
			
			--X and Y spawning position values
			x = math.random(StartX,EndX)
			y = math.random(StartY,EndY)
			
			
			--store and apply variables
			SnowflakeData[meterName.."Distance"] = Distance
			SnowflakeData[meterName.."Size"] = Size
			SKIN:Bang("!SetOption",meterName,"W",Size)
			SKIN:Bang('[!SetOption "'..meterName..' "W" "'..Size..'"][!SetOption "'..meterName..'" "H" "'..Size..'"]')
			SnowflakeData[meterName.."FallSpeed"] = FallSpeed
			SnowflakeData[meterName.."Sway"] = Sway
			SnowflakeData[meterName.."SwayTime"] = math.floor(SwayTime)
			SnowflakeData[meterName.."SwayInterval"] = math.random(0,SwayTime)--random "position" in the sway cycle
			SnowflakeData[meterName.."WindSpeed"] = WindSpeed
			SnowflakeData[meterName.."TotalWind"] = 0
			SnowflakeData[meterName.."LifeFrames"] = 0
			
			--transparency and image tints
			if Transparency < 0 then
				Transparency = 0
			elseif Transparency > 255 then
				Transparency = 255
			end
			SnowflakeData[meterName.."Transparency"] = Transparency
			if TintsActive then
				local ActiveTint = Tints[math.random(1,#Tints)]
				SKIN:Bang("!SetOption",meterName,"ImageTint",ActiveTint..","..Transparency)
				SnowflakeData[meterName.."Tint"] = ActiveTint
			else
				SKIN:Bang("!SetOption",meterName,"ImageTint","255,255,255,"..Transparency)
			end
			
			--rest of the values
			SnowflakeData[meterName.."X"] = x
			SnowflakeData[meterName.."StartingX"] = x--used later for sway calculation because I can't think of any other way to NOT use this -_-
			SnowflakeData[meterName.."Y"] = y
			meter:SetX(x)
			meter:SetY(y)
			SnowflakesInUse[#SnowflakesInUse+1] = meter
			
		else
			print("Tried to spawn a snowflake, but failed due to lack of SnowflakesAvailible ! Change either SpawnRate or add snowflake meters!")
		end
	end
	
	--timer stuff
	timer = timer + 1
	if timer == (SpawnRate*100000) then -- I don't want to eventually have an integer overflow (if that can happen... better safe than sorry.)
		timer = 0
	end
end
















