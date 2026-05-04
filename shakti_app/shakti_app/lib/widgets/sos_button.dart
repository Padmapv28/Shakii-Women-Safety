import 'package:flutter/material.dart';

class SOSButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isActive;
  final AnimationController pulseController;

  const SOSButton({
    super.key,
    required this.onPressed,
    required this.isActive,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (_, child) {
        final scale = isActive
            ? 1.0 + pulseController.value * 0.08
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.orange[700] : Colors.red[700],
            boxShadow: [
              BoxShadow(
                color: (isActive ? Colors.orange : Colors.red)
                    .withOpacity(0.6),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sos, color: Colors.white, size: 72),
              Text(
                isActive ? 'SENDING...' : 'SOS',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
