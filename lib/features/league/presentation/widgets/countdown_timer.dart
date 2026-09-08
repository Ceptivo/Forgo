import 'dart:async';

import 'package:flutter/material.dart';

/// Ticks once a second, showing the time remaining until [target]. Once
/// [target] has passed it shows "Dropping now" and calls [onZero] once
/// (a caller can use that to refresh the next day's data).
class CountdownTimer extends StatefulWidget {
  const CountdownTimer({super.key, required this.target, this.onZero});

  final DateTime target;
  final VoidCallback? onZero;

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _timer;
  bool _firedZero = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      final remaining = widget.target.difference(DateTime.now().toUtc());
      if (!_firedZero && !remaining.isNegative) return;
      if (!_firedZero) {
        _firedZero = true;
        widget.onZero?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.target.difference(DateTime.now().toUtc());
    if (remaining.isNegative) {
      return Text(
        'Dropping now…',
        style: Theme.of(context).textTheme.titleMedium,
      );
    }
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    final text =
        '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontFeatures: const [
        FontFeature.tabularFigures(),
      ]),
    );
  }
}
