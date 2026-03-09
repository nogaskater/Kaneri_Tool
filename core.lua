-- 1. Registro del Comando
SLASH_KT1 = "/kt"
SlashCmdList["KT"] = function(msg)
    if msg == "toggle" then
        if Kaneri_Tool_Settings and Kaneri_Tool_Settings.GlobalConfig then
            local newState = not Kaneri_Tool_Settings.GlobalConfig.forceShowAll
            Kaneri_Tool_Settings.GlobalConfig.forceShowAll = newState
            if KaneriToolMasterCB then KaneriToolMasterCB:SetChecked(newState) end
            print("|cffffcc00Kaneri Tool:|r HUD en modo " .. (newState and "|cff00ff00VISIBLE|r" or "|cff00ccffAUTO|r"))
        end
    else
        if KaneriToolOptionsPanel:IsShown() then KaneriToolOptionsPanel:Hide() else KaneriToolOptionsPanel:Show() end
    end
end

-- 2. Lista de Marcos
local barList = {
    { id = "PlayerFrame", label = "Retrato Jugador" },
    { id = "PetFrame", label = "Retrato Pet" },
    { id = "MainActionBar", label = "Barra 1" },
    { id = "MultiBarBottomLeft", label = "Barra 2" },
    { id = "MultiBarBottomRight", label = "Barra 3" },
    { id = "MultiBarRight", label = "Barra 4" },
    { id = "MultiBarLeft", label = "Barra 5" },
    { id = "MultiBar5", label = "Barra 6" },
    { id = "MultiBar6", label = "Barra 7" },
    { id = "PetActionBar", label = "Barra Pet" },
    { id = "StanceBar", label = "Formas" },
    { id = "DamageMeterSessionWindow1", label = "Recount 1" },
    { id = "DamageMeterSessionWindow2", label = "Recount 2" }
}

-- 3. Motor HUD
local barStates = {} 
local function GetTargetState(cfg)
    if not cfg then return "show" end
    if cfg.forceShowAll then return "show" end

    local zoneResult = 0
    if IsResting() and cfg.z_city ~= 0 then zoneResult = cfg.z_city
    elseif (IsInRaid() and IsIndoors()) and cfg.z_raid ~= 0 then zoneResult = cfg.z_raid
    elseif (IsInGroup() and IsIndoors()) and cfg.z_party ~= 0 then zoneResult = cfg.z_party
    elseif IsIndoors() and not IsInGroup() and cfg.z_delve ~= 0 then zoneResult = cfg.z_delve
    elseif cfg.z_world ~= 0 then zoneResult = cfg.z_world end

    if zoneResult == 1 then return "show" 
    elseif zoneResult == -1 then return "hide" end

    local anyAuto = (cfg.combat and InCombatLockdown()) or 
                    (cfg.exists and UnitExists("target")) or 
                    (cfg.stealth and IsStealthed()) or 
                    (cfg.harm and UnitCanAttack("player", "target")) or
                    (cfg.flying and IsFlying())

    return anyAuto and "show" or "hide"
end

-- 4. Aplicación de Alpha (Fade)
local engine = CreateFrame("Frame")
engine:SetScript("OnUpdate", function(self, elapsed)
    if not Kaneri_Tool_Settings or not Kaneri_Tool_Settings.Bars then return end
    local isEditing = EditModeManagerFrame and EditModeManagerFrame:IsShown()

    for _, data in ipairs(barList) do
        local frame = _G[data.id]
        if frame then
            local bSettings = Kaneri_Tool_Settings.Bars[data.id]
            if bSettings and bSettings.enabled then
                local activeCfg = bSettings.isCustom and bSettings.customConfig or Kaneri_Tool_Settings.GlobalConfig
                local targetState = GetTargetState(activeCfg)

                if not barStates[data.id] then barStates[data.id] = { last = "hide", timer = 0 } end
                local s = barStates[data.id]

                if targetState == "show" then
                    s.timer = 0; s.last = "show"
                elseif s.last == "show" then
                    if s.timer == 0 then s.timer = GetTime() + (activeCfg.delay or 0) end
                    if GetTime() >= s.timer then s.last = "hide" end
                end

                local targetAlpha = (s.last == "show" or isEditing) and 1 or 0
                local currentAlpha = frame:GetAlpha()
                if currentAlpha ~= targetAlpha then
                    local step = elapsed * 3
                    frame:SetAlpha(currentAlpha < targetAlpha and math.min(targetAlpha, currentAlpha + step) or math.max(targetAlpha, currentAlpha - step))
                end
            else
                if frame:GetAlpha() ~= 1 then frame:SetAlpha(1) end
            end
        end
    end
end)

-- 5. Vendedor y Reparación
local sellFrame = CreateFrame("Frame")
sellFrame:RegisterEvent("MERCHANT_SHOW")
sellFrame:SetScript("OnEvent", function()
    if not Kaneri_Tool_Settings then return end
    local cfg = Kaneri_Tool_Settings.GlobalConfig
    if cfg.autoSell and C_MerchantFrame.GetNumJunkItems() > 0 then C_MerchantFrame.SellAllJunkItems() end
    if cfg.autoRepair and CanMerchantRepair() then
        local cost = GetRepairAllCost()
        if cost > 0 and GetMoney() >= cost then
            RepairAllItems()
            print("|cffffcc00Kaneri Tool:|r Reparado.")
        end
    end
end)

-- 6. Interfaz de Usuario
local panel = CreateFrame("Frame", "KaneriToolOptionsPanel", UIParent, "BackdropTemplate")
panel:SetSize(460, 710); panel:SetPoint("CENTER"); panel:Hide()
panel:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { 8, 8, 8, 8 }})
panel:SetBackdropColor(0, 0, 0, 0.95); panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving); panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

local customPanel = CreateFrame("Frame", "KaneriToolCustomPanel", panel, "BackdropTemplate")
customPanel:SetSize(220, 240); customPanel:SetPoint("LEFT", panel, "RIGHT", 5, 0); customPanel:Hide()
customPanel:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { 4, 4, 4, 4 }})
customPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.95)

local currentEditingBar = nil

local function UpdateZoneBtn(btn, val)
    if not btn then return end
    if val == 1 then btn:SetText("VISIBLE"); btn.Text:SetTextColor(0, 1, 0)
    elseif val == -1 then btn:SetText("OCULTO"); btn.Text:SetTextColor(1, 0, 0)
    else btn:SetText("AUTO"); btn.Text:SetTextColor(0.6, 0.6, 1) end
end

local function OpenCustomSettings(barID, barLabel)
    currentEditingBar = barID
    customPanel:Hide()
    customPanel.Title:SetText("|cff00ffff" .. barLabel .. "|r")
    local cfg = Kaneri_Tool_Settings.Bars[barID].customConfig
    customPanel.combatCB:SetChecked(cfg.combat)
    customPanel.harmCB:SetChecked(cfg.harm)
    customPanel.existsCB:SetChecked(cfg.exists)
    customPanel.stealthCB:SetChecked(cfg.stealth)
    customPanel.flyingCB:SetChecked(cfg.flying)
    customPanel:Show()
end

local function SetupUI()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20); title:SetText("Kaneri Tool")

    local masterCB = CreateFrame("CheckButton", "KaneriToolMasterCB", panel, "InterfaceOptionsCheckButtonTemplate")
    masterCB:SetPoint("TOPLEFT", 30, -45); masterCB.Text:SetText("|cff00ff00HUD SIEMPRE ON|r")
    masterCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.forceShowAll)
    masterCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.forceShowAll = self:GetChecked() end)

    local repairCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    repairCB:SetPoint("TOPLEFT", 210, -45); repairCB.Text:SetText("|cffffff00REPARAR|r")
    repairCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.autoRepair)
    repairCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.autoRepair = self:GetChecked() end)

    local sellCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    sellCB:SetPoint("TOPLEFT", 330, -45); sellCB.Text:SetText("|cffaaaaaaVENDER|r")
    sellCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.autoSell)
    sellCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.autoSell = self:GetChecked() end)

    -- 1. Elementos
    local s1 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s1:SetPoint("TOPLEFT", 30, -85); s1:SetText("1. Elementos (|cff00ffffClick Dr: Condiciones|r)")
    for i, data in ipairs(barList) do
        local col, row = (i % 2 == 0) and 1 or 0, math.floor((i - 1) / 2)
        local xBase, yBase = 35 + (col * 190), -105 - (row * 28)
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", xBase, yBase); cb.Text:SetText(data.label)
        cb:SetChecked(Kaneri_Tool_Settings.Bars[data.id].enabled)
        cb:SetScript("OnClick", function(self) Kaneri_Tool_Settings.Bars[data.id].enabled = self:GetChecked() end)

        local mBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        mBtn:SetSize(22, 18); mBtn:SetPoint("LEFT", cb.Text, "RIGHT", 5, 0)
        mBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local function RefreshM()
            local isC = Kaneri_Tool_Settings.Bars[data.id].isCustom
            mBtn:SetText(isC and "C" or "G")
            mBtn:GetFontString():SetTextColor(isC and 1 or 0, isC and 0.6 or 1, isC and 0 or 1)
        end
        RefreshM()
        mBtn:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                Kaneri_Tool_Settings.Bars[data.id].isCustom = not Kaneri_Tool_Settings.Bars[data.id].isCustom
                RefreshM()
                if not Kaneri_Tool_Settings.Bars[data.id].isCustom then customPanel:Hide() end
            else
                if Kaneri_Tool_Settings.Bars[data.id].isCustom then OpenCustomSettings(data.id, data.label)
                else print("|cffffcc00Kaneri Tool:|r Activa [C] para personalizar.") end
            end
        end)
    end

    -- Panel Lateral de Condiciones
    customPanel.Title = customPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    customPanel.Title:SetPoint("TOP", 0, -15)
    local function CreateCustomCB(label, key, y)
        local cb = CreateFrame("CheckButton", nil, customPanel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 15, y); cb.Text:SetText(label)
        cb:SetScript("OnClick", function(self) if currentEditingBar then Kaneri_Tool_Settings.Bars[currentEditingBar].customConfig[key] = self:GetChecked() end end)
        return cb
    end
    customPanel.combatCB = CreateCustomCB("En Combate", "combat", -45)
    customPanel.harmCB = CreateCustomCB("Objetivo Hostil", "harm", -75)
    customPanel.existsCB = CreateCustomCB("Tener Objetivo", "exists", -105)
    customPanel.stealthCB = CreateCustomCB("En Sigilo", "stealth", -135)
    customPanel.flyingCB = CreateCustomCB("Volando", "flying", -165)

    -- 2. Zonas Globales
    local s2 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s2:SetPoint("TOPLEFT", 30, -310); s2:SetText("2. Comportamiento por Zona (Global)")
    local zonesDef = {{l="Exteriores", c="z_world"}, {l="Ciudades", c="z_city"}, {l="Profundidades", c="z_delve"}, {l="Mazmorras", c="z_party"}, {l="Bandas", c="z_raid"}}
    for i, zone in ipairs(zonesDef) do
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 40, -325 - (i * 30)); label:SetText(zone.l)
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(100, 22); btn:SetPoint("LEFT", label, "RIGHT", 130, 0)
        UpdateZoneBtn(btn, Kaneri_Tool_Settings.GlobalConfig[zone.c])
        btn:SetScript("OnClick", function(self)
            local cur = Kaneri_Tool_Settings.GlobalConfig[zone.c]
            Kaneri_Tool_Settings.GlobalConfig[zone.c] = (cur == 0) and 1 or (cur == 1 and -1 or 0)
            UpdateZoneBtn(self, Kaneri_Tool_Settings.GlobalConfig[zone.c])
        end)
    end

    -- 3. Condiciones Globales
    local s3 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s3:SetPoint("TOPLEFT", 30, -510); s3:SetText("3. Condiciones 'AUTO' (Global)")
    local condsDef = {{l="En Combate", c="combat"}, {l="Objetivo Hostil", c="harm"}, {l="Tener Objetivo", c="exists"}, {l="En Sigilo", c="stealth"}, {l="|cff00ccffVolando|r", c="flying"}}
    for i, cond in ipairs(condsDef) do
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        local col, row = (i % 2 == 0) and 1 or 0, math.floor((i - 1) / 2)
        cb:SetPoint("TOPLEFT", 35 + (col * 190), -535 - (row * 24))
        cb.Text:SetText(cond.l)
        cb:SetChecked(Kaneri_Tool_Settings.GlobalConfig[cond.c])
        cb:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig[cond.c] = self:GetChecked() end)
    end

    local slider = CreateFrame("Slider", "KaneriDelaySlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 40, -660); slider:SetWidth(380)
    slider:SetMinMaxValues(0, 30); slider:SetValueStep(1); slider:SetObeyStepOnDrag(true)
    slider:SetValue(Kaneri_Tool_Settings.GlobalConfig.delay or 2)
    _G[slider:GetName() .. 'Text']:SetText("Retraso Global: " .. slider:GetValue() .. "s")
    slider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        _G[self:GetName() .. 'Text']:SetText("Retraso Global: " .. val .. "s")
        Kaneri_Tool_Settings.GlobalConfig.delay = val
    end)

    CreateFrame("Button", nil, panel, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -5, -5)
    CreateFrame("Button", nil, customPanel, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -2, -2)
end

-- 7. Carga
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addon)
    if addon == "Kaneri_Tool" then
        local def = { forceShowAll=false, autoRepair=true, autoSell=true, combat=true, harm=true, exists=true, stealth=false, flying=true, z_party=0, z_raid=0, z_city=0, z_delve=0, z_world=0, delay=2 }
        if not Kaneri_Tool_Settings then Kaneri_Tool_Settings = {} end
        if not Kaneri_Tool_Settings.GlobalConfig then Kaneri_Tool_Settings.GlobalConfig = CopyTable(def) end
        if not Kaneri_Tool_Settings.Bars then Kaneri_Tool_Settings.Bars = {} end
        for _, data in ipairs(barList) do
            if not Kaneri_Tool_Settings.Bars[data.id] then
                Kaneri_Tool_Settings.Bars[data.id] = { enabled = false, isCustom = false, customConfig = CopyTable(def) }
            elseif not Kaneri_Tool_Settings.Bars[data.id].customConfig then
                Kaneri_Tool_Settings.Bars[data.id].customConfig = CopyTable(def)
            end
        end
        SetupUI()
    end
end)