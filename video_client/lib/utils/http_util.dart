import 'dart:convert';
import 'package:http/http.dart' as http;

class HttpUtil {
  static const _baseUri = 'http://192.168.2.136:8888';

  Future<Map<String, dynamic>> getTokenWithAccount(
      String account, String channelName) async {
    final data = {
      'account': account,
      'channelName': channelName,
    };

    final url = Uri.parse('$_baseUri/accountToken');
    final res = await http.post(
      url,
      body: json.encode(data),
      headers: {
        'Content-Type': 'application/json',
      },
    );
    return json.decode(res.body);
  }

  Future<Map<String, dynamic>> getToken(String channelName) async {
    final data = {
      'channelName': channelName,
    };

    final url = Uri.parse('$_baseUri/uidToken');
    final res = await http.post(
      url,
      body: json.encode(data),
      headers: {
        'Content-Type': 'application/json',
      },
    );
    return json.decode(res.body);
  }

  Future<Map<String, dynamic>> createCallingChannel() async {
    final url = Uri.parse('$_baseUri/call/createChannel');

    final res = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
    );

    return json.decode(res.body);
  }

  Future<void> callOneToOne(
      String caller, String callee, String channel) async {
    final data = {
      'caller': caller,
      'callee': callee,
      'channel': channel,
    };

    final url = Uri.parse('$_baseUri/call/oneToOne');
    final res = await http.post(
      url,
      body: json.encode(data),
      headers: {
        'Content-Type': 'application/json',
      },
    );
    return json.decode(res.body);
  }

  Future<Map<String, dynamic>> login() async {
    final url = Uri.parse(_baseUri + '/login');

    final res = await http.get(url);

    return json.decode(res.body);
  }

  Future<Map<String, dynamic>> createRoom(String type) async {
    final url = Uri.parse(_baseUri + '/createRoom');

    final data = {
      'type': type,
    };

    final res = await http.post(
      url,
      body: json.encode(data),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    return json.decode(res.body);
  }
}
