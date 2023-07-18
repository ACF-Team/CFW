local connect    = CFW.connect
local disconnect = CFW.disconnect
local filter     = {
    gmod_hands = true
}

CFW.parentFilter = filter

hook.Add("Initialize", "CFW", function()
    timer.Simple(0, function()
        local ENT       = FindMetaTable("Entity")
        local setParent = ENT.SetParent

        function ENT:SetParent(newParent, newAttach, ...)
            local oldParent = self:GetParent()
            local oldAttach = self:GetParentAttachment()

            setParent(self, newParent, newAttach, ...)

            if self._cfwRemoved then return end -- Removed by an undo
            if oldParent == newParent then return end
            if filter[self:GetClass()] then return end

            if IsValid(oldParent) then disconnect(self, oldParent:EntIndex(), isParent) end
            if IsValid(newParent) then connect(self, newParent, isParent) end

            if self.CFW_NO_FAMILY_TRAVERSAL then return end

            if IsValid(newParent) then
                if newParent._family then
                    self:SetFamily(newParent._family)
                else
                    CFW.classes.family.create(newParent)
                end
            else
                self:SetFamily(nil)
            end
        end
    end)

    hook.Remove("Initialize", "CFW")
end)