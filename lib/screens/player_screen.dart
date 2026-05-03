import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';


import '../widgets/player_controls.dart';
import '../widgets/player_overlays.dart';
import '../services/playback_service.dart';
import '../services/history_service.dart';
import '../services/subtitle_service.dart';
import '../models/subtitle_model.dart';

class PlayerScreen extends StatefulWidget {
  final String videoPath;

  const PlayerScreen({super.key, required this.videoPath});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;

  // Separate controller used only for seek-preview thumbnails
  VideoPlayerController? _previewController;
  bool _previewControllerReady = false;

  Timer? _hideTimer;
  Timer? _overlayHideTimer;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  double speed = 1.0;
  bool showControls = true;
  bool showSpeedSlider = false;
  bool isLocked = false;
  bool isLandscape = false;

  // SEEK PREVIEW
  Duration previewPosition = Duration.zero;
  bool showPreview = false;
  bool _isProgressBarSeeking = false;

  // SUBTITLES
  List<Subtitle> subtitles = [];
  String currentSubtitle = '';
  bool subtitlesEnabled = true; // NEW: lets the user turn subtitles off

  // GESTURE — brightness / volume
  double brightness = 0.5;
  double volume = 0.5;
  bool isBrightnessAdjusting = false;
  bool isVolumeAdjusting = false;

  // LONG PRESS
  bool isLongPressing = false;
  double longPressStartSpeed = 1.0;
  double? _longPressDragStartX;

  // DOUBLE TAP tracking
  Offset? _doubleTapPosition;

  int _lastUpdate = 0;

  // ZOOM
  double _scale = 1.0;
  double _baseScale = 1.0;


  // SCREENSHOT
  final GlobalKey _videoRepaintKey = GlobalKey();
  bool _isCapturing = false;

  // ─────────────────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    VolumeController().listener((v) {
      if (mounted) setState(() => volume = v);
    });
    VolumeController().getVolume().then((v) {
      if (mounted) setState(() => volume = v);
    });
    VolumeController().showSystemUI = false;

    ScreenBrightness().current.then((b) {
      if (mounted) setState(() => brightness = b);
    });

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    await _controller!.initialize();

    final saved = await PlaybackService.getPosition(widget.videoPath);
    if (saved > 0) {
      await _controller!.seekTo(Duration(seconds: saved));
    }

    await HistoryService.addToHistory(widget.videoPath);
    _autoLoadSubtitles();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller!.addListener(_onVideoUpdate);
    _controller!.play();
    _startHideTimer();
    if (mounted) setState(() {});

    // Spin up a second controller for seek-preview frames (non-blocking)
    _initPreviewController();
  }

  Future<void> _initPreviewController() async {
    try {
      final preview =
      VideoPlayerController.file(File(widget.videoPath));
      await preview.initialize();
      await preview.pause(); // keep it paused; we seek it manually
      if (mounted) {
        setState(() {
          _previewController = preview;
          _previewControllerReady = true;
        });
      } else {
        await preview.dispose();
      }
    } catch (_) {
      // Falls back to time-only preview if this fails
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _overlayHideTimer?.cancel();
    _controller?.removeListener(_onVideoUpdate);
    _controller?.pause();
    _controller?.dispose();
    _previewController?.dispose();

    VolumeController().removeListener();
    ScreenBrightness().resetScreenBrightness();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  VIDEO UPDATE LISTENER
  // ─────────────────────────────────────────────────────────────────────────

  void _onVideoUpdate() {
    if (!mounted) return;
    final newPos = _controller!.value.position;
    final newDur = _controller!.value.duration;

    if ((newPos.inSeconds - position.inSeconds).abs() >= 5) {
      PlaybackService.savePosition(widget.videoPath, newPos.inSeconds);
    }

    String newSub = '';
    if (subtitlesEnabled) {
      for (var sub in subtitles) {
        if (newPos >= sub.start && newPos <= sub.end) {
          newSub = sub.text;
          break;
        }
      }
    }

    if (newPos != position || newDur != duration || newSub != currentSubtitle) {
      setState(() {
        position = newPos;
        duration = newDur;
        currentSubtitle = newSub;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SUBTITLES
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _autoLoadSubtitles() async {
    final videoDir = p.dirname(widget.videoPath);
    final videoName = p.basenameWithoutExtension(widget.videoPath);

    final candidates = [
      p.join(videoDir, '$videoName.srt'),
      p.join(videoDir, '$videoName.vtt'),
      p.join(videoDir, '${p.basename(widget.videoPath)}.srt'),
    ];

    for (var path in candidates) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          final normalized =
          content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
          final parsed = SubtitleService.parseSRT(normalized);
          if (parsed.isNotEmpty) {
            if (mounted) {
              setState(() {
                subtitles = parsed;
                subtitlesEnabled = true;
              });
            }
            return;
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _loadSubtitles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
    );

    if (result != null && result.files.single.path != null) {
      try {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final normalized =
        content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        final parsed = SubtitleService.parseSRT(normalized);
        if (mounted) {
          setState(() {
            subtitles = parsed;
            subtitlesEnabled = true;
            currentSubtitle = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loaded ${parsed.length} subtitles')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load subtitle file')),
          );
        }
      }
    }
  }

  /// Called when the user taps the subtitle button.
  /// - If subtitles are loaded  → show a bottom-sheet menu (on/off/load new/remove)
  /// - If no subtitles loaded   → open the file picker directly
  void _onSubtitleButtonPressed() {
    if (subtitles.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1A1A2E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(
                  subtitlesEnabled ? Icons.subtitles_off : Icons.subtitles,
                  color: const Color(0xFF9D00FF),
                ),
                title: Text(
                  subtitlesEnabled
                      ? 'Turn off subtitles'
                      : 'Turn on subtitles',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    subtitlesEnabled = !subtitlesEnabled;
                    if (!subtitlesEnabled) currentSubtitle = '';
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open,
                    color: Color(0xFF9D00FF)),
                title: const Text(
                  'Load subtitle file…',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _loadSubtitles();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                title: const Text(
                  'Remove subtitles',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    subtitles = [];
                    subtitlesEnabled = true;
                    currentSubtitle = '';
                  });
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } else {
      _loadSubtitles();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CONTROLS HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isProgressBarSeeking && !isLocked) {
        setState(() => showControls = false);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });
  }

  void toggleRotation() {
    if (isLandscape) {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    setState(() => isLandscape = !isLandscape);
  }

  void setSpeed(double s) {
    s = (s * 4).round() / 4;
    s = s.clamp(0.25, 4.0);
    speed = s;
    _controller!.setPlaybackSpeed(s);
    setState(() {});
  }

  void _togglePlayPause() {
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
      _startHideTimer();
    }
    setState(() {});
  }

  String _formatTime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }

  void _setBrightness(double value) {
    brightness = value.clamp(0.0, 1.0);
    ScreenBrightness().setScreenBrightness(brightness).catchError((_) {});
  }

  void _setVolume(double value) {
    volume = value.clamp(0.0, 1.0);
    VolumeController().setVolume(volume);
  }

  void _hideOverlaysAfterDelay() {
    _overlayHideTimer?.cancel();
    _overlayHideTimer =
        Timer(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              isBrightnessAdjusting = false;
              isVolumeAdjusting = false;
            });
          }
        });
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.globalPosition;
  }

  void _onDoubleTap() {
    if (_doubleTapPosition == null || _controller == null) return;
    final screenWidth = MediaQuery.of(context).size.width;
    if (_doubleTapPosition!.dx < screenWidth / 2) {
      final target = position - const Duration(seconds: 10);
      _controller!.seekTo(
          target < Duration.zero ? Duration.zero : target);
    } else {
      final target = position + const Duration(seconds: 10);
      _controller!.seekTo(target > duration ? duration : target);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SEEK PREVIEW FRAME
  // ─────────────────────────────────────────────────────────────────────────

  // Throttled: only re-seek the preview controller when the target has
  // moved by more than 500 ms to avoid hammering the codec.
  void _updatePreviewFrame(Duration target) {
    if (!_previewControllerReady || _previewController == null) return;
    final current = _previewController!.value.position;
    if ((target - current).inMilliseconds.abs() > 500) {
      _previewController!.seekTo(target).catchError((_) {});
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SCREENSHOT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _takeScreenshot() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final boundary = _videoRepaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        _showSnack('Could not capture frame');
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showSnack('Screenshot failed');
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final fileName = 'trueplay_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsBytes(bytes);
      await SaverGallery.saveImage(
        bytes,
        fileName: fileName,
        androidRelativePath: 'Pictures/TruePlay',
        skipIfExists: false,
      );
      _showSnack('Screenshot saved to Gallery');
    } catch (e) {
      _showSnack('Screenshot error: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _resetZoom() {
    setState(() => _scale = 1.0);
  }
  // ─────────────────────────────────────────────────────────────────────────
  //  ZOOM
  // ─────────────────────────────────────────────────────────────────────────



  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildVideo() {
    return RepaintBoundary(
      key: _videoRepaintKey,
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  Widget _buildZoomableVideo() {
    return Transform.scale(
      scale: _scale,
      child: _buildVideo(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) {
          PlaybackService.savePosition(
              widget.videoPath, position.inSeconds);
          _controller?.pause();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,

          onDoubleTapDown: _onDoubleTapDown,
          onDoubleTap: isLocked ? null : _onDoubleTap,

          onTap: () {
            setState(() => showControls = !showControls);
            if (showControls) {
              if (!isLocked) {
                SystemChrome.setEnabledSystemUIMode(
                  SystemUiMode.manual,
                  overlays: SystemUiOverlay.values,
                );
              }
              _startHideTimer();
            } else {
              SystemChrome.setEnabledSystemUIMode(
                  SystemUiMode.immersiveSticky);
            }
          },

          onLongPressStart: (details) {
            if (!isLocked) {
              _longPressDragStartX = details.globalPosition.dx;
              setState(() {
                isLongPressing = true;
                longPressStartSpeed = speed;
                speed = 2.0;
                _controller!.setPlaybackSpeed(2.0);
              });
            }
          },

          onLongPressMoveUpdate: (details) {
            if (!isLocked &&
                isLongPressing &&
                _longPressDragStartX != null) {
              final dragDelta =
                  details.globalPosition.dx - _longPressDragStartX!;
              double newSpeed = 2.0 + (dragDelta / screenWidth) * 3.0;
              newSpeed = (newSpeed * 4).round() / 4;
              newSpeed = newSpeed.clamp(0.25, 4.0);
              if (newSpeed != speed) {
                setState(() {
                  speed = newSpeed;
                  _controller!.setPlaybackSpeed(speed);
                });
              }
            }
          },

          onLongPressEnd: (_) {
            if (isLongPressing) {
              _longPressDragStartX = null;
              setState(() {
                isLongPressing = false;
                speed = longPressStartSpeed;
                _controller!.setPlaybackSpeed(longPressStartSpeed);
              });
            }
          },

          onScaleStart: (details) {
            if (isLocked || isLongPressing) return;
            _baseScale = _scale;
            if (details.pointerCount == 1 && _scale <= 1.01) {
              previewPosition = position;
              _hideTimer?.cancel();
            }
          },

          onScaleUpdate: (details) {
            if (isLocked || isLongPressing) return;

            if (details.pointerCount >= 2) {
              // ZOOM LOGIC
              if (showPreview) {
                setState(() => showPreview = false);
              }
              final newScale = (_baseScale * details.scale).clamp(1.0, 4.0);
              if ((newScale - _scale).abs() > 0.01) {
                setState(() => _scale = newScale);
                _hideTimer?.cancel();
              }
            } else if (details.pointerCount == 1 && _scale <= 1.01) {
              // SLIDE LOGIC (Seek / Brightness / Volume)
              final now = DateTime.now().millisecondsSinceEpoch;
              if (now - _lastUpdate < 16) return;
              _lastUpdate = now;

              final dx = details.focalPointDelta.dx;
              final dy = details.focalPointDelta.dy;

              if (dx.abs() > dy.abs() || showPreview) {
                if (!showPreview) showPreview = true;
                final secondsPerPixel = 240.0 / screenWidth;
                previewPosition = previewPosition +
                    Duration(
                        milliseconds:
                            (dx * secondsPerPixel * 1000).toInt());
                previewPosition = Duration(
                  seconds: previewPosition.inSeconds
                      .clamp(0, duration.inSeconds),
                );
                _updatePreviewFrame(previewPosition);
                setState(() {});
              } else {
                if (details.focalPoint.dx < screenWidth / 2) {
                  _setBrightness(brightness - dy / 200);
                  isBrightnessAdjusting = true;
                  isVolumeAdjusting = false;
                } else {
                  _setVolume(volume - dy / 200);
                  isVolumeAdjusting = true;
                  isBrightnessAdjusting = false;
                }
                setState(() {});
              }
            }
          },

          onScaleEnd: (details) {
            if (isLocked || isLongPressing) return;
            if (showPreview) {
              _controller!.seekTo(previewPosition);
            }
            setState(() => showPreview = false);
            _hideOverlaysAfterDelay();
            _startHideTimer();
          },

          child: Stack(
            children: [
              // VIDEO (zoomable via InteractiveViewer)
              Center(child: _buildZoomableVideo()),

              // BACK + FILENAME
              if (showControls && !isLocked)
                Positioned(
                  top: 40,
                  left: 10,
                  right: 220,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            size: 28, color: Colors.white),
                        onPressed: () =>
                            Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          p.basename(widget.videoPath),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                  blurRadius: 8, color: Colors.black)
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // TOP RIGHT: screenshot, subtitles, speed, rotate
              if (showControls && !isLocked)
                Positioned(
                  top: 32,
                  right: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // SCREENSHOT
                      IconButton(
                        tooltip: 'Screenshot',
                        icon: _isCapturing
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.camera_alt,
                            color: Colors.white),
                        onPressed:
                        _isCapturing ? null : _takeScreenshot,
                      ),
                      // SUBTITLES — icon reflects loaded + enabled state
                      IconButton(
                        tooltip: 'Subtitles',
                        icon: Icon(
                          subtitles.isNotEmpty && subtitlesEnabled
                              ? Icons.subtitles
                              : subtitles.isNotEmpty && !subtitlesEnabled
                              ? Icons.subtitles_off
                              : Icons.subtitles_outlined,
                          color:
                          subtitles.isNotEmpty && subtitlesEnabled
                              ? const Color(0xFF9D00FF)
                              : Colors.white,
                        ),
                        onPressed: _onSubtitleButtonPressed,
                      ),
                      IconButton(
                        icon: const Icon(Icons.speed, color: Colors.white),
                        onPressed: () => setState(
                                () => showSpeedSlider = !showSpeedSlider),
                      ),
                      IconButton(
                        icon: const Icon(Icons.screen_rotation,
                            color: Colors.white),
                        onPressed: toggleRotation,
                      ),
                    ],
                  ),
                ),

              // SEEK PREVIEW BOX (now shows a real video frame)
              if (showPreview)
                Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _SeekPreviewBox(
                      previewPosition: previewPosition,
                      duration: duration,
                      formatTime: _formatTime,
                      previewController: _previewControllerReady
                          ? _previewController
                          : null,
                    ),
                  ),
                ),

              // SUBTITLE TEXT
              if (currentSubtitle.isNotEmpty && subtitlesEnabled)
                Positioned(
                  bottom: 110,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        currentSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),

              // BRIGHTNESS / VOLUME / SPEED OVERLAYS
              PlayerOverlays(
                isLongPressing: isLongPressing,
                isSeeking: showPreview,
                isBrightness: isBrightnessAdjusting,
                isVolume: isVolumeAdjusting,
                speed: speed,
                brightness: brightness,
                volume: volume,
              ),

              // BOTTOM CONTROLS
              if (!isLocked)
                IgnorePointer(
                  ignoring: !showControls,
                  child: AnimatedOpacity(
                    opacity: showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: PlayerControls(
                        isPlaying: _controller!.value.isPlaying,
                        showSpeedSlider: showSpeedSlider,
                        speed: speed,
                        position: position,
                        duration: duration,
                        isLocked: isLocked,
                        showLock: showControls,
                        onPlayPause: _togglePlayPause,
                        onSeekStart: (v) {
                          _hideTimer?.cancel();
                          final target = Duration(seconds: v.toInt());
                          _updatePreviewFrame(target);
                          setState(() {
                            _isProgressBarSeeking = true;
                            previewPosition = target;
                            showPreview = true;
                          });
                        },
                        onSeekUpdate: (v) {
                          final target = Duration(seconds: v.toInt());
                          _updatePreviewFrame(target);
                          setState(() {
                            previewPosition = target;
                            showPreview = true;
                          });
                        },
                        onSeek: (v) {
                          _controller!.seekTo(
                              Duration(seconds: v.toInt()));
                          setState(() {
                            _isProgressBarSeeking = false;
                            showPreview = false;
                          });
                          _startHideTimer();
                        },
                        onSpeedChange: setSpeed,
                        onToggleSpeed: () => setState(
                                () => showSpeedSlider = !showSpeedSlider),
                        onToggleLock: () {
                          setState(() {
                            isLocked = !isLocked;
                            showControls = true;
                          });
                          _startHideTimer();
                        },
                      ),
                    ),
                  ),
                ),

              // LOCK ICON (always visible when locked)
              if (isLocked)
                Positioned(
                  left: 16,
                  bottom: 40,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        isLocked = false;
                        showControls = true;
                      });
                      _startHideTimer();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock,
                              color: Color(0xFF9D00FF), size: 22),
                          SizedBox(width: 8),
                          Text('Tap to unlock',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),

              // ZOOM LEVEL HINT (tap to reset)
              if (_scale > 1.01 && showControls && !isLocked)
                Positioned(
                  top: 90,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _resetZoom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.zoom_out,
                                color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '${_scale.toStringAsFixed(1)}×  Tap to reset',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SEEK PREVIEW BOX
//  Shows a real video frame (via the preview controller) plus timecode.
// ─────────────────────────────────────────────────────────────────────────────
class _SeekPreviewBox extends StatelessWidget {
  final Duration previewPosition;
  final Duration duration;
  final String Function(Duration) formatTime;
  final VideoPlayerController? previewController;

  const _SeekPreviewBox({
    required this.previewPosition,
    required this.duration,
    required this.formatTime,
    this.previewController,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? (previewPosition.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9D00FF), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Video frame thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: (previewController != null &&
                previewController!.value.isInitialized)
                ? AspectRatio(
              aspectRatio: previewController!.value.aspectRatio,
              child: VideoPlayer(previewController!),
            )
                : Container(
              height: 80,
              color: Colors.black54,
              child: const Center(
                child: Icon(Icons.movie,
                    color: Colors.white30, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Timecode
          Text(
            formatTime(previewPosition),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF9D00FF)),
            ),
          ),
        ],
      ),
    );
  }
}