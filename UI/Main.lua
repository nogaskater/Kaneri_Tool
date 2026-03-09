function KaneriTool:SetupMainUI()
    if KaneriToolOptionsPanel then return end

    local p = CreateFrame("Frame", "KaneriToolOptionsPanel", UIParent, "BackdropTemplate")
    p:SetSize(240, 160)
    -- Posición: Entre el centro (0,0) y la esquina superior izquierda
    p:SetPoint("CENTER", UIParent, "CENTER", -350, 200) 
    p:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { 4, 4, 4, 4 }})
    p:SetBackdropColor(0, 0, 0, 0.9)
    p:SetMovable(true); p:EnableMouse(true); p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving); p:SetScript("OnDragStop", p.StopMovingOrSizing)
    p:Hide()

    local title = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", 0, -12); title:SetText("Kaneri Tool")

    -- Check Visibilidad
    local visCB = CreateFrame("CheckButton", "KaneriVisCB", p, "InterfaceOptionsCheckButtonTemplate")
    visCB:SetPoint("TOPLEFT", 15, -40)
    visCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.visibilidadActiva)
    visCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.visibilidadActiva = self:GetChecked() end)

    -- Botón Abrir Configuración Barras
    local visBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    visBtn:SetSize(160, 22); visBtn:SetPoint("LEFT", visCB, "RIGHT", 5, 0)
    visBtn:SetText("Configurar Barras")
    visBtn:SetScript("OnClick", function() KaneriTool:ToggleVisibilityConfig() end)

    -- Reparar
    local repCB = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
    repCB:SetPoint("TOPLEFT", 15, -75); repCB.Text:SetText("Reparar Auto.")
    repCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.autoRepair)
    repCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.autoRepair = self:GetChecked() end)

    -- Vender
    local sellCB = CreateFrame("CheckButton", nil, p, "InterfaceOptionsCheckButtonTemplate")
    sellCB:SetPoint("TOPLEFT", 15, -110); sellCB.Text:SetText("Vender Basura")
    sellCB:SetChecked(Kaneri_Tool_Settings.GlobalConfig.autoSell)
    sellCB:SetScript("OnClick", function(self) Kaneri_Tool_Settings.GlobalConfig.autoSell = self:GetChecked() end)

    CreateFrame("Button", nil, p, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -2, -2)
end

SLASH_KT1 = "/kt"
SlashCmdList["KT"] = function(msg)
    if not KaneriToolOptionsPanel then KaneriTool:SetupMainUI() end
    if msg == "reset" then
        Kaneri_Tool_Settings = nil
        ReloadUI()
    else
        if KaneriToolOptionsPanel:IsShown() then KaneriToolOptionsPanel:Hide() else KaneriToolOptionsPanel:Show() end
    end
end