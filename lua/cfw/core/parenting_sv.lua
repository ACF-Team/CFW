local connect    = CFW.connect
local disconnect = CFW.disconnect
local filter     = {
    gmod_hands = true
}

CFW.parentFilter = filter

local detours = {}

function CFW.addParentDetour(class, variable)
    if not class then return end
    if not variable then return end

    detours[class] = function(entity)
        return entity[variable]
    end
end

hook.Add("Initialize", "CFW", function()
    timer.Simple(0, function()
        local ENT       = FindMetaTable("Entity")
        local setParent = ENT.SetParent
        local getParent = ENT.GetParent

        --[[
            The hooks here are as follows:
            (we need better docs! many such cases!)

                - CFW_PreParentedTo: Allows the entity to block itself from being parented.
                - CFW_PreParented: Allows the entity to block another entity from being parented to it.
                - CFW_OnParentedTo: A non-blockable equiv. of PreParentedTo
                - CFW_OnParented: A non-blockable equiv. of PreParented

                The hook order is this:
                    - CFW_PreParentedTo on potential child (may block)
                    - CFW_PreParented on potential parent (may block)
                    - If a valid old parent exists, CFW_OnParented(child, false)
                    - ACTUAL SET PARENT HAPPENS
                    - If a valid new parent, call CFW_OnParented
                    - Call self OnParentedTo
        ]]
        function ENT:SetParent(newParent, newAttach, ...)
            local savedParent
            local oldParent = getParent(self)
            local validNewParent = IsValid(newParent)
            local validOldParent = IsValid(oldParent)

            -- Check if the entity is able to be a child to this parent or not.
            if self.CFW_PreParentedTo and self:CFW_PreParentedTo(oldParent, newParent, newAttach, ...) == false then
                return
            end

            -- If a valid new parent, get any entity detours that may be present for the new parents class
            if validNewParent then
                local detour = detours[newParent:GetClass()]

                -- Store savedParent so we can do CFW_PreParented and CFW_OnParented later on the actual target
                if newParent.CFW_OnParented then
                    savedParent = newParent
                end

                -- Set newParent to detour
                if detour then
                    -- march note: shouldn't we be setting validNewParent again here?
                    -- won't do it for now to avoid breaking anything, but seems like an obvious one
                    newParent = detour(newParent) or newParent
                end
            end

            -- Block parenting to self (why doesn't this just happen earlier on?? that case would never be valid!)
            if self == newParent then return end

            -- Check if the parent is willing to accept this child or not
            if IsValid(savedParent) and savedParent.CFW_PreParented and savedParent:CFW_PreParented(self) == false then
                return
            end

            -- At this point on, nothing else will block the parenting call
            -- Pre-deparenting hook
            -- MARCH: Changed this to not check "not validNewParent" (didn't really make sense... and didn't allow deparenting checks unless there was no valid parent??)
            if validOldParent and oldParent.CFW_OnParented then
                oldParent:CFW_OnParented(self, false)
            end

            -- Actual setparent call
            setParent(self, newParent, newAttach, ...)

            -- Hook for post-new-child
            if IsValid(savedParent) then
                savedParent:CFW_OnParented(self, true)
            end

            -- Hook for post-new-parent
            if self.CFW_OnParentedTo then
                self:CFW_OnParentedTo(oldParent, newParent)
            end

            if self._cfwRemoved then return end -- Removed by an undo
            if oldParent == newParent then return end
            if (validOldParent and oldParent:IsPlayer()) or (validNewParent and newParent:IsPlayer()) then return end
            if (validOldParent and oldParent:IsNPC()) or (validNewParent and newParent:IsNPC()) then return end
            if (validOldParent and oldParent:IsNextBot()) or (validNewParent and newParent:IsNextBot()) then return end
            if filter[self:GetClass()] then return end

            if validOldParent then disconnect(self, oldParent:EntIndex(), isParent) end
            if validNewParent then connect(self, newParent, isParent) end

            if self.CFW_NO_FAMILY_TRAVERSAL then return end

            if validNewParent then
                if newParent._family then
                    self:SetFamily(newParent._family)
                else
                    CFW.Classes.Family.create(newParent)
                end
            else
                self:SetFamily(nil)
            end
        end

        function ENT:GetParent()
            local parent = getParent(self)

            if IsValid(parent) then
                local detour = detours[parent:GetClass()]

                if detour then
                    parent = detour(parent) or parent
                end
            end

            return parent
        end
    end)

    hook.Remove("Initialize", "CFW")
end)

-- In order to prevent NULL entities flooding the ENT._links table, we'll just get rid of them before they get removed
-- This is a fix for a really annoying issue that was showing up in multiple different ways
hook.Add("EntityRemoved", "cfw.entityRemoved", function(ent)
    if not IsValid(ent) then return end

    local links = ent:GetCFWLinks()

    if not next(links) then return end

    for index in pairs(links) do
        disconnect(ent, index)
    end
end)
