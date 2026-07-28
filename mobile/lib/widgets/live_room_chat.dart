import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/chat_message_model.dart';
import '../theme/bigo_theme.dart';

/// Bigo-style chat column shared by host, viewer, and guest.
class LiveRoomChat extends StatelessWidget {
  final List<ChatMessageModel> messages;
  final ScrollController scrollController;
  final TextEditingController inputController;
  final bool isMuted;
  final String muteMessage;
  final VoidCallback onSend;

  /// Opens the gift picker — shown next to the send button.
  final VoidCallback? onGift;

  /// Tapping a (non-system, non-self) username — host moderation only.
  final void Function(ChatMessageModel message)? onTapUsername;

  final String? currentUserId;

  const LiveRoomChat({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.inputController,
    this.isMuted = false,
    this.muteMessage = 'You are muted by the host',
    required this.onSend,
    this.onGift,
    this.onTapUsername,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (messages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                controller: scrollController,
                shrinkWrap: true,
                reverse: true,
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[messages.length - 1 - index];
                  final canModerate =
                      onTapUsername != null &&
                      !message.isSystemMessage &&
                      message.userId.isNotEmpty &&
                      message.userId != currentUserId;
                  return _ChatRow(
                    key: ValueKey(message.id),
                    message: message,
                    canModerate: canModerate,
                    onTapUsername: canModerate
                        ? () => onTapUsername!(message)
                        : null,
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 6),
        _buildInputBar(context),
      ],
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 34,
            padding: const EdgeInsets.only(left: 2, right: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(
                    Icons.emoji_emotions_outlined,
                    color: Colors.white70,
                    size: 18,
                  ),
                  onPressed: () => _openEmojiPicker(context),
                ),
                Expanded(
                  child: isMuted
                      ? Text(
                          muteMessage,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : TextField(
                          controller: inputController,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          onSubmitted: (_) => onSend(),
                          decoration: const InputDecoration(
                            hintText: 'Say hi...',
                            hintStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                ),
                if (!isMuted)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: const Icon(Icons.send, color: Colors.white, size: 16),
                    onPressed: onSend,
                  ),
              ],
            ),
          ),
        ),
        if (onGift != null) ...[
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onGift,
              customBorder: const CircleBorder(),
              child: Ink(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      BigoColors.hot,
                      BigoColors.hot.withValues(alpha: 0.75),
                    ],
                  ),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _openEmojiPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (sheetContext) => _EmojiPickerSheet(
        onSelected: (emoji) {
          inputController.text += emoji;
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final ChatMessageModel message;
  final bool canModerate;
  final VoidCallback? onTapUsername;

  const _ChatRow({
    super.key,
    required this.message,
    required this.canModerate,
    required this.onTapUsername,
  });

  static final _bubbleColor = Colors.black.withValues(alpha: 0.32);
  static const _nameColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final body = message.isSystemMessage
        ? (message.message == ChatMessageModel.joinedRoom ||
                message.message == 'entered the room' ||
                message.message.isEmpty
            ? 'joined'
            : message.message)
        : message.message;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
          decoration: BoxDecoration(
            color: _bubbleColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                child: Text(
                  message.username.isNotEmpty
                      ? message.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: _nameColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.25,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    children: [
                      TextSpan(
                        text: '${message.username}: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _nameColor,
                          decoration: canModerate
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          decorationColor: Colors.white38,
                        ),
                        recognizer: canModerate
                            ? (TapGestureRecognizer()..onTap = onTapUsername)
                            : null,
                      ),
                      TextSpan(
                        text: body,
                        style: TextStyle(
                          fontStyle: message.isSystemMessage
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: message.isSystemMessage
                              ? Colors.white70
                              : Colors.white,
                        ),
                      ),
                    ],
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

class _EmojiPickerSheet extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _EmojiPickerSheet({required this.onSelected});

  static const _emojis = [
    '😀',
    '😂',
    '😍',
    '😘',
    '😎',
    '🤔',
    '😢',
    '😡',
    '👍',
    '🔥',
    '🎉',
    '❤️',
    '👏',
    '🙏',
    '💯',
    '😅',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _emojis
              .map(
                (emoji) => GestureDetector(
                  onTap: () => onSelected(emoji),
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
