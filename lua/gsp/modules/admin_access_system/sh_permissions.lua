GSP = GSP or {}
GSP.MusicRanks = GSP.MusicRanks or {}
GSP.AdminRanks = GSP.AdminRanks or {}

local MAX_RANK_NAME_LENGTH = 64
local MAX_RANKS_LIMIT = 50 


function GSP.IsAdminModInstalled()
    return (ulx ~= nil) or (ULib ~= nil) or (sam ~= nil) or (sadmin ~= nil) or (xadmin ~= nil) or (CAMI ~= nil) or (ServerGuard ~= nil)
end

function GSP.HasAdminPermission(ply)
    if not IsValid(ply) then return false end
    
    if game.SinglePlayer() or ply:IsListenServerHost() then return true end
    
    if ply:IsSuperAdmin() then return true end

    if not GSP.IsAdminModInstalled() then return false end

    return GSP.AdminRanks and GSP.AdminRanks[ply:GetUserGroup()] == true
end

function GSP.HasMusicPermission(ply)
    if not IsValid(ply) then return false end

    if game.SinglePlayer() or ply:IsListenServerHost() then return true end

    if ply:IsSuperAdmin() or GSP.HasAdminPermission(ply) then return true end

    if not GSP.IsAdminModInstalled() then return false end

    return GSP.MusicRanks and GSP.MusicRanks[ply:GetUserGroup()] == true
end

if SERVER then
    util.AddNetworkString("GSP_SyncMusicRanks")
    util.AddNetworkString("GSP_SyncAdminRanks")
    util.AddNetworkString("GSP_AddMusicRank")
    util.AddNetworkString("GSP_RemoveMusicRank")
    util.AddNetworkString("GSP_AddAdminRank")
    util.AddNetworkString("GSP_RemoveAdminRank")
    util.AddNetworkString("GSP_OpenAdminUI")

    function GSP.LoadPermissions()
        if not file.Exists("gsp", "DATA") then file.CreateDir("gsp") end
        
        if file.Exists("gsp/music_ranks.json", "DATA") then
            local data = file.Read("gsp/music_ranks.json", "DATA")
            GSP.MusicRanks = util.JSONToTable(data) or {}
        else
            GSP.MusicRanks = {["superadmin"] = true}
            GSP.SaveMusicRanks()
        end

        if file.Exists("gsp/admin_ranks.json", "DATA") then
            local data = file.Read("gsp/admin_ranks.json", "DATA")
            GSP.AdminRanks = util.JSONToTable(data) or {}
        else
            GSP.AdminRanks = {["superadmin"] = true}
            GSP.SaveAdminRanks()
        end
    end

    function GSP.SaveMusicRanks() file.Write("gsp/music_ranks.json", util.TableToJSON(GSP.MusicRanks, true)) end
    function GSP.SaveAdminRanks() file.Write("gsp/admin_ranks.json", util.TableToJSON(GSP.AdminRanks, true)) end

    function GSP.SyncPermissions(ply)
        if IsValid(ply) then
            net.Start("GSP_SyncMusicRanks") net.WriteTable(GSP.MusicRanks) net.Send(ply)
            net.Start("GSP_SyncAdminRanks") net.WriteTable(GSP.AdminRanks) net.Send(ply)
        else
            net.Start("GSP_SyncMusicRanks") net.WriteTable(GSP.MusicRanks) net.Broadcast()
            net.Start("GSP_SyncAdminRanks") net.WriteTable(GSP.AdminRanks) net.Broadcast()
        end
    end

    if GAMEMODE then GSP.LoadPermissions() else hook.Add("Initialize", "GSP_PermissionsInit", GSP.LoadPermissions) end

    net.Receive("GSP_AddMusicRank", function(len, ply)
        if not GSP.HasAdminPermission(ply) then return end

        local rank = net.ReadString()
        if type(rank) ~= "string" then return end

        rank = string.lower(string.Trim(rank))

        if #rank == 0 or #rank > MAX_RANK_NAME_LENGTH then
            ply:ChatPrint("[GSP] Error: The rank name must be between 1 and " .. MAX_RANK_NAME_LENGTH .. " characters long!")
            return
        end

        if not string.match(rank, "^[%w%-_]+$") then
            ply:ChatPrint("[GSP] Error: The rank name contains invalid characters! Only letters, numbers, '-', and '_' are allowed.")
            return
        end

        local currentCount = table.Count(GSP.MusicRanks or {})
        if currentCount >= MAX_RANKS_LIMIT and not GSP.MusicRanks[rank] then
            ply:ChatPrint("[GSP] Error: Maximum music rank limit (" .. MAX_RANKS_LIMIT .. ") reached!")
            return
        end
        GSP.MusicRanks[rank] = true
        GSP.SaveMusicRanks()
        GSP.SyncPermissions()
    end)

    net.Receive("GSP_RemoveMusicRank", function(len, ply)
        if not GSP.HasAdminPermission(ply) then return end
        local rank = net.ReadString()
        if GSP.MusicRanks[rank] then GSP.MusicRanks[rank] = nil; GSP.SaveMusicRanks(); GSP.SyncPermissions() end
    end)

    net.Receive("GSP_AddAdminRank", function(len, ply)
        if not GSP.HasAdminPermission(ply) then return end

        local rank = net.ReadString()
        if type(rank) ~= "string" then return end

        rank = string.lower(string.Trim(rank))

        if #rank == 0 or #rank > MAX_RANK_NAME_LENGTH then
            ply:ChatPrint("[GSP] Błąd: Nazwa rangi musi mieć od 1 do " .. MAX_RANK_NAME_LENGTH .. " znaków!")
            return
        end

        if not string.match(rank, "^[%w%-_]+$") then
            ply:ChatPrint("[GSP] Błąd: Nazwa rangi zawiera niedozwolone znaki! Dozwolone są tylko litery, cyfry, '-' i '_'.")
            return
        end

        local currentCount = table.Count(GSP.AdminRanks or {})
        if currentCount >= MAX_RANKS_LIMIT and not GSP.AdminRanks[rank] then
            ply:ChatPrint("[GSP] Błąd: Osiągnięto maksymalny limit rang administracyjnych (" .. MAX_RANKS_LIMIT .. ")!")
            return
        end

        GSP.AdminRanks[rank] = true
        GSP.SaveAdminRanks()
        GSP.SyncPermissions() 

    end)

    net.Receive("GSP_RemoveAdminRank", function(len, ply)
        if not GSP.HasAdminPermission(ply) then return end
        local rank = net.ReadString()
        if GSP.AdminRanks[rank] then GSP.AdminRanks[rank] = nil; GSP.SaveAdminRanks(); GSP.SyncPermissions() end
    end)

    hook.Add("PlayerInitialSpawn", "GSP_PermissionsSpawnSync", function(ply)
        timer.Simple(2.5, function() if IsValid(ply) then GSP.SyncPermissions(ply) end end)
    end)

    hook.Add("PlayerSay", "GSP_AdminChatCommand", function(ply, text)
        if string.lower(text) == string.lower(GSP.AdminChatCommand or "!GSP_admin") then
            if GSP.HasAdminPermission(ply) then
                net.Start("GSP_OpenAdminUI") net.Send(ply)
                GSP.SyncPermissions(ply)
            else
            end
            return ""
        end
    end)
end

if CLIENT then
    GSP.AdminUI = GSP.AdminUI or nil
    GSP.AdminBridge = GSP.AdminBridge or nil

    net.Receive("GSP_SyncMusicRanks", function()
        GSP.MusicRanks = net.ReadTable()
        if GSP.AdminBridge then GSP.AdminBridge:Emit("UpdateMusicRanks", GSP.MusicRanks) end
    end)

    net.Receive("GSP_SyncAdminRanks", function()
        GSP.AdminRanks = net.ReadTable()
        if GSP.AdminBridge then GSP.AdminBridge:Emit("UpdateAdminRanks", GSP.AdminRanks) end
    end)

    local function OpenAdminUI()
        if IsValid(GSP.AdminUI) then GSP.AdminUI:Remove() end

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
        GSP.AdminBridge = bridge

        bridge:On("AddMusicRank", function(data) net.Start("GSP_AddMusicRank") net.WriteString(data.rank) net.SendToServer() end)
        bridge:On("RemoveMusicRank", function(data) net.Start("GSP_RemoveMusicRank") net.WriteString(data.rank) net.SendToServer() end)
        bridge:On("AddAdminRank", function(data) net.Start("GSP_AddAdminRank") net.WriteString(data.rank) net.SendToServer() end)
        bridge:On("RemoveAdminRank", function(data) net.Start("GSP_RemoveAdminRank") net.WriteString(data.rank) net.SendToServer() end)
        bridge:On("CloseUI", function() if IsValid(frame) then frame:Close() end end)
        bridge:On("StartDrag", function() isDragging, dragX, dragY = true, gui.MouseX() - frame.x, gui.MouseY() - frame.y end)

        bridge:On("ChangeLanguage", function(data)
            local lang = data.lang
            if GSP.Translations[lang] then
                GSP.CurrentLanguage = lang
                bridge:Emit("UpdateTranslations", GSP.Translations[lang])
                
                if not file.Exists("gsp", "DATA") then file.CreateDir("gsp") end
                local settings = { lang = lang, vol = GSP.LocalVolume, mute = GSP.LocalMuted }
                file.Write("gsp/client_settings.json", util.TableToJSON(settings))
            end
        end)

        bridge:On("ChangeCloseKey", function(data)
            GSP.CloseKey = data.key
            local settings = { lang = GSP.CurrentLanguage, vol = GSP.LocalVolume, mute = GSP.LocalMuted, closeKey = GSP.CloseKey }
            file.Write("gsp/client_settings.json", util.TableToJSON(settings))
        end)

        bridge:On("SetBindingMode", function(data)
            GSP.IsBindingMode = data.state
        end)

        bridge:On("RequestAdminPermissions", function()
            bridge:Emit("UpdateMusicRanks", GSP.MusicRanks or {})
            bridge:Emit("UpdateAdminRanks", GSP.AdminRanks or {})
            bridge:Emit("UpdateTranslations", GSP.Translations[GSP.CurrentLanguage or GSP.DefaultLanguage or "pl"])
            bridge:Emit("UpdateClientState", {
                closeKey = GSP.CloseKey or "Escape"
            })
        end)

        bridge:Emit("SetUIMode", { mode = "admin" })

        local htmlPath = GSP.HTMLPath or "gsp/index.html"
        local localHTML = file.Read(htmlPath, "LUA")
        if localHTML and localHTML ~= "" then html:SetHTML(localHTML) end
        html:RequestFocus()
        GSP.AdminUI = frame
    end

    net.Receive("GSP_OpenAdminUI", function() OpenAdminUI() end)
end