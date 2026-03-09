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
    { id = "DamageMeterSessionWindow1", label = "Ventana Recount 1" },
    { id = "DamageMeterSessionWindow2", label = "Ventana Recount 2" }
}

-- 3. Motor HUD (Lógica de visibilidad)
local delayEndTime, isCountingDown, lastFinalState, fadeSpeed = 0, false, "hide", 3 

local function GetTargetState()
    if not Kaneri_Tool_Settings or not Kaneri_Tool_Settings.GlobalConfig then return "show" end
    local cfg = Kaneri_Tool_Settings.GlobalConfig
    if cfg.forceShowAll then isCountingDown = false return "show" end

    -- Prioridad por Zonas
    local zoneResult = 0
    if IsResting() and cfg.z_city ~= 0 then zoneResult = cfg.z_city
    elseif (IsInRaid() and IsIndoors()) and cfg.z_raid ~= 0 then zoneResult = cfg.z_raid
    elseif (IsInGroup() and IsIndoors()) and cfg.z_party ~= 0 then zoneResult = cfg.z_party
    elseif IsIndoors() and not IsInGroup() and cfg.z_delve ~= 0 then zoneResult = cfg.z_delve
    elseif cfg.z_world ~= 0 then zoneResult = cfg.z_world end

    if zoneResult == 1 then isCountingDown = false return "show" 
    elseif zoneResult == -1 then isCountingDown = false return "hide" end

    -- Condiciones Automáticas (Nueva: Flying)
    local anyAuto = (cfg.combat and InCombatLockdown()) or 
                    (cfg.exists and UnitExists("target")) or 
                    (cfg.stealth and IsStealthed()) or 
                    (cfg.harm and UnitCanAttack("player", "target")) or
                    (cfg.flying and IsFlying())

    if anyAuto then isCountingDown = false return "show" end
    
    -- Manejo del Retraso (Delay)
    if lastFinalState == "show" and not anyAuto then
        if not isCountingDown then 
            delayEndTime = GetTime() + (cfg.delay or 0) 
            isCountingDown = true 
        end
    end
    
    if isCountingDown then
        if GetTime() < delayEndTime then return "show" else isCountingDown = false return "hide" end
    end
    
    return "hide"
end

-- 4. Aplicación de Alpha (Fade)
local engine = CreateFrame("Frame")
engine:SetScript("OnUpdate", function(self, elapsed)
    local isEditing = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    local state = GetTargetState()
    local targetAlpha = (state == "show" or isEditing) and 1 or 0
    
    for _, data in ipairs(barList) do
        local frame = _G[data.id]
        if frame then
            if isEditing or (Kaneri_Tool_Settings and Kaneri_Tool_Settings.ActiveBars[data.id]) then
                local currentAlpha = frame:GetAlpha()
                if currentAlpha ~= targetAlpha then
                    local step = elapsed * fadeSpeed
                    frame:SetAlpha(currentAlpha < targetAlpha and math.min(targetAlpha, currentAlpha + step) or math.max(targetAlpha, currentAlpha - step))
                end
            else
                if frame:GetAlpha() ~= 1 then frame:SetAlpha(1) end
            end
        end
    end
    lastFinalState = state
end)

-- 5. Vendedor y Reparación
local sellFrame = CreateFrame("Frame")
sellFrame:RegisterEvent("MERCHANT_SHOW")
sellFrame:SetScript("OnEvent", function()
    if not Kaneri_Tool_Settings then return end
    local cfg = Kaneri_Tool_Settings.GlobalConfig
    if cfg.autoSell and C_MerchantFrame.GetNumJunkItems() > 0 then
        C_MerchantFrame.SellAllJunkItems()
    end
    if cfg.autoRepair and CanMerchantRepair() then
        local cost = GetRepairAllCost()
        if cost > 0 and GetMoney() >= cost then
            RepairAllItems()
            print(string.format("|cffffcc00Kaneri Tool:|r Reparado por %s.", GetCoinTextureString(cost)))
        end
    end
end)

-- 6. Interfaz de Usuario
local panel = CreateFrame("Frame", "KaneriToolOptionsPanel", UIParent, "BackdropTemplate")
panel:SetSize(460, 710); panel:SetPoint("CENTER"); panel:Hide()
panel:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { 8, 8, 8, 8 }})
panel:SetBackdropColor(0, 0, 0, 0.95)
panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving); panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

local function UpdateZoneBtn(btn, val)
    if val == 1 then btn:SetText("VISIBLE"); btn.Text:SetTextColor(0, 1, 0)
    elseif val == -1 then btn:SetText("OCULTO"); btn.Text:SetTextColor(1, 0, 0)
    else btn:SetText("AUTO"); btn.Text:SetTextColor(0.6, 0.6, 1) end
end

local function SetupUI()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20); title:SetText("Kaneri Tool")

    -- Checkboxes superiores
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
    s1:SetPoint("TOPLEFT", 30, -85); s1:SetText("1. Elementos a controlar")
    for i, data in ipairs(barList) do
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        local col, row = (i % 2 == 0) and 1 or 0, math.floor((i - 1) / 2)
        cb:SetPoint("TOPLEFT", 35 + (col * 190), -105 - (row * 28))
        cb.Text:SetText(data.label)
        cb:SetChecked(Kaneri_Tool_Settings.ActiveBars[data.id])
        cb:SetScript("OnClick", function(self) Kaneri_Tool_Settings.ActiveBars[data.id] = self:GetChecked() end)
    end

    -- 2. Zonas
    local s2 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s2:SetPoint("TOPLEFT", 30, -310); s2:SetText("2. Comportamiento por Zona")
    local zones = {{l="Exteriores", c="z_world"}, {l="Ciudades", c="z_city"}, {l="Profundidades", c="z_delve"}, {l="Mazmorras", c="z_party"}, {l="Bandas", c="z_raid"}}
    for i, zone in ipairs(zones) do
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

    -- 3. Condiciones AUTO (Incluye Volando)
    local s3 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s3:SetPoint("TOPLEFT", 30, -510); s3:SetText("3. Condiciones 'AUTO' (Mostrar si...)")
    local conds = {
        {l="En Combate", c="combat"}, {l="Objetivo Hostil", c="harm"}, 
        {l="Tener Objetivo", c="exists"}, {l="En Sigilo", c="stealth"},
        {l="|cff00ccffVolando|r", c="flying"}
    }
    for i, cond in ipairs(conds) do
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        local col, row = (i % 2 == 0) and 1 or 0, math.floor((i - 1) / 2)
        cb:SetPoint("TOPLEFT", 35 + (col * 190), -535 - (row * 24))
        cb.Text:SetText(cond.l)
        cb:SetChecked(Kaneri_Tool_Settings.GlobalConfig[cond.c])
        cb:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig[cond.c] = self:GetChecked() end)
    end

    -- Slider Delay
    local slider = CreateFrame("Slider", "KaneriDelaySlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 40, -660); slider:SetWidth(380)
    slider:SetMinMaxValues(0, 30); slider:SetValueStep(1); slider:SetObeyStepOnDrag(true)
    slider:SetValue(Kaneri_Tool_Settings.GlobalConfig.delay or 2)
    _G[slider:GetName() .. 'Text']:SetText("Retraso al ocultar: " .. slider:GetValue() .. "s")
    slider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        _G[self:GetName() .. 'Text']:SetText("Retraso al ocultar: " .. val .. "s")
        Kaneri_Tool_Settings.GlobalConfig.delay = val
    end)

    CreateFrame("Button", nil, panel, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -5, -5)
end

-- 7. Carga Inicial
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addon)
    if addon == "Kaneri_Tool" then
        if not Kaneri_Tool_Settings then 
            Kaneri_Tool_Settings = { 
                GlobalConfig = { forceShowAll=false, autoRepair=true, autoSell=true, combat=true, harm=true, exists=true, stealth=false, flying=true, z_party=0, z_raid=0, z_city=0, z_delve=0, z_world=0, delay=2 }, 
                ActiveBars = {} 
            } 
        end
        SetupUI()
    end
end)