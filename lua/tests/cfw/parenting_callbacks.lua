-- The per-entity parenting callbacks consumers define on their entities, and CFW.addParentDetour
-- Documented order for Child:SetParent(New) while parented to Old:
--     Child:CFW_PreParentedTo(Old, New, ...)  -- may block by returning false
--     New:CFW_PreParented(Child)              -- may block by returning false
--     Old:CFW_OnParented(Child, false)
--     (the parent actually changes)
--     New:CFW_OnParented(Child, true)
--     Child:CFW_OnParentedTo(Old, New)

local DetourClass = "cfw_test_detour"

scripted_ents.Register({ Type = "anim", Base = "base_anim" }, DetourClass)

-- Installs every callback on the given entities, each logging its name, arguments and what GetParent reports at that moment
local function Instrument(Log, Child, ...)
    local function Entry(Name, Ent, ...)
        Log[#Log + 1] = { name = Name, ent = Ent, args = { ... }, parent = Child:GetParent() }
    end

    Child.CFW_PreParentedTo = function(self, ...) Entry("PreParentedTo", self, ...) end
    Child.CFW_OnParentedTo  = function(self, ...) Entry("OnParentedTo", self, ...) end

    for _, Parent in ipairs({ ... }) do
        Parent.CFW_PreParented = function(self, ...) Entry("PreParented", self, ...) end
        Parent.CFW_OnParented  = function(self, ...) Entry("OnParented", self, ...) end
    end
end

local function Names(Log)
    local Out = {}

    for I, Entry in ipairs(Log) do
        Out[I] = Entry.name
    end

    return Out
end

return {
    groupName = "CFW: Parenting callbacks",

    afterEach = CFWTest.Cleanup,

    cases = {
        {
            name = "Parenting runs PreParentedTo, PreParented, OnParented and OnParentedTo in that order",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local Child, New = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Log        = {}

                Instrument(Log, Child, New)
                Child:SetParent(New)

                expect(Names(Log)).to.deepEqual({ "PreParentedTo", "PreParented", "OnParented", "OnParentedTo" })

                done()
            end
        },

        {
            name = "Reparenting tells the old parent before the parent changes and the new parent after",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local Child = CFWTest.SpawnProp(State)
                local Old   = CFWTest.SpawnProp(State)
                local New   = CFWTest.SpawnProp(State)
                local Log   = {}

                Child:SetParent(Old)
                Instrument(Log, Child, Old, New)
                Child:SetParent(New)

                expect(Names(Log)).to.deepEqual({ "PreParentedTo", "PreParented", "OnParented", "OnParented", "OnParentedTo" })

                local PreTo, Pre, OnOld, OnNew, OnTo = unpack(Log)

                expect(PreTo.ent).to.equal(Child)
                expect(PreTo.args[1]).to.equal(Old)
                expect(PreTo.args[2]).to.equal(New)
                expect(PreTo.parent).to.equal(Old)

                expect(Pre.ent).to.equal(New)
                expect(Pre.args[1]).to.equal(Child)
                expect(Pre.parent).to.equal(Old)

                expect(OnOld.ent).to.equal(Old)
                expect(OnOld.args[1]).to.equal(Child)
                expect(OnOld.args[2]).to.beFalse()
                expect(OnOld.parent).to.equal(Old)

                expect(OnNew.ent).to.equal(New)
                expect(OnNew.args[1]).to.equal(Child)
                expect(OnNew.args[2]).to.beTrue()
                expect(OnNew.parent).to.equal(New)

                expect(OnTo.ent).to.equal(Child)
                expect(OnTo.args[1]).to.equal(Old)
                expect(OnTo.args[2]).to.equal(New)
                expect(OnTo.parent).to.equal(New)

                done()
            end
        },

        {
            name = "Unparenting tells the old parent and the child, with no new parent",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local Child, Old = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Log        = {}

                Child:SetParent(Old)
                Instrument(Log, Child, Old)
                Child:SetParent(nil)

                expect(Names(Log)).to.deepEqual({ "PreParentedTo", "OnParented", "OnParentedTo" })

                local _, OnOld, OnTo = unpack(Log)

                expect(OnOld.args[1]).to.equal(Child)
                expect(OnOld.args[2]).to.beFalse()
                expect(OnTo.args[1]).to.equal(Old)
                expect(IsValid(OnTo.args[2])).to.beFalse()
                expect(IsValid(Child:GetParent())).to.beFalse()

                done()
            end
        },

        {
            name = "Returning false from CFW_PreParentedTo blocks the parenting",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local Child, New = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local OnParented = stub()

                Child.CFW_PreParentedTo = function() return false end
                New.CFW_OnParented = OnParented

                Child:SetParent(New)
                CFWTest.WaitTicks(5)

                expect(IsValid(Child:GetParent())).to.beFalse()
                expect(Child:CFW_GetContraption()).to.beNil()
                expect(OnParented).wasNot.called()

                done()
            end
        },

        {
            name = "Returning false from CFW_PreParented blocks the parenting",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local Child, New = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local OnParentedTo = stub()

                New.CFW_PreParented = function() return false end
                Child.CFW_OnParentedTo = OnParentedTo

                Child:SetParent(New)
                CFWTest.WaitTicks(5)

                expect(IsValid(Child:GetParent())).to.beFalse()
                expect(Child:CFW_GetContraption()).to.beNil()
                expect(OnParentedTo).wasNot.called()

                done()
            end
        },

        {
            name = "Returning nothing from the Pre callbacks does not block the parenting",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local Child, New = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                Child.CFW_PreParentedTo = function() end
                New.CFW_PreParented = function() end

                Child:SetParent(New)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(Child, New) end)

                expect(Child:GetParent()).to.equal(New)
                expect(CFWTest.SameContraption(Child, New)).to.beTrue()

                done()
            end
        },

        {
            name = "Parenting to a detoured class parents to the detour target instead",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                CFW.addParentDetour(DetourClass, "CFWTest_DetourTarget")

                local Child   = CFWTest.SpawnProp(State)
                local Detour  = CFWTest.SpawnProp(State, DetourClass)
                local Target  = CFWTest.SpawnProp(State)

                Detour.CFWTest_DetourTarget = Target

                Child:SetParent(Detour)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(Child, Target) end)

                expect(Child:GetParent()).to.equal(Target)
                expect(CFWTest.SameContraption(Child, Target)).to.beTrue()

                done()
            end
        },

        {
            name = "Parenting to a detoured class still runs the callbacks of the entity it was parented to",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                CFW.addParentDetour(DetourClass, "CFWTest_DetourTarget")

                local Child  = CFWTest.SpawnProp(State)
                local Detour = CFWTest.SpawnProp(State, DetourClass)
                local Target = CFWTest.SpawnProp(State)
                local Pre, On = stub(), stub()

                Detour.CFWTest_DetourTarget = Target
                Detour.CFW_PreParented = Pre
                Detour.CFW_OnParented = On

                Child:SetParent(Detour)

                expect(Pre).was.called()
                expect(On).was.called()
                expect(On.callHistory[1] and On.callHistory[1][2]).to.equal(Child)
                expect(On.callHistory[1] and On.callHistory[1][3]).to.beTrue()

                done()
            end
        },

        {
            name = "A detoured class with no target set parents normally",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                CFW.addParentDetour(DetourClass, "CFWTest_DetourTarget")

                local Child  = CFWTest.SpawnProp(State)
                local Detour = CFWTest.SpawnProp(State, DetourClass)

                Child:SetParent(Detour)

                expect(Child:GetParent()).to.equal(Detour)

                done()
            end
        },
    }
}
