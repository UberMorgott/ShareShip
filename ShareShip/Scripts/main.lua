-- ShareShip: scaffold. Real logic added after SDK dump identifies the owner-check UFunction.
-- See docs/08-sdk-dump-workflow.md for the discovery procedure.

local MOD_NAME = "ShareShip"

print(string.format("[%s] scaffold loaded\n", MOD_NAME))

-- Sanity hook borrowed from WindrosePlus main.lua: confirms UE4SS is attached to Windrose's R5 module.
-- Registers only when a hold-open UFunction is identified; placeholder below.
-- Example (do NOT uncomment until UFunction name is verified via CXXHeaderDump):
--
-- RegisterHook("/Script/R5.R5MovementComponent:ServerSaveMoveInput", function(Context)
--     local pc = Context:get()
--     if pc and pc:IsValid() then
--         print(string.format("[%s] move-input tick from %s\n", MOD_NAME, pc:GetFullName()))
--     end
-- end)
