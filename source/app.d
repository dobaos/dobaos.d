import core.thread;
import std.functional;
import std.json;
import std.stdio;

import dobaos_client;

void main()
{
  auto dob = new DobaosClient();

  // register listener for broadcasted datapoint values
  void processValue(const JSONValue value) {
    writeln("broadcasted: ", value);
  }
  dob.onDatapointValue = toDelegate(&processValue);
  dob.onInit = () {
    writeln("+====descriptions====+");
    //writeln(dob.getDescription());
    writeln("+====values====+");
    writeln(dob.getValue());
    writeln("+====stored====+");
    writeln(dob.getStored());
    writeln("+====read req====+");
    writeln(dob.readValue([999]));
    writeln("+====get progmode====+");
    writeln(dob.getProgrammingMode());
    writeln("+====set progmode====+");
    writeln(dob.setProgrammingMode(1));
    writeln("+====set progmode====+");
    writeln(dob.setProgrammingMode(false));
    writeln("+====get server items====+");
    writeln(dob.getServerItems());
    writeln("+====get version====+");
    writeln(dob.getVersion());
    writeln("+====reset====+");
    writeln(dob.reset());
    writeln("+====set value====+");
    writeln(dob.setValue(2, false));
    writeln("+====set value====+");
    writeln(dob.setValue(2, 1));
    // raw value
    writeln(dob.setValue(10, cast(ubyte[]) [10, 10, 10]));
    writeln(dob.setValue(1, cast(ubyte[]) [0, 1]));
    writeln("+====put value====+");
    writeln(dob.putValue(2, JSONValue(1)));
  };
  dob.onSdkInit = () {
    writeln("sdk init");
  };
  dob.onSdkReset = () {
    writeln("sdk reset");
  };

  dob.init();

  while(true) {
    dob.processMessages();
    Thread.sleep(2.msecs);
  }
}
