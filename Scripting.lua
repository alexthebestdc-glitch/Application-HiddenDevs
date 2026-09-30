-- Local Script used to turn a part Neon Green when the part is stepped on!

local part = script.Parent

local touchDebounce = false

local debounceTime = 0.5 



    part.Material = Enum.Material.Neon

    part.Color = Color3.fromRGB(0, 255, 0) -- Bright green

end

local function resetPart()

    part.Material = Enum.Material.Plastic

    part.Color = Color3.fromRGB(255, 255, 255) -- White

end

part.Touched:Connect(function(hit)

    local humanoid = hit.Parent:FindFirstChild("Humanoid")

    

    if humanoid and not touchDebounce then

        touchDebounce = true

        makeNeonGreen()

        

        wait(2)

        resetPart()

       

        wait(debounceTime)

        touchDebounce = false

    end

end)

print("Neon green part script loaded!")