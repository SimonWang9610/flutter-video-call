import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class RTCView extends StatelessWidget {
  final String type;
  final RTCVideoRenderer render;
  final bool canPreview;
  final bool isMainView;

  const RTCView({
    Key? key,
    required this.type,
    required this.render,
    required this.canPreview,
    this.isMainView = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final size = isMainView ? screenSize * 0.8 : screenSize * 0.3;

    return type == 'audio' ? _buildAudioView(size) : _buildVideoView(size);
  }

  Widget _buildAudioView(Size size) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: RTCVideoView(render),
    );
  }

  Widget _buildVideoView(Size size) {
    return canPreview
        ? SizedBox(
            width: size.width,
            height: size.height,
            child: RTCVideoView(render),
          )
        : const CircularProgressIndicator();
  }
}
