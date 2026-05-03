import 'package:flutter/material.dart';

class PlayerControls extends StatefulWidget {
  final bool isPlaying;
  final bool showSpeedSlider;
  final double speed;
  final Duration position;
  final Duration duration;
  final bool isLocked;
  final bool showLock;

  final VoidCallback onPlayPause;
  final Function(double) onSeekStart;
  final Function(double) onSeekUpdate;
  final Function(double) onSeek;
  final Function(double) onSpeedChange;
  final VoidCallback onToggleSpeed;
  final VoidCallback onToggleLock;

  const PlayerControls({
    super.key,
    required this.isPlaying,
    required this.showSpeedSlider,
    required this.speed,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeek,
    required this.onSpeedChange,
    required this.onToggleSpeed,
    required this.isLocked,
    required this.showLock,
    required this.onToggleLock,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  // FIX: local drag value so thumb doesn't snap back during drag
  double? _dragValue;

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final double maxVal =
    widget.duration.inSeconds > 0
        ? widget.duration.inSeconds.toDouble()
        : 1.0;

    // While dragging use local value, otherwise use playback position
    final double curVal =
    (_dragValue ?? widget.position.inSeconds.toDouble()).clamp(0.0, maxVal);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // SEEK BAR
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.0,
                  activeTrackColor: const Color(0xFF9D00FF),
                  inactiveTrackColor: Colors.white30,
                  thumbColor: const Color(0xFF9D00FF),
                  overlayColor: const Color(0x339D00FF),
                  thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                  overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14.0),
                ),
                child: Slider(
                  value: curVal,
                  min: 0,
                  max: maxVal,
                  onChangeStart: (v) {
                    setState(() => _dragValue = v);
                    widget.onSeekStart(v);
                  },
                  onChanged: (v) {
                    setState(() => _dragValue = v);
                    widget.onSeekUpdate(v);
                  },
                  onChangeEnd: (v) {
                    setState(() => _dragValue = null);
                    widget.onSeek(v);
                  },
                ),
              ),

              // TIME
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _format(widget.position),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      _format(widget.duration),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 2),

              // CONTROLS ROW
              Row(
                children: [
                  // LOCK
                  if (widget.showLock)
                    IconButton(
                      icon: Icon(
                        widget.isLocked ? Icons.lock : Icons.lock_open,
                        color: const Color(0xFF9D00FF),
                        size: 22,
                      ),
                      onPressed: widget.onToggleLock,
                    ),

                  // BACK 10
                  IconButton(
                    icon: const Icon(Icons.replay_10,
                        color: Color(0xFF9D00FF), size: 26),
                    onPressed: () {
                      final t = widget.position.inSeconds - 10;
                      widget.onSeek(t < 0 ? 0 : t.toDouble());
                    },
                  ),

                  // PLAY/PAUSE
                  IconButton(
                    icon: Icon(
                      widget.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: const Color(0xFF9D00FF),
                      size: 42,
                    ),
                    onPressed: widget.onPlayPause,
                  ),

                  // FORWARD 10
                  IconButton(
                    icon: const Icon(Icons.forward_10,
                        color: Color(0xFF9D00FF), size: 26),
                    onPressed: () {
                      final t = widget.position.inSeconds + 10;
                      widget.onSeek(t > widget.duration.inSeconds
                          ? widget.duration.inSeconds.toDouble()
                          : t.toDouble());
                    },
                  ),

                  const Spacer(),

                  // SPEED BADGE
                  GestureDetector(
                    onTap: widget.onToggleSpeed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D00FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                            const Color(0xFF9D00FF).withOpacity(0.5)),
                      ),
                      child: Text(
                        '${widget.speed.toStringAsFixed(2)}x',
                        style: const TextStyle(
                          color: Color(0xFF9D00FF),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // SPEED SLIDER
              if (widget.showSpeedSlider)
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.0,
                    activeTrackColor: const Color(0xFF9D00FF),
                    inactiveTrackColor: Colors.white24,
                    thumbColor: const Color(0xFF9D00FF),
                  ),
                  child: Slider(
                    value: widget.speed,
                    min: 0.25,
                    max: 4.0,
                    divisions: 15,
                    label: '${widget.speed.toStringAsFixed(2)}x',
                    onChanged: widget.onSpeedChange,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
