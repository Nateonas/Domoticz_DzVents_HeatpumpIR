--[[
to use with ToniA's heatpumpir lib + ESpeasy and _P115_heatpumpir 
https://github.com/ToniA/arduino-heatpumpir/blob/master/HeatpumpIR.h

Create the following dummy devices and write down the idx:
* AC Mode (selector switch): Auto, Heat, Cool, Dry, Fan, Maint
* AC Fan Speed (selector switch): Auto, 1, 2, 3, 4, 5
* AC Set Temperature (thermostat setpoint)

If your AC support vertical and Horizontal air directions then you can also create:
* AC Hor dir (selector switch): Auto, Manual, Swing, Middle, Left, Mleft, Mright, Right
* AC Vert dir (selector switch): Auto, Manual, Swing, Up, Mup, Middle, Mdown, Down

For any function your AC doesn't support or you have no need to use then you don't
need to create a device and set the idx below to 0.

Author  : Nateonas
Date    : 2024-07-05
Version : 1
Source  : hpapagaj, modified by bjacobse (original LUA version 1.0 January 2017)
Repo    : https://github.com/Nateonas
Licence : MIT

!! HELP !!
Please inform me when you are changing/improving this dzvents-script.
Better improve the source so everybody can profit than create a personal fork.
https://github.com/Nateonas

]]

--------------------------------------------------------------------------------
--  Customise user defaults     
--------------------------------------------------------------------------------
local ipadress          = '192.168.8.17'                                        -- Set espeasy heatpump IP address
local idxACMode         = 11856                                                 -- idx of AC Mode selector switch         set to 0 if not available or not used, default is sent see below
local idxACFan          = 11855                                                 -- idx of AC Fan speed selector switch    set to 0 if not available or not used, default is sent see below
local idxACTemp         = 11854                                                 -- idx of AC Temperature thermostat       set to 0 if not available or not used, default is sent see below
local idxHorDir         = 0                                                     -- idx of AC Horizontal airflow direction set to 0 if not available or not used, default is sent see below
local idxVerDir         = 0                                                     -- idx of AC Vertical airflow direction   set to 0 if not available or not used, default is sent see below
local ACmodel           = 'mitsubishi_heavy_zj'                                 -- See https://github.com/ToniA/arduino-heatpumpir/blob/master/HeatpumpIRFactory.cpp

local scriptVar         = 'HeatpumpIR'                                          -- name for logging and shellcallback, no need to change
local mintemp           = 18                                                    -- Minimum temp setting, see function temprange
local maxtemp           = 30                                                    -- Minimum temp setting, see function temprange

-- default codes
local power             = 1     -- Power ON
local mode              = 1     -- Auto
local fan               = 0     -- Auto
local settemperature    = 20    -- 20°C
local verdir            = 6     -- Down
local hordir            = 2     -- Middle


return {
-------------------------------------------------------------------- TRIGGERS --
	on = {
		devices = { idxACMode,
		            idxACFan,
		            idxACTemp,
		          },
--        httpResponses = { scriptVar },                                        -- HTTP responses that contain quotation marks seem processed incorrectly by dzvents:
	     },                                                                     -- '.. Error parsing json to LUA table: (invalid json string) Command unknown ..'

--------------------------------------------------------------------- LOGGING --
	logging = {
		level = domoticz.LOG_INFO,
--		level = domoticz.LOG_DEBUG,
		marker = scriptVar,
	},

------------------------------------------------------------------------ MAIN --
	execute = function ( domoticz, event )

------------------------------------------------------------------- FUNCTIONS --
        local function dlog(text) return domoticz.log(text, domoticz.LOG_DEBUG) end -- DEBUG log
        local function ilog(text) return domoticz.log(text, domoticz.LOG_INFO)  end -- INFO log
        local function flog(text) return domoticz.log(text, domoticz.LOG_FORCE) end -- Forced logging (always log regardless of logging setting)
        local function elog(text) return domoticz.log(text, domoticz.LOG_ERROR) end -- Error logging
        local exists = domoticz.utils.deviceExists
        
        local function temprange(temp, min, max)                                -- Most ACs expect a minimum and a maximum temperature from the remote
            if temp > max then temp = max end                                   -- going below or above can result in unexpected behaviour
            if temp < min then temp = min end                                   -- The HeatpumpIR doesn't sufficienly protect for sending incorrect temperatures, so we do it here.
            return temp
        end

-- function dumptable (for debugging)
        local function dumptable(o)
            if type(o) == 'table' then
                local s = '{ '
                    for k,v in pairs(o) do
                        if type(k) ~= 'number' then k = '"'..k..'"' end
                        s = s .. '[' .. k .. '] = ' .. dumptable(v) .. ','
                    end
                return s .. '} '
            else
                return tostring(o)
            end
        end

------------------------------------------------------------- DEVICE TRIGGERS --
        if event.isDevice then
            local logtext = ''

            --// Operating modes
            if exists(idxACMode) then
                local modetext  = domoticz.devices(idxACMode).levelName
                logtext = logtext .. ' Mode - ' .. modetext
                if modetext == 'Off' then
                    mode  = 0
                    power = 0
                elseif modetext == 'Auto'  then mode = 1        
                elseif modetext == 'Heat'  then mode = 2        
                elseif modetext == 'Cool'  then mode = 3        
                elseif modetext == 'Dry'   then mode = 4        
                elseif modetext == 'Fan'   then mode = 5        
                elseif modetext == 'Maint' then mode = 6
                else   ilog('Mode unknown, using default')
                end
            end
    
            --// Fan speeds. Note that some heatpumps have less than 5 fan speeds
            if exists(idxACFan) then
                local fantext   = domoticz.devices(idxACFan).levelName
                logtext = logtext .. ' | Speed - ' .. fantext
                if     fantext == 'Auto' then fan = 0
                elseif fantext == '1'    then fan = 1        
                elseif fantext == '2'    then fan = 2        
                elseif fantext == '3'    then fan = 3        
                elseif fantext == '4'    then fan = 4        
                elseif fantext == '5'    then fan = 5
                else   ilog('Fanspeed unknown, using default')
                end
            end
    
            --Set temperature
            if exists(idxACTemp) then
                settemperature = temprange( tonumber(domoticz.devices(idxACTemp).setPoint),
                                            mintemp,
                                            maxtemp)
                logtext = logtext .. ' | Temperature - ' .. settemperature .. '°C'
            end

            --// Vertical air directions. Note that these cannot be set on all heat pumps
            if exists(idxVerDir) then
                local  vertext = domoticz.devices(idxVerDir).levelName
                logtext = logtext .. ' | Vert dir - ' .. vertext
                if     vertext == 'Auto'   then verdir = 0
                elseif vertext == 'Manual' then verdir = 0        
                elseif vertext == 'Swing'  then verdir = 1        
                elseif vertext == 'Up'     then verdir = 2        
                elseif vertext == 'Mup'    then verdir = 3        
                elseif vertext == 'Middle' then verdir = 4        
                elseif vertext == 'Mdown'  then verdir = 5
                elseif vertext == 'Down'   then verdir = 6
                else   ilog('Vert direction unknown, using default')
                end
            end
    
            --// Horizontal air directions. Note that these cannot be set on all heat pumps
            if exists(idxHorDir) then
                local  hortext = domoticz.devices(idxHorDir).levelName
                logtext = logtext .. ' | Horz dir - ' .. hortext
                if     hortext == 'Auto'   then hordir = 0
                elseif hortext == 'Manual' then hordir = 0        
                elseif hortext == 'Swing'  then hordir = 1        
                elseif hortext == 'Middle' then hordir = 2        
                elseif hortext == 'Left'   then hordir = 3        
                elseif hortext == 'Mleft'  then hordir = 4        
                elseif hortext == 'Mright' then hordir = 5
                elseif hortext == 'Right'  then hordir = 6
                else   ilog('Horizontal direction unknown, using default')
                end
            end
    
            local heatpumpURL = 'http://' ..ipadress.. '/control?cmd=heatpumpir,' .. ACmodel..','..power..','..mode..','..fan..','..settemperature..','..verdir..','..hordir
            ilog (logtext)
            ilog (heatpumpURL)
            domoticz.openURL({
                    url      = heatpumpURL,
                    callback = scriptVar
                })

        end
        
-------------------------------------------------------------- HTTP RESPONSES --
        if event.isHTTPResponse and event.trigger == scriptVar then
            if not (event.ok) then
                elog('Error: ' .. event.protocol .. 
                    ' status code: ' .. event.statusCode .. 
                    ' (' .. event.statusText .. ')')                            -- no need to (error)log the error, for dzvents log's an http-error automatically itself
            else
                ilog('Response = ' .. dumptable(event.data))
            end
        end
    end
}
