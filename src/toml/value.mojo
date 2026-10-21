from std.memory import ArcPointer

comptime KIND_STRING: UInt8 = 0
comptime KIND_INTEGER: UInt8 = 1
comptime KIND_FLOAT: UInt8 = 2
comptime KIND_BOOL: UInt8 = 3
comptime KIND_DATETIME: UInt8 = 4
comptime KIND_ARRAY: UInt8 = 5
comptime KIND_TABLE: UInt8 = 6

comptime DATETIME_OFFSET: UInt8 = 0
comptime DATETIME_LOCAL: UInt8 = 1
comptime DATE_LOCAL: UInt8 = 2
comptime TIME_LOCAL: UInt8 = 3


struct TomlNode(Copyable, Movable):
    # widest first, flags packed at the end: 96 B instead of 152 B
    var s: String
    var kids: List[Int]  # array items, or table values parallel to tkeys
    var tkeys: List[String]
    var i: Int64
    var f: Float64
    var kind: UInt8
    var dt_kind: UInt8
    var b: Bool
    var is_aot: Bool
    var header_closed: Bool
    var dotted_closed: Bool
    var inline_closed: Bool

    def __init__(out self):
        self.s = ""
        self.kids = []
        self.tkeys = []
        self.i = 0
        self.f = 0.0
        self.kind = UInt8(KIND_STRING)
        self.dt_kind = 0
        self.b = False
        self.is_aot = False
        self.header_closed = False
        self.dotted_closed = False
        self.inline_closed = False


comptime INDEX_AT = 16  # tables with more keys than this get a hash index


struct TomlDoc(Copyable, Movable):
    var pool: List[TomlNode]
    # table node -> key -> value node, only for tables past INDEX_AT keys,
    # so small tables stay a linear scan with no per-node cost
    var index: Dict[Int, Dict[String, Int]]

    def __init__(out self):
        self.pool = []
        self.index = {}

    def find_key(self, table: Int, key: String) -> Int:
        if table in self.index:
            try:
                return self.index[table].get(key, -1)
            except:
                return -1
        ref n = self.pool[table]
        for i in range(len(n.tkeys)):
            if n.tkeys[i] == key:
                return n.kids[i]
        return -1

    def add_key(mut self, table: Int, key: String, value: Int):
        self.pool[table].tkeys.append(key)
        self.pool[table].kids.append(value)
        ref n = self.pool[table]
        if len(n.tkeys) == INDEX_AT + 1:
            var d = Dict[String, Int]()
            for i in range(len(n.tkeys)):
                d[n.tkeys[i]] = n.kids[i]
            self.index[table] = d^
        elif len(n.tkeys) > INDEX_AT + 1:
            try:
                self.index[table][key] = value
            except:
                pass

    def push(mut self, var n: TomlNode) -> Int:
        self.pool.append(n^)
        return len(self.pool) - 1


struct TomlValue(Copyable, Movable):
    var doc: ArcPointer[TomlDoc]
    var idx: Int

    def __init__(out self, doc: ArcPointer[TomlDoc], idx: Int):
        self.doc = doc
        self.idx = idx

    def kind(self) -> UInt8:
        return self.doc[].pool[self.idx].kind

    def is_table(self) -> Bool:
        return self.kind() == KIND_TABLE

    def is_array(self) -> Bool:
        return self.kind() == KIND_ARRAY

    def is_string(self) -> Bool:
        return self.kind() == KIND_STRING

    def is_integer(self) -> Bool:
        return self.kind() == KIND_INTEGER

    def is_float(self) -> Bool:
        return self.kind() == KIND_FLOAT

    def is_bool(self) -> Bool:
        return self.kind() == KIND_BOOL

    def is_datetime(self) -> Bool:
        return self.kind() == KIND_DATETIME

    def as_string(self) raises -> String:
        if self.kind() != KIND_STRING:
            raise Error("toml: value is not a string")
        return self.doc[].pool[self.idx].s

    def as_int(self) raises -> Int64:
        if self.kind() != KIND_INTEGER:
            raise Error("toml: value is not an integer")
        return self.doc[].pool[self.idx].i

    def as_float(self) raises -> Float64:
        if self.kind() != KIND_FLOAT:
            raise Error("toml: value is not a float")
        return self.doc[].pool[self.idx].f

    def as_bool(self) raises -> Bool:
        if self.kind() != KIND_BOOL:
            raise Error("toml: value is not a boolean")
        return self.doc[].pool[self.idx].b

    def as_datetime_text(self) raises -> String:
        if self.kind() != KIND_DATETIME:
            raise Error("toml: value is not a datetime")
        return self.doc[].pool[self.idx].s

    def datetime_kind(self) raises -> UInt8:
        if self.kind() != KIND_DATETIME:
            raise Error("toml: value is not a datetime")
        return self.doc[].pool[self.idx].dt_kind

    def len(self) -> Int:
        ref n = self.doc[].pool[self.idx]
        if n.kind == KIND_ARRAY:
            return len(n.kids)
        if n.kind == KIND_TABLE:
            return len(n.tkeys)
        return 0

    def __getitem__(self, i: Int) raises -> TomlValue:
        ref n = self.doc[].pool[self.idx]
        if n.kind != KIND_ARRAY:
            raise Error("toml: value is not an array")
        if i < 0 or i >= len(n.kids):
            raise Error("toml: array index out of range")
        return TomlValue(self.doc, n.kids[i])

    def __getitem__(self, key: String) raises -> TomlValue:
        var opt = self.get(key)
        if not opt:
            raise Error("toml: key not found: " + key)
        return opt.value().copy()

    def get(self, key: String) -> Optional[TomlValue]:
        ref n = self.doc[].pool[self.idx]
        if n.kind != KIND_TABLE:
            return None
        var i = self.doc[].find_key(self.idx, key)
        if i < 0:
            return None
        return TomlValue(self.doc, i)

    def keys(self) -> List[String]:
        ref n = self.doc[].pool[self.idx]
        var out: List[String] = []
        for k in n.tkeys:
            out.append(k)
        return out^

    def contains(self, key: String) -> Bool:
        return self.doc[].find_key(self.idx, key) >= 0
