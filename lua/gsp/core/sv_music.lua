GSP = GSP or {}

local nets = {
    "GSP_OpenUI", "GSP_Play", "GSP_Stop", "GSP_Sync", "GSP_SyncRanks", 
    "GSP_AddRank", "GSP_RemoveRank", "GSP_QueueAdd", "GSP_QueueSync", 
    "GSP_SetVolume", "GSP_SetLooping", "GSP_TogglePause", "GSP_Seek", 
    "GSP_SetLength", "GSP_NextTrack", "GSP_StateSync", "GSP_SendList", "GSP_UpdateQueue"
}
for _, n in ipairs(nets) do util.AddNetworkString(n) end

local MAX_QUEUE_SIZE = 100
local MAX_STRING_LENGTH = 1024

local function SanitizeSongName(songName)
    if not songName or type(songName) ~= "string" then return "" end
    songName = string.Trim(songName)

    local isURL = string.StartWith(songName, "http://") or string.StartWith(songName, "https://")
    if isURL then
        return songName
    end

    local safeName = string.GetFileFromFilename(songName)
    local ext = string.lower(string.GetExtensionFromFilename(safeName) or "")

    if ext == "mp3" or ext == "ogg" then
        return safeName
    end

    return ""
end

function GSP.IndexSongs()
    GSP.AvailableSongs = {}
    local files, _ = file.Find("sound/" .. (GSP.MusicDirectory or "GSP") .. "/*", "GAME")
    if files then
        for _, filename in ipairs(files) do
            local ext = string.GetExtensionFromFilename(filename)
            if ext == "mp3" or ext == "ogg" then
                resource.AddFile("sound/" .. GSP.MusicDirectory .. "/" .. filename)
                table.insert(GSP.AvailableSongs, filename)
            end
        end
    end
    print("[GSP] Indexed " .. #GSP.AvailableSongs .. " songs.")
end

if GAMEMODE then GSP.IndexSongs() else hook.Add("Initialize", "GSP_MusicInit", GSP.IndexSongs) end

function GSP.PlayTrack(songName)
    GSP.CurrentSong = songName
    GSP.SongStartTime = CurTime()
    GSP.SongDuration = 0
    GSP.IsPaused = false
    timer.Remove("GSP_TrackTimer")

    net.Start("GSP_Play") net.WriteString(songName) net.Broadcast()
end

function GSP.SkipTrack()
    if GSP.IsLooping and GSP.CurrentSong then
        GSP.PlayTrack(GSP.CurrentSong)
        return
    end
    if GSP.Queue and #GSP.Queue > 0 then
        local nextSong = table.remove(GSP.Queue, 1)
        GSP.BroadcastQueue()
        GSP.PlayTrack(nextSong)
    else
        GSP.CurrentSong = nil
        timer.Remove("GSP_TrackTimer")
        net.Start("GSP_Stop") net.Broadcast()
    end
end

function GSP.BroadcastQueue()
    local queue = GSP.Queue or {}
    local count = math.min(#queue, 255) 

    net.Start("GSP_QueueSync")
        net.WriteUInt(count, 8) 
        for i = 1, count do
            net.WriteString(queue[i])
        end
    net.Broadcast()
end

function GSP.BroadcastState()
    net.Start("GSP_StateSync")
    net.WriteFloat(GSP.GlobalVolume or 1)
    net.WriteBool(GSP.IsLooping or false)
    net.WriteBool(GSP.IsPaused or false)
    net.Broadcast()
end


net.Receive("GSP_SetLength", function(len, ply)
    if not GSP.HasMusicPermission(ply) then return end
    if not GSP.CurrentSong then return end
    if GSP.SongDuration and GSP.SongDuration > 0 then return end
    local length = net.ReadFloat()
    if length > 0 and length < 10000 then
        GSP.SongDuration = length
        timer.Create("GSP_TrackTimer", length, 1, function() GSP.SkipTrack() end)
    end
end)

net.Receive("GSP_QueueAdd", function(len, ply)
    if not GSP.HasMusicPermission(ply) then return end

    local songName = net.ReadString()
    local sanitized = SanitizeSongName(songName)
    if sanitized == "" then return end

    GSP.Queue = GSP.Queue or {}
    if #GSP.Queue >= MAX_QUEUE_SIZE then return end

    if not GSP.CurrentSong then 
        GSP.PlayTrack(sanitized) 
    else 
        table.insert(GSP.Queue, sanitized) 
        GSP.BroadcastQueue() 
    end
end)

net.Receive("GSP_NextTrack", function(len, ply)
    if not GSP.HasMusicPermission(ply) then return end
    local quickSong = net.ReadString()
    if quickSong and quickSong ~= "" then GSP.PlayTrack(quickSong) else GSP.SkipTrack() end
end)

net.Receive("GSP_SetVolume", function(len, ply)
    if not GSP.HasMusicPermission(ply) then return end
    GSP.GlobalVolume = math.Clamp(net.ReadFloat(), 0, 1)
    GSP.BroadcastState()
end)

net.Receive("GSP_SetLooping", function(len, ply)
    if not GSP.HasMusicPermission(ply) then return end
    GSP.IsLooping = net.ReadBool()
    GSP.BroadcastState()
end)

net.Receive("GSP_TogglePause", function(len, ply)
    if not GSP.HasMusicPermission(ply) then return end
    if not GSP.CurrentSong then return end
    GSP.IsPaused = not GSP.IsPaused
    if GSP.IsPaused then GSP.PauseTime = CurTime() timer.Pause("GSP_TrackTimer")
    else GSP.SongStartTime = GSP.SongStartTime + (CurTime() - GSP.PauseTime) timer.UnPause("GSP_TrackTimer") end
    GSP.BroadcastState()
end)

net.Receive("GSP_Seek", function(len, ply)
    if not GSP.HasMusicPermission(ply) then return end
    if not GSP.CurrentSong then return end
    
    local newTime = net.ReadFloat()
    
    if not newTime or newTime ~= newTime then return end 

    local maxDuration = GSP.SongDuration or 0
    if maxDuration > 0 then
        newTime = math.Clamp(newTime, 0, maxDuration)
    else
        newTime = math.max(0, newTime)
    end

    GSP.SongStartTime = CurTime() - newTime
    if GSP.SongDuration and GSP.SongDuration > 0 and timer.Exists("GSP_TrackTimer") then
        timer.Adjust("GSP_TrackTimer", math.max(0.1, GSP.SongDuration - newTime), 1, function() GSP.SkipTrack() end)
    end
    net.Start("GSP_Seek") net.WriteFloat(newTime) net.Broadcast()
end)

net.Receive("GSP_Stop", function(len, ply)
    if not GSP.HasMusicPermission(ply) then return end
    GSP.CurrentSong = nil; timer.Remove("GSP_TrackTimer")
    net.Start("GSP_Stop") net.Broadcast()
end)

net.Receive("GSP_Play", function(len, ply)
    if not GSP.HasMusicPermission(ply) then return end

    local songName = net.ReadString()
    local sanitized = SanitizeSongName(songName)
    if sanitized == "" then return end

    GSP.PlayTrack(sanitized)
end)

net.Receive("GSP_UpdateQueue", function(len, ply)
    if not GSP.HasMusicPermission(ply) then return end

    local rawQueue = net.ReadTable()
    if type(rawQueue) ~= "table" then return end

    local cleanQueue = {}
    local count = 0

    for _, value in pairs(rawQueue) do
        if count >= MAX_QUEUE_SIZE then break end

        local sanitized = SanitizeSongName(value)
        if sanitized ~= "" then
            count = count + 1
            cleanQueue[count] = sanitized
        end
    end

    GSP.Queue = cleanQueue
    GSP.BroadcastQueue()
end)

hook.Add("PlayerInitialSpawn", "GSP_SyncNewPlayer", function(ply)
    timer.Simple(3, function()
        if not IsValid(ply) then return end
        GSP.BroadcastState() GSP.BroadcastQueue()
        if GSP.CurrentSong then
            local timePlayed = GSP.IsPaused and (GSP.PauseTime - GSP.SongStartTime) or (CurTime() - GSP.SongStartTime)
            net.Start("GSP_Sync") net.WriteString(GSP.CurrentSong) net.WriteFloat(math.max(0, timePlayed)) net.Send(ply)
        end
    end)
end)

hook.Add("PlayerSay", "GSP_ChatCommand", function(ply, text)
    if string.lower(text) == string.lower(GSP.ChatCommand or "!GSP") then
        net.Start("GSP_OpenUI") net.Send(ply)
        if GSP.HasMusicPermission(ply) then
            net.Start("GSP_SendList") net.WriteTable(GSP.AvailableSongs or {}) net.Send(ply)
        end
        return "" 
    end
end)