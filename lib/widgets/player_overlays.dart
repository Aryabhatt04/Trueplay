import 'package:flutter/material.dart';

class PlayerOverlays extends StatelessWidget {
  final bool isLongPressing;
  final bool isSeeking;
  final bool isBrightness;
  final bool isVolume;
  final double speed;
  final double brightness;
  final double volume;

  const PlayerOverlays({
    super.key,
    required this.isLongPressing,
    required this.isSeeking,
    required this.isBrightness,
    required this.isVolume,
    required this.speed,
    required this.brightness,
    required this.volume,
  });

  Widget _buildPill({
    required IconData icon,
    required double value,
    required String label,
    required Alignment alignment,
  }) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          child: Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(height: 8),
                // Vertical bar
                SizedBox(
                  height: 80,
                  width: 4,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: value.clamp(0.0, 1.0),
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // LONG PRESS SPEED INDICATOR
        if (isLongPressing)
          Positioned(
            top: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fast_forward,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${speed.toStringAsFixed(2)}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // BRIGHTNESS PILL (left side, vertical)
        if (isBrightness)
          _buildPill(
            icon: brightness > 0.5
                ? Icons.brightness_high
                : Icons.brightness_low,
            value: brightness,
            label: '${(brightness * 100).round()}%',
            alignment: Alignment.centerLeft,
          ),

        // VOLUME PILL (right side, vertical)
        if (isVolume)
          _buildPill(
            icon: volume > 0.5
                ? Icons.volume_up
                : volume > 0
                    ? Icons.volume_down
                    : Icons.volume_off,
            value: volume,
            label: '${(volume * 100).round()}%',
            alignment: Alignment.centerRight,
          ),
      ],
    );
  }
}
