-- Función para obtener el estado deseado de una barra según zona y condiciones
function KaneriTool:GetTargetState(cfg)
    if not Kaneri_Tool_Settings.GlobalConfig.visibilidadActiva then return "show" end
    
    local g = Kaneri_Tool_Settings.GlobalConfig
    local z = 0
    local _, instanceType = GetInstanceInfo()
    
    -- Prioridad de Zonas
    if instanceType == "raid" then z = g.z_raid
    elseif instanceType == "party" then z = g.z_party
    elseif instanceType == "scenario" then z = g.z_delve
    elseif IsResting() then z = g.z_city
    else z = g.z_world end
    
    if z == 1 then return "show" end
    if z == -1 then return "hide" end
    
    -- Condiciones automáticas
    local any = (cfg.combat and InCombatLockdown()) or 
                (cfg.exists and UnitExists("target")) or 
                (cfg.stealth and IsStealthed()) or 
                (cfg.harm and UnitCanAttack("player", "target")) or 
                (cfg.flying and IsFlying())
                
    return any and "show" or "hide"
end