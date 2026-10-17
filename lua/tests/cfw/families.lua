-- Families: the parenting hierarchy CFW tracks within a contraption
-- Covers the accessors consumers use, the cfw.family.* hooks, and how family and contraption hooks are ordered against each other

local Hooks = {
    "cfw.family.created",
    "cfw.family.added",
    "cfw.family.subbed",
    "cfw.family.deleted",
    "cfw.contraption.entityAdded",
    "cfw.contraption.entityRemoved",
}

local function Snapshot(_, _, Ent)
    if not isentity(Ent) or not IsValid(Ent) then return {} end

    return {
        family      = Ent:GetFamily(),
        contraption = Ent:CFW_GetContraption(),
    }
end

local function Record()
    return CFWTest.RecordHooks(Hooks, Snapshot)
end

local function Parent(Child, Target)
    Child:SetParent(Target)

    CFWTest.WaitUntil(function() return Child:GetFamily() ~= nil and Child:GetFamily() == Target:GetFamily() end)
end

return {
    groupName = "CFW: Families",

    afterEach = CFWTest.Cleanup,

    cases = {
        {
            name = "Parenting connects the child and parent into one contraption",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                B:SetParent(A)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B) end)

                expect(CFWTest.SameContraption(A, B)).to.beTrue()

                done()
            end
        },

        {
            name = "Parenting creates a family rooted at the parent",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                Parent(B, A)

                local Family = A:GetFamily()

                expect(Family).to.exist()
                expect(B:GetFamily()).to.equal(Family)
                expect(Family and Family:GetRoot()).to.equal(A)
                expect(Family and Family.ancestor).to.equal(A)
                expect(A:GetAncestor()).to.equal(A)
                expect(B:GetAncestor()).to.equal(A)
                expect(Family and Family.ents[A]).to.beTrue()
                expect(Family and Family.ents[B]).to.beTrue()
                expect(Family and Family.children[B]).to.beTrue()
                expect(Family and Family.children[A]).to.beNil()

                done()
            end
        },

        {
            name = "Grandchildren join the same family and share its root",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B, C = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                Parent(B, A)
                Parent(C, B)

                expect(C:GetFamily()).to.equal(A:GetFamily())
                expect(C:GetAncestor()).to.equal(A)
                expect(A:GetFamily().children[C]).to.beTrue()

                done()
            end
        },

        {
            name = "The root's GetFamilyChildren holds every descendant as keys",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B, C = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                Parent(B, A)
                Parent(C, B)

                local Children = A:GetFamilyChildren()

                expect(Children[B]).to.beTrue()
                expect(Children[C]).to.beTrue()
                expect(Children[A]).to.beNil()

                done()
            end
        },

        {
            name = "The contraption lists the family in its families",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                Parent(B, A)

                local Con    = A:CFW_GetContraption()
                local Family = A:GetFamily()

                expect(Con).to.exist()
                expect(Con and Con.families[Family]).to.beTrue()

                done()
            end
        },

        {
            name = "family.created fires before family.added for the root, which fires before family.added for the child",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Log  = Record()

                Parent(B, A)

                local Family   = A:GetFamily()
                local Created  = CFWTest.Filter(Log, "cfw.family.created")
                local CreatedI = CFWTest.IndexOf(Log, "cfw.family.created")
                local AddedA   = CFWTest.IndexOf(Log, "cfw.family.added", A)
                local AddedB   = CFWTest.IndexOf(Log, "cfw.family.added", B)

                expect(#Created).to.equal(1)
                expect(Created[1] and Created[1].args[1]).to.equal(Family)
                expect(CreatedI or math.huge).to.beLessThan(AddedA or 0)
                expect(AddedA or math.huge).to.beLessThan(AddedB or 0)

                done()
            end
        },

        {
            name = "During family.added the entity already reports its family and its contraption",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Log  = Record()

                Parent(B, A)

                local Family = A:GetFamily()
                local Con    = A:CFW_GetContraption()
                local AddedA = CFWTest.Filter(Log, "cfw.family.added", A)
                local AddedB = CFWTest.Filter(Log, "cfw.family.added", B)

                expect(#AddedA).to.equal(1)
                expect(#AddedB).to.equal(1)
                expect(AddedA[1] and AddedA[1].state.family).to.equal(Family)
                expect(AddedA[1] and AddedA[1].state.contraption).to.equal(Con)
                expect(AddedB[1] and AddedB[1].state.family).to.equal(Family)
                expect(AddedB[1] and AddedB[1].state.contraption).to.equal(Con)

                done()
            end
        },

        {
            name = "Unparenting the only child dissolves the family",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                Parent(B, A)

                local Family = A:GetFamily()
                local Log    = Record()

                B:SetParent(nil)
                CFWTest.WaitUntil(function() return A:GetFamily() == nil and B:GetFamily() == nil end)

                local Deleted = CFWTest.Filter(Log, "cfw.family.deleted")

                expect(A:GetFamily()).to.beNil()
                expect(B:GetFamily()).to.beNil()
                expect(B:GetAncestor()).to.equal(B)
                expect(#Deleted).to.equal(1)
                expect(Deleted[1] and Deleted[1].args[1]).to.equal(Family)

                done()
            end
        },

        {
            name = "On unparent, family.subbed fires before contraption.entityRemoved, while the entity is still in its contraption",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                Parent(B, A)

                local Con = B:CFW_GetContraption()
                local Log = Record()

                B:SetParent(nil)
                CFWTest.WaitUntil(function() return B:CFW_GetContraption() == nil end)

                local Subbed   = CFWTest.Filter(Log, "cfw.family.subbed", B)
                local SubbedI  = CFWTest.IndexOf(Log, "cfw.family.subbed", B)
                local RemovedI = CFWTest.IndexOf(Log, "cfw.contraption.entityRemoved", B)

                expect(#Subbed).to.equal(1)
                expect(Subbed[1] and Subbed[1].state.family).to.beNil()
                expect(Subbed[1] and Subbed[1].state.contraption).to.equal(Con)
                expect(RemovedI).to.exist()
                expect(SubbedI or math.huge).to.beLessThan(RemovedI or 0)

                done()
            end
        },

        {
            name = "Unparenting one of several children leaves the rest of the family intact",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B, C = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                Parent(B, A)
                Parent(C, A)

                local Family = A:GetFamily()
                local Log    = Record()

                C:SetParent(nil)
                CFWTest.WaitUntil(function() return C:GetFamily() == nil end)

                expect(C:GetFamily()).to.beNil()
                expect(A:GetFamily()).to.equal(Family)
                expect(B:GetFamily()).to.equal(Family)
                expect(Family.children[C]).to.beNil()
                expect(#CFWTest.Filter(Log, "cfw.family.subbed", C)).to.equal(1)
                expect(#CFWTest.Filter(Log, "cfw.family.deleted")).to.equal(0)

                done()
            end
        },

        {
            name = "Unparenting an entity that has children makes it the root of its own family",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B, C = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                Parent(B, A)
                Parent(C, B)

                B:SetParent(nil)
                CFWTest.WaitUntil(function() return B:GetAncestor() == B and B:GetFamily() ~= nil end)

                local Family = B:GetFamily()

                expect(Family).to.exist()
                expect(Family and Family:GetRoot()).to.equal(B)
                expect(C:GetFamily()).to.equal(Family)
                expect(C:GetAncestor()).to.equal(B)
                expect(A:GetFamily()).to.beNil()

                done()
            end
        },

        {
            name = "Families track their members by class",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A = CFWTest.SpawnProp(State)
                local B = CFWTest.SpawnProp(State, "prop_dynamic")

                Parent(B, A)

                local Family  = A:GetFamily()
                local Dynamic = Family:EntitiesByClass("prop_dynamic")
                local Missing = Family:EntitiesByClass("cfw_test_no_such_class")

                expect(Dynamic[B]).to.beTrue()
                expect(Dynamic[A]).to.beNil()
                expect(Missing).to.beA("table")
                expect(next(Missing)).to.beNil()
                expect(Family:ContainsClass("prop_dynamic")).to.beTrue()
                expect(Family:ContainsClass("cfw_test_no_such_class")).to.beFalse()

                done()
            end
        },
    }
}
