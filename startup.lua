---@diagnostic disable: undefined-global

local pretty = require "cc.pretty"
local pb = require("pixelbox_lite")
local json = require("json");
local aes = require("AES");

rednet.open("back")

local function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

local function clamp(X, min, max)
    if X < min then return min end
    if X > max then return max end
    return X
end

local function drawLine(box,x1,y1,x2,y2,color)
    local x, y = 0,0
    for t=0,1,0.01 do
        if x1 > x2 then
            x = math.floor(x1 + t * (x2 - x1))
        else
            x = math.ceil(x1 + t * (x2 - x1))
        end
        if y1 > y2 then
            y = math.floor(y1 + t * (y2 - y1))
        else
            y = math.ceil(y1 + t * (y2 - y1))
        end
        box.canvas[y][x] = color
    end
end

X, Y = term.getSize()

ECG = pb.new(window.create(term.current(), 1, Y-10, X, 11))
ECGX, ECGY = ECG.width, ECG.height

local gData
local firstData = false
local key = aes.StringToKey("CCTweakedReactor", 1024)

local function main()
    local oldStatus = false
    while true do
        local id, message = rednet.receive()

        if id == 229 then
            message = json.decode(aes.TableToString(aes.Decrypt(message, key)))
            gData = message
            firstData = true
            if oldStatus ~= message.status then
                term.clear()
            end
            -- term.clear()
            term.setCursorPos(1,1)
            term.write("Burn Rate: ")
            local brtext = message.br.."mB/t                                  "
            local color = ""
            local back = ""
            if message.br <= 1 then
                for _ = 1, string.len(brtext), 1 do color = color .. "d" back = back .. "f" end
            elseif message.br <= 2 then
                for _ = 1, string.len(brtext), 1 do color = color .. "9" back = back .. "f" end
            elseif message.br <= 4 then
                for _ = 1, string.len(brtext), 1 do color = color .. "b" back = back .. "f" end
            elseif message.br <= 8 then
                for _ = 1, string.len(brtext), 1 do color = color .. "a" back = back .. "f" end
            else
                for _ = 1, string.len(brtext), 1 do color = color .. "e" back = back .. "f" end
            end
            term.blit(brtext, color, back)
            term.setCursorPos(1,2)
            term.write("Consume: "..round(message.consume,2).." FE/t                                  ")
            term.setCursorPos(1,3)
            term.write("Prod.: "..round(message.prod/2.5, 2).." FE/t                                  ")
            term.setCursorPos(1,4)
            term.write("Fuel Diff.: ")
            local fdtext = message.deltafuel.." mB/t                                  "
            local color = ""
            local back = ""
            if message.deltafuel >= 0 then
                for _ = 1, string.len(fdtext), 1 do color = color .. "9" back = back .. "f" end
            else
                for _ = 1, string.len(fdtext), 1 do color = color .. "e" back = back .. "f" end
            end
            term.blit(fdtext, color, back)
            term.setCursorPos(1,5)
            term.write("Fuel: "..message.fuel.." mB/t                                  ")
            term.setCursorPos(1,6)
            term.write("Turbine Energy: "..(message.efp*100).."%                                  ")
            term.setCursorPos(1,7)
            term.write("Reactor Temp: ")
            local temptext = math.floor(message.temp).." "..string.char(176).."C                                  "
            local color = ""
            local back = ""
            if message.temp <= 400 then
                for _ = 1, string.len(temptext), 1 do color = color .. "d" back = back .. "f" end
            elseif message.temp <= 425 then
                for _ = 1, string.len(temptext), 1 do color = color .. "9" back = back .. "f" end
            elseif message.temp <= 450 then
                for _ = 1, string.len(temptext), 1 do color = color .. "b" back = back .. "f" end
            elseif message.temp <= 475 then
                for _ = 1, string.len(temptext), 1 do color = color .. "a" back = back .. "f" end
            else
                for _ = 1, string.len(temptext), 1 do color = color .. "e" back = back .. "f" end
            end
            term.blit(temptext, color, back)
            term.setCursorPos(1,8)
            term.write("Waste: ")
            local wastetext = message.waste.." %                                  "
            local color = ""
            local back = ""
            if message.waste <= 0.01 then
                for _ = 1, string.len(wastetext), 1 do color = color .. "9" back = back .. "f" end
            else
                for _ = 1, string.len(wastetext), 1 do color = color .. "e" back = back .. "f" end
            end
            term.blit(wastetext, color, back)
            term.setCursorPos(1,9)
            term.write("Status: ")
            if message.status then
                term.blit("Active", "dddddd", "ffffff")
            else
                term.blit("Scrammed", "eeeeeeee", "ffffffff")
            end
            oldStatus = message.status
        end
        sleep()
    end
end

local function graph()
    local ctable = {}
    local ptable = {}
    local offy = 10
    while true do
        if firstData then
            pb.restore(ECG, colors.gray)
            local cttemp = round(ECGY+offy-gData.consume/1800, 2)
            local pttemp = round(ECGY+offy-gData.prod/5000, 2)

            if pttemp >= ECGY-3 or cttemp >= ECGY-3 then
                offy = offy - 1
            elseif pttemp < 2 or cttemp < 2 then
                offy = offy + 1
            end

            ctable[#ctable+1] = clamp(cttemp, 1, ECGY-1)
            ptable[#ptable+1] = clamp(pttemp, 1, ECGY-1)
            local ox, oy = 0,0
            for k, v in pairs(ptable) do
                if k <= 1 then
                    v = math.floor(v)
                    k = math.floor(k)
                    ECG.canvas[v][k] = colors.green
                else
                    drawLine(ECG, ox,oy,k,v, colors.green)
                end
                ox, oy = k,v
            end
            ox, oy = 0,0
            for k, v in pairs(ctable) do
                if k <= 1 then
                    v = math.floor(v)
                    k = math.floor(k)
                    ECG.canvas[v][k] = colors.lime
                else
                    drawLine(ECG, ox,oy,k,v, colors.lime)
                end
                ox, oy = k,v
            end

            ECG:render()

            if #ptable > ECG.width-2 then
                table.remove(ptable, 1)
                table.remove(ctable, 1)
            end
        end
        sleep()
    end
end

parallel.waitForAll(main, graph)
