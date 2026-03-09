local function UpdateZoneBtn(btn, val)
    if not btn or not btn.Text then return end
    if val == 1 then btn.Text:SetText("VISIBLE"); btn.Text:SetTextColor(0, 1, 0)
    elseif val == -1 then btn.Text:SetText("OCULTO"); btn.Text:SetTextColor(1, 0, 0)
    else btn.Text:SetText("AUTO"); btn.Text:SetTextColor(0.6, 0.6, 1) end
end

function KaneriTool:ToggleVisibilityConfig()
    if KaneriToolConfigPanel and KaneriToolConfigPanel:IsShown() then
        KaneriToolConfigPanel:Hide()
        return
    end
    self:SetupVisibilityUI()
    KaneriToolConfigPanel:Show()
end

function KaneriTool:SetupVisibilityUI()
    if KaneriToolConfigPanel then return end

    local f = CreateFrame("Frame", "KaneriToolConfigPanel", UIParent, "BackdropTemplate")
    f:SetSize(900, 720); f:SetPoint("CENTER")
    f:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { 8, 8, 8, 8 }})
    f:SetBackdropColor(0, 0, 0, 0.95); f:EnableMouse(true); f:SetMovable(true)
    f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20); title:SetText("Configuración de Visibilidad")

    -- --- SECCIÓN GLOBAL (Zonas y Condiciones) ---
    local zDefs = {{l="Exteriores", c="z_world"}, {l="Ciudades/Tabernas", c="z_city"}, {l="Profundidades", c="z_delve"}, {l="Mazmorras", c="z_party"}, {l="Bandas", c="z_raid"}}
    for i, z in ipairs(zDefs) do
        local l = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", 50, -65 - (i * 26)); l:SetText(z.l)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(120, 18); b:SetPoint("LEFT", l, "RIGHT", 60, 0)
        b.Text = b:GetFontString()
        UpdateZoneBtn(b, Kaneri_Tool_Settings.GlobalConfig[z.c])
        b:SetScript("OnClick", function(self)
            local cur = Kaneri_Tool_Settings.GlobalConfig[z.c]
            Kaneri_Tool_Settings.GlobalConfig[z.c] = (cur == 0) and 1 or (cur == 1 and -1 or 0)
            UpdateZoneBtn(self, Kaneri_Tool_Settings.GlobalConfig[z.c])
        end)
    end

    local cDefs = {{l="En Combate", c="combat"}, {l="Tener Objetivo", c="exists"}, {l="Objetivo Hostil", c="harm"}, {l="En Sigilo", c="stealth"}, {l="|cff00ccffVolando|r", c="flying"}}
    for i, cond in ipairs(cDefs) do
        local cb = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 430, -65 - (i * 26))
        cb.Text:SetText(cond.l); cb:SetChecked(Kaneri_Tool_Settings.GlobalConfig[cond.c])
        cb:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig[cond.c] = self:GetChecked() end)
    end

    -- --- SLIDERS GLOBALES ---
    local sliderBox = CreateFrame("Frame", nil, f)
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

    -- --- LISTA DE BARRAS (SCROLL) ---
    local scrollFrame = CreateFrame("ScrollFrame", "KTScroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 25, -305); scrollFrame:SetPoint("BOTTOMRIGHT", -35, 35)
    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(820, #KaneriTool.BarList * 35)
    scrollFrame:SetScrollChild(scrollChild)

    for i, data in ipairs(KaneriTool.BarList) do
        local y = -((i-1) * 35)
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(820, 32); row:SetPoint("TOPLEFT", 0, y)

        local cb = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("LEFT", 5, 0); cb:SetSize(24, 24)
        cb:SetChecked(Kaneri_Tool_Settings.Bars[data.id].enabled)
        cb:SetScript("OnClick", function(self) Kaneri_Tool_Settings.Bars[data.id].enabled = self:GetChecked() end)

        local mBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        mBtn:SetSize(80, 20); mBtn:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        
        local txt = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        txt:SetPoint("LEFT", mBtn, "RIGHT", 10, 0); txt:SetText(data.label); txt:SetWidth(120); txt:SetJustifyH("LEFT")

        local optFrame = CreateFrame("Frame", nil, row)
        optFrame:SetSize(600, 32); optFrame:SetPoint("LEFT", txt, "RIGHT", 5, 0)

        local function CreateQuickCB(key, label, x)
            local c = CreateFrame("CheckButton", nil, optFrame, "InterfaceOptionsCheckButtonTemplate")
            c:SetSize(20, 20); c:SetPoint("LEFT", x, 0)
            c.Text:SetFontObject("GameFontNormalSmall"); c.Text:SetText(label)
            c:SetScript("OnClick", function(self) Kaneri_Tool_Settings.Bars[data.id].customConfig[key] = self:GetChecked() end)
            return c
        end

        local qComb = CreateQuickCB("combat", "Combate", 0)
        local qTarg = CreateQuickCB("exists", "Objetivo", 80)
        local qHarm = CreateQuickCB("harm", "Hostil", 160)
        local qStea = CreateQuickCB("stealth", "Sigilo", 230)
        local qFly  = CreateQuickCB("flying", "Vuelo", 300)

        -- Slider de Opacidad Individual
        local indAlpha = CreateFrame("Slider", "KT_IndAlpha_"..data.id, optFrame, "OptionsSliderTemplate")
        indAlpha:SetPoint("LEFT", 380, 0); indAlpha:SetWidth(120); indAlpha:SetHeight(14)
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
            
            -- Aplicar Colores al Botón
            local fontStr = mBtn:GetFontString()
            if isC then
                fontStr:SetTextColor(0, 1, 0) -- Verde para Custom
                optFrame:Show()
                local cfg = Kaneri_Tool_Settings.Bars[data.id].customConfig
                qComb:SetChecked(cfg.combat); qTarg:SetChecked(cfg.exists)
                qHarm:SetChecked(cfg.harm); qStea:SetChecked(cfg.stealth); qFly:SetChecked(cfg.flying)
                indAlpha:SetValue(cfg.alpha or 1)
            else
                fontStr:SetTextColor(0.2, 0.6, 1) -- Azul para Global
                optFrame:Hide()
            end
        end

        mBtn:SetScript("OnClick", function() 
            Kaneri_Tool_Settings.Bars[data.id].isCustom = not Kaneri_Tool_Settings.Bars[data.id].isCustom
            Refresh()
        end)
        Refresh()
    end

    CreateFrame("Button", nil, f, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -5, -5)
end