GSP = GSP or {}

GSP.UI = GSP.UI or nil
GSP.Bridge = GSP.Bridge or nil

GSP.Server = GSP.Server or { Song = "Brak utworu", Duration = 0, StartTime = 0, PauseTime = 0, IsPaused = false, Channel = nil, DHTML = nil }
GSP.Client = GSP.Client or { Song = "Brak utworu", Duration = 0, StartTime = 0, PauseTime = 0, IsPaused = false, Channel = nil, DHTML = nil }
GSP.ClientQueue = GSP.ClientQueue or {}

GSP.GlobalVolume = GSP.GlobalVolume or 1
GSP.LocalVolume = GSP.LocalVolume or 0.5
GSP.LocalMuted = GSP.LocalMuted or false

local function LoadClientSettings()
    if file.Exists("gsp/client_settings.json", "DATA") then
        local data = file.Read("gsp/client_settings.json", "DATA")
        local settings = util.JSONToTable(data or "")
        if settings then
            GSP.LocalVolume = settings.vol or 0.5
            GSP.CurrentLanguage = settings.lang or GSP.DefaultLanguage or "en"
            GSP.LocalMuted = settings.mute or false
            GSP.CloseKey = settings.closeKey or "Escape"
        end
    end
end

hook.Add("Initialize", "GSP_LoadClientSettings", LoadClientSettings)

local function ApplyState()
    local clientPlaying = (GSP.Client.Song ~= "Brak utworu" and not GSP.Client.IsPaused)
    local sVol = GSP.GlobalVolume * GSP.LocalVolume
    if GSP.LocalMuted or clientPlaying then sVol = 0 end
    
    if IsValid(GSP.Server.Channel) then
        GSP.Server.Channel:SetVolume(sVol)
        if GSP.Server.IsPaused then GSP.Server.Channel:Pause() else GSP.Server.Channel:Play() end
    end
    if IsValid(GSP.Server.DHTML) then
        GSP.Server.DHTML:RunJavascript("if(player && player.setVolume) { player.setVolume(" .. math.floor(sVol * 100) .. "); }")
        if GSP.Server.IsPaused then GSP.Server.DHTML:RunJavascript("if(player && player.pauseVideo) { player.pauseVideo(); }")
        else GSP.Server.DHTML:RunJavascript("if(player && player.playVideo) { player.playVideo(); }") end
    end

    local cVol = GSP.LocalVolume
    if GSP.LocalMuted then cVol = 0 end
    if IsValid(GSP.Client.Channel) then
        GSP.Client.Channel:SetVolume(cVol)
        if GSP.Client.IsPaused then GSP.Client.Channel:Pause() else GSP.Client.Channel:Play() end
    end
    if IsValid(GSP.Client.DHTML) then
        GSP.Client.DHTML:RunJavascript("if(player && player.setVolume) { player.setVolume(" .. math.floor(cVol * 100) .. "); }")
        if GSP.Client.IsPaused then GSP.Client.DHTML:RunJavascript("if(player && player.pauseVideo) { player.pauseVideo(); }")
        else GSP.Client.DHTML:RunJavascript("if(player && player.playVideo) { player.playVideo(); }") end
    end
end

local function StopMusic(isServer)
    local state = isServer and GSP.Server or GSP.Client
    if IsValid(state.Channel) then state.Channel:Stop() state.Channel = nil end
    if IsValid(state.DHTML) then 
        state.DHTML:RunJavascript("if(player && player.stopVideo) player.stopVideo();")
        state.DHTML:Remove() state.DHTML = nil 
    end
    if not isServer then timer.Remove("GSP_ClientTrackTimer") end
end

local function NextClientTrack()
    if GSP.Client.IsLooping and GSP.Client.Song ~= "Brak utworu" then
        PlayMusic(false, GSP.Client.Song, 0)
    elseif #GSP.ClientQueue > 0 then
        local nextSong = table.remove(GSP.ClientQueue, 1)
        PlayMusic(false, nextSong, 0)
    else
        StopMusic(false)
        GSP.Client.Song = "Brak utworu"
        GSP.Client.Duration = 0
    end
    ApplyState() 
    SyncReactState()
end

local function GetYouTubeID(url)
    local id = string.match(url, "v=([%w%-_]+)")
    if not id then id = string.match(url, "youtu%.be/([%w%-_]+)") end
    if not id then id = string.match(url, "embed/([%w%-_]+)") end
    return id
end

function PlayMusic(isServer, songName, startTimeOffset)
    local state = isServer and GSP.Server or GSP.Client
    StopMusic(isServer)
    state.Song = songName
    state.Duration = 0
    state.StartTime = CurTime() - (startTimeOffset or 0)
    state.IsPaused = false
    
    local isURL = string.StartWith(songName, "http://") or string.StartWith(songName, "https://")
    if isURL then
        local ytID = GetYouTubeID(songName)
        if ytID then
            local html = vgui.Create("DHTML")
            html:SetSize(1, 1) html:SetPos(-10, -10) html:SetVisible(true)
            html:SetMouseInputEnabled(false) html:SetKeyBoardInputEnabled(false)
            html:AddFunction("gmod", "onPlayerReady", function() ApplyState() end)
            html:AddFunction("gmod", "sendDuration", function(duration)
                if tonumber(duration) and tonumber(duration) > 0 then
                    state.Duration = tonumber(duration)
                    if isServer then
                        net.Start("GSP_SetLength") net.WriteFloat(state.Duration) net.SendToServer()
                    else
                        timer.Create("GSP_ClientTrackTimer", state.Duration, 1, NextClientTrack)
                    end
                end
            end)
            
            local initVol = isServer and (GSP.GlobalVolume * GSP.LocalVolume) or GSP.LocalVolume
            if GSP.LocalMuted then initVol = 0 end
            local startSec = math.floor(startTimeOffset or 0)
            
            html:SetHTML([[
                <!DOCTYPE html><html><body style="margin:0;background-color:black;">
                    <div id="player"></div>
                    <script>
                        var tag = document.createElement('script'); tag.src = "https://www.youtube.com/iframe_api";
                        var firstScriptTag = document.getElementsByTagName('script')[0]; firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
                        var player;
                        function onYouTubeIframeAPIReady() {
                            player = new YT.Player('player', { videoId: ']] .. ytID .. [[',
                                playerVars: { 'autoplay': 1, 'controls': 0, 'start': ]] .. startSec .. [[, 'origin': 'http://garrysmod.com' },
                                events: {
                                    -- Bezpośrednio przy ready ustawiamy wyliczoną w Lua głośność (brak opóźnienia i trzasku)
                                    'onReady': function(e) { 
                                        e.target.setVolume(]] .. math.floor(initVol * 100) .. [[); 
                                        gmod.onPlayerReady(); 
                                        setTimeout(function(){ if(player.getDuration) gmod.sendDuration(player.getDuration()); }, 1000); 
                                    },
                                    'onStateChange': function(e) { if (e.data == YT.PlayerState.PLAYING) gmod.sendDuration(player.getDuration()); }
                                }
                            });
                        }
                    </script>
                </body></html>
            ]])
            state.DHTML = html
        else
            sound.PlayURL(songName, "noplay noblock", function(station, errID, errName)
                if IsValid(station) then
                    if startTimeOffset and startTimeOffset > 0 then station:SetTime(startTimeOffset) end
                    state.Channel = station
                    ApplyState()
                    
                    local duration = station:GetLength()
                    if not duration or duration <= 0 then
                        local timerName = "GSP_LengthRetry_" .. tostring(station)
                        timer.Create(timerName, 0.1, 10, function()
                            if IsValid(station) then
                                local dur = station:GetLength()
                                if dur and dur > 0 and dur < 86400 then
                                    state.Duration = dur
                                    timer.Remove(timerName)
                                    
                                    if isServer then
                                        net.Start("GSP_SetLength") net.WriteFloat(state.Duration) net.SendToServer()
                                    else
                                        timer.Create("GSP_ClientTrackTimer", state.Duration, 1, NextClientTrack)
                                    end
                                    SyncReactState()
                                end
                            else
                                timer.Remove(timerName)
                            end
                        end)
                    else
                        state.Duration = duration
                        if isServer then
                            net.Start("GSP_SetLength") net.WriteFloat(state.Duration) net.SendToServer()
                        else
                            timer.Create("GSP_ClientTrackTimer", state.Duration, 1, NextClientTrack)
                        end
                    end
                    
                    SyncReactState()
                else
                    local errMsg = string.format("[GSP] Blad odtwarzania URL: '%s' (Kod: %s, %s)", songName, tostring(errID or "N/A"), errName or "Nieznany blad")
                    print(errMsg)
                    if not isServer then LocalPlayer():ChatPrint(errMsg) end

                    state.Song = "Brak utworu"
                    state.Duration = 0
                    if not isServer then timer.Remove("GSP_ClientTrackTimer") end
                    SyncReactState()
                end
            end)
        end
    else
        local safeSongName = string.GetFileFromFilename(songName)
        local ext = string.lower(string.GetExtensionFromFilename(safeSongName) or "")

        if ext ~= "mp3" and ext ~= "ogg" then
            state.Song = "Brak utworu"
            return
        end

        local path = "sound/" .. (GSP.MusicDirectory or "GSP") .. "/" .. safeSongName
        sound.PlayFile(path, "noplay noblock", function(station, errID, errName)
            if IsValid(station) then
                if startTimeOffset and startTimeOffset > 0 then station:SetTime(startTimeOffset) end
                state.Channel = station
                ApplyState()
                
                local duration = station:GetLength()
                if not duration or duration <= 0 then
                    local timerName = "GSP_LengthRetry_" .. tostring(station)
                    timer.Create(timerName, 0.1, 10, function()
                        if IsValid(station) then
                            local dur = station:GetLength()
                            if dur and dur > 0 and dur < 86400 then
                                state.Duration = dur
                                timer.Remove(timerName)
                                
                                if isServer then
                                    net.Start("GSP_SetLength") net.WriteFloat(state.Duration) net.SendToServer()
                                else
                                    timer.Create("GSP_ClientTrackTimer", state.Duration, 1, NextClientTrack)
                                end
                                SyncReactState()
                            end
                        else
                            timer.Remove(timerName)
                        end
                    end)
                else
                    state.Duration = duration
                    if isServer then
                        net.Start("GSP_SetLength") net.WriteFloat(state.Duration) net.SendToServer()
                    else
                        timer.Create("GSP_ClientTrackTimer", state.Duration, 1, NextClientTrack)
                    end
                end
                
                SyncReactState()
            else
                local errMsg = string.format("[GSP] Blad pliku lokalnego: '%s' (Kod: %s, %s)", safeSongName, tostring(errID or "N/A"), errName or "Brak pliku")
                print(errMsg)
                if not isServer then LocalPlayer():ChatPrint(errMsg) end
                
                state.Song = "Brak utworu"
                state.Duration = 0
                if not isServer then timer.Remove("GSP_ClientTrackTimer") end
                SyncReactState()
            end
        end)
    end
end

function SyncReactState()
    if not GSP.Bridge then return end
    local sTime = 0
    if GSP.Server.Song ~= "Brak utworu" then
        sTime = GSP.Server.IsPaused and (GSP.Server.PauseTime - GSP.Server.StartTime) or (CurTime() - GSP.Server.StartTime)
    end

    GSP.Bridge:Emit("UpdateServerState", {
        currentSong = GSP.Server.Song,
        globalVolume = GSP.GlobalVolume,
        isPaused = GSP.Server.IsPaused,
        isLooping = GSP.IsLooping or false,
        currentTime = math.max(0, sTime),
        duration = GSP.Server.Duration
    })

    local cTime = 0
    if GSP.Client.Song ~= "Brak utworu" then
        cTime = GSP.Client.IsPaused and (GSP.Client.PauseTime - GSP.Client.StartTime) or (CurTime() - GSP.Client.StartTime)
    end

    GSP.Bridge:Emit("UpdateClientState", {
        currentSong = GSP.Client.Song,
        localVolume = GSP.LocalVolume,
        localMuted = GSP.LocalMuted,
        isAdmin = GSP.HasMusicPermission(LocalPlayer()),
        isPaused = GSP.Client.IsPaused,
        isLooping = GSP.Client.IsLooping or false,
        currentTime = math.max(0, cTime),
        duration = GSP.Client.Duration,
        currentLanguage = GSP.CurrentLanguage,
        closeKey = GSP.CloseKey or "Escape"
    })
    GSP.Bridge:Emit("UpdateClientQueue", GSP.ClientQueue)
end

net.Receive("GSP_Play", function() PlayMusic(true, net.ReadString(), 0); SyncReactState() end)
net.Receive("GSP_Sync", function() PlayMusic(true, net.ReadString(), net.ReadFloat()); SyncReactState() end)
net.Receive("GSP_Stop", function() StopMusic(true); GSP.Server.Song = "Brak utworu"; GSP.Server.Duration = 0; SyncReactState() end)
net.Receive("GSP_StateSync", function()
    GSP.GlobalVolume, GSP.IsLooping = net.ReadFloat(), net.ReadBool()
    local wasPaused = GSP.Server.IsPaused
    GSP.Server.IsPaused = net.ReadBool()
    if GSP.Server.IsPaused and not wasPaused then GSP.Server.PauseTime = CurTime()
    elseif not GSP.Server.IsPaused and wasPaused then GSP.Server.StartTime = GSP.Server.StartTime + (CurTime() - GSP.Server.PauseTime) end
    ApplyState() SyncReactState()
end)

net.Receive("GSP_Seek", function()
    local newTime = net.ReadFloat()
    GSP.Server.StartTime = CurTime() - newTime
    if IsValid(GSP.Server.Channel) and GSP.Server.Duration > 0 then pcall(function() GSP.Server.Channel:SetTime(newTime) end) end
    if IsValid(GSP.Server.DHTML) then GSP.Server.DHTML:RunJavascript("if(player && player.seekTo) { player.seekTo(" .. newTime .. ", true); }") end
    SyncReactState()
end)

net.Receive("GSP_QueueSync", function()
    local count = net.ReadUInt(8) or 0
    local queue = {}
    
    for i = 1, count do
        queue[i] = net.ReadString()
    end

    GSP.Queue = queue
    if GSP.Bridge then 
        GSP.Bridge:Emit("UpdateServerQueue", GSP.Queue) 
    end
end)
net.Receive("GSP_SendList", function() GSP.LocalSongList = net.ReadTable(); if GSP.Bridge then GSP.Bridge:Emit("UpdateLocalSongs", GSP.LocalSongList) end end)

local function OpenUI()
    if IsValid(GSP.UI) then GSP.UI:Remove() end

    local frame = vgui.Create("DFrame")
    frame:SetSize(1100, 700) frame:Center() frame:SetTitle("") frame:ShowCloseButton(false) frame:SetDraggable(false) frame:MakePopup()
    frame.Paint = function() end

    local html = vgui.Create("DHTML", frame)
    html:SetPos(0, 0) html:SetSize(frame:GetWide(), frame:GetTall()) html:SetScrollbars(false)
    html:QueueJavascript("document.body.style.margin = '0'; document.body.style.overflow = 'hidden';")

    local dragBar = vgui.Create("DPanel", frame)
    dragBar:SetSize(900, 45) dragBar:SetPos(0, 0) dragBar.Paint = function() end
    local isDragging, dragX, dragY = false, 0, 0
    dragBar.OnMousePressed = function(self, keyCode)
        if keyCode == MOUSE_LEFT then isDragging, dragX, dragY = true, gui.MouseX() - frame.x, gui.MouseY() - frame.y end
    end
    dragBar.Think = function(self)
        if isDragging then if input.IsMouseDown(MOUSE_LEFT) then frame:SetPos(gui.MouseX() - dragX, gui.MouseY() - dragY) else isDragging = false end end
    end

    local bridge = GModReactBridge:New(html)
    GSP.Bridge = bridge

    bridge:On("PlayTrack", function(data) if data.isServer then net.Start("GSP_Play") net.WriteString(data.song) net.SendToServer() else PlayMusic(false, data.song, 0) SyncReactState() end end)
    bridge:On("QueueAdd", function(data) if data.isServer then net.Start("GSP_QueueAdd") net.WriteString(data.song) net.SendToServer() else table.insert(GSP.ClientQueue, data.song) SyncReactState() end end)
    bridge:On("Seek", function(data) 
        if data.isServer then 
            net.Start("GSP_Seek") net.WriteFloat(data.time) net.SendToServer() 
        else 
            GSP.Client.StartTime = CurTime() - data.time
            
            if IsValid(GSP.Client.Channel) then 
                pcall(function() GSP.Client.Channel:SetTime(data.time) end) 
            end
            
            if IsValid(GSP.Client.DHTML) then 
                GSP.Client.DHTML:RunJavascript("if(player && player.seekTo) { player.seekTo(" .. data.time .. ", true); }") 
            end
            
            if timer.Exists("GSP_ClientTrackTimer") and GSP.Client.Duration > 0 then
                timer.Adjust("GSP_ClientTrackTimer", math.max(0.1, GSP.Client.Duration - data.time), 1, NextClientTrack)
            end
            
            SyncReactState() 
        end 
    end)
    bridge:On("TogglePause", function(data) if data.isServer then net.Start("GSP_TogglePause") net.SendToServer() else GSP.Client.IsPaused = not GSP.Client.IsPaused; if GSP.Client.IsPaused then GSP.Client.PauseTime = CurTime() timer.Pause("GSP_ClientTrackTimer") else GSP.Client.StartTime = GSP.Client.StartTime + (CurTime() - GSP.Client.PauseTime) timer.UnPause("GSP_ClientTrackTimer") end; ApplyState(); SyncReactState() end end)
    bridge:On("StopMusic", function(data) if data.isServer then net.Start("GSP_Stop") net.SendToServer() else StopMusic(false) GSP.Client.Song = "Brak utworu" GSP.Client.Duration = 0 ApplyState() SyncReactState() end end)
    bridge:On("NextTrack", function(data) if data.isServer then net.Start("GSP_NextTrack") net.WriteString(data and data.song or "") net.SendToServer() else NextClientTrack() end end)
    bridge:On("SyncQueue", function(data) if data.isServer then net.Start("GSP_UpdateQueue") net.WriteTable(data.queue) net.SendToServer() else GSP.ClientQueue = data.queue SyncReactState() end end)
    
    bridge:On("SetGlobalVolume", function(data) net.Start("GSP_SetVolume") net.WriteFloat(data.volume) net.SendToServer() end)
    bridge:On("SetLooping", function(data) net.Start("GSP_SetLooping") net.WriteBool(data.state) net.SendToServer() end)
    bridge:On("SetLocalVolume", function(data) GSP.LocalVolume = data.volume ApplyState() SyncReactState() end)
    bridge:On("SetLocalLooping", function(data) 
        GSP.Client.IsLooping = data.state 
        SyncReactState() 
    end)
    bridge:On("CloseUI", function() if IsValid(frame) then frame:Close() end end)
    bridge:On("StartDrag", function() isDragging, dragX, dragY = true, gui.MouseX() - frame.x, gui.MouseY() - frame.y end)

    bridge:On("ToggleLocalMute", function(data) 
        GSP.LocalMuted = data.state 
        ApplyState() SyncReactState() 
        local settings = { lang = GSP.CurrentLanguage, vol = GSP.LocalVolume, mute = GSP.LocalMuted, closeKey = GSP.CloseKey or "Escape" }
        file.Write("gsp/client_settings.json", util.TableToJSON(settings))
    end)

    bridge:On("ChangeLanguage", function(data)
        local lang = data.lang
        if GSP.Translations[lang] then
            GSP.CurrentLanguage = lang
            bridge:Emit("UpdateTranslations", GSP.Translations[lang])
            local settings = { lang = lang, vol = GSP.LocalVolume, mute = GSP.LocalMuted, closeKey = GSP.CloseKey or "Escape" }
            file.Write("gsp/client_settings.json", util.TableToJSON(settings))
        end
    end)

    bridge:On("ChangeCloseKey", function(data)
        GSP.CloseKey = data.key
        SyncReactState()
        local settings = { lang = GSP.CurrentLanguage, vol = GSP.LocalVolume, mute = GSP.LocalMuted, closeKey = GSP.CloseKey }
        file.Write("gsp/client_settings.json", util.TableToJSON(settings))
    end)

    bridge:On("SetBindingMode", function(data)
        GSP.IsBindingMode = data.state
    end)

    bridge:On("RequestPlayerSync", function()
        bridge:Emit("UpdateServerQueue", GSP.Queue or {})
        bridge:Emit("UpdateLocalSongs", GSP.LocalSongList or {})
        bridge:Emit("UpdateLanguages", GSP.Languages or {})
        
        local lang = GSP.CurrentLanguage or GSP.DefaultLanguage or "en"
        local translations = GSP.Translations[lang] or GSP.Translations["en"] or GSP.Translations["pl"]
        bridge:Emit("UpdateTranslations", translations)
        
        SyncReactState()
    end)

    bridge:Emit("SetUIMode", { mode = "player" })

    local htmlPath = GSP.HTMLPath or "gsp/index.html"
    local localHTML = file.Read(htmlPath, "LUA")
    if localHTML and localHTML ~= "" then html:SetHTML(localHTML) end
    html:RequestFocus()
    timer.Create("GSP_ReactSync", 1.0, 0, SyncReactState)
    frame.OnClose = function() 
        timer.Remove("GSP_ReactSync") 
        GSP.IsBindingMode = false
        GSP.Bridge = nil 
    end
    GSP.UI = frame
end

net.Receive("GSP_OpenUI", function() OpenUI() end)

hook.Add("OnPauseMenuShow", "GSP_BlockEscapeShow", function()
    if GSP.IsBindingMode then
        GSP.IsBindingMode = false 
        return false
    end
end)
