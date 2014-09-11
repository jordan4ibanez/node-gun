--[[
Released under GPL

]]--

node_gun_users = {}
minetest.register_tool("node_gun:node_gun", {
	description = "Node Gun",
	inventory_image = "node_gun.png",
	on_place = function(itemstack, placer, pointed_thing)
		local node = minetest.env:get_node(pointed_thing.under).name
		--stop people from picking up air
		if node == "air" then
			return
		end
		--stop players from picking up more than one node
		if node_gun_users[placer:get_player_name()] == true then
			return
		end
		node_gun_users[placer:get_player_name()] = true
		minetest.env:remove_node(pointed_thing.under)
		nodeupdate(pointed_thing.under)
		node_gun_spawn_falling_node(pointed_thing.under, node, placer:get_player_name())
		minetest.sound_play("node_gun_on", {pos = pointed_thing.under,gain = 1.0,max_hear_distance = 15,})
	end,
})
function node_gun_spawn_falling_node(p, nodename, player)
	obj = minetest.env:add_entity(p, "node_gun:falling_node")
	obj:get_luaentity():set_node(nodename)
	obj:get_luaentity():set_owner(player)
end

minetest.register_entity("node_gun:falling_node", {
	initial_properties = {
		physical = false,
		collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
		visual = "wielditem",
		textures = {},
		visual_size = {x=0.667, y=0.667},
		--owner = nil,
	},

	nodename = "",

	set_node = function(self, nodename)
		self.nodename = nodename
		local stack = ItemStack(nodename)
		local itemtable = stack:to_table()
		local itemname = nil
		if itemtable then
			itemname = stack:to_table().name
		end
		local item_texture = nil
		local item_type = ""
		if minetest.registered_items[itemname] then
			item_texture = minetest.registered_items[itemname].inventory_image
			item_type = minetest.registered_items[itemname].type
		end
		prop = {
			is_visible = true,
			textures = {nodename},
		}
		self.object:set_properties(prop)
	end,
	set_owner = function(self, player)
		self.owner = player
	end,
	get_staticdata = function(self)
		return self.nodename
	end,

	on_activate = function(self, staticdata)
		self.nodename = staticdata
		self.object:set_armor_groups({immortal=1})
		--self.object:setacceleration({x=0, y=-10, z=0})
		self:set_node(self.nodename)
	end,
	on_rightclick = function(self, clicker)
		if clicker:get_player_name() == self.owner then
			local pos = self.object:getpos()
			minetest.sound_play("node_gun_off", {pos = pos,gain = 1.0,max_hear_distance = 15,})
			local playerpos = minetest.env:get_player_by_name(self.owner):getpos()
			local x = (pos.x - playerpos.x) * 10
			local y = (pos.y - (playerpos.y + 1.5)) * 10
			local z = (pos.z - playerpos.z) * 10
			self.object:setvelocity({x=x,y=y,z=z})
			node_gun_users[self.owner] = nil
			self.owner = nil
		elseif self.owner == nil then
			node_gun_users[clicker:get_player_name()] = true
			self.owner = clicker:get_player_name()
			self.object:setacceleration({x=0, y=0, z=0})
			self.object:setvelocity({x=0, y=0, z=0})
			self.object:set_properties({physical = false})
			minetest.sound_play("node_gun_on", {pos = self.object:getpos(),gain = 1.0,max_hear_distance = 15,})
		end
			
	end,
		

	on_step = function(self, dtime)
		if self.owner ~= nil then
			if not minetest.env:get_player_by_name(self.owner):is_player() then
				node_gun_users[self.owner] = nil
				self.owner = nil
			end
		end
		if self.owner ~= nil then
			local player = minetest.env:get_player_by_name(self.owner)
			local dir = player:get_look_dir()
			if player:get_wielded_item():to_string() ~= "" then
				if player:get_wielded_item():to_table().name ~= "node_gun:node_gun" then
					node_gun_users[self.owner] = nil
					self.owner = nil
				end
			else
				node_gun_users[self.owner] = nil
				self.owner = nil
			end
			if dir ~= nil then
				local playerpos = player:getpos()
				local x = playerpos.x + (dir.x * 2)
				local y = (playerpos.y+1.5) + (dir.y * 2)
				local z = playerpos.z + (dir.z * 2)
				self.object:setpos({x=x,y=y,z=z})
				--[[
				pos = self.object:getpos()
				playerpos.y = playerpos.y + 1.5
				local x = (pos.x - playerpos.x) * 2
				local y = (pos.y - playerpos.y) * 2
				local z = (pos.z - playerpos.z) * 2
				minetest.add_particle(playerpos, {x=x,y=y,z=z}, {x=0,y=0,z=0}, 1,5, false, "tnt_smoke.png")
				]]--
			end
		end
		-- Set gravity
		if self.owner == nil then
			self.object:setacceleration({x=0, y=-10, z=0})
			self.object:set_properties({physical = true})
		end
		-- Turn to actual sand when collides to ground or just move
		local pos = self.object:getpos()
		local bcp = {x=pos.x, y=pos.y-0.7, z=pos.z} -- Position of bottom center point
		local bcn = minetest.env:get_node(bcp)
		-- Note: walkable is in the node definition, not in item groups
		if minetest.registered_nodes[bcn.name] and
				minetest.registered_nodes[bcn.name].walkable and self.owner == nil then
			if minetest.registered_nodes[bcn.name].buildable_to then
				minetest.env:remove_node(bcp)
				return
			end
			local np = {x=bcp.x, y=bcp.y+1, z=bcp.z}
			-- Check what's here
			local n2 = minetest.env:get_node(np)
			-- If it's not air or liquid, remove node and replace it with
			-- it's drops
			if n2.name ~= "air" and (not minetest.registered_nodes[n2.name] or
					minetest.registered_nodes[n2.name].liquidtype == "none") then
				local drops = minetest.get_node_drops(n2.name, "")
				minetest.env:remove_node(np)
				-- Add dropped items
				local _, dropped_item
				for _, dropped_item in ipairs(drops) do
					minetest.env:add_item(np, dropped_item)
				end
				-- Run script hook
				local _, callback
				for _, callback in ipairs(minetest.registered_on_dignodes) do
					callback(np, n2, nil)
				end
			end
			-- Create node and remove entity
			--if it's tnt BLOW STUFF UP!
			if self.nodename == "tnt:tnt" then
				local tnt = minetest.env:add_entity(np, "tnt:tnt")
				tnt:get_luaentity().timer = 10
			else
				minetest.env:add_node(np, {name=self.nodename})
			end
			self.object:remove()
			nodeupdate(np)
		else
			-- Do nothing
		end
	end
})