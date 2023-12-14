extends Control

@onready var SignalRTCServer = $SignalRTCServer
@onready var host = $VBoxContainer/Connect/Host
@onready var room = $VBoxContainer/Connect/RoomSecret
@onready var mesh = $VBoxContainer/Connect/Mesh


var finalizedPeerPlayers={}
func _ready():
	if(OS.is_debug_build() && true):
		print("starting in debug/dev mode, connecting to localhost signal server")
		host.text = "ws://localhost:7000"
	else:
		host.text = "ws://150.136.243.59:7000"
		room.text = ""
	
	SignalRTCServer.log.connect(_log)

	#rtc
	multiplayer.connected_to_server.connect(self.peerAsClientConnectedPeerAsServer)
	multiplayer.connection_failed.connect(self.peerAsClientDisconnectedPeerAsServer)
	multiplayer.server_disconnected.connect(self.peerAsClientDisconnectedPeerAsServer)
	
	#rtc host and SignalRTCServer
	multiplayer.peer_connected.connect(self.ServerPeerConnectedByPeer)
	multiplayer.peer_disconnected.connect(self.ServerPeerDisonnectedByPeer)


@rpc("any_peer", "call_local")
func ping(argument):
	# _log("[PeerRTC] Ping from peer %d: arg: %s" % [multiplayer.get_remote_sender_id(), argument])
	_log(str(finalizedPeerPlayers))

@rpc("any_peer", "call_local")
func propagateDataFromHost(data,gameType):
	Gamedata.peerPlayers = data
	Gamedata.playerId = multiplayer.get_unique_id()
	Gamedata.startGame(gameType)
	_log("requested to start a game with"+str(finalizedPeerPlayers))



func peerAsClientConnectedPeerAsServer():
	_log("[PeerRTC] (I am %d) connectd to another peer server" % SignalRTCServer.rtc_mp.get_unique_id())
func peerAsClientDisconnectedPeerAsServer():
	_log("[PeerRTC] (I am %d) disconnectd to another peer server" % SignalRTCServer.rtc_mp.get_unique_id())
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
	handleSealLobby()
	propagateDataFromHost.rpc(finalizedPeerPlayers,Gamedata.GameType.RPS)

func handleSealLobby():
	_log("Requested to seal lobby")
	SignalRTCServer.handlePlayerClickSealLobby_AskServerToSeal()
	for peer in multiplayer.get_peers():
		finalizedPeerPlayers[peer] = {
			peerId=peer #the struct of the player obj
			}
	finalizedPeerPlayers[multiplayer.get_unique_id()] = {peerId=multiplayer.get_unique_id()}
	
	
func _on_start_pressed():
	SignalRTCServer.handlePlayerClickedStart_ConnectToSignalServer(host.text, room.text, mesh.button_pressed)
func _on_stop_pressed():
	SignalRTCServer.handlePlayerClickedStopConnections_CloseAllConnection()


func _on_chinese_poker_pressed():
	handleSealLobby()
	propagateDataFromHost.rpc(finalizedPeerPlayers,Gamedata.GameType.CHINESE_POKER)
