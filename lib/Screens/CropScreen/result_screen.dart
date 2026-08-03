import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResultScreen extends StatelessWidget {
  final MemoryImage image;

  const ResultScreen({
    required this.image,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Result'),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
                decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blueGrey.shade400,
                  Colors.blueGrey.shade600,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            )),
          ),
          Center(
            child: Image(
              image: image,
            ),
          ),
          Positioned(
            // Keep the design's 16pt gap and add the device's real bottom
            // inset — at a flat 16 the Back button sits under the gesture bar.
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            left: 16,
            right: 16,
            child: ElevatedButton(
              child: const Text('Back'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
