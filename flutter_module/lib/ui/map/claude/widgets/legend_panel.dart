// lib/widgets/legend_panel.dart

import 'dart:ui';
import 'package:flutter/material.dart';

class LegendPanel extends StatelessWidget {
  const LegendPanel({super.key});

  static const _items = [
    (_Color(0xff1db954), 'Mowed grass'),
    (_Color(0xffff3b3b), 'Obstacle'),
    (_Color(0xffffd700), 'Boundary'),
    (_Color(0xff546454), 'Unknown'),
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 36,
      right: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xff0d1f0f).withOpacity(0.72),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: _items.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9, height: 9,
                        decoration: BoxDecoration(
                          color: Color(e.$1.value),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        e.$2,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xffb8d8b8),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper: record storing a color int (avoids const Color issues in records)
final class _Color { // ignore: avoid_classes_with_only_static_members
  final int value;
  const _Color(this.value);
}
