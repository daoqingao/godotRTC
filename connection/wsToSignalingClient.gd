extends Node

enum Message {JOIN, ID, PEER_CONNECT, PEER_DISCONNECT, OFFER, ANSWER, CANDIDATE, SEAL}

@export var autojoin := true
@export var lobby := "" # Will create a new lobby if empty.
@export var mesh := true # Will use the lobby host as relay otherwise.

var ws: WebSocketPeer = WebSocketPeer.new()
var code = 1000
var reason = "Unknown"
var old_state = WebSocketPeer.STATE_CLOSED

signal log(str)
func _init():
	pass
func _process(delta):
	ws.poll()
	var state = ws.get_ready_state()
	if state != old_state and state == WebSocketPeer.STATE_OPEN and autojoin: #if you made a new room, and made websocket before connecting to signal server. then auto join lobby
		handlePollAutoJoinLobby_AskServerToJoin(self.lobby)
	while state == WebSocketPeer.STATE_OPEN and ws.get_available_packet_count():
		if not _parse_msg():
			print("Error parsing message from server.")
	if state != old_state and state == WebSocketPeer.STATE_CLOSED:
		code = ws.get_close_code()
		reason = ws.get_close_reason()
		OnServerDisconnectedFromClient()
	old_state = state


func _parse_msg():
	var parsed = JSON.parse_string(ws.get_packet().get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("type") or not parsed.has("id") or \
		typeof(parsed.get("data")) != TYPE_STRING:
		return false

	var msg := parsed as Dictionary
	if not str(msg.type).is_valid_int() or not str(msg.id).is_valid_int():
		return false

	var type := str(msg.type).to_int()
	var src_id := str(msg.id).to_int()

	if type == Message.ID:
		OnServerReturnAssignedId_ClientInitRTC(src_id, msg.data == "true")
	elif type == Message.JOIN:
		OnServerReturnLobbyStr_ClientSetLocalLobby(msg.data)
	elif type == Message.SEAL:
		OnServerFinishedSealLobby_ClientSetSealedToTrue()
	elif type == Message.PEER_CONNECT:
		ServerSentPeerConnectPropagatedToAllPeer_ClientTryToPeerConnect(src_id)
	elif type == Message.PEER_DISCONNECT:
		OnServerSignalsPeerDisconnected_RemoveClientPeerData(src_id)
	elif type == Message.OFFER:
		onClientGetsOffer(src_id, msg.data)
	elif type == Message.ANSWER:
		onClientGetsAnswer(src_id, msg.data)
	elif type == Message.CANDIDATE:
		var candidate: PackedStringArray = msg.data.split("\n", false)
		if candidate.size() != 3:
			return false
		if not candidate[1].is_valid_int():
			return false
		GotCandidatesFromPeer_ClientSetCandidate(src_id, candidate[0], candidate[1].to_int(), candidate[2])
	else:
		return false
	return true # Parsed

func _send_msg(type: int, id: int, data:="") -> int:
	return ws.send_text(JSON.stringify({
		"type": type,
		"id": id,
		"data": data
	}))

###################################RTC RELATED THINGS HERE
#this relates to anything thats related to to WEBRTC, everything setup here is for the sake of rtc connection
var rtc_mp: WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()
var sealed := false

#after a join lobby call, this is then called
#signal was emit from the server and then caught to be called here.
func OnServerReturnAssignedId_ClientInitRTC(id, use_mesh):
	log.emit("[Signaling] Client Connected to Server (would be 1 if you are assinged as the host) And you are assigned Peer ID: %d, Initializing RTC_MP as Peer Server or Peer Client" % id)
	# print("Connected %d, mesh: %s" % [id, use_mesh])
	if use_mesh:
		rtc_mp.create_mesh(id)
	elif id == 1: #if you are the assigned as the host, meaning you are the first
		rtc_mp.create_server()
	else:
		rtc_mp.create_client(id)
	multiplayer.multiplayer_peer = rtc_mp


#could be the client disconnected to the server as well
func OnServerDisconnectedFromClient():
	log.emit("[Signaling] Client Discconected from Server : %d - %s" % [code, reason])
	if not sealed:
		handlePlayerClickedStopConnections_CloseAllConnection() # Unexpected disconnect




func OnServerReturnLobbyStr_ClientSetLocalLobby(lobby):
	log.emit("[Signaling] Joined lobby Successfully %s" % lobby)
	self.lobby = lobby


func OnServerFinishedSealLobby_ClientSetSealedToTrue():
	log.emit("[Signaling] Lobby has been sealed")
	sealed = true




#handler stuff here

func handlePollAutoJoinLobby_AskServerToJoin(lobby: String):
	return _send_msg(Message.JOIN, 0 if mesh else 1, lobby)

func handlePlayerClickedStart_ConnectToSignalServer(url, lobby = "", mesh:=true):
	handlePlayerClickedStopConnections_CloseAllConnection()
	sealed = false
	self.mesh = mesh
	self.lobby = lobby
	ws.close()
	code = 1000
	reason = "Unknown"
	ws.connect_to_url(url)

func handlePlayerClickSealLobby_AskServerToSeal():
	return _send_msg(Message.SEAL, 0) #ask the server to seal

func handlePlayerClickedStopConnections_CloseAllConnection(): #stop connection for both signal server and rtc peer
	multiplayer.multiplayer_peer = null
	rtc_mp.close()
	ws.close()


#all rtc here

#both sides need the description (data of the other peer)
#they are sent THROUGH THE SERVER FIRST, (these offer description datas)

#if you are you are host, and 3 clients, host will peer to all 3 clients, and host will get this call. 3 TIMES, EACH of 3 clients get this once to the HOST
func ServerSentPeerConnectPropagatedToAllPeer_ClientTryToPeerConnect(otherPeerId):
	log.emit("[RTC_INIT] 1 ID initializing RTC ")
	var peer: WebRTCPeerConnection = WebRTCPeerConnection.new()
	peer.initialize({
		"iceServers": [ { "urls": ["stun.l.google.com:19302"] } ]
	})
	peer.session_description_created.connect(self.OnPeerSessionDescriptionCreated.bind(otherPeerId))
	peer.ice_candidate_created.connect(self._new_ice_candidate.bind(otherPeerId))
	rtc_mp.add_peer(peer, otherPeerId)
	if otherPeerId < rtc_mp.get_unique_id(): # So lobby creator never creates offers.
		peer.create_offer()


func OnPeerSessionDescriptionCreated(type, data, id):
	if not rtc_mp.has_peer(id):
		return
	log.emit("[RTC_INIT] ID is creating Session Description to be sent: %d" % id)
	rtc_mp.get_peer(id).connection.set_local_description(type, data) #set host own description
	if type == "offer": _send_msg(Message.OFFER, id, data) #sends offer to the server. which sends to all peers
	else: _send_msg(Message.ANSWER, id, data) #if we get answer, send answer to server, which sends it to all peers





#on first step, client gets this, on second, host gets this
func onClientGetsOffer(id, offer):
	log.emit("[RTC_INIT] 2 Got from PEER ID offer trying initate RTC: %d" % id)
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.set_remote_description("offer", offer) #set other peer description,

func onClientGetsAnswer(id, answer):
	log.emit("[RTC_INIT] 3 Got from PEER ANSWER trying initate RTC: %d" % id)
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.set_remote_description("answer", answer) #same thing for answers, if they answer, then you good, if not.. gg
		#im pretty sure if the others does not answer. it means failure


#this should be stun procedure related. i have no idea 
#i think once annswer goes through, time to establish the connection over here.
#ice like router hole punch stuff gets established here...
func _new_ice_candidate(mid_name, index_name, sdp_name, id):
	log.emit("[RTC_INIT] 4 ID Creating ICE CANDIDATES (FINDING PORTS via STUN servers) to ESTABLISH RTC %d " % id)
	log.emit("[RTC_INIT] These are the candidates.... ? %s" % sdp_name)
	#lets just say we cant make a candidate....
	_send_msg(Message.CANDIDATE, id, "\n%s\n%d\n%s" % [mid_name, index_name, sdp_name])

#the candidates should be like which port forwarding stuff should be a good pick....
func GotCandidatesFromPeer_ClientSetCandidate(id, mid, index, sdp): 
	log.emit("[RTC_INIT] 5 ID Creating ICE CANDIDATES (ROUTER PORTS) to ESTABLISH RTC %d " % id)
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.add_ice_candidate(mid, index, sdp)
	


func OnServerSignalsPeerDisconnected_RemoveClientPeerData(id):
	if rtc_mp.has_peer(id): rtc_mp.remove_peer(id)
