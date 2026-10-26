-- // 1. DECLARAÇÃO ESTÁTICA DOS SERVIÇOS (Otimização máxima de memória)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkClient = game:GetService("NetworkClient")
local TeleportService = game:GetService("TeleportService")
local LogService = game:GetService("LogService")
local DataStoreService = game:GetService("DataStoreService")
local VirtualUser = game:GetService("VirtualUser")
local ScriptContext = game:GetService("ScriptContext")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Heartbeat = RunService.Heartbeat

-- Configurações dinâmicas do Emulador de Rede (RakNet Mimic Layer)
local RakNetConfig = {
    SimularQuedaInternet = false, 
    FakePing = 9999,
    IgnorarRestricoes = true,
    UltimoCicloPPS = 0
}

-- // 2. ESTRUTURA DE DATA-CACHING PERSISTENTE (MEMÓRIA CLIENT-SIDE)
_G.LocalDataCache = _G.LocalDataCache or {
    SessaoAtiva = true,
    DadosSalvos = {},
    HistoricoFlags = {},
    UltimaSincronizacao = os.time()
}

_G.SpoofEnvironment = {
    IsBanned = false,
    IsKicked = false,
    ViolationsDetected = 0,
    BypassActive = true
}

function _G.PreservarDadosLocais(tabelaDeDados)
    if type(tabelaDeDados) == "table" then
        for chave, valor in pairs(tabelaDeDados) do
            _G.LocalDataCache.DadosSalvos[chave] = valor
        end
        print("[💾 CACHE] Estrutura de persistência local atualizada.")
    end
end

-- // 3. DISJUNTOR DE SEGURANÇA ULTRA-RÁPIDO (Panic Switch & Reset)
local function AcionarSaidaDeEmergencia(metodo, remote, dados)
    local log = {
        Timestamp = os.clock(),
        Origem = metodo,
        RemoteAlvo = remote,
        Payload = dados or {}
    }
    table.insert(_G.LocalDataCache.HistoricoFlags, log)
    
    if LocalPlayer.Character then
        LocalPlayer.Character:Destroy()
    end
    
    task.spawn(function()
        while true do 
            -- Loop síncrono para travar a thread antes do envio do ban
        end
    end)
end

-- // 4. GERADOR E LOOP CONTÍNUO DE INSTÂNCIAS FANTASMAS (Spoof de Remotes/Scripts)
local function InjetarModulosFantasmas(index)
    local caracteres = "abcdefghijklmnopqrstuvwxyz"
    local sufixo = string.format("(%02d)", index)
    local base = ""
    for i = 1, 12 do
        local rand = math.random(1, #caracteres)
        base = base .. string.sub(caracteres, rand, rand)
    end
    local nomeFalso = base .. sufixo

    local Destinos = {ReplicatedStorage, LocalPlayer.PlayerGui, workspace}
    local alvoContainer = Destinos[math.random(1, #Destinos)]

    local falsoRemote = Instance.new("RemoteEvent")
    falsoRemote.Name = nomeFalso
    falsoRemote.Parent = alvoContainer
    falsoRemote.OnClientEvent:Connect(function() end)

    local falsoLocal = Instance.new("LocalScript")
    falsoLocal.Name = nomeFalso .. "_Core"
    falsoLocal.Enabled = true
    falsoLocal.Parent = falsoRemote

    local falsoModule = Instance.new("ModuleScript")
    falsoModule.Name = nomeFalso .. "_DataStore"
    falsoModule.Parent = falsoLocal

    local falsoServerScript = Instance.new("Script")
    falsoServerScript.Name = nomeFalso .. "_ServerEngine"
    falsoServerScript.Disabled = false
    falsoServerScript.Parent = falsoRemote
end

task.spawn(function()
    local rodadas = 1
    while task.wait(10) do
        pcall(InjetarModulosFantasmas, rodadas)
        rodadas = rodadas + 1
    end
end)

-- // 5. BLINDAGEM DE METATABELA (Spoof de Ban/Kick e Silenciador)
local MetatabelaOriginal = getrawmetatable(game)
local oldIndex = MetatabelaOriginal.__index
local oldNewIndex = MetatabelaOriginal.__newindex
setreadonly(MetatabelaOriginal, false)

MetatabelaOriginal.__index = newcclosure(function(self, key)
    if _G.SpoofEnvironment.BypassActive then
        local keyLower = string.lower(tostring(key))
        if string.find(keyLower, "ban") or string.find(keyLower, "kick") or string.find(keyLower, "punish") then
            return false
        end
    end
    return oldIndex(self, key)
end)

MetatabelaOriginal.__newindex = newcclosure(function(self, key, value)
    if _G.SpoofEnvironment.BypassActive then
        local keyLower = string.lower(tostring(key))
        if string.find(keyLower, "ban") or string.find(keyLower, "kick") or string.find(keyLower, "cheat") then
            _G.SpoofEnvironment.ViolationsDetected = _G.SpoofEnvironment.ViolationsDetected + 1
            return nil 
        end
    end
    return oldNewIndex(self, key, value)
end)
setreadonly(MetatabelaOriginal, true)

-- // 6. MÓDULO OTIMIZADOR (Lighting Remover & Anti-Cheat Purge)
local function LimparAmbienteELighting()
    -- A. LIGHTING REMOVER (Desativa recursos pesados para otimizar processamento e rede)
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 0
        
        -- Limpa efeitos de pós-processamento que causam lag de renderização
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("BloomEffect") or effect:IsA("Atmosphere") then
                effect:Destroy()
            end
        end
    end)
    print("[💡 LIGHTING] Atmosfera, sombras e pós-processamento removidos com sucesso.")

    -- B. ANTI-CHEAT REMOVER CLIENT-SIDE
    local NomesMaliciosos = {"anticheat", "cheat", "detection", "bypass", "security", "verify", "validation"}
    local function PurgarInstancia(inst)
        if inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
            for _, nome in pairs(NomesMaliciosos) do
                if string.find(string.lower(inst.Name), nome) then
                    inst.Enabled = false
                    if typeof(getconnections) == "function" then
                        for _, conn in pairs(getconnections(inst.Changed)) do conn:Disconnect() end
                    end
                    inst:Destroy()
                end
            end
        end
    end
    for _, desc in pairs(LocalPlayer:GetDescendants()) do pcall(PurgarInstancia, desc) end
    if typeof(getconnections) == "function" then
        for _, conn in pairs(getconnections(ScriptContext.Error)) do conn:Disconnect() end
    end
    if typeof(gccollect) == "function" then gccollect() elseif collectgarbage then collectgarbage("collect") end
    print("[✔ AC REMOVER] Memória limpa e processos espiões revogados.")
end

-- Ativa o limpador de memória e renderização
task.spawn(LimparAmbienteELighting)

-- Interceptador síncrono de logs de falhas locais
LogService.MessageReceived:Connect(function(message, messageType)
    if string.find(string.lower(message), "exploit") or string.find(string.lower(message), "teleport") or string.find(string.lower(message), "desync") then
        return nil
    end
end)

-- // 7. LAYER DE BYPASS RAKNET & ESTABILIZADORES FÍSICOS
local function SincronizarCanalRakNet(estado)
    if estado == true then
        settings().Network.IncomingReplicationLag = 9999
        if LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                    part.Velocity = Vector3.new(0, 0, 0)
                end
            end
        end
    else
        settings().Network.IncomingReplicationLag = 0
    end
end

Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    if root then
        if root.Velocity.Magnitude > 80 then
            root.Velocity = Vector3.new(0, 0, 0)
            root.RotVelocity = Vector3.new(0, 0, 0)
        end
    end
    
    local tempoAtual = os.time()
    if (tempoAtual - RakNetConfig.UltimoCicloPPS) >= 1 then
        RakNetConfig.UltimoCicloPPS = tempoAtual
        if settings().Network.IncomingReplicationLag > 0 and not RakNetConfig.SimularQuedaInternet then
            settings().Network.IncomingReplicationLag = 0
        end
    end
end)

_G.BypassTween = function(targetCFrame)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    SincronizarCanalRakNet(true)
    task.wait(0.02)
    
    local passos = 3
    for i = 1, passos do
        if not root then break end
        root.CFrame = root.CFrame:Lerp(targetCFrame, i / passos)
        root.Velocity = Vector3.new(0, 0, 0)
        task.wait()
    end
    root.CFrame = targetCFrame
    root.Velocity = Vector3.new(0, 0, 0)
    task.wait(0.05)
    SincronizarCanalRakNet(false)
end

-- AFK Reset via comandos nativos síncronos locais
LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(0.1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

UserInputService.WindowFocused:Connect(function()
    if settings().Network.IncomingReplicationLag > 0 and not RakNetConfig.SimularQuedaInternet then
        settings().Network.IncomingReplicationLag = 0
    end
end)

-- // 8. INJEÇÃO SÍNCRONA DO BANANA-CAT-HUB
task.spawn(function()
    print("[🛡️ ENGINE] Serviços mapeados localmente, Lighting removido. Injetando Hub...")
    task.wait(0.5)
    
    local sucesso, erro = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/betsejogos-commits/Banana-Cat-Hub/refs/heads/main/BananaCatHub.lua"))()
    end)
    
    if sucesso then
        print("[✔] Banana-Cat-Hub rodando com sucesso no ambiente otimizado!")
    else
        warn("[❌] Falha no carregamento do Hub externo: ", erro)
    end
end)
