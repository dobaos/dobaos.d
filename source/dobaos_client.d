module dobaos_client;

import std.functional;
import std.json;
import std.stdio;
import std.string;

import tinyredis;
import tinyredis.subscriber;

class DobaosClient {
  private Redis pub;
  private Subscriber sub;
  private Subscriber sub_cast;
  private string redis_host, req_channel, bcast_channel, service_channel;
  private ushort redis_port;

  private bool res_received = false;
  private string res_pattern = "ddcli_*";

  private string last_channel;
  private JSONValue response;

  this(string redis_host = "127.0.0.1", 
      ushort redis_port = 6379,
      string req_channel = "dobaos_req",
      string bcast_channel = "dobaos_cast",
      string service_channel = "dobaos_service",
      string service_bcast = "dobaos_cast") {

    this.redis_host = redis_host;
    this.redis_port = redis_port;
    this.req_channel = req_channel;
    this.bcast_channel = bcast_channel;
    this.service_channel = service_channel;

        // init publisher
    pub = new Redis(redis_host, redis_port);
    // now handle message
    void handleMessage(string pattern, string channel, string message)
    {
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
    sub.psubscribe(res_pattern, toDelegate(&handleMessage));
  }

  public void onDatapointValue(void delegate(const JSONValue) handler) {
    void handleMessage(string channel, string message)
    {
      try {
        JSONValue jres = parseJSON(message);

        // check if response is object
        if (jres.type() != JSONType.object) {
          return;
        }
        // check if response has method field
        auto jmethod = ("method" in jres);
        if (jmethod is null) {
          return;
        }
        if ((*jmethod).str != "datapoint value") {
          return;
        }

        auto jpayload = ("payload" in jres);
        if (jpayload is null) {
          return;
        }

        handler(*jpayload);
      } catch(Exception e) {
        //writeln("error parsing json: %s ", e.msg);
      } 
    }
    sub_cast = new Subscriber(redis_host, redis_port);
    sub_cast.subscribe(bcast_channel, toDelegate(&handleMessage));
  }

  public void processMessages() {
    sub_cast.processMessages();
  }
  
  private JSONValue commonRequest(string channel, string method, JSONValue payload) {
    res_received = false;
    response = null;
    last_channel = res_pattern.replace("*", "42");

    JSONValue jreq = parseJSON("{}");
    jreq["method"] = method;
    jreq["payload"] = payload;
    jreq["response_channel"] = last_channel;
    pub.send("PUBLISH", channel, jreq.toJSON());

    while(!res_received) {
      sub.processMessages();
    }

    return response;
  }

  public JSONValue getDescription() {
    JSONValue payload = null;

    return commonRequest(req_channel, "get description", payload);
  }
  public JSONValue getDescription(ushort id) {
    JSONValue payload = id;

    return commonRequest(req_channel, "get description", payload);
  }
  public JSONValue getDescription(ushort[] id) {
    JSONValue payload = id;

    return commonRequest(req_channel, "get description", payload);
  }

  public JSONValue getValue() {
    JSONValue payload = null;

    return commonRequest(req_channel, "get value", payload);
  }
  public JSONValue getValue(ushort id) {
    JSONValue payload = id;

    return commonRequest(req_channel, "get value", payload);
  }
  public JSONValue getValue(ushort[] id) {
    JSONValue payload = id;

    return commonRequest(req_channel, "get value", payload);
  }

  public JSONValue readValue(ushort id) {
    JSONValue payload = id;

    return commonRequest(req_channel, "read value", payload);
  }
  public JSONValue readValue(ushort[] id) {
    JSONValue payload = id;

    return commonRequest(req_channel, "read value", payload);
  }

  public JSONValue setValue(ushort id, JSONValue value) {
    JSONValue payload = parseJSON("{}");
    payload["id"] = id;
    payload["value"] = value;

    return commonRequest(req_channel, "set value", payload);
  }
  public JSONValue setValue(JSONValue values) {
    return commonRequest(req_channel, "set value", values);
  }

  public JSONValue getServerItems() {
    JSONValue payload = null;

    return commonRequest(req_channel, "get server items", payload);
  }
  
  public JSONValue getProgrammingMode() {
    JSONValue payload = null;

    return commonRequest(req_channel, "get programming mode", payload);
  }

  public JSONValue setProgrammingMode(bool value) {
    JSONValue payload = value;

    return commonRequest(req_channel, "set programming mode", payload);
  }
  public JSONValue setProgrammingMode(ushort value) {
    JSONValue payload = value;

    return commonRequest(req_channel, "set programming mode", payload);
  }

  // service methods
  public JSONValue getVersion() {
    JSONValue payload = null;

    return commonRequest(service_channel, "version", payload);
  }

  public JSONValue reset() {
    JSONValue payload = null;

    return commonRequest(service_channel, "reset", payload);
  }
}