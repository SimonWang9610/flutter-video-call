import 'contact_list.dart';
import '/utils/http_util.dart';
import '/utils/sotre_util.dart';
import 'package:flutter/material.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              height: 16,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: TextField(
                controller: _controller,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            TextButton(
              onPressed: _login,
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }

  void _login() async {
    if (_controller.text.isEmpty) return;

    final data = await HttpUtil().login();
    print('login: $data');
    print('username: ${_controller.text}');

    LocalStorage.write('userid', data['userid']);
    LocalStorage.write('username', _controller.text);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactList(
          userid: data['userid'],
          username: _controller.text,
        ),
      ),
    );
  }
}
