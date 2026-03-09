local barStates = {} 
local engine = CreateFrame("Frame")

engine:SetScript("OnUpdate", function(self, elapsed)
    if not Kaneri_Tool_Settings or not Kaneri_Tool_Settings.Bars then return end
    local isEditing = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    
    for _, data in ipairs(KaneriTool.BarList) do
        local frame = _G[data.id]
        if frame then
            local b = Kaneri_Tool_Settings.Bars[data.id]
            if b and b.enabled then
                -- Seleccionar configuración: Custom o Global
                local cfg = b.isCustom and b.customConfig or Kaneri_Tool_Settings.GlobalConfig
                local target = KaneriTool:GetTargetState(cfg)
                
                if not barStates[data.id] then barStates[data.id] = { last = "hide", timer = 0 } end
                local s = barStates[data.id]
                
                if target == "show" then 
                    s.timer = 0; s.last = "show"
                elseif s.last == "show" then
                    if s.timer == 0 then s.timer = GetTime() + (cfg.delay or 0) end
                    if GetTime() >= s.timer then s.last = "hide" end
                end
                
                -- Obtener opacidad máxima (del slider correspondiente)
                local maxAlpha = cfg.alpha or 1
                local tAlpha = (s.last == "show" or isEditing) and maxAlpha or 0
                local cAlpha = frame:GetAlpha()
                
                -- Suavizado de transición
                if math.abs(cAlpha - tAlpha) > 0.01 then
                    local step = elapsed * 3
                    frame:SetAlpha(cAlpha < tAlpha and math.min(tAlpha, cAlpha + step) or math.max(tAlpha, cAlpha - step))
                end
            else 
                -- Si la barra no está gestionada por el addon, volver a opacidad 1
                if frame:GetAlpha() ~= 1 then frame:SetAlpha(1) end 
            end
        end
    end
end)