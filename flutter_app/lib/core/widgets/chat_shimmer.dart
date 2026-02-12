import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

/// Shimmer skeleton for loading messages in the chat screen.
class ChatShimmerLoader extends StatelessWidget {
  const ChatShimmerLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        _ShimmerBubble(isMe: false, width: 200, delay: 0),
        _ShimmerBubble(isMe: false, width: 160, delay: 100),
        _ShimmerBubble(isMe: true, width: 220, delay: 200),
        _ShimmerBubble(isMe: false, width: 180, delay: 300),
        _ShimmerBubble(isMe: true, width: 140, delay: 400),
        _ShimmerBubble(isMe: true, width: 240, delay: 500),
        _ShimmerBubble(isMe: false, width: 170, delay: 600),
      ],
    );
  }
}

class _ShimmerBubble extends StatefulWidget {
  final bool isMe;
  final double width;
  final int delay;

  const _ShimmerBubble({
    required this.isMe,
    required this.width,
    required this.delay,
  });

  @override
  State<_ShimmerBubble> createState() => _ShimmerBubbleState();
}

class _ShimmerBubbleState extends State<_ShimmerBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _opacity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: child,
          );
        },
        child: Container(
          margin: EdgeInsets.only(
            bottom: 6,
            left: widget.isMe ? 80 : 0,
            right: widget.isMe ? 0 : 80,
          ),
          width: widget.width,
          height: 44,
          decoration: BoxDecoration(
            color: widget.isMe
                ? AppTheme.brandGreen.withOpacity(0.2)
                : isDark
                    ? AppTheme.darkCard
                    : Colors.grey.shade200,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
              bottomRight: Radius.circular(widget.isMe ? 4 : 18),
            ),
          ),
        ),
      ),
    );
  }
}
