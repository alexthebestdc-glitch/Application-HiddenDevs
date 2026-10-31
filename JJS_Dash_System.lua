--[[
========================================================================================
            JUJUTSU SHENANIGANS (JJS) DIRECTIONAL DASH & COMBAT SYSTEM
========================================================================================
This file contains the complete Jujutsu Shenanigans movement, dash, and M1 combat system.
Follow the setup guide below to install it into any Roblox Studio place.

----------------------------------------------------------------------------------------
                                   SETUP INSTRUCTIONS
----------------------------------------------------------------------------------------
1. REPLICATEDSTORAGE:
   Create a Folder named: Movement
   Inside "Movement", create:
     - Folder named: Remotes
         Inside "Remotes", create 4 RemoteEvents:
           * DashRemote
           * SprintRemote
           * DashStrikeRemote
           * M1Remote
     - Folder named: Modules
         Inside "Modules", create a ModuleScript named: VFX
         (Paste the code from SECTION 1: VFX MODULE below into it)

2. SERVERSCRIPTSERVICE:
   Create a Script named: Movement Services
   (Paste the code from SECTION 2: SERVER SCRIPT below into it)

3. STARTERPLAYER -> STARTERCHARACTERSCRIPTS:
   Create a LocalScript named: DirectionalMovement
   (Paste the code from SECTION 3: CLIENT SCRIPT below into it)

4. STARTERGUI (Optional HUD):
   Create a ScreenGui named: HUD
   Inside "HUD", create a Frame named: DashIndicator (Size: 70x70, Anchor: 1, 1, Pos: {1, -25}, {1, -25})
   Inside "DashIndicator", create:
     - TextLabel named "KeyLabel" (Text: "Q")
     - TextLabel named "ActionLabel" (Text: "DASH")
     - TextLabel named "CooldownText" (Text: "")
     - Frame named "CooldownOverlay" (Size: {1, 0}, {0, 0}, Anchor: 0, 1, Pos: {0, 0}, {1, 0})
     - UIStroke named "Stroke"

----------------------------------------------------------------------------------------
KEYBINDS & CONTROLS:
  * Q (Neutral or W + Q) : Front Dash (Anime forward dive lunge, rocks fly, speed lines)
  * S + Q                 : Back Dash (360° Acrobatic Backflip through the air)
  * A + Q                 : Left Dash (360° Evasive Corkscrew Spin Roll)
  * D + Q                 : Right Dash (360° Evasive Corkscrew Spin Roll)
  * Mid-air + Q           : Air Dash (Horizontal burst with sonic shockwave ring)
  * Left Mouse Button (M1): 4-Hit Combat Combo (Jab -> Cross -> Body Hook -> Heavy Knockback Finisher)
  * Front Dash + M1       : Dash Strike (Cancels dash into lunging heavy punch that stuns)
  * LeftShift             : Sprint Toggle (Increases speed to 26 studs/s, widens FOV)
  * Double-Tap W          : Sprint
========================================================================================
--]]


-- ====================================================================================
-- SECTION 1: VFX MODULE (ReplicatedStorage.Movement.Modules.VFX)
-- ClassName: ModuleScript
-- ====================================================================================
local VFX_CODE = [=[
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VFX = {}

-- Audio
function VFX.PlayDashSound(rootPart: BasePart, pitch: number?)
    if not rootPart then return end
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://12222216"
    sound.Volume = 0.95
    sound.PlaybackSpeed = pitch or (math.random(118, 128) / 100)
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = 6
    sound.RollOffMaxDistance = 90
    sound.Parent = rootPart
    sound:Play()
    sound.Ended:Connect(function() sound:Destroy() end)
    Debris:AddItem(sound, 1.5)
end

function VFX.PlaySwingSound(rootPart: BasePart, pitch: number?)
    if not rootPart then return end
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://12222216"
    sound.Volume = 0.7
    sound.PlaybackSpeed = pitch or (math.random(145, 160) / 100)
    sound.Parent = rootPart
    sound:Play()
    sound.Ended:Connect(function() sound:Destroy() end)
    Debris:AddItem(sound, 1)
end

function VFX.PlayHitSound(rootPart: BasePart, isFinisher: boolean)
    if not rootPart then return end
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://12222225"
    sound.Volume = isFinisher and 1.2 or 0.85
    sound.PlaybackSpeed = isFinisher and 0.95 or (math.random(110, 125) / 100)
    sound.Parent = rootPart
    sound:Play()
    sound.Ended:Connect(function() sound:Destroy() end)
    Debris:AddItem(sound, 1.5)
end

-- SPRINT EFFECT: Subtle footstep dirt under shoes only
function VFX.SpawnFootstepDust(rootPart: BasePart, moveDir: Vector3)
    if not rootPart then return end
    local attach = Instance.new("Attachment")
    attach.Position = Vector3.new(math.random(-5, 5)/10, -2.8, math.random(-5, 5)/10)
    attach.Parent = rootPart
    
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
    emitter.Color = ColorSequence.new(Color3.fromRGB(160, 150, 140))
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 0.8),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Lifetime = NumberRange.new(0.2, 0.3)
    emitter.Rate = 0
    emitter.Speed = NumberRange.new(2, 5)
    emitter.EmissionDirection = Enum.NormalId.Back
    attach.CFrame = CFrame.lookAt(Vector3.zero, -moveDir)
    emitter.Parent = attach
    
    emitter:Emit(4)
    task.delay(0.35, function() attach:Destroy() end)
end

-- DASH EFFECT: High-Speed Anime Wind Lines & Speed Streaks
function VFX.SpawnDashSpeedLines(rootPart: BasePart, dashDir: Vector3)
    if not rootPart then return end
    local attach = Instance.new("Attachment")
    attach.Position = Vector3.new(0, -0.5, 0)
    attach.Parent = rootPart
    
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255), Color3.fromRGB(150, 200, 255))
    emitter.LightEmission = 0.9
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(0.3, 1.2),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.7, 0.4),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Lifetime = NumberRange.new(0.18, 0.28)
    emitter.Rate = 0
    emitter.Speed = NumberRange.new(18, 30)
    emitter.SpreadAngle = Vector2.new(15, 15)
    emitter.Drag = 3
    
    local oppDir = -dashDir
    emitter.EmissionDirection = Enum.NormalId.Back
    attach.CFrame = CFrame.lookAt(Vector3.zero, oppDir)
    emitter.Parent = attach
    
    emitter:Emit(25)
    task.delay(0.4, function() attach:Destroy() end)
end

-- DASH EFFECT: Ground Shockwave Ripple
function VFX.SpawnGroundShockwave(rootPart: BasePart, dashDir: Vector3)
    if not rootPart then return end
    local wave = Instance.new("Part")
    wave.Name = "DashShockwave"
    wave.Anchored = true
    wave.CanCollide = false
    wave.CanQuery = false
    wave.CanTouch = false
    wave.CastShadow = false
    wave.Material = Enum.Material.Neon
    wave.Color = Color3.fromRGB(210, 235, 255)
    wave.Transparency = 0.35
    wave.Size = Vector3.new(2, 0.05, 2)
    wave.CFrame = CFrame.new(rootPart.Position - Vector3.new(0, 2.7, 0))
    
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Cylinder
    mesh.Parent = wave
    wave.Parent = workspace
    
    local tween = TweenService:Create(wave, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(9, 0.02, 9),
        Transparency = 1,
    })
    tween:Play()
    tween.Completed:Connect(function() wave:Destroy() end)
    Debris:AddItem(wave, 0.3)
end

-- Flying Ground Debris / Rock Chunks
function VFX.SpawnGroundDebris(rootPart: BasePart, dashDir: Vector3)
    if not rootPart then return end
    local groundPos = rootPart.Position - Vector3.new(0, 2.3, 0)
    
    for i = 1, 4 do
        local rock = Instance.new("Part")
        rock.Name = "GroundDebris"
        rock.Size = Vector3.new(math.random(4, 7) / 10, math.random(4, 7) / 10, math.random(4, 7) / 10)
        rock.Position = groundPos + (dashDir * (i * 1.2)) + Vector3.new(math.random(-12, 12) / 10, 0.2, math.random(-12, 12) / 10)
        rock.Material = Enum.Material.Slate
        rock.Color = Color3.fromRGB(115, 115, 120)
        rock.CanCollide = false
        rock.CanQuery = false
        rock.CanTouch = false
        rock.CastShadow = false
        rock.AssemblyLinearVelocity = Vector3.new(math.random(-8, 8), math.random(14, 22), math.random(-8, 8)) - (dashDir * 4)
        rock.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
        rock.Parent = workspace
        
        task.delay(0.32, function()
            local tween = TweenService:Create(rock, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = Vector3.new(0.05, 0.05, 0.05),
                Transparency = 1
            })
            tween:Play()
            tween.Completed:Connect(function() rock:Destroy() end)
        end)
    end
end

-- Expanding Air Ring for Aerial Dash
function VFX.SpawnAirRing(rootPart: BasePart, dashDir: Vector3)
    if not rootPart then return end
    local ring = Instance.new("Part")
    ring.Name = "AirDashRing"
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanQuery = false
    ring.CanTouch = false
    ring.CastShadow = false
    ring.Material = Enum.Material.Neon
    ring.Color = Color3.fromRGB(240, 250, 255)
    ring.Transparency = 0.3
    ring.Size = Vector3.new(0.5, 0.5, 0.2)
    
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Cylinder
    mesh.Parent = ring
    
    local lookAtCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + dashDir)
    ring.CFrame = lookAtCFrame * CFrame.Angles(0, 0, math.rad(90))
    ring.Parent = workspace
    
    local tween = TweenService:Create(ring, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(12, 12, 0.1),
        Transparency = 1,
    })
    tween:Play()
    tween.Completed:Connect(function() ring:Destroy() end)
    Debris:AddItem(ring, 0.3)
end

-- Wind Trails
function VFX.AttachWindTrails(character: Model, duration: number)
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
    if not rootPart then return end
    
    local att0 = Instance.new("Attachment")
    att0.Position = Vector3.new(-1.2, 0, 0.5)
    att0.Parent = rootPart
    
    local att1 = Instance.new("Attachment")
    att1.Position = Vector3.new(1.2, 0, 0.5)
    att1.Parent = rootPart
    
    local trail = Instance.new("Trail")
    trail.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.5, 0.6),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Lifetime = 0.15
    trail.Attachment0 = att0
    trail.Attachment1 = att1
    trail.FaceCamera = true
    trail.Parent = rootPart
    
    task.delay(duration, function()
        trail.Enabled = false
        task.delay(0.2, function()
            trail:Destroy()
            att0:Destroy()
            att1:Destroy()
        end)
    end)
end

-- Afterimages
function VFX.SpawnAfterimage(character: Model)
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
    if not rootPart then return end
    
    local ghostModel = Instance.new("Model")
    ghostModel.Name = "DashAfterimage"
    
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
            local ghostPart = Instance.new("Part")
            ghostPart.Size = part.Size
            ghostPart.CFrame = part.CFrame
            ghostPart.Anchored = true
            ghostPart.CanCollide = false
            ghostPart.CanQuery = false
            ghostPart.CanTouch = false
            ghostPart.CastShadow = false
            ghostPart.Material = Enum.Material.Neon
            ghostPart.Color = Color3.fromRGB(180, 215, 255)
            ghostPart.Transparency = 0.45
            ghostPart.Parent = ghostModel
            
            local tween = TweenService:Create(ghostPart, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Transparency = 1,
                Size = part.Size * 1.05
            })
            tween:Play()
        end
    end
    
    ghostModel.Parent = workspace
    Debris:AddItem(ghostModel, 0.28)
end

-- M1 Punch Swing Streak
function VFX.SpawnPunchSlash(rootPart: BasePart, comboStep: number)
    if not rootPart then return end
    local swing = Instance.new("Part")
    swing.Name = "PunchSlash"
    swing.Anchored = true
    swing.CanCollide = false
    swing.CanQuery = false
    swing.CanTouch = false
    swing.CastShadow = false
    swing.Material = Enum.Material.Neon
    swing.Color = comboStep == 4 and Color3.fromRGB(255, 120, 60) or Color3.fromRGB(240, 245, 255)
    swing.Transparency = 0.3
    swing.Size = Vector3.new(2.5, 0.1, 1.8)
    
    local offset = comboStep % 2 == 1 and Vector3.new(0.6, 0.2, -1.8) or Vector3.new(-0.6, 0.2, -1.8)
    swing.CFrame = rootPart.CFrame * CFrame.new(offset) * CFrame.Angles(0, math.rad(comboStep % 2 == 1 and 25 or -25), 0)
    swing.Parent = workspace
    
    local tween = TweenService:Create(swing, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(4, 0.05, 3),
        Transparency = 1
    })
    tween:Play()
    tween.Completed:Connect(function() swing:Destroy() end)
    Debris:AddItem(swing, 0.15)
end

-- Hit effect on target
function VFX.SpawnHitEffect(targetRoot: BasePart, isFinisher: boolean)
    if not targetRoot then return end
    local attach = Instance.new("Attachment")
    attach.Parent = targetRoot
    
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color = isFinisher 
        and ColorSequence.new(Color3.fromRGB(255, 100, 40), Color3.fromRGB(255, 220, 100))
        or ColorSequence.new(Color3.fromRGB(255, 240, 200), Color3.fromRGB(255, 180, 80))
    emitter.LightEmission = 1
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, isFinisher and 1.2 or 0.6),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Lifetime = NumberRange.new(0.15, 0.25)
    emitter.Rate = 0
    emitter.Speed = NumberRange.new(isFinisher and 18 or 10, isFinisher and 32 or 20)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Parent = attach
    
    emitter:Emit(isFinisher and 28 or 14)
    task.delay(0.3, function() attach:Destroy() end)
end

-- Master function called when a player dashes
function VFX.PlayDashVFX(character: Model, dashDir: Vector3, isAir: boolean, duration: number, dashType: string?)
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
    if not rootPart then return end
    
    local pitch = 1.22
    if dashType == "Back" then
        pitch = 1.35
    elseif dashType == "Left" or dashType == "Right" then
        pitch = 1.28
    end
    
    VFX.PlayDashSound(rootPart, pitch)
    VFX.AttachWindTrails(character, duration or 0.22)
    
    if isAir then
        VFX.SpawnAirRing(rootPart, dashDir)
    else
        VFX.SpawnGroundShockwave(rootPart, dashDir)
        VFX.SpawnGroundDebris(rootPart, dashDir)
        VFX.SpawnDashSpeedLines(rootPart, dashDir)
    end
    
    VFX.SpawnAfterimage(character)
    task.delay(0.06, function() VFX.SpawnAfterimage(character) end)
    task.delay(0.12, function() VFX.SpawnAfterimage(character) end)
end

return VFX
]=]


-- ====================================================================================
-- SECTION 2: SERVER SCRIPT (ServerScriptService["Movement Services"])
-- ClassName: Script
-- ====================================================================================
local SERVER_CODE = [=[
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
]=]


-- ====================================================================================
-- SECTION 3: CLIENT SCRIPT (StarterPlayer.StarterCharacterScripts.DirectionalMovement)
-- ClassName: LocalScript
-- ====================================================================================
local CLIENT_CODE = [=[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
local torso = character:WaitForChild("Torso") :: BasePart

local movementFolder = ReplicatedStorage:WaitForChild("Movement", 5) or ReplicatedStorage:WaitForChild("JJS_Movement")
local remotesFolder = movementFolder:WaitForChild("Remotes")
local dashRemote = remotesFolder:WaitForChild("DashRemote") :: RemoteEvent
local sprintRemote = remotesFolder:WaitForChild("SprintRemote") :: RemoteEvent
local dashStrikeRemote = remotesFolder:WaitForChild("DashStrikeRemote") :: RemoteEvent
local m1Remote = remotesFolder:WaitForChild("M1Remote") :: RemoteEvent

local VFX = require(movementFolder.Modules:WaitForChild("VFX"))

-- UI Reference
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("HUD", 5) or playerGui:WaitForChild("JJS_HUD")
local dashIndicator = hud:WaitForChild("DashIndicator")
local cdOverlay = dashIndicator:WaitForChild("CooldownOverlay")
local cdText = dashIndicator:WaitForChild("CooldownText")
local stroke = dashIndicator:WaitForChild("Stroke")

-- Configuration
local FRONT_DASH_SPEED = 85
local FRONT_DASH_DURATION = 0.22

local BACK_DASH_SPEED = 72
local BACK_DASH_DURATION = 0.32
local BACK_DASH_UP = 18

local SIDE_DASH_SPEED = 78
local SIDE_DASH_DURATION = 0.25

local AIR_DASH_SPEED = 80
local AIR_DASH_DURATION = 0.22

local DASH_COOLDOWN = 1.2
local WALK_SPEED = 16
local SPRINT_SPEED = 26
local DEFAULT_FOV = 70
local SPRINT_FOV = 78
local DASH_FOV = 77

-- State
local canDash = true
local isDashing = false
local currentDashType = nil
local canAirDash = true
local isSprinting = false
local lastWTapTime = 0
local canDashStrike = false

local activeDashDuration = 0.22
local activeDashStartTime = 0

-- M1 Attack State
local comboStep = 0
local lastM1Time = 0
local isAttacking = false
local attackDuration = 0.22
local attackStartTime = 0
local activeM1Step = 0
local COMBO_RESET_DELAY = 1.1

-- Joint references (R6 Support)
local rootJoint = rootPart:WaitForChild("RootJoint") :: Motor6D
local neckJoint = torso:WaitForChild("Neck") :: Motor6D
local rShoulder = torso:WaitForChild("Right Shoulder") :: Motor6D
local lShoulder = torso:WaitForChild("Left Shoulder") :: Motor6D
local rHip = torso:WaitForChild("Right Hip") :: Motor6D
local lHip = torso:WaitForChild("Left Hip") :: Motor6D

local origRootC0 = rootJoint.C0
local origNeckC0 = neckJoint.C0
local origRShoulderC0 = rShoulder.C0
local origLShoulderC0 = lShoulder.C0
local origRHipC0 = rHip.C0
local origLHipC0 = lHip.C0

local currentFovTween = nil
local function setCameraFov(targetFov: number, duration: number, style: Enum.EasingStyle)
    if currentFovTween then
        currentFovTween:Cancel()
    end
    currentFovTween = TweenService:Create(camera, TweenInfo.new(duration or 0.25, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        FieldOfView = targetFov
    })
    currentFovTween:Play()
end

local function isGrounded(): boolean
    local floor = humanoid.FloorMaterial
    return floor ~= Enum.Material.Air and floor ~= nil
end

humanoid.StateChanged:Connect(function(oldState, newState)
    if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then
        canAirDash = true
    end
end)

humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
    if isGrounded() then
        canAirDash = true
    end
end)

local function setSprinting(state: boolean)
    if isSprinting == state then return end
    if isAttacking then return end
    isSprinting = state
    
    local targetSpeed = isSprinting and SPRINT_SPEED or WALK_SPEED
    humanoid.WalkSpeed = targetSpeed
    sprintRemote:FireServer(isSprinting)
    
    local targetFov = isSprinting and SPRINT_FOV or DEFAULT_FOV
    setCameraFov(targetFov, 0.3)
end

local function executeDash()
    if not canDash or isDashing then return end
    if humanoid.Health <= 0 then return end
    
    if character:GetAttribute("Stunned") or character:GetAttribute("Ragdolled") or isAttacking then
        return
    end
    
    local grounded = isGrounded()
    if not grounded and not canAirDash then
        return
    end
    
    local isAir = not grounded
    if isAir then
        canAirDash = false
    end
    
    canDash = false
    isDashing = true
    
    local moveDir = humanoid.MoveDirection
    local dashDir: Vector3
    local dashType: string
    
    if moveDir.Magnitude > 0.05 then
        dashDir = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
        local localMove = rootPart.CFrame:VectorToObjectSpace(dashDir)
        
        if isAir then
            dashType = "Air"
        elseif localMove.Z > 0.40 then
            dashType = "Back"
        elseif localMove.X < -0.40 then
            dashType = "Left"
        elseif localMove.X > 0.40 then
            dashType = "Right"
        else
            dashType = "Front"
        end
    else
        local look = rootPart.CFrame.LookVector
        dashDir = Vector3.new(look.X, 0, look.Z).Unit
        dashType = isAir and "Air" or "Front"
    end
    
    currentDashType = dashType
    canDashStrike = (dashType == "Front")
    
    local speed = FRONT_DASH_SPEED
    local duration = FRONT_DASH_DURATION
    local upwardBoost = 5
    
    if dashType == "Back" then
        speed = BACK_DASH_SPEED
        duration = BACK_DASH_DURATION
        upwardBoost = BACK_DASH_UP
    elseif dashType == "Left" or dashType == "Right" then
        speed = SIDE_DASH_SPEED
        duration = SIDE_DASH_DURATION
        upwardBoost = 6
    elseif dashType == "Air" then
        speed = AIR_DASH_SPEED
        duration = AIR_DASH_DURATION
        upwardBoost = 1
    end
    
    activeDashDuration = duration
    activeDashStartTime = os.clock()
    
    VFX.PlayDashVFX(character, dashDir, isAir, duration, dashType)
    dashRemote:FireServer(dashDir, isAir, dashType)
    
    setCameraFov(DASH_FOV, 0.08, Enum.EasingStyle.Sine)
    task.delay(0.12, function()
        local returnFov = isSprinting and SPRINT_FOV or DEFAULT_FOV
        setCameraFov(returnFov, 0.22)
    end)
    
    local attachment = Instance.new("Attachment")
    attachment.Name = "DashAttachment"
    attachment.Parent = rootPart
    
    local linearVelocity = Instance.new("LinearVelocity")
    linearVelocity.Name = "DashVelocity"
    linearVelocity.Attachment0 = attachment
    linearVelocity.MaxForce = 190000
    linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    linearVelocity.VectorVelocity = (dashDir * speed) + Vector3.new(0, upwardBoost, 0)
    linearVelocity.Parent = rootPart
    
    if isAir then
        rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, math.max(rootPart.AssemblyLinearVelocity.Y, 2), rootPart.AssemblyLinearVelocity.Z)
    end
    
    task.delay(duration, function()
        if linearVelocity and linearVelocity.Parent then linearVelocity:Destroy() end
        if attachment and attachment.Parent then attachment:Destroy() end
        isDashing = false
        currentDashType = nil
        canDashStrike = false
    end)
    
    task.spawn(function()
        cdOverlay.Size = UDim2.new(1, 0, 1, 0)
        cdText.Visible = true
        stroke.Color = Color3.fromRGB(40, 40, 50)
        
        local startTime = os.clock()
        while true do
            local elapsed = os.clock() - startTime
            local remaining = DASH_COOLDOWN - elapsed
            if remaining <= 0 then break end
            
            local progress = remaining / DASH_COOLDOWN
            cdOverlay.Size = UDim2.new(1, 0, progress, 0)
            cdText.Text = string.format("%.1f", remaining)
            RunService.RenderStepped:Wait()
        end
        
        cdOverlay.Size = UDim2.new(1, 0, 0, 0)
        cdText.Visible = false
        canDash = true
        
        stroke.Color = Color3.fromRGB(255, 255, 255)
        local pulseTween = TweenService:Create(stroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Color = Color3.fromRGB(80, 80, 95)
        })
        pulseTween:Play()
    end)
end

local function triggerDashStrike()
    if not canDashStrike or not isDashing then return end
    canDashStrike = false
    
    isAttacking = true
    activeM1Step = 4
    attackDuration = 0.28
    attackStartTime = os.clock()
    
    dashStrikeRemote:FireServer()
    VFX.PlaySwingSound(rootPart, 1.2)
    VFX.SpawnPunchSlash(rootPart, 4)
    
    local punchLook = rootPart.CFrame.LookVector
    rootPart.AssemblyLinearVelocity = (punchLook * 45) + Vector3.new(0, 5, 0)
    
    setCameraFov(75, 0.06, Enum.EasingStyle.Sine)
    task.delay(0.12, function()
        setCameraFov(isSprinting and SPRINT_FOV or DEFAULT_FOV, 0.2)
        isAttacking = false
        activeM1Step = 0
    end)
end

local function executeM1()
    if isDashing then
        if canDashStrike then
            triggerDashStrike()
        end
        return
    end
    
    if isAttacking then return end
    if humanoid.Health <= 0 then return end
    if character:GetAttribute("Stunned") or character:GetAttribute("Ragdolled") then return end
    
    local now = os.clock()
    if (now - lastM1Time) > COMBO_RESET_DELAY then
        comboStep = 1
    else
        comboStep = (comboStep % 4) + 1
    end
    lastM1Time = now
    
    isAttacking = true
    activeM1Step = comboStep
    attackDuration = (comboStep == 4) and 0.35 or 0.22
    attackStartTime = now
    
    local isFinisher = (comboStep == 4)
    VFX.PlaySwingSound(rootPart, isFinisher and 1.1 or 1.45)
    VFX.SpawnPunchSlash(rootPart, comboStep)
    m1Remote:FireServer(comboStep)
    
    local look = rootPart.CFrame.LookVector
    local lungeSpeed = isFinisher and 22 or 12
    rootPart.AssemblyLinearVelocity = (look * lungeSpeed) + Vector3.new(0, 3, 0)
    
    setCameraFov(DEFAULT_FOV + (isFinisher and 3 or 1.5), 0.05, Enum.EasingStyle.Sine)
    task.delay(0.08, function()
        setCameraFov(isSprinting and SPRINT_FOV or DEFAULT_FOV, 0.15)
    end)
    
    task.delay(attackDuration, function()
        isAttacking = false
        activeM1Step = 0
    end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Q then
        executeDash()
    end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        executeM1()
    end
    
    if input.KeyCode == Enum.KeyCode.LeftShift then
        setSprinting(not isSprinting)
    end
    
    if input.KeyCode == Enum.KeyCode.W then
        local now = os.clock()
        if (now - lastWTapTime) <= 0.28 then
            setSprinting(true)
        end
        lastWTapTime = now
    end
end)

humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
    if humanoid.MoveDirection.Magnitude < 0.05 and isSprinting then
        setSprinting(false)
    end
end)

dashRemote.OnClientEvent:Connect(function(otherPlayer: Player, dashDir: Vector3, isAir: boolean, otherDashType: string?)
    if otherPlayer and otherPlayer.Character and otherPlayer ~= player then
        VFX.PlayDashVFX(otherPlayer.Character, dashDir, isAir, 0.24, otherDashType)
    end
end)

m1Remote.OnClientEvent:Connect(function(otherPlayer: Player, otherStep: number)
    if otherPlayer and otherPlayer.Character and otherPlayer ~= player then
        local otherRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
        if otherRoot then
            VFX.PlaySwingSound(otherRoot, otherStep == 4 and 1.1 or 1.45)
            VFX.SpawnPunchSlash(otherRoot, otherStep)
        end
    end
end)

local sprintDustTimer = 0
RunService.Heartbeat:Connect(function(dt)
    if isSprinting and isGrounded() and humanoid.MoveDirection.Magnitude > 0.1 then
        sprintDustTimer += dt
        if sprintDustTimer >= 0.20 then
            sprintDustTimer = 0
            VFX.SpawnFootstepDust(rootPart, humanoid.MoveDirection)
        end
    else
        sprintDustTimer = 0
    end
end)

local curRootRot = Vector3.zero
local curNeckRot = Vector3.zero
local curRSRot = Vector3.zero
local curLSRot = Vector3.zero
local curRHRot = Vector3.zero
local curLHRot = Vector3.zero

RunService.RenderStepped:Connect(function(dt)
    if humanoid.Health <= 0 then return end
    
    local tgtRoot = Vector3.zero
    local tgtNeck = Vector3.zero
    local tgtRS = Vector3.zero
    local tgtLS = Vector3.zero
    local tgtRH = Vector3.zero
    local tgtLH = Vector3.zero
    local lerpSpeed = 16
    
    if isDashing and currentDashType then
        local elapsed = os.clock() - activeDashStartTime
        local progress = math.clamp(elapsed / activeDashDuration, 0, 1)
        lerpSpeed = 24
        
        if currentDashType == "Front" then
            tgtRoot = Vector3.new(-math.rad(34), 0, 0)
            tgtNeck = Vector3.new(math.rad(24), 0, 0)
            tgtRS = Vector3.new(math.rad(80), -math.rad(15), math.rad(15))
            tgtLS = Vector3.new(math.rad(80), math.rad(15), -math.rad(15))
            tgtRH = Vector3.new(-math.rad(28), 0, 0)
            tgtLH = Vector3.new(math.rad(32), 0, 0)
            
        elseif currentDashType == "Back" then
            local flipProgress = progress * math.pi * 2
            local tuck = math.sin(progress * math.pi)
            tgtRoot = Vector3.new(flipProgress, 0, 0)
            tgtNeck = Vector3.new(-math.rad(15), 0, 0)
            tgtRS = Vector3.new(math.rad(120) * tuck, 0, math.rad(35) * tuck)
            tgtLS = Vector3.new(math.rad(120) * tuck, 0, -math.rad(35) * tuck)
            tgtRH = Vector3.new(math.rad(75) * tuck, 0, 0)
            tgtLH = Vector3.new(math.rad(75) * tuck, 0, 0)
            lerpSpeed = 30
            
        elseif currentDashType == "Left" then
            local spinProgress = progress * math.pi * 2
            local bank = math.sin(progress * math.pi)
            tgtRoot = Vector3.new(0, spinProgress, -math.rad(26) * bank)
            tgtRS = Vector3.new(math.rad(45), -math.rad(30), math.rad(30))
            tgtLS = Vector3.new(-math.rad(30), math.rad(60), 0)
            tgtLH = Vector3.new(math.rad(25) * bank, 0, -math.rad(20) * bank)
            tgtRH = Vector3.new(-math.rad(25) * bank, 0, -math.rad(10) * bank)
            lerpSpeed = 28
            
        elseif currentDashType == "Right" then
            local spinProgress = -progress * math.pi * 2
            local bank = math.sin(progress * math.pi)
            tgtRoot = Vector3.new(0, spinProgress, math.rad(26) * bank)
            tgtLS = Vector3.new(math.rad(45), math.rad(30), -math.rad(30))
            tgtRS = Vector3.new(-math.rad(30), -math.rad(60), 0)
            tgtRH = Vector3.new(math.rad(25) * bank, 0, math.rad(20) * bank)
            tgtLH = Vector3.new(-math.rad(25) * bank, 0, math.rad(10) * bank)
            lerpSpeed = 28
            
        elseif currentDashType == "Air" then
            tgtRoot = Vector3.new(-math.rad(24), 0, 0)
            tgtNeck = Vector3.new(math.rad(18), 0, 0)
            tgtRS = Vector3.new(math.rad(20), 0, math.rad(65))
            tgtLS = Vector3.new(math.rad(20), 0, -math.rad(65))
            tgtRH = Vector3.new(-math.rad(15), 0, 0)
            tgtLH = Vector3.new(-math.rad(15), 0, 0)
        end
        
    elseif isAttacking and activeM1Step > 0 then
        local elapsed = os.clock() - attackStartTime
        local progress = math.clamp(elapsed / attackDuration, 0, 1)
        local snap = math.sin(progress * math.pi)
        lerpSpeed = 32
        
        if activeM1Step == 1 then
            tgtRoot = Vector3.new(0, -math.rad(18) * snap, 0)
            tgtRS = Vector3.new(math.rad(95) * snap, 0, -math.rad(12) * snap)
            tgtLS = Vector3.new(math.rad(30), math.rad(35), 0)
            
        elseif activeM1Step == 2 then
            tgtRoot = Vector3.new(0, math.rad(20) * snap, 0)
            tgtLS = Vector3.new(math.rad(95) * snap, 0, math.rad(12) * snap)
            tgtRS = Vector3.new(math.rad(30), -math.rad(35), 0)
            
        elseif activeM1Step == 3 then
            tgtRoot = Vector3.new(-math.rad(10) * snap, -math.rad(28) * snap, 0)
            tgtRS = Vector3.new(math.rad(75) * snap, -math.rad(45) * snap, -math.rad(35) * snap)
            tgtLS = Vector3.new(math.rad(40), math.rad(20), 0)
            
        elseif activeM1Step == 4 then
            tgtRoot = Vector3.new(-math.rad(16) * snap, -math.rad(38) * snap, 0)
            tgtRS = Vector3.new(math.rad(115) * snap, -math.rad(25) * snap, -math.rad(48) * snap)
            tgtLS = Vector3.new(-math.rad(20) * snap, math.rad(35), -math.rad(20))
            tgtRH = Vector3.new(-math.rad(18) * snap, 0, 0)
            tgtLH = Vector3.new(math.rad(22) * snap, 0, 0)
        end
        
    else
        local moveDir = humanoid.MoveDirection
        local localMove = rootPart.CFrame:VectorToObjectSpace(moveDir)
        if localMove.Magnitude > 0.05 then
            tgtRoot = Vector3.new(
                -localMove.Z * math.rad(isSprinting and 9 or 5),
                0,
                -localMove.X * math.rad(isSprinting and 11 or 7)
            )
        end
    end
    
    local alpha = math.clamp(dt * lerpSpeed, 0, 1)
    curRootRot = curRootRot:Lerp(tgtRoot, alpha)
    curNeckRot = curNeckRot:Lerp(tgtNeck, alpha)
    curRSRot = curRSRot:Lerp(tgtRS, alpha)
    curLSRot = curLSRot:Lerp(tgtLS, alpha)
    curRHRot = curRHRot:Lerp(tgtRH, alpha)
    curLHRot = curLHRot:Lerp(tgtLH, alpha)
    
    rootJoint.C0 = origRootC0 * CFrame.Angles(curRootRot.X, curRootRot.Y, curRootRot.Z)
    neckJoint.C0 = origNeckC0 * CFrame.Angles(curNeckRot.X, curNeckRot.Y, curNeckRot.Z)
    rShoulder.C0 = origRShoulderC0 * CFrame.Angles(curRSRot.X, curRSRot.Y, curRSRot.Z)
    lShoulder.C0 = origLShoulderC0 * CFrame.Angles(curLSRot.X, curLSRot.Y, curLSRot.Z)
    rHip.C0 = origRHipC0 * CFrame.Angles(curRHRot.X, curRHRot.Y, curRHRot.Z)
    lHip.C0 = origLHipC0 * CFrame.Angles(curLHRot.X, curLHRot.Y, curLHRot.Z)
end)

print("[DirectionalMovement] Initialized.")
]=]
