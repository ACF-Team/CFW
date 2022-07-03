hook.Add("Initialize", "CFW", function()
    timer.Simple(0, function()
        local ENT       = FindMetaTable("Entity")
        local setParent = ENT.SetParent

        function ENT:SetParent(parent, newAttach, ...)
            local oldParent = self:GetParent()
            local oldAttach = self:GetParentAttachment()

            setParent(self, parent, newAttach, ...)

            -- Contraption framework doesn't care about attachments, so we short circuit here if it's just an attachmentID change
            if self._cfwRemoved then return end -- Removed by an undo
            if oldParent == parent and oldAttach ~= newAttach then return end
            if IsValid(parent) and parent:GetClass() == "predicted_viewmodel" then return end

            if IsValid(oldParent) then CFW.disconnect(self, oldParent) end
            if IsValid(parent) then CFW.connect(self, parent) end
        end
    end)

    hook.Remove("Initialize", "CFW")
end)