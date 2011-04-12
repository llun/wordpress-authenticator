#Wordpress

Before use authenticator, user must install md5 plugins to wordpress.

#Prosody

##Require library

 1. LuaDBI with MySQL.
 2. Wordpress must install MD5 Password Hashes.

##How to use

 1. Copy mod_auth_wordpress.lua to prosody plugins folder.
 2. Add authentication to VirtualHost and change mysql configuration to wordpress database.
 
        VirtualHost "sample.com"
          authentication = "wordpress";
          wordpress = {
            host = "localhost";
            port = 3306;
            database = "wordpress";
            username = "username";
            password = "password";
            prefix = "wp_";
          };
          
   2.1 If you want to use groups with Wordpress UAM Plugins, enable wordpress_mysql_groups in VirtualHost.
   
      VirtualHost "sample.com"
        wordpress = {
          ...
          groups = true;
        }
        
  3. Restart prosody.
     

#Darwin Calendar Server

##How to use

 1. Copy wordpress.py and wordpressmysql.py to twistedcaldav/directory directory in calendar server library directory.
 2. Add wordpress directory service in caldavd.plist like below. 
 
        <!-- WordPress MySQL Directory Service -->
        <key>DirectoryService</key>
        <dict>
          <key>type</key>
          <string>twistedcaldav.directory.wordpressmysql.WordpressMySQLDirectoryService</string>

          <key>params</key>
          <dict>
            <key>host</key>
            <string>localhost</string>

            <key>username</key>
            <string>wordpress_mysql_username</string>

            <key>password</key>
            <string>wordpress_mysql_password</string>

            <key>database</key>
            <string>wordpress_database</string>

            <key>prefix</key>
            <string>wp_</string>
          </dict>
        </dict>
        
 3. Restart calendar server.

##How to test

 1. Copy wordpress*.py and test/test_wordpress*.py to CalendarServer-2.4/twistedcaldav/directory
 2. Run ./test twistedcaldav.directory.test.test_wordpressdirectory or twistedcaldav.directory.test.test_wordpressmysqldirectory

