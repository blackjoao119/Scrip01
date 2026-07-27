--[[
    ╔════════════════════════════════════════════════════════════╗
    ║       PROJECT: WARCORE v1.3.0 (ESP OPTIMIZED)             ║
    ║       STUDIO: WARCORE LABS                                 ║
    ║------------------------------------------------------------║
    ║       LEAD DEVELOPER: ENZO CAVALCANTI                      ║
    ║       MOD: RAIOS-X AVANÇADO + DRAWING API                 ║
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
    ShowDistanceOnTracer = false,

    -- Micro-HUD
    MicroHpEnabled = false,
    MicroDistEnabled = false,
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
local ESPLoopConnection = nil

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
    rayParams.FilterDescendantsInstances = {Player.Character, targetPart.Parent}
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
--// BOTÃO FLUTUANTE DA MIRA
--// =============================================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

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
local Stroke = Instance.new("UIStroke", FloatingBtn)
Stroke.Thickness = 2
Stroke.Color = Color3.fromRGB(35, 42, 65)

local function UpdateBtnVisual(active)
    if active then
        TweenService:Create(FloatingBtn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(16, 28, 48)}):Play()
        TweenService:Create(Stroke, TweenInfo.new(0.25), {Color = Color3.fromRGB(0, 240, 255)}):Play()
        FloatingBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        FloatingBtn.Text = "⚡ ON"
    else
        TweenService:Create(FloatingBtn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(11, 14, 24)}):Play()
        TweenService:Create(Stroke, TweenInfo.new(0.25), {Color = Color3.fromRGB(35, 42, 65)}):Play()
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
local function CreateESPObjects(player)
    if ESPData[player] then return end

    local data = {
        char = nil,
        highlight = nil,
        line = Drawing.new("Line"),
        dot = nil,
        distText = Drawing.new("Text"),
        alive = false,
        connections = {}
    }

    data.line.Visible = false
    data.line.Thickness = getgenv().SystemConfig.LineThickness
    data.line.Transparency = 1

    data.distText.Visible = false
    data.distText.Size = 14
    data.distText.Center = true
    data.distText.Outline = true
    data.distText.OutlineColor = Color3.fromRGB(0,0,0)
    data.distText.Color = getgenv().SystemConfig.DistColor

    local dotType = getgenv().SystemConfig.DotType
    if dotType == "Circle" then
        data.dot = Drawing.new("Circle")
        data.dot.Thickness = 1
        data.dot.Filled = true
    else
        data.dot = Drawing.new("Square")
        data.dot.Thickness = 1
        data.dot.Filled = true
    end
    data.dot.Visible = false
    data.dot.Size = getgenv().SystemConfig.DotSize
    data.dot.Color = Color3.fromRGB(255,0,0)

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
        hl.Parent = char
        hl.Adornee = char
    end)
    table.insert(conns, charAddedConn)

    local charRemovingConn = player.CharacterRemoving:Connect(function()
        data.char = nil
        data.alive = false
        hl.Parent = nil
        data.line.Visible = false
        data.dot.Visible = false
        data.distText.Visible = false
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

local function CleanupESP(player)
    local data = ESPData[player]
    if not data then return end

    for _, conn in ipairs(data.connections) do
        conn:Disconnect()
    end
    if data.line then data.line:Remove() end
    if data.dot then data.dot:Remove() end
    if data.distText then data.distText:Remove() end
    if data.highlight then data.highlight:Destroy() end
    ESPData[player] = nil
end

--// =============================================
--// ATUALIZAÇÃO DO ESP (CHAMADA NO RENDERSTEPPED)
--// =============================================
local function UpdateESP(player)
    local data = ESPData[player]
    if not data then return end

    local char = data.char
    if not char or not data.alive then
        data.line.Visible = false
        data.dot.Visible = false
        data.distText.Visible = false
        if data.highlight then data.highlight.Enabled = false end
        return
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        data.line.Visible = false
        data.dot.Visible = false
        data.distText.Visible = false
        if data.highlight then data.highlight.Enabled = false end
        return
    end

    local head = char:FindFirstChild("Head")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not head or not root then
        data.line.Visible = false
        data.dot.Visible = false
        data.distText.Visible = false
        if data.highlight then data.highlight.Enabled = false end
        return
    end

    local config = getgenv().SystemConfig
    local hlEnabled = config.HighlightEnabled
    local dotEnabled = config.DotEnabled
    local lineEnabled = config.LineEnabled
    local showDist = config.ShowDistanceOnTracer

    local behind = IsBehindWall(head)
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
                data.dot.Color = behind and Color3.fromRGB(255, 165, 0) or Color3.fromRGB(255, 0, 0)
            end
            data.dot.Size = config.DotSize
        else
            data.dot.Visible = false
        end
    else
        data.dot.Visible = false
    end

    -- TRACER (linha + distância)
    if lineEnabled and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        -- ORIGEM: posição da CÂMERA na tela (fixa no centro) – assim a linha não "sobe" ao correr
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

            if showDist then
                local dist = math.floor(Player:DistanceFromCharacter(root.Position))
                data.distText.Visible = true
                data.distText.Text = dist .. "m"
                data.distText.Color = config.DistColor
                data.distText.Size = config.MicroTextSize + 4
                data.distText.Position = (data.line.From + data.line.To) / 2
            else
                data.distText.Visible = false
            end
        else
            data.line.Visible = false
            data.distText.Visible = false
        end
    else
        data.line.Visible = false
        data.distText.Visible = false
    end
end

--// =============================================
--// INICIALIZAÇÃO DOS JOGADORES
--// =============================================
for _, p in ipairs(Players:GetPlayers()) do
    CreateESPObjects(p)
end

Players.PlayerAdded:Connect(CreateESPObjects)
Players.PlayerRemoving:Connect(CleanupESP)

--// =============================================
--// INTERFACE RAYFIELD
--// =============================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "👑 WARCORE v1.3.0",
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
VisualTab:CreateToggle({
    Name = "Distância no Tracer",
    CurrentValue = false,
    Callback = function(v) getgenv().SystemConfig.ShowDistanceOnTracer = v end
})
VisualTab:CreateToggle({
    Name = "Micro-HUD: Vida",
    CurrentValue = false,
    Callback = function(v) getgenv().SystemConfig.MicroHpEnabled = v end
})
VisualTab:CreateToggle({
    Name = "Micro-HUD: Distância + Nome",
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
        for player, data in pairs(ESPData) do
            if data.dot then
                local old = data.dot
                old:Remove()
                if newType == "Circle" then
                    data.dot = Drawing.new("Circle")
                    data.dot.Thickness = 1
                    data.dot.Filled = true
                else
                    data.dot = Drawing.new("Square")
                    data.dot.Thickness = 1
                    data.dot.Filled = true
                end
                data.dot.Visible = false
                data.dot.Size = getgenv().SystemConfig.DotSize
                data.dot.Color = Color3.fromRGB(255,0,0)
            end
        end
    end
})

--// =============================================
--// LOOP PRINCIPAL UNIFICADO (RENDERSTEPPED)
--// =============================================
RunService.RenderStepped:Connect(function(dt)
    -- Mira Assistida
    if getgenv().SystemConfig.MiraAtiva then
        local target = getTarget()
        if target then
            local goal = CFrame.new(Camera.CFrame.Position, target.Position)
            Camera.CFrame = Camera.CFrame:Lerp(goal, getgenv().SystemConfig.Smoothness * math.clamp(60 * dt, 0, 1))
        end
    end

    -- FullBright / Clareza
    if getgenv().SystemConfig.FullBright then
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        Lighting.ClockTime = 14
    end
    if getgenv().SystemConfig.ClarezaMod then
        Lighting.Brightness = 3
        Lighting.ExposureCompensation = 0.5
    else
        if not getgenv().SystemConfig.FullBright then
            Lighting.Brightness = OriginalSettings.Brightness
            Lighting.ExposureCompensation = OriginalSettings.Exposure
        end
    end

    -- Atualiza estado FFA e ESP de todos os jogadores
    isFFA = IsFFA()
    for player, data in pairs(ESPData) do
        UpdateESP(player)
    end
end)

--// =============================================
--// (AQUI VOCÊ DEVE INSERIR O CÓDIGO ORIGINAL DE FLY, SPEED, JUMP, NOCLIP, TELEPORTE E MICRO-HUD)
--// =============================================
-- Para não alongar, mantenha as mesmas funções do seu script original.
-- Elas não foram alteradas e funcionam perfeitamente com o novo loop.
-- Apenas certifique-se de que o Micro-HUD usa a função CreateMicroDisplay do original.

--// =============================================
--// FINAL
--// =============================================
Rayfield:Notify({
    Title = "👑 WARCORE v1.3.0",
    Content = "ESP otimizado + Tracer corrigido!",
    Duration = 5,
    Image = 4483362458
})