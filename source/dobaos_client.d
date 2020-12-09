module dobaos_client;

import core.thread;

import std.base64;
import std.conv;
import std.datetime.stopwatch;
import std.functional;
import std.json;
import std.random;
import std.stdio;
import std.string;

import tinyredis;
import tinyredis.subscriber;

enum Errors: string {
  TIMEOUT = "ERR_TIMEOUT"
}

enum Methods: string {
  get_description = "get description",
  get_value = "get value",
  get_stored = "get stored",
  read_value = "read value",
  set_value = "set value",
  put_value = "put value",
  get_server_items = "get server items",
  get_programming_mode = "get programming mode",
  set_programming_mode = "set programming mode",
  get_version = "version",
  reset = "reset",
  success = "success",
  error = "error",
  on_datapoint_value = "datapoint value",
  on_sdk_init = "sdk init",
  on_sdk_reset = "sdk reset"
}

class DobaosClient {
  private Redis pub;
  private Subscriber sub;
  private Subscriber sub_cast;
  private string redis_host, req_channel, bcast_channel;
  private ushort redis_port;

  private bool res_received = false;
  private string res_pattern = "ddcli_*";

  private string last_channel;
  private JSONValue response;
  
  private Duration req_timeout;
  private Random rnd;

  public void delegate() onInit;
  public void delegate() onSdkInit;
  public void delegate() onSdkReset;
  public void delegate(JSONValue) onDatapointValue;

  this(string redis_host = "127.0.0.1", 
      ushort redis_port = 6379,
      string req_channel = "dobaos_req",
      string bcast_channel = "dobaos_cast",
      Duration req_timeout = 5000.msecs
      ) {

    this.redis_host = redis_host;
    this.redis_port = redis_port;
    this.req_channel = req_channel;
    this.bcast_channel = bcast_channel;
    this.req_timeout = req_timeout;
  }

  public void init() {
    // init publisher
    pub = new Redis(redis_host, redis_port);

    // now handle message
    void handleResponse(string pattern, string channel, string message) {
      try {
        if (channel != last_channel) {
          return;
        }

        JSONValue jres = parseJSON(message);

        // check if response is object
        if (!jres.type == JSONType.object) {
          return;
        }
        // check if response has method field
        auto jmethod = ("method" in jres);
        if (jmethod is null) {
          return;
        }

        response = jres;
        res_received = true;
      } catch(Exception e) {
        //writeln("error parsing json: %s ", e.msg);
      } 
    }
    sub = new Subscriber(redis_host, redis_port);
    sub.psubscribe(res_pattern, toDelegate(&handleResponse));

    void handleBroadcast(string channel, string message) {
      try {
        JSONValue j = parseJSON(message);

        // check if response is object
        if (j.type != JSONType.object) {
          return;
        }
        // check if response has method field
        auto jmethod = ("method" in j);
        if (jmethod is null) {
          return;
        }
        auto jpayload = ("payload" in j);

        string method = (*jmethod).str;
        switch(method) {
          case Methods.on_datapoint_value:
            if (jpayload is null) {
              return;
            }
            if (onDatapointValue !is null)
              onDatapointValue(*jpayload);
            break;
          case Methods.on_sdk_init:
            if (onSdkInit !is null)
              onSdkInit();
            break;
          case Methods.on_sdk_reset:
            if (onSdkReset !is null)
              onSdkReset();
            break;
          default:
            break;
        }
      } catch(Exception e) {
        //writeln("error parsing json: %s ", e.msg);
      } 
    }
    sub_cast = new Subscriber(redis_host, redis_port);
    sub_cast.subscribe(bcast_channel, toDelegate(&handleBroadcast));
    if (onInit !is null)
       onInit();
  }

  public void processMessages() {
    sub_cast.processMessages();
  }
  
  private JSONValue commonRequest(string channel, string method, JSONValue payload) {
    res_received = false;
    response = null;

    int rnum = uniform(0, 65535, rnd);
    last_channel = res_pattern.replace("*", to!string(rnum));

    JSONValue jreq = parseJSON("{}");
    jreq["method"] = method;
    jreq["payload"] = payload;
    jreq["response_channel"] = last_channel;
    pub.send("PUBLISH", channel, jreq.toJSON());

    auto sw = StopWatch(AutoStart.yes);
    auto dur = sw.peek();
    bool timeout = dur > req_timeout;
    while(!res_received && !timeout) {
      sub.processMessages();
      timeout = sw.peek() > req_timeout;
      if (timeout) {
        sw.stop();
        throw new Exception(Errors.TIMEOUT);
      }
      Thread.sleep(1.msecs);
    }
    if (response["method"].str == Methods.error) {
      throw new Exception(response["payload"].str);
    }

    return response["payload"];
  }

  public JSONValue getDescription(JSONValue payload) {
    return commonRequest(req_channel, Methods.get_description, payload);
  }
  public JSONValue getDescription() { return getDescription(JSONValue(null)); }
  public JSONValue getDescription(ushort id) { return getDescription(JSONValue(id)); }
  public JSONValue getDescription(ushort[] id) { return getDescription(JSONValue(id)); }
  public JSONValue getDescription(int id) { return getDescription(JSONValue(id)); }
  public JSONValue getDescription(int[] id) { return getDescription(JSONValue(id)); }
  public JSONValue getDescription(string id) { return getDescription(JSONValue(id)); }
  public JSONValue getDescription(string[] id) { return getDescription(JSONValue(id)); }

  public JSONValue getValue(JSONValue payload) {
    return commonRequest(req_channel, Methods.get_value, payload);
  }
  public JSONValue getValue() { return getValue(JSONValue(null)); }
  public JSONValue getValue(ushort id) { return getValue(JSONValue(id)); }
  public JSONValue getValue(ushort[] id) { return getValue(JSONValue(id)); }
  public JSONValue getValue(int id) { return getValue(JSONValue(id)); }
  public JSONValue getValue(int[] id) { return getValue(JSONValue(id)); }
  public JSONValue getValue(string id) { return getValue(JSONValue(id)); }
  public JSONValue getValue(string[] id) { return getValue(JSONValue(id)); }

  public JSONValue getStored(JSONValue payload) {
    return commonRequest(req_channel, Methods.get_stored, payload);
  }
  public JSONValue getStored() { return getStored(JSONValue(null)); }
  public JSONValue getStored(ushort id) { return getStored(JSONValue(id)); }
  public JSONValue getStored(ushort[] id) { return getStored(JSONValue(id)); }
  public JSONValue getStored(int id) { return getStored(JSONValue(id)); }
  public JSONValue getStored(int[] id) { return getStored(JSONValue(id)); }
  public JSONValue getStored(string id) { return getStored(JSONValue(id)); }
  public JSONValue getStored(string[] id) { return getStored(JSONValue(id)); }

  public JSONValue readValue(JSONValue payload) {
    return commonRequest(req_channel, Methods.read_value, payload);
  }
  public JSONValue readValue(ushort id) { return readValue(JSONValue(id)); }
  public JSONValue readValue(ushort[] id) { return readValue(JSONValue(id)); }
  public JSONValue readValue(int id) { return readValue(JSONValue(id)); }
  public JSONValue readValue(int[] id) { return readValue(JSONValue(id)); }
  public JSONValue readValue(string id) { return readValue(JSONValue(id)); }
  public JSONValue readValue(string[] id) { return readValue(JSONValue(id)); }


  public JSONValue setValue(JSONValue payload) {
    return commonRequest(req_channel, Methods.set_value, payload);
  }
  public JSONValue setValue(T, V)(T id, V value) {
    JSONValue payload = parseJSON("{}");
    payload["id"] = id;
    payload["value"] = value;

    return setValue(payload);
  }
  // raw
  public JSONValue setValue(T, V: ubyte[])(T id, V value) {
    JSONValue payload = parseJSON("{}");
    payload["id"] = id;
    payload["raw"] = Base64.encode(value);

    return setValue(payload);
  }

  public JSONValue putValue(JSONValue payload) {
    return commonRequest(req_channel, Methods.put_value, payload);
  }
  public JSONValue putValue(T, V)(T id, V value) {
    JSONValue payload = parseJSON("{}");
    payload["id"] = id;
    payload["value"] = value;

    return putValue(payload);
  }
  // raw
  public JSONValue putValue(T, V: ubyte[])(T id, V value) {
    JSONValue payload = parseJSON("{}");
    payload["id"] = id;
    payload["raw"] = Base64.encode(value);

    return putValue(payload);
  }

  public JSONValue getServerItems() {
    JSONValue payload = null;
    return commonRequest(req_channel, Methods.get_server_items, payload);
  }
  
  public JSONValue getProgrammingMode() {
    JSONValue payload = null;
    return commonRequest(req_channel, Methods.get_programming_mode, payload);
  }

  public JSONValue setProgrammingMode(JSONValue value) {
    JSONValue payload = value;

    return commonRequest(req_channel, Methods.set_programming_mode, payload);
  }
  public JSONValue setProgrammingMode(bool value) { return setProgrammingMode(JSONValue(value)); }
  public JSONValue setProgrammingMode(int value) { return setProgrammingMode(JSONValue(value)); }

  // service methods
  public JSONValue getVersion() {
    JSONValue payload = null;
    return commonRequest(req_channel, Methods.get_version, payload);
  }

  public JSONValue reset() {
    JSONValue payload = null;
    return commonRequest(req_channel, Methods.reset, payload);
  }
}
