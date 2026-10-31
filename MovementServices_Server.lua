--[[
    ServerScriptService -> Movement Services (Script)
    Jujutsu Shenanigans (JJS) Server Validation, I-Frames, Dash Strike Hitbox, and M1 Damage
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local movementFolder = ReplicatedStorage:WaitForChild("Movement")
local remotesFolder = movementFolder:WaitForChild("Remotes")
local dashRemote = remotesFolder:WaitForChild("DashRemote") :: RemoteEvent
local sprintRemote = remotesFolder:WaitForChild("SprintRemote") :: RemoteEvent
local dashStrikeRemote = remotesFolder:WaitForChild("DashStrikeRemote") :: RemoteEvent
local m1Remote = remotesFolder:WaitForChild("M1Remote") :: RemoteEvent

local VFX = require(movementFolder.Modules:WaitForChild("VFX"))

local lastDashTimes = {}
local lastM1Times = {}
local MIN_DASH_INTERVAL = 0.85
local MIN_M1_INTERVAL = 0.20

-- Handle Dash replication and I-Frames
dashRemote.OnServerEvent:Connect(function(player, dashDir: Vector3, isAir: boolean, dashType: string?)
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not rootPart then return end
    
    if char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") then
        return
    end
    
    local now = os.clock()
    local lastDash = lastDashTimes[player] or 0
    if now - lastDash < MIN_DASH_INTERVAL then
        return
    end
    lastDashTimes[player] = now
    
    -- Apply I-Frames (Invulnerability)
    char:SetAttribute("Invulnerable", true)
    char:SetAttribute("Dashing", true)
    task.delay(0.20, function()
        if char then
            char:SetAttribute("Invulnerable", false)
            char:SetAttribute("Dashing", false)
        end
    end)
    
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            dashRemote:FireClient(otherPlayer, player, dashDir, isAir, dashType)
        end
    end
end)

-- Handle Dash Strike (Dash + M1 attack)
dashStrikeRemote.OnServerEvent:Connect(function(player)
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not rootPart then return end
    
    if char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") then
        return
    end
    
    VFX.PlayDashSound(rootPart, 1.4)
    VFX.SpawnPunchSlash(rootPart, 4)
    
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            m1Remote:FireClient(otherPlayer, player, 4)
        end
    end
    
    local hitOrigin = rootPart.Position + (rootPart.CFrame.LookVector * 4.5)
    local hitRadius = 6.0
    
    local function checkTarget(enemyChar: Model, enemyHumanoid: Humanoid, enemyRoot: BasePart)
        if enemyHumanoid and enemyHumanoid.Health > 0 and enemyRoot then
            local dist = (enemyRoot.Position - hitOrigin).Magnitude
            if dist <= hitRadius and not enemyChar:GetAttribute("Invulnerable") then
                enemyHumanoid:TakeDamage(15)
                
                local knockDir = (rootPart.CFrame.LookVector * 48) + Vector3.new(0, 16, 0)
                enemyRoot.AssemblyLinearVelocity = knockDir
                
                enemyChar:SetAttribute("Stunned", true)
                task.delay(0.5, function()
                    if enemyChar then enemyChar:SetAttribute("Stunned", false) end
                end)
                
                VFX.PlayHitSound(enemyRoot, true)
                VFX.SpawnHitEffect(enemyRoot, true)
            end
        end
    end
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            checkTarget(p.Character, p.Character:FindFirstChildOfClass("Humanoid"), p.Character:FindFirstChild("HumanoidRootPart"))
        end
    end
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model ~= char and not Players:GetPlayerFromCharacter(model) then
            checkTarget(model, model:FindFirstChildOfClass("Humanoid"), model:FindFirstChild("HumanoidRootPart"))
        end
    end
end)

-- Handle M1 Attacks (4-Hit Combo)
m1Remote.OnServerEvent:Connect(function(player, comboStep: number)
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not rootPart then return end
    
    if char:GetAttribute("Stunned") or char:GetAttribute("Ragdolled") then
        return
    end
    
    local now = os.clock()
    local lastM1 = lastM1Times[player] or 0
    if now - lastM1 < MIN_M1_INTERVAL then
        return
    end
    lastM1Times[player] = now
    
    local isFinisher = (comboStep == 4)
    VFX.PlaySwingSound(rootPart, isFinisher and 1.1 or 1.45)
    VFX.SpawnPunchSlash(rootPart, comboStep)
    
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            m1Remote:FireClient(otherPlayer, player, comboStep)
        end
    end
    
    local hitOrigin = rootPart.Position + (rootPart.CFrame.LookVector * (isFinisher and 4.8 or 4.0))
    local hitRadius = isFinisher and 6.0 or 5.2
    local damage = isFinisher and 14 or (comboStep == 3 and 9 or 8)
    
    local function checkHit(enemyChar: Model, enemyHum: Humanoid, enemyRoot: BasePart)
        if enemyHum and enemyHum.Health > 0 and enemyRoot then
            local dist = (enemyRoot.Position - hitOrigin).Magnitude
            if dist <= hitRadius and not enemyChar:GetAttribute("Invulnerable") then
                enemyHum:TakeDamage(damage)
                
                if isFinisher then
                    local knockDir = (rootPart.CFrame.LookVector * 52) + Vector3.new(0, 18, 0)
                    enemyRoot.AssemblyLinearVelocity = knockDir
                    enemyChar:SetAttribute("Stunned", true)
                    task.delay(0.75, function()
                        if enemyChar then enemyChar:SetAttribute("Stunned", false) end
                    end)
                else
                    local pushDir = (rootPart.CFrame.LookVector * 12)
                    enemyRoot.AssemblyLinearVelocity = Vector3.new(pushDir.X, enemyRoot.AssemblyLinearVelocity.Y, pushDir.Z)
                    enemyChar:SetAttribute("Stunned", true)
                    task.delay(0.35, function()
                        if enemyChar then enemyChar:SetAttribute("Stunned", false) end
                    end)
                end
                
                VFX.PlayHitSound(enemyRoot, isFinisher)
                VFX.SpawnHitEffect(enemyRoot, isFinisher)
            end
        end
    end
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            checkHit(p.Character, p.Character:FindFirstChildOfClass("Humanoid"), p.Character:FindFirstChild("HumanoidRootPart"))
        end
    end
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model ~= char and not Players:GetPlayerFromCharacter(model) then
            checkHit(model, model:FindFirstChildOfClass("Humanoid"), model:FindFirstChild("HumanoidRootPart"))
        end
    end
end)

-- Handle Sprint
sprintRemote.OnServerEvent:Connect(function(player, isSprinting: boolean)
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    
    if isSprinting then
        if not char:GetAttribute("Stunned") and not char:GetAttribute("Ragdolled") then
            humanoid.WalkSpeed = 26
        end
    else
        humanoid.WalkSpeed = 16
    end
end)

Players.PlayerRemoving:Connect(function(player)
    lastDashTimes[player] = nil
    lastM1Times[player] = nil
end)

print("[Movement Services] Server Initialized.")
