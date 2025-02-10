-- BombPassDataLogger.server.lua
local DataStoreService = game:GetService("DataStoreService")
local BombPassStore = DataStoreService:GetDataStore("BombPassStore")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BombPassEvent = ReplicatedStorage:WaitForChild("BombPassDataEvent")

-- Function to log bomb pass data for a player
local function logBombPassData(player, bombPassData)
    print("[SERVER] Received bomb pass data from:", player.Name)
    print("[SERVER] Held Time:", bombPassData.heldTime, "Remaining Time:", bombPassData.remaining)
    
    local key = "Player_" .. player.UserId
    local success, err = pcall(function()
        BombPassStore:UpdateAsync(key, function(oldData)
            oldData = oldData or {}
            table.insert(oldData, bombPassData)
            return oldData
        end)
    end)
    
    if not success then
        warn("[SERVER] Failed to store bomb pass data for", player.Name, ":", err)
    end
end

-- Listen for RemoteEvent from clients
BombPassEvent.OnServerEvent:Connect(function(player, bombPassData)
    if type(bombPassData) == "table" and bombPassData.heldTime and bombPassData.remaining then
        logBombPassData(player, bombPassData)
    else
        warn("[SERVER] Invalid bomb pass data received from", player.Name)
    end
end)
