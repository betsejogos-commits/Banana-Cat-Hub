-- ======================================================================================
-- 1. [SISTEMA DE AUTENTICAÇÃO E VERIFICAÇÃO DE KEYS]
-- ======================================================================================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Lista de Keys válidas configuradas
local PayKeys = {
    ["AleatoryKeyPay"] = true,
    ["ScriptContentPay"] = true,
    ["202020234"] = true,
    ["pay67"] = true,
    ["101010"] = true
}

-- Verifica se a Key global injetada via loadstring existe e é válida
if not getgenv().KeyCorret or not PayKeys[getgenv().KeyCorret] then
    LocalPlayer:Kick("\n[Banana Cat Hub]\nErro de Autenticação!\nSua Key é inválida ou expirou.\nPreço do Script: R$ 5,90")
    return
end

-- Bloqueia reinjeções duplicadas se a autenticação já tiver passado uma vez
if getgenv().__BF_LOADED then return getgenv().__BF_RESULT end

-- ======================================================================================
-- 2. [SISTEMA ANTI-RUBBERBAND AVANÇADO (SEGURANÇA)]
-- ======================================================================================
local lastValidCFrame = nil
local isBypassing = false

task.spawn(function()
    while task.wait() do
        pcall(function()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                if not getgenv().noclip and not isBypassing then 
                    lastValidCFrame = root.CFrame 
                end
                -- Mitigação e bypass de física contra puxões do servidor nativo
                if root.AssemblyLinearVelocity.Magnitude > 250 and lastValidCFrame then
                    isBypassing = true
                    for i = 1, 5 do
                        root.CFrame = lastValidCFrame
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    end
                    task.wait(0.05)
                    isBypassing = false
                end
            end
        end)
    end
end)

-- ======================================================================================
-- 3. [TELA DE CARREGAMENTO ESTILIZADA FIEL À IMAGEM (PAINEL MINIMALISTA)]
-- ======================================================================================
local CoreGui = game:GetService("CoreGui")
if CoreGui:FindFirstChild("BananaCatLoadingScreen") then CoreGui.BananaCatLoadingScreen:Destroy() end

local loadingGui = Instance.new("ScreenGui", CoreGui)
loadingGui.Name = "BananaCatLoadingScreen"
loadingGui.IgnoreGuiInset = true
loadingGui.DisplayOrder = 99999

-- Fundo completamente transparente para não cobrir o jogo
local mainBackground = Instance.new("Frame", loadingGui)
mainBackground.Size = UDim2.new(1, 0, 1, 0)
mainBackground.BackgroundTransparency = 1

-- Caixa do Painel Centralizada e Arredondada (Fiel à Imagem)
local centerFrame = Instance.new("Frame", mainBackground)
centerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
centerFrame.Position = UDim2.new(0.5, 0, 0.5, -20)
centerFrame.Size = UDim2.new(0, 420, 0, 130)
centerFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
centerFrame.BackgroundTransparency = 0.15
centerFrame.BorderSizePixel = 0
Instance.new("UICorner", centerFrame).CornerRadius = UDim.new(0, 14)

-- Texto do Canto Esquerdo superior (Nome do Jogo/Script)
local gameLabel = Instance.new("TextLabel", centerFrame)
gameLabel.Size = UDim2.new(0, 150, 0, 20)
gameLabel.Position = UDim2.new(0, 20, 0, 15)
gameLabel.BackgroundTransparency = 1
gameLabel.Font = Enum.Font.GothamMedium
gameLabel.Text = "Blox Fruits •"
gameLabel.TextColor3 = Color3.fromRGB(80, 120, 255)
gameLabel.TextSize = 13
gameLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Texto do Canto Direito superior (Status/Versão)
local premiumLabel = Instance.new("TextLabel", centerFrame)
premiumLabel.Size = UDim2.new(0, 150, 0, 20)
premiumLabel.Position = UDim2.new(1, -170, 0, 15)
premiumLabel.BackgroundTransparency = 1
premiumLabel.Font = Enum.Font.GothamMedium
premiumLabel.Text = "PREMIUM LOADER"
premiumLabel.TextColor3 = Color3.fromRGB(120, 180, 120)
premiumLabel.TextSize = 12
premiumLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Texto de Porcentagem Grande Centralizada
local percentageLabel = Instance.new("TextLabel", centerFrame)
percentageLabel.Size = UDim2.new(1, 0, 0, 40)
percentageLabel.Position = UDim2.new(0, 0, 0, 40)
percentageLabel.BackgroundTransparency = 1
percentageLabel.Font = Enum.Font.GothamBold
percentageLabel.Text = "0.0%"
percentageLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
percentageLabel.TextSize = 36

-- Texto de Status Inferior Minimalista
local statusLabel = Instance.new("TextLabel", centerFrame)
statusLabel.Size = UDim2.new(1, -40, 0, 20)
statusLabel.Position = UDim2.new(0, 20, 1, -25)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "Initializing game systems..."
statusLabel.TextColor3 = Color3.fromRGB(110, 115, 130)
statusLabel.TextSize = 12

-- Barra de Progresso Fina com pino indicador (Estilo Slider da foto)
local progressBarBg = Instance.new("Frame", centerFrame)
progressBarBg.Position = UDim2.new(0, 20, 0, 85)
progressBarBg.Size = UDim2.new(1, -40, 0, 4)
progressBarBg.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
progressBarBg.BorderSizePixel = 0
Instance.new("UICorner", progressBarBg).CornerRadius = UDim.new(0, 2)

local progressBarFill = Instance.new("Frame", progressBarBg)
progressBarFill.Size = UDim2.new(0, 0, 1, 0)
progressBarFill.BackgroundColor3 = Color3.fromRGB(90, 130, 255)
progressBarFill.BorderSizePixel = 0
Instance.new("UICorner", progressBarFill).CornerRadius = UDim.new(0, 2)

-- Pino indicador na ponta da barra de progresso
local progressSliderPin = Instance.new("Frame", progressBarFill)
progressSliderPin.AnchorPoint = Vector2.new(0.5, 0.5)
progressSliderPin.Position = UDim2.new(1, 0, 0.5, 0)
progressSliderPin.Size = UDim2.new(0, 10, 0, 10)
progressSliderPin.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
progressSliderPin.BorderSizePixel = 0
Instance.new("UICorner", progressSliderPin).CornerRadius = UDim.new(0, 5)

-- Animação e contagem incremental de porcentagem síncrona
task.spawn(function()
    local steps = {
        {0.05, "Checking license key..."},
        {0.24, "Bypassing native anticheat hooks..."},
        {0.56, "Injecting high-speed RubberBand parameters..."},
        {0.82, "Spoofing network client memory values..."},
        {1.00, "Banana Cat Hub loaded successfully!"}
    }
    
    local TS = game:GetService("TweenService")
    local currentPercent = 0
    
    for _, step in ipairs(steps) do
        statusLabel.Text = step[2]
        
        -- Transição suave da barra
        local tween = TS:Create(progressBarFill, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(step[1], 0, 1, 0)
        })
        tween:Play()
        
        -- Incremento numérico realista acompanhando a animação
        local targetPercent = step[1] * 100
        while currentPercent < targetPercent do
            currentPercent = currentPercent + math.random(1, 3) / 10
            if currentPercent > targetPercent then currentPercent = targetPercent end
            percentageLabel.Text = string.format("%.1f%%", currentPercent)
            task.wait(0.01)
        end
        
        tween.Completed:Wait()
        task.wait(0.1)
    end
    
    task.wait(0.2)
    loadingGui:Destroy()
end)

-- ======================================================================================
-- 4. [EXECUÇÃO DO CONTEÚDO PRINCIPAL VIA LOADSTRING]
-- ======================================================================================
repeat wait() until game:IsLoaded() and game.Players.LocalPlayer
loadstring(game:HttpGet("https://raw.githubusercontent.com/betsejogos-commits/Banana-Cat-Hub/refs/heads/main/BananaCatHub.lua"))()
getgenv().__BF_LOADED = true
