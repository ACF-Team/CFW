-- Contraption lifecycle: what consumers see when entities get connected, merged, split and disconnected
-- Covers which cfw.contraption.* hooks fire, in what order, and what is already true while each one runs

local Hooks = {
    "cfw.contraption.created",
    "cfw.contraption.entityAdded",
    "cfw.contraption.entityRemoved",
    "cfw.contraption.merged",
    "cfw.contraption.split",
    "cfw.contraption.removed",
}

-- Captured inside each hook, so assertions describe what a listener would have seen at that moment
local function Snapshot(_, Con, Other)
    local Snap = {
        count      = Con.count,
        registered = CFW.Contraptions[Con] == true,
    }

    if isentity(Other) and IsValid(Other) then
        Snap.owner  = Other:CFW_GetContraption()
        Snap.member = Con.ents[Other] == true
    elseif istable(Other) then
        Snap.otherCount = Other.count
    end

    return Snap
end

local function Record()
    return CFWTest.RecordHooks(Hooks, Snapshot)
end

return {
    groupName = "CFW: Contraption lifecycle",

    afterEach = CFWTest.Cleanup,

    cases = {
        {
            name = "Welding two lone entities puts both in one new contraption",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                local Con = CFWTest.WeldChain(A, B)

                expect(Con).to.exist()
                expect(B:CFW_GetContraption()).to.equal(Con)
                expect(Con.ents[A]).to.beTrue()
                expect(Con.ents[B]).to.beTrue()
                expect(Con.count).to.equal(2)
                expect(CFW.Contraptions[Con]).to.beTrue()

                done()
            end
        },

        {
            name = "created fires once, before entityAdded for either entity",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Log  = Record()
                local Con  = CFWTest.WeldChain(A, B)

                local Created  = CFWTest.Filter(Log, "cfw.contraption.created")
                local CreatedI = CFWTest.IndexOf(Log, "cfw.contraption.created")
                local AddedA   = CFWTest.IndexOf(Log, "cfw.contraption.entityAdded", A)
                local AddedB   = CFWTest.IndexOf(Log, "cfw.contraption.entityAdded", B)

                expect(#Created).to.equal(1)
                expect(Created[1] and Created[1].args[1]).to.equal(Con)
                expect(AddedA).to.exist()
                expect(AddedB).to.exist()
                expect(CreatedI).to.beLessThan(AddedA or 0)
                expect(CreatedI).to.beLessThan(AddedB or 0)

                done()
            end
        },

        {
            name = "created fires while the contraption is already registered and still empty",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Log  = Record()

                CFWTest.WeldChain(A, B)

                local Created = CFWTest.Filter(Log, "cfw.contraption.created")[1]

                expect(Created).to.exist()
                expect(Created and Created.state.registered).to.beTrue()
                expect(Created and Created.state.count).to.equal(0)

                done()
            end
        },

        {
            name = "entityAdded fires once per entity, after the entity already belongs to the contraption",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Log  = Record()
                local Con  = CFWTest.WeldChain(A, B)

                local AddedA = CFWTest.Filter(Log, "cfw.contraption.entityAdded", A)
                local AddedB = CFWTest.Filter(Log, "cfw.contraption.entityAdded", B)

                expect(#AddedA).to.equal(1)
                expect(#AddedB).to.equal(1)
                expect(AddedA[1] and AddedA[1].args[1]).to.equal(Con)
                expect(AddedA[1] and AddedA[1].state.owner).to.equal(Con)
                expect(AddedA[1] and AddedA[1].state.member).to.beTrue()
                expect(AddedB[1] and AddedB[1].state.owner).to.equal(Con)
                expect(AddedB[1] and AddedB[1].state.member).to.beTrue()

                done()
            end
        },

        {
            name = "Welding a lone entity onto a contraption adds it without creating another contraption",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B, C = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Con     = CFWTest.WeldChain(A, B)
                local Log     = Record()

                CFWTest.Weld(B, C)
                CFWTest.WaitUntil(function() return C:CFW_GetContraption() ~= nil end)

                local Added = CFWTest.Filter(Log, "cfw.contraption.entityAdded", C)

                expect(C:CFW_GetContraption()).to.equal(Con)
                expect(Con.count).to.equal(3)
                expect(#CFWTest.Filter(Log, "cfw.contraption.created")).to.equal(0)
                expect(#Added).to.equal(1)
                expect(Added[1] and Added[1].args[1]).to.equal(Con)

                done()
            end
        },

        {
            name = "Connecting two contraptions merges them into one",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B    = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local C, D, E = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Small   = CFWTest.WeldChain(A, B)
                local Large   = CFWTest.WeldChain(C, D, E)

                CFWTest.Weld(B, C)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B, C, D, E) end)

                local Con = A:CFW_GetContraption()

                expect(CFWTest.SameContraption(A, B, C, D, E)).to.beTrue()
                expect(Con.count).to.equal(5)
                expect(Con == Small or Con == Large).to.beTrue()

                done()
            end
        },

        {
            name = "merged fires once with the absorbed and surviving contraptions, after every moved entity was added to the survivor",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B    = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local C, D, E = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Small   = CFWTest.WeldChain(A, B)
                local Large   = CFWTest.WeldChain(C, D, E)
                local Log     = Record()

                CFWTest.Weld(B, C)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B, C, D, E) end)

                local Survivor = A:CFW_GetContraption()
                local Absorbed = Survivor == Small and Large or Small
                local Merged   = CFWTest.Filter(Log, "cfw.contraption.merged")
                local MergedI  = CFWTest.IndexOf(Log, "cfw.contraption.merged")

                expect(#Merged).to.equal(1)
                expect(Merged[1] and Merged[1].args[1]).to.equal(Absorbed)
                expect(Merged[1] and Merged[1].args[2]).to.equal(Survivor)

                local Moved = Absorbed == Small and { A, B } or { C, D, E }

                for _, Ent in ipairs(Moved) do
                    local AddedI = CFWTest.IndexOf(Log, "cfw.contraption.entityAdded", Ent)

                    expect(AddedI).to.exist()
                    expect(AddedI or math.huge).to.beLessThan(MergedI or 0)
                end

                done()
            end
        },

        {
            name = "Merging does not report the absorbed contraption as removed, and unregisters it",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B    = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local C, D, E = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Small   = CFWTest.WeldChain(A, B)
                local Large   = CFWTest.WeldChain(C, D, E)
                local Log     = Record()

                CFWTest.Weld(B, C)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B, C, D, E) end)

                local Survivor = A:CFW_GetContraption()
                local Absorbed = Survivor == Small and Large or Small

                expect(#CFWTest.Filter(Log, "cfw.contraption.removed")).to.equal(0)
                expect(CFW.Contraptions[Absorbed]).to.beNil()
                expect(CFW.Contraptions[Survivor]).to.beTrue()

                done()
            end
        },

        {
            name = "Cutting a contraption in two leaves one piece on the original contraption and the other on a new one",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B    = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local C, D, E = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Cut     = CFWTest.Weld(B, C)

                CFWTest.Weld(A, B)
                CFWTest.Weld(C, D)
                CFWTest.Weld(D, E)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B, C, D, E) end)

                local Original = A:CFW_GetContraption()

                Cut:Remove()
                CFWTest.WaitUntil(function() return A:CFW_GetContraption() ~= C:CFW_GetContraption() end)

                local Left, Right = A:CFW_GetContraption(), C:CFW_GetContraption()
                local New         = Left == Original and Right or Left

                expect(CFWTest.SameContraption(A, B)).to.beTrue()
                expect(CFWTest.SameContraption(C, D, E)).to.beTrue()
                expect(Left).notTo.equal(Right)
                expect(Left == Original or Right == Original).to.beTrue()
                expect(Left and Left.count).to.equal(2)
                expect(Right and Right.count).to.equal(3)
                expect(CFW.Contraptions[Original]).to.beTrue()
                expect(CFW.Contraptions[New]).to.beTrue()

                done()
            end
        },

        {
            name = "split fires once with the original and new contraptions, after the moved entities left one and joined the other",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B    = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local C, D, E = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Cut     = CFWTest.Weld(B, C)

                CFWTest.Weld(A, B)
                CFWTest.Weld(C, D)
                CFWTest.Weld(D, E)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B, C, D, E) end)

                local Original = A:CFW_GetContraption()
                local Log      = Record()

                Cut:Remove()
                CFWTest.WaitUntil(function() return #CFWTest.Filter(Log, "cfw.contraption.split") > 0 end)

                local Split  = CFWTest.Filter(Log, "cfw.contraption.split")
                local SplitI = CFWTest.IndexOf(Log, "cfw.contraption.split")
                local New    = Split[1] and Split[1].args[2]
                local Moved  = A:CFW_GetContraption() == New and { A, B } or { C, D, E }
                local Stayed = #Moved == 2 and 3 or 2

                expect(#Split).to.equal(1)
                expect(Split[1] and Split[1].args[1]).to.equal(Original)
                expect(New).notTo.equal(Original)
                expect(Split[1] and Split[1].state.count).to.equal(Stayed)
                expect(Split[1] and Split[1].state.otherCount).to.equal(#Moved)

                for _, Ent in ipairs(Moved) do
                    local Removed = CFWTest.Filter(Log, "cfw.contraption.entityRemoved", Ent)[1]
                    local Added   = CFWTest.Filter(Log, "cfw.contraption.entityAdded", Ent)[1]

                    expect(Removed and Removed.args[1]).to.equal(Original)
                    expect(Added and Added.args[1]).to.equal(New)
                    expect(Added and Added.state.owner).to.equal(New)
                    expect(CFWTest.IndexOf(Log, "cfw.contraption.entityRemoved", Ent) or math.huge).to.beLessThan(SplitI or 0)
                    expect(CFWTest.IndexOf(Log, "cfw.contraption.entityAdded", Ent) or math.huge).to.beLessThan(SplitI or 0)
                end

                done()
            end
        },

        {
            name = "Removing one of two connections between the same entities changes nothing",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Weld = CFWTest.Weld(A, B)

                constraint.Rope(A, B, 0, 0, vector_origin, vector_origin, 100, 0, 0, 1, "cable/rope", false)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B) end)
                CFWTest.WaitTicks(2) -- Let both connections register before cutting one

                local Con = A:CFW_GetContraption()
                local Log = Record()

                Weld:Remove()
                CFWTest.WaitTicks(5)

                expect(CFWTest.SameContraption(A, B)).to.beTrue()
                expect(A:CFW_GetContraption()).to.equal(Con)
                expect(#Log).to.equal(0)

                done()
            end
        },

        {
            name = "Removing the last connection dissolves the contraption",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Weld = CFWTest.Weld(A, B)

                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B) end)

                local Con = A:CFW_GetContraption()

                Weld:Remove()
                CFWTest.WaitUntil(function() return A:CFW_GetContraption() == nil and B:CFW_GetContraption() == nil end)

                expect(A:CFW_GetContraption()).to.beNil()
                expect(B:CFW_GetContraption()).to.beNil()
                expect(CFW.Contraptions[Con]).to.beNil()

                done()
            end
        },

        {
            name = "removed fires once, after entityRemoved for each remaining entity",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Weld = CFWTest.Weld(A, B)

                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B) end)

                local Con = A:CFW_GetContraption()
                local Log = Record()

                Weld:Remove()
                CFWTest.WaitUntil(function() return #CFWTest.Filter(Log, "cfw.contraption.removed") > 0 end)

                local Removed  = CFWTest.Filter(Log, "cfw.contraption.removed")
                local RemovedI = CFWTest.IndexOf(Log, "cfw.contraption.removed")
                local SubA     = CFWTest.Filter(Log, "cfw.contraption.entityRemoved", A)
                local SubB     = CFWTest.Filter(Log, "cfw.contraption.entityRemoved", B)

                expect(#Removed).to.equal(1)
                expect(Removed[1] and Removed[1].args[1]).to.equal(Con)
                expect(#SubA).to.equal(1)
                expect(#SubB).to.equal(1)
                expect(SubA[1] and SubA[1].args[1]).to.equal(Con)
                expect(SubA[1] and SubA[1].state.owner).to.beNil()
                expect(SubA[1] and SubA[1].state.member).to.beFalse()
                expect(CFWTest.IndexOf(Log, "cfw.contraption.entityRemoved", A) or math.huge).to.beLessThan(RemovedI or 0)
                expect(CFWTest.IndexOf(Log, "cfw.contraption.entityRemoved", B) or math.huge).to.beLessThan(RemovedI or 0)

                done()
            end
        },

        {
            name = "Removing an entity takes it out of its contraption",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B, C = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local Con     = CFWTest.WeldChain(A, B, C)
                local Log     = Record()

                C:Remove()
                CFWTest.WaitUntil(function() return not IsValid(C) end)

                local Sub = CFWTest.Filter(Log, "cfw.contraption.entityRemoved")

                expect(CFWTest.SameContraption(A, B)).to.beTrue()
                expect(A:CFW_GetContraption()).to.equal(Con)
                expect(Con.count).to.equal(2)
                expect(#Sub).to.equal(1)
                expect(Sub[1] and Sub[1].args[1]).to.equal(Con)

                done()
            end
        },

        {
            name = "Ropes connect entities too",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                constraint.Rope(A, B, 0, 0, vector_origin, vector_origin, 100, 0, 0, 1, "cable/rope", false)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B) end)

                expect(CFWTest.SameContraption(A, B)).to.beTrue()

                done()
            end
        },

        {
            name = "Constraining to the world does not create a contraption",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A = CFWTest.SpawnProp(State)

                CFWTest.Weld(A, game.GetWorld())
                CFWTest.WaitTicks(5)

                expect(A:CFW_GetContraption()).to.beNil()

                done()
            end
        },

        {
            name = "Cutting a few entities off keeps the rest in the original contraption",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B, C, D = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local X, Y       = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                -- A is Ent1 of the cut, so the bigger side is the one the cut starts from
                CFWTest.WeldChain(A, B, C, D)
                CFWTest.WeldChain(X, Y)

                local Cut = CFWTest.Weld(A, X)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B, C, D, X, Y) end)

                local Original = A:CFW_GetContraption()
                local Log      = Record()

                Cut:Remove()
                CFWTest.WaitUntil(function() return #CFWTest.Filter(Log, "cfw.contraption.split") > 0 end)

                expect(D:CFW_GetContraption()).to.equal(Original)
                expect(CFWTest.SameContraption(A, B, C, D)).to.beTrue()
                expect(CFWTest.SameContraption(X, Y)).to.beTrue()
                expect(X:CFW_GetContraption()).notTo.equal(Original)
                expect(#CFWTest.Filter(Log, "cfw.contraption.entityRemoved")).to.equal(2)

                done()
            end
        },

        {
            name = "Removing a whole contraption at once leaves nothing registered, however many constraints join two entities",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local B, S, X, Y = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                CFWTest.Weld(B, S)
                constraint.Rope(B, S, 0, 0, vector_origin, vector_origin, 100, 0, 0, 1, "cable/rope", false)
                constraint.Ballsocket(B, S, 0, 0, vector_origin, 0, 0, 0)
                CFWTest.Weld(B, X)
                CFWTest.Weld(X, Y)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(B, S, X, Y) end)

                local Log = Record()
                local Seen = { B:CFW_GetContraption() }

                for _, Ent in ipairs({ B, S, X, Y }) do Ent:Remove() end
                CFWTest.WaitTicks(3)

                for _, Entry in ipairs(CFWTest.Filter(Log, "cfw.contraption.created")) do Seen[#Seen + 1] = Entry.args[1] end

                for _, Con in ipairs(Seen) do
                    expect(CFW.Contraptions[Con]).to.beNil()
                end

                done()
            end
        },

        {
            name = "A constraint to an entity removed in the same tick doesn't connect anything",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                CFWTest.Weld(A, B)
                B:Remove()
                CFWTest.WaitTicks(3)

                expect(A:CFW_GetContraption()).to.beNil()

                done()
            end
        },

        {
            name = "An AdvDupe2 undo leaves what it didn't remove tracked normally",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                local A, B = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)
                local P, Q = CFWTest.SpawnProp(State), CFWTest.SpawnProp(State)

                -- A and B are the "paste", P was welded on afterwards and Q hangs off P
                CFWTest.WeldChain(A, B)
                CFWTest.Weld(P, A)
                Q:SetParent(P)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B, P, Q) end)

                -- What undo.Do_Undo does, without the net message to an owner the test doesn't have
                hook.Run("PreUndo", { Name = "AdvDupe2", Entities = { A, B } })
                A:Remove()
                B:Remove()
                CFWTest.WaitUntil(function() return not IsValid(A) and not IsValid(B) end)
                CFWTest.WaitTicks(1)

                local Con = P:CFW_GetContraption()

                expect(Con).to.exist()
                expect(Con and CFW.Contraptions[Con]).to.beTrue()
                expect(Q:CFW_GetContraption()).to.equal(Con)

                -- Reparenting afterwards still reaches CFW
                Q:SetParent(nil)
                CFWTest.WaitTicks(2)

                expect(Q:CFW_GetContraption()).to.beNil()
                expect(P:CFW_GetContraption()).to.beNil()
                expect(P:GetFamily()).to.beNil()

                done()
            end
        },

        {
            name = "A stock duplicator copy of entities without a factory doesn't share the original's contraption",
            async = true,
            coroutine = true,
            timeout = 5,
            func = function(State)
                CFWTest.WaitForReady()

                -- The stock duplicator copies the whole Lua table of a class it has no factory for
                local Class = "cfw_test_dupe"
                scripted_ents.Register({
                    Type = "anim", Base = "base_anim",
                    Initialize = function(self) self:PhysicsInit(SOLID_VPHYSICS) end,
                }, Class)

                local A, B, C = CFWTest.SpawnProp(State, Class), CFWTest.SpawnProp(State, Class), CFWTest.SpawnProp(State, Class)

                CFWTest.Weld(A, B)
                C:SetParent(B)
                CFWTest.WaitUntil(function() return CFWTest.SameContraption(A, B, C) end)

                local Original = A:CFW_GetContraption()
                local Count    = Original.count
                local Copy     = duplicator.Copy(A)
                local Created  = duplicator.Paste(nil, Copy.Entities, Copy.Constraints)

                for _, Ent in pairs(Created) do State.Ents[#State.Ents + 1] = Ent end
                CFWTest.WaitTicks(3)

                expect(Original.count).to.equal(Count)
                expect(A:CFW_GetContraption()).to.equal(Original)

                for _, Ent in pairs(Created) do
                    local Con = Ent:CFW_GetContraption()

                    expect(Con).notTo.equal(Original)
                    expect(Original.ents[Ent]).to.beNil()
                    if Con then expect(CFW.Contraptions[Con]).to.beTrue() end
                end

                done()
            end
        },
    }
}
