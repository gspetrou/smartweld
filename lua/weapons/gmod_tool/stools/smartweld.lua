--[[
Smart Weld
Created by: Stalker (STEAM_0:1:18093014)		- Contact for support
Originally by Duncan Stead (Dunk)				- Dont contact for support
]]

TOOL.AllowedClasses = {
	prop_physics				= true,
	prop_ragdoll				= true,
	prop_vehicle				= true,
	prop_vehicle_jeep			= true,
	prop_vehicle_airboat		= true,
	prop_vehicle_apc			= true,
	prop_vehicle_crane			= true,
	prop_vehicle_prisoner_pod	= true
}

TOOL.AllowedBaseClasses = {
	base_entity					= true,
	base_edit					= true,
	base_anim					= true,
	base_gmodentity				= true,
	base_wire_entity			= true,
	wac_hc_base					= true,
	wac_pl_base					= true,
	wac_pod_base				= true,
	sent_sakarias_scar_base		= true
}

TOOL.MaxWeldsPerProp = 10 -- Only for when you weld more than 127 props at once

TOOL.Category 						= "Constraints"
TOOL.Name 							= "Weld - Smart"
TOOL.ClientConVar["selectradius"] 	= 100
TOOL.ClientConVar["nocollide"] 		= 1
TOOL.ClientConVar["freeze"] 		= 0
TOOL.ClientConVar["clearwelds"]		= 1
TOOL.ClientConVar["strength"] 		= 0
TOOL.ClientConVar["world"] 			= 0
TOOL.ClientConVar["color_r"] 		= 0
TOOL.ClientConVar["color_g"] 		= 255
TOOL.ClientConVar["color_b"] 		= 0
TOOL.ClientConVar["color_a"] 		= 255
TOOL.SelectedProps = {}

if CLIENT then
	language.Add("tool.smartweld.name", "Weld - Smart")
	language.Add("tool.smartweld.desc", "Automatically welds selected props")
	language.Add("tool.smartweld.0", "Left-click to select/deselect props. Use key and left click to auto-select.")
	language.Add("tool.smartweld.1", "Right-click to weld selected props. Reload key to unselect all. Hold Use and right-click to weld everything to the prop you\'re looking at.")
	language.Add("tool.smartweld.selectoutsideradius", "Auto-Select Radius:")
	language.Add("tool.smartweld.selectoutsideradius.help", "The auto-select radius, anything beyond this value wont be selected")
	language.Add("tool.smartweld.strength", "Force Limit:")
	language.Add("tool.smartweld.strength.help", "The strength of the welds created. Use 0 for unbreakable welds")
	language.Add("tool.smartweld.world", "Weld everything to world")
	language.Add("tool.smartweld.world.help", "Turning this on will weld everything to the world. Useful for making something totally immovable")
	language.Add("tool.smartweld.nocollide", "No-collide")
	language.Add("tool.smartweld.nocollide.help", "Whether all props should no-collide each other when welded")
	language.Add("tool.smartweld.freeze", "Auto-freeze")
	language.Add("tool.smartweld.freeze.help", "Whether all selected props should be frozen after the weld")
	language.Add("tool.smartweld.clearwelds", "Remove old welds")
	language.Add("tool.smartweld.clearwelds.help", "If a selected prop has any welds already on it this will remove them first")
	language.Add("tool.smartweld.color", "Selection color")
	language.Add("tool.smartweld.color.help", "Modify the selection color, it\'s useful for grouping")
	language.Add("Undone_smartweld", "Undone Smart-Weld")
end

function TOOL.BuildCPanel(panel)
	panel:SetName("Smart Weld")

	panel:AddControl("Header", {
		Text = "",
		Description = "Automatically welds selected props."
	})

	-- Outside Radius
	panel:AddControl("Slider", {
		Label = "#tool.smartweld.selectoutsideradius",
		Help = "#tool.smartweld.selectoutsideradius",
		Type = "float",
		Min = "0",
		Max = "1000",
		Command = "smartweld_selectradius"
	})

	-- Force Limit
	panel:AddControl("Slider", {
		Label = "#tool.smartweld.strength",
		Help = "#tool.smartweld.strength",
		Type = "float",
		Min = "0",
		Max = "10000",
		Command = "smartweld_strength"
	})

	-- Weld to each other or all to world
	panel:AddControl("Checkbox", {
		Label = "#tool.smartweld.world",
		Help = "#tool.smartweld.world",
		Command = "smartweld_world"
	})

	-- No-Collide Props While Welding
	panel:AddControl("Checkbox", {
		Label = "#tool.smartweld.nocollide",
		Help = "#tool.smartweld.nocollide",
		Command = "smartweld_nocollide"
	})

	-- Freeze Props When Welded
	panel:AddControl("Checkbox", {
		Label = "#tool.smartweld.freeze",
		Help = "#tool.smartweld.freeze",
		Command = "smartweld_freeze"
	})

	-- Clear Previous Welds Before Welding
	panel:AddControl("Checkbox", {
		Label = "#tool.smartweld.clearwelds",
		Help = "#tool.smartweld.clearwelds",
		Command = "smartweld_clearwelds"
	})

	-- Color
	panel:AddControl("Color", {
		Label = "#tool.smartweld.color",
		Help = "#tool.smartweld.color",
		Red = "smartweld_color_r",
		Green = "smartweld_color_g",
		Blue = "smartweld_color_b",
		Alpha = "smartweld_color_a"
	})
end
 
function TOOL:Deploy()
end

-- Clears selected props when you die or holster the tool
function TOOL:Holster()
	if CLIENT or game.SinglePlayer() then
		for k, v in ipairs(self.SelectedProps) do
			if IsValid(v.ent) then
				v.ent:SetColor(v.col)
			end
		end
	end
	self.SelectedProps = {}
	self:SetStage(1)
end

-- Does some validity checks then either selects or deselects the prop
function TOOL:LeftClick(tr)
	if IsFirstTimePredicted() and IsValid(tr.Entity) and not tr.Entity:IsPlayer() then
		if SERVER and not util.IsValidPhysicsObject(tr.Entity, tr.PhysicsBone) then
			return false 
		end

		if self:GetOwner():KeyDown(IN_USE) then
			return self:AutoSelect(tr.Entity)
		end

		return self:HandleProp(tr)
	end
	return false
end

-- Auto-selects props
function TOOL:AutoSelect(ent)
	if not IsValid(ent) then return false end
	local preAutoSelect = #self.SelectedProps

	local selectRadius = self:GetClientNumber("selectradius")
	local radiusProps = ents.FindInSphere(ent:GetPos(), selectRadius)
	if #radiusProps < 1 then return false end

	local numNearProps = 0

	for i = 1, #radiusProps do
		if self:IsAllowedEnt(ent) and not self:PropHasBeenSelected(radiusProps[i]) then
			self:SelectProp(radiusProps[i])

			numNearProps = numNearProps + 1
		end
	end

	self:Notify((#self.SelectedProps-preAutoSelect).." prop(s) have been auto-selected.", NOTIFY_GENERIC)
end

-- Decides if we should select or deselect the specified entity
function TOOL:HandleProp(tr)
	if #self.SelectedProps == 0 then
		self:SelectProp(tr.Entity, tr.PhysicsBone)
	else
		for k, v in ipairs(self.SelectedProps) do
			if v.ent == tr.Entity then
				self:DeselectProp(tr.Entity)

				return true
			end
		end
		self:SelectProp(tr.Entity, tr.PhysicsBone)
	end

	return true
end

-- Deselects the chosen prop
function TOOL:DeselectProp(ent)
	for k, v in ipairs(self.SelectedProps) do
		if v.ent == ent then
			if CLIENT or game.SinglePlayer() then
				ent:SetColor(v.col)
			end
			table.remove(self.SelectedProps, k)
		end
	end

	return true
end

-- Adds prop to props table and sets its color
function TOOL:SelectProp(entity, hitBoneNum)
	if self:IsAllowedEnt(entity) then
		if #self.SelectedProps == 0 then
			self:SetStage(1)
		end

		local boneNum = entity:IsRagdoll() and hitBoneNum or 0

		table.insert(self.SelectedProps, {
			ent = entity,
			col = entity:GetColor(),
			bone = boneNum
		})

		if CLIENT or game.SinglePlayer() then
			entity:SetColor(Color(self:GetClientNumber("color_r", 0), self:GetClientNumber("color_g", 0), self:GetClientNumber("color_b", 0), self:GetClientNumber("color_a", 255)))
		end
		return true
	end
	return false
end

-- Pretty much deselects all
function TOOL:Reload()
	if IsFirstTimePredicted() and self.SelectedProps then
		self:SetStage(1)

		if CLIENT or game.SinglePlayer() then
			for k, v in ipairs(self.SelectedProps) do
				v.ent:SetColor(v.col)
			end
		end
		
		self.SelectedProps = {}
		self:Notify("Prop Selection Cleared", NOTIFY_CLEANUP)
	end
end

-- Handles the welding
function TOOL:RightClick(tr)
	if (#self.SelectedProps <= 1) then
		self:Notify((#self.SelectedProps == 1 and "Select at least one more prop to weld." or "No props selected!"), NOTIFY_GENERIC)
		return false
	end

	if SERVER then
		undo.Create("smartweld")

			self:PreWeld()
			self:PerformWeld(tr)	

			undo.SetPlayer(self:GetOwner())
		undo.Finish()
	end

	self:FinishWelding(tr.Entity)
	return false
end

-- Does stuff that should happen before welding such as clearing old welds or freezing all the props
function TOOL:PreWeld()
	local freezeProps = self:GetClientNumber("freeze")
	local removeOldWelds = self:GetClientNumber("clearwelds")

	for k, v in ipairs(self.SelectedProps) do
		if (removeOldWelds == 1) then
			constraint.RemoveConstraints(v.ent, "Weld") 
		end

		if (freezeProps == 1) then
			if IsValid(v.ent) then
				local physobj = v.ent:GetPhysicsObject()
				if IsValid(physobj) then
					physobj:EnableMotion(false)
					self:GetOwner():AddFrozenPhysicsObject(v.ent, physobj)
				end
			end
		end
	end
end

-- Decides what kind of weld to perform and then does it
function TOOL:PerformWeld()
	local weldToWorld = self:GetClientNumber("world")
	local nocollide = tobool(self:GetClientNumber("nocollide"))
	local weldForceLimit = math.floor(self:GetClientNumber("strength"))

	if (weldToWorld == 1) then
		for k, v in ipairs(self.SelectedProps) do
			local weld = constraint.Weld(v.ent, game.GetWorld(), 0, 0, weldForceLimit, nocollide, false)
			undo.AddEntity(weld)
		end
	elseif self:GetOwner():KeyDown(IN_USE) then 	-- Weld all to one
		for k, v in ipairs(self.SelectedProps) do
			local weld = constraint.Weld(v.ent, tr.Entity, v.bone, tr.PhysicsBone, weldForceLimit, nocollide, false)
			undo.AddEntity(weld)
		end
	elseif (#self.SelectedProps < 128) then
		for k, v in ipairs(self.SelectedProps) do	-- Normal Weld
			for otherProps = 1, #self.SelectedProps do
				if (i ~= otherProps) and (i ~= #self.SelectedProps) then
					if not IsValid(v.ent) or not IsValid(self.SelectedProps[otherProps].ent) then continue end
					local weld = constraint.Weld(v.ent, self.SelectedProps[otherProps].ent, v.bone, self.SelectedProps[otherProps].bone, weldForceLimit, nocollide, false)
					undo.AddEntity(weld)
				end
			end
		end
	else	-- There is a source engine limit with welding more than 127 props so we have to work around it by welding to the closest props
		local welds = {}
		local weldcount = 0
		for k,v in ipairs(self.SelectedProps) do
			welds[k] = {}
		end

		for k, v in ipairs(self.SelectedProps) do
			for x = 1, self.MaxWeldsPerProp do
				local closestdistance = 99999999
				local closestprop = -1

				for d, j in ipairs(self.SelectedProps) do
					if k ~= d then
						local linked = false

						for k, val in ipairs(welds[k]) do
							if val == d then
								linked = true
								break
							end
						end

						if not linked then
							local distance = (v.ent:GetPos() - j.ent:GetPos()):Length()

							if distance < closestdistance then
								closestdistance = distance
								closestprop = d
							end
						end
					end
				end

				if closestprop ~= -1 then
					-- Weld to this prop and add to weld list
					local weld = constraint.Weld(v.ent, self.SelectedProps[closestprop].ent, 0, 0, weldForceLimit, nocollide, false)
					undo.AddEntity(weld)

					weldcount = weldcount + 1
					table.insert(welds[k], closestprop)
					table.insert(welds[closestprop], k)
				else
					break
				end
			end
		end
		
	end
end

function TOOL:FinishWelding(entity)
	if CLIENT or game.SinglePlayer() then
		local numProps = 0

		for k, v in ipairs(self.SelectedProps) do
			if IsValid(v.ent) then
				v.ent:SetColor(v.col)
				numProps = numProps + 1
			end
		end

		if self:GetOwner():KeyDown(IN_USE) then	-- If they chose to weld all to one prop this will correct the count
			for k, v in ipairs(self.SelectedProps) do
				if (v.ent == entity) then
					numProps = numProps + 1
					break
				end
			end
			self:Notify("Weld complete! "..numProps.." props have been welded to a single prop.", NOTIFY_GENERIC)
		elseif tobool(self:GetClientNumber("world")) then
			self:Notify("Weld complete! "..numProps.." props have been welded to the world.", NOTIFY_GENERIC)
		else
			self:Notify("Weld complete! "..numProps.." props have been welded to each other.", NOTIFY_GENERIC)
		end
	end
	self.SelectedProps = {}
	self:SetStage(1)
end

-- Checks if a prop has already been selected
function TOOL:PropHasBeenSelected(ent)
	for k, v in ipairs(self.SelectedProps) do
		if (ent == v.ent) then
			return true
		end
	end

	return false
end

-- Decides if we want to weld the entity or not
function TOOL:IsAllowedEnt(ent)
	if IsValid(ent) then
		local ply = SERVER and self:GetOwner() or self.Owner
		local tr = ply:GetEyeTrace()
		tr.Entity = ent

		if (not hook.Run("CanTool", ply, tr, "smartweld")) or ((not self.AllowedBaseClasses[baseclass.Get(ent:GetClass()).Base]) and (not self.AllowedClasses[ent:GetClass()])) then
			return false
		end

		return true
	end
	
	return false
end

-- Puts one of those annoying notifications to the lower right of the screen
function TOOL:Notify(text, notifyType)
	if IsFirstTimePredicted() then
		if CLIENT and IsValid(self.Owner) then
			notification.AddLegacy(text, notifyType, 5)
			surface.PlaySound("buttons/button15.wav")
		elseif game.SinglePlayer() then
			self:GetOwner():SendLua("GAMEMODE:AddNotify(\""..text.."\", NOTIFY_GENERIC, 5)")	-- Because singleplayer is doodoo
			self:GetOwner():SendLua("surface.PlaySound(\"buttons/button15.wav\")")
		end
	end
end
