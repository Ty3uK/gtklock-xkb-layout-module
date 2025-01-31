const pango = @import("pango");

pub fn convertCString(input: [*]const u8) []const u8 {
    var len: usize = 0;
    while (input[len] != 0) : (len += 1) {}
    return input[0..len];
}

pub fn createFontSizeAttrList(newFontSize: c_int) *pango.AttrList {
    const list = pango.AttrList.new();
    const desc = pango.FontDescription.new();
    desc.setSize(newFontSize * pango.SCALE);
    const attr = pango.AttrFontDesc.new(desc);
    list.insert(attr);
    return list;
}
