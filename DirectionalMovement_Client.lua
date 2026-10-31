--[[
    StarterPlayer -> StarterCharacterScripts -> DirectionalMovement (LocalScript)
    Jujutsu Shenanigans (JJS) Client Movement, 4 Animated Dashes, M1 Combat, and Sprinting
--]]

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
