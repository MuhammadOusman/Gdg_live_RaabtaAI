import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'chat_controller.dart';
import 'models/chat_message.dart';
import 'services/voice_note_player.dart';

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
  static const double _bottomOffset = 110;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final VoiceNotePlayer _voicePlayer = const VoiceNotePlayer();

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
                                player: _voicePlayer,
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
    if (mounted) {
      setState(() {});
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

class _Composer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: textController,
      builder: (context, _) {
        final hasText = textController.text.trim().isNotEmpty;
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
                  controller: textController,
                  focusNode: focusNode,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
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
                        onTap: onSend,
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
                            onTap: onMicPressed,
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
  const _ChatBubble({required this.message, required this.player});

  final ChatMessage message;
  final VoiceNotePlayer player;

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
            player: player,
          ),
        ),
      ),
    );
  }
}

class _BubbleBody extends StatelessWidget {
  const _BubbleBody({required this.message, required this.isMe, required this.player});

  final ChatMessage message;
  final bool isMe;
  final VoiceNotePlayer player;

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
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.black.withValues(alpha: 0.25),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: message.audioPath == null
                    ? null
                    : () async {
                        await player.play(message.audioPath!);
                      },
                icon: Icon(
                  Icons.play_arrow_rounded,
                  color: message.audioPath == null ? Colors.white38 : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: List.generate(
                      16,
                      (index) => Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Container(
                          width: 2,
                          height: 6 + ((index % 5) * 2).toDouble(),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message.text ?? 'Voice note',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              timestamp,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
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
