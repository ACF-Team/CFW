-- Base class shared by Contraption and Family.
-- Both track entities in an ents table, an entsbyclass map, and a count
-- The extensions also add mass tracking and other features

CFW.Classes.EntityCollection = {}

do
    local BASE  = CFW.Classes.EntityCollection

    BASE.__index = BASE

    -- Returns the set of tracked entities of the given class, or an empty table.
    function BASE:EntitiesByClass(className)
        return self.entsbyclass[className] or {}
    end

    -- Returns true if at least one entity of the given class is tracked.
    function BASE:ContainsClass(className)
        local tracked = self.entsbyclass[className]
        return tracked and next(tracked) ~= nil or false
    end

    -- Registers entity in entsbyclass.
    function BASE:AddByClass(entity)
        local className = entity:GetClass()
        self.entsbyclass[className] = self.entsbyclass[className] or {}
        self.entsbyclass[className][entity] = true
    end

    -- Removes entity from entsbyclass.
    function BASE:RemoveByClass(entity)
        local className = entity:GetClass()
        local byClass   = self.entsbyclass[className]

        if byClass then
            byClass[entity] = nil
            if not next(byClass) then
                self.entsbyclass[className] = nil
            end
        end
    end

    -- Bulk-inserts all entities from another collection's entsbyclass into this one.
    function BASE:MergeByClass(other)
        for className, ents in pairs(other.entsbyclass) do
            self.entsbyclass[className] = self.entsbyclass[className] or {}

            for ent in pairs(ents) do
                self.entsbyclass[className][ent] = true
            end
        end
    end
end
