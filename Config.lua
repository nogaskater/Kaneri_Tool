KaneriTool = {} -- Tabla global para compartir funciones entre archivos

KaneriTool.BarList = {
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

local ldr = CreateFrame("Frame")
ldr:RegisterEvent("ADDON_LOADED")
ldr:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Kaneri_Tool" then
        local defaults = { 
            GlobalConfig = {
                visibilidadActiva=true, autoRepair=true, autoSell=true, 
                combat=true, exists=true, harm=true, stealth=false, 
                flying=true, z_party=0, z_raid=0, z_city=0, z_delve=0, 
                z_world=0, delay=2, alpha=1 
            },
            Bars = {}
        }

        if not Kaneri_Tool_Settings then 
            Kaneri_Tool_Settings = defaults 
        end

        for _, data in ipairs(KaneriTool.BarList) do
            if not Kaneri_Tool_Settings.Bars[data.id] then
                Kaneri_Tool_Settings.Bars[data.id] = { 
                    enabled = false, isCustom = false, 
                    customConfig = CopyTable(Kaneri_Tool_Settings.GlobalConfig) 
                }
            end
        end
        print("|cffffcc00Kaneri Tool|r cargado. Usa /kt")
    end
end)