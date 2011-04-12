-- Prosody Wordpress UAM Group

local rostermanager = require "core.rostermanager";
local datamanager = require "util.datamanager";
local jid = require "util.jid";

local DBI;
local connection;

local bare_sessions = bare_sessions;

local params = module:get_option("wordpress");
local module_host = module:get_host();

function load_contacts()
  local groups = { default = {} };
  local members = { };

  local load_groups_sql = string.format("select ID id, groupname name from %suam_accessgroups", params.prefix);
  local load_groups_stmt = connection:prepare(load_groups_sql);
  
  if load_groups_stmt then
    load_groups_stmt:execute();
    
    -- Fetch groups
    for group_row in load_groups_stmt:rows(true) do
      groups[group_row.name] = {};
      module:log("debug", "New group: %s", tostring(group_row.name));
      
      -- Match user with group
      local object_id_sql = string.format("select object_id from %suam_accessgroup_to_object where `group_id` = ?;", params.prefix);
      local object_id_stmt = connection:prepare(object_id_sql);
      
      if object_id_stmt then
        object_id_stmt:execute(group_row.id);
        
        for object_row in object_id_stmt:rows(true) do
          -- Fetch user information
          local user_sql = string.format("select user_login, display_name from %susers where `ID` = ?;", params.prefix);
          local user_stmt = connection:prepare(user_sql);
          
          if user_stmt then
            user_stmt:execute(object_row.object_id);
            if user_stmt:rowcount() > 0 then
              local user_row = user_stmt:fetch(true);
              
              bare_jid = string.format("%s@%s", user_row.user_login, module_host);
              groups[group_row.name][bare_jid] = user_row.display_name or false;
              members[bare_jid] = members[bare_jid] or {};
              members[bare_jid][#members[bare_jid] + 1] = group_row.name;
              module:log("debug", "New member of %s: %s", group_row.name, bare_jid);
            end
            
            user_stmt:close();
          end
          
        end
        
        object_id_stmt:close();
      end
      
    end
    
    load_groups_stmt:close();
  end

  module:log("info", "Groups loaded successfully");
  
  return groups, members;
end

function inject_roster_contacts(username, host, roster)
  local groups, members = load_contacts();
  
  local user_jid = username.."@"..host;
  module:log("debug", "Injecting group members to roster %s", user_jid);
  if not members[user_jid] and not members[false] then return; end -- Not a member of any groups
  
  local function import_jids_to_roster(group_name, groups)
    for member_jid in pairs(groups[group_name]) do
      -- Add them to roster
      module:log("debug", "processing jid %s in group %s", tostring(member_jid), tostring(group_name));
      if member_jid ~= user_jid then
        if not roster[member_jid] then roster[member_jid] = {}; end
        roster[member_jid].subscription = "both";
        if groups[group_name][member_jid] then
          roster[member_jid].name = groups[group_name][member_jid];
        end
        if not roster[member_jid].groups then
          roster[member_jid].groups = { [group_name] = true };
        end
        roster[member_jid].groups[group_name] = true;
        roster[member_jid].persist = false;
      end
    end
  end

  -- Find groups this JID is a member of
  if members[user_jid] then
    for _, group_name in ipairs(members[user_jid]) do
      module:log("debug", "Importing group %s", group_name);
      import_jids_to_roster(group_name, groups);
    end
  end
  
  -- Import public groups
  if members[false] then
    for _, group_name in ipairs(members[false]) do
      module:log("debug", "Importing group %s", group_name);
      import_jids_to_roster(group_name, groups);
    end
  end
  
  for online_jid, user in pairs(bare_sessions) do
    if (online_jid ~= user_jid) and roster[online_jid] then
      local other_roster = user.roster;
      if not other_roster[user_jid] then
        local node, host, resource = jid.split(user_jid);
        module:log("debug", "push %s to %s@%s", online_jid, node, host);
        
        rostermanager.roster_push(node, host, online_jid);
      end
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
  if params == nil then
    -- Don't load this module to virtual host doesn't have wordpress option
    return;
  end;
  
  initial_connection();
  groups_wordpress_enable = params.groups
  if not groups_wordpress_enable then return; end
  
  module:hook("roster-load", inject_roster_contacts);
  datamanager.add_callback(remove_virtual_contacts);
end

function module.unload()
  datamanager.remove_callback(remove_virtual_contacts);
end

-- database methods from mod_storage_sql.lua
local function test_connection()
	if not connection then return nil; end
	if connection:ping() then
		return true;
	else
		module:log("debug", "Database connection closed");
		connection = nil;
	end
end

local function connect()
	if not test_connection() then
		prosody.unlock_globals();
		local dbh, err = DBI.Connect(
			"MySQL", params.database,
			params.username, params.password,
			params.host, params.port
		);
		prosody.lock_globals();
		if not dbh then
			module:log("debug", "Database connection failed: %s", tostring(err));
			return nil, err;
		end
		module:log("debug", "Successfully connected to database");
		dbh:autocommit(false); -- don't commit automatically
		connection = dbh;
		return connection;
	end
end

function initial_connection()
  local ok;
	prosody.unlock_globals();
	ok, DBI = pcall(require, "DBI");
	if not ok then
		package.loaded["DBI"] = {};
		module:log("error", "Failed to load the LuaDBI library for accessing SQL databases: %s", DBI);
		module:log("error", "More information on installing LuaDBI can be found at http://prosody.im/doc/depends#luadbi");
	end
	prosody.lock_globals();
	if not ok or not DBI.Connect then
		return; -- Halt loading of this module
	end
	
	params.host = params.host or "localhost";
	params.port = params.port or 3306;
	params.database = params.database or "wordpress";
	params.username = params.username or "root";
	params.password = params.password or "";
	params.prefix = params.prefix or "wp_";
	params.groups = params.groups or false;
	
	assert(connect());
end
