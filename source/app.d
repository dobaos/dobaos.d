import core.thread;
import std.functional;
import std.json;
import std.stdio;

import dobaos_client;

void main()
{
  auto dob = new DobaosClient("10.0.42.6");
  writeln("+====descriptions====+");
  writeln(dob.getDescription());
  writeln("+====values====+");
  writeln(dob.getValue());
  writeln("+====read req====+");
  writeln(dob.readValue([1, 6, 7, 8, 9]));
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
  writeln(dob.setValue(2, JSONValue(false)));
  writeln("+====set value====+");
  writeln(dob.setValue(2, JSONValue(1)));
  // raw value
  writeln(dob.setValue(10, [10, 10, 10]));
  writeln(dob.setValue(2, [0, 1]));

  // register listener for broadcasted datapoint values
  void processValue(const JSONValue value) {
    writeln("broadcasted: ", value);
  }
  dob.onDatapointValue(toDelegate(&processValue));

  while(true) {
    dob.processMessages();
    Thread.sleep(2.msecs);
  }
}
