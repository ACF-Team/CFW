local connect    = CFW.connect
local disconnect = CFW.disconnect

hook.Add("Initialize", "CFW", function()
    timer.Simple(0, function()
        local ENT       = FindMetaTable("Entity")
        local setParent = ENT.SetParent

        function ENT:SetParent(parent, newAttach, ...)
            local oldParent = self:GetParent()
            local oldAttach = self:GetParentAttachment()

            setParent(self, parent, newAttach, ...)

            if self._cfwRemoved then return end -- Removed by an undo
            if oldParent == parent and oldAttach ~= newAttach then return end
            if self:GetClass() == "gmod_hands" then return end
        
            if IsValid(oldParent) then disconnect(self, oldParent, isParent) end
            if IsValid(parent) then connect(self, parent, isParent) end
        end
    end)

    hook.Remove("Initialize", "CFW")
end)