-- 1. Registro del Comando
SLASH_KT1 = "/kt"
SlashCmdList["KT"] = function(msg)
    if msg == "toggle" then
        if Kaneri_Tool_Settings and Kaneri_Tool_Settings.GlobalConfig then
            local newState = not Kaneri_Tool_Settings.GlobalConfig.forceShowAll
            Kaneri_Tool_Settings.GlobalConfig.forceShowAll = newState
            if KaneriToolMasterCB then KaneriToolMasterCB:SetChecked(newState) end
            print("|cffffcc00Kaneri Tool:|r HUD " .. (newState and "|cff00ff00ON|r" or "|cff00ccffAUTO|r"))
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
            else if frame:GetAlpha() ~= 1 then frame:SetAlpha(1) end end
        end
    end
end)

-- 5. Eventos (Venta/Repara)
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

-- 6. Interfaz de Usuario (ANCHO AUMENTADO)
local panel = CreateFrame("Frame", "KaneriToolOptionsPanel", UIParent, "BackdropTemplate")
panel:SetSize(800, 710); panel:SetPoint("CENTER"); panel:Hide()
panel:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { 8, 8, 8, 8 }})
panel:SetBackdropColor(0, 0, 0, 0.95); panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving); panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

local function UpdateZoneBtn(btn, val)
    if val == 1 then btn:SetText("VISIBLE"); btn.Text:SetTextColor(0, 1, 0)
    elseif val == -1 then btn:SetText("OCULTO"); btn.Text:SetTextColor(1, 0, 0)
    else btn:SetText("AUTO"); btn.Text:SetTextColor(0.6, 0.6, 1) end
end

local function SetupUI()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20); title:SetText("Kaneri Tool")

    -- Superior
    local masterCB = CreateFrame("CheckButton", "KaneriToolMasterCB", panel, "InterfaceOptionsCheckButtonTemplate")
    masterCB:SetPoint("TOPLEFT", 100, -45); masterCB.Text:SetText("|cff00ff00HUD SIEMPRE ON|r")
    masterCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.forceShowAll)
    masterCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.forceShowAll = self:GetChecked() end)

    local repairCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    repairCB:SetPoint("TOPLEFT", 350, -45); repairCB.Text:SetText("|cffffff00REPARAR|r")
    repairCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.autoRepair)
    repairCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.autoRepair = self:GetChecked() end)

    local sellCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    sellCB:SetPoint("TOPLEFT", 550, -45); sellCB.Text:SetText("|cffaaaaaaVENDER|r")
    sellCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.autoSell)
    sellCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.autoSell = self:GetChecked() end)

    -- 1. ELEMENTOS (Estructura Ancha)
    local s1 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s1:SetPoint("TOPLEFT", 30, -85); s1:SetText("1. Configuración de Elementos (Individual)")

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(740, 220); scrollFrame:SetPoint("TOPLEFT", 25, -110)
    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(720, 400)
    scrollFrame:SetScrollChild(scrollChild)

    for i, data in ipairs(barList) do
        local y = -((i-1) * 30)
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(720, 28); row:SetPoint("TOPLEFT", 0, y)

        -- Checkbox principal
        local cb = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("LEFT", 5, 0); cb:SetSize(24, 24)
        cb:SetChecked(Kaneri_Tool_Settings.Bars[data.id].enabled)
        cb:SetScript("OnClick", function(self) Kaneri_Tool_Settings.Bars[data.id].enabled = self:GetChecked() end)

        -- Boton GLOBAL / CUSTOM (Más ancho)
        local mBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        mBtn:SetSize(80, 20); mBtn:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        
        -- Etiqueta nombre
        local txt = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        txt:SetPoint("LEFT", mBtn, "RIGHT", 10, 0); txt:SetText(data.label); txt:SetWidth(140); txt:SetJustifyH("LEFT")

        -- Contenedor de Opciones Custom (Palabras completas)
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

    -- 2. ZONAS (Global) - Ajustado al nuevo ancho
    local s2 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s2:SetPoint("TOP", 0, -340); s2:SetText("2. Comportamiento por Zona (Global)")
    local zDefs = {{l="Exteriores", c="z_world"}, {l="Ciudades", c="z_city"}, {l="Profundidades", c="z_delve"}, {l="Mazmorras", c="z_party"}, {l="Bandas", c="z_raid"}}
    for i, z in ipairs(zDefs) do
        local l = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", 250, -355 - (i * 30)); l:SetText(z.l)
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(120, 22); b:SetPoint("LEFT", l, "RIGHT", 150, 0)
        UpdateZoneBtn(b, Kaneri_Tool_Settings.GlobalConfig[z.c])
        b:SetScript("OnClick", function(self)
            local cur = Kaneri_Tool_Settings.GlobalConfig[z.c]
            Kaneri_Tool_Settings.GlobalConfig[z.c] = (cur == 0) and 1 or (cur == 1 and -1 or 0)
            UpdateZoneBtn(self, Kaneri_Tool_Settings.GlobalConfig[z.c])
        end)
    end

    -- 3. CONDICIONES (Global)
    local s3 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s3:SetPoint("TOP", 0, -530); s3:SetText("3. Condiciones 'AUTO' (Global)")
    local cDefs = {{l="En Combate", c="combat"}, {l="Objetivo Hostil", c="harm"}, {l="Tener Objetivo", c="exists"}, {l="En Sigilo", c="stealth"}, {l="|cff00ccffVolando|r", c="flying"}}
    for i, cond in ipairs(cDefs) do
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        local col, row = (i % 2 == 0) and 1 or 0, math.floor((i-1)/2)
        cb:SetPoint("TOPLEFT", 220 + (col * 220), -555 - (row * 24))
        cb.Text:SetText(cond.l); cb:SetChecked(Kaneri_Tool_Settings.GlobalConfig[cond.c])
        cb:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig[cond.c] = self:GetChecked() end)
    end

    local slider = CreateFrame("Slider", "KaneriDelaySlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("BOTTOM", 0, 40); slider:SetWidth(600)
    slider:SetMinMaxValues(0, 30); slider:SetValueStep(1); slider:SetObeyStepOnDrag(true)
    slider:SetValue(Kaneri_Tool_Settings.GlobalConfig.delay or 2)
    _G[slider:GetName()..'Text']:SetText("Retraso Global antes de ocultar: "..slider:GetValue().."s")
    slider:SetScript("OnValueChanged", function(self, v)
        local val = math.floor(v)
        _G[self:GetName()..'Text']:SetText("Retraso Global antes de ocultar: "..val.."s")
        Kaneri_Tool_Settings.GlobalConfig.delay = val
    end)

    CreateFrame("Button", nil, panel, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -5, -5)
end

-- 7. Carga
local ldr = CreateFrame("Frame")
ldr:RegisterEvent("ADDON_LOADED")
ldr:SetScript("OnEvent", function(self, event, addon)
    if addon ~= "Kaneri_Tool" then return end
    local d = { forceShowAll=false, autoRepair=true, autoSell=true, combat=true, harm=true, exists=true, stealth=false, flying=true, z_party=0, z_raid=0, z_city=0, z_delve=0, z_world=0, delay=2 }
    if not Kaneri_Tool_Settings then Kaneri_Tool_Settings = { GlobalConfig = d, Bars = {} } end
    for _, data in ipairs(barList) do
        if not Kaneri_Tool_Settings.Bars[data.id] then
            Kaneri_Tool_Settings.Bars[data.id] = { enabled = false, isCustom = false, customConfig = CopyTable(d) }
        end
    end
    SetupUI()
end)