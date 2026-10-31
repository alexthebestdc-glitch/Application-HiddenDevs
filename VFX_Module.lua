--[[
    ReplicatedStorage -> Movement -> Modules -> VFX (ModuleScript)
    Jujutsu Shenanigans (JJS) Visual & Audio Effects Engine
--]]

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
