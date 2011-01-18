import os,sys,xmpp

currentUser = None
xmppClient = None
nicks = {}

###### Bot Command
def commandNick():
  pass
  
def commandHelp(client, user):
  message = """
  !help - See this menu.
  !nick <new name> - Change nick name.
  """
  client.send(xmpp.Message(user, message))

###### Bot Logic
def parseCommand(client, user, message):
  if message == '!help':
    commandHelp(client, user)
    return True
    
  return False
  
def messageCB(client, message):
  text = message.getBody()
  user = message.getFrom()
  
  if not parseCommand(client, user, text):
    if text is not None:
      roster = xmppClient.getRoster()
      items = roster.getItems()
      for item in items:
        jid = xmpp.JID(user)
        itemJID = xmpp.JID(item)
        
        sender = jid.getNode()
        receiver = itemJID.getNode()
        if item <> currentUser and receiver <> sender:
          message = "%s: %s"%(jid.getNode(), text)
          client.send(xmpp.Message(item, message))
  
###### Bot initial process
def stepOn(client):
  try:
    client.Process(1)
  except KeyboardInterrupt:
    return 0
  return 1
  
def goOn(client):
  while stepOn(client):
    pass

if len(sys.argv) < 3:
  print "Usage: xrepeat.py username@server.net password"
else:
  jid = xmpp.JID(sys.argv[1])
  user, server, password = jid.getNode(), jid.getDomain(), sys.argv[2]
  currentUser = sys.argv[1]
  
  xmppClient = xmpp.Client(server, debug = [])
  connectionResource = xmppClient.connect()
  if not connectionResource:
    print "Unable to connect to server %s!"%server
    sys.exit(1)
  if connectionResource <> 'tls':
    print "Warning: unable to establish secure connection - TLS failed!"
  
  authorizedResource = xmppClient.auth(user, password)
  if not authorizedResource:
    print "Unable to autorize on %s - check login/password."%server
    sys.exit(1)
  if authorizedResource <> 'sasl':
    print "Warning: unable to perform SASL auth os %s. Old authentication method used!"%server
  
  xmppClient.RegisterHandler('message', messageCB)
  xmppClient.sendInitPresence()
  print "Repeat bot started"
  
  goOn(xmppClient)

