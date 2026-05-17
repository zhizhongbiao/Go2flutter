// lib/widgets/stats_hud.dart

import 'dart:ui';
import 'package:flutter/material.dart';

class StatsHud extends StatelessWidget {
  final int    pointCount;
  final String status;
  final double zoom;
  final int?   simMs;
  final int?   writeMs;

  const StatsHud({
    super.key,
    required this.pointCount,
    required this.status,
    required this.zoom,
    this.simMs,
    this.writeMs,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: const Color(0xff0d1f0f).withOpacity(0.72),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xff1db954).withOpacity(0.28),
              ),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: Color(0xff9effc4),
                height: 1.6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  const Text(
                    '⬤  LIDAR POINT CLOUD',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff52d46e),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _row('Points ', _fmtCount(pointCount)),
                  _row('Zoom   ', zoom.toStringAsFixed(1)),
                  _row('Status ', status),
                  if (simMs   != null) _row('Sim    ', '${simMs}ms'),
                  if (writeMs != null) _row('Write  ', '${writeMs}ms'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _row(String label, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(color: Color(0xff4a7a4a))),
      Text(value),
    ],
  );

  static String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
