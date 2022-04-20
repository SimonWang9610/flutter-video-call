import 'package:flutter/material.dart';

class VideoCalling extends StatelessWidget {
  final String username;
  const VideoCalling({
    Key? key,
    required this.username,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(
            height: 20,
          ),
          Text('Calling $username'),
          const SizedBox(
            height: 16,
          ),
          CircleAvatar(
            radius: 15,
            child: Text(
              username[0].toUpperCase(),
            ),
          )
        ],
      ),
    );
  }
}
