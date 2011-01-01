-- Prosody Wordpress UAM Group

local db = require 'luasql.mysql';

local groups;
local members;

local jid, datamanager = require "util.jid", require "util.datamanager";
local jid_bare, jid_prep = jid.bare, jid.prep;

local module_host = module:get_host();

local mysql_server = module:get_option("wordpress_mysql_host") or "localhost";
local mysql_port = module:get_option("wordpress_mysql_port") or 3306;
local mysql_database = module:get_option("wordpress_mysql_database") or "wordpress";
local mysql_username = module:get_option("wordpress_mysql_username") or "root";
local mysql_password = module:get_option("wordpress_mysql_password") or "";
local mysql_prefix = module:get_option("wordpress_mysql_prefix") or "wp_";

local env = assert(db.mysql());

function inject_roster_contacts(username, host, roster)
	--module:log("debug", "Injecting group members to roster");
	local bare_jid = username.."@"..host;
	if not members[bare_jid] and not members[false] then return; end -- Not a member of any groups
	
	local function import_jids_to_roster(group_name)
		for jid in pairs(groups[group_name]) do
			-- Add them to roster
			--module:log("debug", "processing jid %s in group %s", tostring(jid), tostring(group_name));
			if jid ~= bare_jid then
				if not roster[jid] then roster[jid] = {}; end
				roster[jid].subscription = "both";
				if groups[group_name][jid] then
					roster[jid].name = groups[group_name][jid];
				end
				if not roster[jid].groups then
					roster[jid].groups = { [group_name] = true };
				end
				roster[jid].groups[group_name] = true;
				roster[jid].persist = false;
			end
		end
	end

	-- Find groups this JID is a member of
	if members[bare_jid] then
		for _, group_name in ipairs(members[bare_jid]) do
			--module:log("debug", "Importing group %s", group_name);
			import_jids_to_roster(group_name);
		end
	end
	
	-- Import public groups
	if members[false] then
		for _, group_name in ipairs(members[false]) do
			--module:log("debug", "Importing group %s", group_name);
			import_jids_to_roster(group_name);
		end
	end
	
	if roster[false] then
		roster[false].version = true;
	end
end

function remove_virtual_contacts(username, host, datastore, data)
	if host == module_host and datastore == "roster" then
		local new_roster = {};
		for jid, contact in pairs(data) do
			if contact.persist ~= false then
				new_roster[jid] = contact;
			end
		end
		if new_roster[false] then
			new_roster[false].version = nil; -- Version is void
		end
		return username, host, datastore, new_roster;
	end

	return username, host, datastore, data;
end

function module.load()
  groups_wordpress_enable = module:get_option("wordpress_mysql_groups") or false;
  if not groups_wordpress_enable then return; end
	
	module:hook("roster-load", inject_roster_contacts);
	datamanager.add_callback(remove_virtual_contacts);
	
	groups = { default = {} };
	members = { };
	
	local connection = assert(env:connect(mysql_database, mysql_username, mysql_password, mysql_server, mysql_port));
	
	local query = string.format("select ID id, groupname name from %suam_accessgroups", mysql_prefix);
	local cursor = assert(connection:execute (query));
	
	-- Fetch groups
  local row = cursor:fetch({}, "a");
  while row do
    if not members[false] then
      members[false] = {};
    end
    members[false][#members[false] + 1] = row.name;
    groups[row.name] = {}
    
    module:log("debug", "New group: %s", tostring(row.name));
    
    -- Match user with group
    local group_query = string.format("select object_id from %suam_accessgroup_to_object where `group_id` = '%d'", mysql_prefix, row.id);
    local group_cursor = assert(connection:execute (group_query));
    
    local group_row = group_cursor:fetch({}, "a");
    while group_row do
      -- Fetch user information
      local user_query = string.format("select user_login, display_name from %susers where ID = '%d'", mysql_prefix, group_row.object_id);
      local user_cursor = assert(connection:execute (user_query));
      local user_row = user_cursor:fetch({}, "a");
      
      jid = string.format("%s@%s", user_row.user_login, module_host);
      groups[row.name][jid] = user_row.display_name or false;
      members[jid] = members[jid] or {};
      members[jid][#members[jid] + 1] = row.name;
      module:log("debug", "New member of %s: %s", row.name, jid);
      
      user_cursor:close();
      
      group_row = group_cursor:fetch(row, "a");
    end
    
    group_cursor:close();
    
    -- Fetch next group
    row = cursor:fetch(row, "a");
  end
  
  cursor:close();
  connection:close();
	
	module:log("info", "Groups loaded successfully");
end

function module.unload()
	datamanager.remove_callback(remove_virtual_contacts);
end
