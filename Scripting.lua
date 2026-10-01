local part = script.Parent
local sound = part.Sound

part.Touched:Connect(function(hit)
	local character = hit.Parent
	local humanoid = character:FindFirstChild("Humanoid")
	
	if humanoid then
		part.CanTouch = false
		part.Color = Color3.fromRGB(0, 255, 0)
		sound:Play()
		
		task.wait(2.5)
		
		part.Color = Color3.fromRGB(163,162,165)
		part.CanTouch = true
		
	end
end)
