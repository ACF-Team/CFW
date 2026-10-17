-- totalMass on contraptions and families, which ACF-3 reads directly (engines, baseplates, contraption mass checks)
-- Whatever CFW does internally, totalMass has to keep matching the sum of its members' physics masses

local Tolerance = 0.01

return {
    groupName = "CFW: Mass tracking",

    afterEach = CFWTest.Cleanup,

    cases = {
        {
            name = "A new contraption's totalMass is the sum of its members' masses",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                A:GetPhysicsObject():SetMass(100)
                B:GetPhysicsObject():SetMass(250)

                local Con = CFWTest.WeldChain(A, B)

                expect(Con and Con.totalMass).to.aboutEqual(350, Tolerance)

                done()
            end
        },

        {
            name = "Changing a member's mass updates totalMass",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Con  = CFWTest.WeldChain(A, B)

                A:GetPhysicsObject():SetMass(500)
                CFWTest.WaitUntil(function() return math.abs(Con.totalMass - CFWTest.SumMass(Con.ents)) < Tolerance end)

                expect(Con.totalMass).to.aboutEqual(CFWTest.SumMass(Con.ents), Tolerance)
                expect(Con.totalMass).to.aboutEqual(500 + B:GetPhysicsObject():GetMass(), Tolerance)

                done()
            end
        },

        {
            name = "Adding an entity to a contraption adds its mass",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B, C = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Con     = CFWTest.WeldChain(A, B)

                C:GetPhysicsObject():SetMass(321)
                CFWTest.Weld(B, C)
                CFWTest.WaitUntil(function() return C:CFW_GetContraption() == Con end)

                expect(Con.totalMass).to.aboutEqual(CFWTest.SumMass(Con.ents), Tolerance)

                done()
            end
        },

        {
            name = "Removing an entity subtracts its mass",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B, C = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Con     = CFWTest.WeldChain(A, B, C)

                C:Remove()
                CFWTest.WaitUntil(function() return not IsValid(C) end)

                expect(Con.totalMass).to.aboutEqual(CFWTest.SumMass(Con.ents), Tolerance)

                done()
            end
        },

        {
            name = "Merging contraptions combines their mass",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B, C, D = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                A:GetPhysicsObject():SetMass(10)
                C:GetPhysicsObject():SetMass(1000)

                CFWTest.WeldChain(A, B)
                CFWTest.WeldChain(C, D)
                CFWTest.Weld(B, C)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B, C, D) end)

                local Con = A:CFW_GetContraption()

                expect(Con.totalMass).to.aboutEqual(CFWTest.SumMass(Con.ents), Tolerance)

                done()
            end
        },

        {
            name = "Splitting a contraption divides its mass between the pieces",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B, C, D = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Cut        = CFWTest.Weld(B, C)

                A:GetPhysicsObject():SetMass(10)
                D:GetPhysicsObject():SetMass(1000)

                CFWTest.Weld(A, B)
                CFWTest.Weld(C, D)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B, C, D) end)

                Cut:Remove()
                CFWTest.WaitUntil(function() return A:CFW_GetContraption() ~= D:CFW_GetContraption() end)

                local Left, Right = A:CFW_GetContraption(), D:CFW_GetContraption()

                expect(Left and Left.totalMass).to.aboutEqual(CFWTest.SumMass(Left and Left.ents or {}), Tolerance)
                expect(Right and Right.totalMass).to.aboutEqual(CFWTest.SumMass(Right and Right.ents or {}), Tolerance)

                done()
            end
        },

        {
            name = "A family's totalMass is the sum of its members' masses and follows mass changes",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                B:SetParent(A)
                CFWTest.WaitUntil(function() return A:GetFamily() ~= nil and B:GetFamily() == A:GetFamily() end)

                local Family = A:GetFamily()

                expect(Family.totalMass).to.aboutEqual(CFWTest.SumMass(Family.ents), Tolerance)

                B:GetPhysicsObject():SetMass(777)
                CFWTest.WaitUntil(function() return math.abs(Family.totalMass - CFWTest.SumMass(Family.ents)) < Tolerance end)

                expect(Family.totalMass).to.aboutEqual(CFWTest.SumMass(Family.ents), Tolerance)

                done()
            end
        },
    }
}
