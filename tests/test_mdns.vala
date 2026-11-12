// SPDX-License-Identifier: GPL-3.0-or-later

using Gradio;

void put_u16 (uint8[] buf, ref int n, int value) {
    buf[n++] = (uint8) (value >> 8);
    buf[n++] = (uint8) value;
}

void put_u32 (uint8[] buf, ref int n, int value) {
    buf[n++] = (uint8) (value >> 24);
    buf[n++] = (uint8) (value >> 16);
    buf[n++] = (uint8) (value >> 8);
    buf[n++] = (uint8) value;
}

void put_name (uint8[] buf, ref int n, string name) {
    foreach (var label in name.split (".")) {
        var raw = label.data;
        buf[n++] = (uint8) raw.length;
        for (int i = 0; i < raw.length; i++)
            buf[n++] = raw[i];
    }
    buf[n++] = 0;
}

void put_record (uint8[] buf, ref int n, string name, int type, uint8[] rdata) {
    put_name (buf, ref n, name);
    put_u16 (buf, ref n, type);
    put_u16 (buf, ref n, 1);
    put_u32 (buf, ref n, 120);
    put_u16 (buf, ref n, rdata.length);
    for (int i = 0; i < rdata.length; i++)
        buf[n++] = rdata[i];
}

uint8[] ptr_rdata (string target) {
    var rdata = new uint8[256];
    int n = 0;
    put_name (rdata, ref n, target);
    var result = new uint8[n];
    for (int i = 0; i < n; i++)
        result[i] = rdata[i];
    return result;
}

uint8[] srv_rdata (int port, string target) {
    var rdata = new uint8[256];
    int n = 0;
    put_u16 (rdata, ref n, 0);
    put_u16 (rdata, ref n, 0);
    put_u16 (rdata, ref n, port);
    put_name (rdata, ref n, target);
    var result = new uint8[n];
    for (int i = 0; i < n; i++)
        result[i] = rdata[i];
    return result;
}

uint8[] txt_rdata (string[] entries) {
    var rdata = new uint8[256];
    int n = 0;
    foreach (var entry in entries) {
        var raw = entry.data;
        rdata[n++] = (uint8) raw.length;
        for (int i = 0; i < raw.length; i++)
            rdata[n++] = raw[i];
    }
    var result = new uint8[n];
    for (int i = 0; i < n; i++)
        result[i] = rdata[i];
    return result;
}

uint8[] a_rdata (int a, int b, int c, int d) {
    return new uint8[] { (uint8) a, (uint8) b, (uint8) c, (uint8) d };
}

void test_mdns_decompress_name () {
    var data2 = new uint8[] {
        0x00, 0x00, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x07, '_', 'g', 'o', 'o', 'g', 'l', 'e', 0x00,
        0x04, 'c', 'a', 's', 't',
        0xc0, 0x0c
    };
    var name = Mdns.read_name (data2, 21);
    assert (name == "cast._google");
}

void test_mdns_parse_ptr () {
    // header: id 0, flags 0, qd=0, an=1; answer: name ptr->0x0c, PTR, class IN, ttl, rdlen, rdata ptr->0x0c
    var data = new uint8[] {
        0x00, 0x00, 0x84, 0x00, 0x00, 0x00, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00,
        0x04, 'c', 'a', 's', 't',
        0x00,
        0x00, 0x0c, 0x00, 0x01, 0x00, 0x00, 0x00, 0x3c,
        0x00, 0x02, 0xc0, 0x0c
    };
    var records = Mdns.parse_message (data);
    assert (records != null);
    var target = Mdns.read_name (data, 12);
    assert (target == "cast");
    assert (records.length == 1);
    assert (records.get (0).ptr_target == "cast");
}

void test_mdns_assemble_device () {
    const string service = "_googlecast._tcp.local";
    const string instance = "Nest._googlecast._tcp.local";
    const string host = "Nest.local";

    var packet = new uint8[512];
    int n = 0;
    // header: no questions, 4 additional records
    put_u16 (packet, ref n, 0); // id
    put_u16 (packet, ref n, 0); // flags
    put_u16 (packet, ref n, 0); // questions
    put_u16 (packet, ref n, 0); // answers
    put_u16 (packet, ref n, 0); // authority
    put_u16 (packet, ref n, 4); // additional

    put_record (packet, ref n, service, 12, ptr_rdata (instance));
    put_record (packet, ref n, instance, 33, srv_rdata (8009, host));
    put_record (packet, ref n, instance, 16, txt_rdata ({ "id=nest-1", "fn=Nest Mini", "md=Google Nest Mini" }));
    put_record (packet, ref n, host, 1, a_rdata (192, 168, 0, 20));

    var records = Mdns.parse_message (packet[0:n]);
    assert (records != null);
    assert (records.length == 4);

    var devices = Mdns.assemble_devices (records);
    assert (devices.length == 1);
    assert (devices.get (0).id == "nest-1");
    assert (devices.get (0).name == "Nest Mini");
    assert (devices.get (0).host == "192.168.0.20");
    assert (devices.get (0).port == 8009);
    assert (devices.get (0).model == "Google Nest Mini");
}

void test_mdns_assemble_without_txt () {
    const string instance = "Plain._googlecast._tcp.local";
    const string host = "Plain.local";

    var records = new GLib.GenericArray<MdnsRecord> ();
    var ptr = new MdnsRecord ();
    ptr.type = 12;
    ptr.ptr_target = instance;
    records.add (ptr);
    var srv = new MdnsRecord ();
    srv.type = 33;
    srv.name = instance;
    srv.srv_target = host;
    srv.port = 42000;
    records.add (srv);
    var a = new MdnsRecord ();
    a.type = 1;
    a.name = host;
    a.address = "10.0.0.2";
    records.add (a);

    var devices = Mdns.assemble_devices (records);
    assert (devices.length == 1);
    assert (devices.get (0).id == "Plain");
    assert (devices.get (0).name == "Plain");
    assert (devices.get (0).host == "10.0.0.2");
    assert (devices.get (0).port == 42000);
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/cast/mdns_parse_ptr", test_mdns_parse_ptr);
    Test.add_func ("/cast/mdns_decompress", test_mdns_decompress_name);
    Test.add_func ("/cast/mdns_assemble", test_mdns_assemble_device);
    Test.add_func ("/cast/mdns_assemble_no_txt", test_mdns_assemble_without_txt);
    return Test.run ();
}