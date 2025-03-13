import 'package:flutter/material.dart';
import 'dart:async';

class TimeLeftDisplay extends StatefulWidget {
  final DateTime endTime;
  final VoidCallback? onComplete;

  const TimeLeftDisplay({
    super.key,
    required this.endTime,
    this.onComplete,
  });

  @override
  State<TimeLeftDisplay> createState() => _TimeLeftDisplayState();
}

class _TimeLeftDisplayState extends State<TimeLeftDisplay> {
  Timer? _timer;
  String _timeLeft = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    // Update immediately
    _updateTimeLeft();
    
    // Then update every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft();
    });
  }

  void _updateTimeLeft() {
    final now = DateTime.now();
    final difference = widget.endTime.difference(now);
    
    if (difference.isNegative) {
      setState(() => _timeLeft = '0s');
      _timer?.cancel();
      widget.onComplete?.call();
      return;
    }

    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    final seconds = difference.inSeconds.remainder(60);

    setState(() {
      if (hours > 0) {
        _timeLeft = '${hours}h ${minutes}m ${seconds}s';
      } else if (minutes > 0) {
        _timeLeft = '${minutes}m ${seconds}s';
      } else {
        _timeLeft = '${seconds}s';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(_timeLeft);
  }
}
