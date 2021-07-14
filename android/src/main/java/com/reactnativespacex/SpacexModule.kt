package com.reactnativespacex

import android.util.Log
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.reactnativespacex.impl.*
import com.reactnativespacex.impl.utils.trace
import org.json.JSONArray
import org.json.JSONObject

class NativeGraphqlClient(
  val key: String,
  val context: ReactApplicationContext,
  endpoint: String,
  descriptor: String,
  params: Map<String, String>,
  storage: String?,
  mode: SpaceXMode
) {

  private var connected = false
  private val client = SpaceXClient(endpoint, mode, params, context, storage)
  private val watches = mutableMapOf<String, () -> Unit>()
  private val subscriptions = mutableMapOf<String, () -> Unit>()
  private val operations = SpaceXOperationDescriptor(JSONObject(descriptor))

  //
  // Init and Destroy
  //

  init {
    client.setConnectionStateListener {
      if (this.connected != it) {
        this.connected = it
        val map = WritableNativeMap()
        map.putString("key", key)
        map.putString("type", "status")
        map.putString("status", if (it) "connected" else "connecting")
        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit("graphql_client", map)
      }
    }
  }

  fun dispose() {
    subscriptions.forEach {
      it.value()
    }
    subscriptions.clear()
    watches.forEach { it.value() }
    watches.clear()
  }

  //
  // Query
  //

  fun query(id: String, query: String, arguments: ReadableMap, parameters: ReadableMap) {

    // Resolve Fetch Policy
    var policy = FetchPolicy.CACHE_FIRST
    val policyKey = if (parameters.hasKey("fetchPolicy")) parameters.getString("fetchPolicy") else null
    when (policyKey) {
      "cache-first" -> policy = FetchPolicy.CACHE_FIRST
      "network-only" -> policy = FetchPolicy.NETWORK_ONLY
      "cache-and-network" -> policy = FetchPolicy.CACHE_AND_NETWORK
      "no-cache" -> throw Error("no-cache is unsupported on Android")
    }

    client.query(this.operations.operationByName(query), arguments.toKotlinX(), policy, object : OperationCallback {
      override fun onResult(result: JSONObject) {
        val res = trace("toReact") { result.toReact() }

        val map = WritableNativeMap()
        map.putString("key", key)
        map.putString("type", "response")
        map.putString("id", id)
        map.putMap("data", res)

        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit("graphql_client", map)
      }

      override fun onError(result: JSONArray) {
        val res = trace("toReact") { result.toReact() }
        val map = WritableNativeMap()
        map.putString("key", key)
        map.putString("type", "failure")
        map.putString("id", id)
        map.putString("kind", "graphql")
        map.putArray("data", res)
        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit("graphql_client", map)
      }
    })
  }

  //
  // Query Watch
  //

  fun watch(id: String, query: String, arguments: ReadableMap, parameters: ReadableMap) {
    // Resolve Fetch Policy
    var policy = FetchPolicy.CACHE_FIRST
    val policyKey = if (parameters.hasKey("fetchPolicy")) parameters.getString("fetchPolicy") else null
    when (policyKey) {
      "cache-first" -> policy = FetchPolicy.CACHE_FIRST
      "network-only" -> policy = FetchPolicy.NETWORK_ONLY
      "cache-and-network" -> policy = FetchPolicy.CACHE_AND_NETWORK
      "no-cache" -> throw Error("no-cache is unsupported on Android")
    }

    val res = client.watch(this.operations.operationByName(query), arguments.toKotlinX(), policy, object : OperationCallback {
      override fun onResult(result: JSONObject) {
        val res = trace("toReact") { result.toReact() }

        val map = WritableNativeMap()
        map.putString("key", key)
        map.putString("type", "response")
        map.putString("id", id)
        map.putMap("data", res)

        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit("graphql_client", map)
      }

      override fun onError(result: JSONArray) {
        val res = trace("toReact") { result.toReact() }
        val map = WritableNativeMap()
        map.putString("key", key)
        map.putString("type", "failure")
        map.putString("id", id)
        map.putString("kind", "graphql")
        map.putArray("data", res)
        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit("graphql_client", map)
      }
    })
    watches[id] = res
  }

  fun watchEnd(id: String) {
    watches.remove(id)?.invoke()
  }

  //
  // Mutation
  //

  fun mutate(id: String, query: String, arguments: ReadableMap) {
    client.mutation(this.operations.operationByName(query), arguments.toKotlinX(), object : OperationCallback {
      override fun onResult(result: JSONObject) {
        val res = trace("toReact") { result.toReact() }

        val map = WritableNativeMap()
        map.putString("key", key)
        map.putString("type", "response")
        map.putString("id", id)

        map.putMap("data", res)

        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit("graphql_client", map)
      }

      override fun onError(result: JSONArray) {
        val res = trace("toReact") { result.toReact() }
        val map = WritableNativeMap()
        map.putString("key", key)
        map.putString("type", "failure")
        map.putString("id", id)
        map.putString("kind", "graphql")
        map.putArray("data", res)
        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit("graphql_client", map)
      }
    })
  }

  //
  // Subscriptions
  //

  fun subscribe(id: String, query: String, arguments: ReadableMap) {
    subscriptions[id] = client.subscribe(this.operations.operationByName(query), arguments.toKotlinX(), object : OperationCallback {
      override fun onResult(result: JSONObject) {
        val res = trace("toReact") { result.toReact() }

        val map = WritableNativeMap()
        map.putString("key", key)
        map.putString("type", "response")
        map.putString("id", id)

        map.putMap("data", res)

        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit("graphql_client", map)
      }

      override fun onError(result: JSONArray) {
        val res = trace("toReact") { result.toReact() }
        val map = WritableNativeMap()
        map.putString("key", key)
        map.putString("type", "failure")
        map.putString("id", id)
        map.putString("kind", "graphql")
        map.putArray("data", res)
        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit("graphql_client", map)
      }
    })
  }

  fun unsubscribe(id: String) {
    subscriptions.remove(id)?.invoke()
  }

  //
  // Store operations
  //

  fun read(id: String, query: String, arguments: ReadableMap) {
    client.read(this.operations.operationByName(query), arguments.toKotlinX(), object : StoreReadCallback {
      override fun onResult(result: JSONObject?) {
        val res = trace("toReact") { result?.toReact() }
        val map = WritableNativeMap()
        map.putString("key", key)
        map.putString("type", "response")
        map.putString("id", id)

        if (res != null) {
          map.putMap("data", res)
        } else {
          map.putNull("data")
        }

        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit("graphql_client", map)
      }
    })
  }

  fun write(id: String, data: ReadableMap, query: String, arguments: ReadableMap) {
    client.write(this.operations.operationByName(query), arguments.toKotlinX(), data.toKotlinX(), object : StoreWriteCallback {
      override fun onResult() {
        val map = WritableNativeMap()
        map.putString("key", key)
        map.putString("type", "response")
        map.putString("id", id)
        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit("graphql_client", map)
      }

      override fun onError() {
        // Ignore
      }

    })
  }
}

class SpacexModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

  private val clients = mutableMapOf<String, NativeGraphqlClient>()

  override fun getName(): String {
    return "SpaceX"
  }

  @ReactMethod
  fun createClient(key: String, endpoint: String, descriptor: String, params: ReadableMap, storage: String?, mode: String) {
    Log.d("SpaceX", "createClient")
    if (this.clients.containsKey(key)) {
      throw Error("Client with key $key already exists")
    }
    var modeType: SpaceXMode = SpaceXMode.TRANSPORT_WS
    if (mode == "openland") {
      modeType = SpaceXMode.OPENLAND
    }
    this.clients[key] = NativeGraphqlClient(key, this.reactApplicationContext, endpoint, descriptor, params.toKotlinStringX(), storage, modeType)
  }

  @ReactMethod
  fun closeClient(key: String) {
    Log.d("SpaceX", "closeClient")
    if (!this.clients.containsKey(key)) {
      throw Error("Client with key $key does not exists")
    }
    this.clients.remove(key)!!.dispose()
  }

  @ReactMethod
  fun query(key: String, id: String, query: String, arguments: ReadableMap, parameters: ReadableMap) {
    Log.d("SpaceX", "query:$query")
    if (!this.clients.containsKey(key)) {
      throw Error("Client with key $key does not exists")
    }
    this.clients[key]!!.query(id, query, arguments, parameters)
  }

  @ReactMethod
  fun watch(key: String, id: String, query: String, arguments: ReadableMap, parameters: ReadableMap) {
    Log.d("SpaceX", "watch:$query")
    if (!this.clients.containsKey(key)) {
      throw Error("Client with key $key does not exists")
    }
    this.clients[key]!!.watch(id, query, arguments, parameters)
  }

  @ReactMethod
  fun watchEnd(key: String, id: String) {
    Log.d("SpaceX", "watchEnd")
    if (!this.clients.containsKey(key)) {
      throw Error("Client with key $key does not exists")
    }
    this.clients[key]!!.watchEnd(id)
  }


  @ReactMethod
  fun mutate(key: String, id: String, query: String, arguments: ReadableMap) {
    Log.d("SpaceX", "mutate: $query")
    if (!this.clients.containsKey(key)) {
      throw Error("Client with key $key does not exists")
    }
    this.clients[key]!!.mutate(id, query, arguments)
  }

  @ReactMethod
  fun subscribe(key: String, id: String, query: String, arguments: ReadableMap) {
    Log.d("SpaceX", "subscribe: $query")
    if (!this.clients.containsKey(key)) {
      throw Error("Client with key $key does not exists")
    }
    this.clients[key]!!.subscribe(id, query, arguments)
  }

  @ReactMethod
  fun unsubscribe(key: String, id: String) {
    Log.d("SpaceX", "unsubscribe")
    if (!this.clients.containsKey(key)) {
      throw Error("Client with key $key does not exists")
    }
    this.clients[key]!!.unsubscribe(id)
  }

  @ReactMethod
  fun read(key: String, id: String, query: String, arguments: ReadableMap) {
    Log.d("SpaceX", "read: $query")
    if (!this.clients.containsKey(key)) {
      throw Error("Client with key $key does not exists")
    }
    this.clients[key]!!.read(id, query, arguments)
  }


  @ReactMethod
  fun write(key: String, id: String, data: ReadableMap, query: String, arguments: ReadableMap) {
    Log.d("SpaceX", "write: $query")
    if (!this.clients.containsKey(key)) {
      throw Error("Client with key $key does not exists")
    }
    this.clients[key]!!.write(id, data, query, arguments)
  }
}
