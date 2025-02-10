--[[
    Combined Script with:
      • Bomb Passing (with distance check)
      • Anti-Slippery & Remove Hitbox features
      • A simple Key System (demo keys, runtime variables, killswitch check)
      • OrionLib UI with toggles, sliders, and dropdowns
      • If key redemption is successful, the bomb script is loaded via loadstring

    Adjust demo keys, URLs, and other parameters as needed.
]]--
--========================--
--  KEY SYSTEM MODULE      --
--========================--
local KeySystem = {}

local validKeys = {
    ["ABC123"] = {
        type = "lifetime",
        discordId = "123456789",
        note = "Test lifetime key",
        expiry = nil,
    },
    ["DAY456"] = {
        type = "day",
        discordId = "987654321",
        note = "Demo day key",
        expiry = os.time() + 86400,  -- expires in 1 day
    },
}

local function checkKillswitch()
    -- For demonstration, always return false (no kill switch active)
    return false
end

function KeySystem:RedeemKey(key)
    if checkKillswitch() then
        return false, "Script disabled by developer."
    end
    local keyData = validKeys[key]
    if keyData then
        if keyData.type == "day" and keyData.expiry and os.time() > keyData.expiry then
            return false, "Key has expired."
        end
        return true, keyData
    else
        return false, "Invalid key."
    end
end

function KeySystem:ResetHWID()
    print("HWID has been reset (placeholder).")
    return true
end

--========================--
--  KEY SYSTEM INTEGRATION
--========================--
-- Example integration: in a real setup, get this from a UI TextBox.
local userKey = "ABC123"
local keySuccess, keyDataOrError = KeySystem:RedeemKey(userKey)
if keySuccess then
    print("Key redeemed successfully!")
    print("Key Data:", keyDataOrError)
    -- If the key is valid, load the bomb script
    loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Passthebomb/refs/heads/main/pass%20the%20bom%20.lua"))()
else
    warn("Key redemption failed: " .. keyDataOrError)
    -- Optionally, show an error message in your UI
end
