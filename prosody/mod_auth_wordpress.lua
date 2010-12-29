-- Prosody Wordpress Authentication

local datamanager = require "util.datamanager";
local md5 = require "md5";
local new_sasl = require "util.sasl".new;
local nodeprep = require "util.encodings".stringprep.nodeprep;
local log = require "util.logger".init("auth_wordpress");
local db = require 'luasql.mysql'

local hosts = hosts;

local mysql_server = module:get_option("wordpress_mysql_host") or "localhost";
local mysql_port = module:get_option("wordpress_mysql_port") or 3306;
local mysql_database = module:get_option("wordpress_mysql_database") or "wordpress";
local mysql_username = module:get_option("wordpress_mysql_username") or "root";
local mysql_password = module:get_option("wordpress_mysql_password") or "";
local mysql_prefix = module:get_option("wordpress_mysql_prefix") or "wp_";

local env = assert(db.mysql())

function new_wordpress_provider(host)
	local provider = { name = "wordpress" };
	log("debug", "initializing wordpress authentication provider for host '%s'", host);

	function provider.test_password(username, password)
    local pass = false;
    local query = string.format("select user_pass from %susers where `user_login` = '%s'", mysql_prefix, username);
    local connection = assert(env:connect(mysql_database, mysql_username, mysql_password, mysql_server, mysql_port));
    local cursor = assert (connection:execute (query));
    if cursor:numrows() > 0 then
      user_pass = cursor:fetch();
      md5_pass = md5.sumhexa(password)
      
      pass = md5_pass == user_pass;
    end
		
		cursor:close();
		connection:close();
		
		if pass then
			return true;
		else
			return nil, "Auth failed. Invalid username or password.";
		end
		
	end

	function provider.get_password(username) return nil, "Password unavailable for Wordpress."; end
	function provider.set_password(username, password) return nil, "Password unavailable for Wordpress.";	end
  function provider.create_user(username, password) return nil, "Account creation/modification not available with Wordpress.";	end

	function provider.user_exists(username)
	  log("debug", "Exists %s", username);
	  local pass = false;
	  local query  = string.format("select id from %susers where `user_login` = '%s'", prefix, username);
	  local connection = assert(env:connect(mysql_database, mysql_username, mysql_password, mysql_server, mysql_port));
    local cursor = assert (connection:execute (query));
    if cursor:numrows() > 0 then
      pass = true;
    end
    
    cursor:close();
    connection:close();
	  
		if not pass then
			log("debug", "Account not found for username '%s' at host '%s'", username, module.host);
			return nil, "Auth failed. Invalid username";
		end
		return true;
	end

	function provider.get_sasl_handler()
	  local realm = module:get_option("sasl_realm") or module.host;
	  
	  local realm = module:get_option("sasl_realm") or module.host;
		local testpass_authentication_profile = {
			plain_test = function(sasl, username, password, realm)
				local prepped_username = nodeprep(username);
				if not prepped_username then
					log("debug", "NODEprep failed on username: %s", username);
					return "", nil;
				end
				return provider.test_password(prepped_username, password), true;
			end
		};
		return new_sasl(realm, testpass_authentication_profile);
	  
	end
	
	return provider;
end

module:add_item("auth-provider", new_wordpress_provider(module.host));

