# IcyStorm
A customizable rainmeter skin that emulates realistic snow on your desktop.

The skin is composed of two parts - the .ini file that has a bunch of variables for you to tweak and a .lua file that handles animation.

## Customizable variables
Here's what each variable does:

###UpdateRate
Required to be the same value as "Update" in [Rainmeter]

###NumSnowflakes
The number of particles to use. If you change this, you must have the correct amount of meters at the bottom of the ini file. FOr exampole, if NumSnowflakes is 60, then there should be MeterSnowflake1, MeterSnowflake2, Metersnowflake3, ... , MeterSnowflake60.

###SnowflakeAntiAlias
Anti-Alias for the particles

###TotalScreenAreaX / TotalScreenAreaY
The total size of the screen that will be used. This should be equal to your resolution.


###Lifetime
Lifetime, in seconds, of each particle before it starts to fade away.
Generally, you would want the lifetime to be something close to how long it takes for the particle to reach the bottom of the screen.

###NumImageTints / ImageTint1 / etc
NumImageTints is to specify how many colors you will be using. If you set it to 1, then only ImageTint1 will be used, if you set NumImageTints to 2, then both ImageTint1 and ImageTint2 will be used. You can use as many image tints as you would like, just contine adding "ImageTing[number]" as you go along.
ImageTint numbers are RGB values.

###StartX / EndX
The location where snowflakes spawn on a horizontal axis. 

###StartY / EndY
The location where snowflakes spawn on a horizontal axis. If would not like to have the particles to pop into existence, set this to a negative value so that they spawn "above" the screen

###MinTransparency / MaxTransparency
A random value will be chosen between MinTransparency and MaxTransparency for each particle

###MinSize / MaxSize
A random value will be chosen between MinSize and MaxSize for each particle

###MinFallSpeed / MaxFallSpeed
The range of which how fast each particle will fall. Remember to adjust the Lifetime variable if you change this!

###MinSway / MaxSway
The range of how much each particle will sway side to side

###MinSwayTime / MaxSwayTime
The range of how long it takes each particle to sway side to side

###MinWindSpeed / MaxWindSpeed
The range of how fast each particle will move to the right. Set negative values to have them move left.

###WindType
Wind type sets the type of wind function that will be used
WindType=0 -- Wind calculated on snowflake "Distence" - like all other values
WindType=1 -- Random Wind. a random value between min and max windspeed is chosen. Uses RerollChance;WindType=2 -- Rnadom Wind without rerolling. Slightly less cpu usage? chooses a random value between min and max windspeed and does NOT change it.

###RerollChance
eroll chance (percentage, 1-100) rolls every 1/10th of a second. Used with WindType=1

###DebugMode
If you need some help determining the right value for "LifeTime", or need some misc information about other things, this is the place.
You generally want to use 90%-95%+ of the total number of snowflakes. so ~50/60 is ok, 55/60 is great, 59/60 is excellent
If the lifetime is shorter than the time it takes for a particle to reach the bottom of the screen, it fades away. 
DebugMode=1 - Prints how many particles are on screen to the total amount of particles (OnScreen / Availible)
DebugMode=2 - Prints information of MeterSnowflake1 (X / Y / LifeFrames / FallSpeed / Sway / TimeToSway / SwayInterval / Windspeed / TotalWind)
DebugMode=3 - Prints spawning information like DebugMode=1, but more detailed ( OnScreen / Availible / SpawnRateInFrames / TotalLifetimeFrames / FPS)
**Note that leaving this on gives tremendous lag**
