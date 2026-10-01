local part = script.Parent
local sound = part.Sound
local canTouch = true

part.Touched:Connect(function(hit)
local character = hit.Parent
local humanoid = character:FindFirstChild("Humanoid")

if humanoid and canTouch then
canTouch = false

part.Color = Color3.fromRGB(0, 255, 0) -- Changes to Green
sound:Play()

task.wait(2)

part.Color = Color3.fromRGB(255, 255, 255) -- Resets to White
canTouch = true
end
