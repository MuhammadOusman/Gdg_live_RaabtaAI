import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'chat_controller.dart';
import 'models/chat_message.dart';

class MatchChatScreen extends StatelessWidget {
  const MatchChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatController(),
      child: const _MatchChatBody(),
    );
  }
}

class _MatchChatBody extends StatefulWidget {
  const _MatchChatBody();

  @override
  State<_MatchChatBody> createState() => _MatchChatBodyState();
}

class _MatchChatBodyState extends State<_MatchChatBody> {
  static const double _bottomOffset = 88;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF050607),
      body: Stack(
        children: [
          const Positioned.fill(child: _ChatBackdrop()),
          SafeArea(
            bottom: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: math.max(viewInsets, _bottomOffset)),
              child: Column(
                children: [
                  _ChatHeader(
                    onBack: () {},
                    onMenu: () {},
                  ),
                  Expanded(
                    child: Consumer<ChatController>(
                      builder: (context, controller, _) {
                        final messages = controller.messages;
                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ChatBubble(
                                message: message,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                    child: _Composer(
                      textController: _textController,
                      focusNode: _focusNode,
                      onSend: _sendText,
                      onMicPressed: _toggleRecording,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }

    context.read<ChatController>().sendText(text);
    _textController.clear();
    _focusNode.requestFocus();
    setState(() {});
  }

  Future<void> _toggleRecording() async {
    final controller = context.read<ChatController>();
    if (controller.isRecording) {
      await controller.stopRecording();
    } else {
      await controller.startRecording();
    }
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.onBack, required this.onMenu});

  final VoidCallback onBack;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
          ),
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFF1D2430),
            child: Icon(Icons.auto_awesome_rounded, color: Color(0xFF4A90E2), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match Thread',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Message yourself • end-to-end secured',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.more_vert_rounded),
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.textController,
    required this.focusNode,
    required this.onSend,
    required this.onMicPressed,
  });

  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final Future<void> Function() onMicPressed;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> with SingleTickerProviderStateMixin {
  late AnimationController _pulsingController;

  @override
  void initState() {
    super.initState();
    _pulsingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulsingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final isRecording = controller.isRecording;
    final duration = controller.recordingDuration;

    if (isRecording) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF11151A).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          children: [
            // Trash/Cancel Button
            IconButton(
              onPressed: () async {
                await controller.cancelRecording();
              },
              icon: const Icon(Icons.delete_outline_rounded),
              color: Colors.redAccent,
              tooltip: 'Cancel recording',
            ),
            const SizedBox(width: 8),
            // Recording indicator & Time
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.2).animate(
                    CurvedAnimation(parent: _pulsingController, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDurationSeconds(duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Recording audio...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            // Stop & Send Button
            _ActionButton(
              color: const Color(0xFF24B15E),
              icon: Icons.send_rounded,
              onTap: () async {
                await controller.stopRecording();
              },
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: widget.textController,
      builder: (context, _) {
        final hasText = widget.textController.text.trim().isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF11151A).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.emoji_emotions_outlined),
                color: Colors.white70,
              ),
              Expanded(
                child: TextField(
                  controller: widget.textController,
                  focusNode: widget.focusNode,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => widget.onSend(),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.34)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: hasText
                    ? _ActionButton(
                        key: const ValueKey('send'),
                        color: const Color(0xFF4A90E2),
                        icon: Icons.send_rounded,
                        onTap: widget.onSend,
                      )
                    : Row(
                        key: const ValueKey('voice'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ActionButton(
                            color: const Color(0xFF22272F),
                            icon: Icons.attach_file_rounded,
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            color: const Color(0xFF24B15E),
                            icon: Icons.mic_rounded,
                            onTap: widget.onMicPressed,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDurationSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.color, required this.icon, required this.onTap, super.key});

  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          width: 44,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isMe = message.sender == 'me';
    final bubbleColor = isMe ? const Color(0xFF2F7CFF) : const Color(0xFF124D3E);
    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(isMe ? 22 : 6),
              bottomRight: Radius.circular(isMe ? 6 : 22),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: isMe ? 0.06 : 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: _BubbleBody(
            message: message,
            isMe: isMe,
          ),
        ),
      ),
    );
  }
}

class _BubbleBody extends StatelessWidget {
  const _BubbleBody({required this.message, required this.isMe});

  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final timestamp = _formatTime(message.timestamp);

    if (message.type == MessageType.image) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF2A8B6C), width: 2),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF060607), Color(0xFF111112)],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CustomPaint(
                      painter: _MediaPlaceholderPainter(),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      message.mediaLabel ?? 'Shared media',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 18,
                  bottom: 18,
                  child: Icon(Icons.reply_rounded, color: Colors.white, size: 26),
                ),
                Positioned(
                  right: 14,
                  bottom: 12,
                  child: Text(
                    timestamp,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.76),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
          if ((message.text ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                message.text!,
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _MessageFooter(timestamp: timestamp, isMe: isMe),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    if (message.type == MessageType.audio) {
      return _VoiceNoteBubble(
        message: message,
        timestamp: timestamp,
        isMe: isMe,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.text ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.35),
          ),
          const SizedBox(height: 8),
          _MessageFooter(timestamp: timestamp, isMe: isMe),
        ],
      ),
    );
  }
}

class _VoiceNoteBubble extends StatelessWidget {
  const _VoiceNoteBubble({
    required this.message,
    required this.timestamp,
    required this.isMe,
  });

  final ChatMessage message;
  final String timestamp;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final canPlay = message.audioPath != null;
    final accent = isMe ? Colors.white : const Color(0xFF6EE7B7);
    final foreground = isMe ? Colors.white : Colors.white.withValues(alpha: 0.92);

    return Selector<ChatController, AudioPlaybackState>(
      selector: (context, controller) {
        final isCurrent = controller.playingMessageId == message.id;
        return AudioPlaybackState(
          isPlaying: isCurrent && controller.isPlayingAudio,
          position: isCurrent ? controller.audioPosition : Duration.zero,
          duration: isCurrent ? controller.audioDuration : Duration.zero,
        );
      },
      builder: (context, playbackState, child) {
        final isPlayingThis = playbackState.isPlaying;
        final position = playbackState.position;
        final duration = playbackState.duration;

        double progress = 0.0;
        if (duration.inMilliseconds > 0) {
          progress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
        }

        String timeStr;
        if (isPlayingThis || position > Duration.zero) {
          timeStr = '${_formatDuration(position)} / ${_formatDuration(duration)}';
        } else {
          timeStr = message.text != null && message.text != 'Voice note'
              ? message.text!
              : 'Voice note';
        }

        return SizedBox(
          width: 280,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Play/Pause Button
                    Material(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: canPlay
                            ? () {
                                context.read<ChatController>().playAudio(message.id, message.audioPath!);
                              }
                            : null,
                        child: SizedBox(
                          height: 38,
                          width: 38,
                          child: Icon(
                            isPlayingThis ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: canPlay ? accent : Colors.white38,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Waveform with scrubbing capabilities
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              return GestureDetector(
                                onTapDown: (details) {
                                  if (!canPlay) return;
                                  final dx = details.localPosition.dx;
                                  final pct = (dx / width).clamp(0.0, 1.0);
                                  if (duration > Duration.zero) {
                                    context.read<ChatController>().seekAudio(duration * pct);
                                  }
                                },
                                onHorizontalDragUpdate: (details) {
                                  if (!canPlay) return;
                                  final dx = details.localPosition.dx;
                                  final pct = (dx / width).clamp(0.0, 1.0);
                                  if (duration > Duration.zero) {
                                    context.read<ChatController>().seekAudio(duration * pct);
                                  }
                                },
                                child: SizedBox(
                                  height: 28,
                                  child: CustomPaint(
                                    painter: _VoiceWaveformPainter(
                                      color: foreground.withValues(alpha: canPlay ? 0.25 : 0.15),
                                      progressColor: accent.withValues(alpha: 0.95),
                                      progress: progress,
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: foreground.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Avatar with Microphone Badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          child: Icon(
                            Icons.person_rounded,
                            color: foreground.withValues(alpha: 0.7),
                            size: 20,
                          ),
                        ),
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF24B15E),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: _MessageFooter(timestamp: timestamp, isMe: isMe),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VoiceWaveformPainter extends CustomPainter {
  const _VoiceWaveformPainter({
    required this.color,
    required this.progressColor,
    required this.progress,
  });

  final Color color;
  final Color progressColor;
  final double progress;

  static const List<double> _levels = [
    0.28, 0.55, 0.36, 0.76, 0.48, 0.92, 0.62, 0.42, 0.82, 0.34,
    0.68, 0.96, 0.52, 0.74, 0.38, 0.58, 0.86, 0.46, 0.72, 0.4,
    0.64, 0.88, 0.5, 0.32,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final inactivePaint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final activePaint = Paint()
      ..color = progressColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    final spacing = size.width / (_levels.length - 1);
    final centerY = size.height / 2;
    final activeCount = (progress * _levels.length).round();

    for (var i = 0; i < _levels.length; i++) {
      final x = i * spacing;
      final height = (size.height * _levels[i]).clamp(5.0, size.height);
      final paint = i < activeCount ? activePaint : inactivePaint;
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveformPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.progress != progress;
  }
}

class _MessageFooter extends StatelessWidget {
  const _MessageFooter({required this.timestamp, required this.isMe});

  final String timestamp;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timestamp,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
        ),
        if (isMe) ...[
          const SizedBox(width: 6),
          Icon(
            Icons.done_all_rounded,
            size: 15,
            color: Colors.lightBlueAccent.withValues(alpha: 0.94),
          ),
        ],
      ],
    );
  }
}

class _ChatBackdrop extends StatelessWidget {
  const _ChatBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF090B0D), Color(0xFF040506)],
        ),
      ),
      child: CustomPaint(
        painter: _BackdropPatternPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BackdropPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    dotPaint.color = Colors.white.withValues(alpha: 0.03);
    linePaint.color = Colors.white.withValues(alpha: 0.04);

    const step = 88.0;
    for (double y = 0; y < size.height + step; y += step) {
      for (double x = 0; x < size.width + step; x += step) {
        final center = Offset(x + (y / 7) % 10, y);
        canvas.drawCircle(center, 2.5 + (x / step) % 2, dotPaint);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: 9),
          0.7,
          1.4,
          false,
          linePaint,
        );
      }
    }

    final glow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x224A90E2), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: size.shortestSide));
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.2), size.shortestSide * 0.35, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MediaPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF050607), Color(0xFF121316)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      background,
    );

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var i = 0; i < 8; i++) {
      final dy = 30.0 + (i * 28);
      canvas.drawLine(Offset(16, dy), Offset(size.width - 16, dy), linePaint);
    }

    final accentPaint = Paint()..color = const Color(0xFF2A8B6C).withValues(alpha: 0.5);
    canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.34), 42, accentPaint);
    canvas.drawCircle(Offset(size.width * 0.74, size.height * 0.50), 20, accentPaint);
    canvas.drawCircle(Offset(size.width * 0.22, size.height * 0.74), 30, accentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatTime(DateTime timestamp) {
  final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
  final minute = timestamp.minute.toString().padLeft(2, '0');
  final suffix = timestamp.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class AudioPlaybackState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  AudioPlaybackState({
    required this.isPlaying,
    required this.position,
    required this.duration,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioPlaybackState &&
          runtimeType == other.runtimeType &&
          isPlaying == other.isPlaying &&
          position == other.position &&
          duration == other.duration;

  @override
  int get hashCode => isPlaying.hashCode ^ position.hashCode ^ duration.hashCode;
}

