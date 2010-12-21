import os

from twisted.python.filepath import FilePath
from twisted.internet.defer import inlineCallbacks

from twistedcaldav.directory.calendaruserproxy import CalendarUserProxyDatabase
from twistedcaldav.directory.directory import DirectoryService
import twistedcaldav.directory.test.util
from twistedcaldav.directory.resourceinfo import ResourceInfoDatabase
from twistedcaldav.directory.wordpressmysql import WordpressMySQLDirectoryService
from twistedcaldav.config import config

class WordpressMySQLDirectory(
twistedcaldav.directory.test.util.BasicTestCase,
twistedcaldav.directory.test.util.DigestTestCase
):

  recordTypes = set((
    DirectoryService.recordType_users,
  ))
  
  users = {
    "admin" : { "password": "password", "guid": "996ad860-2a9a-504f-8861-aeafd0b2ae29", "addresses": ("mailto:admin@wordpress.com", ) },
  }
  
  locations = {}

  def service(self):
    return WordpressMySQLDirectoryService({'host' : 'localhost', 'username' : 'calendar', 'password' : 'password', 'database' : 'wordpress', 'prefix' : 'wp_' })
    
  def test_service(self):
    self.service().listRecords(DirectoryService.recordType_users)
    