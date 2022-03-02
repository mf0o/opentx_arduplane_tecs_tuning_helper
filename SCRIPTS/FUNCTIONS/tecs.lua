-- tecs tuning advisor 
-- v0.0.6     26.01.2022	workflow seems to be working, no telemetry support yet
-- v0.0.7     28.02.2022	adding global variable telemetry, making TECS globally available for tecstm.lua
-- v0.0.8	  01.03.2022	correcting TECS_PITCH_MAX
-- v0.0.9	  01.03.2022	added 4 deg margin to TECS_PITCH_MIN and TECS_PITCH_MAX
-- v0.1.0	  01.03.2022	changed procedure for ARSPD_FBW_MIN from circle to straight without a security margin
-- v0.1.1	  02.03.2022	logfiles will be written with timestamp


-- todo:
-- airspeedsensor
-- write tecs to AP?

-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY, without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, see <http://www.gnu.org/licenses>.


local step=1            -- init
local stepCount = 7     -- step/loop count
local f                 -- logfile handle
local exdelay = 250     -- this limits opentx to fire the script too often

telemetry = {}			-- shared from SCRIPTS/TELEMETRY/tecstm.lua
telemetry.pitch = 0		-- [-90 +90]
telemetry.hSpeed = 50	-- whats the unit here?
telemetry.vSpeed = 3	-- whats the unit here?

local function iniTTA()
    step = 1
    extime=getTime()
end
 
local function KPH_to_CMs(KPH)      return string.format("%d", (KPH/0.036) )    		end
local function KPH_to_Ms(KPH)       return string.format("%d", (KPH/3.6) )      		end
local getThrottlePct = function()	return math.floor((getValue("thr")+1024)/ 20.48)  	end


-- these are the global TECS parameters
-- each defined as a function to export the raw value into a different unit + security margins

TECS = {
--1
    TRIM_THROTTLE   = { value = 0,  exporter = function(v) return(v) end },                -- %
    TRIM_ARSPD_CM   = { value = 0,  exporter = function(v) return( KPH_to_CMs(v) ) end },  -- kph -> cm/s
--2
    THR_MAX         = { value = 0,  exporter = function(v) return(v) end },                -- %
	ARSPD_FBW_MAX   = { value = 0,  exporter = function(v) return( KPH_to_Ms(v * 0.95 ) ) end },   -- kph -> m/s * 0.95
--3
    TECS_PITCH_MAX  = { value = 0,  exporter = function(v) return(v + 4) end },    -- deg
	TECS_CLMB_MAX   = { value = 0,  exporter = function(v) return(v) end },    -- m/s
    FBWB_CLIMB_RATE = { value = 0,  exporter = function(v) return(v) end },    -- m/s
--4
    ARSPD_FBW_MIN   = { value = 0,  exporter = function(v) return( KPH_to_Ms(v ) ) end },   -- kph -> m/s
--5
    STAB_PITCH_DOWN = { value = 0,  exporter = function(v) return(v) end },    -- deg
    TECS_SINK_MIN   = { value = 0,  exporter = function(v) return(v) end },    -- m/s
--6
    TECS_PITCH_MIN  = { value = 0,  exporter = function(v) return(v - 4) end },    -- deg
    TECS_SINK_MAX   = { value = 0,  exporter = function(v) return(v) end },    -- m/s
--7
    KFF_THR2PTCH    = { value = 0,  exporter = function(v) return(v) end },    -- deg
}


-- these are the tuning steps
-- each step has a audio and text description and can set multiple params
local stepDef = {
    step1 = {
        audio = function() 		playFile("tecs1.wav") end,
        text  = function(arg)	return "continue in Fly by Wire A and fly level at desired cruise speed" end,
        fn    = function(arg)
            TECS['TRIM_THROTTLE'].value = getThrottlePct()
            TECS['TRIM_ARSPD_CM'].value = telemetry.hSpeed -- "55" -- kph_to_CMs
            return
        end,
    },
    step2 = {
        audio = function() 		playFile("tecs2.wav") end,  
        text  = function(arg)   return "now accelerate to your desired maximum cruise speed" end, 
        fn    = function(arg)
            TECS['THR_MAX'].value = getThrottlePct()
            TECS['ARSPD_FBW_MAX'].value = telemetry.hSpeed 		-- "98" -- "26" -- kph_to_Ms
            return
        end,
    },
    step3 = {
        audio = function() 
            playFile("tecs3.wav") 
            playNumber( TECS['THR_MAX'].value, 13)
            playFile("tecs3.1.wav") 
            playNumber( TECS['TRIM_ARSPD_CM'].value, 7)
        end,
        text = function(arg)    return string.format("keep the throttle at %s and start climbing until your airspeed reaches %s kph.", TECS['THR_MAX'].value, TECS['TRIM_ARSPD_CM'].value)    end,    
        fn   = function(arg)
            TECS['TECS_PITCH_MAX'].value 	= telemetry.pitch 		-- "27"
            TECS['TECS_CLMB_MAX'].value 	= telemetry.vSpeed 		-- "7.0"
            TECS['FBWB_CLIMB_RATE'].value 	= telemetry.vSpeed 		-- "7.0"
            return
        end,
    },    
    step4 = {
        audio = function() 		playFile("tecs4.wav") end,
        text  = function(arg)   return "slow down to the minimum safe speed without stalling" end,
        fn    = function(arg)
            TECS['ARSPD_FBW_MIN'].value = telemetry.hSpeed 		-- "46" -- kph to m/s "13" 
            return
        end,
    },
    step5 = {
        audio = function() 
            playFile("tecs5.wav") 
            playNumber( TECS['ARSPD_FBW_MIN'].value ,7)
        end,
        text = function(arg)    return string.format("gain some altitude, then cut throttle and pitch down until airspeed reaches %s kph",TECS['ARSPD_FBW_MIN'].value)        end,
        fn   = function(arg)
            TECS['STAB_PITCH_DOWN'].value = telemetry.pitch 	-- "7.0"
            TECS['TECS_SINK_MIN'].value = telemetry.vSpeed 		-- "3.0"
            return
        end,
    },
    step6 = {
        audio = function() 
            playFile("tecs6.wav") 
            playNumber( TECS['ARSPD_FBW_MAX'].value ,7)
        end,
        text = function(arg)    return string.format("continue with zero throttle and pitch down until airspeed reaches %s kph",TECS['ARSPD_FBW_MAX'].value)        end,
        fn   = function(arg)
            TECS['TECS_PITCH_MIN'].value = telemetry.pitch 		-- "-26.0"
            TECS['TECS_SINK_MAX'].value = telemetry.vSpeed 		-- "10.0"
            return
        end
    },
    step7 = {
        audio = function() 		playFile("tecs7.wav") end,
        text  = function(arg)   return string.format("fly full speed and try to hold altitude")        end,
        fn    = function(arg)
            TECS['KFF_THR2PTCH'].value = telemetry.pitch 		-- "-4.0"
            return
        end
    }
}

local function logTECS(TECS)
	local datenow = getDateTime()
	local timestamp = datenow.year..""..datenow.mon..""..datenow.day..'_'..datenow.hour..""..datenow.min
	local f = io.open("/LOGS/tecs_"..timestamp..".txt", "a")
	
	for param in next,TECS,nil do 
		local exportValue = nil
		while not exportValue do
			exportValue = TECS[param].exporter(TECS[param].value)
			if type(exportValue) == "lightfunction" then        -- https://github.com/opentx/opentx/issues/6201
				exportValue = nil
			end
		end
		io.write(f, string.format("%s=%s\r\n", param, exportValue ))
	 end
	io.close(f)
end


-- this gets executed each time the switch is been triggered
-- runs each function, text or audio to the related step
-- saves everything to a logfile called "tecs.txt"
local function runTTA()
    if extime+exdelay < getTime() then

         if step == 1 then
             stepDef["step"..step]["audio"]()                                    -- play audio
             step=step+1
         else
             local prevStep=step-1
             stepDef["step"..prevStep]["fn"]()                                   -- execute function of previous step
 
             if step > stepCount then                                            -- reset and print summary
                 step = 1
				 logTECS(TECS)
                 playFile("tecsf.wav") 
 
             else
                 stepDef["step"..step]["audio"]()                                    -- play audio instructions
                 step=step+1
             end
         end
        extime=getTime()
    end
    return 1
end
 
return { init=iniTTA, run=runTTA }
 