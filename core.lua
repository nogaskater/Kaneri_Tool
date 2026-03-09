-- 1. Registro del Comando con Toggle y Seguridad de Carga
SLASH_KT1 = "/kt"
SlashCmdList["KT"] = function(msg)
    if not KaneriToolOptionsPanel then SetupUI() end
    
    if msg == "toggle" then
        if Kaneri_Tool_Settings and Kaneri_Tool_Settings.GlobalConfig then
            local cfg = Kaneri_Tool_Settings.GlobalConfig
            cfg.visibilidadActiva = not cfg.visibilidadActiva
            if KaneriVisCB then KaneriVisCB:SetChecked(cfg.visibilidadActiva) end
            local estado = cfg.visibilidadActiva and "|cff00ff00ACTIVADA|r" or "|cffff0000DESACTIVADA|r"
            print("|cffffcc00Kaneri Tool:|r Visibilidad " .. estado)
        end
    else
        if KaneriToolOptionsPanel:IsShown() then 
            KaneriToolOptionsPanel:Hide() 
            if KaneriToolConfigPanel then KaneriToolConfigPanel:Hide() end
        else 
            KaneriToolOptionsPanel:ClearAllPoints()
            KaneriToolOptionsPanel:SetPoint("CENTER", UIParent, "CENTER")
            KaneriToolOptionsPanel:Show() 
        end
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
    if not Kaneri_Tool_Settings or not Kaneri_Tool_Settings.GlobalConfig.visibilidadActiva then return "show" end
    local g = Kaneri_Tool_Settings.GlobalConfig
    local z = 0
    if IsResting() and g.z_city ~= 0 then z = g.z_city
    elseif (IsInRaid() and IsIndoors()) and g.z_raid ~= 0 then z = g.z_raid
    elseif (IsInGroup() and IsIndoors()) and g.z_party ~= 0 then z = g.z_party
    elseif IsIndoors() and not IsInGroup() and g.z_delve ~= 0 then z = g.z_delve
    elseif g.z_world ~= 0 then z = g.z_world end
    
    if z == 1 then return "show" end
    if z == -1 then return "hide" end
    
    local any = (cfg.combat and InCombatLockdown()) or 
                (cfg.exists and UnitExists("target")) or 
                (cfg.stealth and IsStealthed()) or 
                (cfg.harm and UnitCanAttack("player", "target")) or 
                (cfg.flying and IsFlying())
                
    return any and "show" or "hide"
end

-- 4. Aplicación de Alpha (OnUpdate)
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
                
                local maxAlpha = cfg.alpha or 1
                local tAlpha = (s.last == "show" or isEditing) and maxAlpha or 0
                local cAlpha = frame:GetAlpha()
                
                if math.abs(cAlpha - tAlpha) > 0.01 then
                    local step = elapsed * 3
                    frame:SetAlpha(cAlpha < tAlpha and math.min(tAlpha, cAlpha + step) or math.max(tAlpha, cAlpha - step))
                end
            else 
                if frame:GetAlpha() ~= 1 then frame:SetAlpha(1) end 
            end
        end
    end
end)

-- 5. Lógica de Mercader
local sellFrame = CreateFrame("Frame")
sellFrame:RegisterEvent("MERCHANT_SHOW")
sellFrame:SetScript("OnEvent", function()
    if not Kaneri_Tool_Settings then return end
    local cfg = Kaneri_Tool_Settings.GlobalConfig
    if cfg.autoSell and C_MerchantFrame.GetNumJunkItems() > 0 then C_MerchantFrame.SellAllJunkItems() end
    if cfg.autoRepair and CanMerchantRepair() then
        local cost = GetRepairAllCost()
        if cost > 0 and GetMoney() >= cost then RepairAllItems(); print("|cffffcc00Kaneri Tool:|r Reparado.") end
    end
end)

-- 6. INTERFAZ DE USUARIO
local function UpdateZoneBtn(btn, val)
    if not btn.Text then return end
    if val == 1 then btn.Text:SetText("VISIBLE"); btn.Text:SetTextColor(0, 1, 0)
    elseif val == -1 then btn.Text:SetText("OCULTO"); btn.Text:SetTextColor(1, 0, 0)
    else btn.Text:SetText("AUTO"); btn.Text:SetTextColor(0.6, 0.6, 1) end
end

function SetupUI()
    if KaneriToolOptionsPanel then return end

    local panel = CreateFrame("Frame", "KaneriToolOptionsPanel", UIParent, "BackdropTemplate")
    panel:SetSize(240, 160); panel:SetPoint("CENTER"); panel:Hide()
    panel:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { 4, 4, 4, 4 }})
    panel:SetBackdropColor(0, 0, 0, 0.9); panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
    panel:SetClampedToScreen(true)
    panel:SetScript("OnDragStart", panel.StartMoving); panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

    local configPanel = CreateFrame("Frame", "KaneriToolConfigPanel", panel, "BackdropTemplate")
    configPanel:SetSize(800, 720); configPanel:SetPoint("TOPLEFT", panel, "TOPRIGHT", 10, 0); configPanel:Hide()
    configPanel:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { 8, 8, 8, 8 }})
    configPanel:SetBackdropColor(0, 0, 0, 0.95); configPanel:SetResizable(true); configPanel:SetClampedToScreen(true)
    if configPanel.SetResizeBounds then configPanel:SetResizeBounds(800, 500, 800, 1000) end

    local rb = CreateFrame("Button", nil, configPanel)
    rb:SetPoint("BOTTOMRIGHT", -8, 8); rb:SetSize(16, 16)
    rb:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    rb:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    rb:SetScript("OnMouseDown", function() configPanel:StartSizing("BOTTOMRIGHT") end)
    rb:SetScript("OnMouseUp", function() configPanel:StopMovingOrSizing() end)

    -- CORRECCIÓN TÍTULO (Línea del error anterior arreglada)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", 0, -12); title:SetText("Kaneri Tool")
    
    local visCB = CreateFrame("CheckButton", "KaneriVisCB", panel, "InterfaceOptionsCheckButtonTemplate")
    visCB:SetPoint("TOPLEFT", 15, -40); visCB:SetSize(24, 24)
    visCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.visibilidadActiva)
    visCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.visibilidadActiva = self:GetChecked() end)

    local visBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    visBtn:SetSize(160, 22); visBtn:SetPoint("LEFT", visCB, "RIGHT", 5, 0)
    visBtn:SetText("Visibilidad Barras")
    visBtn:SetScript("OnClick", function() if configPanel:IsShown() then configPanel:Hide() else configPanel:Show() end end)

    local repCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    repCB:SetPoint("TOPLEFT", 15, -75); repCB.Text:SetText("Reparar Auto.")
    repCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.autoRepair)
    repCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.autoRepair = self:GetChecked() end)

    local sellCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    sellCB:SetPoint("TOPLEFT", 15, -110); sellCB.Text:SetText("Vender Basura")
    sellCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.autoSell)
    sellCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.autoSell = self:GetChecked() end)

    CreateFrame("Button", nil, panel, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -2, -2)

    local cfgTitle = configPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    cfgTitle:SetPoint("TOP", 0, -20); cfgTitle:SetText("Configuración de Visibilidad")

    -- ZONAS RECUPERADAS
    local zDefs = {{l="Exteriores", c="z_world"}, {l="Ciudades", c="z_city"}, {l="Profundidades", c="z_delve"}, {l="Mazmorras", c="z_party"}, {l="Bandas", c="z_raid"}}
    for i, z in ipairs(zDefs) do
        local l = configPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", 50, -65 - (i * 26)); l:SetText(z.l)
        local b = CreateFrame("Button", nil, configPanel, "UIPanelButtonTemplate")
        b:SetSize(100, 18); b:SetPoint("LEFT", l, "RIGHT", 60, 0)
        b.Text = b:GetFontString() -- Asegurar referencia al texto
        UpdateZoneBtn(b, Kaneri_Tool_Settings.GlobalConfig[z.c])
        b:SetScript("OnClick", function(self)
            local cur = Kaneri_Tool_Settings.GlobalConfig[z.c]
            Kaneri_Tool_Settings.GlobalConfig[z.c] = (cur == 0) and 1 or (cur == 1 and -1 or 0)
            UpdateZoneBtn(self, Kaneri_Tool_Settings.GlobalConfig[z.c])
        end)
    end

    -- CONDICIONES GLOBALES RECUPERADAS
    local cDefs = {{l="En Combate", c="combat"}, {l="Objetivo Hostil", c="harm"}, {l="Tener Objetivo", c="exists"}, {l="En Sigilo", c="stealth"}, {l="|cff00ccffVolando|r", c="flying"}}
    for i, cond in ipairs(cDefs) do
        local cb = CreateFrame("CheckButton", nil, configPanel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 430, -65 - (i * 26))
        cb.Text:SetText(cond.l); cb:SetChecked(Kaneri_Tool_Settings.GlobalConfig[cond.c])
        cb:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig[cond.c] = self:GetChecked() end)
    end

    -- SLIDERS GLOBALES RECUPERADOS
    local sliderBox = CreateFrame("Frame", nil, configPanel)
    sliderBox:SetPoint("TOP", 0, -215); sliderBox:SetSize(720, 60)
    
    local function CreateGlobalSlider(name, label, xOff, min, max, key)
        local s = CreateFrame("Slider", name, sliderBox, "OptionsSliderTemplate")
        s:SetPoint("CENTER", xOff, 0); s:SetWidth(280)
        s:SetMinMaxValues(min, max); s:SetValueStep(key == "alpha" and 0.05 or 1); s:SetObeyStepOnDrag(true)
        s:SetValue(Kaneri_Tool_Settings.GlobalConfig[key] or (key == "alpha" and 1 or 2))
        local txt = _G[s:GetName()..'Text']
        local function UpdateText(val)
            if key == "alpha" then txt:SetText(label..": "..math.floor(val*100).."%")
            else txt:SetText(label..": "..val.."s") end
        end
        UpdateText(s:GetValue())
        s:SetScript("OnValueChanged", function(self, v)
            Kaneri_Tool_Settings.GlobalConfig[key] = v
            UpdateText(v)
        end)
    end
    CreateGlobalSlider("KaneriGlobalDelay", "Retraso", -160, 0, 30, "delay")
    CreateGlobalSlider("KaneriGlobalAlpha", "Opacidad Máxima", 160, 0.1, 1, "alpha")

    -- LISTA DINÁMICA DE BARRAS RECUPERADA
    local scrollFrame = CreateFrame("ScrollFrame", "KaneriConfigScroll", configPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 25, -305); scrollFrame:SetPoint("BOTTOMRIGHT", -35, 35)
    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(720, #barList * 35)
    scrollFrame:SetScrollChild(scrollChild)

    for i, data in ipairs(barList) do
        if not Kaneri_Tool_Settings.Bars[data.id] then
            Kaneri_Tool_Settings.Bars[data.id] = { enabled = false, isCustom = false, customConfig = CopyTable(Kaneri_Tool_Settings.GlobalConfig) }
        end
        local y = -((i-1) * 35)
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(720, 32); row:SetPoint("TOPLEFT", 0, y)

        local cb = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("LEFT", 5, 0); cb:SetSize(24, 24)
        cb:SetChecked(Kaneri_Tool_Settings.Bars[data.id].enabled)
        cb:SetScript("OnClick", function(self) Kaneri_Tool_Settings.Bars[data.id].enabled = self:GetChecked() end)

        local mBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        mBtn:SetSize(80, 20); mBtn:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        
        local txt = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        txt:SetPoint("LEFT", mBtn, "RIGHT", 10, 0); txt:SetText(data.label); txt:SetWidth(120); txt:SetJustifyH("LEFT")

        local optFrame = CreateFrame("Frame", nil, row)
        optFrame:SetSize(480, 32); optFrame:SetPoint("LEFT", txt, "RIGHT", 0, 0)

        local function CreateQuickCB(key, label, x)
            local c = CreateFrame("CheckButton", nil, optFrame, "InterfaceOptionsCheckButtonTemplate")
            c:SetSize(20, 20); c:SetPoint("LEFT", x, 0)
            c.Text:SetFontObject("GameFontNormalSmall"); c.Text:SetText(label)
            c:SetScript("OnClick", function(self) Kaneri_Tool_Settings.Bars[data.id].customConfig[key] = self:GetChecked() end)
            return c
        end

        local qComb = CreateQuickCB("combat", "C", 0)
        local qTarg = CreateQuickCB("exists", "O", 35)
        local qHarm = CreateQuickCB("harm", "H", 70)
        local qStea = CreateQuickCB("stealth", "S", 105)
        local qFly  = CreateQuickCB("flying", "V", 140)

        local indAlpha = CreateFrame("Slider", "KT_IndAlpha_"..data.id, optFrame, "OptionsSliderTemplate")
        indAlpha:SetPoint("LEFT", 185, 0); indAlpha:SetWidth(150); indAlpha:SetHeight(14)
        indAlpha:SetMinMaxValues(0.1, 1); indAlpha:SetValueStep(0.1); indAlpha:SetObeyStepOnDrag(true)
        local iTxt = _G[indAlpha:GetName()..'Text']
        indAlpha:SetScript("OnValueChanged", function(self, v)
            Kaneri_Tool_Settings.Bars[data.id].customConfig.alpha = v
            iTxt:SetText("Alpha: "..math.floor(v*100).."%")
        end)
        _G[indAlpha:GetName()..'Low']:SetText(""); _G[indAlpha:GetName()..'High']:SetText("")

        local function Refresh()
            local isC = Kaneri_Tool_Settings.Bars[data.id].isCustom
            mBtn:SetText(isC and "CUSTOM" or "GLOBAL")
            local r, g, b = isC and 1 or 0.2, isC and 0.6 or 0.6, isC and 0.2 or 1
            local fs = mBtn:GetFontString()
            if fs then fs:SetTextColor(r, g, b) end
            if isC then 
                optFrame:Show()
                local cfg = Kaneri_Tool_Settings.Bars[data.id].customConfig
                qComb:SetChecked(cfg.combat); qTarg:SetChecked(cfg.exists)
                qHarm:SetChecked(cfg.harm); qStea:SetChecked(cfg.stealth); qFly:SetChecked(cfg.flying)
                indAlpha:SetValue(cfg.alpha or 1)
                iTxt:SetText("Alpha: "..math.floor((cfg.alpha or 1)*100).."%")
            else optFrame:Hide() end
        end

        mBtn:SetScript("OnClick", function() 
            Kaneri_Tool_Settings.Bars[data.id].isCustom = not Kaneri_Tool_Settings.Bars[data.id].isCustom
            Refresh()
        end)
        Refresh()
    end
    CreateFrame("Button", nil, configPanel, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -5, -5)
end

-- 7. Carga Segura
local ldr = CreateFrame("Frame")
ldr:RegisterEvent("PLAYER_LOGIN")
ldr:SetScript("OnEvent", function(self)
    local d = { visibilidadActiva=true, autoRepair=true, autoSell=true, combat=true, harm=true, exists=true, stealth=false, flying=true, z_party=0, z_raid=0, z_city=0, z_delve=0, z_world=0, delay=2, alpha=1 }
    if not Kaneri_Tool_Settings then Kaneri_Tool_Settings = { GlobalConfig = d, Bars = {} } end
    for _, data in ipairs(barList) do
        if not Kaneri_Tool_Settings.Bars[data.id] then
            Kaneri_Tool_Settings.Bars[data.id] = { enabled = false, isCustom = false, customConfig = CopyTable(d) }
        end
    end
    SetupUI()
    self:UnregisterAllEvents()
end)