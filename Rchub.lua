-- RC HUB - AutoFarm + Noclip + Speed + BreakDefense (Rayfield) - Versão completa
-- Mantive o bloco do AutoFarm Slayer exatamente como você pediu e adicionei Oni/Gyutaro/Kaigaku/Trinkets/Noclip/Speed.

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "TSUO HUB DEMONFALL",
   LoadingTitle = "ATUALIZAÇÃO 1.0",
   LoadingSubtitle = "BY POCOYO",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = nil,
      FileName = "RCHubConfig"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvite",
      RememberJoins = true
   },
   KeySystem = false,
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

-- Safe getter de remotes
local function getRemotes()
    local r = ReplicatedStorage:FindFirstChild("Remotes")
    if not r then return nil end
    return {
        Async = r:FindFirstChild("Async"),
        Sync = r:FindFirstChild("Sync"),
    }
end

local Remotes = getRemotes()

-- Função pra garantir remotes atualizados
local function ensureRemotes()
    if Remotes and Remotes.Async and Remotes.Sync then return end
    Remotes = getRemotes()
end

-- equipar espada (chamada 1x ao ativar cada farm)
local function equipSword()
    ensureRemotes()
    if Remotes and Remotes.Async then
        pcall(function()
            Remotes.Async:FireServer("Katana","EquippedEvents", true, true)
        end)
    end
end

-- Funções de ataque (usadas pelos farms)
local function attack()
    ensureRemotes()
    if Remotes and Remotes.Async then
        pcall(function()
            Remotes.Async:FireServer("Katana","Server")
        end)
    end
end

local function breakDefense()
    ensureRemotes()
    if Remotes and Remotes.Async then
        pcall(function()
            Remotes.Async:FireServer("Katana","Heavy")
        end)
    end
end

local function executeOnce()
    ensureRemotes()
    if Remotes and Remotes.Sync then
        pcall(function()
            Remotes.Sync:InvokeServer("Character","Execute")
        end)
    end
end

-- Heurística simples para detectar defesa (mesma do seu script)
local function isDefending(npcModel)
    if not npcModel then return false end
    local names = {"Defending","Defend","Blocking","IsBlocking","IsDefending","Block"}
    for _,n in ipairs(names) do
        local child = npcModel:FindFirstChild(n)
        if child and child:IsA("BoolValue") and child.Value == true then return true end
        if child and child:IsA("NumberValue") and child.Value > 0 then return true end
    end
    for _,n in ipairs(names) do
        local attr = npcModel:GetAttribute(n)
        if attr == true or attr == 1 then return true end
    end
    local partNames = {"Shield","Block","Defense","BlockingPart"}
    for _,pn in ipairs(partNames) do
        local p = npcModel:FindFirstChild(pn)
        if p and p.Name:lower():find(pn:lower()) then return true end
    end
    local humanoid = npcModel:FindFirstChild("Humanoid")
    if humanoid then
        for _,v in pairs(humanoid:GetChildren()) do
            if v:IsA("BoolValue") or v:IsA("NumberValue") then
                local lname = v.Name:lower()
                if lname:find("block") or lname:find("defend") then
                    if v.Value == true or v.Value > 0 then return true end
                end
            end
        end
    end
    return false
end

-- Teleport helper
local function getPlayerRefs()
    if not player then return nil end
    local ch = player.Character
    if not ch then return nil end
    local hrp = ch:FindFirstChild("HumanoidRootPart")
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return nil end
    return {char = ch, hrp = hrp, humanoid = hum}
end

local function teleportToTargetPart(targetPart, offset)
    if not targetPart then return end
    local refs = getPlayerRefs()
    if not refs then return end
    local hrp = refs.hrp
    if not hrp then return end
    local newPos = targetPart.Position + offset
    if newPos.Y < -150 then
        newPos = targetPart.Position + Vector3.new(0,3,0)
    end
    pcall(function()
        hrp.CanCollide = false
        hrp.CFrame = CFrame.new(newPos)
    end)
end

-- find helper by name (checks Map Slayers then workspace)
local function findTargetByName(name)
    local mapas = Workspace:FindFirstChild("Map") or Workspace:FindFirstChild("Maps")
    local slayerFolder = mapas and (mapas:FindFirstChild("Slayers") or mapas:FindFirstChild("Slayer"))
    if slayerFolder then
        for _,c in pairs(slayerFolder:GetChildren()) do
            if c:IsA("Model") and c.Name == name and c:FindFirstChild("Humanoid") then
                return c
            end
        end
    end
    for _,obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name == name and obj:FindFirstChild("Humanoid") then
            return obj
        end
    end
    return nil
end

-- === -----------------------------------------------------------
-- ===  AQUI ESTÁ O BLOCO DO AUTO FARM SLAYER EXATAMENTE COMO VOCÊ MANDOU
-- ===  (não alterei nada neste bloco)
-- === -----------------------------------------------------------
local npcName = "GenericSlayer" -- Nome do NPC
local farmEnabled = false
local currentSpeed = 100
local noclipEnabled = false
local speedEnabled = false

local safeBelowOffset = Vector3.new(0, -5, 0) -- 5 studs abaixo do NPC
local tpAboveOffset = Vector3.new(0, 5, 0) -- 5 studs acima

-- FARM LOOP (uses isDefending to call breakDefense)
local farmConnection = nil
local function startFarmLoop()
    if farmConnection then return end
    farmConnection = RunService.Heartbeat:Connect(function()
        if not farmEnabled then return end
        local target = findTargetByName(npcName)
        if not target or not target.Parent then return end
        local hrpTarget = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart")
        local humanoidTarget = target:FindFirstChild("Humanoid")
        if not hrpTarget or not humanoidTarget or humanoidTarget.Health <= 0 then return end

        -- If NPC is defending -> try breakDefense first
        if isDefending(target) then
            -- try a few heavy hits with small spacing (avoid over-flood)
            for i = 1, 3 do
                if not farmEnabled then break end
                breakDefense()
                task.wait(0.18)
                -- recheck: if no longer defending, break out
                if not isDefending(target) then break end
            end
            -- small pause to let state update
            task.wait(0.25)
        end

        -- Teleport below (keep upright)
        teleportToTargetPart(hrpTarget, safeBelowOffset)

        -- Normal attack spam
        attack()
        -- attempt execute if dead soon after (optional)
        if humanoidTarget.Health <= 0 then
            task.wait(0.2)
            executeOnce()
        end
    end)
end

local function stopFarmLoop()
    if farmConnection then
        farmConnection:Disconnect()
        farmConnection = nil
    end
end
-- === -----------------------------------------------------------
-- ===  FIM DO BLOCO DO AUTO FARM SLAYER (SEM ALTERAÇÃO)
-- === -----------------------------------------------------------

-- === Agora: replicar MESMA LÓGICA para Oni, Gyutaro e Kaigaku,
-- cada um com seu flag/connection separado, e equipar espada ao ativar.

-- Oni (GenericOni)
local oniEnabled = false
local oniConn = nil
local function startOniLoop()
    if oniConn then return end
    oniConn = RunService.Heartbeat:Connect(function()
        if not oniEnabled then return end
        local target = findTargetByName("GenericOni")
        if not target or not target.Parent then return end
        local hrpTarget = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart")
        local humanoidTarget = target:FindFirstChild("Humanoid")
        if not hrpTarget or not humanoidTarget or humanoidTarget.Health <= 0 then return end

        if isDefending(target) then
            for i = 1, 3 do
                if not oniEnabled then break end
                breakDefense()
                task.wait(0.18)
                if not isDefending(target) then break end
            end
            task.wait(0.25)
        end

        teleportToTargetPart(hrpTarget, safeBelowOffset)
        attack()
        if humanoidTarget.Health <= 0 then
            task.wait(0.2)
            executeOnce()
        end
    end)
end
local function stopOniLoop()
    if oniConn then oniConn:Disconnect(); oniConn = nil end
end

-- Gyutaro
local gyuEnabled = false
local gyuConn = nil
local function startGyutaroLoop()
    if gyuConn then return end
    gyuConn = RunService.Heartbeat:Connect(function()
        if not gyuEnabled then return end
        local target = findTargetByName("Gyutaro")
        if not target or not target.Parent then return end
        local hrpTarget = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart")
        local humanoidTarget = target:FindFirstChild("Humanoid")
        if not hrpTarget or not humanoidTarget or humanoidTarget.Health <= 0 then return end

        if isDefending(target) then
            for i = 1, 3 do
                if not gyuEnabled then break end
                breakDefense()
                task.wait(0.18)
                if not isDefending(target) then break end
            end
            task.wait(0.25)
        end

        teleportToTargetPart(hrpTarget, safeBelowOffset)
        attack()
        if humanoidTarget.Health <= 0 then
            task.wait(0.2)
            executeOnce()
        end
    end)
end
local function stopGyutaroLoop()
    if gyuConn then gyuConn:Disconnect(); gyuConn = nil end
end

-- Kaigaku
local kaiEnabled = false
local kaiConn = nil
local function startKaigakuLoop()
    if kaiConn then return end
    kaiConn = RunService.Heartbeat:Connect(function()
        if not kaiEnabled then return end
        local target = findTargetByName("Kaigaku")
        if not target or not target.Parent then return end
        local hrpTarget = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart")
        local humanoidTarget = target:FindFirstChild("Humanoid")
        if not hrpTarget or not humanoidTarget or humanoidTarget.Health <= 0 then return end

        if isDefending(target) then
            for i = 1, 3 do
                if not kaiEnabled then break end
                breakDefense()
                task.wait(0.18)
                if not isDefending(target) then break end
            end
            task.wait(0.25)
        end

        teleportToTargetPart(hrpTarget, safeBelowOffset)
        attack()
        if humanoidTarget.Health <= 0 then
            task.wait(0.2)
            executeOnce()
        end
    end)
end
local function stopKaigakuLoop()
    if kaiConn then kaiConn:Disconnect(); kaiConn = nil end
end

-- === AutoFarm Trinkets (coleta controlada) ===
local trinketState = {running = false}
local function getAllTrinkets()
    local list = {}
    local map = Workspace:FindFirstChild("Map")
    if map and map:FindFirstChild("Trinkets") then
        for _,t in pairs(map.Trinkets:GetChildren()) do table.insert(list, t) end
    end
    for _,inst in pairs(Workspace:GetChildren()) do
        if inst.Name == "Copper Goblet" or inst.Name == "Gold Goblet" or inst.Name == "Silver Ring" then
            table.insert(list, inst)
        end
    end
    return list
end

local function collectTrinketOnce(trinket)
    if not trinket or not trinket.Parent then return false end
    local main = trinket:FindFirstChild("Main") or trinket:FindFirstChildWhichIsA("BasePart") or nil
    local refs = getPlayerRefs()
    if not main or not refs then return false end
    pcall(function() refs.hrp.CFrame = main.CFrame + Vector3.new(0,3,0) end)
    task.wait(0.12)
    ensureRemotes()
    if Remotes and Remotes.Async then
        pcall(function() Remotes.Async:FireServer("Character","Interaction", main) end)
    end
    local t = 0
    while trinket.Parent and t < 3 do task.wait(0.2); t = t + 0.2 end
    return not trinket.Parent
end

local function startTrinketLoop()
    if trinketState.running then return end
    trinketState.running = true
    task.spawn(function()
        while trinketState.running do
            local refs = getPlayerRefs()
            if not refs then task.wait(1) else
                local list = getAllTrinkets()
                if #list == 0 then task.wait(1)
                else
                    table.sort(list, function(a,b)
                        local pa = a:FindFirstChildWhichIsA("BasePart") or a:FindFirstChild("Main")
                        local pb = b:FindFirstChildWhichIsA("BasePart") or b:FindFirstChild("Main")
                        if pa and pb and refs.hrp then
                            return (refs.hrp.Position - pa.Position).Magnitude < (refs.hrp.Position - pb.Position).Magnitude
                        end
                        return false
                    end)
                    for _,t in pairs(list) do
                        if not trinketState.running then break end
                        if not t or not t.Parent then continue end
                        pcall(function() collectTrinketOnce(t) end)
                        task.wait(0.3) -- small gap to avoid flood
                    end
                end
            end
            task.wait(0.3)
        end
    end)
end

local function stopTrinketLoop()
    trinketState.running = false
end

-- === Noclip & Speed (igual ao seu comportamento anterior) ===
local noclipConnection = nil
local speedConnection = nil

local function toggleNoclip(state)
    noclipEnabled = state
    if state then
        if noclipConnection then noclipConnection:Disconnect() end
        noclipConnection = RunService.Stepped:Connect(function()
            local refs = getPlayerRefs()
            if refs and refs.char then
                for _, part in pairs(refs.char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
        Rayfield:Notify({Title="Noclip", Content="Ativado", Duration=2})
    else
        if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
        local refs = getPlayerRefs()
        if refs and refs.char then
            for _, part in pairs(refs.char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
        Rayfield:Notify({Title="Noclip", Content="Desativado", Duration=2})
    end
end

local function toggleSpeed(state)
    speedEnabled = state
    if state then
        if speedConnection then speedConnection:Disconnect() end
        speedConnection = RunService.Heartbeat:Connect(function()
            local refs = getPlayerRefs()
            if refs and refs.humanoid then
                refs.humanoid.WalkSpeed = currentSpeed
                refs.humanoid.Sit = false
                refs.humanoid.PlatformStand = false
            end
        end)
        Rayfield:Notify({Title="Speed", Content="Ativado: "..currentSpeed, Duration=2})
    else
        if speedConnection then speedConnection:Disconnect(); speedConnection = nil end
        local refs = getPlayerRefs()
        if refs and refs.humanoid then refs.humanoid.WalkSpeed = 16 end
        Rayfield:Notify({Title="Speed", Content="Desativado", Duration=2})
    end
end

-- === UI: organizar conforme você pediu ===

-- Auto Farm Mob (Slayer / Oni / Desbugar)
local FarmTab = Window:CreateTab("AUTO FARM MOB", 4483362458)

-- Slayer (mantive o comportamento do seu bloco – liga farmEnabled global)
FarmTab:CreateToggle({
    Name = "AUTO FARM SLAYER",
    CurrentValue = farmEnabled,
    Callback = function(state)
        farmEnabled = state
        if farmEnabled then
            ensureRemotes()
            equipSword() -- equipa ao ativar
            startFarmLoop()
            Rayfield:Notify({Title="AutoFarm Slayer", Content="Ativado", Duration=2})
        else
            stopFarmLoop()
            Rayfield:Notify({Title="AutoFarm Slayer", Content="Desativado", Duration=2})
        end
    end
})

-- Oni
FarmTab:CreateToggle({
    Name = "AUTO FARM ONI",
    CurrentValue = oniEnabled,
    Callback = function(state)
        oniEnabled = state
        if oniEnabled then
            ensureRemotes()
            equipSword()
            startOniLoop()
            Rayfield:Notify({Title="AutoFarm Oni", Content="Ativado", Duration=2})
        else
            stopOniLoop()
            Rayfield:Notify({Title="AutoFarm Oni", Content="Desativado", Duration=2})
        end
    end
})

-- Desbugar (TP 5 studs above current slayer target)
FarmTab:CreateButton({
    Name = "DESBUGAR (TP 5 studs acima do NPC)",
    Callback = function()
        -- tenta achar o alvo atual (prioriza map slayers)
        local t = findTargetByName("GenericSlayer")
        if not t then t = findTargetByName("GenericOni") end
        if t and t:FindFirstChild("HumanoidRootPart") then
            teleportToTargetPart(t.HumanoidRootPart, tpAboveOffset)
            Rayfield:Notify({Title="Desbugar", Content="Teleported acima do NPC", Duration=2})
        else
            Rayfield:Notify({Title="Desbugar", Content="NPC não encontrado", Duration=2})
        end
    end
})

-- Auto Farm Boss (Gyutaro / Kaigaku)
local BossTab = Window:CreateTab("AUTO FARM BOSS", 4483362458)

BossTab:CreateToggle({
    Name = "AUTO FARM GYUTARO",
    CurrentValue = gyuEnabled,
    Callback = function(state)
        gyuEnabled = state
        if gyuEnabled then
            ensureRemotes()
            equipSword()
            startGyutaroLoop()
            Rayfield:Notify({Title="AutoFarm Gyutaro", Content="Ativado", Duration=2})
        else
            stopGyutaroLoop()
            Rayfield:Notify({Title="AutoFarm Gyutaro", Content="Desativado", Duration=2})
        end
    end
})

BossTab:CreateToggle({
    Name = "AUTO FARM KAIGAKU",
    CurrentValue = kaiEnabled,
    Callback = function(state)
        kaiEnabled = state
        if kaiEnabled then
            ensureRemotes()
            equipSword()
            startKaigakuLoop()
            Rayfield:Notify({Title="AutoFarm Kaigaku", Content="Ativado", Duration=2})
        else
            stopKaigakuLoop()
            Rayfield:Notify({Title="AutoFarm Kaigaku", Content="Desativado", Duration=2})
        end
    end
})

-- Adiciona botão TP Blue Demon no tab Boss (coord que você pediu antes)
BossTab:CreateButton({
    Name = "TP Blue Demon",
    Callback = function()
        local refs = getPlayerRefs()
        if refs and refs.hrp then
            refs.hrp.CFrame = CFrame.new(1654.9093, 1133.05872, -1268.4397, -0.364888608, 4.92119696e-08, -0.931051195, 2.01689208e-08, 1, 4.49519426e-08, 0.931051195, -2.37584663e-09, -0.364888608)
            Rayfield:Notify({Title="Teleport", Content="TP Blue Demon", Duration=2})
        end
    end
})

-- Auto Farm Trinkets tab
local TrinketTab = Window:CreateTab("AUTO FARM TRINKETS", 4483362458)

TrinketTab:CreateToggle({
    Name = "Ativar Auto Farm Trinkets",
    CurrentValue = false,
    Callback = function(state)
        if state then
            startTrinketLoop()
            Rayfield:Notify({Title="Trinkets", Content="Ativado", Duration=2})
        else
            stopTrinketLoop()
            Rayfield:Notify({Title="Trinkets", Content="Desativado", Duration=2})
        end
    end
})

-- Teleports: Respiração tab (adiciona os TPs que você pediu)
local RespTab = Window:CreateTab("TP RESPIRAÇÃO", 4483362458)
local function addRespBtn(name, cf) RespTab:CreateButton({Name = name, Callback = function() local refs = getPlayerRefs(); if refs then refs.hrp.CFrame = cf end end}) end

addRespBtn("Respiração do Fogo", CFrame.new(1503.54578,1236.19189,-352.901184,0.289705396,-2.31545383e-09,0.957115889,2.70456613e-09,1,1.60056535e-09,-0.957115889,2.12489071e-09,0.289705396))
addRespBtn("Respiração do Amor", CFrame.new(1179.53027,1077.53284,-1110.29541,0.358261943,1.15730721e-07,-0.933621109,-1.15011387e-08,1,1.19545604e-07,0.933621109,-3.20909344e-08,0.358261943))
addRespBtn("Respiração da Serpente", CFrame.new(994.2005,1070.27002,-1147.62012,-0.984538198,1.6619105e-09,0.175170153,7.04086955e-10,1,-5.53010882e-09,-0.175170153,-5.32126831e-09,-0.984538198))
addRespBtn("Respiração da Pedra", CFrame.new(-1715.5415,1039.72217,-1371.6084))
addRespBtn("Respiração da lua", CFrame.new(1821.46387, 1116.07239, -5959.49707, -0.867134869, -2.52667345e-08, -0.498073369, 8.882723e-09, 1, -6.61935644e-08, 0.498073369, -6.18229947e-08, -0.867134869))

-- Teleports normal tab (vários TPs)
local TpTab = Window:CreateTab("TELEPORTE", 4483362458)
local function addTpBtn(tab, name, cf) tab:CreateButton({Name = name, Callback = function() local refs = getPlayerRefs(); if refs then refs.hrp.CFrame = cf end end}) end

addTpBtn(TpTab, "Vila Okuiya", CFrame.new(-3144.50903,703.953979,-1152.58362,0.0220944081,-1.24713608e-07,0.999755859,-4.62866456e-09,1,1.24846352e-07,-0.999755859,-7.38594119e-09,0.0220944081))
addTpBtn(TpTab, "Vila de Kamakura", CFrame.new(-2141.30225,1161.67212,-1697.14087,-0.408639222,1.64608718e-08,0.912696004,7.06537762e-08,1,1.35982106e-08,-0.912696004,7.00421836e-08,-0.408639222))
addTpBtn(TpTab, "Vila de Hayakawa", CFrame.new(454.556335,755.253296,-1984.2356,0.996727884,-6.91496922e-08,-0.0808305144,6.72240787e-08,1,-2.65441287e-08,0.0808305144,2.10235171e-08,0.996727884))
addTpBtn(TpTab, "Destino do Entretenimento", CFrame.new(-6300.48193,747.194763,-6382.80127,-0.136492968,-7.21723126e-08,0.990641057,-1.67586602e-08,1,7.05450987e-08,-0.990641057,-6.9729067e-09,-0.136492968))
addTpBtn(TpTab, "Slayer Coops", CFrame.new(-1991.42065,871.603027,-6507.77393,-0.0869276747,6.60826913e-08,-0.996214628,2.56487152e-08,1,6.40957367e-08,0.996214628,-1.99799324e-08,-0.0869276747))
addTpBtn(TpTab, "Comida (antigo Treinar Respiração)", CFrame.new(-2247.56372,1176.92786,-1516.83728,-0.856747448,2.16664393e-08,-0.515736163,-4.79127571e-10,1,4.28066365e-08,0.515736163,3.69215805e-08,-0.856747448))
addTpBtn(TpTab, "Black Merchant Local 1", CFrame.new(-3386.9707,703.953857,-1073.89648))
addTpBtn(TpTab, "Black Merchant Local 2", CFrame.new(-3392.8833,706.103149,-1597.4502))

-- Extras: Noclip + Speed tab
local ExtraTab = Window:CreateTab("EXTRAS", 4483362458)
ExtraTab:CreateToggle({ Name = "Noclip", CurrentValue = false, Callback = function(v) toggleNoclip(v) end })
ExtraTab:CreateToggle({ Name = "Speed", CurrentValue = false, Callback = function(v) toggleSpeed(v) end })
ExtraTab:CreateSlider({ Name = "Velocidade", Range = {16, 500}, Increment = 5, CurrentValue = currentSpeed, Callback = function(v) currentSpeed = v end })

-- Info
local InfoTab = Window:CreateTab("INFO", 4483362458)
InfoTab:CreateParagraph({ Title = "Carregado", Content = "AutoFarm Slayer/Oni/Boss (mesma lógica), Trinkets, TPs, Noclip, Speed." })

-- Reapply loops on respawn
player.CharacterAdded:Connect(function()
    wait(1)
    if noclipEnabled then toggleNoclip(true) end
    if speedEnabled then toggleSpeed(true) end
    if farmEnabled then startFarmLoop() end
    if oniEnabled then startOniLoop() end
    if gyuEnabled then startGyutaroLoop() end
    if kaiEnabled then startKaigakuLoop() end
    if trinketState.running then startTrinketLoop() end
end)

Rayfield:Notify({Title="RC HUB", Content="Carregado — farms prontos", Duration=3})
