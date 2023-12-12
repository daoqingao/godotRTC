extends Control

@onready var client = $Client
@onready var host = $VBoxContainer/Connect/Host
@onready var room = $VBoxContainer/Connect/RoomSecret
@onready var mesh = $VBoxContainer/Connect/Mesh


var finalizedPeerPlayers={}
func _ready():
	#if(OS.get_name()=="Android"):
		#host.text = "ws://150.136.243.59:7000"
	#if(OS.get_name()=="Windows"):
		#host.text = "ws://localhost:7000"
	print(OS.get_name())
	#signalingServer
	client.log.connect(self._log)
	#all of these 4 signals are just logs. bruh
	# client.lobby_joined.connect(self._lobby_joined)
	# client.lobby_sealed.connect(self._lobby_sealed)
	# client.connected.connect(self._connected)
	# client.disconnected.connect(self._disconnected)

	#rtc
	multiplayer.connected_to_server.connect(self.peerAsClientConnectedPeerAsServer)
	multiplayer.connection_failed.connect(self.peerAsClientDisconnectedPeerAsServer)
	multiplayer.server_disconnected.connect(self.peerAsClientDisconnectedPeerAsServer)
	
	#rtc host and client
	multiplayer.peer_connected.connect(self.ServerPeerConnectedByPeer)
	multiplayer.peer_disconnected.connect(self.ServerPeerDisonnectedByPeer)


@rpc("any_peer", "call_local")
func ping(argument):
	# _log("[PeerRTC] Ping from peer %d: arg: %s" % [multiplayer.get_remote_sender_id(), argument])
	_log(str(finalizedPeerPlayers))

@rpc("any_peer", "call_local")
func propagateDataFromHost(data):
	Gamedata.peerPlayers = data
	Gamedata.playerId = multiplayer.get_unique_id()
	Gamedata.startGame("RPS")
	_log("requested to propagate data from host")
	_log(str(finalizedPeerPlayers))



func peerAsClientConnectedPeerAsServer():
	_log("[PeerRTC] (I am %d) connectd to another peer server" % client.rtc_mp.get_unique_id())
func peerAsClientDisconnectedPeerAsServer():
	_log("[PeerRTC] (I am %d) disconnectd to another peer server" % client.rtc_mp.get_unique_id())
#rtc server host peer of (1), gets all of these messages. and these as usualy shoul
func ServerPeerConnectedByPeer(id: int):
	_log("[PeerRTC] Server/Receiver: %d connected" % id)
func ServerPeerDisonnectedByPeer(id: int):
	_log("[PeerRTC] Server/Receiver: %d disconnected" % id)

func _log(msg):
	print(msg)
	$VBoxContainer/TextEdit.text += str(msg) + "\n"

func _on_peers_pressed():
	_log(multiplayer.get_peers())
	
func _on_ping_pressed():
	ping.rpc(randf())

func _on_seal_pressed():
	client.handlePlayerClickSealLobby_AskServerToSeal()
	for peer in multiplayer.get_peers():
		finalizedPeerPlayers[peer] = {
			peerId=peer #the struct of the player obj
			}
	finalizedPeerPlayers[multiplayer.get_unique_id()] = {peerId=multiplayer.get_unique_id()}
	propagateDataFromHost.rpc(finalizedPeerPlayers)
	
	
func _on_start_pressed():
	client.handlePlayerClickedStart_ConnectToSignalServer(host.text, room.text, mesh.button_pressed)
func _on_stop_pressed():
	client.handlePlayerClickedStopConnections_CloseAllConnection()
