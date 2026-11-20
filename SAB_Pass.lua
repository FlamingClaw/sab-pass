--[[ SAB Pass Farmer
One job: take a fresh or new-ish account to the last rank of the event pass, on its own.
  * finishes the tutorial (lever -> buy -> wax -> wait -> collect)
  * pulls the lever itself (no Auto Roll pass needed), buys what helps, waxes it, buys wax stations
  * does every daily quest: collect, wax, help, pull, buy, wax a Rare / Epic / Legendary
  * claims finished quests, the daily bonus and pass ranks 1-19 (FREE side only)
  * NEVER claims the last rank (the 90%-of-best butter), never uses Claim All, never buys anything with Robux
Measured on a fresh account, Nov 20 2026: 20 ranks / 4300 acorns, 5 quests a day + 100 bonus after 4,
a full day is 520-730 acorns, quests reset at 00:00 UTC, the event ends Dec 1 00:00 UTC.
]]
local VERSION = "pass v1.1"
local genv = (getgenv and getgenv()) or _G
if genv.SABP and genv.SABP.kill then pcall(genv.SABP.kill) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = workspace
local UIS = game:GetService("UserInputService")
local RunS = game:GetService("RunService")
local plr = Players.LocalPlayer
local P = { alive = true, conns = {}, log = {}, logN = 0 } -- state
local CFG = { Run = true, Help = true, ClaimRanks = true, LowGfx = false, FpsCap = 20, StopRank = 19, Job = "" }
local FILE = "SAB/SAB_Pass_" .. tostring(plr.UserId) .. ".txt" -- one settings file per account

---------------------------------------------------------------- basics
local function now() return os.clock() end
local function srv() return WS:GetServerTimeNow() end
local KILLED = {}
local function nap(t) task.wait(t) if not P.alive then error(KILLED, 0) end end
local function track(c) P.conns[#P.conns + 1] = c return c end
local function note(s)
    s = os.date("%H:%M:%S") .. " " .. tostring(s)
    table.insert(P.log, 1, s)
    if #P.log > 8 then table.remove(P.log) end
    P.logN = P.logN + 1
end
local SUF = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local function fmt(n)
    if type(n) ~= "number" then return "?" end
    local i = 1
    while math.abs(n) >= 1000 and i < #SUF do n = n / 1000 i = i + 1 end
    return (string.format("%.2f", n):gsub("%.?0+$", "")) .. SUF[i]
end
local function cash()
    local v = plr:GetAttribute("BoardValueMoney")
    return type(v) == "number" and v or 0
end
local function char()
    local c = plr.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if h and hum and hum.Health > 0 then return c, h end
end
local function waitFor(cond, t)
    local t0 = now()
    while now() - t0 < t do
        if cond() then return true end
        nap(0.1)
    end
    return cond()
end
local function hop(pos, look) -- stand at pos (a little above), facing look
    local _, h = char()
    if not h then return false end
    h.CFrame = look and CFrame.new(pos, Vector3.new(look.X, pos.Y, look.Z)) or CFrame.new(pos)
    h.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    return true
end
local function near(part, dist) -- beside a part, on the side facing the plot's middle
    local p = part.Position
    hop(p + Vector3.new(0, 2.5, dist or 4), p)
    nap(0.25)
end
local function fire(prompt)
    if not (prompt and prompt.Parent and prompt.Enabled) then return false end
    if type(fireproximityprompt) == "function" and pcall(fireproximityprompt, prompt) then return true end
    pcall(function() prompt:InputHoldBegin() end)
    nap(math.max(prompt.HoldDuration, 0) + 0.1)
    pcall(function() prompt:InputHoldEnd() end)
    return true
end
local function remote(name) local r = RS:FindFirstChild("Remotes") return r and r:FindFirstChild(name) end
local function invoke(name, ...)
    local r = remote(name)
    if not r then return false, "no remote " .. name end
    local args = { ... }
    return pcall(function() return r:InvokeServer(table.unpack(args)) end)
end

---------------------------------------------------------------- game data
local INFO, RANKS = {}, { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5, Celestial = 6, Divine = 7, Dream = 8 }
pcall(function() INFO = require(RS.Modules.SquishyInfo) end)
pcall(function() -- the game's own rarity order, if it has more
    local rng = require(RS.Modules.SquishyRNG)
    for i, k in ipairs(rng.Keys or {}) do RANKS[k] = i end
end)
local WAXP = {}
pcall(function() WAXP = require(RS.Modules.WaxPrices) end)
local function info(name) return INFO[name] or {} end
local function rankOf(name) return RANKS[info(name).rarity or ""] or 0 end

local function plot()
    local n = plr:GetAttribute("PlotNumber")
    local ps = WS:FindFirstChild("Plots")
    return n and ps and ps:FindFirstChild(tostring(n))
end
local function padModel()
    local pl = plot()
    local r = pl and pl:FindFirstChild("RolledSquishy")
    return r and r:FindFirstChildWhichIsA("Model")
end
local function held()
    local a = plr:GetAttribute("SquishyEquipped")
    return (type(a) == "string" and a ~= "") and a or nil
end
local function stations() -- my unlocked stations: { st, prompt, busy }
    local out, pl = {}, plot()
    local ws = pl and pl:FindFirstChild("WaxStations")
    local n = tonumber(plr:GetAttribute("WaxStations")) or 1
    for i = 1, n do
        local st = ws and ws:FindFirstChild(tostring(i))
        local ph = st and st:FindFirstChild("SquishyPlaceHolder")
        local pp = ph and ph:FindFirstChild("PlacePrompt")
        if pp then out[#out + 1] = { st = st, ph = ph, pp = pp, busy = st:GetAttribute("HasSquishy") == true } end
    end
    return out
end
local function freeStation()
    for _, s in ipairs(stations()) do if not s.busy and s.pp.Enabled then return s end end
end

---------------------------------------------------------------- the pass (whichever event is live)
local PASS = { st = nil, at = 0, cfg = nil }
function PASS.find()
    local r = RS:FindFirstChild("Remotes")
    for _, x in ipairs(r and r:GetChildren() or {}) do
        if x:IsA("RemoteFunction") and x.Name:match("^%u%a+Action$") and x.Name ~= "CrateAction" and x.Name ~= "AutoRollAction" then
            local ok, v = pcall(function() return x:InvokeServer("state") end)
            if ok and type(v) == "table" and v.live == true and type(v.quests) == "table" then
                local id = x.Name:gsub("Action$", "")
                if not PASS.cfg or PASS.id ~= id then
                    PASS.id, PASS.r = id, x
                    pcall(function() PASS.cfg = require(RS.Modules[id .. "Config"]) end)
                end
                return v
            end
        end
    end
end
function PASS.refresh()
    PASS.at = now()
    local v = PASS.find()
    PASS.st = v
    return v
end
function PASS.act(...)
    if not PASS.r then return false end
    local args = { ... }
    local ok, v = pcall(function() return PASS.r:InvokeServer(table.unpack(args)) end)
    return ok and not (type(v) == "table" and v.ok == false), v
end
function PASS.open(kind) -- the open quest of a kind (not done)
    for _, q in ipairs(PASS.st and PASS.st.quests or {}) do
        if q.kind == kind and not q.done then return q end
    end
end
function PASS.rareNeed() -- the lowest rarity rank an open "wax a X or better" quest needs
    local q = PASS.open("rare")
    if not q then return nil end
    local d = PASS.cfg and PASS.cfg.questById and PASS.cfg.questById[q.id]
    return (d and d.minRank) or ((q.id:find("legend") and 4) or (q.id:find("epic") and 3) or 2), q
end
local function claimedFree(r)
    local c = PASS.st and PASS.st.claimed and PASS.st.claimed.free
    if type(c) ~= "table" then return false end
    if c[r] == true or c[tostring(r)] == true then return true end
    for _, x in ipairs(c) do if x == r then return true end end
    return false
end
function PASS.claimAll() -- quests, the day's bonus, ranks 1..StopRank on the FREE side
    local st = PASS.st
    if not st then return end
    local any = false
    for _, q in ipairs(st.quests) do
        if q.done and not q.claimed then
            local ok, v = PASS.act("claimQuest", q.id)
            if ok then note(("CLAIMED quest %s (%s)"):format(tostring(q.text), type(v) == "table" and tostring(v.text) or "ok")) any = true end
            nap(0.5)
        end
    end
    if st.bonusReady == true then
        if PASS.act("claimBonus") then note("CLAIMED the daily quest bonus") any = true end
        nap(0.5)
    end
    if any then st = PASS.refresh() end
    if CFG.ClaimRanks and st and type(st.rank) == "number" then
        local top = math.min(st.rank, CFG.StopRank)
        for r = 1, top do
            if not claimedFree(r) then
                local ok, v = PASS.act("claim", r, "free")
                if ok then note(("CLAIMED rank %d reward (%s)"):format(r, type(v) == "table" and tostring(v.text) or "ok")) end
                nap(0.6)
            end
        end
        PASS.refresh()
    end
end

---------------------------------------------------------------- actions
P.pulls, P.buys, P.waxes, P.collects, P.helps = 0, 0, 0, 0, 0
local function pull()
    local pl = plot()
    local lv = pl and pl:FindFirstChild("Lever")
    local w = lv and lv:FindFirstChild("Wheel")
    local p = w and w:FindFirstChildWhichIsA("ProximityPrompt")
    if not p then P.msg = "lever not found" return false end
    local before = padModel()
    near(w, 5)
    if not fire(p) then return false end
    P.pulls = P.pulls + 1
    -- a roll takes ~2 s to land; the next pull is only taken after it
    waitFor(function() local m = padModel() return m and m ~= before end, 3.5)
    nap(0.4)
    return true
end
local function buy()
    local pl = plot()
    local h = pl and pl:FindFirstChild("RolledSquishyPlaceHolder")
    local a = h and h:FindFirstChild("BuyPromptAttachment")
    local bp = a and a:FindFirstChild("BuyPrompt")
    local m = padModel()
    if not (bp and m) then return false end
    local name, c0 = m.Name, cash()
    near(h, 5)
    fire(bp)
    if waitFor(function() return held() ~= nil end, 2) then
        P.buys = P.buys + 1
        note(("BOUGHT %s for $%s"):format(info(name).displayName or name, fmt(c0 - cash())))
        return true
    end
    note("buy refused: " .. name)
    P.noBuy = { name = name, at = now() }
    return false
end
local function place()
    local name = held()
    local s = freeStation()
    if not (name and s) then return false end
    near(s.ph, 6)
    fire(s.pp)
    if waitFor(function() return s.st:GetAttribute("HasSquishy") == true or held() == nil end, 2.5) then
        P.waxes = P.waxes + 1
        note(("WAXING %s on station %s"):format(info(name).displayName or name, s.st.Name))
        return true
    end
    return false
end
local function collectorValue()
    local pl = plot()
    local cp = pl and pl:FindFirstChild("Collector") and pl.Collector:FindFirstChild("CollectorPart")
    local g = cp and cp:FindFirstChild("MoneyGui")
    local l = g and g:FindFirstChildWhichIsA("TextLabel", true)
    local t = l and l.Text or ""
    local num, suf = t:gsub(",", ""):match("([%d%.]+)%s*(%a*)")
    local n = tonumber(num)
    if not n then return 0, cp end
    for i, x in ipairs(SUF) do if x:lower() == (suf or ""):lower() then return n * 1000 ^ (i - 1), cp end end
    return n, cp
end
local function collect()
    local _, cp = collectorValue()
    local _, h = char()
    if not (cp and h) then return false end
    local c0 = cash()
    hop(cp.Position + Vector3.new(0, 3, 0))
    if type(firetouchinterest) == "function" then pcall(firetouchinterest, h, cp, 0) end
    nap(0.6)
    if type(firetouchinterest) == "function" then pcall(firetouchinterest, h, cp, 1) end
    hop(cp.Position + Vector3.new(0, 3, 9))
    nap(0.3)
    P.collects, P.lastCollect = P.collects + 1, now()
    if cash() > c0 then note(("COLLECTED +$%s"):format(fmt(cash() - c0))) end
    return true
end
local function buyStation() -- the next wax station, when it costs under a third of our cash
    local n = tonumber(plr:GetAttribute("WaxStations")) or 1
    local price = WAXP[n + 1]
    if not price or cash() < price * 3 then return false end
    local ok, a, b = invoke("BuyWax", n + 1)
    if ok and a then
        note(("BOUGHT wax station %d for $%s"):format(n + 1, fmt(price)))
        return true
    end
    -- the server may want us at the pitcher
    local pl = plot()
    local st = pl and pl.WaxStations:FindFirstChild(tostring(n + 1))
    local pm = st and st:FindFirstChild("Pitcher") and st.Pitcher:FindFirstChild("Mesh")
    if pm then
        near(pm, 5)
        ok, a, b = invoke("BuyWax", n + 1)
        if ok and a then note(("BOUGHT wax station %d for $%s"):format(n + 1, fmt(price))) return true end
    end
    P.noStationUntil = now() + 120
    note("wax station not bought: " .. tostring(b or a))
    return false
end

---------------------------------------------------------------- helping other players' waxes
local HX = { done = {}, tries = {}, nextAt = 0 }
function HX.list()
    local out, t, me = {}, srv(), tostring(plr.UserId)
    local my = plot()
    for _, pl in ipairs(WS:FindFirstChild("Plots") and WS.Plots:GetChildren() or {}) do
        local ws = pl ~= my and pl:FindFirstChild("WaxStations")
        for _, st in ipairs(ws and ws:GetChildren() or {}) do
            local o = st:GetAttribute("PourOwner")
            local id = st:GetAttribute("PourId")
            if type(o) == "number" and o ~= plr.UserId and st:GetAttribute("HasSquishy") and st:GetAttribute("PourLong") == true
                and st:GetAttribute("PourFull") ~= true and id and not HX.done[id] then
                local hs, n, mine = tostring(st:GetAttribute("Helpers") or ""), 0, false
                for u in hs:gmatch("[^,%s]+") do n = n + 1 if u == me then mine = true end end
                local e = tonumber(st:GetAttribute("PourEnd"))
                local owner = Players:GetPlayerByUserId(o)
                if not mine and n < 6 and owner and owner:GetAttribute("WaxHelpOff") ~= true and (not e or e - t > 75) then
                    local ph = st:FindFirstChild("SquishyPlaceHolder")
                    if ph then out[#out + 1] = { st = st, id = id, ph = ph, owner = owner } end
                end
            end
        end
    end
    return out
end
function HX.one()
    local w = HX.list()[1]
    if not w then HX.nextAt = now() + 20 return false end
    local tries = HX.tries[w.id] or 0
    local ph = w.ph
    hop(ph.Position + Vector3.new(0, tries == 0 and 0 or (ph.Size.Y / 2 + 3), 0)) -- inside the butter, then on top
    nap(0.35)
    local ok, v = invoke("ClanRequest", "help", w.st:GetAttribute("PourOwner"), tonumber(w.st.Name))
    local why = ok and type(v) == "table" and tostring(v.reason or v.text or "") or tostring(v)
    if ok and type(v) == "table" and v.ok then
        HX.done[w.id] = true
        P.helps = P.helps + 1
        note(("HELPED %s's wax"):format(w.owner.DisplayName))
    elseif why:lower():find("moment") then
        HX.nextAt = now() + 1.6 -- the server's pace limit: ask again shortly
        return true
    elseif why:lower():find("walk up") and tries < 1 then
        HX.tries[w.id] = tries + 1
    else
        HX.done[w.id] = true
    end
    HX.nextAt = now() + 1.4
    return true
end

---------------------------------------------------------------- deciding what to buy
-- Each wax station can only wax one butter at a time, so a station's time is what we spend. Buy:
--   * anything a "wax a Rare/Epic/Legendary" quest needs (and is the right rarity)
--   * anything at all while a "buy N" or "wax N" quest is open (cheap butters wax in 15 s)
--   * otherwise what makes the most money: a butter that earns more than the weakest in the stack
--     (or the stack has room), and is not trivially small next to our cash
local function stackMin()
    local ok, v = invoke("EditStack", "State", nil)
    local st = ok and type(v) == "table" and v.state
    if not st then return nil, 0, 100 end
    local lo
    for _, e in ipairs(st.entries or {}) do
        local inc = tonumber(e.perSecond or e.income) or 0
        if not lo or inc < lo then lo = inc end
    end
    return lo, #(st.entries or {}), tonumber(st.capacity) or 100
end
local function worthBuying(name)
    local i = info(name)
    local price, inc = tonumber(i.price) or math.huge, tonumber(i.income) or 0
    if i.incomeType or i.rarity == "Limited" then return false, "limited" end
    if price > cash() then return false, "too dear" end
    local need = PASS.rareNeed()
    if need and rankOf(name) >= need then return true, "rarity quest" end
    if PASS.open("buy") or PASS.open("stack") then return true, "quest" end
    if now() - (P.stackAt or 0) > 30 then P.stackLo, P.stackN, P.stackCap = stackMin() P.stackAt = now() end
    if (P.stackN or 0) < (P.stackCap or 100) then
        return price >= cash() * 0.01 or (P.stackN or 0) < 10, "room in the stack"
    end
    return inc > (P.stackLo or 0), "beats the weakest"
end

---------------------------------------------------------------- the loop
P.lastCollect = 0
local function step()
    if not CFG.Run then P.msg = "stopped" return end
    if not char() then P.msg = "waiting for the character" return end
    local tut = plr:GetAttribute("InTutorial") == true
    -- 1 hands full: wax it
    if held() then
        if freeStation() then P.msg = "waxing" place() else P.msg = "holding a butter, all stations busy" end
        return
    end
    -- 2 tutorial's collect step / money waiting in the collector
    local cv = collectorValue()
    local collectEvery = PASS.open("collect") and 6 or 25
    if (tut and plr:GetAttribute("TutorialStep") == "Collect") or (cv > 0 and now() - P.lastCollect > collectEvery) then
        P.msg = "collecting" collect() return
    end
    if tut and plr:GetAttribute("TutorialStep") == "WaitWax" then P.msg = "tutorial: waiting for the wax" return end
    -- 3 a wax station when it is cheap next to our cash
    if not tut and now() >= (P.noStationUntil or 0) and buyStation() then return end
    -- 4 help someone (help quests, and it is quick)
    if not tut and CFG.Help and PASS.open("help") and now() >= HX.nextAt then
        P.msg = "helping a wax" if HX.one() then return end
    end
    -- 5 something on the pad: buy it or roll again
    local m = padModel()
    if m and freeStation() then
        local yes, why = worthBuying(m.Name)
        if tut or (yes and not (P.noBuy and P.noBuy.name == m.Name and now() - P.noBuy.at < 10)) then
            P.msg = "buying " .. (info(m.Name).displayName or m.Name) .. " (" .. tostring(why or "tutorial") .. ")"
            buy()
            return
        end
    end
    -- 6 pull the lever (free): pull quests, and the next butter to look at
    if freeStation() or PASS.open("pull") then
        P.msg = "pulling the lever" pull() return
    end
    -- 7 nothing else: help anyone while every station waxes (it is free and helps your main)
    if CFG.Help and now() >= HX.nextAt then P.msg = "helping while stations wax" if HX.one() then return end end
    P.msg = "all stations waxing"
end

---------------------------------------------------------------- window
local C = { bg = Color3.fromRGB(22, 20, 18), panel = Color3.fromRGB(40, 33, 26), text = Color3.fromRGB(245, 236, 222),
    dim = Color3.fromRGB(170, 155, 135), on = Color3.fromRGB(226, 128, 40), off = Color3.fromRGB(70, 60, 50),
    good = Color3.fromRGB(80, 190, 110), bad = Color3.fromRGB(220, 80, 70) }
local function mk(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props) do pcall(function() o[k] = v end) end
    o.Parent = parent
    return o
end
local pg = plr:WaitForChild("PlayerGui")
if pg:FindFirstChild("SABPassGui") then pg.SABPassGui:Destroy() end
local sg = mk("ScreenGui", { Name = "SABPassGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 998 }, pg)
local W = mk("Frame", { Size = UDim2.new(0, 250, 0, 214), Position = UDim2.new(0, 12, 0, 60), BackgroundColor3 = C.bg,
    BorderSizePixel = 0, Active = true }, sg)
mk("UICorner", { CornerRadius = UDim.new(0, 10) }, W)
mk("UIStroke", { Color = C.on, Thickness = 1 }, W)
local function lbl(parent, y, h, size, color, bold)
    return mk("TextLabel", { Position = UDim2.new(0, 10, 0, y), Size = UDim2.new(1, -20, 0, h), BackgroundTransparency = 1,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextSize = size, TextColor3 = color, Text = "",
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true }, parent)
end
local title = lbl(W, 7, 16, 12, C.text, true)
title.Text = "SAB PASS FARMER  " .. VERSION
local function btn(text, x, w, y)
    local b = mk("TextButton", { Position = UDim2.new(x, x == 0 and 10 or 2, 0, y), Size = UDim2.new(w, -12, 0, 22), Text = text,
        BackgroundColor3 = C.off, TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 10, BorderSizePixel = 0, AutoButtonColor = true }, W)
    mk("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
    return b
end
local hideB = mk("TextButton", { Position = UDim2.new(1, -30, 0, 5), Size = UDim2.new(0, 22, 0, 18), Text = "_", BackgroundColor3 = C.off,
    TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12, BorderSizePixel = 0 }, W)
mk("UICorner", { CornerRadius = UDim.new(0, 5) }, hideB)
local rankL = lbl(W, 26, 30, 11, C.on, true)
local questL = lbl(W, 56, 70, 10, C.text, false)
local statL = lbl(W, 126, 28, 9, C.dim, false)
local runB, helpB, gfxB = btn("RUN", 0, 1 / 3, 156), btn("HELP", 1 / 3, 1 / 3, 156), btn("LOW GFX", 2 / 3, 1 / 3, 156)
local logL = lbl(W, 182, 30, 9, C.dim, false)
logL.TextTruncate = Enum.TextTruncate.AtEnd
-- drag by the title area
do
    local d
    W.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            d = { i.Position, W.Position }
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then d = nil end end)
        end
    end)
    track(UIS.InputChanged:Connect(function(i)
        if d and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
            local dx, dy = i.Position.X - d[1].X, i.Position.Y - d[1].Y
            W.Position = UDim2.new(0, d[2].X.Offset + dx, 0, d[2].Y.Offset + dy)
        end
    end))
end
local small = false
hideB.MouseButton1Click:Connect(function()
    small = not small
    W.Size = small and UDim2.new(0, 250, 0, 56) or UDim2.new(0, 250, 0, 214)
    hideB.Text = small and "+" or "_"
    for _, o in ipairs({ questL, statL, runB, helpB, gfxB, logL }) do o.Visible = not small end
end)

---------------------------------------------------------------- settings file, low graphics
local function save()
    if not writefile then return end
    pcall(function()
        if makefolder and isfolder and not isfolder("SAB") then makefolder("SAB") end
        writefile(FILE, ("Run=%s\nHelp=%s\nLowGfx=%s\nJob=%s\n"):format(tostring(CFG.Run), tostring(CFG.Help), tostring(CFG.LowGfx), CFG.Job))
    end)
end
pcall(function()
    if readfile and isfile and isfile(FILE) then
        for k, v in readfile(FILE):gmatch("(%w+)=([^\n]*)") do
            if v == "true" or v == "false" then CFG[k] = (v == "true") else CFG[k] = v end
        end
    end
end)
-- LOW GFX: the screen stays normal. Other players' bases, stacks and butters are made see-through on
-- this screen only (see-through parts are not drawn, nothing is removed, so helping still works);
-- floating labels, sparkles, shadows and post effects go off; a frame cap keeps the phone cool.
local GFX = { unseen = setmetatable({}, { __mode = "k" }) }
function GFX.hide(d)
    if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
        if d.Transparency < 1 then GFX.unseen[d] = d.Transparency d.Transparency = 1 end
    elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")
        or d:IsA("Light") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
        if d.Enabled then GFX.unseen[d] = true d.Enabled = false end
    end
end
function GFX.fx(d) -- effects anywhere (yours included): only the costly, purely visual ones
    if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
        if d.Enabled then GFX.unseen[d] = true d.Enabled = false end
    end
end
local function lowGfx(on)
    CFG.LowGfx = on
    pcall(function() RunS:Set3dRenderingEnabled(true) end) -- (older versions blanked the screen)
    local plots, mine = WS:FindFirstChild("Plots"), plot()
    local L = game:GetService("Lighting")
    if on then
        task.spawn(function()
            local n = 0
            for _, d in ipairs(WS:GetDescendants()) do
                if not CFG.LowGfx then return end
                if plots and d:IsDescendantOf(plots) and not (mine and d:IsDescendantOf(mine)) then pcall(GFX.hide, d) else pcall(GFX.fx, d) end
                n = n + 1
                if n % 600 == 0 then task.wait() end
            end
        end)
        if not GFX.conn then
            GFX.conn = track(WS.DescendantAdded:Connect(function(d)
                if not CFG.LowGfx then return end
                task.defer(function()
                    local p, m = WS:FindFirstChild("Plots"), plot()
                    if p and d:IsDescendantOf(p) and not (m and d:IsDescendantOf(m)) then pcall(GFX.hide, d) else pcall(GFX.fx, d) end
                end)
            end))
        end
        pcall(function() GFX.shadows = GFX.shadows == nil and L.GlobalShadows or GFX.shadows L.GlobalShadows = false end)
        for _, e in ipairs(L:GetChildren()) do
            if e:IsA("PostEffect") and e.Enabled then GFX.unseen[e] = true e.Enabled = false end
        end
    else
        for d, v in pairs(GFX.unseen) do
            pcall(function()
                if not d.Parent then return end
                if type(v) == "number" then d.Transparency = v else d.Enabled = true end
            end)
        end
        GFX.unseen = setmetatable({}, { __mode = "k" })
        if GFX.shadows ~= nil then pcall(function() L.GlobalShadows = GFX.shadows end) GFX.shadows = nil end
    end
    local f = (type(setfpscap) == "function" and setfpscap) or nil
    if f then pcall(f, on and CFG.FpsCap or 60) end
end
local function paint()
    runB.BackgroundColor3 = CFG.Run and C.good or C.off
    runB.Text = CFG.Run and "RUNNING" or "STOPPED"
    helpB.BackgroundColor3 = CFG.Help and C.on or C.off
    gfxB.BackgroundColor3 = CFG.LowGfx and C.on or C.off
end
runB.MouseButton1Click:Connect(function() CFG.Run = not CFG.Run paint() save() end)
helpB.MouseButton1Click:Connect(function() CFG.Help = not CFG.Help paint() save() end)
gfxB.MouseButton1Click:Connect(function() lowGfx(not CFG.LowGfx) paint() save() end)
paint()
if CFG.LowGfx then lowGfx(true) end

local function refresh()
    local st = PASS.st
    if st then
        local pts, rank = tonumber(st.points) or 0, tonumber(st.rank) or 0
        local nextAt = PASS.cfg and PASS.cfg.pointsFor and PASS.cfg.pointsFor(math.min(rank + 1, 20)) or 0
        local left = math.max(0, (tonumber(st.resetsAt) or srv()) - srv())
        rankL.Text = ("%s pass: rank %d / 20   %d acorns%s\nnew quests in %dh %02dm"):format(PASS.id or "?", rank, pts,
            rank < 20 and (" (next at " .. nextAt .. ")") or " - MAX", math.floor(left / 3600), math.floor((left % 3600) / 60))
        local L = {}
        for _, q in ipairs(st.quests) do
            L[#L + 1] = ("%s %s  %d/%d"):format(q.claimed and "[ok]" or (q.done and "[!!]" or "[  ]"), q.text, q.progress or 0, q.goal or 0)
        end
        questL.Text = table.concat(L, "\n")
    else
        rankL.Text = "no live event pass found"
        questL.Text = ""
    end
    statL.Text = ("$%s | stations %s | %s\npulls %d  bought %d  waxed %d  helps %d"):format(fmt(cash()),
        tostring(plr:GetAttribute("WaxStations") or 1), P.msg or "", P.pulls, P.buys, P.waxes, P.helps)
    logL.Text = table.concat({ P.log[1] or "", P.log[2] or "" }, "\n")
end

---------------------------------------------------------------- staying in the game
-- anti-idle, and a rejoin (to the pinned server if there is one) when the game drops us. It does NOT
-- queue itself for the next server: it only starts when you run it or Delta's autoexecute does.
track(plr.Idled:Connect(function()
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
end))
local function rejoin(why)
    if P.rejoining then return end
    P.rejoining = true
    note("REJOIN: " .. tostring(why))
    local TS = game:GetService("TeleportService")
    local ok = false
    if CFG.Job ~= "" then ok = pcall(function() TS:TeleportToPlaceInstance(game.PlaceId, CFG.Job, plr) end) end
    if not ok then pcall(function() TS:Teleport(game.PlaceId, plr) end) end
    task.delay(30, function() P.rejoining = false end)
end
pcall(function()
    local cg = game:GetService("CoreGui")
    local pr = cg:FindFirstChild("RobloxPromptGui")
    local ov = pr and pr:FindFirstChild("promptOverlay")
    if ov then track(ov.ChildAdded:Connect(function(c) if c.Name == "ErrorPrompt" then task.wait(2) rejoin("disconnected") end end)) end
end)
pcall(function()
    local ask = remote("RollConfirmAsk") -- "roll away your X?": yes, on an alt
    if ask then track(ask.OnClientEvent:Connect(function(name) task.spawn(function() invoke("RollConfirmAnswer", name) end) end)) end
end)

---------------------------------------------------------------- run
function P.kill()
    P.alive = false
    if CFG.LowGfx then pcall(lowGfx, false) CFG.LowGfx = true end -- back to normal, the saved choice kept
    for _, c in ipairs(P.conns) do pcall(function() c:Disconnect() end) end
    pcall(function() sg:Destroy() end)
end
genv.SABP = { P = P, CFG = CFG, PASS = PASS, HX = HX, kill = P.kill, step = step, VERSION = VERSION,
    pin = function() CFG.Job = game.JobId save() note("this server is now the one to rejoin") end }
note(VERSION .. " loaded")
task.spawn(function() -- the pass: read it, claim what is done, every 20 s
    while P.alive do
        local ok, e = pcall(function() PASS.refresh() PASS.claimAll() end)
        if not ok and e ~= KILLED then note("pass: " .. tostring(e)) end
        task.wait(20)
    end
end)
task.spawn(function() -- the farm
    task.wait(3)
    while P.alive do
        local ok, e = pcall(step)
        if not ok and e ~= KILLED then note("error: " .. tostring(e)) task.wait(2) end
        task.wait(0.15)
    end
end)
task.spawn(function()
    while P.alive do pcall(refresh) task.wait(1) end
end)
