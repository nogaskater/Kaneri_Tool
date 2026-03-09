-- 1. Registro del Comando
SLASH_KT1 = "/kt"
SlashCmdList["KT"] = function(msg)
    if KaneriToolOptionsPanel:IsShown() then 
        KaneriToolOptionsPanel:Hide() 
        if KaneriToolConfigPanel then KaneriToolConfigPanel:Hide() end
    else 
        KaneriToolOptionsPanel:Show() 
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
    if not cfg or not Kaneri_Tool_Settings.GlobalConfig.visibilidadActiva then return "show" end
    local z = 0
    if IsResting() and cfg.z_city ~= 0 then z = cfg.z_city
    elseif (IsInRaid() and IsIndoors()) and cfg.z_raid ~= 0 then z = cfg.z_raid
    elseif (IsInGroup() and IsIndoors()) and cfg.z_party ~= 0 then z = cfg.z_party
    elseif IsIndoors() and not IsInGroup() and cfg.z_delve ~= 0 then z = cfg.z_delve
    elseif cfg.z_world ~= 0 then z = cfg.z_world end
    if z == 1 then return "show" elseif z == -1 then return "hide" end
    local any = (cfg.combat and InCombatLockdown()) or (cfg.exists and UnitExists("target")) or 
                (cfg.stealth and IsStealthed()) or (cfg.harm and UnitCanAttack("player", "target")) or (cfg.flying and IsFlying())
    return any and "show" or "hide"
end

-- 4. Aplicación de Alpha
local engine = CreateFrame("Frame")
engine:SetScript("OnUpdate", function(self, elapsed)
    if not Kaneri_Tool_Settings or not Kaneri_Tool_Settings.Bars then return end
    local isEditing = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    for _, data in ipairs(barList) do
        local frame = _G[data.id]
        if frame then
            local b = Kaneri_Tool_Settings.Bars[data.id]
            if b and b.enabled then
                if not Kaneri_Tool_Settings.GlobalConfig.visibilidadActiva then
                    if frame:GetAlpha() ~= 1 then frame:SetAlpha(1) end
                else
                    local cfg = b.isCustom and b.customConfig or Kaneri_Tool_Settings.GlobalConfig
                    local target = GetTargetState(cfg)
                    if not barStates[data.id] then barStates[data.id] = { last = "hide", timer = 0 } end
                    local s = barStates[data.id]
                    if target == "show" then s.timer = 0; s.last = "show"
                    elseif s.last == "show" then
                        if s.timer == 0 then s.timer = GetTime() + (cfg.delay or 0) end
                        if GetTime() >= s.timer then s.last = "hide" end
                    end
                    local tAlpha = (s.last == "show" or isEditing) and 1 or 0
                    local cAlpha = frame:GetAlpha()
                    if cAlpha ~= tAlpha then
                        local step = elapsed * 3
                        frame:SetAlpha(cAlpha < tAlpha and math.min(tAlpha, cAlpha + step) or math.max(tAlpha, cAlpha - step))
                    end
                end
            else if frame:GetAlpha() ~= 1 then frame:SetAlpha(1) end end
        end
    end
end)

-- 5. Venta y Reparación
local sellFrame = CreateFrame("Frame")
sellFrame:RegisterEvent("MERCHANT_SHOW")
sellFrame:SetScript("OnEvent", function()
    local cfg = Kaneri_Tool_Settings.GlobalConfig
    if cfg.autoSell and C_MerchantFrame.GetNumJunkItems() > 0 then C_MerchantFrame.SellAllJunkItems() end
    if cfg.autoRepair and CanMerchantRepair() then
        local cost = GetRepairAllCost()
        if cost > 0 and GetMoney() >= cost then RepairAllItems(); print("|cffffcc00Kaneri Tool:|r Reparado.") end
    end
end)

-- 6. INTERFAZ DE USUARIO
local panel = CreateFrame("Frame", "KaneriToolOptionsPanel", UIParent, "BackdropTemplate")
panel:SetSize(240, 160); panel:SetPoint("CENTER"); panel:Hide()
panel:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { 4, 4, 4, 4 }})
panel:SetBackdropColor(0, 0, 0, 0.9); panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving); panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

-- PANEL DE CONFIGURACIÓN (A LA DERECHA, ALINEADO ARRIBA)
local configPanel = CreateFrame("Frame", "KaneriToolConfigPanel", panel, "BackdropTemplate")
configPanel:SetSize(800, 710); configPanel:SetPoint("TOPLEFT", panel, "TOPRIGHT", 10, 0); configPanel:Hide()
configPanel:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { 8, 8, 8, 8 }})
configPanel:SetBackdropColor(0, 0, 0, 0.95)

local function UpdateZoneBtn(btn, val)
    if val == 1 then btn:SetText("VISIBLE"); btn.Text:SetTextColor(0, 1, 0)
    elseif val == -1 then btn:SetText("OCULTO"); btn.Text:SetTextColor(1, 0, 0)
    else btn:SetText("AUTO"); btn.Text:SetTextColor(0.6, 0.6, 1) end
end

local function SetupUI()
    -- PANEL PRINCIPAL (CONTROL RÁPIDO)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", 0, -12); title:SetText("Kaneri Tool")

    -- 1. Visibilidad
    local visCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    visCB:SetPoint("TOPLEFT", 15, -40); visCB:SetSize(24, 24)
    visCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.visibilidadActiva)
    visCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.visibilidadActiva = self:GetChecked() end)

    local visBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    visBtn:SetSize(160, 22); visBtn:SetPoint("LEFT", visCB, "RIGHT", 5, 0)
    visBtn:SetText("Visibilidad Barras")
    visBtn:SetScript("OnClick", function() if configPanel:IsShown() then configPanel:Hide() else configPanel:Show() end end)

    -- 2. Reparar
    local repCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    repCB:SetPoint("TOPLEFT", 15, -75); repCB.Text:SetText("Reparar Auto.")
    repCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.autoRepair)
    repCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.autoRepair = self:GetChecked() end)

    -- 3. Vender
    local sellCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    sellCB:SetPoint("TOPLEFT", 15, -110); sellCB.Text:SetText("Vender Basura")
    sellCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.autoSell)
    sellCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.autoSell = self:GetChecked() end)

    CreateFrame("Button", nil, panel, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -2, -2)

    -- PANEL DE CONFIGURACIÓN (DETALLE)
    local cfgTitle = configPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    cfgTitle:SetPoint("TOP", 0, -20); cfgTitle:SetText("Configuración de Visibilidad")

    -- SECCIÓN 1: ELEMENTOS
    local s1 = configPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s1:SetPoint("TOPLEFT", 30, -60); s1:SetText("1. Configuración de Elementos (Individual)")

    local scrollFrame = CreateFrame("ScrollFrame", nil, configPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(740, 250); scrollFrame:SetPoint("TOPLEFT", 25, -85)
    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(720, 400)
    scrollFrame:SetScrollChild(scrollChild)

    for i, data in ipairs(barList) do
        local y = -((i-1) * 30)
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(720, 28); row:SetPoint("TOPLEFT", 0, y)

        local cb = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("LEFT", 5, 0); cb:SetSize(24, 24)
        cb:SetChecked(Kaneri_Tool_Settings.Bars[data.id].enabled)
        cb:SetScript("OnClick", function(self) Kaneri_Tool_Settings.Bars[data.id].enabled = self:GetChecked() end)

        local mBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        mBtn:SetSize(80, 20); mBtn:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        
        local txt = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        txt:SetPoint("LEFT", mBtn, "RIGHT", 10, 0); txt:SetText(data.label); txt:SetWidth(140); txt:SetJustifyH("LEFT")

        local optFrame = CreateFrame("Frame", nil, row)
        optFrame:SetSize(450, 28); optFrame:SetPoint("LEFT", txt, "RIGHT", 10, 0)

        local function CreateQuickCB(key, label, x)
            local c = CreateFrame("CheckButton", nil, optFrame, "InterfaceOptionsCheckButtonTemplate")
            c:SetSize(20, 20); c:SetPoint("LEFT", x, 0)
            c.Text:SetFontObject("GameFontNormalSmall"); c.Text:SetText(label)
            c:SetScript("OnClick", function(self) Kaneri_Tool_Settings.Bars[data.id].customConfig[key] = self:GetChecked() end)
            return c
        end

        local qComb = CreateQuickCB("combat", "Combate", 0)
        local qTarg = CreateQuickCB("exists", "Objetivo", 90)
        local qHarm = CreateQuickCB("harm", "Hostil", 180)
        local qStea = CreateQuickCB("stealth", "Sigilo", 260)
        local qFly  = CreateQuickCB("flying", "Vuelo", 340)
        
        local function Refresh()
            local isC = Kaneri_Tool_Settings.Bars[data.id].isCustom
            mBtn:SetText(isC and "CUSTOM" or "GLOBAL")
            local r, g, b = isC and 1 or 0.2, isC and 0.6 or 0.6, isC and 0.2 or 1
            mBtn:GetFontString():SetTextColor(r, g, b)
            if isC then 
                optFrame:Show()
                local cfg = Kaneri_Tool_Settings.Bars[data.id].customConfig
                qComb:SetChecked(cfg.combat); qTarg:SetChecked(cfg.exists)
                qHarm:SetChecked(cfg.harm); qStea:SetChecked(cfg.stealth); qFly:SetChecked(cfg.flying)
            else optFrame:Hide() end
        end

        mBtn:SetScript("OnClick", function() 
            Kaneri_Tool_Settings.Bars[data.id].isCustom = not Kaneri_Tool_Settings.Bars[data.id].isCustom
            Refresh()
        end)
        Refresh()
    end

    -- SECCIÓN 2: ZONAS
    local s2 = configPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s2:SetPoint("TOP", 0, -360); s2:SetText("2. Comportamiento por Zona (Global)")
    local zDefs = {{l="Exteriores", c="z_world"}, {l="Ciudades", c="z_city"}, {l="Profundidades", c="z_delve"}, {l="Mazmorras", c="z_party"}, {l="Bandas", c="z_raid"}}
    for i, z in ipairs(zDefs) do
        local l = configPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", 250, -375 - (i * 30)); l:SetText(z.l)
        local b = CreateFrame("Button", nil, configPanel, "UIPanelButtonTemplate")
        b:SetSize(120, 22); b:SetPoint("LEFT", l, "RIGHT", 150, 0)
        UpdateZoneBtn(b, Kaneri_Tool_Settings.GlobalConfig[z.c])
        b:SetScript("OnClick", function(self)
            local cur = Kaneri_Tool_Settings.GlobalConfig[z.c]
            Kaneri_Tool_Settings.GlobalConfig[z.c] = (cur == 0) and 1 or (cur == 1 and -1 or 0)
            UpdateZoneBtn(self, Kaneri_Tool_Settings.GlobalConfig[z.c])
        end)
    end

    -- SECCIÓN 3: CONDICIONES GLOBAL
    local s3 = configPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s3:SetPoint("TOP", 0, -560); s3:SetText("3. Condiciones 'AUTO' (Global)")
    local cDefs = {{l="En Combate", c="combat"}, {l="Objetivo Hostil", c="harm"}, {l="Tener Objetivo", c="exists"}, {l="En Sigilo", c="stealth"}, {l="|cff00ccffVolando|r", c="flying"}}
    for i, cond in ipairs(cDefs) do
        local cb = CreateFrame("CheckButton", nil, configPanel, "InterfaceOptionsCheckButtonTemplate")
        local col, row = (i % 2 == 0) and 1 or 0, math.floor((i-1)/2)
        cb:SetPoint("TOPLEFT", 220 + (col * 220), -585 - (row * 24))
        cb.Text:SetText(cond.l); cb:SetChecked(Kaneri_Tool_Settings.GlobalConfig[cond.c])
        cb:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig[cond.c] = self:GetChecked() end)
    end

    local slider = CreateFrame("Slider", "KaneriDelaySlider", configPanel, "OptionsSliderTemplate")
    slider:SetPoint("BOTTOM", 0, 40); slider:SetWidth(600)
    slider:SetMinMaxValues(0, 30); slider:SetValueStep(1); slider:SetObeyStepOnDrag(true)
    slider:SetValue(Kaneri_Tool_Settings.GlobalConfig.delay or 2)
    _G[slider:GetName()..'Text']:SetText("Retraso Global antes de ocultar: "..slider:GetValue().."s")
    slider:SetScript("OnValueChanged", function(self, v)
        local val = math.floor(v)
        _G[self:GetName()..'Text']:SetText("Retraso Global antes de ocultar: "..val.."s")
        Kaneri_Tool_Settings.GlobalConfig.delay = val
    end)

    CreateFrame("Button", nil, configPanel, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -5, -5)
end

-- 7. Carga
local ldr = CreateFrame("Frame")
ldr:RegisterEvent("ADDON_LOADED")
ldr:SetScript("OnEvent", function(self, event, addon)
    if addon ~= "Kaneri_Tool" then return end
    local d = { visibilidadActiva=true, autoRepair=true, autoSell=true, combat=true, harm=true, exists=true, stealth=false, flying=true, z_party=0, z_raid=0, z_city=0, z_delve=0, z_world=0, delay=2 }
    if not Kaneri_Tool_Settings then Kaneri_Tool_Settings = { GlobalConfig = d, Bars = {} } end
    for _, data in ipairs(barList) do
        if not Kaneri_Tool_Settings.Bars[data.id] then
            Kaneri_Tool_Settings.Bars[data.id] = { enabled = false, isCustom = false, customConfig = CopyTable(d) }
        end
    end
    SetupUI()
end)