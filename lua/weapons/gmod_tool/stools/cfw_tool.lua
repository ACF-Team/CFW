TOOL.Category	= "Contraption Framework"
TOOL.Name		= "CFW Tool"
TOOL.AddToMenu	= false


--[[
	To access this, use 'gmod_tool cfw_tool'
	Hidden because this relies on developer 1, so not for use by normal means, for now
	Eventually this will get fleshed out with multiple debug modes

	For example:
	Op 1 - Show entity's links via link table
	Op 2 - Show contraption that this entity is a part of
	Op 3 - ?

	Tool screen should reflect mode of the tool as well
	When this happens, maybe allow normal use of the tool as well?
]]


TOOL.Entity		= nil

function TOOL:LeftClick(tr)
	if not IsFirstTimePredicted() then return end
	if CLIENT then return true end

	if (not IsValid(tr.Entity)) or tr.Entity:IsWorld() then
		self.Entity = nil
	else
		self.Entity	= tr.Entity
	end

	return true
end

function TOOL:Reload()
	if not IsFirstTimePredicted() then return end
	if CLIENT then return end

	self.Entity = nil
end

function TOOL:Think()
	local ent	= self.Entity
	if not IsValid(ent) then return end
	local selftbl	= ent:GetTable()

	if not selftbl._links then return end

	local tick = engine.TickInterval() + 0.05

	local Rendered = {}
	for _, link in pairs(selftbl._links) do
		local entA, entB = link.entA, link.entB
		debugoverlay.Line(entA:GetPos(),entB:GetPos(),tick,link.color,true)

		if not Rendered[entA] then
			debugoverlay.Text(entA:GetPos(),"A",tick,false)

			Rendered[entA] = true
		end

		if not Rendered[entB] then
			debugoverlay.Text(entB:GetPos(),"B",tick,false)
			Rendered[entB] = true
		end



	end
end

