-- Contraption query methods consumers call: EntitiesByClass, ContainsClass, GetAABB, GetPos

local OtherClass = "prop_physics_multiplayer"

local function Inside(Pos, Mins, Maxs)
    return Pos.x >= Mins.x and Pos.y >= Mins.y and Pos.z >= Mins.z
        and Pos.x <= Maxs.x and Pos.y <= Maxs.y and Pos.z <= Maxs.z
end

return {
    groupName = "CFW: Contraption queries",

    afterEach = CFWTest.Cleanup,

    cases = {
        {
            name = "EntitiesByClass returns the members of that class as keys",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State, OtherClass)
                local Con  = CFWTest.WeldChain(A, B)

                local Props = Con:EntitiesByClass("prop_physics")
                local Other = Con:EntitiesByClass(OtherClass)

                expect(Props[A]).to.beTrue()
                expect(Props[B]).to.beNil()
                expect(Other[B]).to.beTrue()
                expect(Other[A]).to.beNil()

                done()
            end
        },

        {
            name = "EntitiesByClass returns an empty table for a class the contraption doesn't have",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Con  = CFWTest.WeldChain(A, B)

                local Missing = Con:EntitiesByClass("cfw_test_no_such_class")

                expect(Missing).to.beA("table")
                expect(next(Missing)).to.beNil()

                done()
            end
        },

        {
            name = "ContainsClass reports whether any member has that class",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State, OtherClass)
                local Con  = CFWTest.WeldChain(A, B)

                expect(Con:ContainsClass("prop_physics")).to.beTrue()
                expect(Con:ContainsClass(OtherClass)).to.beTrue()
                expect(Con:ContainsClass("cfw_test_no_such_class")).to.beFalse()

                done()
            end
        },

        {
            name = "A class stops being reported once its last member leaves",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local C    = CFWTest.SpawnProp(State, OtherClass)
                local Con  = CFWTest.WeldChain(A, B, C)

                C:Remove()
                CFWTest.WaitUntil(function() return not IsValid(C) end)

                expect(Con:ContainsClass(OtherClass)).to.beFalse()
                expect(next(Con:EntitiesByClass(OtherClass))).to.beNil()

                done()
            end
        },

        {
            name = "GetAABB returns world bounds enclosing every member, and their center",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Con  = CFWTest.WeldChain(A, B)

                local Mins, Maxs, Center = Con:GetAABB()

                expect(Mins).to.beA("Vector")
                expect(Maxs).to.beA("Vector")
                expect(Center).to.beA("Vector")
                expect(Inside(A:GetPos(), Mins, Maxs)).to.beTrue()
                expect(Inside(B:GetPos(), Mins, Maxs)).to.beTrue()
                expect(Inside(A:LocalToWorld(A:OBBMaxs()), Mins, Maxs)).to.beTrue()
                expect(Inside(B:LocalToWorld(B:OBBMins()), Mins, Maxs)).to.beTrue()
                expect(Center:Distance((Mins + Maxs) * 0.5)).to.beLessThan(0.01)

                done()
            end
        },

        {
            name = "GetAABB only includes members the filter accepts",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Con  = CFWTest.WeldChain(A, B)

                local Mins, Maxs = Con:GetAABB(function(Ent) return Ent == A end)

                expect(Inside(A:GetPos(), Mins, Maxs)).to.beTrue()
                expect(Inside(B:GetPos(), Mins, Maxs)).to.beFalse()

                done()
            end
        },

        {
            name = "GetPos returns the average position of the members",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Con  = CFWTest.WeldChain(A, B)

                local Pos = Con:GetPos()

                expect(Pos:Distance((A:GetPos() + B:GetPos()) * 0.5)).to.beLessThan(0.01)

                done()
            end
        },
    }
}
