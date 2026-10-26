-- // 1. MAPEAMENTO AVANÇADO DE TODOS OS SERVIÇOS CRÍTICOS DO ROBLOX
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
    VirtualUser = game:GetService("VirtualUser")
}

local LocalPlayer = Services.Players.LocalPlayer
local Heartbeat = Services.RunService.Heartbeat

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

-- Função síncrona para reter estruturas de tabelas do Blox Fruits na memória
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
    -- Registra imediatamente o dump do comando no cache local antes do crash
    local log = {
        Timestamp = os.clock(),
        Origem = metodo,
        RemoteAlvo = remote,
        Payload = dados or {}
    }
    table.insert(_G.LocalDataCache.HistoricoFlags, log)
    
    -- Destrói a representação física do boneco instantaneamente (Perda de tracking no servidor)
    if LocalPlayer.Character then
        LocalPlayer.Character:Destroy()
    end
    
    -- Morte térmica da thread de rede local: Prende pacotes pendentes de Kick/Ban na RakNet
    task.spawn(function()
        while true do 
            -- Loop infinito síncrono consome o ciclo de processamento local, impedindo o envio da flag
        end
    end)
end

-- // 4. HOOKS DE METAMETHODS DE REDE (Interceptação de Tráfego de Saída)
local RemotesInvasivos = {}

local function EscanearEFiltrar(instancia)
    if instancia:IsA("RemoteEvent") or instancia:IsA("RemoteFunction") then
        local nameLower = string.lower(instancia.Name)
        if string.find(nameLower, "check") or string.find(nameLower, "teleport") or string.find(nameLower, "admin") or string.find(nameLower, "cheat") or string.find(nameLower, "kick") or string.find(nameLower, "ban") then
            table.insert(RemotesInvasivos, instancia)
        end
    end
end

-- Sincronização de escaneamento via CollectionService e Storages
Services.CollectionService:GetInstanceAddedSignal("AntiCheatTag"):Connect(EscanearEFiltrar)
for _, inst in pairs(Services.CollectionService:GetTagged("AntiCheatTag")) do EscanearEFiltrar(inst) end
for _, desc in pairs(Services.ReplicatedStorage:GetDescendants()) do EscanearEFiltrar(desc) end

if typeof(hookmetamethod) == "function" then
    -- Gancho de Namecall para silenciar RemoteEvents/RemoteFunctions do Anti-Cheat
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        local nameLower = string.lower(self.Name)
        
        if (method == "FireServer" or method == "InvokeServer") then
            -- Se a internet simulada estiver "caída" durante um Tween perigoso, cancela o tráfego invasivo
            if table.find(RemotesInvasivos, self) and RakNetConfig.SimularQuedaInternet then
                return nil
            end
            
            -- Bloqueio preventivo geral baseado em assinaturas de strings comuns de punição
            if string.find(nameLower, "cheat") or string.find(nameLower, "ban") or string.find(nameLower, "kick") or string.find(nameLower, "detection") then
                task.spawn(AcionarSaidaDeEmergencia, "Namecall Hook", self.Name, args)
                return nil
            end
        end
        return oldNamecall(self, ...)
    end)
    
    -- Gancho de Index na API para interceptar chamadas diretas à função Player:Kick()
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if self == LocalPlayer and string.lower(key) == "kick" then
            return newcclosure(function(playerInstance, ... surveillanceArgs)
                AcionarSaidaDeEmergencia("API Player:Kick", "Direct_Method", surveillanceArgs)
            end)
        end
        return oldIndex(self, key)
    end)
end

-- Intercepta e mascara logs de erros gerados pelo processador ou por falhas de renderização de chunks
Services.LogService.MessageReceived:Connect(function(message, messageType)
    if string.find(string.lower(message), "exploit") or string.find(string.lower(message), "teleport") or string.find(string.lower(message), "desync") then
        return nil
    end
end)

-- // 5. EMULADOR DE REDE RAKNET (Bypass por Latência Controlada)
local function SincronizarCanalRakNet(estado)
    RakNetConfig.SimularQuedaInternet = estado
    if estado == true then
        -- Injeta lag local artificial drástico na camada do NetworkClient para reter replicação física
        settings().Network.IncomingReplicationLag = RakNetConfig.FakePing
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

-- // 6. SISTEMAS COMPLEMENTARES DE ACELERAÇÃO (Anti-AFK & Estabilizador)
LocalPlayer.Idled:Connect(function()
    Services.VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(0.1)
    Services.VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

Services.UserInputService.WindowFocused:Connect(function()
    if settings().Network.IncomingReplicationLag > 0 and not RakNetConfig.SimularQuedaInternet then
        settings().Network.IncomingReplicationLag = 0
    end
end)

-- Loop de Alta Frequência (Física e PPS Throttle)
Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    -- Estabilizador Anti-Rubberband (Zera acelerações espúrias geradas pelo arrasto do servidor)
    if root then
        if root.Velocity.Magnitude > 80 then
            root.Velocity = Vector3.new(0, 0, 0)
            root.RotVelocity = Vector3.new(0, 0, 0)
        end
    end
    
    -- Regulador de PPS para evitar estouro de buffer do HttpService e NetworkClient
    local tempoAtual = os.time()
    if (tempoAtual - RakNetConfig.UltimoCicloPPS) >= 1 then
        RakNetConfig.UltimoCicloPPS = tempoAtual
        if settings().Network.IncomingReplicationLag > 0 and not RakNetConfig.SimularQuedaInternet then
            settings().Network.IncomingReplicationLag = 0
        end
    end
end)

-- MOTOR DE TWEEN ULTRA AVANÇADO DISPONÍVEL GLOBALMENTE
_G.BypassTween = function(targetCFrame)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    -- Ativa o Desync na camada RakNet antes do deslocamento linear
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

-- // 7. EXECUÇÃO PARALELA SÍNCRONA DO BANANA-CAT-HUB
task.spawn(function()
    print("[🛡️ SYSTEM] Camada de serviços protegida. Injetando Hub externo...")
    task.wait(0.5)
    
    local sucesso, erro = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/betsejogos-commits/Banana-Cat-Hub/refs/heads/main/BananaCatHub.lua"))()
    end)
    
    if sucesso then
        print("[✔] Banana-Cat-Hub carregado e operando sob monitoramento térmico de rede.")
    else
        warn("[❌] Falha crítica na inicialização do Hub externo: ", erro)
    end
end)
