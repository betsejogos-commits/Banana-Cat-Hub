-- // 1. MAPEAMENTO UNIVERSAL DE SERVIÇOS DO ROBLOX
local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    HttpService = game:GetService("HttpService"),
    CollectionService = game:GetService("CollectionService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    NetworkClient = game:GetService("NetworkClient"),
    TeleportService = game:GetService("TeleportService"),
    LogService = game:GetService("LogService"),
    DataStoreService = game:GetService("DataStoreService"),
    VirtualUser = game:GetService("VirtualUser"),
    ScriptContext = game:GetService("ScriptContext"),
    ServerStorage = game:GetService("ServerStorage") or nil -- Caso o executor tenha capabilidade
}

local LocalPlayer = Services.Players.LocalPlayer
local Heartbeat = Services.RunService.Heartbeat

-- // 2. BAN & KICK SPOOFER (Virtualização de Estado)
-- Tabela global que dita as respostas falsas para qualquer script que consulte punições
_G.SpoofEnvironment = {
    IsBanned = false,
    IsKicked = false,
    ViolationsDetected = 0,
    BypassActive = true
}

-- Bloqueia variáveis globais ou atributos que o jogo tente setar para marcar o jogador
local MetatabelaOriginal = getrawmetatable(game)
local oldIndex = MetatabelaOriginal.__index
local oldNewIndex = MetatabelaOriginal.__newindex
setreadonly(MetatabelaOriginal, false)

MetatabelaOriginal.__index = newcclosure(function(self, key)
    -- Se qualquer script do jogo perguntar ao LocalPlayer ou a um Remote se o jogador está banido/kickado
    if _G.SpoofEnvironment.BypassActive then
        local keyLower = string.lower(tostring(key))
        if string.find(keyLower, "ban") or string.find(keyLower, "kick") or string.find(keyLower, "punish") then
            -- Retorna falso ou nulo, dizendo pro jogo: "Não puna o jogador, ele está limpo"
            return false
        end
    end
    return oldIndex(self, key)
end)

MetatabelaOriginal.__newindex = newcclosure(function(self, key, value)
    -- Se o Anti-Cheat tentar setar um atributo como "Banned = true" no jogador, o script intercepta e cancela
    if _G.SpoofEnvironment.BypassActive then
        local keyLower = string.lower(tostring(key))
        if string.find(keyLower, "ban") or string.find(keyLower, "kick") or string.find(keyLower, "cheat") then
            _G.SpoofEnvironment.ViolationsDetected = _G.SpoofEnvironment.ViolationsDetected + 1
            return nil -- Ignora a gravação do Ban/Kick na memória
        end
    end
    return oldNewIndex(self, key, value)
end)
setreadonly(MetatabelaOriginal, true)

-- // 3. GERADOR DE INSTÂNCIAS FANTASMAS (Remote, Local, Server e Module Spoof)
local function InjetarMódulosFantasmas()
    print("[⚡ SPOOF] Gerando canais de tráfego fantasma na memória do motor...")
    
    -- Função interna para gerar nomes aleatórios baseados no seu padrão solicitado
    local function GerarNomeAleatorio(index)
        local caracteres = "abcdefghijklmnopqrstuvwxyz"
        local sufixo = string.format("(%02d)", index)
        local base = ""
        for i = 1, 12 do
            local rand = math.random(1, #caracteres)
            base = base .. string.sub(caracteres, rand, rand)
        end
        return base .. sufixo
    end

    -- Alvos de replicação invisível para espalhar os falsos remotes e scripts
    local Destinos = {Services.ReplicatedStorage, Services.Players.LocalPlayer.PlayerGui, workspace}
    if Services.ServerStorage then table.insert(Destinos, Services.ServerStorage) end

    for i = 1, 5 do
        local nomeFalso = GerarNomeAleatorio(i)
        
        -- A. Cria e injeta falsos RemoteEvents para poluir o tráfego do Anti-Cheat
        local falsoRemote = Instance.new("RemoteEvent")
        falsoRemote.Name = nomeFalso
        falsoRemote.Parent = Destinos[math.random(1, #Destinos)]
        
        -- Conecta um ouvinte vazio para fazer o remote parecer legítimo e ativo na memória
        falsoRemote.OnClientEvent:Connect(function() end)

        -- B. Injeta representações lógicas de LocalScripts e ModuleScripts
        -- Executores avançados geram essas instâncias em nível de memória protegida (Ghost Parts)
        local falsoLocal = Instance.new("LocalScript")
        falsoLocal.Name = nomeFalso .. "_Core"
        falsoLocal.Enabled = true
        falsoLocal.Parent = falsoRemote

        local falsoModule = Instance.new("ModuleScript")
        falsoModule.Name = nomeFalso .. "_DataStore"
        falsoModule.Parent = falsoLocal
        
        -- C. Emula comportamento de ServerScript (apenas client-side spoof para enganar scanners locais)
        local falsoServerScript = Instance.new("Script")
        falsoServerScript.Name = nomeFalso .. "_ServerEngine"
        falsoServerScript.Disabled = false
        falsoServerScript.Parent = falsoRemote

        print("[✔ SPOOF] Injetado com sucesso: " .. nomeFalso)
    end
end

-- Ativa a injeção do ambiente poluído
task.spawn(InjetarMódulosFantasmas)

-- // 4. REMOVER DE ANTI-CHEAT INTEGRADO (Memory Purge)
local function RemoverAntiCheatDoJogo()
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
        for _, conn in pairs(getconnections(Services.ScriptContext.Error)) do conn:Disconnect() end
    end
    if typeof(gccollect) == "function" then gccollect() elseif collectgarbage then collectgarbage("collect") end
end
task.spawn(RemoverAntiCheatDoJogo)

-- // 5. LAYER DE BYPASS RAKNET (Tween de Redirecionamento de Posição)
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

-- // 6. FLUXO SÍNCRONO FINAL: BANANA-CAT-HUB UNDER OVERLAY
task.spawn(function()
    print("[🛡️ SYSTEM] Ambiente virtualizado com Spoof Ban/Kick. Injetando Hub externo...")
    task.wait(0.5)
    
    local sucesso, erro = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/betsejogos-commits/Banana-Cat-Hub/refs/heads/main/BananaCatHub.lua"))()
    end)
    
    if sucesso then
        print("[✔] Banana-Cat-Hub inicializado dentro da jaula de Spoofing de rede!")
    else
        warn("[❌] Erro ao subir Hub externo: ", erro)
    end
end)
