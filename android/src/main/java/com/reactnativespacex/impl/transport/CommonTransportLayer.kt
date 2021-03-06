package com.reactnativespacex.impl.transport

import android.annotation.SuppressLint
import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.os.Build
import com.reactnativespacex.impl.SpaceXMode
import com.reactnativespacex.impl.transport.net.ThrustedSocket
import com.reactnativespacex.impl.utils.DispatchQueue
import com.reactnativespacex.impl.utils.fatalError
import com.reactnativespacex.impl.utils.xLog
import org.json.JSONObject

enum class NetworkingApolloState {
  WAITING, CONNECTING, STARTING, STARTED, COMPLETED
}

val PING_INTERVAL = 1000
val SOCKET_TIMEOUT = 5000

@SuppressLint("MissingPermission")
class CommonTransportLayer(
  val context: Context,
  val url: String,
  val params: Map<String, String?>,
  val mode: SpaceXMode,
  private val handlerQueue: DispatchQueue,
  private val handler: NetworkingHandler
) {

  private val queue = DispatchQueue("spacex-networking-apollo")
  private var state = NetworkingApolloState.WAITING
  private var client: ThrustedSocket? = null
  private var failuresCount = 0
  private var reachable = false
  private var started = false
  private var pending = mutableMapOf<String, JSONObject>()
  private var pingTimeout: (() -> Unit)? = null

  private val connectivityCallback = object : ConnectivityManager.NetworkCallback() {
    override fun onAvailable(network: Network) {
      queue.async {
        onReachable()
      }
    }

    override fun onUnavailable() {
      queue.async {
        onUnreachable()
      }
    }

    override fun onLost(network: Network) {
      queue.async {
        onUnreachable()
      }
    }
  }

  init {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
      connectivityManager.registerDefaultNetworkCallback(connectivityCallback)
    } else {
      // Enforce network for old androids
      reachable = true
    }
  }

  fun connect() {
    queue.async {
      xLog("SpaceX-Apollo", "Starting")
      this.started = true
      if (this.reachable) {
        doConnect()
      }
    }
  }

  fun startRequest(id: String, body: JSONObject) {
    queue.async {
      if (state == NetworkingApolloState.WAITING || state == NetworkingApolloState.CONNECTING) {
        // Add to pending buffer if we are not connected already
        this.pending[id] = body
      } else if (state == NetworkingApolloState.STARTING) {
        // If we connected, but not started add to pending buffer (in case of failed start)
        // and send message to socket

        this.pending[id] = body
        this.writeToSocket(JSONObject(mapOf(
          "type" to "start",
          "id" to id,
          "payload" to body
        )))
      } else if (state == NetworkingApolloState.STARTED) {
        this.writeToSocket(JSONObject(mapOf(
          "type" to "start",
          "id" to id,
          "payload" to body
        )))
      } else if (state == NetworkingApolloState.COMPLETED) {
        // Silently ignore if connection is completed
      } else {
        fatalError()
      }
    }
  }

  fun stopRequest(id: String) {
    queue.async {
      if (state == NetworkingApolloState.WAITING || state == NetworkingApolloState.CONNECTING) {
        // Remove from pending buffer if we are not connected already
        this.pending.remove(id)
      } else if (state == NetworkingApolloState.STARTING) {
        // If we connected, but not started remove from pending buffer (in case of failed start)
        // and send cancellation message to socket
        this.pending.remove(id)
        this.writeToSocket(JSONObject(mapOf("type" to "stop", "id" to id)))
      } else if (state == NetworkingApolloState.STARTED) {
        this.writeToSocket(JSONObject(mapOf("type" to "stop", "id" to id)))
      } else if (state == NetworkingApolloState.COMPLETED) {
        // Silently ignore if connection is completed
      } else {
        fatalError()
      }
    }
  }

  fun close() {
    queue.async {
      if (this.state !== NetworkingApolloState.COMPLETED) {
        this.state = NetworkingApolloState.COMPLETED

        // Remove all pending requests
        this.pending.clear()

        // Stopping client
        this.stopClient()

        // Stopping network state callback
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
          val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
          connectivityManager.unregisterNetworkCallback(connectivityCallback)
        }
      }
    }
  }

  private fun doConnect() {
    xLog("SpaceX-Transport", "Connecting")
    if (this.state != NetworkingApolloState.WAITING) {
      fatalError("Unexpected state")
    }
    this.state = NetworkingApolloState.CONNECTING

    val ws = ThrustedSocket(this.url,
      if (this.mode == SpaceXMode.OPENLAND) null else "graphql-ws",
      SOCKET_TIMEOUT,
      this.queue
    )
    ws.onOpen = {
      if (this.client == ws) {
        onConnected()
      }
    }
    ws.onClose = {
      if (this.client == ws) {
        onDisconnected()
      }
    }
    ws.onMessage = {
      if (this.client == ws) {
        onReceived(it)
      }
    }
    this.client = ws
  }

  private fun onConnected() {
    xLog("SpaceX-Transport", "Connected")
    if (this.state != NetworkingApolloState.CONNECTING) {
      fatalError("Unexpected state")
    }
    this.state = NetworkingApolloState.STARTING

    if (this.mode == SpaceXMode.OPENLAND) {
      this.writeToSocket(JSONObject(mapOf(
        "protocol_v" to 2,
        "type" to "connection_init",
        "payload" to this.params
      )))
    } else {
      this.writeToSocket(JSONObject(mapOf(
        "type" to "connection_init",
        "payload" to this.params
      )))
    }
    for (p in this.pending) {
      this.writeToSocket(JSONObject(mapOf(
        "type" to "start",
        "id" to p.key,
        "payload" to p.value
      )))
    }
  }

  private fun sendPing() {
    this.pingTimeout?.invoke()
    this.pingTimeout = this.queue.asyncDelayed(PING_INTERVAL) {
      if (this.mode == SpaceXMode.OPENLAND) {
        writeToSocket(JSONObject(mapOf(
          "type" to "ping"
        )))
      }
    }
  }

  private fun onReceived(message: String) {
    // xLog("SpaceX-Apollo", "<< $message")

    val parsed = JSONObject(message)
    val type = parsed.getString("type")
//        xLog("SpaceX-Apollo", "<< $type")
    if (type == "ka") {
      // Ignore
    } else if (type == "connection_ack") {
      if (this.state == NetworkingApolloState.STARTING) {
        xLog("SpaceX-Transport", "Started")

        // Change State
        this.state = NetworkingApolloState.STARTED

        // Remove all pending messages
        this.pending.clear()

        // Reset failure count
        this.failuresCount = 0

        // Ping
        sendPing()

        // Notify about state
        this.handlerQueue.async {
          this.handler.onConnected()
        }
      }
    } else if (type == "data") {
      val id = parsed.getString("id")
      val payload = parsed.getJSONObject("payload")
      val errors = payload.optJSONArray("errors")
      if (errors != null) {
        this.handlerQueue.async {
          xLog("SpaceX-Transport", "Error ($id)")
          this.handler.onError(id, errors)
        }
      } else {
        val data = payload.getJSONObject("data")
        this.handlerQueue.async {
          xLog("SpaceX-Transport", "Data ($id)")
          this.handler.onResponse(id, data)
        }
      }
    } else if (type == "error") {
      val id = parsed.getString("id")
//            this.handlerQueue.async {
//                xLog("SpaceX-Apollo", "Critical Error ($id): Retrying")
//                this.handler.onCompleted(id)
//            }
    } else if (type == "ping") {
      if (this.mode === SpaceXMode.OPENLAND) {
        this.writeToSocket(JSONObject(mapOf(
          "type" to "pong"
        )))
      }
    } else if (type == "pong") {
      sendPing()
    } else if (type == "complete") {
      val id = parsed.getString("id")
      this.handlerQueue.async {
        xLog("SpaceX-Transport", "Complete ($id)")
        this.handler.onCompleted(id)
      }
    }
  }

  private fun onReachable() {
    xLog("SpaceX-Transport", "Reachable")
    this.reachable = true
    if (this.started && (this.state == NetworkingApolloState.WAITING
        || this.state == NetworkingApolloState.CONNECTING)) {
      this.stopClient()
      this.state = NetworkingApolloState.WAITING
      this.failuresCount = 0
      this.doConnect()
    }
  }

  private fun onUnreachable() {
    xLog("SpaceX-Transport", "Unreachable")
    this.reachable = false
  }

  private fun onDisconnected() {
    xLog("SpaceX-Transport", "Disconnected")
    if (this.state == NetworkingApolloState.STARTED) {
      this.handlerQueue.async {
        this.handler.onDisconnected()
        this.handler.onSessionRestart()
      }
    }
    this.stopClient()
    this.state = NetworkingApolloState.WAITING
    this.failuresCount += 1
    if (this.reachable) {
      this.doConnect()
    }
    this.queue.asyncDelayed(2000) {
      if (this.state == NetworkingApolloState.WAITING && this.reachable) {
        this.doConnect()
      }
    }
  }

  private fun stopClient() {
    val ws = client
    client = null

    ws?.onMessage = null
    ws?.onClose = null
    ws?.onOpen = null
    ws?.close()

    this.pingTimeout?.invoke()
    this.pingTimeout = null
  }

  private fun writeToSocket(src: JSONObject) {
    val msg = src.toString()
    xLog("SpaceX-Apollo", ">> $msg")
    this.client!!.post(msg)
  }
}
