--[[
Smart Weld
Created by: Stalkur (STEAM_0:1:18093014)		- Contact for support
Originally by Duncan Stead (Dunk)			- Dont contact for support
]]

TOOL.Category = "Constraints"
TOOL.Name = "Weld - Smart"
TOOL.ClientConVar["selectradius"] = 128
TOOL.ClientConVar["selectinsideradius"] = 0
TOOL.ClientConVar["nocollide"] = 1
TOOL.ClientConVar["freeze"] = 0
TOOL.ClientConVar["clearwelds"] = 1
TOOL.ClientConVar["strength"] = 0
TOOL.ClientConVar["world"] = 0
TOOL.ClientConVar["color_r"] = 0
TOOL.ClientConVar["color_g"] = 255
TOOL.ClientConVar["color_b"] = 0
TOOL.ClientConVar["color_a"] = 255

-- Add any classes for stuff you want to be smart weld-able
TOOL.allowedClasses = {
	"prop_physics",
	"prop_ragdoll"
}

-- Adds a slight delay between each individual weld. Useful for servers and high prop counts
-- NOT DONE YET! DOES NOTHING IN THIS VERSION!
local slowweld = false
local slowweld_delay = 1 -- The higher the number the less lag but will make the weld take longer and longer

if CLIENT then
	language.Add("tool.smartweld.name", "Weld - Smart")
	language.Add("tool.smartweld.desc", "Automatically welds selected props")
	language.Add("tool.smartweld.0", "Left-click to select/deselect props. Use key and left click to auto-select.")
	language.Add("tool.smartweld.1", "Right-click to weld selected props. Reload key to unselect all. Hold Use and right-click to weld everything to the prop you're looking at.")
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
	language.Add("tool.smartweld.color.help", "Modify the selection color to make the props look less idiotic")
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

--Clear stuff when you die or holster
function TOOL:Holster()
	if (CLIENT or game.SinglePlayer()) and self.selectedProps and #self.selectedProps ~= 0 then
		for i = 1, #self.selectedProps do
			if IsValid(self.selectedProps[i].ent) then
				self.selectedProps[i].ent:SetColor(self.selectedProps[i].col)
			end
		end

	end
	self.selectedProps = nil
	self:SetStage(1)
end

-- Does some validity checks then either selects or deselects the prop
function TOOL:LeftClick(tr)
	if IsFirstTimePredicted() then
		if not IsValid(tr.Entity) or tr.Entity:IsPlayer() then return false end
		if SERVER and not util.IsValidPhysicsObject(tr.Entity, tr.PhysicsBone) then return false end

		if not self.selectedProps then
			self.selectedProps = {}	-- This will be a useful shared table housing every selected prop, it's original color, and selected bone
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
	if not ent:IsValid() then return false end
	local outterSelectedProps = self:GetClientNumber("selectradius")

	local radiusProps = ents.FindInSphere(ent:GetPos(), outterSelectedProps)
	if #radiusProps < 1 then return false end

	local numNearProps = 0

	for k, v in pairs(radiusProps) do
		for i=1, #self.allowedClasses do
			if v:GetClass() == self.allowedClasses[i] then
				numNearProps = numNearProps + 1
			end
		end

		if #self.selectedProps == 0 or not self:PropHasBeenSelected(v) then
			self:SelectProp(v)
		end
	end

	self:Notify(numNearProps.." prop(s) have been auto-selected.", NOTIFY_GENERIC)
end

-- Decides if we should select it or deselect it
function TOOL:HandleProp(tr)
	if not tr.Entity:IsValid() then return false end

	if #self.selectedProps == 0 then
		self:SelectProp(tr.Entity)
	else
		for i = 1,  #self.selectedProps do
			if self.selectedProps[i].ent == tr.Entity then
				self:DeselectProp(tr.Entity, i)

				return true
			end
		end
		self:SelectProp(tr.Entity)
	end

	return true
end

-- Deselectes the chosen prop(s)
function TOOL:DeselectProp(ent, propTblPos)
	if SERVER then
		for k, v in pairs(self.selectedProps) do
			if self.selectedProps[k].ent == ent then
				table.remove(self.selectedProps, k)
			end
		end
	end

	if CLIENT or game.SinglePlayer() then
		ent:SetColor(self.selectedProps[propTblPos].col)
		table.remove(self.selectedProps, propTblPos)
	end

	return true
end

-- Does some tests then selects the prop. Adds to props table, objects table, and sets color
function TOOL:SelectProp(entity)
	if entity:IsPlayer() then return false end

	for i=1, #self.allowedClasses do
		if entity:GetClass() == self.allowedClasses[i] then
			if #self.selectedProps == 0 then
				self:SetStage(1)
			end

			table.insert(self.selectedProps, {
				ent = entity,
				col = entity:GetColor(),
				bone = 0
			})

			if CLIENT or game.SinglePlayer() then
				entity:SetColor(Color(self:GetClientNumber("color_r", 0), self:GetClientNumber("color_g", 0), self:GetClientNumber("color_b", 0), self:GetClientNumber("color_a", 255)))
			end
			return true
		end
	end
	return false
end

-- Pretty much deselects all
function TOOL:Reload()
	if IsFirstTimePredicted() and self.selectedProps then
		self:SetStage(1)

		if CLIENT or game.SinglePlayer() then
			for i = 1, #self.selectedProps do
				self.selectedProps[i].ent:SetColor(self.selectedProps[i].col)
			end
			self:Notify(#self.selectedProps.." prop(s) have been deselected.", NOTIFY_CLEANUP)
		end
		
		self.selectedProps = nil
	end
end

-- Handles the welding
function TOOL:RightClick(tr)
	if not self.selectedProps or #self.selectedProps == 0 then
		self:Notify("No props selected!", NOTIFY_GENERIC)
		return false
	elseif #self.selectedProps == 1 then
		self:Notify("Select at least one more prop to weld.", NOTIFY_GENERIC)
		return false
	end

	if SERVER then
		local weldForceLimit = tonumber(self:GetClientNumber("strength"))
		local weldToWorld = self:GetClientNumber("world")
		local freezeProps = self:GetClientNumber("freeze")
		local removeOldWelds = self:GetClientNumber("clearwelds")
		local nocollide = tobool(self:GetClientNumber("nocollide"))

		undo.Create("smartweld")

		-- Refresh welds has to be in its own loop otherwise it will delete the new welds as it goes
		-- Will freeze all the props if that option is enabled
		for i = 1, #self.selectedProps do	
			if removeOldWelds == 1 then
				local propsconstraints = constraint.FindConstraints(self.selectedProps[i].ent, "Weld")

				if propsconstraints then
					for i = 1, #propsconstraints do
						propsconstraints[i].Constraint:Remove()
					end
				end
			end

			if freezeProps == 1 then
				if self.selectedProps[i].ent:IsValid() then
					local propPhys = self.selectedProps[i].ent:GetPhysicsObject()
					propPhys:EnableMotion(false)
					propPhys:Sleep()
					self:GetOwner():AddFrozenPhysicsObject(self.selectedProps[i].ent, propPhys)
				end
			end
		end

		if weldToWorld == 1 then
			for i = 1, #self.selectedProps do
				local weld = constraint.Weld(self.selectedProps[i].ent, game.GetWorld(), 0, 0, weldForceLimit, false, false)
				undo.AddEntity(weld)
			end
		elseif self:GetOwner():KeyDown(IN_USE) then 	-- Weld all to one
			for i = 1, #self.selectedProps do
				print(i)
				local weld = constraint.Weld(self.selectedProps[i].ent, tr.Entity, self.selectedProps[i].bone, tr.PhysicsBone, weldForceLimit, nocollide, false)
				undo.AddEntity(weld)
			end
		elseif #self.selectedProps < 128 then 	-- They want to do a normal weld but if it's more than 127 props we have to chunk it
			for i = 1, #self.selectedProps do	-- Normal Weld
				for otherProps = 1, #self.selectedProps do
					if i ~= otherProps and i ~= #self.selectedProps then
						if not IsValid(self.selectedProps[i].ent) or not IsValid(self.selectedProps[otherProps].ent) then continue end
						local weld = constraint.Weld(self.selectedProps[i].ent, self.selectedProps[otherProps].ent, self.selectedProps[i].bone, self.selectedProps[otherProps].bone, 0, nocollide, false)
						undo.AddEntity(weld)
					end
				end
			end
		else 	-- A normal weld that is done in a different way since it is with more than 127 props
			for i = 1, #self.selectedProps do
				if i == #self.selectedProps then
					break
				end

				local weld = constraint.Weld(self.selectedProps[i].ent, self.selectedProps[i+1].ent, self.selectedProps[i].bone, self.selectedProps[i+1].bone, 0, nocollide, false)
				undo.AddEntity(weld)
			end
		end

		undo.SetPlayer(self:GetOwner())
		undo.Finish()
	end

	self:FinishWelding()
	return false
end

function TOOL:FinishWelding()
	if CLIENT or game.SinglePlayer() then
		local numProps = 0

		for i = 1, #self.selectedProps do
			if IsValid(self.selectedProps[i].ent) then
				self.selectedProps[i].ent:SetColor(self.selectedProps[i].col)
				numProps = numProps + 1
			end
		end

		if self:GetOwner():KeyDown(IN_USE) then	-- If they chose to weld all to one prop this will correct the count
			numProps = numProps + 1
		end

		self:Notify("Weld complete! "..numProps.." props welded.", NOTIFY_GENERIC)
		print("You succesfully welded ".. numProps.." props.")
	end
	if SERVER then print(self:GetOwner():Nick().." ("..self:GetOwner():SteamID()..") succesfully welded "..#self.selectedProps.." props.") end
	self.selectedProps = nil
	self:SetStage(1)
end

-- Checks if a prop has already been selected
function TOOL:PropHasBeenSelected(ent)
	for i, v in ipairs(self.selectedProps) do
		if ent == self.selectedProps[i].ent then
			return true
		end
	end
	return false
end

-- Puts one of those annoying notifications to the lower right of the screen
function TOOL:Notify(text, notifyType)
	if game.SinglePlayer() then
		self:GetOwner():SendLua("GAMEMODE:AddNotify(\""..text.."\", NOTIFY_GENERIC, 5)")	-- Because singleplayer is doodoo
		self:GetOwner():SendLua("surface.PlaySound(\"buttons/button15.wav\")")
	else
		if not IsValid(self.Owner) or self.Owner ~= LocalPlayer() then return end
		if IsFirstTimePredicted() then
			notification.AddLegacy(text, notifyType, 5)
		end
	end
end
