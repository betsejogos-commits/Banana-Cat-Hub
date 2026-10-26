if getgenv().__BF_LOADED then
	return getgenv().__BF_RESULT
end

repeat
	wait()
until game:IsLoaded() and game.Players.LocalPlayer
-- Luraph macro stubs (LPH_ATTRIBUTES(VM(NONE)) duoc goi o 4 cho, truoc do khong duoc dinh nghia)
LPH_ATTRIBUTES = LPH_ATTRIBUTES or function(...)
	return ...
end
VM = VM or function(...)
	return ...
end

-- Nang identity thread (loi "lacking capability Plugin") + guard UI de 1 element loi khong lam dung ca script
function ElevateIdentity()
	pcall(function()
		local f = setthreadidentity or setidentity or set_thread_identity or (syn and syn.set_thread_identity) or setthreadcontext
		if f then
			f(8)
		end
	end)
end
ElevateIdentity()

-- Mo rong ban kinh Streaming: neu khong, cac Part spawn quai (EnemySpawns) va
-- chinh con quai trong Workspace.Enemies se KHONG ton tai phia client cho toi
-- khi nhan vat thuc su di toi gan (Roblox StreamingEnabled). Luc do DetectMob
-- va DetectPartSpawnMob deu tra ve nil -> farm dung im cho den khi minh tu chay
-- lai gan. Tat/no rong Streaming ngay tu dau de mob spawn xa cung duoc client
-- nhan biet va script tu di toi duoc.
pcall(function()
	workspace.StreamingEnabled = false
end)
pcall(function()
	workspace.StreamingMinRadius = 1e8
	workspace.StreamingTargetRadius = 1e8
end)

task.spawn(function()
	local env = getgenv()
	local need = {
		"getconnections", "fireclickdetector", "fireproximityprompt", "firetouchinterest", "newcclosure",
		"getrawmetatable", "getnamecallmethod", "setclipboard", "isfolder", "makefolder", "writefile",
		"readfile", "delfile", "sethiddenproperty", "getupvalues", "getupvalue", "setupvalue",
		"queue_on_teleport", "getnilinstances", "Drawing", "hookmetamethod", "request",
	}
	local miss = {}
	for _, n in ipairs(need) do
		if env[n] == nil then
			table.insert(miss, n)
		end
	end
	if not (env.setthreadidentity or env.setidentity or env.set_thread_identity) then
		table.insert(miss, "setthreadidentity")
	end
	local ok, name = pcall(function()
		return identifyexecutor and identifyexecutor() or "unknown"
	end)
	print("[BananaFix] executor:", ok and name or "unknown", "| thieu ham:", #miss > 0 and table.concat(miss, ", ") or "khong")
end)
local function uiStub()
	return setmetatable({}, {
		__index = function()
			return function() end
		end,
		__call = function() end,
	})
end
local function guardUI(obj, label)
	if type(obj) ~= "table" then
		return obj
	end
	return setmetatable({}, {
		__index = function(_, k)
			local v = obj[k]
			if type(v) ~= "function" then
				return v
			end
			return function(...)
				local res = table.pack(pcall(v, ...))
				if not res[1] then
					ElevateIdentity()
					res = table.pack(pcall(v, ...))
				end
				if not res[1] then
					warn(("[BananaFix] %s.%s failed: %s"):format(label, tostring(k), tostring(res[2])))
					return uiStub()
				end
				return guardUI(res[2], label .. "." .. tostring(k)), unpack(res, 3, res.n)
			end
		end,
		__newindex = function(_, k, v)
			obj[k] = v
		end,
	})
end

-- Quest UI check: V1 (PlayerGui.Main.Quest) + V2 (PlayerGui.TrackedQuestFrame)
-- V3 (StarterGui.Main.Quest) khong dung: day la ban mau, khong phan anh quest dang co.
local function readText(inst)
	if not inst then
		return nil
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		return inst.Text ~= "" and inst.Text or nil
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("TextLabel") and d.Text ~= "" then
			return d.Text
		end
	end
	return nil
end
function GetQuestTitle()
	local lp = game:GetService("Players").LocalPlayer
	local pg = lp and lp:FindFirstChild("PlayerGui")
	if not pg then
		return nil
	end
	-- V1
	local main = pg:FindFirstChild("Main") or pg:FindFirstChild("Main (minimal)")
	local q = main and main:FindFirstChild("Quest")
	if q and q.Visible then
		local c = q:FindFirstChild("Container")
		local qt = c and c:FindFirstChild("QuestTitle")
		local txt = readText(qt and qt:FindFirstChild("Title"))
		if txt then
			return txt
		end
	end
	-- V2
	local tr = pg:FindFirstChild("TrackedQuestFrame")
	if tr then
		local on = (tr:IsA("ScreenGui") and tr.Enabled) or (tr:IsA("GuiObject") and tr.Visible)
		local fr = tr:FindFirstChild("Frame")
		if on and fr and fr.Visible then
			return readText(fr:FindFirstChild("header"))
		end
	end
	return nil
end
local _rawHasQuest = function()
	return GetQuestTitle() ~= nil
end
local _questSeenUntil = 0
function HasQuest()
	-- Giu trang thai "co quest" trong 1s sau lan cuoi thay UI hien quest,
	-- de tranh doc UI ngay luc dang animation/lag -> tuong nham la mat quest
	-- roi goi lai TakeQuestLevel giua chung, gay farm level chap chon.
	if _rawHasQuest() then
		_questSeenUntil = tick() + 1
		return true
	end
	return tick() < _questSeenUntil
end

-- Lay TOAN BO text cua UI quest (V1 + V2), khong chi moi title.
-- Dung cho cac che do can so ten boss/mob (Elite Hunter, Rainbow Haki, CDK...)
local function collectText(root)
	local out = {}
	if not root then
		return out
	end
	local function add(i)
		if (i:IsA("TextLabel") or i:IsA("TextButton") or i:IsA("TextBox")) and i.Text ~= "" then
			out[#out + 1] = i.Text
		end
	end
	add(root)
	for _, d in ipairs(root:GetDescendants()) do
		add(d)
	end
	return out
end
function GetQuestText()
	local lp = game:GetService("Players").LocalPlayer
	local pg = lp and lp:FindFirstChild("PlayerGui")
	if not pg then
		return ""
	end
	local parts = {}
	local main = pg:FindFirstChild("Main") or pg:FindFirstChild("Main (minimal)")
	local q = main and main:FindFirstChild("Quest")
	if q and q.Visible then
		for _, t in ipairs(collectText(q)) do
			parts[#parts + 1] = t
		end
	end
	local tr = pg:FindFirstChild("TrackedQuestFrame")
	if tr then
		local on = (tr:IsA("ScreenGui") and tr.Enabled) or (tr:IsA("GuiObject") and tr.Visible)
		if on then
			for _, t in ipairs(collectText(tr)) do
				parts[#parts + 1] = t
			end
		end
	end
	return table.concat(parts, " | ")
end
-- Quest hien tai co nhac toi `name` khong (khong phan biet hoa thuong, plain find)
function QuestHas(name)
	if not name then
		return false
	end
	name = tostring(name):lower()
	if GetQuestText():lower():find(name, 1, true) then
		return true
	end
	if GetQuestTitle() and GetQuestTitle():lower():find(name, 1, true) then
		return true
	end
	return false
end
-- Dung cho Elite Hunter: dam bao dang giu quest cua boss `name`.
-- Tra ve true = co the danh boss ngay. Co cooldown de khong abandon/nhan lien tuc khi UI cap nhat cham.
local _lastEliteTake = 0
function EnsureEliteQuest(name)
	if QuestHas(name) then
		return true
	end
	if tick() - _lastEliteTake < 6 then
		return true
	end
	_lastEliteTake = tick()
	local CF = game:GetService("ReplicatedStorage").Remotes.CommF_
	pcall(function()
		if HasQuest() then
			CF:InvokeServer("AbandonQuest")
		end
		CF:InvokeServer("EliteHunter")
	end)
	task.wait(1)
	return QuestHas(name)
end

Settings = {}
HttpService = game:GetService("HttpService")
FolderName = "Banana Cat Hub"
SaveFileNameGame = "-BloxFruitBNNC.json"
SaveFileName = game.Players.LocalPlayer.Name .. SaveFileNameGame
function SaveSettings(b, t, A)
	if A ~= nil then
		Settings[b] = Settings[b] or {}
		Settings[b][t] = A
	elseif b ~= nil then
		Settings[b] = t
	end
	if not isfolder(FolderName) then
		makefolder(FolderName)
	end
	writefile(FolderName .. "/" .. SaveFileName, HttpService:JSONEncode(Settings))
end
if getgenv().Config then
	Settings = getgenv().Config
	SaveSettings()
end
function ReadSetting(tries)
	tries = tries or 0
	local b, t = pcall(function()
		if not isfolder(FolderName) then
			makefolder(FolderName)
		end
		return HttpService:JSONDecode(readfile(FolderName .. "/" .. SaveFileName))
	end)
	if b and type(t) == "table" then
		return t
	else
		if tries >= 3 then
			return {}
		end
		SaveSettings()
		return ReadSetting(tries + 1)
	end
end
Settings = ReadSetting()
getgenv().Settings = Settings
function PrepareMultiSelectList(b, t, A)
	local a = {}
	for s in pairs(b) do
		local b = t and t[s]
		if b == nil then
			a[s] = A and true or false
		else
			a[s] = b
		end
	end
	return a
end
function EnsureAllTrueDefaults(b, t)
	if type(Settings[b]) ~= "table" then
		Settings[b] = {}
	end
	local A = false
	for a, a in ipairs(t) do
		if Settings[b][a] == nil then
			Settings[b][a] = true
			A = true
		end
	end
	if A then
		for t, A in pairs(Settings[b]) do
			SaveSettings(b, t, A)
		end
	end
end
repeat
	wait()
until game:FindFirstChild("CoreGui")
repeat
	wait()
until not game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen")
repeat
	wait()
until game:IsLoaded() and (game.Players.LocalPlayer:FindFirstChild("DataLoaded"))
function FireButton(b)
	b.Selectable = true
	game:GetService("GuiService").SelectedObject = b
	game:GetService("VirtualInputManager"):SendKeyEvent(true, "Return", false, b)
	game:GetService("VirtualInputManager"):SendKeyEvent(false, "Return", false, b)
	b.Activated:Connect(function()
		game:GetService("GuiService").SelectedObject = nil
	end)
end
repeat
	wait()
until game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main (minimal)")
	or (game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main"))
local b = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main (minimal)")
	or (game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main"))
repeat
	wait()
until b:FindFirstChild("ChooseTeam")
repeat
	task.wait()
	pcall(function()
		local choose = b:FindFirstChild("ChooseTeam")
		if choose then
			local isPirate = Settings["Select Team"] == "Pirate"
			FireButton(choose.Container[isPirate and "Pirates" or "Marines"].Frame.TextButton)
			wait(1)
		end
	end)
until not b.Parent or not b:FindFirstChild("ChooseTeam") or not b.ChooseTeam.Visible
game:GetService("GuiService").SelectedObject = nil
repeat
	wait()
until game:IsLoaded() and game.Players.LocalPlayer
repeat
	wait()
until game:FindFirstChild("CoreGui")
getgenv().ExploitReq = (syn and syn.request)
	or (identifyexecutor and identifyexecutor() == "Fluxus" and request)
	or http_request
	or (http and http.request)
	or request
	or requests
getgenv().request = getgenv().request or getgenv().ExploitReq
if getgenv().LoadScript then
	return print("Double UI")
end
getgenv().CheckPlaceId = game.PlaceId == 100117331123089 and 100117331123089 or 7449423635
getgenv().CheckPlaceId2 = game.PlaceId == 4442272183 and 4442272183 or 79091703265657
getgenv().CheckPlaceId3 = game.PlaceId == 2753915549 and 2753915549 or 85211729168715
getgenv().LoadScript = true
local t = game.Players.LocalPlayer
getgenv().getupvalue = debug.getupvalue
getgenv().getupvalues = debug.getupvalues
wOrigin = game:GetService("Workspace"):WaitForChild("_WorldOrigin")
CommF = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_")
vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:connect(function()
	vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	wait(1)
	vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)
local A =
	loadstring(game:HttpGet("https://raw.githubusercontent.com/obiiyeuem/vthangsitink/refs/heads/main/zzzz.lua"))()
Main = guardUI(A.CreateMain({ Title = "Blox Fruit", Desc = " - Blox Fruit" }), "Main")
PageShop = Main.CreatePage({ Page_Name = "Shop", Page_Title = "Shop" })
getgenv().Options = A.Options
SectionShopMisc = PageShop.CreateSection("Misc Shop")
function Remote(a, s, X)
	if not a and X then
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer(s, true)
	else
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer(a, s, X)
	end
end
getgenv().tablefruitausea3 = {}
whitelistedfruit = {}
TableDevilFruit = {}
local a, s, X = next, game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GetFruits", false)
for g, g in a, s, X do
	if g.Price >= 1000000 then
		table.insert(whitelistedfruit, string.split(g.Name, "-")[1] .. " Fruit")
		getgenv().tablefruitausea3[g.Name] = g.Price
	end
	TableDevilFruit[g.Name] = false
end
getgenv().tablefruitausea3["Dragon (East)-Dragon (East)"] = 15000000
getgenv().tablefruitausea3["Dragon (West)-Dragon (West)"] = 15000000
ItemId = require(game.ReplicatedStorage.Economy.ItemId)
function CheckFruitReal(g)
	local G, f, K = next, game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GetFruits", false)
	for R, R in G, f, K do
		if R.Name == g then
			return R
		end
	end
end
SkinFruit = {}
-- spawn(function()
--     for g, g in next, require(game:GetService("ReplicatedStorage").Modules.SkinUtil.FruitSkins).Grouped do
--         for G, G in next, g do
--             getgenv().tablefruitausea3[g.StorageName] = CheckFruitReal(G.Item).Price
--             table.insert(whitelistedfruit, G.StorageName .. " Fruit")
--             SkinFruit[G.StorageName .. " Fruit"] = true
--         end
--     end
-- end)
NameWorldMaterials = {
	Ectoplasm = { [getgenv().CheckPlaceId2] = "TravelDressrosa" },
	["Magma Ore"] = { [getgenv().CheckPlaceId2] = "TravelDressrosa" },
	Leather = { [getgenv().CheckPlaceId] = "TravelZou" },
	["Scrap Metal"] = { [getgenv().CheckPlaceId] = "TravelZou" },
	["Angel Wings"] = { [getgenv().CheckPlaceId3] = "TravelMain" },
	["Fish Tail"] = { [getgenv().CheckPlaceId] = "TravelZou" },
	["Radioactive Material"] = { [getgenv().CheckPlaceId2] = "TravelDressrosa" },
	["Vampire Fang"] = { [getgenv().CheckPlaceId2] = "TravelDressrosa" },
	["Mystic Droplet"] = { [getgenv().CheckPlaceId2] = "TravelDressrosa" },
	["Mini Tusk"] = { [getgenv().CheckPlaceId] = "TravelZou" },
	Gunpowder = { [getgenv().CheckPlaceId] = "TravelZou" },
	["Demonic Wisp"] = { [getgenv().CheckPlaceId] = "TravelZou" },
	["Dragon Scale"] = { [getgenv().CheckPlaceId] = "TravelZou" },
	["Conjured Cocoa"] = { [getgenv().CheckPlaceId] = "TravelZou" },
	Bones = { [getgenv().CheckPlaceId] = "TravelZou" },
}
NameMaterials = {
	Ectoplasm = { "Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer", "Cursed Captain" },
	["Magma Ore"] = { "Lava Pirate", "Magma Ninja" },
	Leather = { "Jungle Pirate", "Musketeer Pirate" },
	["Scrap Metal"] = { "Jungle Pirate" },
	["Angel Wings"] = { "God's Guard", "Shanda", "Royal Squad", "Royal Soldier" },
	["Fish Tail"] = { "Fishman Raider", "Fishman Captain" },
	["Radioactive Material"] = { "Factory Staff" },
	["Vampire Fang"] = { "Vampire" },
	["Mystic Droplet"] = { "Sea Soldier", "Water Fighter" },
	["Mini Tusk"] = { "Mythological Pirate" },
	Gunpowder = { "Pistol Billionaire" },
	["Demonic Wisp"] = { "Demonic Soul" },
	["Dragon Scale"] = { "Dragon Crew Archer", "Dragon Crew Warrior" },
	["Conjured Cocoa"] = { "Cocoa Warrior", "Chocolate Bar Battler" },
	Bones = { "Reborn Skeleton", "Demonic Soul", "Living Zombie", "Posessed Mummy" },
}
TableMaterials = {}
for g, G in next, NameMaterials, nil do
	table.insert(TableMaterials, g)
end
REDEEM_CODES = {
	"EASTEREXP",
	"BANEXPLOIT",
	"NOMOREHACKS",
	"WildDares",
	"BossBuild",
	"GetPranked",
	"EARN_FRUITS",
	"Sub2UncleKizaru",
	"FIGHT4FRUIT",
	"kittgaming",
	"TRIPLEABUSE",
	"Sub2CaptainMaui",
	"Sub2Fer999",
	"Enyu_is_Pro",
	"Magicbus",
	"JCWK",
	"Starcodeheo",
	"Bluxxy",
	"SUB2GAMERROBOT_EXP1",
	"Sub2NoobMaster123",
	"Sub2Daigrock",
	"Axiore",
	"TantaiGaming",
	"StrawHatMaine",
	"Sub2OfficialNoobie",
	"TheGreatAce",
	"SEATROLLIN",
	"24NOADMIN",
	"ADMIN_TROLL",
	"NEWTROLL",
	"SECRET_ADMIN",
	"staffbattle",
	"NOEXPLOIT",
	"NOOB2ADMIN",
	"CODESLIDE",
	"fruitconcepts",
}
SectionShopMisc.CreateButton({ Title = "Redeem Code" }, function()
	LPH_ATTRIBUTES(VM(NONE))
	for _, v in REDEEM_CODES do
		game.ReplicatedStorage.Remotes.Redeem:InvokeServer(v)
	end
end)

SectionShopMisc.CreateButton({ Title = "Teleport Old World" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ [1] = "TravelMain" }))
end)

SectionShopMisc.CreateButton({ Title = "Teleport New World" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ [1] = "TravelDressrosa" }))
end)

SectionShopMisc.CreateButton({ Title = "Teleport Thid Sea" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ [1] = "TravelZou" }))
end)

SectionShopMisc.CreateButton({ Title = "Buy Dual Flintlock" }, function()
	game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyItem", "Dual Flintlock")
end)

SectionShopMisc.CreateButton({ Title = "Reroll Race" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BlackbeardReward", "Reroll", "2")
end)

SectionShopMisc.CreateButton({ Title = "Reset Stats" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BlackbeardReward", "Refund", "1")
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BlackbeardReward", "Refund", "2")
end)

SectionShopMisc.CreateButton({ Title = "Buy Race Cyborg" }, function()
	game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CyborgTrainer", "Buy")
end)

SectionShopMisc.CreateButton({ Title = "Buy Race Ghoul" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Ectoplasm", "BuyCheck", 4)
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Ectoplasm", "Change", 4)
end)

SectionShopFighting = PageShop.CreateSection("Fighting Shop")
local g = {}
getgenv().notsave = g
local G = {
	BuyBlackLeg = "Dark Step Teacher",
	BuySuperhuman = "Martial Arts Master",
	BuySharkmanKarate = "Sharkman Teacher",
	DragonClaw = "Sabi",
	BuyDragonTalon = "Uzoth",
	BuyElectro = "Mad Scientist",
	BuyFishmanKarate = "Water Kung-fu Teacher",
	BuyDeathStep = "Phoeyu, the Reformed",
	BuyGodhuman = "Ancient Monk",
	BuyElectricClaw = "Previous Hero",
	BuySanguineArt = "Shafi",
}
NPCManager = require(game:GetService("ReplicatedStorage").NPCManager)
function DetectNpc(f)
	local K = t.Character and (t.Character:FindFirstChild("HumanoidRootPart"))
	if not K then
		return
	end
	local R, m, E, l = next, { workspace.NPCs, game:GetService("ReplicatedStorage").NPCs }, 1 / 0
	for Q, Q in R, m, nil do
		local R, m, S = next, Q:GetChildren()
		for Q, L in R, m, S do
			if
				L:GetAttribute("NPCLoaded")
				and (L:GetAttribute("NPCReady"))
				and L.Name == f
				and (L:FindFirstChild("HumanoidRootPart"))
			then
				Q = (K.Position - L.HumanoidRootPart.Position).Magnitude
				if Q < E then
					E, l = Q, L
				end
			end
		end
	end
	if not l then
		return NPCManager.getNPCsByName(f)[1]._modelState._instance
	end
	return l, E
end

SectionShopFighting.CreateToggle({ Title = "Black Leg", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["Black Leg"] and (task.wait()) do
				local K, K = pcall(function()
					local R = DetectNpc(G.BuyBlackLeg)
					if t:DistanceFromCharacter(R.HumanoidRootPart.Position) < 8 then
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyBlackLeg")
					end
					getgenv().BackupTween(R.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
				if K then
					print(K)
				end
			end
		end)
	end
	g["Black Leg"] = f
end)

SectionShopFighting.CreateToggle({ Title = "Fishman Karate", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["Fishman Karate"] and (task.wait()) do
				local K, K = pcall(function()
					local R = DetectNpc(G.BuyFishmanKarate)
					if t:DistanceFromCharacter(R.HumanoidRootPart.Position) < 8 then
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyFishmanKarate")
					end
					getgenv().BackupTween(R.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
				if K then
					print(K)
				end
			end
		end)
	end
	g["Fishman Karate"] = f
end)

SectionShopFighting.CreateToggle({ Title = "Electro", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g.Electro and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuyElectro)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyElectro")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g.Electro = f
end)

SectionShopFighting.CreateToggle({ Title = "Dragon Breath", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g.DragonClaw and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.DragonClaw)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "1")
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "2")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g.DragonClaw = f
end)

SectionShopFighting.CreateToggle({ Title = "SuperHuman", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g.SuperHuman and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuySuperhuman)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						Remote("BuySuperhuman")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g.SuperHuman = f
end)

SectionShopFighting.CreateToggle({ Title = "Death Step", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["Death Step"] and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuyDeathStep)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						Remote("BuyDeathStep")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g["Death Step"] = f
end)

SectionShopFighting.CreateToggle({ Title = "Sharkman Karate", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["Sharkman Karate"] and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuySharkmanKarate)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						Remote("BuySharkmanKarate")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g["Sharkman Karate"] = f
end)

SectionShopFighting.CreateToggle({ Title = "Electric Claw", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["Electric Claw"] and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuyElectricClaw)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						Remote("BuyElectricClaw")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g["Electric Claw"] = f
end)

SectionShopFighting.CreateToggle({ Title = "Dragon Talon", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["Dragon Talon"] and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuyDragonTalon)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						Remote("BuyDragonTalon")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g["Dragon Talon"] = f
end)
SectionShopFighting.CreateToggle({ Title = "God Human", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["God Human"] and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuyGodhuman)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						Remote("BuyGodhuman")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g["God Human"] = f
end)
SectionShopFighting.CreateToggle({ Title = "Sanguine Art", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["Sanguine Art"] and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuySanguineArt)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						Remote("BuySanguineArt")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g["Sanguine Art"] = f
end)
SectionShopAbilities = PageShop.CreateSection("Abilities Shop")
SectionShopAbilities.CreateButton({ Title = "Skyjump [ $10,000 Beli ]" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyHaki", "Geppo")
end)
SectionShopAbilities.CreateButton({ Title = "Buso Haki [ $25,000 Beli ]" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyHaki", "Buso")
end)
SectionShopAbilities.CreateButton({ Title = "Observation haki [ $750,000 Beli ]" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("KenTalk", "Buy")
end)
SectionShopAbilities.CreateButton({ Title = "Soru [ $100,000 Beli ]" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyHaki", "Soru")
end)
PageStatusAndServer = Main.CreatePage({ Page_Name = "Status And Server", Page_Title = "Status And Server" })
-- ===================== BananaCat Status UI (v4) =====================
do
	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer
	local env = getgenv()

	local UI_KEY = "Show BananaCat Status UI"
	local BLUE = Color3.fromRGB(70, 140, 255)
	local BG = Color3.fromRGB(10, 14, 26)

	-- 1) Chuỗi ưu tiên (mỗi lúc chỉ 1 cái chạy, chiếm StackFarm = false)
	local CHAIN = {
		"Auto New World",
		"Collect Chest When Server Spawn God's Chalice or Fist of Darkness",
		"Auto Third World", "Attack Darkbeard", "Summon Darkbeard",
		"Attack Rip Indra", "Auto Touch Pad Haki", "Auto Summon Rip Indra",
		"Attack Soul Reaper", "Summon Soul Reaper", "Attack Dough King", "Summon Dough King",
		"Auto Elite Hunter", "Auto Factory", "Auto Pirate Raid", "Teleport To Fruit",
		"Auto Quest Dojo Trainer",
	}
	-- 2) Nhóm bị chặn bởi StackFarmOther (bị tạm dừng khi chuỗi ưu tiên đang chạy)
	local GATED_OTHER = {
		"Auto Collect Egg Easter", "Auto Fishing", "Auto Accept Quest Fishing",
		"Auto Attack All Mob and Boss", "Auto Chest", "Kill Mob",
	}
	-- 3) Nhóm farm chạy vòng lặp riêng (bật = đang chạy)
	local INDEPENDENT = {
		"Auto Quest Dragon Hunter", "Auto Collect Berry", "Auto Chest Hop",
		"Auto Buy Chip and Attack Law", "Auto UP Observation V2", "Farm Observation",
		"Farm Observation [ Hop Server ]", "Kill Boss", "Kill All Boss",
		"Auto Raid", "Auto Multi Raid", "Auto Awake Fruit", "Auto Join Dungeon", "Auto Attack Dungeon",
		"Auto Sea Event", "Auto Sea Event With Friend", "Auto Find Mirage", "Auto Spawn Kitsune Island",
		"Auto Summon Soul Ember", "Auto Collect Soul Ember", "Auto Trade Azure Ember",
		"Auto Find Leviathan", "Multi Find Leviathan", "Auto Start Leviathan", "Auto Attack Leviathan",
		"Auto Destroy IDK", "Auto Upgrade Race V2-V3", "Auto Upgrade Race V2-V3 Draco",
		"Auto Trial", "Auto Trial Draco", "Multi Trial", "Auto Pull Lever",
		"Auto Get Fully Cyborg", "Auto Get Cyborg", "Auto Get Ghoul",
		"Auto Finish Train Quest", "Auto Finish Train Draco Quest",
		"Auto Trade Bone", "Auto Get Rainbow Haki", "Auto Soul Guitar", "Auto CDK", "Auto Yama",
		"Auto Tushita", "Auto TTK", "Auto Saber", "Auto Craft Item Shark Anchor", "Auto Yoru Mini",
		"Auto Farm Mastery 600 Melees", "Auto Farm Mastery 600 Sword In Inventory",
		"Auto Upgrade Sword Inventory", "Auto Upgrade Gun Inventory",
		"Auto Crafting Volcanic Magnet", "Auto Find Prehistoric Island", "Auto Event Prehistoric Island",
		"Auto Collect Bone", "Auto Collect Egg",
	}

	-- ---------- Owner của chuỗi ưu tiên ----------
	-- Gọi ngay sau dòng `StackFarm = false` của từng nhánh: BananaOwner("Tên toggle")
	local owner
	function env.BananaOwner(name)
		owner = name
	end
	BananaOwner = env.BananaOwner

	local override, overrideUntil = nil, 0
	function env.SetBananaStatus(text, ttl)
		override = text and tostring(text) or nil
		overrideUntil = tick() + (ttl or 4)
	end

	local hopDepth, teleportUntil = 0, 0
	pcall(function()
		lp.OnTeleport:Connect(function()
			teleportUntil = tick() + 8
		end)
	end)
	local wrapped = {}
	local function hookHop()
		for _, name in ipairs({ "HopServer", "HopLessAll" }) do
			local cur = env[name]
			if type(cur) == "function" and wrapped[name] ~= cur then
				local orig = cur
				local new = function(...)
					hopDepth = hopDepth + 1
					local r = table.pack(pcall(orig, ...))
					hopDepth = math.max(0, hopDepth - 1)
					if not r[1] then
						error(r[2], 0)
					end
					return table.unpack(r, 2, r.n)
				end
				wrapped[name] = new
				env[name] = new
			end
		end
	end

	-- ---------- Theo dõi di chuyển (fly) / đánh mob ----------
	local lastMoveCF, lastMoveT = nil, 0
	local lastBoatCF, lastBoatT = nil, 0
	local lastMob, lastMobT = nil, 0
	local lastFind, lastFindT = nil, 0

	local function mobName(E)
		if typeof(E) ~= "Instance" then
			return nil
		end
		if E:IsA("Model") then
			return E.Name
		end
		local p = E.Parent
		if p and p:IsA("Model") then
			return p.Name
		end
		return E.Name
	end
	local function onAttack(E)
		local n = mobName(E)
		if n then
			lastMob, lastMobT = n, tick()
		end
	end
	local function onMove(P)
		if typeof(P) == "CFrame" then
			lastMoveCF, lastMoveT = P, tick()
		end
	end
	local function onBoat(_, F)
		if typeof(F) == "CFrame" then
			lastBoatCF, lastBoatT = F, tick()
		end
	end
	local function onFind(Q)
		local txt
		if type(Q) == "string" then
			txt = Q
		elseif type(Q) == "table" then
			local names = {}
			for i = 1, math.min(#Q, 2) do
				if type(Q[i]) == "string" then
					names[#names + 1] = Q[i]
				end
			end
			if #names > 0 then
				txt = table.concat(names, "/")
			end
		end
		if txt then
			lastFind, lastFindT = txt, tick()
		end
	end

	local function wrap(orig, pre)
		return function(...)
			pcall(pre, ...)
			return orig(...)
		end
	end

	-- Các hàm được định nghĩa muộn nên bọc dần trong vòng lặp (chỉ bọc 1 lần cho mỗi hàm)
	local wTo, wBackup, wSize, wClick, wShoot, wDetect, wBoat
	local function hookMovement()
		if type(toTarget) == "function" and toTarget ~= wTo then
			wTo = wrap(toTarget, onMove)
			toTarget = wTo
		end
		if type(env.BackupTween) == "function" and env.BackupTween ~= wBackup then
			wBackup = wrap(env.BackupTween, onMove)
			env.BackupTween = wBackup
		end
		if type(sizepart) == "function" and sizepart ~= wSize then
			wSize = wrap(sizepart, onAttack)
			sizepart = wSize
		end
		if type(env.ClickM1) == "function" and env.ClickM1 ~= wClick then
			wClick = wrap(env.ClickM1, onAttack)
			env.ClickM1 = wClick
		end
		if type(ShootM1) == "function" and ShootM1 ~= wShoot then
			wShoot = wrap(ShootM1, onAttack)
			ShootM1 = wShoot
		end
		if type(DetectMob) == "function" and DetectMob ~= wDetect then
			wDetect = wrap(DetectMob, onFind)
			DetectMob = wDetect
		end
		if type(manageTween) == "function" and manageTween ~= wBoat then
			wBoat = wrap(manageTween, onBoat)
			manageTween = wBoat
		end
	end

	-- Tên đảo gần điểm đến nhất
	local locCache, locT = {}, 0
	local function placeName(cf)
		if typeof(cf) ~= "CFrame" then
			return "?"
		end
		if tick() - locT > 5 then
			locT = tick()
			locCache = {}
			pcall(function()
				for _, p in ipairs(workspace._WorldOrigin.Locations:GetChildren()) do
					if p:IsA("BasePart") then
						locCache[#locCache + 1] = { p.Name, p.Position }
					end
				end
			end)
		end
		local pos = cf.Position
		local best, bd = nil, math.huge
		for _, e in ipairs(locCache) do
			local dx, dz = e[2].X - pos.X, e[2].Z - pos.Z
			local d = math.sqrt(dx * dx + dz * dz)
			if d < bd then
				best, bd = e[1], d
			end
		end
		if best and bd < 1500 then
			return best
		end
		return string.format("%d, %d, %d", math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))
	end

	-- ---------- Tính toggle farm đang HOẠT ĐỘNG ----------
	local function on(k)
		return Settings[k] == true
	end

	local function computeActive()
		local out = {}
		local stackFarm = StackFarm ~= false
		local stackOther = StackFarmOther ~= false

		-- Chuỗi ưu tiên đang chiếm quyền: chỉ hiện đúng nhánh đang chạy
		if not stackFarm or not stackOther then
			local name = owner
			if not (name and on(name)) then
				name = nil
				for _, k in ipairs(CHAIN) do
					if on(k) then
						name = k
						break
					end
				end
			end
			if name then
				out[#out + 1] = name
			end
		end

		-- Level farm: chỉ chạy khi StackFarm đang mở
		if stackFarm and on("Start Farm") then
			if on("Farm Material") then
				out[#out + 1] = "Farm Material : " .. tostring(Settings["Select Material"] or "?")
			else
				out[#out + 1] = "Start Farm : " .. tostring(Settings["Select Method Farm"] or "Level Farm")
			end
			if on("Farm Mastery") then
				out[#out + 1] = "Farm Mastery"
			end
		end

		-- Nhóm bị tạm dừng khi chuỗi ưu tiên chạy
		if stackOther then
			for _, k in ipairs(GATED_OTHER) do
				if on(k) then
					out[#out + 1] = k
				end
			end
		end

		-- Nhóm chạy vòng lặp riêng
		for _, k in ipairs(INDEPENDENT) do
			if on(k) then
				out[#out + 1] = k
			end
		end
		return out
	end

	local function autoStatus(active)
		if hopDepth > 0 then
			return "Hopping server..."
		end
		if tick() < teleportUntil then
			return "Teleporting..."
		end
		local char = lp.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return "Waiting for respawn..."
		end

		local now = tick()
		local act = active[1]
		local suffix = act and (" | " .. act) or ""

		-- Đang đánh mob / boss (mọi chế độ farm): ghi rõ tên
		if lastMob and now - lastMobT < 1.5 then
			return "Fighting " .. lastMob .. suffix
		end
		-- Đang lái thuyền
		if lastBoatCF and now - lastBoatT < 1.5 then
			return "Sailing boat to " .. placeName(lastBoatCF) .. suffix
		end
		-- Đang bay/tween tới điểm đến
		if lastMoveCF and now - lastMoveT < 1.0 then
			local find = (lastFind and now - lastFindT < 2) and (" (find " .. lastFind .. ")") or ""
			return "Traveling to " .. placeName(lastMoveCF) .. find .. suffix
		end

		-- Không di chuyển / không đánh: mô tả việc đang làm
		if not act then
			return "Idle"
		end
		if string.sub(act, 1, 10) == "Start Farm" then
			local okQ, quest = pcall(GetQuestTitle)
			if okQ and quest then
				return act .. " | waiting mob : " .. string.sub(tostring(quest), 1, 50)
			end
			return act .. " | taking quest..."
		end
		return "Running : " .. act
	end

	-- ---------- UI ----------
	local function getParent()
		if gethui then
			local ok, ui = pcall(gethui)
			if ok and ui then
				return ui
			end
		end
		local ok, core = pcall(function()
			return game:GetService("CoreGui")
		end)
		if ok and core then
			return core
		end
		return lp:WaitForChild("PlayerGui")
	end

	local parent = getParent()
	local old = parent:FindFirstChild("BananaCatStatusUI")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "BananaCatStatusUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = Settings[UI_KEY] ~= false
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Name = "Main"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 12)
	frame.Size = UDim2.new(0.9, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = BG
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(480, math.huge)
	sizeLimit.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = BLUE
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 22)
	padding.PaddingRight = UDim.new(0, 22)
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.Parent = frame
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = frame

	local function makeLabel(text, color, size, order)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.Font = Enum.Font.GothamBold
		l.Text = text
		l.TextColor3 = color
		l.TextSize = size
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.LayoutOrder = order
		l.Parent = frame
		return l
	end

	makeLabel("BananaCat Status", BLUE, 20, 1)
	local statusLabel = makeLabel("Status : ...", Color3.fromRGB(255, 255, 255), 18, 2)

	local lastStatus
	local function refresh()
		local active = computeActive()
		local text = (override and tick() < overrideUntil) and override or autoStatus(active)
		local st = "Status : " .. text
		if st ~= lastStatus then
			lastStatus = st
			statusLabel.Text = st
		end
	end

	task.spawn(function()
		while gui.Parent do
			pcall(hookHop)
			pcall(hookMovement)
			pcall(refresh)
			task.wait(0.3)
		end
	end)

	-- ---------- Toggle ở đầu tab Status And Server ----------
	local SectionStatusUI = PageStatusAndServer.CreateSection("BananaCat Status UI")
	SectionStatusUI.CreateToggle({
		Title = "Show BananaCat Status UI",
		Desc = "Show what the script is doing at the top of the screen",
		Default = Settings[UI_KEY] ~= false,
	}, function(v)
		SaveSettings(UI_KEY, v)
		gui.Enabled = v
	end)
end
-- ===================== end BananaCat Status UI =====================
SectionStatus = PageStatusAndServer.CreateSection("Status")
TimerLabel = SectionStatus.CreateLabel({ Title = "Timer" })
TimerServerLabel = SectionStatus.CreateLabel({ Title = "Timer Server" })
NextTimerServerLabel = SectionStatus.CreateLabel({ Title = "Next Time Spawn Fist of Darkness or God's Chalice" })
StatusEliteHunter = SectionStatus.CreateLabel({ Title = "Elite" })
StatusTyrant = SectionStatus.CreateLabel({ Title = "Eyes Summon Tyrant" })
StatusKatakuri = SectionStatus.CreateLabel({ Title = "Summon Katakuri" })
Statusspy = SectionStatus.CreateLabel({ Title = "Status SPY" })
StatusMirage = SectionStatus.CreateLabel({ Title = "Mirage" })
StatusPrehistoricIsland = SectionStatus.CreateLabel({ Title = "Prehistoric Island" })
StatusFrozenDimension = SectionStatus.CreateLabel({ Title = "Frozen Dimension" })
StatusMoon = SectionStatus.CreateLabel({ Title = "Moon" })
StatusGear = SectionStatus.CreateLabel({ Title = "Acient One Status" })
SectionServer = PageStatusAndServer.CreateSection("Server")
SectionServer.CreateButton({ Title = "Open Gui Server Browser (Low Player and Ping)" }, function()
	local G = game:GetService("HttpService")
	game:GetService("TeleportService")
	local f, K = game:GetService("Players"), game:GetService("TweenService")
	local R, R, m = f.LocalPlayer, game.PlaceId, syn and syn.request or http_request or request
	if not m then
		warn("[ServerBrowser] Executor does not support http_request")
		return
	end
	if game.CoreGui:FindFirstChild("SB_UI") then
		game.CoreGui.SB_UI:Destroy()
	end
	local E, l, Q =
		{ servers = {}, cursor = nil, finished = false, lastUpdate = 0, pages = 0 },
		{
			CACHE_TIME = 60,
			MAX_SHOW = 50,
			PAGE_DELAY = 5,
			RETRY_MAX = 4,
			RETRY_BASE = 2,
			RETRY_JITTER = 5,
			RATE_COOLDOWN = 30,
		},
		{
			BG = Color3.fromRGB(10, 11, 16),
			SURFACE = Color3.fromRGB(13, 14, 20),
			ROW = Color3.fromRGB(16, 17, 26),
			ROW_HOVER = Color3.fromRGB(20, 22, 35),
			ROW_TOP = Color3.fromRGB(10, 22, 34),
			BORDER = Color3.fromRGB(28, 31, 48),
			BORDER_HOV = Color3.fromRGB(0, 80, 120),
			CYAN = Color3.fromRGB(0, 212, 255),
			CYAN_DIM = Color3.fromRGB(0, 80, 120),
			GREEN = Color3.fromRGB(0, 204, 102),
			GREEN_GLOW = Color3.fromRGB(0, 255, 136),
			AMBER = Color3.fromRGB(255, 170, 0),
			RED = Color3.fromRGB(255, 68, 85),
			TEXT_PRI = Color3.fromRGB(232, 234, 240),
			TEXT_SEC = Color3.fromRGB(80, 90, 120),
			TEXT_DIM = Color3.fromRGB(45, 52, 82),
		}
	local function S(L, d, I)
		local _ = Instance.new(L)
		for L, o in pairs(d or {}) do
			_[L] = o
		end
		if I then
			_.Parent = I
		end
		return _
	end
	local function L(d, I)
		return S("UICorner", { CornerRadius = UDim.new(0, d) }, I)
	end
	local function d(I, _, o, V)
		return S("UIStroke", { Thickness = I, Color = _, Transparency = o or 0 }, V)
	end
	local function I(_, o, V, N, y)
		K:Create(_, TweenInfo.new(V or 0.15, N or Enum.EasingStyle.Quad, y or Enum.EasingDirection.Out), o):Play()
	end
	local function K(_, o, V)
		_.MouseEnter:Connect(function()
			I(_, { BackgroundColor3 = V })
		end)
		_.MouseLeave:Connect(function()
			I(_, { BackgroundColor3 = o })
		end)
	end
	local function _()
		return math.random() * l.RETRY_JITTER
	end
	local o = S(
		"ScreenGui",
		{ Name = "SB_UI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true },
		game.CoreGui
	)
	local V = S(
		"Frame",
		{
			Name = "Window",
			Size = UDim2.new(0, 580, 0, 500),
			Position = UDim2.new(0.5, -290, 0.5, -250),
			BackgroundColor3 = Q.SURFACE,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		},
		o
	)
	L(4, V)
	d(1, Q.BORDER, 0, V)
	do
		local N, y, x
		V.InputBegan:Connect(function(k)
			if k.UserInputType == Enum.UserInputType.MouseButton1 then
				N = true
				y = k.Position
				x = V.Position
			end
		end)
		V.InputEnded:Connect(function(k)
			local P, e = k.UserInputType, Enum.UserInputType.MouseButton1
			if P == e then
				N = false
			end
		end)
		game:GetService("UserInputService").InputChanged:Connect(function(k)
			if N and k.UserInputType == Enum.UserInputType.MouseMovement then
				local N = k.Position - y
				V.Position = UDim2.new(x.X.Scale, x.X.Offset + N.X, x.Y.Scale, x.Y.Offset + N.Y)
			end
		end)
	end
	f = S("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Q.BG, BorderSizePixel = 0 }, V)
	S(
		"TextLabel",
		{
			Size = UDim2.new(0, 300, 0, 18),
			Position = UDim2.new(0, 18, 0, 9),
			BackgroundTransparency = 1,
			Text = "SERVER BROWSER",
			TextColor3 = Q.TEXT_PRI,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		},
		f
	)
	S(
		"TextLabel",
		{
			Size = UDim2.new(0, 360, 0, 14),
			Position = UDim2.new(0, 18, 0, 30),
			BackgroundTransparency = 1,
			Text = "CACHE PAGE \194\183 LOAD MORE \194\183 LOWEST PLAYER / PING",
			TextColor3 = Q.TEXT_DIM,
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
		},
		f
	)
	local N = S(
		"TextButton",
		{
			Size = UDim2.new(0, 28, 0, 28),
			Position = UDim2.new(1, -42, 0, 12),
			BackgroundColor3 = Color3.fromRGB(26, 13, 13),
			BorderSizePixel = 0,
			Text = "X",
			TextColor3 = Q.RED,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
		},
		f
	)
	L(3, N)
	K(N, Color3.fromRGB(26, 13, 13), Color3.fromRGB(60, 20, 20))
	N.MouseButton1Click:Connect(function()
		o:Destroy()
	end)
	f = S(
		"Frame",
		{
			Size = UDim2.new(1, 0, 0, 42),
			Position = UDim2.new(0, 0, 0, 52),
			BackgroundColor3 = Color3.fromRGB(11, 12, 17),
			BorderSizePixel = 0,
		},
		V
	)
	local o = S(
		"Frame",
		{
			Size = UDim2.new(0, 6, 0, 6),
			Position = UDim2.new(0, 14, 0.5, -3),
			BackgroundColor3 = Q.TEXT_DIM,
			BorderSizePixel = 0,
		},
		f
	)
	L(99, o)
	local N, y =
		S(
			"TextLabel",
			{
				Size = UDim2.new(1, -300, 1, 0),
				Position = UDim2.new(0, 26, 0, 0),
				BackgroundTransparency = 1,
				Text = "READY",
				TextColor3 = Q.TEXT_SEC,
				Font = Enum.Font.Gotham,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			f
		),
		S(
			"TextButton",
			{
				Size = UDim2.new(0, 82, 0, 26),
				Position = UDim2.new(1, -270, 0.5, -13),
				BackgroundColor3 = Color3.fromRGB(14, 22, 40),
				BorderSizePixel = 0,
				Text = "REFRESH",
				TextColor3 = Color3.fromRGB(100, 140, 200),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
			},
			f
		)
	L(3, y)
	K(y, Color3.fromRGB(14, 22, 40), Color3.fromRGB(10, 30, 55))
	local x = S(
		"TextButton",
		{
			Size = UDim2.new(0, 82, 0, 26),
			Position = UDim2.new(1, -182, 0.5, -13),
			BackgroundColor3 = Color3.fromRGB(16, 32, 24),
			BorderSizePixel = 0,
			Text = "LOAD MORE",
			TextColor3 = Q.GREEN,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
		},
		f
	)
	L(3, x)
	K(x, Color3.fromRGB(16, 32, 24), Color3.fromRGB(10, 48, 28))
	local k = S(
		"TextButton",
		{
			Size = UDim2.new(0, 82, 0, 26),
			Position = UDim2.new(1, -94, 0.5, -13),
			BackgroundColor3 = Color3.fromRGB(38, 18, 18),
			BorderSizePixel = 0,
			Text = "RESET",
			TextColor3 = Q.RED,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
		},
		f
	)
	L(3, k)
	K(k, Color3.fromRGB(38, 18, 18), Color3.fromRGB(60, 20, 20))
	local P = S(
		"Frame",
		{
			Size = UDim2.new(1, 0, 0, 24),
			Position = UDim2.new(0, 0, 0, 94),
			BackgroundColor3 = Color3.fromRGB(11, 12, 17),
			BorderSizePixel = 0,
		},
		V
	)
	local function e(Y, H, B)
		S(
			"TextLabel",
			{
				Size = UDim2.new(0, B, 1, 0),
				Position = UDim2.new(0, H, 0, 0),
				BackgroundTransparency = 1,
				Text = Y,
				TextColor3 = Q.TEXT_DIM,
				Font = Enum.Font.GothamBold,
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			P
		)
	end
	e("#", 14, 28)
	e("JOB ID", 42, 170)
	e("PLAYERS", 220, 80)
	e("PING", 310, 60)
	local P = S(
		"ScrollingFrame",
		{
			Size = UDim2.new(1, -8, 1, -172),
			Position = UDim2.new(0, 4, 0, 118),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Q.CYAN_DIM,
			CanvasSize = UDim2.new(0, 0, 0, 0),
		},
		V
	)
	local e = S("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, P)
	S(
		"UIPadding",
		{
			PaddingTop = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 6),
		},
		P
	)
	f = S(
		"Frame",
		{
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 1, -30),
			BackgroundColor3 = Color3.fromRGB(10, 11, 15),
			BorderSizePixel = 0,
		},
		V
	)
	local Y, H, B =
		S(
			"TextLabel",
			{
				Size = UDim2.new(0.5, 0, 1, 0),
				Position = UDim2.new(0, 14, 0, 0),
				BackgroundTransparency = 1,
				Text = "PLACE \194\183 " .. tostring(R),
				TextColor3 = Q.TEXT_DIM,
				Font = Enum.Font.Gotham,
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			f
		),
		S(
			"TextLabel",
			{
				Size = UDim2.new(0.5, -14, 1, 0),
				Position = UDim2.new(0.5, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = "SHOWING 0 / 0",
				TextColor3 = Q.TEXT_DIM,
				Font = Enum.Font.Gotham,
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Right,
			},
			f
		),
		S(
			"Frame",
			{
				Size = UDim2.new(1, 0, 1, -52),
				Position = UDim2.new(0, 0, 0, 52),
				BackgroundColor3 = Q.SURFACE,
				BackgroundTransparency = 0.05,
				ZIndex = 20,
				Visible = false,
			},
			V
		)
	local f, Z =
		S(
			"TextLabel",
			{
				Size = UDim2.new(1, -20, 0, 36),
				Position = UDim2.new(0, 10, 0.5, 10),
				BackgroundTransparency = 1,
				Text = "SCANNING SERVERS...",
				TextColor3 = Q.CYAN,
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = true,
				ZIndex = 21,
			},
			B
		),
		S(
			"Frame",
			{
				Size = UDim2.new(1, -8, 0, 28),
				Position = UDim2.new(0, 4, 0, 118),
				BackgroundColor3 = Color3.fromRGB(38, 24, 6),
				BorderSizePixel = 0,
				ZIndex = 15,
				Visible = false,
			},
			V
		)
	L(3, Z)
	d(1, Q.AMBER, 0.4, Z)
	local C = S(
		"TextLabel",
		{
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.new(0, 6, 0, 0),
			BackgroundTransparency = 1,
			Text = "\226\143\179 429 RATE LIMITED \226\128\148 WAITING...",
			TextColor3 = Q.AMBER,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 16,
		},
		Z
	)
	local function J(F)
		C.Text = F
		Z.Visible = true
		P.Position = UDim2.new(0, 4, 0, 150)
		P.Size = UDim2.new(1, -8, 1, -204)
	end
	local function F()
		Z.Visible = false
		P.Position = UDim2.new(0, 4, 0, 118)
		P.Size = UDim2.new(1, -8, 1, -172)
	end
	local q = S(
		"Frame",
		{
			Size = UDim2.new(0, 360, 0, 36),
			Position = UDim2.new(0.5, -180, 1, -50),
			BackgroundColor3 = Color3.fromRGB(10, 26, 40),
			BorderSizePixel = 0,
			ZIndex = 30,
			Visible = false,
		},
		V
	)
	L(3, q)
	local V = S(
		"TextLabel",
		{
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.new(0, 6, 0, 0),
			BackgroundTransparency = 1,
			Text = "READY",
			TextColor3 = Q.CYAN,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextWrapped = true,
			ZIndex = 31,
		},
		q
	)
	local c
	local function D(r, n)
		if c then
			task.cancel(c)
		end
		V.Text = r
		V.TextColor3 = n or Q.CYAN
		q.Visible = true
		c = task.delay(3.5, function()
			q.Visible = false
		end)
	end
	local function V(q, c)
		N.Text = q
		o.BackgroundColor3 = c or Q.TEXT_DIM
	end
	local function o(N)
		return ({
			RATE_LIMIT = "429 RATE LIMITED \226\128\148 TOO MANY REQUESTS",
			FORBIDDEN = "403 FORBIDDEN \226\128\148 ACCESS BLOCKED",
			UNAUTHORIZED = "401 UNAUTHORIZED",
			SERVER_ERROR = "5xx ROBLOX SERVER ERROR",
			NETWORK_ERROR = "NETWORK / EXECUTOR ERROR",
			INVALID_JSON = "INVALID JSON RESPONSE",
			EMPTY_BODY = "EMPTY RESPONSE BODY",
		})[N] or "REQUEST FAILED: " .. tostring(N)
	end
	local function N(q, c)
		local r = 0
		for n = 0, l.RETRY_MAX, 1 do
			local u, W = pcall(function()
				return m({
					Url = q,
					Method = "GET",
					Headers = { ["User-Agent"] = "Mozilla/5.0", Accept = "application/json" },
				})
			end)
			if not u or not W then
				return nil, "NETWORK_ERROR"
			end
			u = W.StatusCode or W.Status or 0
			if u == 429 then
				r += 1
				if n >= l.RETRY_MAX then
					return nil, "RATE_LIMIT"
				end
				local m = if r >= 2 then l.RATE_COOLDOWN + _() else math.pow(l.RETRY_BASE, n + 1) + _()
				local _ = string.format(
					"\226\143\179 429 RATE LIMITED \226\128\148 WAITING %.0fs THEN RETRYING (%d/%d)",
					m,
					n + 1,
					l.RETRY_MAX
				)
				if c then
					J(_)
					B.Visible = false
				else
					B.Visible = true
					f.Text = _
				end
				V("RATE LIMITED \226\128\148 WAITING " .. math.floor(m) .. "s", Q.AMBER)
				D(string.format("\226\143\179 429 \226\128\148 RETRYING IN %.0fs", m), Q.AMBER)
				warn(
					string.format(
						"[ServerBrowser] 429 \226\128\148 waiting %.1fs (attempt %d/%d)",
						m,
						n + 1,
						l.RETRY_MAX
					)
				)
				local _ = math.floor(m)
				task.spawn(function()
					while _ > 0 do
						task.wait(1)
						_ -= 1
						local q = string.format(
							"\226\143\179 429 RATE LIMITED \226\128\148 %.0fs REMAINING (%d/%d)",
							_,
							n + 1,
							l.RETRY_MAX
						)
						if c then
							if Z.Visible then
								C.Text = q
							end
						elseif B.Visible then
							f.Text = q
						end
					end
				end)
				task.wait(m)
				if c then
					F()
				end
				continue
			end
			if u == 403 then
				return nil, "FORBIDDEN"
			end
			if u == 401 then
				return nil, "UNAUTHORIZED"
			end
			if u >= 500 then
				return nil, "SERVER_ERROR"
			end
			if u ~= 200 and u ~= 0 then
				return nil, "HTTP_" .. tostring(u)
			end
			if not W.Body or W.Body == "" then
				return nil, "EMPTY_BODY"
			end
			local m, _ = pcall(G.JSONDecode, G, W.Body)
			if not m or not _ then
				return nil, "INVALID_JSON"
			end
			return _, nil
		end
		return nil, "RATE_LIMIT"
	end
	local function m()
		for _, _ in ipairs(P:GetChildren()) do
			if _:IsA("Frame") then
				_:Destroy()
			end
		end
	end
	local function _()
		table.sort(E.servers, function(Z, C)
			local q, c = Z.playing or 999, C.playing or 999
			if q ~= c then
				return q < c
			end
			return (Z.ping or 999) < (C.ping or 999)
		end)
	end
	local function Z(C)
		if C < 100 then
			return Q.GREEN_GLOW
		elseif C < 200 then
			return Q.AMBER
		else
			return Q.RED
		end
	end
	local function C(q)
		if q > 0.8 then
			return Q.RED
		elseif q > 0.5 then
			return Q.AMBER
		else
			return Q.CYAN
		end
	end
	local function q(c, r)
		local n = r == 1
		local u = n and Q.ROW_TOP or Q.ROW
		local W =
			S("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = u, BorderSizePixel = 0, LayoutOrder = r }, P)
		L(3, W)
		local O = d(1, n and Q.CYAN_DIM or Q.BORDER, 0, W)
		W.MouseEnter:Connect(function()
			I(W, { BackgroundColor3 = Q.ROW_HOVER })
			I(O, { Color = Q.BORDER_HOV })
		end)
		W.MouseLeave:Connect(function()
			I(W, { BackgroundColor3 = u })
			I(O, { Color = n and Q.CYAN_DIM or Q.BORDER })
		end)
		S(
			"TextLabel",
			{
				Size = UDim2.new(0, 28, 1, 0),
				Position = UDim2.new(0, 10, 0, 0),
				BackgroundTransparency = 1,
				Text = string.format("%02d", r),
				TextColor3 = n and Q.CYAN or Q.TEXT_DIM,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			W
		)
		S(
			"TextLabel",
			{
				Size = UDim2.new(0, 160, 0, 14),
				Position = UDim2.new(0, 44, 0, 8),
				BackgroundTransparency = 1,
				Text = tostring(c.id):sub(1, 18) .. "...",
				TextColor3 = Color3.fromRGB(60, 75, 110),
				Font = Enum.Font.Code,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			W
		)
		local d, I = c.playing or 0, c.maxPlayers or 20
		r = d / math.max(I, 1)
		S(
			"TextLabel",
			{
				Size = UDim2.new(0, 80, 0, 14),
				Position = UDim2.new(0, 44, 0, 26),
				BackgroundTransparency = 1,
				Text = d .. "/" .. I .. " players",
				TextColor3 = Q.TEXT_DIM,
				Font = Enum.Font.Gotham,
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			W
		)
		S(
			"TextLabel",
			{
				Size = UDim2.new(0, 50, 0, 20),
				Position = UDim2.new(0, 210, 0, 4),
				BackgroundTransparency = 1,
				Text = tostring(d),
				TextColor3 = Q.TEXT_PRI,
				Font = Enum.Font.GothamBold,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			W
		)
		d = S(
			"Frame",
			{
				Size = UDim2.new(0, 50, 0, 2),
				Position = UDim2.new(0, 210, 0, 28),
				BackgroundColor3 = Color3.fromRGB(22, 24, 36),
				BorderSizePixel = 0,
			},
			W
		)
		L(1, d)
		L(
			1,
			S(
				"Frame",
				{ Size = UDim2.new(math.clamp(r, 0, 1), 0, 1, 0), BackgroundColor3 = C(r), BorderSizePixel = 0 },
				d
			)
		)
		d = c.ping or 999
		S(
			"TextLabel",
			{
				Size = UDim2.new(0, 55, 1, 0),
				Position = UDim2.new(0, 278, 0, 0),
				BackgroundTransparency = 1,
				Text = d .. "ms",
				TextColor3 = Z(d),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			W
		)
		d = S(
			"TextButton",
			{
				Size = UDim2.new(0, 72, 0, 28),
				Position = UDim2.new(1, -82, 0.5, -14),
				BackgroundColor3 = Color3.fromRGB(10, 30, 18),
				BorderSizePixel = 0,
				Text = "JOIN",
				TextColor3 = Q.GREEN,
				Font = Enum.Font.GothamBold,
				TextSize = 10,
			},
			W
		)
		L(3, d)
		K(d, Color3.fromRGB(10, 30, 18), Color3.fromRGB(8, 44, 24))
		d.MouseButton1Click:Connect(function()
			D("TELEPORTING TO " .. tostring(c.id):sub(1, 16) .. "...", Q.CYAN)
			local K, S = pcall(function()
				game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", c.id)
			end)
			if not K then
				D("TELEPORT FAILED: " .. tostring(S), Q.RED)
				V("TELEPORT FAILED", Q.RED)
			end
		end)
	end
	local function K()
		m()
		_()
		local S = #E.servers
		local L = math.min(S, l.MAX_SHOW)
		for d = 1, L, 1 do
			q(E.servers[d], d)
		end
		P.CanvasSize = UDim2.new(0, 0, 0, e.AbsoluteContentSize.Y + 16)
		H.Text = "SHOWING " .. L .. " / " .. S
		Y.Text = "PLACE \194\183 " .. tostring(R) .. " \194\183 PAGE " .. tostring(E.pages)
		if E.finished then
			V("CACHE DONE \226\128\148 " .. S .. " SERVERS", Q.GREEN_GLOW)
		else
			V("CACHE SAVED \226\128\148 " .. S .. " SERVERS \226\128\148 PAGE " .. E.pages, Q.CYAN)
		end
	end
	local function S()
		E.servers = {}
		E.cursor = nil
		E.finished = false
		E.lastUpdate = 0
		E.pages = 0
		F()
		m()
		H.Text = "SHOWING 0 / 0"
		Y.Text = "PLACE \194\183 " .. tostring(R)
		V("CACHE RESET", Q.RED)
		D("CACHE RESET", Q.RED)
	end
	local m = false
	local function L(d, I)
		if m then
			return
		end
		m = true
		if I then
			S()
		end
		y.Active = false
		x.Active = false
		k.Active = false
		y.Text = "LOADING"
		x.Text = "WAIT"
		local _, P = 0
		repeat
			if E.finished then
				break
			end
			_ += 1
			E.pages = E.pages + 1
			I = #E.servers > 0
			if I then
				B.Visible = false
			else
				B.Visible = true
				f.Text = "SCANNING PAGE " .. E.pages .. "\226\128\166"
			end
			V("PAGE " .. E.pages .. " \226\128\148 " .. #E.servers .. " FOUND", Q.AMBER)
			local e = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(R)
			local R, Y = N(if E.cursor then e .. "&cursor=" .. G:UrlEncode(E.cursor) else e, I)
			if not R then
				e = o(Y)
				if not I then
					f.Text = e
				end
				V(e, Q.RED)
				D(e, Q.RED)
				warn("[ServerBrowser] " .. e .. " | Page: " .. E.pages)
				P = Y
				break
			end
			for G, G in ipairs(R.data or {}) do
				if G.id and G.id ~= game.JobId then
					e, Y = G.playing or 0, G.maxPlayers or 0
					if Y == 0 or e < Y then
						table.insert(E.servers, G)
					end
				end
			end
			E.cursor = R.nextPageCursor
			E.lastUpdate = tick()
			if not E.cursor or E.cursor == "" then
				E.finished = true
				E.cursor = nil
			end
			if not E.finished and _ < d then
				R = string.format("PAGE %d DONE \226\128\148 WAITING %.1fs\226\128\166", E.pages, l.PAGE_DELAY)
				if #E.servers > 0 then
					K()
					J(R)
				else
					f.Text = R
				end
				V(R, Q.CYAN)
				task.wait(l.PAGE_DELAY)
				F()
			end
		until _ >= d
		B.Visible = false
		F()
		K()
		if P then
			if #E.servers > 0 then
				D(o(P) .. " \226\128\148 SHOWING " .. #E.servers .. " CACHED", Q.AMBER)
				V(o(P) .. " | PARTIAL " .. #E.servers, Q.AMBER)
			else
				V(o(P), Q.RED)
			end
		elseif E.finished then
			V("FULL SCAN DONE \226\128\148 " .. #E.servers .. " SERVERS", Q.GREEN_GLOW)
			D("SCAN COMPLETE \226\128\148 " .. #E.servers .. " SERVERS", Q.GREEN_GLOW)
		else
			V("PAGE SAVED \226\128\148 CLICK LOAD MORE TO CONTINUE", Q.CYAN)
		end
		y.Active = true
		x.Active = true
		k.Active = true
		y.Text = "REFRESH"
		x.Text = "LOAD MORE"
		m = false
	end
	y.MouseButton1Click:Connect(function()
		task.spawn(function()
			local G = tick() - E.lastUpdate
			if #E.servers > 0 and G <= l.CACHE_TIME then
				K()
				D("CACHE STILL FRESH (" .. math.floor(l.CACHE_TIME - G) .. "s) \226\128\148 RESET TO RELOAD", Q.CYAN)
				return
			end
			L(2, true)
		end)
	end)
	x.MouseButton1Click:Connect(function()
		task.spawn(function()
			if E.finished then
				D("ALL PAGES LOADED \226\128\148 NO MORE SERVERS", Q.AMBER)
				V("NO MORE PAGES", Q.AMBER)
				return
			end
			L(2, false)
		end)
	end)
	k.MouseButton1Click:Connect(function()
		if not m then
			S()
		end
	end)
	task.spawn(function()
		L(2, true)
	end)
end)
StatusPlaceId = SectionServer.CreateLabel({ Title = "PlaceId: " .. game.PlaceId })
local G = ""
SectionServer.CreateBox(
	{ Title = "Input JobId Normal And JobId BananaCat", Placeholder = "Type here", Number = false, Default = nil },
	function(f)
		G = f
	end
)
SectionServer.CreateToggle({ Title = "Spam Join", Desc = nil, Default = Settings["Spam Join"] or false }, function(f)
	SaveSettings("Spam Join", f)
end)
if not (bit32 or bit) then
	({}).bxor = function(f, K)
		local R, m = 0, 1
		while f > 0 or K > 0 do
			local E, l = f % 2, K % 2
			f, K, R, m = (f - E) / 2, (K - l) / 2, if E ~= l then R + m else R, m * 2
		end
		return R
	end
end
local f = loadstring(
	'local function EQ(a, r)\10 local b, c = nil, nil\10 local success = pcall(function()\10 b, c = a, r\10 end)\10\10 if not success or b == nil or c == nil then\10 return false\10 end\10\10 if type(b) ~= type(c) then\10 return false\10 end\10\10 local d = { c, b, c, b }\10 if d[1] ~= d[1] then\10 return false\10 end\10 if d[1] ~= d[2] then\10 return false\10 end\10 if d[2] ~= d[1] then\10 return false\10 end\10\10 local e, f, g = 1 and 2, 2 and nil, true == not not true\10\10 if type(b) == "number" and type(c) == "number" then\10 if e and g and not f then\10 return b == c\10 end\10 elseif type(b) == "string" and type(c) == "string" then\10 if e and g then\10 return b == c\10 end\10 else\10 return b == c\10 end\10\10 return false\10end\10\10local function _vrf()\10 local x = os.time and os.time() or 12345\10 if tostring(print):find("function") == nil then\10 while true do\10 end\10 end\10 if tostring(type):find("function") == nil then\10 while true do\10 end\10 end\10 if (x * x + x) % 2 ~= 0 then\10 while true do\10 end\10 end\10 if not EQ(x, x) then\10 while true do\10 end\10 end\10end\10\10local function _gct()\10 _vrf()\10 local s, p1, p2, p3 = 17, {}, {}, {}\10 local _m = { [17] = 23, [23] = 41, [41] = 999 }\10\10 while true do\10 if s == 17 then\10 for i = 0, 255 do\10 local c = ("%c"):format(i)\10 p1[i] = c\10 p2[c] = i\10 end\10 s = _m[17]\10 elseif s == 23 then\10 for i = 0, 255 do\10 p3[i] = p1[i]\10 end\10 s = _m[23]\10 elseif s == 41 then\10 if EQ(s, 41) then\10 return p3, p2\10 else\10 while true do\10 end\10 end\10 else\10 while true do\10 end\10 end\10 end\10end\10\10local _CT, _BT = _gct()\10\10local _sp = (function()\10 local _xk = { 0x61, 0x9A, 0x43, 0xF1, 0x27, 0xBC, 0x58, 0x0D, 0xE7, 0x33 }\10\10 local _enc = {\10 { 0x9A, 0x71, 0x24, 0xEF, 0x38, 0x4C },\10 { 0x7D, 0xA1, 0x55, 0x92, 0xB7, 0x44, 0x18 },\10 { 0x2F, 0xC3, 0x89, 0x11, 0xD4, 0x67 },\10 { 0xA8, 0x3E, 0xD1, 0x5B },\10 { 0x44, 0xE2, 0x71, 0x9C, 0x0A, 0xD8, 0x61, 0xF4 },\10 { 0x1E, 0x7B, 0xC0, 0x35, 0x92, 0xAF, 0x4D, 0x28 },\10 { 0xF3, 0x60, 0x1A, 0x87, 0xCE, 0x39, 0x54 },\10 { 0x88, 0x2D, 0xB6, 0x41, 0xFA, 0x73, 0x19, 0xCC, 0x05 },\10 }\10\10 local function _dec(data, seed)\10 local result = ""\10 local state = seed or 0x53\10\10 for i = 1, #data do\10 local byte = data[i]\10 local keyIdx = ((i - 1) % #_xk) + 1\10 local key = _xk[keyIdx]\10\10 byte = bit32.bxor(byte, key)\10 byte = (byte - state + 256) % 256\10 byte = bit32.bxor(byte, (i * 23) % 256)\10 state = (state + i + key + 17) % 256\10\10 result = result .. _CT[byte]\10 end\10\10 return result\10 end\10\10 local _d = {}\10 for i = 1, #_enc do\10 _d[i] = _dec(_enc[i], (i * 0x29) % 256)\10 end\10\10 return _d\10end)()\10\10local function _gb(str, pos)\10 _vrf()\10 local c, s = 0, 5\10 local _states = { [5] = 7, [7] = 11, [11] = 999 }\10\10 while true do\10 if s == 5 then\10 for ch in str:gmatch(".") do\10 c = c + 1\10 if c == pos then\10 s = _states[5]\10 break\10 end\10 end\10 if s ~= 7 then\10 s = _states[11]\10 end\10 elseif s == 7 then\10 local ch = ""\10 local cnt = 0\10 for c2 in str:gmatch(".") do\10 cnt = cnt + 1\10 if cnt == pos then\10 ch = c2\10 break\10 end\10 end\10 if EQ(_BT[ch] or 0, _BT[ch] or 0) then\10 return _BT[ch] or 0\10 end\10 elseif s == 11 then\10 return 0\10 end\10 end\10end\10\10local function _tc(num)\10 if EQ(num, num) then\10 return _CT[num % 256]\10 end\10 while true do\10 end\10end\10\10local function _js(tbl)\10 local r, s = "", 3\10 local _sm = { [3] = 8, [8] = 999 }\10\10 while true do\10 if s == 3 then\10 for i = 1, #tbl do\10 r = r .. tbl[i]\10 end\10 s = _sm[3]\10 elseif s == 8 then\10 if EQ(r, r) then\10 return r\10 end\10 end\10 end\10end\10\10local function _gl(str)\10 _vrf()\10 local c = 0\10 for _ in str:gmatch(".") do\10 c = c + 1\10 end\10 if EQ(c, c) then\10 return c\10 end\10 return 0\10end\10\10local function _rp(str, pat, rep)\10 _vrf()\10 local r, pl, m = "", _gl(pat), true\10\10 for i = 1, pl do\10 if _gb(str, i) ~= _gb(pat, i) then\10 m = false\10 break\10 end\10 end\10\10 if m and EQ(m, true) then\10 r = rep\10 for i = pl + 1, _gl(str) do\10 local ch = ""\10 local cnt = 0\10 for c in str:gmatch(".") do\10 cnt = cnt + 1\10 if cnt == i then\10 ch = c\10 break\10 end\10 end\10 r = r .. ch\10 end\10 return r\10 end\10\10 return str\10end\10\10local function _cs(...)\10 local args, r = { ... }, ""\10 for i = 1, #args do\10 r = r .. args[i]\10 end\10 if EQ(r, r) then\10 return r\10 end\10 return ""\10end\10\10local function _gks(key, len)\10 _vrf()\10 local ks, kl, st = {}, _gl(key), 0\10\10 for i = 1, len do\10 local kp = ((i - 1) % kl) + 1\10 local kb = _gb(key, kp)\10 st = (st + kb + i + ((i * 11) % 256)) % 256\10 ks[i] = (kb + st + (i * 17) + ((kb * 3) % 256)) % 256\10 end\10\10 if EQ(#ks, len) then\10 return ks\10 end\10 return {}\10end\10\10local function _mix_key_material(key, salt)\10 _vrf()\10 local rev = key:reverse()\10 local out = {}\10 local src = _cs(key, salt, rev, _tc(_gl(key) % 256), _tc(_gl(salt) % 256))\10\10 for i = 1, _gl(src) do\10 local b = _gb(src, i)\10 b = bit32.bxor(b, (i * 29) % 256)\10 b = (b + ((i * 7) % 256)) % 256\10 out[i] = _tc(b)\10 end\10\10 return _js(out)\10end\10\10local function _derive_stream(key, salt, len)\10 _vrf()\10 local km = _mix_key_material(key, salt)\10 return _gks(km, len)\10end\10\10local function _randb()\10 return math.random(0, 255)\10end\10\10local function _gensalt128()\10 _vrf()\10 local t = {}\10 for i = 1, 16 do\10 t[i] = _tc(_randb())\10 end\10 return _js(t)\10end\10\10local function _secure_round_enc(key, data, salt, round_idx)\10 _vrf()\10 local dl = _gl(data)\10 local ks = _derive_stream(_cs(key, _tc(48 + round_idx)), salt, dl)\10 local r = {}\10 local st = (_gl(key) + _gl(salt) + round_idx * 37 + 91) % 256\10\10 for i = 1, dl do\10 local db = _gb(data, i)\10 local sb = _gb(salt, ((i + round_idx - 2) % 16) + 1)\10 local kk = ks[i]\10\10 st = (st + kk + sb + i + round_idx) % 256\10\10 local enc = db\10 enc = bit32.bxor(enc, kk)\10 enc = (enc + st + sb) % 256\10 enc = bit32.bxor(enc, ((i * 31) + sb + round_idx * 9) % 256)\10 enc = (enc + ((kk * 5) % 256)) % 256\10\10 r[i] = _tc(enc)\10 end\10\10 return _js(r)\10end\10\10local function _secure_round_dec(key, data, salt, round_idx)\10 _vrf()\10 local dl = _gl(data)\10 local ks = _derive_stream(_cs(key, _tc(48 + round_idx)), salt, dl)\10 local r = {}\10 local st = (_gl(key) + _gl(salt) + round_idx * 37 + 91) % 256\10\10 for i = 1, dl do\10 local sb = _gb(salt, ((i + round_idx - 2) % 16) + 1)\10 local kk = ks[i]\10\10 st = (st + kk + sb + i + round_idx) % 256\10\10 local eb = _gb(data, i)\10\10 local db = eb\10 db = (db - ((kk * 5) % 256) + 256) % 256\10 db = bit32.bxor(db, ((i * 31) + sb + round_idx * 9) % 256)\10 db = (db - st - sb + 512) % 256\10 db = bit32.bxor(db, kk)\10\10 r[i] = _tc(db)\10 end\10\10 return _js(r)\10end\10\10local function _ae(key, data, salt, rnd)\10 _vrf()\10 rnd = rnd or 3\10 local r = data\10\10 for rd = 1, rnd do\10 r = _secure_round_enc(key, r, salt, rd)\10 if not EQ(r, r) then\10 while true do\10 end\10 end\10 end\10\10 return r\10end\10\10local function _ad(key, data, salt, rnd)\10 _vrf()\10 rnd = rnd or 3\10 local r = data\10\10 for rd = rnd, 1, -1 do\10 r = _secure_round_dec(key, r, salt, rd)\10 if not EQ(r, r) then\10 while true do\10 end\10 end\10 end\10\10 return r\10end\10\10local _b64 = (function()\10 local chs = string.char(\10 65,\10 66,\10 67,\10 68,\10 69,\10 70,\10 71,\10 72,\10 73,\10 74,\10 75,\10 76,\10 77,\10 78,\10 79,\10 80,\10 81,\10 82,\10 83,\10 84,\10 85,\10 86,\10 87,\10 88,\10 89,\10 90,\10 97,\10 98,\10 99,\10 100,\10 101,\10 102,\10 103,\10 104,\10 105,\10 106,\10 107,\10 108,\10 109,\10 110,\10 111,\10 112,\10 113,\10 114,\10 115,\10 116,\10 117,\10 118,\10 119,\10 120,\10 121,\10 122,\10 48,\10 49,\10 50,\10 51,\10 52,\10 53,\10 54,\10 55,\10 56,\10 57,\10 43,\10 47\10 )\10\10 local function enc(data)\10 _vrf()\10 local r, dl = {}, _gl(data)\10 local i = 1\10\10 while i <= dl do\10 local b1 = _gb(data, i)\10 local b2 = i + 1 <= dl and _gb(data, i + 1) or 0\10 local b3 = i + 2 <= dl and _gb(data, i + 2) or 0\10\10 local n = b1 * 65536 + b2 * 256 + b3\10\10 local c1 = (n // 262144) % 64 + 1\10 local c2 = (n // 4096) % 64 + 1\10 local c3 = (n // 64) % 64 + 1\10 local c4 = n % 64 + 1\10\10 r[#r + 1] = _gb(chs, c1)\10 r[#r + 1] = _gb(chs, c2)\10 r[#r + 1] = i + 1 <= dl and _gb(chs, c3) or 61\10 r[#r + 1] = i + 2 <= dl and _gb(chs, c4) or 61\10\10 i = i + 3\10 end\10\10 local out = {}\10 for idx = 1, #r do\10 out[idx] = _tc(r[idx])\10 end\10\10 if EQ(_js(out), _js(out)) then\10 return _js(out)\10 end\10 return ""\10 end\10\10 local function dec(data)\10 _vrf()\10 local r, dl = {}, _gl(data)\10 local i = 1\10\10 while i <= dl do\10 local c1 = _gb(data, i)\10 local c2 = _gb(data, i + 1)\10 local c3 = _gb(data, i + 2)\10 local c4 = _gb(data, i + 3)\10\10 local function fp(byte)\10 if byte == 61 then\10 return 0\10 end\10 for p = 1, 64 do\10 if _gb(chs, p) == byte then\10 return p - 1\10 end\10 end\10 return 0\10 end\10\10 local n1, n2, n3, n4 = fp(c1), fp(c2), fp(c3), fp(c4)\10 local n = n1 * 262144 + n2 * 4096 + n3 * 64 + n4\10\10 r[#r + 1] = _tc((n // 65536) % 256)\10 if c3 ~= 61 then\10 r[#r + 1] = _tc((n // 256) % 256)\10 end\10 if c4 ~= 61 then\10 r[#r + 1] = _tc(n % 256)\10 end\10\10 i = i + 4\10 end\10\10 if EQ(_js(r), _js(r)) then\10 return _js(r)\10 end\10 return ""\10 end\10\10 return { encode = enc, decode = dec }\10end)()\10\10local function _seed_rng()\10 local seed = (os.time and os.time() or 12345)\10 + math.floor((os.clock and os.clock() or 0) * 100000)\10 + math.random(1, 999999)\10\10 math.randomseed(seed)\10 math.random()\10 math.random()\10 math.random()\10end\10\10_seed_rng()\10\10local function ebgzqifrwa(plaintext)\10 _vrf()\10 local k = _cs(_sp[5], _sp[6], _sp[7], _sp[8])\10 if not EQ(k, k) then\10 while true do\10 end\10 end\10\10 local salt = _gensalt128()\10 local enc = _ae(k, plaintext, salt, 3)\10 local payload = _cs(salt, enc)\10 local b64 = _b64.encode(payload)\10\10 if EQ(b64, b64) then\10 return _cs("BananaCat-", b64)\10 end\10 return ""\10end\10\10local function lebidlyjyf(encrypted)\10 _vrf()\10 local k = _cs(_sp[5], _sp[6], _sp[7], _sp[8])\10 if not EQ(k, k) then\10 while true do\10 end\10 end\10\10 local ed = _rp(encrypted, "BananaCat-", "")\10 local dc = _b64.decode(ed)\10\10 if _gl(dc) < 16 then\10 return ""\10 end\10\10 local salt_tbl = {}\10 local data_tbl = {}\10\10 for i = 1, 16 do\10 salt_tbl[#salt_tbl + 1] = _tc(_gb(dc, i))\10 end\10\10 for i = 17, _gl(dc) do\10 data_tbl[#data_tbl + 1] = _tc(_gb(dc, i))\10 end\10\10 local salt = _js(salt_tbl)\10 local data = _js(data_tbl)\10\10 if EQ(data, data) then\10 return _ad(k, data, salt, 3)\10 end\10 return ""\10end\10return ebgzqifrwa, lebidlyjyf\10'
)
Realm = require(game:GetService("ReplicatedStorage").Util.Realm)
function tryTeleport(K, R, m)
	local E, l = pcall(function()
		game:GetService("TeleportService"):TeleportToPlaceInstance(K, R, t)
	end)
	if E then
		m.done = true
	else
		warn("Teleport th\225\186\165t b\225\186\161i:", K, l)
	end
end
function teleportSmart(K)
	local R, m, E = Realm.safeGetCurrentSeaAsync(), {}, { done = false }
	for l, l in
		ipairs(
			if R == "Sea1"
				then { 2753915549, 85211729168715 }
				else if R == "Sea2"
					then { 4442272183, 79091703265657 }
					else if R == "Sea3" then { 7449423635, 100117331123089 } else m
		)
	do
		task.spawn(function()
			if not E.done then
				tryTeleport(l, K, E)
			end
		end)
	end
end
SectionServer.CreateButton({ Title = "Join JobId" }, function()
	if Settings["Spam Join"] then
		while task.wait() do
			local K, R, R = G, f()
			local m = string.find
			game:GetService("ReplicatedStorage").__ServerBrowser
				:InvokeServer("teleport", if m(G, "BananaCat-") then (R(G)) else K)
		end
	else
		local K, R, R = G, f()
		local m = string.find
		game:GetService("ReplicatedStorage").__ServerBrowser
			:InvokeServer("teleport", if m(G, "BananaCat-") then (R(G)) else K)
	end
end)
SectionServer.CreateButton({ Title = "Copy JobId" }, function()
	setclipboard(tostring(game.JobId))
end)
local G, K = {}, {}
if not pcall(function()
	readfile("Banana Cat Hub/Jobid.json")
end) then
	writefile("Banana Cat Hub/Jobid.json", game:GetService("HttpService"):JSONEncode(G))
end
if not pcall(function()
	readfile("Banana Cat Hub/NotSameServers.json")
end) then
	writefile("Banana Cat Hub/NotSameServers.json", game:GetService("HttpService"):JSONEncode(G))
end
function CheckJobIdServer()
	local R, m, E, l = {}, next, game:GetService("HttpService"):JSONDecode(readfile("Banana Cat Hub/Jobid.json"))
	for Q, S in m, E, l do
		table.insert(R, Q)
	end
	return R
end
function HopServer(R)
	local function m()
		for E = 1, 100, 1 do
			for l, Q in pairs((game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer(E))) do
				if l ~= game.JobId and not table.find(CheckJobIdServer(), l) then
					game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", l)
					writefile("Banana Cat Hub/Jobid.json", game:GetService("HttpService"):JSONEncode(K))
					getgenv().limit_type("clearAll")
				end
			end
		end
	end
	local K = R or (Settings["Time Hop Server"] or 5)
	require(game:GetService("ReplicatedStorage").Notification)
		.new("<Color=Red>Banana Cat Hub : Wait " .. K .. "s [Hop Server]<Color=/>")
		:Display()
	while wait(K) do
		require(game:GetService("ReplicatedStorage").Notification)
			.new("<Color=Red>Banana Cat Hub : Hop Server<Color=/>")
			:Display()
		m()
	end
end
SectionServer.CreateButton({ Title = "Hop Server" }, function()
	HopServer()
end)
function HopLessAll()
	require(game:GetService("ReplicatedStorage").Notification)
		.new("<Color=Red>Banana Hub : Hop Server<Color=/>")
		:Display()
	local K, R, m, E = game.PlaceId, {}, "", os.date("!*t").hour
	if
		not pcall(function()
			R = game:GetService("HttpService"):JSONDecode(readfile("Banana Cat Hub/NotSameServers.json"))
		end)
	then
		table.insert(R, E)
		writefile("Banana Cat Hub/NotSameServers.json", game:GetService("HttpService"):JSONEncode(R))
	end
	function HopServerLess()
		local l, Q =
			if m == ""
				then (game.HttpService:JSONDecode(
					game:HttpGet("https://games.roblox.com/v1/games/" .. K .. "/servers/Public?sortOrder=Asc&limit=100")
				))
				else (game.HttpService:JSONDecode(
					game:HttpGet(
						"https://games.roblox.com/v1/games/"
							.. K
							.. "/servers/Public?sortOrder=Asc&limit=100&cursor="
							.. m
					)
				)),
			""
		local K = l.nextPageCursor and l.nextPageCursor ~= "null" and l.nextPageCursor ~= nil
		if K then
			m = l.nextPageCursor
		end
		K = 0
		for m, S in pairs(l.data) do
			m = true
			Q = tostring(S.id)
			if tonumber(S.maxPlayers) > tonumber(S.playing) and tonumber(S.playing) <= 3 then
				for l, l in pairs(R) do
					if K ~= 0 then
						m = if Q == tostring(l) then false else m
					elseif tonumber(E) ~= tonumber(l) then
						pcall(function()
							delfile("Banana Cat Hub/NotSameServers.json")
							R = {}
							table.insert(R, E)
						end)
					end
					K += 1
				end
				if m == true then
					table.insert(R, Q)
					wait()
					pcall(function()
						writefile("Banana Cat Hub/NotSameServers.json", game:GetService("HttpService"):JSONEncode(R))
						wait()
						game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", Q)
						getgenv().limit_type("clearAll")
					end)
					wait(4)
				end
			end
		end
	end
	while wait() do
		HopServerLess()
	end
end
SectionServer.CreateButton({ Title = "Hop Server Less People" }, function()
	HopLessAll()
end)
function MoonTextureId()
	if game.PlaceId == getgenv().CheckPlaceId3 then
		return game:GetService("Lighting").Sky.MoonTextureId
	elseif game.PlaceId == getgenv().CheckPlaceId2 then
		return game:GetService("Lighting").FantasySky.MoonTextureId
	elseif game.PlaceId == getgenv().CheckPlaceId then
		return game:GetService("Lighting").Sky.MoonTextureId
	end
end
function CheckMoon()
	local K, R, m, E =
		"http://www.roblox.com/asset/?id=9709149431",
		"http://www.roblox.com/asset/?id=9709149052",
		MoonTextureId(),
		"Bad Moon"
	return if m == K or m == R then if m == K then "Full Moon" else if m == R then "Next Night" else E else E
end
function function6()
	return math.floor(game.Lighting.ClockTime)
end
function getServerTime()
	RealTime = tostring(math.floor(game.Lighting.ClockTime * 100) / 100)
	RealTime = tostring(game.Lighting.ClockTime)
	RealTimeTable = RealTime:split(".")
	Minute, Second = RealTimeTable[1], tonumber(0 + tonumber(RealTimeTable[2] / 100)) * 60
	return Minute, Second
end
function function8()
	local K = game.Lighting.ClockTime
	if CheckMoon() == "Full Moon" and K <= 5 then
		return tostring(function6()) .. " ( Will End Moon In " .. math.floor(5 - K) .. " Minutes )"
	elseif CheckMoon() == "Full Moon" and (K > 5 and K < 12) then
		return tostring(function6()) .. " ( Fake Moon )"
	elseif CheckMoon() == "Full Moon" and (K > 12 and K < 18) then
		return tostring(function6()) .. " ( Will Full Moon In " .. math.floor(18 - K) .. " Minutes )"
	elseif CheckMoon() == "Full Moon" and (K > 18 and K <= 24) then
		return tostring(function6()) .. " ( Will End Moon In " .. math.floor(30 - K) .. " Minutes )"
	end
	if CheckMoon() == "Next Night" and K < 12 then
		return tostring(function6()) .. " ( Will Full Moon In " .. math.floor(18 - K) .. " Minutes )"
	elseif CheckMoon() == "Next Night" and K > 12 then
		return tostring(function6()) .. " ( Will Full Moon In " .. math.floor(30 - K) .. " Minutes )"
	end
	return tostring(function6())
end
function CheckAcientOneDracoStatus()
	if not game.Players.LocalPlayer.Character:FindFirstChild("RaceTransformed") then
		if game.PlaceId == getgenv().CheckPlaceId then
			local K = game.workspace.HydraIslandClient.RemoteFunction:InvokeServer("Interacted")
			if K == 1 or K == 2 or K == 3 or K == 4 then
				return "Ready For Trial"
			end
		end
		return "You have yet to achieve greatness"
	end
	local K, R, m = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("UpgradeRace", "Check", 2)
	if K == 1 then
		return "Required Train More"
	elseif K == 2 or K == 4 or K == 7 then
		return "Can Buy Gear With " .. m .. " Fragments"
	elseif K == 3 then
		return "Required Train More"
	elseif K == 5 then
		return "You Are Done Your Race."
	elseif K == 6 then
		return "Upgrades completed: " .. R - 2 .. "/3, Need Trains More"
	end
	if K ~= 8 then
		if K == 0 then
			return "Ready For Trial"
		else
			return "You have yet to achieve greatness"
		end
	end
	return "Remaining " .. 10 - R .. " training sessions."
end
do
	local function K()
		if not game.Players.LocalPlayer.Character:FindFirstChild("RaceTransformed") then
			return "You have yet to achieve greatness"
		end
		local R, m, E = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("UpgradeRace", "Check")
		if R == 1 then
			return "Required Train More"
		elseif R == 2 or R == 4 or R == 7 then
			return "Can Buy Gear With " .. E .. " Fragments"
		elseif R == 3 then
			return "Required Train More"
		elseif R == 5 then
			return "You Are Done Your Race."
		elseif R == 6 then
			return "Upgrades completed: " .. m - 2 .. "/3, Need Trains More"
		end
		if R ~= 8 then
			if R == 0 then
				return "Ready For Trial"
			else
				return "You have yet to achieve greatness"
			end
		end
		return "Remaining " .. 10 - m .. " training sessions."
	end
	local R
	local m = 0
	function CheckAcientOneStatus()
		if R and tick() - m < 1 then
			return R
		end
		R = K()
		m = tick()
		return R
	end
	function ResetRaceStatus()
		R = nil
	end
end
function CheckGoTrain()
	local K = CheckAcientOneStatus()
	if
		string.find(K, "Upgrades completed")
		or K == "Required Train More"
		or (string.find(K, "training sessions."))
		or (string.find(K, "Can Buy Gear"))
	then
		return true
	end
end
function CheckClockTime()
	local K = game.Lighting.ClockTime
	return if K >= 18 or K < 5 then "Night" else "Day"
end
function StatusCheckLeviathan()
	if game.PlaceId == getgenv().CheckPlaceId then
		if
			game:GetService("ReplicatedStorage")
				:WaitForChild("Remotes")
				:WaitForChild("CommF_")
				:InvokeServer("InfoLeviathan", "1") ~= -1
		then
			if
				game:GetService("ReplicatedStorage")
					:WaitForChild("Remotes")
					:WaitForChild("CommF_")
					:InvokeServer("InfoLeviathan", "1") == 5
			then
				return "You can find leviathan now"
			else
				return "Buy Find leviathan"
			end
		else
			return "I DONT KNOW"
		end
	end
	return "..."
end
function IsMobAlive(K)
	if
		K
		and K.Parent
		and (K:FindFirstChild("HumanoidRootPart"))
		and (K:FindFirstChildWhichIsA("Humanoid"))
		and K.Humanoid.Health > 0
	then
		return true
	end
end
local K = { "Deandre", "Urban", "Diablo" }
function DetectEliteHunter()
	local R, m, E = next, game:GetService("ReplicatedStorage"):GetChildren()
	for l, l in R, m, E do
		if l:IsA("Model") and (table.find(K, l.Name)) and (IsMobAlive(l)) then
			return l
		end
	end
	E, m, R = next, game:GetService("Workspace").Enemies:GetChildren()
	for l, l in E, m, R do
		if l:IsA("Model") and (table.find(K, l.Name)) and (IsMobAlive(l)) then
			return l
		end
	end
end
local K = 0
lastCheckTime = tick()
function GetOldestLocation()
	local R, m = 1 / 0
	for E, l in ipairs(workspace._WorldOrigin.Locations:GetChildren()) do
		E = l:GetAttribute("TimeIn")
		if E and E < R then
			R, m = E, l
		end
	end
	return m
end
spawn(function()
	while wait(0.25) do
		local R, R = pcall(function()
			local m = game.workspace.DistributedGameTime
			local E, l, Q = m % 60, math.floor(m / 60 % 60), math.floor(m / 3600)
			TimerLabel.SetText(string.format("Timer: %.0fh %.0fm %.0fs", Q, l, E))
			l = GetOldestLocation()
			if l then
				Q = l:GetAttribute("TimeIn")
				E, m = tick() - 25200 - Q, 14400
				math.floor(E / m)
				local S = m - E % m
				local m, L, d, I, _, o =
					math.floor(S / 3600),
					math.floor(S % 3600 / 60),
					math.floor(S % 60),
					math.floor(E / 3600),
					math.floor(E % 3600 / 60),
					math.floor(E % 60)
				TimerServerLabel.SetText(string.format("Server Timer: %.0fh %.0fm %.0fs", I, _, o))
				NextTimerServerLabel.SetText(
					string.format("Next Time Spawn Fist of Darkness or God's Chalice: %.0fh %.0fm %.0fs", m, L, d)
				)
				if tonumber(m) == 0 and tonumber(L) == 0 and tonumber(d) <= 5 then
					getgenv().GoCollectChest = true
				end
			end
			if DetectEliteHunter() then
				StatusEliteHunter.SetText("Elite Hunter: \226\156\133")
			else
				StatusEliteHunter.SetText("Elite Hunter: \226\157\140")
			end
			if game.PlaceId == getgenv().CheckPlaceId then
				K = 0
				Q = workspace.Map:FindFirstChild("TikiOutpost") and workspace.Map.TikiOutpost.IslandModel
				if Q then
					l = {}
					for m = 1, 4, 1 do
						E = Q:FindFirstChild("Eye" .. m, true)
						if E then
							table.insert(l, E)
						end
					end
					for m, Q in ipairs(l) do
						m = Q.Transparency == 1 and K < 4
						if m then
							K += 1
						end
					end
				end
			end
			StatusTyrant.SetText("Tyrant Eyes: " .. tostring(K) .. " Eyes")
			E = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CakePrinceSpawner", true) or ""
			if E and (E:find("open the portal now")) then
				game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CakePrinceSpawner")
			end
			StatusKatakuri.SetText("Cake Prince: " .. string.gsub(E, "%D", "") .. " Mobs")
			Statusspy.SetText("Leviathan: " .. StatusCheckLeviathan())
			if workspace.Map:FindFirstChild("MysticIsland") then
				StatusMirage.SetText("Mirage Island: \226\156\133")
			else
				StatusMirage.SetText("Mirage Island: \226\157\140")
			end
			if not workspace.Map:FindFirstChild("PrehistoricIsland") then
				StatusPrehistoricIsland.SetText("Prehistoric Island: \226\157\140")
			else
				StatusPrehistoricIsland.SetText("Prehistoric Island: \226\156\133")
			end
			if not workspace._WorldOrigin.Locations:FindFirstChild("Frozen Dimension") then
				StatusFrozenDimension.SetText("Frozen Dimension: \226\157\140")
			else
				StatusFrozenDimension.SetText("Frozen Dimension: \226\156\133")
			end
			StatusGear.SetText("Ancient One: " .. CheckAcientOneStatus())
			if getgenv().StatusGearDraco then
				getgenv().StatusGearDraco.SetText("Draco: " .. CheckAcientOneDracoStatus())
			end
			StatusMoon.SetText("Moon Phase: " .. CheckMoon() .. " | " .. function8())
		end)
		if R then
			print(R)
		end
	end
end)
LocalPlayerMain = Main.CreatePage({ Page_Name = "LocalPlayer", Page_Title = "LocalPlayer" })
SectionLocalPlayerMain = LocalPlayerMain.CreateSection("Local Player")
SectionLocalPlayerMain.CreateToggle(
	{
		Title = "Auto Translate",
		Desc = "It may take a bit longer to translate the first time.",
		Default = Settings["Auto Translate"] or false,
	},
	function(K)
		SaveSettings("Auto Translate", K)
	end
)
SectionLocalPlayerMain.CreateButton({ Title = "Stop Tween" }, function()
	getgenv().noclip = false
	TweenManager.CancelCurrent()
end)
SectionLocalPlayerMain.CreateButton({ Title = "Fix UI Button Game" }, function()
	require(game:GetService("ReplicatedStorage").Modules.LastInput).IsMobile = function()
		return true
	end
	wait(0.5)
	t.Character.Humanoid.Health = 0
end)
SectionLocalPlayerMain.CreateButton({ Title = "Load config in Web" }, function()
	local K = game:GetService("HttpService")
	game:GetService("RunService")
	local R, m, E = "https://cfg.banana-hub.xyz", getgenv().Key, game.Players.LocalPlayer.Name
	function ApplyConfigFromWeb(l)
		for Q, S in pairs(l) do
			if not S.name then
				continue
			end
			Q = Options[S.name]
			if Q and S then
				if S.value ~= nil and Q.type ~= "slider_dropdown" and Q.type ~= "priority_dropdown" then
					if Q.FunctionCreate and Q.FunctionCreate.SetValue then
						if Q.type == "box" then
							Q.FunctionCreate.SetValue(tostring(S.value))
						elseif Q.type == "dropdown" then
							Q.FunctionCreate.SetValue(S.value)
						elseif Q.type == "slider" then
							Q.FunctionCreate.SetValue(S.value)
						else
							Q.FunctionCreate:SetValue(S.value)
						end
					elseif Q.FunctionCreate and Q.FunctionCreate.SetStage then
						Q.FunctionCreate.SetStage(S.value)
					end
				end
				if Q.type == "priority_dropdown" and S.selected then
					if Q.FunctionCreate and Q.FunctionCreate.SetValue then
						Q.FunctionCreate.SetValue(S.selected)
					end
				end
				if Q.type == "slider_dropdown" and S.values then
					for l, L in pairs(S.values) do
						if Q.FunctionCreate and Q.FunctionCreate.SetSubValue then
							Q.FunctionCreate:SetSubValue(l, L)
						end
					end
				end
			end
		end
	end
	local l, Q = pcall(function()
		return request({
			Url = string.format("%s/config/get?authId=%s&userId=%s&roblox=true", R, K:UrlEncode(m), K:UrlEncode(E)),
			Method = "GET",
		})
	end)
	if l and Q.StatusCode == 200 then
		ApplyConfigFromWeb((K:JSONDecode(Q.Body)))
	end
end)
SectionLocalPlayerMain.CreateButton(
	{ Title = "Push Data To Web ( just push when join game,if push again plz rejoin )" },
	function()
		local K, R = game:GetService("HttpService"), "https://cfg.banana-hub.xyz"
		function BuildSchema()
			local m, E = {}, 1
			for l, Q in pairs(Options) do
				local S, L, d = Q.Page_Name or "Default Page", Q.Section_Name or "Default Section", tostring(E)
				if Q.type == "toggle" then
					m[d] = { name = l, type = "toggle", value = Q.value, page = S, section = L }
				elseif Q.type == "button" then
					m[d] = { name = l, type = "button", value = l, text = l, page = S, section = L }
				elseif Q.type == "textlabel" then
					local I = Q.FunctionCreate and Q.FunctionCreate.GetText and (Q.FunctionCreate.GetText())
						or Q.text
						or l
					m[d] = {
						name = l,
						type = "label",
						value = I,
						text = I,
						color = Q.color or "#B8B8B8",
						size = Q.size or "14px",
						bold = Q.bold or false,
						page = S,
						section = L,
					}
				elseif Q.type == "box" then
					m[d] = { name = l, type = "box", value = Q.value or "", page = S, section = L }
				elseif Q.type == "slider" then
					m[d] = {
						name = l,
						type = "slider",
						min = Q.min or 0,
						max = Q.max or 100,
						step = Q.step or 1,
						value = Q.value or Q.min or 0,
						page = S,
						section = L,
					}
				elseif Q.type == "dropdown" then
					m[d] = {
						name = l,
						type = "dropdown",
						options = table.clone(Q.list or {}),
						value = Q.value or Q.list and Q.list[1] or "",
						page = S,
						section = L,
					}
				elseif Q.type == "priority_dropdown" then
					local I = table.clone(Q.value or {})
					m[d] = {
						name = l,
						type = "priority_dropdown",
						options = table.clone(Q.list or {}),
						selected = I,
						value = I,
						page = S,
						section = L,
					}
				elseif Q.type == "multi_toggle" then
					m[d] = {
						name = l,
						type = "multi_toggle",
						options = table.clone(Q.list or {}),
						value = table.clone(Q.value or {}),
						page = S,
						section = L,
					}
				elseif Q.type == "slider_dropdown" then
					local I, _ = {}, {}
					for o, V in pairs(Q.list or {}) do
						I[o] = { min = V.min or 0, max = V.max or 100, step = V.step or 1 }
						_[o] = Q.value and Q.value[o] or V.Default or V.min or 0
					end
					m[d] = { name = l, type = "slider_dropdown", sliders = I, values = _, page = S, section = L }
				end
				E += 1
			end
			return m
		end
		function UploadSchemaToWeb(m, E)
			if not m or not E then
				warn("\226\157\140 Missing authId or userId for schema upload")
				return false
			end
			local l = BuildSchema()
			local Q, S = pcall(function()
				return request({
					Url = string.format("%s/schema/init?authId=%s&userId=%s", R, K:UrlEncode(m), K:UrlEncode(E)),
					Method = "POST",
					Headers = { ["Content-Type"] = "application/json" },
					Body = K:JSONEncode(l),
				})
			end)
			if Q and S.StatusCode == 200 then
				print("\226\156\133 Schema initialized (first time)")
				return true
			end
			if Q and S.StatusCode == 409 then
				print("\226\132\185\239\184\143 Schema already exists, skipping upload")
				return true
			end
			warn("\226\157\140 Schema upload failed")
			if Q then
				warn("Status:", S.StatusCode)
				warn("Body:", S.Body)
			end
			return false
		end
		function PushSchemaToWebupdate(m, E)
			if not m or not E then
				return
			end
			local l = BuildSchema()
			local Q, S = pcall(function()
				return request({
					Url = string.format("%s/schema/update?authId=%s&userId=%s", R, K:UrlEncode(m), K:UrlEncode(E)),
					Method = "POST",
					Headers = { ["Content-Type"] = "application/json" },
					Body = K:JSONEncode(l),
				})
			end)
			if Q and S.StatusCode == 200 then
				print("\226\156\133 Schema UPDATED \226\134\146 web will reload")
			else
				warn("\226\157\140 Push schema failed")
				if Q then
					warn("Status:", S.StatusCode)
					warn("Body:", S.Body)
				end
			end
		end
		local m, E = getgenv().Key, game.Players.LocalPlayer.Name
		if not m then
			warn("Missing Key, cannot push data")
			return
		end
		request({
			Url = "https://cfg.banana-hub.xyz/config/get?authId=" .. m .. "&userId=" .. E .. "&roblox=true",
			Method = "GET",
		})
		function ForceResetSchema(l, Q)
			pcall(function()
				request({
					Url = string.format("%s/schema/delete?authId=%s&userId=%s", R, K:UrlEncode(l), K:UrlEncode(Q)),
					Method = "DELETE",
				})
			end)
			wait(0.5)
			return UploadSchemaToWeb(l, Q)
		end
		ForceResetSchema(m, E)
	end
)
local K = require(game.ReplicatedStorage:WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("Inventory"))
SectionLocalPlayerMain.CreateButton({ Title = "Show Item" }, function()
	if not game:GetService("CoreGui").ExperienceChat.bubbleChat:FindFirstChild("Right") then
		local R, m, E = game.Players.LocalPlayer, game:GetService("CoreGui"), game:GetService("ReplicatedStorage")
		if not K.IsOpen then
			K:Open()
			task.wait(2)
		end
		local l, Q, S = R.PlayerGui.Inventory.Frame.Main.PageContent.Inner.TileGrid.Inner.Container, {}, {}
		t.PlayerGui:WaitForChild("Inventory"):WaitForChild("Frame")
		l.CanvasPosition = Vector2.new(0, 0)
		local L, d = l.CanvasSize.Y.Offset - l.AbsoluteWindowSize.Y, 0
		while l.CanvasPosition.Y < L and (task.wait(0.1)) do
			l.CanvasPosition = Vector2.new(0, d)
			for I, _ in pairs(l:GetChildren()) do
				if _:FindFirstChild("Details") and (_.Details:FindFirstChild("Line-1")) then
					I = _.Details["Line-1"].ContentText
						.. (_.Details:FindFirstChild("Line-2") and _.Details["Line-2"].ContentText or "")
					if not Q[I] then
						Q[I] = true
						table.insert(S, _:Clone())
					end
				end
			end
			d += 20
		end
		Q = { "Left", "Right" }
		for I, I in ipairs(Q) do
			l = m.ExperienceChat.bubbleChat:FindFirstChild(I)
			if l then
				l:Destroy()
			end
		end
		L = Instance.new("Frame", m.ExperienceChat.bubbleChat)
		L.Name = "Left"
		L.BackgroundTransparency = 1
		L.Size = UDim2.new(0.5, 0, 1, 0)
		Q = Instance.new("Frame", m.ExperienceChat.bubbleChat)
		Q.Name = "Right"
		Q.BackgroundTransparency = 1
		Q.Position = UDim2.new(0.5, 0, 0, 0)
		Q.Size = UDim2.new(0.5, 0, 1, 0)
		local function I(_)
			local o = Instance.new("UIListLayout", _)
			o.FillDirection = Enum.FillDirection.Vertical
			o.HorizontalAlignment = Enum.HorizontalAlignment.Center
			o.SortOrder = Enum.SortOrder.LayoutOrder
			o.Padding = UDim.new(0, 10)
			return o
		end
		I(L)
		I(Q)
		local function _(o)
			local V = Instance.new("UIGridLayout", o)
			V.CellPadding = UDim2.new(0, 8, 0, 8)
			V.CellSize = UDim2.new(0, 70, 0, 70)
			V.FillDirectionMaxCells = 8
			V.FillDirection = Enum.FillDirection.Horizontal
			V.SortOrder = Enum.SortOrder.LayoutOrder
			return V
		end
		l = Instance.new("Frame", L)
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.LayoutOrder = 1
		_(l)
		L = Instance.new("Frame", Q)
		L.BackgroundTransparency = 1
		L.Size = UDim2.new(1, 0, 0, 0)
		L.AutomaticSize = Enum.AutomaticSize.Y
		L.LayoutOrder = 1
		_(L)
		d = { Vector2.new(218, 225), Vector2.new(436, 225) }
		for o, o in ipairs(S) do
			I = o.Details.Category.ContentText
			if I == "Blox Fruit" and (table.find(d, o.ImageRectOffset)) then
				o.Parent = L
			elseif I ~= "Blox Fruit" then
				o.Parent = l
			end
		end
		S = Instance.new("Frame", Q)
		S.BackgroundTransparency = 1
		S.Size = UDim2.new(1, 0, 0, 0)
		S.AutomaticSize = Enum.AutomaticSize.Y
		S.LayoutOrder = 100
		_(S)
		local L, d, I =
			{
				Superhuman = Vector2.new(3, 2),
				DeathStep = Vector2.new(4, 3),
				ElectricClaw = Vector2.new(2, 0),
				SharkmanKarate = Vector2.new(0, 0),
				DragonTalon = Vector2.new(1, 5),
				Godhuman = "rbxassetid://10338473987",
			},
			{},
			{}
		for o, V in pairs(L) do
			if E.Remotes.CommF_:InvokeServer("Buy" .. o, true) == 1 then
				l = Instance.new("ImageLabel", S)
				l.BackgroundTransparency = 1
				if type(V) == "string" then
					l.Image = V
				else
					l.Image = "rbxassetid://9945562382"
					l.ImageRectSize = Vector2.new(100, 100)
					l.ImageRectOffset = V * 100
				end
				I[o] = l
				table.insert(d, o)
			end
		end
		local function S()
			local L = Instance.new("TextLabel")
			L.BackgroundTransparency = 1
			L.Size = UDim2.new(0.5, 0, 0.5, 0)
			L.Position = UDim2.new(0.5, 0, 0.5, 0)
			L.Font = Enum.Font.GothamBold
			L.TextColor3 = Color3.fromRGB(255, 255, 255)
			L.TextSize = 10
			L.TextXAlignment = Enum.TextXAlignment.Right
			L.TextYAlignment = Enum.TextYAlignment.Bottom
			L.ZIndex = 5
			return L
		end
		local function L(o)
			for V, V in pairs(R.Backpack:GetChildren()) do
				if V.Name:gsub(" ", "") == o then
					return V
				end
			end
		end
		spawn(function()
			local o, V = #d, 0
			while V < o do
				for d, o in pairs(I) do
					if not o:FindFirstChild("Ditme") then
						E.Remotes.CommF_:InvokeServer("Buy" .. d)
						task.wait(0.1)
						local E = L(d)
						if E then
							E:WaitForChild("Level")
							local L = S()
							L.Name = "Ditme"
							L.Text = E.Level.Value
							L.Parent = o
							V += 1
						end
					end
				end
				task.wait()
			end
		end)
		task.wait(2)
		R.PlayerGui.Main.AwakeningToggler.Visible = true
		l = R.PlayerGui.Main.AwakeningToggler:Clone()
		l.LayoutOrder = 101
		R.PlayerGui.Main.AwakeningToggler.Visible = false
		l.Parent = Q
		l.Size = UDim2.new(1, 0, 0.3, 0)
		local function E(l)
			return tostring(l):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
		end
		_ = R.PlayerGui.Main.Fragments:Clone()
		_.Parent = m.ExperienceChat.bubbleChat
		_.Position = UDim2.new(0, 6, 0.85799, 0)
		_.Text = "\198\146" .. E(R.Data.Fragments.Value)
		wait(2)
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.MenuButton.Visible = false
		end)
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.HP.Visible = false
		end)
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.Energy.Visible = false
		end)
		for R, R in pairs(game:GetService("Players").LocalPlayer.PlayerGui.Main:GetChildren()) do
			if R:IsA("ImageButton") then
				R.Visible = false
			end
		end
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.Compass.Visible = false
		end)
		K:Close()
	else
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.MenuButton.Visible = true
		end)
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.HP.Visible = true
		end)
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.Energy.Visible = true
		end)
		for K, K in pairs(game:GetService("Players").LocalPlayer.PlayerGui.Main:GetChildren()) do
			if K:IsA("ImageButton") then
				K.Visible = true
			end
		end
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.Compass.Visible = true
		end)
		for K, K in pairs(game:GetService("CoreGui").ExperienceChat.bubbleChat:GetChildren()) do
			if K.Name == "Left" or K.Name == "Right" or K.Name == "Fragments" then
				K:Destroy()
			end
		end
	end
end)
SectionLocalPlayerMain.CreateButton({ Title = "Open Devil Fruit Shop" }, function()
	local K = require(game.ReplicatedStorage.Controllers.UI.FruitShop)
	K.init()
	K:Open()
end)
SectionLocalPlayerMain.CreateButton({ Title = "Open Devil Fruit Shop Mirage" }, function()
	local K = require(game.ReplicatedStorage.Controllers.UI.FruitShop)
	K.init()
	K:Open("AdvancedFruitDealer")
end)
SectionLocalPlayerMain.CreateButton({ Title = "Open Title" }, function()
	game:GetService("Players").LocalPlayer.PlayerGui.Main.Titles.Visible = true
end)
SectionLocalPlayerMain.CreateButton({ Title = "Open Color" }, function()
	game:GetService("Players").LocalPlayer.PlayerGui.Main.Colors.Visible = true
end)
SectionLocalPlayerMain.CreateDropdown(
	{
		Title = "Select Stats",
		List = PrepareMultiSelectList(
			{ Melee = false, Defense = false, Sword = false, Gun = false, ["Demon Fruit"] = false },
			Settings["Select Stats"]
		),
		Search = true,
		Selected = true,
		Default = Settings["Select Stats"] or nil,
	},
	function(K, R)
		SaveSettings("Select Stats", K, R)
	end
)
SectionLocalPlayerMain.CreateToggle(
	{ Title = "Auto Stats", Desc = nil, Default = Settings["Auto Stats"] or false },
	function(K)
		spawn(function()
			while Settings["Auto Stats"] and (task.wait(0.3)) do
				pcall(function()
					for R, m in next, Settings["Select Stats"], nil do
						if
							m
							and game.Players.localPlayer.Data.Points.Value > 0
							and game:GetService("Players").LocalPlayer.Data.Stats[R].Level.Value < 2800
						then
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("AddPoint", R, 9999)
							wait(3)
						end
					end
				end)
			end
		end)
		SaveSettings("Auto Stats", K)
	end
)
SectionLocalPlayerMain.CreateDropdown(
	{
		Title = "Select Team",
		List = { "Pirate", "Marine" },
		Search = true,
		Selected = false,
		Default = Settings["Select Team"] or nil,
	},
	function(K)
		SaveSettings("Select Team", K)
	end
)
SectionLocalPlayerMain.CreateDropdown(
	{ Title = "Change Team", List = { "Pirates", "Marines" }, Search = true, Selected = false, Default = nil },
	function(K)
		if K then
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ [1] = "SetTeam", [2] = K }))
		end
	end
)
SectionLocalPlayerMain.CreateToggle({ Title = "Noclip", Desc = nil, Default = Settings.Noclip or false }, function(K)
	SaveSettings("Noclip", K)
end)
local K
function SetRobloxGUI(R)
	game.CoreGui.RobloxGui.Enabled = R
end
spawn(function()
	local R = tick()
	repeat
		wait(1)
		if tick() - R > 179 then
			game:Shutdown()
			wait(10)
		end
	until game:FindFirstChild("CoreGui") and game.Players.LocalPlayer and game.Players.LocalPlayer.Character
	R = tick()
	repeat
		wait(1)
		if tick() - R > 169 then
			game:Shutdown()
			wait(10)
		end
	until game.Players.LocalPl…