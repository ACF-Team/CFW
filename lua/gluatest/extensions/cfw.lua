-- Shared helpers for CFW's GLuaTest suite (lua/tests/cfw)
-- These only drive CFW the way a consumer would (spawning, welding, parenting, removing) and observe the result.
-- Never reach into CFW internals here: the point of the suite is to pin the public contract so the internals can be reworked freely.

CFWTest = CFWTest or {}

local TestModel = "models/hunter/blocks/cube05x05x05.mdl"
local Origin    = Vector(0, 0, 2000)
local ReadyTick = 10
local Spawned   = 0

-- Yields the current (test) coroutine until Condition returns true or Timeout seconds pass
-- Returns whether the condition was met, so tests don't depend on how many ticks CFW takes to react
function CFWTest.WaitUntil(Condition, Timeout)
    if Condition() then return true end

    local Co       = coroutine.running()
    local Deadline = CurTime() + (Timeout or 2)
    local Name     = "CFWTest_WaitUntil_" .. tostring(Co)

    timer.Create(Name, 0, 0, function()
        local Met = Condition() == true

        if not Met and CurTime() < Deadline then return end

        timer.Remove(Name)

        local Ok, Err = coroutine.resume(Co, Met)

        if not Ok then ErrorNoHaltWithStack(Err) end
    end)

    return coroutine.yield()
end

function CFWTest.WaitTicks(Count)
    local Target = engine.TickCount() + Count

    return CFWTest.WaitUntil(function() return engine.TickCount() >= Target end)
end

-- Consumers only ever interact with CFW once the server is up and running
-- Tests start on the very first tick, so give CFW the same courtesy before acting
-- Also waits out a tick so entities removed by the previous case are fully gone and can't fire hooks into this one
function CFWTest.WaitForReady()
    CFWTest.WaitUntil(function() return engine.TickCount() >= ReadyTick end, 5)

    return CFWTest.WaitTicks(2)
end

-- Spawns a frozen prop that is tracked on State for cleanup
function CFWTest.SpawnProp(State, Class)
    Spawned = Spawned + 1

    local Ent = ents.Create(Class or "prop_physics")

    Ent:SetModel(TestModel)
    Ent:SetPos(Origin + Vector((Spawned % 20) * 60, math.floor(Spawned / 20) % 20 * 60, 0))
    Ent:Spawn()

    local PhysObj = Ent:GetPhysicsObject()

    if IsValid(PhysObj) then PhysObj:EnableMotion(false) end

    State.Ents = State.Ents or {}
    State.Ents[#State.Ents + 1] = Ent

    return Ent
end

function CFWTest.Weld(A, B)
    return constraint.Weld(A, B, 0, 0, 0, true, false)
end

function CFWTest.SameContraption(...)
    local Ents = { ... }
    local Con  = Ents[1]:CFW_GetContraption()

    if not Con then return false end

    for I = 2, #Ents do
        if Ents[I]:CFW_GetContraption() ~= Con then return false end
    end

    return true
end

-- Welds every entity to the next and waits until they're all one contraption
function CFWTest.WeldChain(...)
    local Ents = { ... }

    for I = 1, #Ents - 1 do
        CFWTest.Weld(Ents[I], Ents[I + 1])
    end

    CFWTest.WaitUntil(function() return CFWTest.SameContraption(unpack(Ents)) end)

    return Ents[1]:CFW_GetContraption()
end

-- Records every listed hook in the order it fires, along with whatever Snapshot captures at that moment
-- Snapshot(HookName, ...) runs inside the hook, so it sees the state consumers see
function CFWTest.RecordHooks(HookNames, Snapshot)
    local Log = {}

    for _, HookName in ipairs(HookNames) do
        hook.Add(HookName, "CFWTest_Recorder", function(...)
            Log[#Log + 1] = {
                name  = HookName,
                args  = { ... },
                state = Snapshot and Snapshot(HookName, ...),
            }
        end)
    end

    return Log
end

-- Returns the entries in Log whose name matches and whose arguments include Subject
function CFWTest.Filter(Log, HookName, Subject)
    local Out = {}

    for _, Entry in ipairs(Log) do
        if Entry.name ~= HookName then continue end

        if Subject ~= nil then
            local Found = false

            for _, Arg in pairs(Entry.args) do
                if Arg == Subject then Found = true break end
            end

            if not Found then continue end
        end

        Out[#Out + 1] = Entry
    end

    return Out
end

-- Index of the first entry matching HookName (and Subject, if given), or nil
function CFWTest.IndexOf(Log, HookName, Subject)
    for I, Entry in ipairs(Log) do
        if Entry.name == HookName then
            if Subject == nil then return I end

            for _, Arg in pairs(Entry.args) do
                if Arg == Subject then return I end
            end
        end
    end
end

function CFWTest.Cleanup(State)
    if not State.Ents then return end

    for _, Ent in ipairs(State.Ents) do
        if IsValid(Ent) then Ent:Remove() end
    end
end

function CFWTest.SumMass(Set)
    local Total = 0

    for Ent in pairs(Set) do
        local PhysObj = Ent:GetPhysicsObject()

        if IsValid(PhysObj) then Total = Total + PhysObj:GetMass() end
    end

    return Total
end
