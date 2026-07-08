if SERVER then AddCSLuaFile() end

local ModName = "GSP"
local LoadedFiles = {}

MsgC(Color(0, 255, 0), "\n["..ModName.."]", Color(255, 255, 255), " Initializing module... (Version 1.0)\n")

GSP = GSP or {}
GSP.InvidiousDomain = "yewtu.be"
GSP.ChatCommand = "!GSP"           
GSP.AdminChatCommand = "!GSP_admin" 
GSP.MusicDirectory = "GSP" 
GSP.HTMLPath = "gsp_html/index.html.lua"

if SERVER then
    AddCSLuaFile(GSP.HTMLPath)
end

GSP.ActiveChannel = nil
GSP.ActiveDHTML = nil
GSP.UI = nil
GSP.LocalSongList = {}
GSP.AllowedRanks = GSP.AllowedRanks or {}
GSP.Queue = GSP.Queue or {}

GSP.CurrentlyPlayingStr = "Brak utworu"
GSP.GlobalVolume = 0.75
GSP.LocalVolume = 0.5
GSP.LocalMuted = false
GSP.IsLooping = false
GSP.IsPaused = false
GSP.SongDuration = 0
GSP.SongStartTime = 0
GSP.PauseTime = 0

if SERVER then
    GSP.AvailableSongs = GSP.AvailableSongs or {}
    GSP.CurrentSong = nil
end

local col_mod    = Color(0, 255, 0)   
local col_sv     = Color(0, 150, 255) 
local col_cl     = Color(255, 200, 0) 
local col_sh     = Color(0, 255, 255) 
local col_white  = Color(255, 255, 255)
local col_ent    = Color(255, 100, 255) 

local function LogLoad(path, prefix)
    local col = col_sh
    local side = "SH"
    if prefix == "sv_" then col = col_sv; side = "SV"
    elseif prefix == "cl_" then col = col_cl; side = "CL" end

    MsgC(col_mod, "[" .. ModName .. "] ", col, "[" .. side .. "] ", col_white, "Loading: " .. path .. "\n")
end

local function SafeLoad(fullPath)
    if LoadedFiles[fullPath] then return end
    
    local filename = string.GetFileFromFilename(fullPath)
    local prefix = string.sub(filename, 1, 3)
    
    local isShared = (prefix == "sh_")
    local isClient = (prefix == "cl_")
    local isServer = (prefix == "sv_")

    if SERVER then
        if isShared or isClient then AddCSLuaFile(fullPath) end
        if isShared or isServer then 
            LogLoad(fullPath, prefix)
            include(fullPath) 
        end
    elseif CLIENT then
        if isShared or isClient then 
            LogLoad(fullPath, prefix)
            include(fullPath) 
        end
    end

    LoadedFiles[fullPath] = true
end

local function RegisterEntity(folderPath, entityName)
    entityName = string.lower(entityName)
    local ENT = {}
    ENT.Folder = folderPath
    _G.ENT = ENT 

    local sh = folderPath .. "/shared.lua"
    local sv = folderPath .. "/init.lua"
    local cl = folderPath .. "/cl_init.lua"
    
    local function SafeInclude(path)
        if not file.Exists(path, "LUA") then return true end
        local ok, err = pcall(function() include(path) end)
        if not ok then
            ErrorNoHalt("\n[" .. ModName .. " ERROR] Błąd w pliku encji: " .. path .. "\n" .. err .. "\n\n")
            return false
        end
        return true
    end

    local success = true
    if SERVER then
        if file.Exists(sh, "LUA") then AddCSLuaFile(sh) end
        if file.Exists(cl, "LUA") then AddCSLuaFile(cl) end
        success = SafeInclude(sh) and SafeInclude(sv)
    else
        success = SafeInclude(sh) and SafeInclude(cl)
    end

    _G.ENT = nil

    if success then
        scripted_ents.Register(ENT, entityName)
        MsgC(col_mod, "[" .. ModName .. "] ", col_ent, "[ENT] ", col_white, "Registered: " .. entityName .. "\n")
    else
        MsgC(Color(255, 0, 0), "[" .. ModName .. "] ", col_ent, "[ENT] ", col_white, "FAILED to register: " .. entityName .. " (Check errors above)\n")
    end
end

local function SmartLoad(folder, mode)
    local files, folders = file.Find(folder .. "/*", "LUA")

    if mode == "lua" then
        for _, filename in ipairs(files) do
            if string.EndsWith(filename, ".lua") then
                SafeLoad(folder .. "/" .. filename)
            end
        end
        for _, subfolder in ipairs(folders) do
            SmartLoad(folder .. "/" .. subfolder, "lua")
        end
    elseif mode == "ents" then
        local hasShared = file.Exists(folder .. "/shared.lua", "LUA")
        local hasInit   = file.Exists(folder .. "/init.lua", "LUA")

        if hasShared or hasInit then
            local entityName = string.GetFileFromFilename(folder)
            RegisterEntity(folder, entityName)
        else
            for _, subfolder in ipairs(folders) do
                SmartLoad(folder .. "/" .. subfolder, "ents")
            end
        end
    end
end

MsgC(Color(0, 255, 0), "["..ModName.."]", Color(255, 255, 255), " Loading shared files...\n")
SafeLoad(ModName .. "/config/sh_lang.lua")
SmartLoad(ModName .. "/modules", "lua")
SmartLoad(ModName .. "/core", "lua")
MsgC(Color(0, 255, 0), "["..ModName.."]", Color(255, 255, 255), " Successfully loaded!\n\n")