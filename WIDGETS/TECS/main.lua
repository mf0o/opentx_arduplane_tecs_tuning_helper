-- tecs tuning advisor v0.1.3

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


local unitScale = getGeneralSettings().imperial == 0 and 1 or 3.28084
local unitLabel = getGeneralSettings().imperial == 0 and "m" or "ft"
local unitLongScale = getGeneralSettings().imperial == 0 and 1/1000 or 1/1609.34
local unitLongLabel = getGeneralSettings().imperial == 0 and "km" or "mi"


local frameTypes = {}
-- copter
frameTypes[0]   = "c"
frameTypes[2]   = "c"
frameTypes[3]   = "c"
frameTypes[4]   = "c"
frameTypes[7]   = "a"
frameTypes[13]  = "c"
frameTypes[14]  = "c"
frameTypes[15]  = "c"
frameTypes[29]  = "c"
-- plane
frameTypes[1]   = "p"
frameTypes[16]  = "p"
frameTypes[19]  = "p"
frameTypes[20]  = "p"
frameTypes[21]  = "p"
frameTypes[22]  = "p"
frameTypes[23]  = "p"
frameTypes[24]  = "p"
frameTypes[25]  = "p"
frameTypes[28]  = "p"
-- rover
frameTypes[10]  = "r"
-- boat
frameTypes[11]  = "b"


local frame = {}
local frameType = nil

-- TELEMETRY
local noTelemetryData = 1
local hideNoTelemetry = false
telemetry = {}
-- STATUS
telemetry.flightMode = 0
telemetry.simpleMode = 0
telemetry.landComplete = 0
telemetry.statusArmed = 0
telemetry.battFailsafe = 0
telemetry.ekfFailsafe = 0
telemetry.failsafe = 0
telemetry.fencePresent = 0
telemetry.fenceBreached = 0
telemetry.throttle = 0
telemetry.imuTemp = 0
-- GPS
telemetry.numSats = 0
telemetry.gpsStatus = 0
telemetry.gpsHdopC = 100
telemetry.gpsAlt = 0
-- BATT 1
telemetry.batt1volt = 0
telemetry.batt1current = 0
telemetry.batt1mah = 0
-- BATT 2
telemetry.batt2volt = 0
telemetry.batt2current = 0
telemetry.batt2mah = 0
-- HOME
telemetry.homeDist = 0
telemetry.homeAlt = 0
telemetry.homeAngle = -1
-- VELANDYAW
telemetry.vSpeed = 0
telemetry.hSpeed = 0
telemetry.yaw = 0
-- ROLLPITCH
telemetry.roll = 0
telemetry.pitch = 0
telemetry.range = 0
-- PARAMS
telemetry.frameType = -1
telemetry.batt1Capacity = 0
telemetry.batt2Capacity = 0
-- WP
telemetry.wpNumber = 0
telemetry.wpDistance = 0
telemetry.wpXTError = 0
telemetry.wpBearing = 0
telemetry.wpCommands = 0
-- VFR
telemetry.airspeed = 0
telemetry.throttle = 0
telemetry.baroAlt = 0
-- TOTAL DISTANCE
telemetry.totalDist = 0
-- 
telemetry.rpm1 = 0
telemetry.rpm2 = 0
-- 
telemetry.heightAboveTerrain = 0
telemetry.terrainUnhealthy = 0

local conf = {
    language = "en",
    battAlertLevel1 = 0,
    battAlertLevel2 = 0,
    battCapOverride1 = 0,
    battCapOverride2 = 0,
    disableAllSounds = false,
    disableMsgBeep = 1,
    timerAlert = 0,
    minAltitudeAlert = 0,
    maxAltitudeAlert = 0,
    maxDistanceAlert = 0,
    repeatAlertsPeriod = 10,
    battConf = 1, -- 1=parallel,2=other
    cell1Count = 0,
    cell2Count = 0,
    rangeFinderMax = 0,
    horSpeedMultiplier = 1,
    vertSpeedMultiplier = 1,
    horSpeedLabel = "m",
    vertSpeedLabel = "m/s",
    centerPanel = nil,
    rightPanel = nil,
    leftPanel = nil,
    altView = nil,
    defaultBattSource = "na",
    enablePX4Modes = false,
    enableHaptic = false,
    enableCRSF = true						-- added this as a default
  }


-- telemetry pop function, either SPort or CRSF
local telemetryPop = nil


local function processTelemetry(DATA_ID, VALUE,now)
    if DATA_ID == 0x5006 then -- ROLLPITCH
      -- roll [0,1800] ==> [-180,180]
      telemetry.roll = (math.min(bit32.extract(VALUE,0,11),1800) - 900) * 0.2
      -- pitch [0,900] ==> [-90,90]
      telemetry.pitch = (math.min(bit32.extract(VALUE,11,10),900) - 450) * 0.2
      -- #define ATTIANDRNG_RNGFND_OFFSET    21
      -- number encoded on 11 bits: 10 bits for digits + 1 for 10^power
      telemetry.range = bit32.extract(VALUE,22,10) * (10^bit32.extract(VALUE,21,1)) -- cm
    elseif DATA_ID == 0x5005 then -- VELANDYAW
      telemetry.vSpeed = bit32.extract(VALUE,1,7) * (10^bit32.extract(VALUE,0,1)) * (bit32.extract(VALUE,8,1) == 1 and -1 or 1)
      telemetry.yaw = bit32.extract(VALUE,17,11) * 0.2
      -- once detected it's sticky
      if bit32.extract(VALUE,28,1) == 1 then
        telemetry.airspeed = bit32.extract(VALUE,10,7) * (10^bit32.extract(VALUE,9,1)) -- dm/s
      else
        telemetry.hSpeed = bit32.extract(VALUE,10,7) * (10^bit32.extract(VALUE,9,1)) -- dm/s
      end
--      if status.airspeedEnabled == 0 then
--        status.airspeedEnabled = bit32.extract(VALUE,28,1)
--      end
    elseif DATA_ID == 0x5001 then -- AP STATUS
      telemetry.flightMode = bit32.extract(VALUE,0,5)
      telemetry.simpleMode = bit32.extract(VALUE,5,2)
      telemetry.landComplete = bit32.extract(VALUE,7,1)
      telemetry.statusArmed = bit32.extract(VALUE,8,1)
      telemetry.battFailsafe = bit32.extract(VALUE,9,1)
      telemetry.ekfFailsafe = bit32.extract(VALUE,10,2)
      telemetry.failsafe = bit32.extract(VALUE,12,1)
      telemetry.fencePresent = bit32.extract(VALUE,13,1)
      telemetry.fenceBreached = telemetry.fencePresent == 1 and bit32.extract(VALUE,14,1) or 0 -- we ignore fence breach if fence is disabled
      telemetry.throttle = math.floor(0.5 + (bit32.extract(VALUE,19,6) * (bit32.extract(VALUE,25,1) == 1 and -1 or 1) * 1.58)) -- signed throttle [-63,63] -> [-100,100]
      -- IMU temperature: 0 means temp =< 19°, 63 means temp => 82°
      telemetry.imuTemp = bit32.extract(VALUE,26,6) + 19 -- C°
    elseif DATA_ID == 0x5002 then -- GPS STATUS
    --   telemetry.numSats = bit32.extract(VALUE,0,4)
    --   -- offset  4: NO_GPS = 0, NO_FIX = 1, GPS_OK_FIX_2D = 2, GPS_OK_FIX_3D or GPS_OK_FIX_3D_DGPS or GPS_OK_FIX_3D_RTK_FLOAT or GPS_OK_FIX_3D_RTK_FIXED = 3
    --   -- offset 14: 0: no advanced fix, 1: GPS_OK_FIX_3D_DGPS, 2: GPS_OK_FIX_3D_RTK_FLOAT, 3: GPS_OK_FIX_3D_RTK_FIXED
    --   telemetry.gpsStatus = bit32.extract(VALUE,4,2) + bit32.extract(VALUE,14,2)
    --   telemetry.gpsHdopC = bit32.extract(VALUE,7,7) * (10^bit32.extract(VALUE,6,1)) -- dm
    --   telemetry.gpsAlt = bit32.extract(VALUE,24,7) * (10^bit32.extract(VALUE,22,2)) * (bit32.extract(VALUE,31,1) == 1 and -1 or 1) -- dm
    elseif DATA_ID == 0x5003 then -- BATT
    --   telemetry.batt1volt = bit32.extract(VALUE,0,9) -- dV
    --   -- telemetry max is 51.1V, 51.2 is reported as 0.0, 52.3 is 0.1...60 is 88
    --   -- if 12S and V > 51.1 ==> Vreal = 51.2 + telemetry.batt1volt
    --   if conf.cell1Count == 12 and telemetry.batt1volt < 240 then
    --     -- assume a 2Vx12 as minimum acceptable "real" voltage
    --     telemetry.batt1volt = 512 + telemetry.batt1volt
    --   end
    --   telemetry.batt1current = bit32.extract(VALUE,10,7) * (10^bit32.extract(VALUE,9,1)) --dA
    --   telemetry.batt1mah = bit32.extract(VALUE,17,15)
    elseif DATA_ID == 0x5008 then -- BATT2
    --   telemetry.batt2volt = bit32.extract(VALUE,0,9)
    --   -- telemetry max is 51.1V, 51.2 is reported as 0.0, 52.3 is 0.1...60 is 88
    --   -- if 12S and V > 51.1 ==> Vreal = 51.2 + telemetry.batt1volt
    --   if conf.cell2Count == 12 and telemetry.batt2volt < 240 then
    --     -- assume a 2Vx12 as minimum acceptable "real" voltage
    --     telemetry.batt2volt = 512 + telemetry.batt2volt
    --   end
    --   telemetry.batt2current = bit32.extract(VALUE,10,7) * (10^bit32.extract(VALUE,9,1))
    --   telemetry.batt2mah = bit32.extract(VALUE,17,15)
    elseif DATA_ID == 0x5004 then -- HOME
    --   telemetry.homeDist = bit32.extract(VALUE,2,10) * (10^bit32.extract(VALUE,0,2))
    --   telemetry.homeAlt = bit32.extract(VALUE,14,10) * (10^bit32.extract(VALUE,12,2)) * 0.1 * (bit32.extract(VALUE,24,1) == 1 and -1 or 1) --m
    --   telemetry.homeAngle = bit32.extract(VALUE, 25,  7) * 3
    elseif DATA_ID == 0x5000 then -- MESSAGES
    --   if VALUE ~= lastMsgValue then
    --     lastMsgValue = VALUE
    --     local c
    --     local msgEnd = false
    --     for i=3,0,-1
    --     do
    --       c = bit32.extract(VALUE,i*8,7)
    --       if c ~= 0 then
    --         msgBuffer = msgBuffer .. string.char(c)
    --         updateHash(c)
    --       else
    --         msgEnd = true;
    --         break;
    --       end
    --     end
--        collectgarbage()
--        collectgarbage()
        -- if msgEnd then
        --   -- push and display message
        --   local severity = (bit32.extract(VALUE,7,1) * 1) + (bit32.extract(VALUE,15,1) * 2) + (bit32.extract(VALUE,23,1) * 4)
        --   pushMessage( severity, msgBuffer)
        --   playHash()
        --   resetHash()
        --   msgBuffer = nil
        --   -- recover memory
        --   collectgarbage()
        --   collectgarbage()
        --   msgBuffer = ""
        -- end
    --   end
    elseif DATA_ID == 0x5007 then -- PARAMS
    --   local paramId = bit32.extract(VALUE,24,4)
    --   local paramValue = bit32.extract(VALUE,0,24)
    --   if paramId == 1 then
    --     telemetry.frameType = paramValue
    --   elseif paramId == 4 then
    --     telemetry.batt1Capacity = paramValue
    --   elseif paramId == 5 then
    --     telemetry.batt2Capacity = paramValue
    --   end
    elseif DATA_ID == 0x5009 then -- WAYPOINTS @1Hz
    --   telemetry.wpNumber = bit32.extract(VALUE,0,10) -- wp index
    --   telemetry.wpDistance = bit32.extract(VALUE,12,10) * (10^bit32.extract(VALUE,10,2)) -- meters
    --   telemetry.wpXTError = bit32.extract(VALUE,23,4) * (10^bit32.extract(VALUE,22,1)) * (bit32.extract(VALUE,27,1) == 1 and -1 or 1)-- meters
    --   telemetry.wpBearing = bit32.extract(VALUE,29,3) -- offset from cog with 45° resolution
    elseif DATA_ID == 0x500A then --  1 and 2
    --   -- rpm1 and rpm2 are int16_t
    --   local rpm1 = bit32.extract(VALUE,0,16)
    --   local rpm2 = bit32.extract(VALUE,16,16)
    --   telemetry.rpm1 = 10*(bit32.extract(VALUE,15,1) == 0 and rpm1 or -1*(1+bit32.band(0x0000FFFF,bit32.bnot(rpm1)))) -- 2 complement if negative
    --   telemetry.rpm2 = 10*(bit32.extract(VALUE,31,1) == 0 and rpm2 or -1*(1+bit32.band(0x0000FFFF,bit32.bnot(rpm2)))) -- 2 complement if negative
    elseif DATA_ID == 0x500B then -- 
      telemetry.heightAboveTerrain = bit32.extract(VALUE,2,10) * (10^bit32.extract(VALUE,0,2)) * 0.1 * (bit32.extract(VALUE,12,1) == 1 and -1 or 1) -- dm to meters
      telemetry.terrainUnhealthy = bit32.extract(VALUE,13,1)
      status.terrainLastData = now
      status.terrainEnabled = 1
  --[[
    elseif DATA_ID == 0x50F1 then -- RC CHANNELS
      -- channels 1 - 32
      local offset = bit32.extract(VALUE,0,4) * 4
      rcchannels[1 + offset] = 100 * (bit32.extract(VALUE,4,6)/63) * (bit32.extract(VALUE,10,1) == 1 and -1 or 1)
      rcchannels[2 + offset] = 100 * (bit32.extract(VALUE,11,6)/63) * (bit32.extract(VALUE,17,1) == 1 and -1 or 1)
      rcchannels[3 + offset] = 100 * (bit32.extract(VALUE,18,6)/63) * (bit32.extract(VALUE,24,1) == 1 and -1 or 1)
      rcchannels[4 + offset] = 100 * (bit32.extract(VALUE,25,6)/63) * (bit32.extract(VALUE,31,1) == 1 and -1 or 1)
  --]]
    elseif DATA_ID == 0x50F2 then -- VFR
      telemetry.airspeed = bit32.extract(VALUE,1,7) * (10^bit32.extract(VALUE,0,1)) -- dm/s
      telemetry.throttle = bit32.extract(VALUE,8,7)
      telemetry.baroAlt = bit32.extract(VALUE,17,10) * (10^bit32.extract(VALUE,15,2)) * 0.1 * (bit32.extract(VALUE,27,1) == 1 and -1 or 1)
      status.airspeedEnabled = 1
    end
  end
  
  
  local function crossfirePop()
      local now = getTime()
      local command, data = crossfireTelemetryPop()
      -- command is 0x80 CRSF_FRAMETYPE_ARDUPILOT
      if (command == 0x80 or command == 0x7F)  and data ~= nil then
        -- actual payload starts at data[2]
        if #data >= 7 and data[1] == 0xF0 then
          local app_id = bit32.lshift(data[3],8) + data[2]
          local value =  bit32.lshift(data[7],24) + bit32.lshift(data[6],16) + bit32.lshift(data[5],8) + data[4]
          return 0x00, 0x10, app_id, value
        elseif #data > 4 and data[1] == 0xF1 then
        --   -- minimum text messages of 1 char
        --   local severity = data[2]
        --   -- copy the terminator as well
        --   for i=3,#data
        --   do
        --     msgBuffer = msgBuffer .. string.char(data[i])
        --     -- hash support
        --     updateHash(data[i])
        --   end
        --   pushMessage(severity, msgBuffer)
        --   -- hash audio support
        --   playHash()
        --   -- hash reset
        --   resetHash()
          msgBuffer = nil
--          collectgarbage()
--          collectgarbage()
          msgBuffer = ""
        elseif #data > 48 and data[1] == 0xF2 then
          -- passthrough array
          local app_id, value
          for i=0,data[2]-1
          do
            app_id = bit32.lshift(data[4+(6*i)],8) + data[3+(6*i)]
            value =  bit32.lshift(data[8+(6*i)],24) + bit32.lshift(data[7+(6*i)],16) + bit32.lshift(data[6+(6*i)],8) + data[5+(6*i)]
            --pushMessage(7,string.format("CRSF:%d - %04X:%08X",i, app_id, value))
            processTelemetry(app_id, value, now)
          end
          noTelemetryData = 0
          hideNoTelemetry = true
        end
      end
      return nil, nil ,nil ,nil
  end
--< Y

-------- from tecs.lua

local step=1            -- init
local stepCount = 7     -- step/loop count
local f                 -- logfile handle
local exdelay = 250      -- this limits opentx to fire the script too often

local function iniTTA()
    step = 1
    extime=getTime()
end
 
local function KPH_to_CMs(KPH)      return string.format("%d", (KPH/0.036) )    		end
local function KPH_to_Ms(KPH)       return string.format("%d", (KPH/3.6) )      		end
local getThrottlePct = function()	return math.floor((getValue("thr")+1024)/ 20.48)  	end


TECS = {
--1
    TRIM_THROTTLE   = { value = 0,  exporter = function(v) return(v) end },                -- %
    TRIM_ARSPD_CM   = { value = 0,  exporter = function(v) return( KPH_to_CMs(v) ) end },  -- kph -> cm/s
--2
    THR_MAX         = { value = 0,  exporter = function(v) return(v) end },                -- %
	ARSPD_FBW_MAX   = { value = 0,  exporter = function(v) return( KPH_to_Ms(v * 0.95 ) ) end },   -- kph -> m/s * 0.95
--3
    TECS_PITCH_MAX  = { value = -4,  exporter = function(v) return(v + 4) end },    -- deg
	TECS_CLMB_MAX   = { value = 0,  exporter = function(v) return(v) end },    -- m/s
    FBWB_CLIMB_RATE = { value = 0,  exporter = function(v) return(v) end },    -- m/s
--4
    ARSPD_FBW_MIN   = { value = 0,  exporter = function(v) return( KPH_to_Ms(v ) ) end },   -- kph -> m/s
--5
    STAB_PITCH_DOWN = { value = 0,  exporter = function(v) return(v) end },    -- deg
    TECS_SINK_MIN   = { value = 0,  exporter = function(v) return(v) end },    -- m/s
--6
    TECS_PITCH_MIN  = { value = 4,  exporter = function(v) return(v - 4) end },    -- deg
    TECS_SINK_MAX   = { value = 0,  exporter = function(v) return(v) end },    -- m/s
--7
    KFF_THR2PTCH    = { value = 0,  exporter = function(v) return(v) end },    -- deg
}


-- these are the tuning steps
-- each step has a audio and text description and can set multiple params
local stepDef = {
    step1 = {
        audio = function() 		playFile("tecs10.wav") end,
        text  = function(arg)	return "continue in Fly by Wire A and fly level at desired cruise speed" end,
        fn    = function(arg)
            TECS['TRIM_THROTTLE'].value = getThrottlePct()
            TECS['TRIM_ARSPD_CM'].value = telemetry.hSpeed -- "55" -- kph_to_CMs
            return
        end,
    },
    step2 = {
        audio = function() 		
			playFile("tecs11.wav") 
			playNumber( TECS['TRIM_ARSPD_CM'].value, 7)
			
			playFile("tecs20.wav")
		end,  
        text  = function(arg)   return "now accelerate to your desired maximum cruise speed" end, 
        fn    = function(arg)
            TECS['THR_MAX'].value = getThrottlePct()
            TECS['ARSPD_FBW_MAX'].value = telemetry.hSpeed 		-- "98" -- "26" -- kph_to_Ms
            return
        end,
    },
    step3 = {
        audio = function() 
            playFile("tecs21.wav")
			playNumber( TECS['ARSPD_FBW_MAX'].value, 7)
			
            playFile("tecs30.wav") 
            playNumber( TECS['THR_MAX'].value, 13)
            playFile("tecs31.wav") 
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
        audio = function() 		
			playFile("tecs32.wav")
			playNumber( TECS['TECS_CLMB_MAX'].value, 5)

			playFile("tecs40.wav") 
		end,
        text  = function(arg)   return "slow down to the minimum safe speed without stalling" end,
        fn    = function(arg)
            TECS['ARSPD_FBW_MIN'].value = telemetry.hSpeed 		-- "46" -- kph to m/s "13" 
            return
        end,
    },
    step5 = {
        audio = function() 
            playFile("tecs41.wav") 
			playNumber( TECS['ARSPD_FBW_MIN'].value ,7)

            playFile("tecs50.wav") 
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
            playFile("tecs51.wav") 
			playNumber( TECS['TECS_SINK_MIN'].value, 5)

            playFile("tecs60.wav") 
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
        audio = function() 		
			playFile("tecs61.wav") 
			playNumber( TECS['TECS_SINK_MAX'].value, 5)

			playFile("tecs70.wav") 
		end,
        text  = function(arg)   return string.format("fly full speed and try to hold altitude")        end,
        fn    = function(arg)
            TECS['KFF_THR2PTCH'].value = telemetry.pitch 		-- "-4.0"
            return
        end
    }
}
-------- widget stuff below

local options = {
	{"BackColor", COLOR, BLACK },
	{"ForeColor", COLOR, WHITE },
	{"Switch", SOURCE, 117 },
}

local function exportTECS(param)
	local exportValue = nil
	if TECS[param]~=nil then
		while not exportValue do
			exportValue = TECS[param].exporter(TECS[param].value)
			if type(exportValue) == "lightfunction" then
				exportValue = nil
			end
		end
		return exportValue
	 else
		return 0
	 end
	 
end

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


local function manual_trigger(wgt)
	
	if extime+exdelay < getTime() then
		if getValue(wgt.options.Switch)>0 then

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
			return "active"
		else	
			return step
		end
			
	else
		return "wait"
	end
end


local function create(zone, options)
	if conf.enableCRSF == true then
		telemetryPop = crossfirePop
	end

	noTelemetryData =  3
	step = 1
	extime=getTime()

	return {zone=zone, options=options}
end


local function update(wgt, newOptions)
    wgt.options = newOptions
end

local function background(wgt)
	local now = getTime()
	-- FAST: this runs at 60Hz (every 16ms)
	noTelemetryData =  2

	for i=1,15
	do
		local success,sensor_id,frame_id,data_id,value = pcall(telemetryPop)

		if success and frame_id == 0x10 then
			processTelemetry(data_id,value,now)
			noTelemetryData = 0
			hideNoTelemetry = true
		end
	end
end


local function refresh(wgt)
  	background(wgt) --A 'widget' doesn't call the background itself when the refresh is active, so we have to do it ourselves !
	
	lcd.setColor (CUSTOM_COLOR, wgt.options.BackColor)
	
	lcd.drawFilledRectangle (
			wgt.zone.x,
			wgt.zone.y,
			wgt.zone.w,
			wgt.zone.h,
			CUSTOM_COLOR)
	
	lcd.clear(CUSTOM_COLOR)
	lcd.setColor (CUSTOM_COLOR,  wgt.options.ForeColor)

	lcd.drawText(1,	0,"= TECS TUNING =",CUSTOM_COLOR)
	lcd.drawText(1	,20	,"Pitch:",CUSTOM_COLOR)
	lcd.drawText(100	,20	, telemetry.pitch ,CUSTOM_COLOR)
	lcd.drawText(1	,40	,"Roll:", CUSTOM_COLOR)
	lcd.drawText(100	,40	, telemetry.roll ,CUSTOM_COLOR)
	lcd.drawText(1	,60	,"Thr:", CUSTOM_COLOR)
	lcd.drawText(100	,60	, math.floor((getValue("thr")+1024)/ 20.48)  ,CUSTOM_COLOR)
	lcd.drawText(1	,100	,"telemetry:", CUSTOM_COLOR)
	lcd.drawText(100	,100	,noTelemetryData, CUSTOM_COLOR)
	lcd.drawText(1	,80	,"state:", CUSTOM_COLOR)
	lcd.drawText(100	,80	,manual_trigger(wgt), CUSTOM_COLOR)

	
--1
	x=200
	x_offset=180
	y=0
	lcd.drawText(x		,y,"TRIM_THROTTLE:", CUSTOM_COLOR)
	lcd.drawText(x+x_offset	,y, exportTECS('TRIM_THROTTLE') , CUSTOM_COLOR)
	lcd.drawText(x		,y+20,"TRIM_ARSPD_CM:", CUSTOM_COLOR)
	lcd.drawText(x+x_offset	,y+20, exportTECS('TRIM_ARSPD_CM') , CUSTOM_COLOR)
--2
	y=40
	lcd.drawText(x		,y,"ARSPD_FBW_MAX:", CUSTOM_COLOR)
	lcd.drawText(x+x_offset	,y, exportTECS('ARSPD_FBW_MAX') , CUSTOM_COLOR)
	lcd.drawText(x		,y+20,"THR_MAX:", CUSTOM_COLOR)
	lcd.drawText(x+x_offset	,y+20, exportTECS('THR_MAX') , CUSTOM_COLOR)
--3
	y=80
	lcd.drawText(x		,y,"TECS_CLMB_MAX:", CUSTOM_COLOR)
	lcd.drawText(x+x_offset	,y, exportTECS('TECS_CLMB_MAX') , CUSTOM_COLOR)
	lcd.drawText(x		,y+20,"FBWB_CLIMB_RATE:", CUSTOM_COLOR)
	lcd.drawText(x+x_offset	,y+20, exportTECS('FBWB_CLIMB_RATE') , CUSTOM_COLOR)
--4
	y=120
	lcd.drawText(x,		y,"ARSPD_FBW_MIN:", CUSTOM_COLOR)
	lcd.drawText(x+x_offset,	y, exportTECS('ARSPD_FBW_MIN') , CUSTOM_COLOR)
	lcd.drawText(x,		y+20,"TECS_PITCH_MAX:", CUSTOM_COLOR)
	lcd.drawText(x+x_offset,	y+20, exportTECS('TECS_PITCH_MAX') , CUSTOM_COLOR)
--5
	y=160
	lcd.drawText(x		,y,"STAB_PITCH_DOWN:", CUSTOM_COLOR)
	lcd.drawText(x+x_offset	,y, exportTECS('STAB_PITCH_DOWN') , CUSTOM_COLOR)
	lcd.drawText(x		,y+20,"TECS_SINK_MIN:", CUSTOM_COLOR)
	lcd.drawText(x+x_offset	,y+20, exportTECS('TECS_SINK_MIN') , CUSTOM_COLOR)
--6
	y=200
	lcd.drawText(x,		y,"TECS_PITCH_MIN:", CUSTOM_COLOR)
	lcd.drawText(x+x_offset,	y, exportTECS('TECS_PITCH_MIN') , CUSTOM_COLOR)
	lcd.drawText(x,		y+20,"TECS_SINK_MAX:", CUSTOM_COLOR)
	lcd.drawText(x+x_offset,	y+20, exportTECS('TECS_SINK_MAX') , CUSTOM_COLOR)
--7
	y=240
	lcd.drawText(x,		y,"KFF_THR2PTCH:", CUSTOM_COLOR)
	lcd.drawText(x+x_offset,	y, exportTECS('KFF_THR2PTCH') , CUSTOM_COLOR)	

end

return { name="TECS", options=options, create=create, update=update, refresh=refresh, background=background }
