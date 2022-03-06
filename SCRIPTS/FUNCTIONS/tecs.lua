-- tecs tuning advisor v0.2.0

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
local debug = true		-- for printing debug and raw messages

telemetry = {}			-- shared from SCRIPTS/TELEMETRY/tecstm.lua
telemetry.pitch = 0		-- [-90 +90] deg
telemetry.airspeed = 50	-- dm/s
telemetry.hSpeed = 50	-- dm/s
telemetry.vSpeed = 3	-- dm/s

local function iniTTA()
    step = 1
    extime=getTime()
end
 
local function KPH_to_CMs(KPH)      return string.format("%d", (KPH/0.036) )			end
local function DMS_to_MS(DMS)      	return string.format("%d", (DMS*0.1) )    			end
local function DMs_to_CMs(DMS)      return string.format("%d", (DMS*10) )    			end
local function DMs_to_KPH(DMS)      return string.format("%d", (DMS/10*3.6) )    		end
local function KPH_to_Ms(KPH)       return string.format("%d", (KPH/3.6) )      		end
local getThrottlePct = function()	return math.floor((getValue("thr")+1024)/ 20.48)  	end


-- these are the global TECS parameters
-- each defined as a function to export the raw value into a different unit + security margins

TECS = {
--1
    TRIM_THROTTLE   = { value = 0,  exporter = function(v) return(v) end }, 							-- raw: percent,  output: percent
    TRIM_ARSPD_CM   = { value = 0,  exporter = function(v) return( DMs_to_CMs(v) ) end },				-- raw: dm/s output: cm/s
--2
    THR_MAX         = { value = 0,  exporter = function(v) return(v) end }, 							-- raw: percent,  output: percent
	ARSPD_FBW_MAX   = { value = 0,  exporter = function(v) return( DMS_to_MS(v * 0.95 ) ) end },   		-- raw: dm/s output: m/s * 0.95
--3
    TECS_PITCH_MAX  = { value = -4, exporter = function(v) return(math.abs(v + 4)) end },    			-- raw: deg	output: +deg 4deg
	TECS_CLMB_MAX   = { value = 0,  exporter = function(v) return (math.min(math.abs(0.1*v),10)) end }, -- raw: dm/s output: +m/s
    FBWB_CLIMB_RATE = { value = 0,  exporter = function(v) return (math.min(math.abs(0.1*v),10)) end }, -- raw: dm/s output: m/s
--4
    ARSPD_FBW_MIN   = { value = 0,  exporter = function(v) return( DMS_to_MS(v ) ) end },   			-- raw: dm/s , output: m/s
--5
    STAB_PITCH_DOWN = { value = 0,  exporter = function(v) return(math.abs(v)) end },   				-- deg
    TECS_SINK_MIN   = { value = 0,  exporter = function(v) return(math.min(math.abs(0.1*v),10)) end },  -- raw: dm/s , output: m/s
--6
    TECS_PITCH_MIN  = { value = 4,  exporter = function(v) return(v - 4) end },    						-- raw deg output: +/-deg - 4
    TECS_SINK_MAX   = { value = 0,  exporter = function(v) return(math.min(math.abs(0.1*v),10))  end }, -- raw: dm/s output: +m/s
--7
    KFF_THR2PTCH    = { value = 0,  exporter = function(v) return(v) end },    							-- raw: deg output: +/-deg
}



-- these are the tuning steps
-- each step has a audio and text description and can set multiple params
local stepDef = {
    step1 = {
        audio = function() 		playFile("tecs10.wav") end,
        text  = function(arg)	return "continue in Fly by Wire A and fly level at desired cruise speed" end,
        fn    = function(arg)
            TECS['TRIM_THROTTLE'].value = getThrottlePct()		--38 -- 
            TECS['TRIM_ARSPD_CM'].value = telemetry.hSpeed 		-- 150 -- 65kph
            return
        end,
    },
    step2 = {
        audio = function() 		
			playFile("tecs11.wav") 
			playNumber( DMs_to_KPH(TECS['TRIM_ARSPD_CM'].value), 7) ---- YOU ARE HERE, DO THIS FOR ALL OF THEM AND DISREGARD function call
			
			playFile("tecs20.wav")
		end,  
        text  = function(arg)   return "now accelerate to your desired maximum cruise speed" end, 
        fn    = function(arg)
            TECS['THR_MAX'].value 		= getThrottlePct()		-- 80 -- 
            TECS['ARSPD_FBW_MAX'].value = telemetry.hSpeed 		-- 230 -- "82kph"
            return
        end,
    },
    step3 = {
        audio = function() 
            playFile("tecs21.wav")
			playNumber( DMs_to_KPH(TECS['ARSPD_FBW_MAX'].value), 7)
			
            playFile("tecs30.wav") 
            playNumber( TECS['THR_MAX'].value, 13)
            playFile("tecs31.wav") 
            playNumber( DMs_to_KPH(TECS['TRIM_ARSPD_CM'].value), 7)
        end,
        text = function(arg)    return string.format("keep the throttle at %s and start climbing until your airspeed reaches %s kilometer per hour.", TECS['THR_MAX'].value, DMs_to_KPH(TECS['TRIM_ARSPD_CM'].value))    end,    
        fn   = function(arg)
            TECS['TECS_PITCH_MAX'].value 	= telemetry.pitch 		-- 27
            TECS['TECS_CLMB_MAX'].value 	= telemetry.vSpeed 		-- 70	--
            TECS['FBWB_CLIMB_RATE'].value 	= telemetry.vSpeed 		-- 70	--
            return
        end,
    },    
    step4 = {
        audio = function() 		
			playFile("tecs32.wav")
			playNumber( math.min(math.abs(0.1*TECS['TECS_CLMB_MAX'].value),10), 5)

			playFile("tecs40.wav") 
		end,
        text  = function(arg)   return "slow down to the minimum safe speed without stalling" end,
        fn    = function(arg)
            TECS['ARSPD_FBW_MIN'].value = telemetry.hSpeed 		-- 120 -- "46kph" 
            return
        end,
    },
    step5 = {
        audio = function() 
            playFile("tecs41.wav") 
			playNumber( DMs_to_KPH(TECS['ARSPD_FBW_MIN'].value) ,7)

            playFile("tecs50.wav") 
            playNumber( DMs_to_KPH(TECS['ARSPD_FBW_MIN'].value) ,7)
        end,
        text = function(arg)    return string.format("gain some altitude, then cut throttle and pitch down until airspeed reaches %s kph",DMs_to_KPH(TECS['ARSPD_FBW_MIN'].value))        end,
        fn   = function(arg)
            TECS['STAB_PITCH_DOWN'].value = telemetry.pitch 	-- "-3" -- 
            TECS['TECS_SINK_MIN'].value =  	telemetry.vSpeed 	-- 20 --
            return
        end,
    },
    step6 = {
        audio = function() 
            playFile("tecs51.wav") 
			playNumber( math.min(math.abs(0.1*TECS['TECS_SINK_MIN'].value),10), 5)

            playFile("tecs60.wav") 
            playNumber( DMs_to_KPH(TECS['ARSPD_FBW_MAX'].value) ,7)
        end,
        text = function(arg)    return string.format("continue with zero throttle and pitch down until airspeed reaches %s kph",DMs_to_KPH(TECS['ARSPD_FBW_MAX'].value))        end,
        fn   = function(arg)
            TECS['TECS_PITCH_MIN'].value =	telemetry.pitch 		-- "-24" --
            TECS['TECS_SINK_MAX'].value  =	telemetry.vSpeed 		-- 120 -- 
            return
        end
    },
    step7 = {
        audio = function() 		
			playFile("tecs61.wav") 
			playNumber( math.min(math.abs(0.1*TECS['TECS_SINK_MAX'].value),10), 5)

			playFile("tecs70.wav") 
		end,
        text  = function(arg)   return string.format("fly full speed and try to hold altitude")        end,
        fn    = function(arg)
            TECS['KFF_THR2PTCH'].value = telemetry.pitch			-- "-5" --
            return
        end
    }
}

local function logTECS(TECS)
	local datenow = getDateTime()
	local timestamp = datenow.year..""..string.format("%02d",datenow.mon)..""..string.format("%02d",datenow.day)..'_'..string.format("%02d",datenow.hour)..""..string.format("%02d",datenow.min)
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
	
	if debug then
		for param in next,TECS,nil do 
			local exportValue = nil
			while not exportValue do
				exportValue = TECS[param].exporter(TECS[param].value)
				if type(exportValue) == "lightfunction" then        -- https://github.com/opentx/opentx/issues/6201
					exportValue = nil
				end
			end
			io.write(f, string.format("debug_%s=%s\r\n", param, TECS[param].value ))
		end
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
                 stepDef["step"..step]["audio"]()                                -- play audio instructions
                 step=step+1
             end
         end
        extime=getTime()
    end
    return 1
end
 
return { init=iniTTA, run=runTTA }
 
