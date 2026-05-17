// lib/widgets/map_controls.dart

import 'package:flutter/material.dart';

class MapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitAll;
  final VoidCallback onReload;
  final bool         loading;

  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitAll,
    required this.onReload,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 36,
      left: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(icon: Icons.add,         onTap: onZoomIn),
          const SizedBox(height: 8),
          _Btn(icon: Icons.remove,      onTap: onZoomOut),
          const SizedBox(height: 8),
          _Btn(icon: Icons.fit_screen,  onTap: onFitAll),
          const SizedBox(height: 8),
          _Btn(
            icon: loading ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
            onTap: loading ? () {} : onReload,
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData   icon;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: const Color(0xff0d1f0f).withOpacity(0.78),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xff1db954).withOpacity(0.22),
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: const Color(0xff9effc4), size: 20),
      ),
    );
  }
}
