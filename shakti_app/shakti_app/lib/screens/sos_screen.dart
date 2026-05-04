import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sos_service.dart';
import '../services/guardian_service.dart';
import '../widgets/sos_button.dart';

class SOSScreen extends ConsumerStatefulWidget {
  const SOSScreen({super.key});

  @override
  ConsumerState<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends ConsumerState<SOSScreen>
    with TickerProviderStateMixin {
  int _countdown = 5;
  bool _countingDown = false;
  Timer? _countdownTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onSOSPressed() {
    setState(() {
      _countingDown = true;
      _countdown = 5;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countingDown = false);
        SOSService.triggerSOS(source: 'manual');
        _showSOSActiveSheet();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _onCancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countingDown = false;
      _countdown = 5;
    });
  }

  void _showSOSActiveSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (_) => _SOSActiveSheet(onCancel: _onCancelSOS),
    );
  }

  Future<void> _onCancelSOS() async {
    Navigator.pop(context);
    // Will trigger face verification internally
    await SOSService._cancelWithVerification();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Emergency SOS',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Instructions
            Text(
              _countingDown
                  ? 'Sending SOS in $_countdown...'
                  : 'Hold to trigger SOS',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 32),

            // Big SOS Button
            SOSButton(
              onPressed: _countingDown ? null : _onSOSPressed,
              isActive: _countingDown,
              pulseController: _pulseController,
            ),

            const SizedBox(height: 32),

            // Cancel Countdown
            if (_countingDown)
              TextButton(
                onPressed: _onCancelCountdown,
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white70, fontSize: 18)),
              ),

            const Spacer(),

            // Quick info
            _buildInfoRow(
                Icons.sms, 'SMS to all guardians'),
            _buildInfoRow(
                Icons.location_on, 'Live GPS location shared'),
            _buildInfoRow(
                Icons.notifications, 'Push alerts sent'),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 32),
      child: Row(
        children: [
          Icon(icon, color: Colors.red[300], size: 18),
          const SizedBox(width: 12),
          Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}

class _SOSActiveSheet extends StatelessWidget {
  final VoidCallback onCancel;
  const _SOSActiveSheet({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red[900],
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_rounded, size: 64, color: Colors.white),
          const SizedBox(height: 16),
          const Text('SOS ACTIVE',
              style: TextStyle(color: Colors.white,
                  fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Guardians have been notified.\nHelp is on the way.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red[900]),
            onPressed: onCancel,
            child: const Text("I'm Safe — Cancel Alert"),
          ),
        ],
      ),
    );
  }
}
