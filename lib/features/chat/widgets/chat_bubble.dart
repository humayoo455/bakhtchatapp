import 'package:flutter/material.dart';

class ChatBubble extends StatefulWidget {
  final String message;
  final bool isMe;
  final String? mediaUrl;
  final String time;
  final String status;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.time,
    required this.status,
    this.mediaUrl,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool isLiked = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
      widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onDoubleTap: () {
          setState(() {
            isLiked = !isLiked;
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: widget.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                      vertical: 5, horizontal: 10),
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  constraints: BoxConstraints(
                    maxWidth:
                    MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? Colors.white
                        : const Color(0xFF1A0A0E),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft:
                      Radius.circular(widget.isMe ? 20 : 0),
                      bottomRight:
                      Radius.circular(widget.isMe ? 0 : 20),
                    ),
                  ),
        child: widget.mediaUrl != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            widget.mediaUrl!,
            fit: BoxFit.cover,
            width: 200,
            height: 200,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                width: 200,
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox(
                width: 200,
                height: 200,
                child: Center(child: Icon(Icons.broken_image)),
              );
            },
          ),
        )
            : Text(
          widget.message,
          style: TextStyle(
            color: widget.isMe ? Colors.black : Colors.white,
            fontSize: 15,
          ),

                  ),
                ),

                // ✅ STATUS ROW (FIXED — NO UI CHANGE)
                Padding(
                  padding: EdgeInsets.only(
                    left: widget.isMe ? 0 : 15,
                    right: widget.isMe ? 15 : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.time,
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 10),
                      ),

                      if (widget.isMe) ...[
                        const SizedBox(width: 4),

                        // ✅ USE STATUS INSTEAD OF isRead
                        if (widget.status == 'sent')
                          const Icon(Icons.done,
                              size: 14, color: Colors.white24),

                        if (widget.status == 'delivered')
                          const Icon(Icons.done_all,
                              size: 14, color: Colors.white24),

                        if (widget.status == 'seen')
                          const Icon(Icons.done_all,
                              size: 14,
                              color: Colors.blueAccent),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // ❤️ LIKE ICON (UNCHANGED)
            if (isLiked)
              Positioned(
                bottom: 15,
                right: widget.isMe ? null : -5,
                left: widget.isMe ? -5 : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF3D1219),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite,
                      color: Colors.pinkAccent, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}