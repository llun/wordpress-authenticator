"""
Wordpress MySQL based user directory service implementation.
"""

__all__ = [
    "WordpressMySQLDirectoryService",
    "WordpressMySQLDirectoryRecord",
]

import xmlrpclib, urllib, uuid, MySQLdb, hashlib

from urlparse import urlparse
from twisted.cred.credentials import UsernamePassword
from twisted.web2.auth.digest import DigestedCredentials

from twistedcaldav.directory.directory import DirectoryService, DirectoryRecord

class WordpressMySQLDirectoryService(DirectoryService):
  """
  Wordpress MySQL based implementation of L{IDirectoryService}.
  """
  baseGUID = "9CA8DEC5-5A17-43A9-84A8-BE77C1FB9172"

  realmName = "Wordpress service"
  
  cache = dict()

  def __init__(self, params):
    super(WordpressMySQLDirectoryService, self).__init__()
    
    defaults = {
      'host' : 'localhost',
      'username' : 'calendar', 
      'password' : 'password',
      'database' : 'database',
      'prefix' : 'wp_',
    }
    ignored = None
    params = self.getParams(params, defaults, ignored)
    
    host = params.get("host")
    username = params.get("username")
    password = params.get("password")
    database = params.get("database")
    prefix = params.get("prefix")

    self._prefix = prefix
    self._conn = MySQLdb.connect(host = host,
                                 user = username,
                                 passwd = password,
                                 db = database)

  def authenticate(self, username, password):
    try:
      self._proxy.wp.getUsersBlogs(username, password)
      return True
    except:
      return False

  def recordTypes(self):
    recordTypes = (
      DirectoryService.recordType_users,
    )
    return recordTypes

  def listRecords(self, recordType):
    records = []

    prefix = self._prefix

    query = "select ID, user_login, user_nicename, user_email, user_pass from %(table)s"%{"table": prefix + "users"}
    cursor = self._conn.cursor()
    cursor.execute (query)
    
    rows = cursor.fetchall()
    cursor.close()
    
    for row in rows:
      user_id = row[0]
      user_login = row[1]
      user_nick = row[2]
      user_mail = row[3]
      user_pass = row[4]
      
      #Fetch user first name and last name
      query = "select meta_value from %(table)s \
               where `meta_key` = 'first_name' \
               and `user_id` = %(user_id)d"%{"table": prefix + "usermeta", "user_id": user_id}
      cursor = self._conn.cursor()
      cursor.execute (query)
      
      user_firstname = cursor.fetchone()
      cursor.close()
      
      query = "select meta_value from %(table)s \
               where `meta_key` = 'last_name' \
               and `user_id` = %(user_id)d"%{"table": prefix + "usermeta", "user_id": user_id}
      cursor = self._conn.cursor()
      cursor.execute (query)
      
      user_lastname = cursor.fetchone()
      cursor.close()
      
      user_fullname = ""
      firstname = ""
      lastname = ""
      
      if user_firstname is not None:
        firstname = user_firstname[0]
        lastname = user_lastname[0]
        
        user_fullname = "%s %s"%(firstname, lastname)
      else:
        user_fullname = user_login
      
      record = WordpressMySQLDirectoryRecord(service = self,
                                             recordType = recordType,
                                             guid = str(uuid.uuid5(uuid.NAMESPACE_OID, str(user_id))),
                                             shortNames = (user_login, ),
                                             email = "mailto:%s"%user_mail,
                                             password = user_pass,
                                             firstname = firstname,
                                             lastname = lastname,
                                             fullname = user_fullname)
      self.cache[user_login] = record
      records.append(record)
    
    return records
      
  def recordWithShortName(self, recordType, shortName):
    if len(self.cache) < 1:
      self.listRecords(recordType)
    
    try:
      return self.cache[shortName]
    except:
      return None

class WordpressMySQLDirectoryRecord(DirectoryRecord):
  """
  Wordpress MySQL based implementation implementation of L{IDirectoryRecord}.
  """
  def __init__(self, service, recordType, guid, 
               shortNames, email, password, 
               firstname = None, lastname = None, fullname = None):
    super(WordpressMySQLDirectoryRecord, self).__init__(
        service               = service,
        recordType            = recordType,
        guid                  = guid,
        shortNames            = shortNames,
        calendarUserAddresses = (email, ),
        firstName             = firstname,
        lastName              = lastname,
        fullName              = fullname,
    )
    
    self._service = service
    self._password = password

  def members(self):
    return []

  def groups(self):
    return []
    
  def verifyCredentials(self, credentials):
    if isinstance(credentials, UsernamePassword):
      m = hashlib.md5()
      m.update(credentials.password)
      input_password = m.hexdigest()
      return self._password == input_password

    return super(WordpressMySQLDirectoryRecord, self).verifyCredentials(credentials)
    