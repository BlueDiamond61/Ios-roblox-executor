local appName = "MobileBlox Studio"
local appVersion = "1.0.0"

local function addNumbers(a, b)
    return a + b
end

local function describeEnvironment()
    print("Running local Lua example")
    print("App: " .. appName)
    print("Version: " .. appVersion)
end

describeEnvironment()

local result = addNumbers(12, 30)
print("12 + 30 = " .. tostring(result))

local tasks = {
    "Edit a script",
    "Save it locally",
    "Run it in the app's local Lua sandbox"
}

for index, task in ipairs(tasks) do
    print(tostring(index) .. ". " .. task)
end

print("Example completed successfully")
