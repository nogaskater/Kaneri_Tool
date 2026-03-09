local f = CreateFrame("Frame")
f:RegisterEvent("MERCHANT_SHOW")
f:SetScript("OnEvent", function()
    if not Kaneri_Tool_Settings then return end
    local cfg = Kaneri_Tool_Settings.GlobalConfig
    
    if cfg.autoSell and C_MerchantFrame.GetNumJunkItems() > 0 then 
        C_MerchantFrame.SellAllJunkItems() 
    end
    
    if cfg.autoRepair and CanMerchantRepair() then
        local cost = GetRepairAllCost()
        if cost > 0 and GetMoney() >= cost then 
            RepairAllItems()
            print("|cffffcc00Kaneri Tool:|r Reparado.") 
        end
    end
end)