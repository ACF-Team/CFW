-- The globals, classes and methods consumers (ACF-3, Wiremod, DetectionPP, E2) reach for directly
-- If one of these disappears or changes shape, something downstream breaks

local ENT = FindMetaTable("Entity")

return {
    groupName = "CFW: Public API surface",

    afterEach = CFWTest.Cleanup,

    cases = {
        {
            name = "Exposes the CFW global and its registries",
            func = function()
                expect(CFW).to.beA("table")
                expect(CFW.Contraptions).to.beA("table")
                expect(CFW.Classes).to.beA("table")
                expect(CFW.Classes.Contraption).to.beA("table")
                expect(CFW.Classes.Family).to.beA("table")
            end
        },

        {
            name = "Exposes CFW.addParentDetour",
            func = function()
                expect(CFW.addParentDetour).to.beA("function")
            end
        },

        {
            name = "Adds the contraption and family accessors to the Entity metatable",
            func = function()
                expect(ENT.CFW_GetContraption).to.beA("function")
                expect(ENT.GetFamily).to.beA("function")
                expect(ENT.GetAncestor).to.beA("function")
                expect(ENT.GetFamilyChildren).to.beA("function")
            end
        },

        {
            name = "Contraptions expose their query methods",
            func = function()
                local Contraption = CFW.Classes.Contraption

                expect(Contraption.EntitiesByClass).to.beA("function")
                expect(Contraption.ContainsClass).to.beA("function")
                expect(Contraption.GetPos).to.beA("function")
                expect(Contraption.GetAABB).to.beA("function")
            end
        },

        {
            name = "Families expose their query methods",
            func = function()
                local Family = CFW.Classes.Family

                expect(Family.GetRoot).to.beA("function")
                expect(Family.EntitiesByClass).to.beA("function")
                expect(Family.ContainsClass).to.beA("function")
            end
        },

        {
            name = "Methods added to CFW.Classes.Contraption are available on contraptions",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                -- ACF-3 extends contraptions this way (lua/cfw/extensions/acf_extensions_sv.lua)
                CFW.Classes.Contraption.CFWTest_Extension = function(self) return self end
                State.Extended = true

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Con  = CFWTest.WeldChain(A, B)

                expect(Con).to.exist()
                expect(Con and Con:CFWTest_Extension()).to.equal(Con)

                done()
            end,

            cleanup = function(State)
                if State.Extended then CFW.Classes.Contraption.CFWTest_Extension = nil end
            end
        },

        {
            name = "A lone entity has no contraption",
            func = function(State)
                local Ent = CFWTest.SpawnProp(State)

                local Con = Ent:CFW_GetContraption()

                expect(Con).to.beNil()
            end
        },

        {
            name = "A lone entity has no family",
            func = function(State)
                local Ent = CFWTest.SpawnProp(State)

                local Family = Ent:GetFamily()

                expect(Family).to.beNil()
            end
        },

        {
            name = "A lone entity is its own ancestor",
            func = function(State)
                local Ent = CFWTest.SpawnProp(State)

                local Ancestor = Ent:GetAncestor()

                expect(Ancestor).to.equal(Ent)
            end
        },

        {
            name = "A lone entity's family children is an empty table",
            func = function(State)
                local Ent = CFWTest.SpawnProp(State)

                local Children = Ent:GetFamilyChildren()

                expect(Children).to.beA("table")
                expect(next(Children)).to.beNil()
            end
        },
    }
}
