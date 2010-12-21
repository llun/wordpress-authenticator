"""
Wordpress based user directory service implementation.
"""

__all__ = [
    "WordpressDirectoryService",
    "WordpressDirectoryRecord",
]

import xmlrpclib, urllib, uuid

from urlparse import urlparse
from twisted.cred.credentials import UsernamePassword
from twisted.web2.auth.digest import DigestedCredentials

from twistedcaldav.directory.directory import DirectoryService, DirectoryRecord

class WordpressDirectoryService(DirectoryService):
  """
  Wordpress based implementation of L{IDirectoryService}.
  """
  baseGUID = "9CA8DEC5-5A17-43A9-84A8-BE77C1FB9172"

  realmName = "Wordpress service"
  
  cache = dict()

  def __init__(self, params):
    super(WordpressDirectoryService, self).__init__()
    
    defaults = {
      'url' : 'http://localhost/xmlrpc.php', 
      'username' : 'admin', 
      'password': 'password'
    }
    ignored = None
    params = self.getParams(params, defaults, ignored)
    
    url = params.get("url")
    username = params.get("username")
    password = params.get("password")
    
    self._proxy = xmlrpclib.ServerProxy(url)
    self._username = username
    self._password = password
    self._domain = urlparse(url).netloc

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
    try:
      records = []
      authors = self._proxy.wp.getAuthors(0, self._username, self._password)
      for author in authors:
        try:
          record = self.cache[author['user_login']]
        except KeyError, err:
          record = WordpressDirectoryRecord(
            service = self,
            recordType = recordType,
            guid = str(uuid.uuid5(uuid.NAMESPACE_OID, author['user_id'])),
            shortNames = (author['user_login'], ),
            email = 'mailto:%(name)s@%(domain)s'%{'name': author['user_login'], 'domain': self._domain},
          )
          self.cache[author['user_login']] = record
        
        records.append(record)
        
      return records
    except xmlrpclib.Fault, err:
      return []
      
  def recordWithShortName(self, recordType, shortName):
    if len(self.cache) < 1:
      self.listRecords(recordType)
    
    try:
      return self.cache[shortName]
    except:
      return None

class WordpressDirectoryRecord(DirectoryRecord):
  """
  Wordpress based implementation implementation of L{IDirectoryRecord}.
  """
  def __init__(self, service, recordType, guid, shortNames, email):
    super(WordpressDirectoryRecord, self).__init__(
        service               = service,
        recordType            = recordType,
        guid                  = guid,
        shortNames            = shortNames,
        calendarUserAddresses = set(email),
    )
    
    self._service = service

  def members(self):
    return []

  def groups(self):
    return []
    
  def verifyCredentials(self, credentials):
    if isinstance(credentials, UsernamePassword):
      return self._service.authenticate(credentials.username, credentials.password)

    return super(WordpressDirectoryRecord, self).verifyCredentials(credentials)
