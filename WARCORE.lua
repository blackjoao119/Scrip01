--[[
    ╔════════════════════════════════════════════════════════════╗
    ║       PROJECT: WARCORE v1.4.0 (ESP OPTIMIZED + FULL)       ║
    ║       STUDIO: WARCORE LABS                                 ║
    ║------------------------------------------------------------║
    ║       LEAD DEVELOPER: ENZO CAVALCANTI                      ║
    ║       MOD: RAIOS-X AVANÇADO + DRAWING API + HUD SEPARADO   ║
    ╚════════════════════════════════════════════════════════════╝
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local Player = Players.LocalPlayer
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

--// =============================================
--// CONFIGURAÇÃO GLOBAL
--// =============================================
getgenv().SystemConfig = {
    -- Combate
    MiraAtiva = false,
    FovRadius = 500,
    Smoothness = 0.35,
    TeamCheck = true,

    -- Visual / Raio-X
    HighlightEnabled = false,
    HlDepthMode = "AlwaysOnTop",
    HlFillTransparency = 0.5,
    HlEnemyColor = Color3.fromRGB(255, 0, 0),
    HlAllyColor = Color3.fromRGB(0, 255, 0),
    WallCheck = false,
    WallColor = Color3.fromRGB(255, 165, 0),
    DotEnabled = false,
    DotType = "Circle",
    DotSize = 6,
    LineEnabled = false,
    LineColor = Color3.fromRGB(0, 255, 255),
    LineThickness = 1.5,
    LineTeamColor = false,
    MaxDistance = 0,

    -- Micro-HUD (cada um com o seu próprio botão)
    MicroHpEnabled = false,      -- barra de vida
    MicroDistEnabled = false,    -- nome + distância
    MicroTextSize = 8,
    MicroWidth = 35,
    DistColor = Color3.fromRGB(255, 255, 255),

    -- Iluminação
    FullBright = false,
    NoShadows = false,
    ClarezaMod = false,

    -- Monitor
    ShowFPS = false,
    ShowPlayers = false,

    -- Movimento
    FlyEnabled = false,
    FlySpeed = 50,
    FlyInfinite = false,
    SpeedEnabled = false,
    SpeedValue = 50,
    JumpEnabled = false,
    JumpPower = 100,
    InfiniteJump = false,
}

--// =============================================
--// VARIÁVEIS AUXILIARES
--// =============================================
local NoClipAtivo = false
local isTeleportOpen = false
local NoClipConnection = nil
local flyVelocity = nil
local flyConnection = nil
local OriginalWalkSpeed = 16
local OriginalJumpPower = 50
local FullBrightApplied = false
local ClarezaApplied = false

local OriginalSettings = {
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    GlobalShadows = Lighting.GlobalShadows,
    Exposure = Lighting.ExposureCompensation,
}

--// =============================================
--// VARIÁVEIS DO SISTEMA ESP
--// =============================================
local ESPData = {}
local isFFA = false

--// =============================================
--// FUNÇÃO TEAM CHECK
--// =============================================
local function IsFFA()
    if Player.Team == nil then return true end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Team ~= nil then return false end
    end
    return true
end

local function IsAlly(player)
    if isFFA then return false end
    return player.Team == Player.Team
end

--// =============================================
--// FUNÇÕES AUXILIARES
--// =============================================
local function getTarget()
    local closest, shortest = nil, getgenv().SystemConfig.FovRadius
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local head = p.Character:FindFirstChild("Head")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                local isTeam = (p.Team == Player.Team and Player.Team ~= nil)
                if not (isTeam and getgenv().SystemConfig.TeamCheck) then
                    local pos, vis = Camera:WorldToViewportPoint(head.Position)
                    if vis and pos.Z > 0 then
                        local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if dist < shortest then
                            shortest = dist
                            closest = head
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function IsBehindWall(targetPart)
    local rayParams = RaycastParams.new()
    local ignore = {targetPart.Parent}
    if Player.Character then
        table.insert(ignore, Player.Character)
    end
    rayParams.FilterDescendantsInstances = ignore
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local result = workspace:Raycast(Camera.CFrame.Position, (targetPart.Position - Camera.CFrame.Position), rayParams)
    return result ~= nil
end

local function getDepthMode()
    local mode = getgenv().SystemConfig.HlDepthMode
    if mode == "AlwaysOnTop" then
        return Enum.HighlightDepthMode.AlwaysOnTop
    elseif mode == "Occluded" then
        return Enum.HighlightDepthMode.Occluded
    else
        return Enum.HighlightDepthMode.AlwaysOnTop
    end
end

--// =============================================
--// INTERFACE: TAGS DE MONITOR + BOTÃO FLUTUANTE
--// =============================================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

-- Tags (FPS / Players)
local TagContainer = Instance.new("Frame", ScreenGui)
TagContainer.Size = UDim2.new(0, 90, 0, 50)
TagContainer.Position = UDim2.new(0, 5, 0, 45)
TagContainer.BackgroundTransparency = 1
local UIList = Instance.new("UIListLayout", TagContainer)
UIList.Padding = UDim.new(0, 3)

local function CreateTag(color)
    local f = Instance.new("Frame", TagContainer)
    f.Size = UDim2.new(0, 90, 0, 18)
    f.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
    f.BackgroundTransparency = 0.2
    f.Visible = false
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 5)
    local stroke = Instance.new("UIStroke", f)
    stroke.Thickness = 1
    stroke.Color = color
    stroke.Transparency = 0.4
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(255, 255, 255)
    l.TextSize = 10
    l.Font = Enum.Font.GothamBold
    return f, l
end

local fpsF, fpsL = CreateTag(Color3.fromRGB(0, 240, 255))
local countF, countL = CreateTag(Color3.fromRGB(255, 0, 120))

-- Botão flutuante da mira
local FloatingBtn = Instance.new("TextButton", ScreenGui)
FloatingBtn.Visible = false
FloatingBtn.Size = UDim2.new(0, 70, 0, 38)
FloatingBtn.Position = UDim2.new(0.1, 0, 0.5, 0)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(11, 14, 24)
FloatingBtn.Text = "⚡ OFF"
FloatingBtn.TextColor3 = Color3.fromRGB(130, 140, 160)
FloatingBtn.Font = Enum.Font.GothamBold
FloatingBtn.TextSize = 13
FloatingBtn.Draggable = true
FloatingBtn.Active = true

local BtnCorner = Instance.new("UICorner", FloatingBtn)
BtnCorner.CornerRadius = UDim.new(0, 10)
local BtnStroke = Instance.new("UIStroke", FloatingBtn)
BtnStroke.Thickness = 2
BtnStroke.Color = Color3.fromRGB(35, 42, 65)

local function UpdateBtnVisual(active)
    if active then
        TweenService:Create(FloatingBtn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(16, 28, 48)}):Play()
        TweenService:Create(BtnStroke, TweenInfo.new(0.25), {Color = Color3.fromRGB(0, 240, 255)}):Play()
        FloatingBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        FloatingBtn.Text = "⚡ ON"
    else
        TweenService:Create(FloatingBtn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(11, 14, 24)}):Play()
        TweenService:Create(BtnStroke, TweenInfo.new(0.25), {Color = Color3.fromRGB(35, 42, 65)}):Play()
        FloatingBtn.TextColor3 = Color3.fromRGB(130, 140, 160)
        FloatingBtn.Text = "⚡ OFF"
    end
end

FloatingBtn.MouseButton1Click:Connect(function()
    getgenv().SystemConfig.MiraAtiva = not getgenv().SystemConfig.MiraAtiva
    UpdateBtnVisual(getgenv().SystemConfig.MiraAtiva)
end)

--// =============================================
--// CRIAÇÃO/REMOÇÃO DOS OBJETOS ESP
--// =============================================
local CleanupESP

local function CreateESPObjects(player)
    if ESPData[player] then return end

    local data = {
        char = nil,
        highlight = nil,
        line = Drawing.new("Line"),
        dot = nil,
        hud = nil,
        alive = false,
        connections = {}
    }

    data.line.Visible = false
    data.line.Thickness = getgenv().SystemConfig.LineThickness
    data.line.Transparency = 1

    local dotType = getgenv().SystemConfig.DotType
    if dotType == "Circle" then
        data.dot = Drawing.new("Circle")
    else
        data.dot = Drawing.new("Square")
    end
    data.dot.Thickness = 1
    data.dot.Filled = true
    data.dot.Visible = false
    data.dot.Size = getgenv().SystemConfig.DotSize
    data.dot.Color = Color3.fromRGB(255, 0, 0)

    local hl = Instance.new("Highlight")
    hl.Name = "System_HL"
    hl.Enabled = false
    hl.FillTransparency = getgenv().SystemConfig.HlFillTransparency
    hl.OutlineTransparency = 0
    pcall(function()
        hl.DepthMode = getDepthMode()
    end)
    data.highlight = hl

    local conns = {}
    local charAddedConn = player.CharacterAdded:Connect(function(char)
        data.char = char
        data.alive = true
        data.hud = nil
        hl.Parent = char
        hl.Adornee = char
    end)
    table.insert(conns, charAddedConn)

    local charRemovingConn = player.CharacterRemoving:Connect(function()
        data.char = nil
        data.alive = false
        data.hud = nil
        hl.Parent = nil
        data.line.Visible = false
        data.dot.Visible = false
    end)
    table.insert(conns, charRemovingConn)

    local removingConn = player.AncestryChanged:Connect(function()
        if not player.Parent then
            CleanupESP(player)
        end
    end)
    table.insert(conns, removingConn)

    data.connections = conns
    ESPData[player] = data

    if player.Character then
        data.char = player.Character
        data.alive = true
        hl.Parent = player.Character
        hl.Adornee = player.Character
    end
end

function CleanupESP(player)
    local data = ESPData[player]
    if not data then return end

    for _, conn in ipairs(data.connections) do
        conn:Disconnect()
    end
    if data.line then data.line:Remove() end
    if data.dot then data.dot:Remove() end
    if data.highlight then data.highlight:Destroy() end
    ESPData[player] = nil
end

--// =============================================
--// MICRO-HUD (VIDA E DISTÂNCIA INDEPENDENTES)
--// =============================================
local function UpdateMicroHUD(data, char, isAlly, distance)
    local config = getgenv().SystemConfig
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")

    if not hum or not root or hum.Health <= 0 or not (config.MicroHpEnabled or config.MicroDistEnabled) then
        if data.hud then data.hud.Enabled = false end
        return
    end

    local billboard = data.hud
    if not billboard or billboard.Parent ~= root then
        billboard = root:FindFirstChild("Aguia_MicroHUD")
        if not billboard then
            billboard = Instance.new("BillboardGui")
            billboard.Name = "Aguia_MicroHUD"
            billboard.AlwaysOnTop = true
            billboard.ExtentsOffset = Vector3.new(0, -3.2, 0)

            local bgBar = Instance.new("Frame", billboard)
            bgBar.Name = "BackgroundBar"
            bgBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            bgBar.BorderSizePixel = 0

            local mainBar = Instance.new("Frame", bgBar)
            mainBar.Name = "MainBar"
            mainBar.Size = UDim2.new(1, 0, 1, 0)
            mainBar.BorderSizePixel = 0

            local label = Instance.new("TextLabel", billboard)
            label.Name = "DistLabel"
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamBold
            label.TextStrokeTransparency = 0.4
            label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            label.TextXAlignment = Enum.TextXAlignment.Center
        end
        data.hud = billboard
    end

    local width = math.max(config.MicroWidth, 80)
    billboard.Size = UDim2.new(0, width, 0, config.MicroTextSize + 12)

    local bgBar = billboard:FindFirstChild("BackgroundBar")
    if bgBar then
        bgBar.Position = UDim2.new(0, 0, 1, -9)
        bgBar.Size = UDim2.new(1, 0, 0, 4)
        bgBar.Visible = config.MicroHpEnabled
        if config.MicroHpEnabled then
            local ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            bgBar.MainBar.Size = UDim2.new(ratio, 0, 1, 0)
            bgBar.MainBar.BackgroundColor3 = isAlly and config.HlAllyColor or config.HlEnemyColor
        end
    end

    local label = billboard:FindFirstChild("DistLabel")
    if label then
        label.Size = UDim2.new(1, 0, 0, config.MicroTextSize + 4)
        label.Position = UDim2.new(0, 0, 0, 1)
        label.TextSize = config.MicroTextSize
        label.Visible = config.MicroDistEnabled
        if config.MicroDistEnabled then
            label.Text = char.Name .. " " .. math.floor(distance) .. "m"
            label.TextColor3 = config.DistColor
        end
    end

    billboard.Enabled = true
end

--// =============================================
--// ATUALIZAÇÃO DO ESP (CHAMADA NO RENDERSTEPPED)
--// =============================================
local function UpdateESP(player)
    local data = ESPData[player]
    if not data then return end

    local function hide()
        data.line.Visible = false
        data.dot.Visible = false
        if data.highlight then data.highlight.Enabled = false end
        if data.hud then data.hud.Enabled = false end
    end

    local char = data.char
    if not char or not data.alive then hide() return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then hide() return end

    local head = char:FindFirstChild("Head")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not head or not root then hide() return end

    local config = getgenv().SystemConfig
    local hlEnabled = config.HighlightEnabled
    local dotEnabled = config.DotEnabled
    local lineEnabled = config.LineEnabled

    local distance = Player:DistanceFromCharacter(root.Position)
    local maxDist = config.MaxDistance
    if maxDist and maxDist > 0 and distance > maxDist then hide() return end

    local behind = false
    if dotEnabled or (config.WallCheck and hlEnabled) then
        behind = IsBehindWall(head)
    end
    local isAlly = IsAlly(player)

    -- HIGHLIGHT
    if data.highlight then
        local hl = data.highlight
        hl.Enabled = hlEnabled
        if hlEnabled then
            local fillColor, outlineColor
            local fillTransp = config.HlFillTransparency
            if isAlly then
                fillColor = config.HlAllyColor
                outlineColor = config.HlAllyColor
            else
                if config.WallCheck and behind then
                    fillColor = config.WallColor
                    outlineColor = config.WallColor
                    fillTransp = 0.3
                else
                    fillColor = config.HlEnemyColor
                    outlineColor = config.HlEnemyColor
                end
            end
            hl.FillColor = fillColor
            hl.OutlineColor = outlineColor
            hl.FillTransparency = fillTransp
            hl.OutlineTransparency = 0
            pcall(function()
                hl.DepthMode = getDepthMode()
            end)
            hl.Adornee = char
        end
    end

    -- DOT
    if dotEnabled then
        local dotPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
        if onScreen and dotPos.Z > 0 then
            data.dot.Visible = true
            data.dot.Position = Vector2.new(dotPos.X, dotPos.Y)
            if isAlly then
                data.dot.Color = config.HlAllyColor
            else
                data.dot.Color = behind and config.WallColor or config.HlEnemyColor
            end
            data.dot.Size = config.DotSize
        else
            data.dot.Visible = false
        end
    else
        data.dot.Visible = false
    end

    -- TRACER (linha pura, sem distância/atrelada ao HUD)
    if lineEnabled and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local camPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local enemyPos, onScreen2 = Camera:WorldToViewportPoint(root.Position)

        if onScreen2 and enemyPos.Z > 0 then
            data.line.Visible = true
            data.line.From = camPos
            data.line.To = Vector2.new(enemyPos.X, enemyPos.Y)
            if config.LineTeamColor then
                data.line.Color = isAlly and config.HlAllyColor or config.HlEnemyColor
            else
                data.line.Color = config.LineColor
            end
            data.line.Thickness = config.LineThickness
            data.line.Transparency = 1
        else
            data.line.Visible = false
        end
    else
        data.line.Visible = false
    end

    -- MICRO-HUD (cada elemento com o seu próprio controle)
    UpdateMicroHUD(data, char, isAlly, distance)
end

--// =============================================
--// INICIALIZAÇÃO DOS JOGADORES
--// =============================================
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= Player then CreateESPObjects(p) end
end

Players.PlayerAdded:Connect(function(p)
    if p ~= Player then CreateESPObjects(p) end
end)
Players.PlayerRemoving:Connect(CleanupESP)

--// =============================================
--// INTERFACE RAYFIELD
--// =============================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "👑 WARCORE v1.4.0",
    LoadingTitle = "WARCORE está iniciando...",
    LoadingSubtitle = "WARCORE LABS PROTOCOL",
    ConfigurationSaving = { Enabled = false },
    Theme = "Custom"
})
Window.BackgroundColor = Color3.fromRGB(11, 13, 23)

local CombatTab = Window:CreateTab("🔫 Combate", 10734950020)
local VisualTab = Window:CreateTab("👁️ Visual", 10734951477)
local RxTab = Window:CreateTab("🛸 Opções RX", 10734951477)
local LightTab = Window:CreateTab("💡 Iluminação", 10734951477)
local MovimentTab = Window:CreateTab("🧱 Movimento", 4483362458)
local TeleportTab = Window:CreateTab("📍 Teleporte", 10734951477)
local StatusTab = Window:CreateTab("📊 Monitor", 4483362458)

--// ----- COMBATE -----
CombatTab:CreateToggle({
    Name = "Ativar Mira Assistida",
    CurrentValue = false,
    Callback = function(v)
        getgenv().SystemConfig.MiraAtiva = v
        FloatingBtn.Visible = v
        UpdateBtnVisual(v)
    end
})
CombatTab:CreateSlider({
    Name = "Suavidade",
    Range = {0.1, 1},
    Increment = 0.05,
    CurrentValue = 0.35,
    Callback = function(v) getgenv().SystemConfig.Smoothness = v end
})

--// ----- VISUAL -----
VisualTab:CreateSection("Elementos de Rastreamento")
VisualTab:CreateToggle({
    Name = "Raio-X (Highlight)",
    CurrentValue = false,
    Callback = function(v) getgenv().SystemConfig.HighlightEnabled = v end
})
VisualTab:CreateToggle({
    Name = "Ponto na Cabeça (Drawing)",
    CurrentValue = false,
    Callback = function(v) getgenv().SystemConfig.DotEnabled = v end
})
VisualTab:CreateToggle({
    Name = "Linha de Mira (Tracer)",
    CurrentValue = false,
    Callback = function(v) getgenv().SystemConfig.LineEnabled = v end
})

VisualTab:CreateSection("Distância Máxima")
VisualTab:CreateSlider({
    Name = "Distância Máxima (0 = ilimitado)",
    Range = {0, 5000},
    Increment = 50,
    CurrentValue = 0,
    Callback = function(v) getgenv().SystemConfig.MaxDistance = v end
})

VisualTab:CreateSection("Micro-HUD (cada um com o seu botão)")
VisualTab:CreateToggle({
    Name = "Micro-HUD: Vida (barra)",
    CurrentValue = false,
    Callback = function(v) getgenv().SystemConfig.MicroHpEnabled = v end
})
VisualTab:CreateToggle({
    Name = "Micro-HUD: Nome + Distância",
    CurrentValue = false,
    Callback = function(v) getgenv().SystemConfig.MicroDistEnabled = v end
})

VisualTab:CreateSection("Tamanhos")
VisualTab:CreateSlider({
    Name = "Texto (Distância)",
    Range = {6, 24},
    Increment = 1,
    CurrentValue = 8,
    Callback = function(v) getgenv().SystemConfig.MicroTextSize = v end
})
VisualTab:CreateSlider({
    Name = "Largura Barra de Vida",
    Range = {20, 100},
    Increment = 5,
    CurrentValue = 35,
    Callback = function(v) getgenv().SystemConfig.MicroWidth = v end
})
VisualTab:CreateSlider({
    Name = "Tamanho do Ponto",
    Range = {3, 15},
    Increment = 1,
    CurrentValue = 6,
    Callback = function(v) getgenv().SystemConfig.DotSize = v end
})

--// ----- RX -----
RxTab:CreateSection("Configurações Avançadas")
RxTab:CreateDropdown({
    Name = "Modo de Visibilidade",
    Options = {"Ver através", "Ocultar atrás"},
    CurrentOption = "Ver através",
    MultipleOptions = false,
    Callback = function(Option)
        getgenv().SystemConfig.HlDepthMode = (Option == "Ver através") and "AlwaysOnTop" or "Occluded"
    end
})
RxTab:CreateSlider({
    Name = "Transparência do Brilho",
    Range = {0, 1},
    Increment = 0.05,
    CurrentValue = 0.5,
    Callback = function(v) getgenv().SystemConfig.HlFillTransparency = v end
})
RxTab:CreateColorPicker({
    Name = "Cor Inimigos",
    Color = Color3.fromRGB(255, 0, 0),
    Callback = function(v) getgenv().SystemConfig.HlEnemyColor = v end
})
RxTab:CreateColorPicker({
    Name = "Cor Aliados",
    Color = Color3.fromRGB(0, 255, 0),
    Callback = function(v) getgenv().SystemConfig.HlAllyColor = v end
})
RxTab:CreateColorPicker({
    Name = "Cor Atrás da Parede",
    Color = Color3.fromRGB(255, 165, 0),
    Callback = function(v) getgenv().SystemConfig.WallColor = v end
})
RxTab:CreateToggle({
    Name = "WallCheck (mudar cor se atrás)",
    CurrentValue = false,
    Callback = function(v) getgenv().SystemConfig.WallCheck = v end
})
RxTab:CreateSection("Tracer e Ponto")
RxTab:CreateColorPicker({
    Name = "Cor da Linha (global)",
    Color = Color3.fromRGB(0, 255, 255),
    Callback = function(v) getgenv().SystemConfig.LineColor = v end
})
RxTab:CreateSlider({
    Name = "Espessura da Linha",
    Range = {0.5, 5},
    Increment = 0.5,
    CurrentValue = 1.5,
    Callback = function(v) getgenv().SystemConfig.LineThickness = v end
})
RxTab:CreateToggle({
    Name = "Linha com Cor do Time",
    CurrentValue = false,
    Callback = function(v) getgenv().SystemConfig.LineTeamColor = v end
})
RxTab:CreateColorPicker({
    Name = "Cor da Distância",
    Color = Color3.fromRGB(255, 255, 255),
    Callback = function(v) getgenv().SystemConfig.DistColor = v end
})
RxTab:CreateDropdown({
    Name = "Forma do Ponto",
    Options = {"Círculo", "Quadrado"},
    CurrentOption = "Círculo",
    MultipleOptions = false,
    Callback = function(Option)
        local newType = (Option == "Círculo") and "Circle" or "Square"
        getgenv().SystemConfig.DotType = newType
        for _, data in pairs(ESPData) do
            if data.dot then
                local old = data.dot
                old:Remove()
                if newType == "Circle" then
                    data.dot = Drawing.new("Circle")
                else
                    data.dot = Drawing.new("Square")
                end
                data.dot.Thickness = 1
                data.dot.Filled = true
                data.dot.Visible = false
                data.dot.Size = getgenv().SystemConfig.DotSize
                data.dot.Color = Color3.fromRGB(255, 0, 0)
            end
        end
    end
})

--// ----- ILUMINAÇÃO -----
LightTab:CreateToggle({
    Name = "Filtro FullBright Ambiência",
    CurrentValue = false,
    Callback = function(v)
        getgenv().SystemConfig.FullBright = v
        if not v then
            Lighting.Ambient = OriginalSettings.Ambient
            Lighting.OutdoorAmbient = OriginalSettings.OutdoorAmbient
            Lighting.ClockTime = OriginalSettings.ClockTime
        end
    end
})
LightTab:CreateToggle({
    Name = "Clareza Técnico Aprimorada",
    CurrentValue = false,
    Callback = function(v) getgenv().SystemConfig.ClarezaMod = v end
})
LightTab:CreateToggle({
    Name = "Otimizar: Remover Sombras",
    CurrentValue = false,
    Callback = function(v)
        getgenv().SystemConfig.NoShadows = v
        if v then
            Lighting.GlobalShadows = false
        else
            Lighting.GlobalShadows = OriginalSettings.GlobalShadows
        end
    end
})

--// =============================================
--// ABA MOVIMENTO (Fly, NoClip, Speed, Pulo)
--// =============================================
local function stopFly()
    if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
    if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
    getgenv().SystemConfig.FlyEnabled = false
end

local function startFly()
    local char = Player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
        hum.AutoRotate = true
    end

    if flyVelocity then flyVelocity:Destroy() end
    flyVelocity = Instance.new("BodyVelocity")
    flyVelocity.Name = "FlyVelocity"
    flyVelocity.MaxForce = Vector3.new(400000, 400000, 400000)
    flyVelocity.Parent = hrp
    getgenv().SystemConfig.FlyEnabled = true

    if flyConnection then flyConnection:Disconnect() end
    flyConnection = RunService.RenderStepped:Connect(function()
        if not getgenv().SystemConfig.FlyEnabled then stopFly(); return end
        local chr = Player.Character
        if not chr then return end
        local root = chr:FindFirstChild("HumanoidRootPart")
        local h = chr:FindFirstChildOfClass("Humanoid")
        if not root or not h then return end
        if not flyVelocity then return end

        local speed = getgenv().SystemConfig.FlySpeed
        local targetVel = Vector3.zero

        if getgenv().SystemConfig.FlyInfinite then
            targetVel = Camera.CFrame.LookVector * speed
        else
            local moveDir = h.MoveDirection
            if moveDir.Magnitude > 0 then
                local flatLook = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
                if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
                local flatCamCFrame = CFrame.lookAt(Vector3.zero, flatLook)
                local rawInput = flatCamCFrame:VectorToObjectSpace(moveDir)
                targetVel = Camera.CFrame:VectorToWorldSpace(rawInput) * speed
            else
                targetVel = Vector3.zero
            end
        end
        flyVelocity.Velocity = targetVel
    end)
end

MovimentTab:CreateSection("🕊️ Fly")
MovimentTab:CreateToggle({
    Name = "Ativar Fly",
    CurrentValue = false,
    Callback = function(v) if v then startFly() else stopFly() end end
})
MovimentTab:CreateToggle({
    Name = "Modo Infinito (câmera)",
    CurrentValue = false,
    Callback = function(v) getgenv().SystemConfig.FlyInfinite = v end
})
MovimentTab:CreateSlider({
    Name = "Velocidade do Fly",
    Range = {1, 500},
    Increment = 1,
    CurrentValue = 50,
    Callback = function(v) getgenv().SystemConfig.FlySpeed = v end
})

MovimentTab:CreateSection("🧱 No-Clip")
MovimentTab:CreateToggle({
    Name = "Ativar Matriz No-Clip",
    CurrentValue = false,
    Callback = function(v)
        NoClipAtivo = v
        if NoClipAtivo then
            NoClipConnection = RunService.Stepped:Connect(function()
                local char = Player.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end)
        else
            if NoClipConnection then
                NoClipConnection:Disconnect()
                NoClipConnection = nil
            end
            local char = Player.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end
        end
    end
})

MovimentTab:CreateSection("⚡ Velocidade de Caminhada")
MovimentTab:CreateToggle({
    Name = "Ativar Speed Hack",
    CurrentValue = false,
    Callback = function(v)
        getgenv().SystemConfig.SpeedEnabled = v
        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v and getgenv().SystemConfig.SpeedValue or OriginalWalkSpeed end
    end
})
MovimentTab:CreateSlider({
    Name = "Velocidade",
    Range = {16, 200},
    Increment = 1,
    CurrentValue = 50,
    Callback = function(v)
        getgenv().SystemConfig.SpeedValue = v
        if getgenv().SystemConfig.SpeedEnabled then
            local char = Player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = v end
        end
    end
})

MovimentTab:CreateSection("🦘 Super Pulo")
MovimentTab:CreateToggle({
    Name = "Ativar Super Pulo",
    CurrentValue = false,
    Callback = function(v)
        getgenv().SystemConfig.JumpEnabled = v
        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = v and getgenv().SystemConfig.JumpPower or OriginalJumpPower end
    end
})
MovimentTab:CreateSlider({
    Name = "Altura do Pulo",
    Range = {50, 300},
    Increment = 5,
    CurrentValue = 100,
    Callback = function(v)
        getgenv().SystemConfig.JumpPower = v
        if getgenv().SystemConfig.JumpEnabled then
            local char = Player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.JumpPower = v end
        end
    end
})

MovimentTab:CreateSection("🔄 Pulo Infinito")
MovimentTab:CreateToggle({
    Name = "Pulo Infinito (pular no ar)",
    CurrentValue = false,
    Callback = function(v) getgenv().SystemConfig.InfiniteJump = v end
})

--// =============================================
--// SISTEMA DE TELEPORTE (com locais fixos)
--// =============================================
local tpGui = Instance.new("ScreenGui", CoreGui)
tpGui.Name = "WarcoreTeleporte"
tpGui.Enabled = true
tpGui.ResetOnSpawn = false
tpGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function hover(btn, baseColor, hoverColor, textHover)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor, BackgroundTransparency = 0.1}):Play()
        if textHover then TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = textHover}):Play() end
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = baseColor, BackgroundTransparency = 0.3}):Play()
        if textHover then TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(220,230,240)}):Play() end
    end)
end

local tpFrame = Instance.new("Frame", tpGui)
tpFrame.Size = UDim2.new(0, 360, 0, 540)
tpFrame.Position = UDim2.new(0.5, -180, 0.5, -270)
tpFrame.BackgroundColor3 = Color3.fromRGB(30, 33, 45)
tpFrame.BackgroundTransparency = 0.05
tpFrame.BorderSizePixel = 0
tpFrame.ClipsDescendants = true
tpFrame.Visible = false
tpFrame.ZIndex = 10

Instance.new("UICorner", tpFrame).CornerRadius = UDim.new(0, 18)
local shadow1 = Instance.new("UIStroke", tpFrame)
shadow1.Thickness = 6
shadow1.Color = Color3.fromRGB(0, 0, 0)
shadow1.Transparency = 0.7
shadow1.Name = "Shadow1"
local shadow2 = Instance.new("UIStroke", tpFrame)
shadow2.Thickness = 2
shadow2.Color = Color3.fromRGB(0, 0, 0)
shadow2.Transparency = 0.5
shadow2.Name = "Shadow2"
local border = Instance.new("UIStroke", tpFrame)
border.Thickness = 1
border.Color = Color3.fromRGB(60, 70, 90)
border.Transparency = 0.2

local titleBar = Instance.new("Frame", tpFrame)
titleBar.Size = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
titleBar.BorderSizePixel = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 18)
local titleFix = Instance.new("Frame", titleBar)
titleFix.Size = UDim2.new(1, 0, 0, 20)
titleFix.Position = UDim2.new(0, 0, 0, 22)
titleFix.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
titleFix.BorderSizePixel = 0

local tpIcon = Instance.new("ImageLabel", titleBar)
tpIcon.Size = UDim2.new(0, 26, 0, 26)
tpIcon.Position = UDim2.new(0, 10, 0, 8)
tpIcon.BackgroundTransparency = 1
tpIcon.Image = "rbxassetid://10734951477"
tpIcon.ImageColor3 = Color3.fromRGB(0, 240, 255)
tpIcon.ScaleType = Enum.ScaleType.Fit

local titleLabel = Instance.new("TextLabel", titleBar)
titleLabel.Size = UDim2.new(1, -110, 1, 0)
titleLabel.Position = UDim2.new(0, 42, 0, 0)
titleLabel.Text = "Teleporte Rápido"
titleLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18
titleLabel.BackgroundTransparency = 1

local minimizeBtn = Instance.new("TextButton", titleBar)
minimizeBtn.Size = UDim2.new(0, 32, 0, 32)
minimizeBtn.Position = UDim2.new(1, -68, 0, 5)
minimizeBtn.Text = "─"
minimizeBtn.TextColor3 = Color3.fromRGB(220, 230, 240)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 20
minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
minimizeBtn.BackgroundTransparency = 0.3
minimizeBtn.AutoButtonColor = false
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 10)

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -32, 0, 5)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
closeBtn.BackgroundTransparency = 0.2
closeBtn.AutoButtonColor = false
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 10)

hover(minimizeBtn, Color3.fromRGB(50,55,65), Color3.fromRGB(70,75,85), Color3.fromRGB(255,255,255))
hover(closeBtn, Color3.fromRGB(190,60,60), Color3.fromRGB(230,80,80), Color3.fromRGB(255,255,255))

local winDragging = false
local winStart, winFrameStart
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        winDragging = true
        winStart = input.Position
        winFrameStart = tpFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then winDragging = false end
        end)
    end
end)
titleBar.InputChanged:Connect(function(input)
    if winDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - winStart
        tpFrame.Position = UDim2.new(winFrameStart.X.Scale, winFrameStart.X.Offset + delta.X, winFrameStart.Y.Scale, winFrameStart.Y.Offset + delta.Y)
    end
end)

local posPanel = Instance.new("Frame", tpFrame)
posPanel.Size = UDim2.new(1, -24, 0, 46)
posPanel.Position = UDim2.new(0, 12, 0, 52)
posPanel.BackgroundColor3 = Color3.fromRGB(40, 43, 55)
posPanel.BorderSizePixel = 0
Instance.new("UICorner", posPanel).CornerRadius = UDim.new(0, 10)
local posStroke = Instance.new("UIStroke", posPanel)
posStroke.Thickness = 1
posStroke.Color = Color3.fromRGB(0, 240, 255)
posStroke.Transparency = 0.7

local posLabel = Instance.new("TextLabel", posPanel)
posLabel.Size = UDim2.new(1, -10, 1, 0)
posLabel.Position = UDim2.new(0, 5, 0, 0)
posLabel.BackgroundTransparency = 1
posLabel.Text = "📍 Posição: --, --, --"
posLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
posLabel.Font = Enum.Font.GothamMedium
posLabel.TextSize = 15

local inputName = Instance.new("TextBox", tpFrame)
inputName.Size = UDim2.new(1, -24, 0, 48)
inputName.Position = UDim2.new(0, 12, 0, 110)
inputName.PlaceholderText = "Nome do Local"
inputName.PlaceholderColor3 = Color3.fromRGB(180, 190, 210)
inputName.BackgroundColor3 = Color3.fromRGB(40, 43, 55)
inputName.TextColor3 = Color3.fromRGB(255, 255, 255)
inputName.Font = Enum.Font.Gotham
inputName.TextSize = 16
inputName.ClearTextOnFocus = false
Instance.new("UICorner", inputName).CornerRadius = UDim.new(0, 10)
local inputStroke = Instance.new("UIStroke", inputName)
inputStroke.Thickness = 1
inputStroke.Color = Color3.fromRGB(80, 90, 110)
inputStroke.Transparency = 0.3

local saveBtn = Instance.new("TextButton", tpFrame)
saveBtn.Size = UDim2.new(1, -24, 0, 48)
saveBtn.Position = UDim2.new(0, 12, 0, 170)
saveBtn.Text = "💾 Salvar Local"
saveBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextSize = 17
saveBtn.AutoButtonColor = false
Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 10)
local saveStroke = Instance.new("UIStroke", saveBtn)
saveStroke.Thickness = 1
saveStroke.Color = Color3.fromRGB(255, 255, 255)
saveStroke.Transparency = 0.4
hover(saveBtn, Color3.fromRGB(0,140,255), Color3.fromRGB(0,170,255), Color3.fromRGB(255,255,255))

local container = Instance.new("ScrollingFrame", tpFrame)
container.Size = UDim2.new(1, -24, 0, 250)
container.Position = UDim2.new(0, 12, 0, 230)
container.BackgroundColor3 = Color3.fromRGB(40, 43, 55)
container.BorderSizePixel = 0
container.ScrollBarThickness = 5
container.ScrollBarImageColor3 = Color3.fromRGB(0, 240, 255)
Instance.new("UICorner", container).CornerRadius = UDim.new(0, 10)

local layout = Instance.new("UIListLayout", container)
layout.Padding = UDim.new(0, 8)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder

local clearBtn = Instance.new("TextButton", tpFrame)
clearBtn.Size = UDim2.new(1, -24, 0, 46)
clearBtn.Position = UDim2.new(0, 12, 0, 492)
clearBtn.Text = "🗑 Limpar Tudo (meus locais)"
clearBtn.BackgroundColor3 = Color3.fromRGB(170, 50, 50)
clearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
clearBtn.Font = Enum.Font.GothamBold
clearBtn.TextSize = 15
clearBtn.AutoButtonColor = false
Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 10)
local clearStroke = Instance.new("UIStroke", clearBtn)
clearStroke.Thickness = 1
clearStroke.Color = Color3.fromRGB(255, 255, 255)
clearStroke.Transparency = 0.4
hover(clearBtn, Color3.fromRGB(170,50,50), Color3.fromRGB(210,70,70), Color3.fromRGB(255,255,255))

local FixedLocations = {
    {name = "👑 Bandeira de Captura", x = -463.30, y = 261.15, z = -1013.22},
    {name = "👑 Local do Barril", x = 1706.69, y = 120.95, z = 3773.69}
}
local savedLocations = {}

local refreshContainer

local function teleportTo(x, y, z, name)
    local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = CFrame.new(x, y, z)
        Rayfield:Notify({Title = "✅ Teleportado", Content = "Você foi para: " .. name, Duration = 2, Image = 4483362458})
    end
end

refreshContainer = function()
    for _, child in ipairs(container:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end

    for i, loc in ipairs(FixedLocations) do
        local btn = Instance.new("TextButton", container)
        btn.Name = "Fixed_" .. loc.name
        btn.Size = UDim2.new(1, -10, 0, 44)
        btn.Text = loc.name .. "\n" .. string.format("%.1f, %.1f, %.1f", loc.x, loc.y, loc.z)
        btn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
        btn.TextColor3 = Color3.fromRGB(30, 30, 30)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.LayoutOrder = i
        btn.AutoButtonColor = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        hover(btn, Color3.fromRGB(255, 200, 0), Color3.fromRGB(255, 220, 50))
        btn.MouseButton1Click:Connect(function()
            teleportTo(loc.x, loc.y, loc.z, loc.name)
        end)
    end

    for i, loc in ipairs(savedLocations) do
        local itemFrame = Instance.new("Frame", container)
        itemFrame.Name = "User_" .. loc.name
        itemFrame.Size = UDim2.new(1, -10, 0, 44)
        itemFrame.BackgroundTransparency = 1
        itemFrame.LayoutOrder = 100 + i

        local itemLayout = Instance.new("UIListLayout", itemFrame)
        itemLayout.FillDirection = Enum.FillDirection.Horizontal
        itemLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        itemLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        itemLayout.Padding = UDim.new(0, 4)

        local btn = Instance.new("TextButton", itemFrame)
        btn.Size = UDim2.new(1, -30, 1, 0)
        btn.Text = loc.name .. "\n" .. string.format("%.1f, %.1f, %.1f", loc.x, loc.y, loc.z)
        btn.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 14
        btn.AutoButtonColor = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        hover(btn, Color3.fromRGB(50,55,70), Color3.fromRGB(70,75,90))
        btn.MouseButton1Click:Connect(function()
            teleportTo(loc.x, loc.y, loc.z, loc.name)
        end)

        local delBtn = Instance.new("TextButton", itemFrame)
        delBtn.Size = UDim2.new(0, 24, 0, 24)
        delBtn.Text = "✕"
        delBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 14
        delBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        delBtn.AutoButtonColor = false
        Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 6)
        hover(delBtn, Color3.fromRGB(200,60,60), Color3.fromRGB(240,80,80), Color3.fromRGB(255,255,255))

        local index = i
        delBtn.MouseButton1Click:Connect(function()
            table.remove(savedLocations, index)
            refreshContainer()
            Rayfield:Notify({Title = "🗑️ Removido", Content = loc.name .. " foi deletado.", Duration = 2, Image = 4483362458})
        end)
    end
    container.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
end

saveBtn.MouseButton1Click:Connect(function()
    if inputName.Text == "" then
        Rayfield:Notify({Title = "⚠️ Erro", Content = "Digite um nome para o local!", Duration = 2, Image = 4483362458})
        return
    end
    local char = Player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local pos = char.HumanoidRootPart.Position
    local x, y, z = math.floor(pos.X * 100) / 100, math.floor(pos.Y * 100) / 100, math.floor(pos.Z * 100) / 100
    table.insert(savedLocations, {name = inputName.Text, x = x, y = y, z = z})
    inputName.Text = ""
    refreshContainer()
    Rayfield:Notify({Title = "💾 Salvo", Content = "Local salvo com sucesso!", Duration = 2, Image = 4483362458})
end)

clearBtn.MouseButton1Click:Connect(function()
    if #savedLocations == 0 then
        Rayfield:Notify({Title = "⚠️ Aviso", Content = "Nenhum local do usuário para limpar.", Duration = 2, Image = 4483362458})
        return
    end
    savedLocations = {}
    refreshContainer()
    Rayfield:Notify({Title = "🗑️ Limpo", Content = "Todos os seus locais foram removidos.", Duration = 2, Image = 4483362458})
end)

local function toggleMenu(show)
    if show then
        tpFrame.Visible = true
        tpFrame.Size = UDim2.new(0, 0, 0, 540)
        tpFrame.BackgroundTransparency = 1
        TweenService:Create(tpFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 360, 0, 540),
            BackgroundTransparency = 0.05
        }):Play()
    else
        local tween = TweenService:Create(tpFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 540),
            BackgroundTransparency = 1
        })
        tween:Play()
        tween.Completed:Connect(function() tpFrame.Visible = false end)
    end
end

local function animateBtn(btn, visible)
    if visible then
        btn.Visible = true
        btn.Size = UDim2.new(0, 0, 0, 0)
        btn.BackgroundTransparency = 1
        TweenService:Create(btn, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 58, 0, 58),
            BackgroundTransparency = 0.1,
            TextSize = 30
        }):Play()
    else
        local tween = TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1
        })
        tween:Play()
        tween.Completed:Connect(function() btn.Visible = false end)
    end
end

local TpFloatingBtn = Instance.new("TextButton", tpGui)
TpFloatingBtn.Size = UDim2.new(0, 58, 0, 58)
TpFloatingBtn.Position = UDim2.new(0.8, 0, 0.7, 0)
TpFloatingBtn.BackgroundColor3 = Color3.fromRGB(11, 13, 23)
TpFloatingBtn.BackgroundTransparency = 0.1
TpFloatingBtn.Text = "📍"
TpFloatingBtn.TextColor3 = Color3.fromRGB(0, 240, 255)
TpFloatingBtn.Font = Enum.Font.GothamBold
TpFloatingBtn.TextSize = 30
TpFloatingBtn.AutoButtonColor = false
TpFloatingBtn.Visible = false
TpFloatingBtn.Active = true
TpFloatingBtn.ZIndex = 10

Instance.new("UICorner", TpFloatingBtn).CornerRadius = UDim.new(0, 22)
local floatShadow = Instance.new("UIStroke", TpFloatingBtn)
floatShadow.Thickness = 3
floatShadow.Color = Color3.fromRGB(0, 0, 0)
floatShadow.Transparency = 0.5
local floatStroke = Instance.new("UIStroke", TpFloatingBtn)
floatStroke.Thickness = 1.5
floatStroke.Color = Color3.fromRGB(0, 240, 255)
floatStroke.Transparency = 0.6

local isDragging = false
local dragStartPos = nil
local btnStartPos = nil
local hasMoved = false
local lastDragTime = 0
local dragThreshold = 10
local clickThreshold = 0.25

TpFloatingBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        hasMoved = false
        dragStartPos = input.Position
        btnStartPos = TpFloatingBtn.Position
        lastDragTime = os.clock()
        local curSize = TpFloatingBtn.Size.X.Offset
        TweenService:Create(TpFloatingBtn, TweenInfo.new(0.1), {
            Size = UDim2.new(0, curSize + 8, 0, curSize + 8),
            BackgroundTransparency = 0.2
        }):Play()
    end
end)

TpFloatingBtn.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartPos
        local distance = math.sqrt(delta.X * delta.X + delta.Y * delta.Y)
        if distance > dragThreshold then hasMoved = true end
        if hasMoved then
            TpFloatingBtn.Position = UDim2.new(
                btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X,
                btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y
            )
        end
    end
end)

TpFloatingBtn.InputEnded:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        local elapsedTime = os.clock() - lastDragTime
        TweenService:Create(TpFloatingBtn, TweenInfo.new(0.1), {
            Size = UDim2.new(0, 58, 0, 58),
            BackgroundTransparency = 0.1
        }):Play()
        if not hasMoved and elapsedTime < clickThreshold then
            isTeleportOpen = not isTeleportOpen
            toggleMenu(isTeleportOpen)
        elseif hasMoved then
            local screenSize = tpGui.AbsoluteSize
            local btnSize = TpFloatingBtn.Size.X.Offset
            local delta = input.Position - dragStartPos
            local newX = math.max(5, math.min(btnStartPos.X.Offset + delta.X, screenSize.X - btnSize - 5))
            local newY = math.max(5, math.min(btnStartPos.Y.Offset + delta.Y, screenSize.Y - btnSize - 5))
            TweenService:Create(TpFloatingBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, newX, 0, newY)
            }):Play()
        end
        isDragging = false
        hasMoved = false
    end
end)

minimizeBtn.MouseButton1Click:Connect(function()
    isTeleportOpen = false
    toggleMenu(false)
end)
closeBtn.MouseButton1Click:Connect(function()
    isTeleportOpen = false
    toggleMenu(false)
end)

TeleportTab:CreateToggle({
    Name = "Ativar Sistema de Teleporte",
    CurrentValue = false,
    Callback = function(value)
        if value then
            animateBtn(TpFloatingBtn, true)
        else
            animateBtn(TpFloatingBtn, false)
            if isTeleportOpen then
                isTeleportOpen = false
                toggleMenu(false)
            end
        end
    end
})

RunService.RenderStepped:Connect(function()
    if tpFrame.Visible and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local p = Player.Character.HumanoidRootPart.Position
        posLabel.Text = string.format("📍 Posição: %.1f, %.1f, %.1f", p.X, p.Y, p.Z)
    end
end)
refreshContainer()

--// =============================================
--// ABA MONITOR
--// =============================================
StatusTab:CreateToggle({
    Name = "Monitorar Taxa de FPS",
    CurrentValue = false,
    Callback = function(v) getgenv().SystemConfig.ShowFPS = v; fpsF.Visible = v end
})
StatusTab:CreateToggle({
    Name = "Contador Ativo de Players",
    CurrentValue = false,
    Callback = function(v) getgenv().SystemConfig.ShowPlayers = v; countF.Visible = v end
})

--// =============================================
--// LOOP PRINCIPAL UNIFICADO (RENDERSTEPPED)
--// =============================================
RunService.RenderStepped:Connect(function(dt)
    local cfg = getgenv().SystemConfig

    -- Mira Assistida
    if cfg.MiraAtiva then
        local target = getTarget()
        if target then
            local goal = CFrame.new(Camera.CFrame.Position, target.Position)
            Camera.CFrame = Camera.CFrame:Lerp(goal, cfg.Smoothness * math.clamp(60 * dt, 0, 1))
        end
    end

    -- Pulo Infinito
    if cfg.InfiniteJump then
        local char = Player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum:GetState() == Enum.HumanoidStateType.Freefall and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end

    -- FullBright / Clareza
    if cfg.FullBright then
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        Lighting.ClockTime = 14
        FullBrightApplied = true
    elseif FullBrightApplied then
        Lighting.Ambient = OriginalSettings.Ambient
        Lighting.OutdoorAmbient = OriginalSettings.OutdoorAmbient
        Lighting.ClockTime = OriginalSettings.ClockTime
        FullBrightApplied = false
    end
    if cfg.ClarezaMod then
        Lighting.Brightness = 3
        Lighting.ExposureCompensation = 0.5
        ClarezaApplied = true
    elseif ClarezaApplied then
        Lighting.Brightness = OriginalSettings.Brightness
        Lighting.ExposureCompensation = OriginalSettings.Exposure
        ClarezaApplied = false
    end

    -- Monitor FPS / Players
    if cfg.ShowFPS then
        fpsL.Text = " ⚡ FPS: " .. math.floor(1 / math.max(dt, 0.0001))
    end
    if cfg.ShowPlayers then
        countL.Text = " 👥 Players: " .. #Players:GetPlayers()
    end

    -- Atualiza estado FFA e ESP de todos os jogadores
    isFFA = IsFFA()
    for player in pairs(ESPData) do
        UpdateESP(player)
    end
end)

--// =============================================
--// REFORÇO DE SPEED / PULO (HEARTBEAT)
--// =============================================
RunService.Heartbeat:Connect(function()
    local cfg = getgenv().SystemConfig
    local char = Player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if cfg.SpeedEnabled then
        if hum.WalkSpeed ~= cfg.SpeedValue then hum.WalkSpeed = cfg.SpeedValue end
    else
        if hum.WalkSpeed ~= OriginalWalkSpeed then hum.WalkSpeed = OriginalWalkSpeed end
    end

    if cfg.JumpEnabled then
        if hum.JumpPower ~= cfg.JumpPower then hum.JumpPower = cfg.JumpPower end
    else
        if hum.JumpPower ~= OriginalJumpPower then hum.JumpPower = OriginalJumpPower end
    end
end)

--// =============================================
--// RESPAWN (CharacterAdded)
--// =============================================
Player.CharacterAdded:Connect(function(char)
    task.wait(0.6)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        OriginalWalkSpeed = hum.WalkSpeed
        OriginalJumpPower = hum.JumpPower
    end
    if NoClipAtivo then
        if NoClipConnection then NoClipConnection:Disconnect() end
        NoClipConnection = RunService.Stepped:Connect(function()
            local chr = Player.Character
            if chr then
                for _, part in ipairs(chr:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
    end
    if getgenv().SystemConfig.FlyEnabled then startFly() end
end)

--// =============================================
--// FINAL
--// =============================================
Rayfield:Notify({
    Title = "👑 WARCORE v1.4.0",
    Content = "HUD separado: Vida e Distância com botões próprios!",
    Duration = 5,
    Image = 4483362458
})
