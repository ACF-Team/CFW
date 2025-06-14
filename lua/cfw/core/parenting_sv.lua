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

        function ENT:SetParent(newParent, newAttach, ...)
            local savedParent
            local oldParent = getParent(self)
            local validNewParent = IsValid(newParent)
            local validOldParent = IsValid(oldParent)

            -- NOTE:
            -- CFW_OnParentedTo is called before any parenting operation happens, to allow entities to block parenting
            -- Therefore GetParent() will be outdated in CFW_OnParentedTo call stacks
            -- See CFW_AfterParentedTo, which cannot block calls.
            if self.CFW_OnParentedTo and self:CFW_OnParentedTo(oldParent, newParent, newAttach, ...) == false then
                return
            end

            if (validOldParent and oldParent.CFW_OnParented) and not validNewParent then
                oldParent:CFW_OnParented(self, false)
            end

            if validNewParent then
                local detour = detours[newParent:GetClass()]

                if newParent.CFW_OnParented then
                    savedParent = newParent
                end

                if detour then
                    newParent = detour(newParent) or newParent
                end
            end

            if self == newParent then return end

            setParent(self, newParent, newAttach, ...)

            if IsValid(savedParent) then
                savedParent:CFW_OnParented(self, true)
            end

            if self.CFW_AfterParentedTo then self:CFW_AfterParentedTo(oldParent, newParent) end

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

    local links = ent:GetLinks()

    if not next(links) then return end

    for index in pairs(links) do
        disconnect(ent, index)
    end
end)
