import 'dart:async';

import 'rtc_media_screen.dart';
import 'client_io.dart';
import 'contact_event.dart';
import '/utils/http_util.dart';
import 'package:flutter/material.dart';

class ContactList extends StatefulWidget {
  final String userid;
  final String username;
  const ContactList({
    Key? key,
    required this.userid,
    required this.username,
  }) : super(key: key);

  @override
  State<ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<ContactList> {
  final List<String> contacts = [];
  late final StreamSubscription<ContactEvent> _sub;

  bool isVideo = true;

  @override
  void initState() {
    super.initState();
    ClientIO().init(widget.userid, widget.username);

    ClientIO().rootContext = context;

    _sub = ClientIO().watchMain().listen((event) {
      print('listen contact event');

      final contact = event.username + ':' + event.userid;

      if (event.online) {
        if (contacts.contains(contact)) return;

        contacts.add(contact);
        setState(() {});
      } else {
        if (contacts.remove(contact)) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('online contacts'),
              const SizedBox(
                height: 20,
              ),
              TextButton(
                onPressed: () {
                  isVideo = true;
                },
                child: const Text('video call'),
              ),
              const SizedBox(
                height: 20,
              ),
              TextButton(
                onPressed: () => isVideo = false,
                child: const Text('audio call'),
              ),
              const SizedBox(
                height: 20,
              ),
              Expanded(
                child: contacts.isNotEmpty
                    ? ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (_, index) => GestureDetector(
                          child: SizedBox(
                            height: 100,
                            width: 200,
                            child: Card(
                              elevation: 5.0,
                              child: Text(contacts[index]),
                            ),
                          ),
                          onTap: () async {
                            final res = await HttpUtil()
                                .createRoom(isVideo ? 'video' : 'audio');
                            final String room = res['room'];
                            final String type = res['type'];

                            final callee = contacts[index].split(':').last;

                            print('callee: $callee');
                            print('room: $room');

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RTCVideo(
                                  room: room,
                                  callee: callee,
                                  caller: widget.userid,
                                  isCaller: true,
                                  type: type,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : const Text('No online contacts'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
