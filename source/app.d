import std.stdio;

import std.json;


// annotations
struct JsonProperty {
  string name;
  alias name this;
}

// retrieve metadata about how json serde should work for a field in a given type
template JsonMetadata(T, string field) {
  import std.traits;
  alias names = FieldNameTuple!T;
  alias TYPES = Fields!T;

  // the name of the
  string serialName() {
    foreach (name ; names) {
      if (name == field) {
        auto udas =  getUDAs!(__traits(getMember, T, name), JsonProperty);
        string ret = field;
        static if (udas.length != 0) {
          ret = udas[0];
        }
        return ret;
      }
    }
  } 
}

unittest {
  struct Foo {
    @JsonProperty("bar") string foo;
  }

  assert(JsonMetadata!(Foo,  "foo").serialName() == "bar");
}

template JsonCodec(T) {
  import std.traits;
  T deserialize(JSONValue json) {
    alias TYPES = Fields!T;
    alias NAMES = FieldNameTuple!T;

    auto builder = T();
    foreach (i, string name ; NAMES) {
      alias TYPE = TYPES[i];
      alias Codec = JsonCodec!TYPE;
      alias META = JsonMetadata!(T, name);

      TYPE value = Codec.deserialize(json[META.serialName()]);
      __traits(getMember, builder, name) = value;
    }
    return builder;
  }
}

unittest {
  struct Point {
    long x = 0;
    long y = 0;
  }
  struct Line {
    Point from;
    Point to;
    string label;
  }

  auto json = parseJSON(`{"from": {"x": 0, "y": 0}, "to": {"x": 2, "y": 2}, "label": "my line"}`);
  auto deser = JsonCodec!Line.deserialize(json);
  assert(deser == Line(Point(0, 0), Point(2, 2), "my line"));
}

unittest {
  struct Foo {
    @JsonProperty("baz") string bar;
  }

  auto json = parseJSON(`{"baz": "foo"}`);
  alias F = JsonCodec!Foo;
  assert(F.deserialize(json) == Foo("foo"));
}

template JsonCodec(T: long) {
  long deserialize(JSONValue value) {
    return value.integer();
  }
}


template JsonCodec(T: string) {
  string deserialize(JSONValue value) {
    return value.str();
  }
}

template JsonCodec(T: bool) {
  bool deserialize(JSONValue value) {
    switch(value.type()) {
      case JSON_TYPE.TRUE:
       return true;
      case JSON_TYPE.FALSE:
       return false;
      default:
       throw new Error("value is not a boolean");
    }
  }
}

unittest {
  auto json = parseJSON(`1234`);
  auto deser = JsonCodec!(long).deserialize(json);
  assert(deser == 1234);

  json = parseJSON(`"hello"`);
  string deserString = JsonCodec!(string).deserialize(json);
  assert(deserString == "hello");

  json = parseJSON(`true`);
  bool deserBool = JsonCodec!(bool).deserialize(json);
  assert(deserBool == true);
}

T deserJson(T)(string json) {
  alias CODEC = JsonCodec!T;
  JSONValue value = parseJSON(json);
  return CODEC.deserialize(value);
}

void main()
{
  struct Point {
    @JsonProperty("x")
    long xVal;

    @JsonProperty("y")
    long yVal;
  }


  // auto line = readln();
  // Point p = line.deserJson!Point;
  // writeln(p);
}

