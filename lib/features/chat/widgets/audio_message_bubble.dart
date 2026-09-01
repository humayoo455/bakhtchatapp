import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/theme/app_theme.dart';

class AudioMessageBubble extends StatefulWidget {
  final String url;
  final bool isMe;
  final AudioPlayer player;
  final int? savedDuration;
  final List<double>? waveform;

  const AudioMessageBubble({
    super.key,
    required this.url,
    required this.isMe,
    required this.player,
    this.savedDuration,
    this.waveform,
  });

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  // 🔥 GLOBAL ACTIVE AUDIO (shared across all bubbles)
  static String? currentUrl;

  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  double progress = 0.0;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();

    if (widget.savedDuration != null) {
      duration = Duration(seconds: widget.savedDuration!);
    }

    _posSub = widget.player.positionStream.listen((p) {
      if (!mounted) return;
      if (currentUrl == widget.url) {
        setState(() {
          position = p;
          if (duration.inMilliseconds > 0) {
            progress = progress = (p.inMilliseconds / duration.inMilliseconds)
                .clamp(0.0, 1.0);
          }
        });
      } else {
        if (progress != 0.0) setState(() => progress = 0.0);
      }
    });

    _durSub = widget.player.durationStream.listen((d) {
      if (!mounted || d == null) return;
      if (currentUrl == widget.url) {
        setState(() => duration = d);
      }
    });

    _stateSub = widget.player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        isPlaying = (currentUrl == widget.url) && state.playing;
        if (state.processingState == ProcessingState.completed && currentUrl == widget.url) {
          position = Duration.zero;
          progress = 0.0;
          isPlaying = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  void toggle() async {
    try {
      if (currentUrl == widget.url && isPlaying) {
        await widget.player.pause();
      } else {
        if (currentUrl != widget.url) {
          currentUrl = widget.url;

          await widget.player.stop();
          await widget.player.setAudioSource(
            AudioSource.uri(Uri.parse(widget.url.trim())),
          );
        }

        await widget.player.play();
      }
    } catch (e) {
      print("PLAYBACK ERROR: $e");
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  Widget buildWaveform(List<double> wave) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;

        // 🔥 calculate how many bars can fit FULL width
        double barWidth = 3;
        double spacing = 2;
        int maxBars = (maxWidth / (barWidth + spacing)).floor();

        // 🔥 scale waveform to FULL WIDTH (no shrinking look)
        List<double> normalized = [];

        if (wave.isNotEmpty) {
          for (int i = 0; i < maxBars; i++) {
            int index = ((i / maxBars) * wave.length).floor();
            normalized.add(wave[index]);
          }
        } else {
          normalized = List.generate(maxBars, (_) => 0.2);
        }

        return Row(
          mainAxisSize: MainAxisSize.max,
          children: List.generate(normalized.length, (i) {
            final isPlayed = (i / normalized.length) <= progress;

            return Container(
              width: barWidth,
              margin: EdgeInsets.only(right: spacing),
              height: (normalized[i] * 30).clamp(5, 30),
              decoration: BoxDecoration(
                color: isPlayed
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final isActive = currentUrl == widget.url;
    final displayPosition = isActive ? position : Duration.zero;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        decoration: BoxDecoration(
          color: widget.isMe ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(widget.isMe ? 20 : 0),
            bottomRight: Radius.circular(widget.isMe ? 0 : 20),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: toggle,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white24,
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // 🔥 WAVEFORM WITH TAP SEEK
                  GestureDetector(
                    onTapDown: (details) async {
                      try {
                        final box = context.findRenderObject() as RenderBox;
                        final localX =
                            box.globalToLocal(details.globalPosition).dx;

                        final width = box.size.width;
                        double tapProgress =
                        (localX / width).clamp(0.0, 1.0);

                        if (duration.inMilliseconds > 0) {
                          final seekPos =
                              duration * tapProgress;

                          await widget.player.seek(seekPos);
                        }
                      } catch (e) {
                        print("SEEK ERROR: $e");
                      }
                    },
                    child: SizedBox(
                      height: 35,
                      width: double.infinity,
                      child: widget.waveform == null ||
                          widget.waveform!.isEmpty
                          ? Row(
                        children: List.generate(
                          40, // 🔥 safe fixed count
                              (i) => Container(
                            width: 2.5,
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 0.8),
                            color: Colors.white24,
                          ),
                        ),
                      )
                          : ClipRect(
                        child: buildWaveform(widget.waveform!),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // 🔥 TIME ROW (SAFE)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(displayPosition),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 10),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
