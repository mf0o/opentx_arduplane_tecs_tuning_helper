-- tecs tuning advisor, telemetry gateway,  v0.2.3

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

local status = {}

status.showDualBattery = false
status.battAlertLevel1 = false
status.battAlertLevel2 = false
status.battsource = "na"
status.flightTime = 0    -- updated from model timer 3
status.timerRunning = 0  -- triggered by landcomplete from AP
status.showMinMaxValues = false
status.terrainLastData = getTime()
status.terrainEnabled = 0
status.airspeedEnabled = 0

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
      if status.airspeedEnabled == 0 then
        status.airspeedEnabled = bit32.extract(VALUE,28,1)
      end
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
        collectgarbage()
        collectgarbage()
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
          collectgarbage()
          collectgarbage()
          msgBuffer = ""
		  elseif #data >= 8 and data[1] == 0xF2 then
			-- passthrough array
			local app_id, value
			for i=0,math.min(data[2]-1, 9)
			do
			app_id = bit32.lshift(data[4+(6*i)],8) + data[3+(6*i)]
			value =  bit32.lshift(data[8+(6*i)],24) + bit32.lshift(data[7+(6*i)],16) + bit32.lshift(data[6+(6*i)],8) + data[5+(6*i)]
			processTelemetry(app_id, value, now)
			end
			noTelemetryData = 0
			hideNoTelemetry = true
        end
      end
      return nil, nil ,nil ,nil
  end
--< Y


local function initLTT()
	
  if conf.enableCRSF == true then
    telemetryPop = crossfirePop
  end
	
end
 

-------------------------------
-- running at 20Hz (every 50ms)
-------------------------------
local function backgroundLT()
  local now = getTime()
  -- FAST: this runs at 60Hz (every 16ms)
  for i=1,7
  do
    local success,sensor_id,frame_id,data_id,value = pcall(telemetryPop)

    if success and frame_id == 0x10 then
      processTelemetry(data_id,value,now)
      noTelemetryData = 0
      hideNoTelemetry = true
    end
  end
	
  collectgarbage()
  collectgarbage()

end

local function exportTECS(param)
		
	local exportValue = nil
	if TECS~=nil then 
		while not exportValue do
			exportValue = TECS[param].exporter(TECS[param].value)
			if type(exportValue) == "lightfunction" then
				exportValue = nil
			end
		end
		return exportValue
	else
		return 10.5
	end
end

local function DMs_to_KPH(DMS)      return string.format("%d", (DMS/10*3.6) )    		end
local function DMS_to_MS(DMS)      	return string.format("%d", (DMS*0.1) )    			end


local function run(e)
  lcd.clear()

  lcd.drawText(3,0,"pch:",0)
  lcd.drawText(26,0, telemetry.pitch ,0)	
  
  lcd.drawText(43,0,"rll:", 0)
  lcd.drawText(66,0, telemetry.roll ,0)
	
  lcd.drawText(83,0,"gSp:", 0)
  lcd.drawText(106,0, DMs_to_KPH(telemetry.hSpeed) ,0)
	
  lcd.drawText(123,0,"aSp:", 0)
  lcd.drawText(146,0, DMs_to_KPH(telemetry.airspeed) ,0)
	
  lcd.drawText(163,0,"clb:", 0)
  lcd.drawText(186,0, DMS_to_MS(telemetry.vSpeed) ,0)

--1
  lcd.drawText(1,8,"TRIM_THROTTLE:", 0)
  lcd.drawText(lcd.getLastPos()+2,8, exportTECS('TRIM_THROTTLE') ,0)
  lcd.drawText(1,16,"TRIM_ARSPD_CM:", 0)
  lcd.drawText(lcd.getLastPos()+2,16, exportTECS('TRIM_ARSPD_CM') ,0)
--2
  lcd.drawText(1,24,"ARSPD_FBW_MAX:", 0)
  lcd.drawText(lcd.getLastPos()+2,24, exportTECS('ARSPD_FBW_MAX') ,0)
  lcd.drawText(1,32,"THR_MAX:", 0)
  lcd.drawText(lcd.getLastPos()+2,32, exportTECS('THR_MAX') ,0)
--3
  lcd.drawText(1,40,"TECS_CLMB_MAX:", 0)
  lcd.drawText(lcd.getLastPos()+2,40, exportTECS('TECS_CLMB_MAX') ,0)
  lcd.drawText(1,48,"FBWB_CLIMB_RATE:", 0)
  lcd.drawText(lcd.getLastPos()+2,48, exportTECS('FBWB_CLIMB_RATE') ,0)
--4
  lcd.drawText(105,8,"ARSPD_FBW_MIN:", 0)
  lcd.drawText(lcd.getLastPos()+2,8, exportTECS('ARSPD_FBW_MIN') ,0)
  lcd.drawText(105,16,"TECS_PITCH_MAX:", 0)
  lcd.drawText(lcd.getLastPos()+2,16, exportTECS('TECS_PITCH_MAX') ,0)
--5
  lcd.drawText(105,24,"STAB_PITCH_DOWN:", 0)
  lcd.drawText(lcd.getLastPos()+2,24, exportTECS('STAB_PITCH_DOWN') ,0)
  lcd.drawText(105,32,"TECS_SINK_MIN:", 0)
  lcd.drawText(lcd.getLastPos()+2,32, exportTECS('TECS_SINK_MIN') ,0)
--6
  lcd.drawText(105,40,"TECS_PITCH_MIN:", 0)
  lcd.drawText(lcd.getLastPos()+2,40, exportTECS('TECS_PITCH_MIN') ,0)
  lcd.drawText(105,48,"TECS_SINK_MAX:", 0)
  lcd.drawText(lcd.getLastPos()+2,48, exportTECS('TECS_SINK_MAX') ,0)

--7
  lcd.drawText(105,56,"KFF_THR2PTCH:", 0)
  lcd.drawText(lcd.getLastPos()+2,56, exportTECS('KFF_THR2PTCH') ,0)
	
	
end
 
return { init=initLTT, background=backgroundLT, run=run }
 
