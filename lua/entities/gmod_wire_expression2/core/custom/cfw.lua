E2Lib.RegisterExtension("contraption", true, "Enables interaction with Contraption Framework")

local function isValidContraption(c)
    return CFW.Contraptions[c] or false
end

do -- Datatype and operator
    registerType("contraption", "xcr", nil, nil, nil,
        function(retval)
            if retval == nil then return end
            if not istable(retval) then error("Return value is neither nil nor a table, but a "..type(retval).."!",0) end
        end,
        function(v)
            return not istable(v)
        end
    )

    e2function number operator_is(contraption cont)
	    return isValidContraption(cont) and 1 or 0
    end

    e2function number operator==(contraption c1, contraption c2)
        return c1 == c2 and 1 or 0
    end
end

do
    hook.Add("cfw.contraption.created", "e2Tables", function(c)
        c.e2Table = E2Lib.newE2Table()
    end)

    -- TODO: Merge support
end

__e2setcost(5)

e2function number contraption:isValid()
    return isValidContraption(this) and 1 or 0
end

e2function contraption entity:getContraption()
    return this:GetContraption()
end

e2function number contraption:count()
    return isValidContraption(this) and this.count or 0
end

e2function number contraption:getMass()
    return isValidContraption(this) and this.totalMass or 0
end

e2function table contraption:getTable()
    return isValidContraption(this) and this.e2Table or E2Lib.newE2Table()
end

__e2setcost(20)

e2function array contraption:getEntities()
    if not isValidContraption(this) then return {} end

    local output = {}
    local count  = 0

    for k in pairs(this.ents) do
        count = count + 1

        output[count] = k
    end

    self.prf = self.prf + count * 2
    return output
end