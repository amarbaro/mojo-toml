from std.memory import ArcPointer
from toml.value import (
    TomlNode,
    TomlDoc,
    TomlValue,
    KIND_STRING,
    KIND_INTEGER,
    KIND_FLOAT,
    KIND_BOOL,
    KIND_DATETIME,
    KIND_ARRAY,
    KIND_TABLE,
    DATETIME_OFFSET,
    DATETIME_LOCAL,
    DATE_LOCAL,
    TIME_LOCAL,
)

comptime QUOTE: UInt8 = 34
comptime APOS: UInt8 = 39
comptime LBRACKET: UInt8 = 91
comptime RBRACKET: UInt8 = 93
comptime LBRACE: UInt8 = 123
comptime RBRACE: UInt8 = 125
comptime COMMA: UInt8 = 44
comptime DOT: UInt8 = 46
comptime EQUALS: UInt8 = 61
comptime HASH: UInt8 = 35
comptime BACKSLASH: UInt8 = 92
comptime SPACE: UInt8 = 32
comptime TAB: UInt8 = 9
comptime NEWLINE: UInt8 = 10
comptime CR: UInt8 = 13
comptime UNDERSCORE: UInt8 = 95
comptime DASH: UInt8 = 45
comptime PLUS: UInt8 = 43
comptime COLON: UInt8 = 58


def is_digit(c: UInt8) -> Bool:
    return c >= 48 and c <= 57


def is_hex_digit(c: UInt8) -> Bool:
    return is_digit(c) or (c >= 97 and c <= 102) or (c >= 65 and c <= 70)


def is_alpha(c: UInt8) -> Bool:
    return (c >= 65 and c <= 90) or (c >= 97 and c <= 122)


def is_bare_key_char(c: UInt8) -> Bool:
    return is_digit(c) or is_alpha(c) or c == UNDERSCORE or c == DASH


def is_forbidden_control(c: UInt8) -> Bool:
    return (c < 0x20 and c != TAB) or c == 0x7F


def hex_val(c: UInt8) -> Int:
    if c >= 48 and c <= 57:
        return Int(c) - 48
    if c >= 97 and c <= 102:
        return Int(c) - 97 + 10
    if c >= 65 and c <= 70:
        return Int(c) - 65 + 10
    return -1


def add_seconds(mut b: List[UInt8], off: Int):
    """TOML 1.1 makes seconds optional: insert ":00" after a bare HH:MM at off."""
    if len(b) < off + 5 or b[off + 2] != COLON:
        return
    if len(b) > off + 5 and b[off + 5] == COLON:
        return
    var out: List[UInt8] = []
    for i in range(off + 5):
        out.append(b[i])
    out.append(COLON)
    out.append(48)
    out.append(48)
    for i in range(off + 5, len(b)):
        out.append(b[i])
    b = out^


def is_leap_year(year: Int) -> Bool:
    if year % 4 != 0:
        return False
    if year % 100 != 0:
        return True
    return year % 400 == 0


def days_in_month(year: Int, month: Int) -> Int:
    if month == 2:
        return 29 if is_leap_year(year) else 28
    if month == 4 or month == 6 or month == 9 or month == 11:
        return 30
    return 31


def bytes_list(s: String) -> List[UInt8]:
    return List[UInt8](s.as_bytes())


def append_utf8(mut buf: List[UInt8], cp: Int):
    if cp < 0x80:
        buf.append(UInt8(cp))
    elif cp < 0x800:
        buf.append(UInt8(0xC0 | (cp >> 6)))
        buf.append(UInt8(0x80 | (cp & 0x3F)))
    elif cp < 0x10000:
        buf.append(UInt8(0xE0 | (cp >> 12)))
        buf.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
        buf.append(UInt8(0x80 | (cp & 0x3F)))
    else:
        buf.append(UInt8(0xF0 | (cp >> 18)))
        buf.append(UInt8(0x80 | ((cp >> 12) & 0x3F)))
        buf.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
        buf.append(UInt8(0x80 | (cp & 0x3F)))


def validate_utf8(data: List[UInt8]) raises:
    var n = len(data)
    var i = 0
    while i < n:
        var c = data[i]
        var cp: Int
        var extra: Int
        if c < 0x80:
            i += 1
            continue
        elif (c & 0xE0) == 0xC0:
            cp = Int(c & 0x1F)
            extra = 1
            if c < 0xC2:
                raise Error("toml: invalid utf-8 (overlong) at byte " + String(i))
        elif (c & 0xF0) == 0xE0:
            cp = Int(c & 0x0F)
            extra = 2
        elif (c & 0xF8) == 0xF0:
            cp = Int(c & 0x07)
            extra = 3
            if c > 0xF4:
                raise Error("toml: invalid utf-8 at byte " + String(i))
        else:
            raise Error("toml: invalid utf-8 at byte " + String(i))
        if i + extra >= n:
            raise Error("toml: truncated utf-8 at byte " + String(i))
        var j = 1
        while j <= extra:
            var cc = data[i + j]
            if (cc & 0xC0) != 0x80:
                raise Error("toml: invalid utf-8 continuation at byte " + String(i))
            cp = (cp << 6) | Int(cc & 0x3F)
            j += 1
        if extra == 2 and cp < 0x800:
            raise Error("toml: overlong utf-8 at byte " + String(i))
        if extra == 3 and cp < 0x10000:
            raise Error("toml: overlong utf-8 at byte " + String(i))
        if cp >= 0xD800 and cp <= 0xDFFF:
            raise Error("toml: utf-8 encodes surrogate at byte " + String(i))
        if cp > 0x10FFFF:
            raise Error("toml: codepoint out of range at byte " + String(i))
        i += 1 + extra


struct Parser:
    var data: List[UInt8]
    var pos: Int
    var doc: TomlDoc
    var root: Int
    var current_table: Int

    def __init__(out self, var data: List[UInt8]) raises:
        validate_utf8(data)
        self.data = data^
        self.pos = 0
        self.doc = TomlDoc()
        var rn = TomlNode()
        rn.kind = KIND_TABLE
        self.root = self.doc.push(rn^)
        self.current_table = self.root

    # ---- low level helpers ----

    def eof(self) -> Bool:
        return self.pos >= len(self.data)

    def peek(self) -> UInt8:
        if self.eof():
            return 0
        return self.data[self.pos]

    def peek_at(self, off: Int) -> UInt8:
        var p = self.pos + off
        if p >= len(self.data):
            return 0
        return self.data[p]

    def line_col(self, at: Int) -> String:
        var line = 1
        var col = 1
        var i = 0
        while i < at and i < len(self.data):
            if self.data[i] == NEWLINE:
                line += 1
                col = 1
            else:
                col += 1
            i += 1
        return String(line) + ":" + String(col)

    def fail(self, msg: String) raises:
        raise Error("toml: " + msg + " at line " + self.line_col(self.pos))

    def skip_line_ws(mut self):
        while not self.eof() and (self.peek() == SPACE or self.peek() == TAB):
            self.pos += 1

    def try_consume_newline(mut self) raises -> Bool:
        if self.peek() == NEWLINE:
            self.pos += 1
            return True
        if self.peek() == CR and self.peek_at(1) == NEWLINE:
            self.pos += 2
            return True
        return False

    def skip_comment_if_any(mut self) raises:
        if self.peek() != HASH:
            return
        self.pos += 1
        while not self.eof() and self.peek() != NEWLINE and self.peek() != CR:
            if is_forbidden_control(self.peek()):
                self.fail("control character in comment")
            self.pos += 1

    def expect_eol(mut self) raises:
        self.skip_line_ws()
        self.skip_comment_if_any()
        if self.eof():
            return
        if self.try_consume_newline():
            return
        self.fail("expected newline")

    # ---- top level ----

    def parse(mut self) raises -> TomlValue:
        while True:
            self.skip_line_ws()
            if self.eof():
                break
            if self.try_consume_newline():
                continue
            if self.peek() == HASH:
                self.expect_eol()
                continue
            if self.peek() == LBRACKET:
                self.parse_table_header()
            else:
                self.parse_keyval_line(self.current_table)
            self.expect_eol()
        var doc = TomlDoc()
        swap(doc, self.doc)  # move the pool out, never a second copy
        return TomlValue(ArcPointer(doc^), self.root)

    def parse_table_header(mut self) raises:
        self.pos += 1
        var is_array = False
        if self.peek() == LBRACKET:
            is_array = True
            self.pos += 1
        self.skip_line_ws()
        var segments = self.parse_key_path()
        self.skip_line_ws()
        if self.peek() != RBRACKET:
            self.fail("expected ']'")
        self.pos += 1
        if is_array:
            if self.peek() != RBRACKET:
                self.fail("expected ']]'")
            self.pos += 1
        self.current_table = self.resolve_header(segments, is_array)

    def resolve_header(mut self, segments: List[String], is_array: Bool) raises -> Int:
        if len(segments) == 0:
            self.fail("empty table header")
        var cur = self.root
        for si in range(len(segments) - 1):
            cur = self.step_header_ancestor(cur, segments[si])
        var last = segments[len(segments) - 1]
        if is_array:
            return self.open_array_table(cur, last)
        return self.open_std_table(cur, last)

    def step_header_ancestor(mut self, cur: Int, key: String) raises -> Int:
        var existing = self.doc.find_key(cur, key)
        if existing < 0:
            var n = TomlNode()
            n.kind = KIND_TABLE
            var idx = self.doc.push(n^)
            self.doc.add_key(cur, key, idx)
            return idx
        var kind = self.doc.pool[existing].kind
        if kind == KIND_TABLE:
            if self.doc.pool[existing].inline_closed:
                self.fail("cannot extend inline table '" + key + "'")
            return existing
        if kind == KIND_ARRAY:
            if not self.doc.pool[existing].is_aot:
                self.fail("cannot index into a static array with a table header")
            var n = len(self.doc.pool[existing].kids)
            if n == 0:
                self.fail("empty array of tables")
            return self.doc.pool[existing].kids[n - 1]
        self.fail("cannot redefine '" + key + "' as a table")
        return -1

    def open_std_table(mut self, cur: Int, key: String) raises -> Int:
        var existing = self.doc.find_key(cur, key)
        if existing < 0:
            var n = TomlNode()
            n.kind = KIND_TABLE
            n.header_closed = True
            var idx = self.doc.push(n^)
            self.doc.add_key(cur, key, idx)
            return idx
        var kind = self.doc.pool[existing].kind
        if kind != KIND_TABLE:
            self.fail("cannot redefine '" + key + "'")
        if self.doc.pool[existing].header_closed or self.doc.pool[existing].dotted_closed:
            self.fail("table '" + key + "' redefined")
        self.doc.pool[existing].header_closed = True
        return existing

    def open_array_table(mut self, cur: Int, key: String) raises -> Int:
        var existing = self.doc.find_key(cur, key)
        if existing < 0:
            var arrn = TomlNode()
            arrn.kind = KIND_ARRAY
            arrn.is_aot = True
            var arr_idx = self.doc.push(arrn^)
            self.doc.add_key(cur, key, arr_idx)
            existing = arr_idx
        var kind = self.doc.pool[existing].kind
        if kind != KIND_ARRAY or not self.doc.pool[existing].is_aot:
            self.fail("cannot redefine '" + key + "' as an array of tables")
        var elem = TomlNode()
        elem.kind = KIND_TABLE
        elem.header_closed = True
        var elem_idx = self.doc.push(elem^)
        self.doc.pool[existing].kids.append(elem_idx)
        return elem_idx

    # ---- keys ----

    def parse_key_path(mut self) raises -> List[String]:
        var out: List[String] = []
        out.append(self.parse_simple_key())
        while True:
            self.skip_line_ws()
            if self.peek() != DOT:
                break
            self.pos += 1
            self.skip_line_ws()
            out.append(self.parse_simple_key())
        return out^

    def parse_simple_key(mut self) raises -> String:
        if self.peek() == QUOTE:
            return self.parse_basic_string(False)
        if self.peek() == APOS:
            return self.parse_literal_string(False)
        var start = self.pos
        while not self.eof() and is_bare_key_char(self.peek()):
            self.pos += 1
        if self.pos == start:
            self.fail("expected a key")
        return self.slice_str(start, self.pos)

    def parse_keyval_line(mut self, table_idx: Int) raises:
        var segments = self.parse_key_path()
        self.skip_line_ws()
        if self.peek() != EQUALS:
            self.fail("expected '='")
        self.pos += 1
        self.skip_line_ws()
        var value_idx = self.parse_value()
        self.set_key_path(table_idx, segments, value_idx)

    def set_key_path(mut self, table_idx: Int, segments: List[String], value_idx: Int) raises:
        var cur = table_idx
        for si in range(len(segments) - 1):
            var key = segments[si]
            var existing = self.doc.find_key(cur, key)
            if existing < 0:
                var n = TomlNode()
                n.kind = KIND_TABLE
                n.dotted_closed = True
                var idx = self.doc.push(n^)
                self.doc.add_key(cur, key, idx)
                cur = idx
            else:
                var kind = self.doc.pool[existing].kind
                if kind != KIND_TABLE or self.doc.pool[existing].header_closed:
                    self.fail("cannot extend '" + key + "' with a dotted key")
                cur = existing
        var last = segments[len(segments) - 1]
        if self.doc.find_key(cur, last) >= 0:
            self.fail("duplicate key '" + last + "'")
        self.doc.add_key(cur, last, value_idx)

    # ---- values ----

    def parse_value(mut self) raises -> Int:
        if self.eof():
            self.fail("expected a value")
        var c = self.peek()
        if c == QUOTE:
            var s = self.parse_basic_string(True)
            var n = TomlNode()
            n.kind = KIND_STRING
            n.s = s
            return self.doc.push(n^)
        if c == APOS:
            var s = self.parse_literal_string(True)
            var n = TomlNode()
            n.kind = KIND_STRING
            n.s = s
            return self.doc.push(n^)
        if c == LBRACKET:
            return self.parse_array()
        if c == LBRACE:
            return self.parse_inline_table()
        if c == UInt8(116):  # t
            self.expect_literal("true")
            var n = TomlNode()
            n.kind = KIND_BOOL
            n.b = True
            return self.doc.push(n^)
        if c == UInt8(102):  # f
            self.expect_literal("false")
            var n = TomlNode()
            n.kind = KIND_BOOL
            n.b = False
            return self.doc.push(n^)
        return self.parse_number_or_datetime()

    def expect_literal(mut self, lit: String) raises:
        var lb = lit.as_bytes()
        for i in range(len(lb)):
            if self.peek_at(i) != lb[i]:
                self.fail("invalid literal, expected '" + lit + "'")
        self.pos += len(lb)

    # ---- strings ----

    def parse_basic_string(mut self, multiline_allowed: Bool) raises -> String:
        self.pos += 1  # opening quote
        var is_multi = False
        if multiline_allowed and self.peek() == QUOTE and self.peek_at(1) == QUOTE:
            is_multi = True
            self.pos += 2
            if self.peek() == CR and self.peek_at(1) == NEWLINE:
                self.pos += 2
            elif self.peek() == NEWLINE:
                self.pos += 1
        var out: List[UInt8] = []
        while True:
            if self.eof():
                self.fail("unterminated string")
            var c = self.peek()
            if c == QUOTE:
                if is_multi:
                    if self.peek_at(1) == QUOTE and self.peek_at(2) == QUOTE:
                        self.pos += 3
                        var extra = 0
                        while extra < 2 and self.peek() == QUOTE:
                            out.append(QUOTE)
                            self.pos += 1
                            extra += 1
                        break
                    else:
                        out.append(QUOTE)
                        self.pos += 1
                else:
                    self.pos += 1
                    break
            elif c == BACKSLASH:
                self.pos += 1
                if self.eof():
                    self.fail("bad escape sequence")
                var e = self.peek()
                if is_multi and (e == NEWLINE or e == CR or e == SPACE or e == TAB):
                    var p2 = self.pos
                    while p2 < len(self.data) and (self.data[p2] == SPACE or self.data[p2] == TAB):
                        p2 += 1
                    var saw_nl = False
                    if p2 < len(self.data) and self.data[p2] == NEWLINE:
                        p2 += 1
                        saw_nl = True
                    elif p2 + 1 < len(self.data) and self.data[p2] == CR and self.data[p2 + 1] == NEWLINE:
                        p2 += 2
                        saw_nl = True
                    if not saw_nl:
                        self.fail("invalid escape sequence")
                    self.pos = p2
                    while not self.eof() and (self.peek() == SPACE or self.peek() == TAB or self.peek() == NEWLINE or (self.peek() == CR and self.peek_at(1) == NEWLINE)):
                        if self.peek() == CR:
                            self.pos += 2
                        else:
                            self.pos += 1
                    continue
                if e == UInt8(110):  # n
                    out.append(NEWLINE)
                elif e == UInt8(116):  # t
                    out.append(TAB)
                elif e == UInt8(114):  # r
                    out.append(CR)
                elif e == UInt8(98):  # b
                    out.append(8)
                elif e == UInt8(102):  # f
                    out.append(12)
                elif e == QUOTE:
                    out.append(QUOTE)
                elif e == BACKSLASH:
                    out.append(BACKSLASH)
                elif e == UInt8(101):  # e (TOML 1.1)
                    out.append(27)
                elif e == UInt8(120):  # x (TOML 1.1)
                    var cp = self.read_hex_escape(2)
                    append_utf8(out, cp)
                elif e == UInt8(117):  # u
                    var cp = self.read_hex_escape(4)
                    append_utf8(out, cp)
                elif e == UInt8(85):  # U
                    var cp = self.read_hex_escape(8)
                    append_utf8(out, cp)
                else:
                    self.fail("invalid escape character")
                self.pos += 1
            elif c == NEWLINE:
                if not is_multi:
                    self.fail("unescaped newline in string")
                out.append(NEWLINE)
                self.pos += 1
            elif c == CR:
                if is_multi and self.peek_at(1) == NEWLINE:
                    out.append(CR)
                    out.append(NEWLINE)
                    self.pos += 2
                else:
                    self.fail("bare carriage return")
            elif is_forbidden_control(c):
                self.fail("control character in string")
            else:
                out.append(c)
                self.pos += 1
        return String(from_utf8=Span(out))

    def read_hex_escape(mut self, ndigits: Int) raises -> Int:
        var cp = 0
        for _ in range(ndigits):
            self.pos += 1
            if self.eof() or not is_hex_digit(self.peek()):
                self.fail("invalid unicode escape")
            cp = cp * 16 + hex_val(self.peek())
        if cp >= 0xD800 and cp <= 0xDFFF:
            self.fail("escape encodes a surrogate")
        if cp > 0x10FFFF:
            self.fail("escape codepoint out of range")
        return cp

    def parse_literal_string(mut self, multiline_allowed: Bool) raises -> String:
        self.pos += 1  # opening apostrophe
        var is_multi = False
        if multiline_allowed and self.peek() == APOS and self.peek_at(1) == APOS:
            is_multi = True
            self.pos += 2
            if self.peek() == CR and self.peek_at(1) == NEWLINE:
                self.pos += 2
            elif self.peek() == NEWLINE:
                self.pos += 1
        var out: List[UInt8] = []
        while True:
            if self.eof():
                self.fail("unterminated string")
            var c = self.peek()
            if c == APOS:
                if is_multi:
                    if self.peek_at(1) == APOS and self.peek_at(2) == APOS:
                        self.pos += 3
                        var extra = 0
                        while extra < 2 and self.peek() == APOS:
                            out.append(APOS)
                            self.pos += 1
                            extra += 1
                        break
                    else:
                        out.append(APOS)
                        self.pos += 1
                else:
                    self.pos += 1
                    break
            elif c == NEWLINE:
                if not is_multi:
                    self.fail("unescaped newline in string")
                out.append(NEWLINE)
                self.pos += 1
            elif c == CR:
                if is_multi and self.peek_at(1) == NEWLINE:
                    out.append(CR)
                    out.append(NEWLINE)
                    self.pos += 2
                else:
                    self.fail("bare carriage return")
            elif is_forbidden_control(c):
                self.fail("control character in string")
            else:
                out.append(c)
                self.pos += 1
        return String(from_utf8=Span(out))

    # ---- arrays / inline tables ----

    def skip_array_ws(mut self) raises:
        while True:
            if self.eof():
                return
            var c = self.peek()
            if c == SPACE or c == TAB:
                self.pos += 1
            elif c == NEWLINE:
                self.pos += 1
            elif c == CR and self.peek_at(1) == NEWLINE:
                self.pos += 2
            elif c == HASH:
                self.skip_comment_if_any()
            else:
                return

    def parse_array(mut self) raises -> Int:
        self.pos += 1
        var n = TomlNode()
        n.kind = KIND_ARRAY
        self.skip_array_ws()
        if self.peek() == RBRACKET:
            self.pos += 1
            return self.doc.push(n^)
        var items: List[Int] = []
        while True:
            self.skip_array_ws()
            var v = self.parse_value()
            items.append(v)
            self.skip_array_ws()
            if self.peek() == COMMA:
                self.pos += 1
                self.skip_array_ws()
                if self.peek() == RBRACKET:
                    self.pos += 1
                    break
                continue
            if self.peek() == RBRACKET:
                self.pos += 1
                break
            self.fail("expected ',' or ']'")
        n.kids = items^
        return self.doc.push(n^)

    def parse_inline_table(mut self) raises -> Int:
        self.pos += 1
        var n = TomlNode()
        n.kind = KIND_TABLE
        n.header_closed = True
        n.inline_closed = True
        var idx = self.doc.push(n^)
        # TOML 1.1: newlines, comments and a trailing comma are allowed inside
        self.skip_array_ws()
        if self.peek() == RBRACE:
            self.pos += 1
            return idx
        while True:
            self.skip_array_ws()
            var segments = self.parse_key_path()
            self.skip_line_ws()
            if self.peek() != EQUALS:
                self.fail("expected '=' in inline table")
            self.pos += 1
            self.skip_line_ws()
            var v = self.parse_value()
            self.set_key_path(idx, segments, v)
            self.skip_array_ws()
            if self.peek() == COMMA:
                self.pos += 1
                self.skip_array_ws()
                if self.peek() == RBRACE:
                    self.pos += 1
                    break
                continue
            if self.peek() == RBRACE:
                self.pos += 1
                break
            self.fail("expected ',' or '}' in inline table")
        return idx

    # ---- numbers and datetimes ----

    def is_token_char(self, c: UInt8) -> Bool:
        return is_digit(c) or is_alpha(c) or c == PLUS or c == DASH or c == DOT or c == COLON or c == UNDERSCORE

    def parse_number_or_datetime(mut self) raises -> Int:
        var start = self.pos
        while not self.eof() and self.is_token_char(self.peek()):
            self.pos += 1
        if self.pos == start:
            self.fail("expected a value")
        var tok = self.slice_str(start, self.pos)

        if self.looks_like_date(tok):
            var full = tok
            if self.peek() == SPACE and self.peek_at(1) != 0 and is_digit(self.peek_at(1)):
                var save = self.pos
                self.pos += 1
                var tstart = self.pos
                while not self.eof() and self.is_token_char(self.peek()):
                    self.pos += 1
                if self.pos > tstart:
                    full = full + " " + self.slice_str(tstart, self.pos)
                else:
                    self.pos = save
            return self.finish_datetime(full, start)

        return self.finish_number(tok, start)

    def slice_str(self, a: Int, b: Int) raises -> String:
        return String(from_utf8=Span(self.data)[a:b])

    def looks_like_date(self, tok: String) -> Bool:
        var b = tok.as_bytes()
        if len(b) < 5:
            return False
        # local-time shape: DD:DD[:DD]... (seconds optional in TOML 1.1)
        if is_digit(b[0]) and is_digit(b[1]) and b[2] == COLON:
            return True
        # date shape: DDDD-DD-DD...
        if len(b) >= 10 and is_digit(b[0]) and is_digit(b[1]) and is_digit(b[2]) and is_digit(b[3]) and b[4] == DASH and is_digit(b[5]) and is_digit(b[6]) and b[7] == DASH:
            return True
        return False

    def finish_datetime(mut self, text: String, start: Int) raises -> Int:
        var b = bytes_list(text)
        var n = TomlNode()
        n.kind = KIND_DATETIME
        if b[2] == COLON:
            add_seconds(b, 0)
        elif len(b) > 10:
            add_seconds(b, 11)
        n.s = String(from_utf8=Span(b))

        if b[2] == COLON:
            # local-time only
            self.validate_time(b, 0, len(b), start)
            n.dt_kind = TIME_LOCAL
            return self.doc.push(n^)

        # date part
        self.validate_date(b, 0, start)
        if len(b) == 10:
            n.dt_kind = DATE_LOCAL
            return self.doc.push(n^)
        if len(b) < 12 or (b[10] != UInt8(84) and b[10] != UInt8(116) and b[10] != SPACE):
            self.fail_at(start, "malformed datetime")
        var tpos = 11
        var tend = len(b)
        # find end of time-secfrac before offset marker
        var i = tpos
        var offset_start = -1
        while i < tend:
            var c = b[i]
            if c == UInt8(90) or c == UInt8(122) or c == PLUS:
                offset_start = i
                break
            if c == DASH and i > tpos:
                offset_start = i
                break
            i += 1
        var time_end = tend
        if offset_start >= 0:
            time_end = offset_start
        self.validate_time(b, tpos, time_end, start)
        if offset_start < 0:
            n.dt_kind = DATETIME_LOCAL
            return self.doc.push(n^)
        n.dt_kind = DATETIME_OFFSET
        self.validate_offset(b, offset_start, len(b), start)
        return self.doc.push(n^)

    def fail_at(self, at: Int, msg: String) raises:
        raise Error("toml: " + msg + " at line " + self.line_col(at))

    def validate_date(self, b: List[UInt8], off: Int, start: Int) raises:
        if len(b) < off + 10:
            self.fail_at(start, "malformed date")
        if not (is_digit(b[off]) and is_digit(b[off + 1]) and is_digit(b[off + 2]) and is_digit(b[off + 3])):
            self.fail_at(start, "malformed date")
        if b[off + 4] != DASH or b[off + 7] != DASH:
            self.fail_at(start, "malformed date")
        if not (is_digit(b[off + 5]) and is_digit(b[off + 6])):
            self.fail_at(start, "malformed date")
        if not (is_digit(b[off + 8]) and is_digit(b[off + 9])):
            self.fail_at(start, "malformed date")
        var year = (Int(b[off]) - 48) * 1000 + (Int(b[off + 1]) - 48) * 100 + (Int(b[off + 2]) - 48) * 10 + (Int(b[off + 3]) - 48)
        var month = (Int(b[off + 5]) - 48) * 10 + (Int(b[off + 6]) - 48)
        var day = (Int(b[off + 8]) - 48) * 10 + (Int(b[off + 9]) - 48)
        if month < 1 or month > 12:
            self.fail_at(start, "invalid month")
        if day < 1 or day > days_in_month(year, month):
            self.fail_at(start, "invalid day")

    def validate_time(self, b: List[UInt8], off: Int, end: Int, start: Int) raises:
        if end - off < 8:
            self.fail_at(start, "malformed time")
        if not (is_digit(b[off]) and is_digit(b[off + 1]) and b[off + 2] == COLON and is_digit(b[off + 3]) and is_digit(b[off + 4]) and b[off + 5] == COLON and is_digit(b[off + 6]) and is_digit(b[off + 7])):
            self.fail_at(start, "malformed time")
        var hour = (Int(b[off]) - 48) * 10 + (Int(b[off + 1]) - 48)
        var minute = (Int(b[off + 3]) - 48) * 10 + (Int(b[off + 4]) - 48)
        var sec = (Int(b[off + 6]) - 48) * 10 + (Int(b[off + 7]) - 48)
        if hour > 23:
            self.fail_at(start, "invalid hour")
        if minute > 59:
            self.fail_at(start, "invalid minute")
        if sec > 60:
            self.fail_at(start, "invalid second")
        var i = off + 8
        if i < end:
            if b[i] != DOT:
                self.fail_at(start, "malformed time fraction")
            i += 1
            var digits = 0
            while i < end and is_digit(b[i]):
                i += 1
                digits += 1
            if digits == 0:
                self.fail_at(start, "malformed time fraction")
        if i != end:
            self.fail_at(start, "malformed time")

    def validate_offset(self, b: List[UInt8], off: Int, end: Int, start: Int) raises:
        if b[off] == UInt8(90) or b[off] == UInt8(122):
            if off + 1 != end:
                self.fail_at(start, "malformed offset")
            return
        if end - off != 6:
            self.fail_at(start, "malformed offset")
        if b[off] != PLUS and b[off] != DASH:
            self.fail_at(start, "malformed offset")
        if not (is_digit(b[off + 1]) and is_digit(b[off + 2]) and b[off + 3] == COLON and is_digit(b[off + 4]) and is_digit(b[off + 5])):
            self.fail_at(start, "malformed offset")
        var oh = (Int(b[off + 1]) - 48) * 10 + (Int(b[off + 2]) - 48)
        var om = (Int(b[off + 4]) - 48) * 10 + (Int(b[off + 5]) - 48)
        if oh > 23 or om > 59:
            self.fail_at(start, "invalid offset")

    def finish_number(mut self, tok: String, start: Int) raises -> Int:
        var b = bytes_list(tok)
        var n = len(b)
        if n == 0:
            self.fail_at(start, "expected a value")
        var i = 0
        var neg = False
        if b[0] == PLUS or b[0] == DASH:
            neg = b[0] == DASH
            i = 1

        if i < n and (b[i] == UInt8(105) or b[i] == UInt8(73)):  # inf
            if self.match_lit(b, i, n, "inf"):
                var node = TomlNode()
                node.kind = KIND_FLOAT
                node.f = -Float64(1.0) / 0.0 if neg else Float64(1.0) / 0.0
                node.s = tok
                return self.doc.push(node^)
            self.fail_at(start, "invalid value")
        if i < n and b[i] == UInt8(110):  # nan
            if self.match_lit(b, i, n, "nan"):
                var node = TomlNode()
                node.kind = KIND_FLOAT
                node.f = Float64(0.0) / 0.0
                node.s = tok
                return self.doc.push(node^)
            self.fail_at(start, "invalid value")

        if i >= n or not is_digit(b[i]):
            self.fail_at(start, "invalid number")

        if b[i] == UInt8(48) and i + 1 < n and (b[i + 1] == UInt8(120) or b[i + 1] == UInt8(111) or b[i + 1] == UInt8(98)):
            if neg or (i == 1):
                self.fail_at(start, "sign not allowed on based integer")
            var radix_char = b[i + 1]
            var radix = 16
            if radix_char == UInt8(111):
                radix = 8
            elif radix_char == UInt8(98):
                radix = 2
            var digits = self.collect_underscored_digits(b, i + 2, n, radix, start)
            if len(digits) == 0:
                self.fail_at(start, "empty based integer")
            var consumed = i + 2
            while consumed < n and (self.digit_value(b[consumed], radix) >= 0 or b[consumed] == UNDERSCORE):
                consumed += 1
            if consumed != n:
                self.fail_at(start, "invalid digit for base " + String(radix))
            var value: Int64 = 0
            for d in digits:
                value = value * Int64(radix) + Int64(d)
            var node = TomlNode()
            node.kind = KIND_INTEGER
            node.i = value
            node.s = tok
            return self.doc.push(node^)

        # decimal integer or float
        var digits1 = self.collect_underscored_digits(b, i, n, 10, start)
        if len(digits1) > 1 and digits1[0] == 0:
            self.fail_at(start, "leading zero in number")
        var j = i
        while j < n and (is_digit(b[j]) or b[j] == UNDERSCORE):
            j += 1

        var is_float = False
        if j < n and b[j] == DOT:
            is_float = True
            j += 1
            var fstart = j
            _ = self.collect_underscored_digits(b, j, n, 10, start)
            var jj = j
            while jj < n and (is_digit(b[jj]) or b[jj] == UNDERSCORE):
                jj += 1
            if jj == fstart:
                self.fail_at(start, "malformed float")
            j = jj
        if j < n and (b[j] == UInt8(101) or b[j] == UInt8(69)):
            is_float = True
            j += 1
            if j < n and (b[j] == PLUS or b[j] == DASH):
                j += 1
            var estart = j
            _ = self.collect_underscored_digits(b, j, n, 10, start)
            var jj2 = j
            while jj2 < n and (is_digit(b[jj2]) or b[jj2] == UNDERSCORE):
                jj2 += 1
            if jj2 == estart:
                self.fail_at(start, "malformed float exponent")
            j = jj2
        if j != n:
            self.fail_at(start, "malformed number")

        if not is_float:
            var value: Int64 = 0
            for d in digits1:
                value = value * 10 + Int64(d)
            if neg:
                value = -value
            var node = TomlNode()
            node.kind = KIND_INTEGER
            node.i = value
            node.s = tok
            return self.doc.push(node^)

        var clean: List[UInt8] = []
        var clean_start = 1 if (n > 0 and b[0] == PLUS) else 0
        for k in range(clean_start, n):
            if b[k] != UNDERSCORE:
                clean.append(b[k])
        var clean_str = String(from_utf8=Span(clean))
        var result = Float64(clean_str)
        var node = TomlNode()
        node.kind = KIND_FLOAT
        node.f = result
        node.s = tok
        return self.doc.push(node^)

    def match_lit(self, b: List[UInt8], i: Int, n: Int, lit: String) -> Bool:
        var lb = lit.as_bytes()
        if n - i != len(lb):
            return False
        for k in range(len(lb)):
            if b[i + k] != lb[k]:
                return False
        return True

    def collect_underscored_digits(self, b: List[UInt8], start: Int, n: Int, radix: Int, tokstart: Int) raises -> List[Int]:
        var out: List[Int] = []
        var i = start
        var prev_underscore = False
        var any_digit = False
        while i < n:
            var c = b[i]
            var v = self.digit_value(c, radix)
            if v >= 0:
                out.append(v)
                any_digit = True
                prev_underscore = False
                i += 1
            elif c == UNDERSCORE:
                if not any_digit or prev_underscore:
                    self.fail_at(tokstart, "misplaced underscore")
                prev_underscore = True
                i += 1
            else:
                break
        if prev_underscore:
            self.fail_at(tokstart, "trailing underscore")
        return out^

    def digit_value(self, c: UInt8, radix: Int) -> Int:
        if radix == 16:
            return hex_val(c)
        if radix == 10:
            if is_digit(c):
                return Int(c) - 48
            return -1
        if radix == 8:
            if c >= 48 and c <= 55:
                return Int(c) - 48
            return -1
        if radix == 2:
            if c == 48 or c == 49:
                return Int(c) - 48
            return -1
        return -1


def parse(text: String) raises -> TomlValue:
    var p = Parser(bytes_list(text))
    return p.parse()
