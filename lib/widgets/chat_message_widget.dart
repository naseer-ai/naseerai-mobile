import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onCopy;

  const ChatMessageWidget({
    super.key,
    required this.message,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final isSystem = message.isSystem;

    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
      ),
      child: Column(
        crossAxisAlignment: isUser 
            ? CrossAxisAlignment.end 
            : CrossAxisAlignment.start,
        children: [
          // Message bubble
          GestureDetector(
            onLongPress: onCopy,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: _getMessageColor(theme, isUser, isSystem),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message content
                  SelectableText(
                    message.content,
                    style: TextStyle(
                      color: _getTextColor(isUser, isSystem),
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  
                  // Streaming indicator
                  if (message.isStreaming)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getTextColor(isUser, isSystem).withOpacity(0.7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Typing...',
                            style: TextStyle(
                              color: _getTextColor(isUser, isSystem).withOpacity(0.7),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Error indicator
                  if (message.hasError)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Colors.red[300],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Failed to send',
                            style: TextStyle(
                              color: Colors.red[300],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Message metadata
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Timestamp
                Text(
                  _formatTime(message.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                ),
                
                // Copy button for assistant messages
                if (message.isAssistant && message.isCompleted && onCopy != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: onCopy,
                      child: Icon(
                        Icons.copy,
                        size: 16,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                      ),
                    ),
                  ),
                
                // Status indicator
                if (message.isUser)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      _getStatusIcon(message.status),
                      size: 16,
                      color: _getStatusColor(message.status),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getMessageColor(ThemeData theme, bool isUser, bool isSystem) {
    if (isSystem) {
      return theme.colorScheme.secondaryContainer;
    }
    if (isUser) {
      return theme.colorScheme.primary;
    }
    return theme.colorScheme.surfaceVariant;
  }

  Color _getTextColor(bool isUser, bool isSystem) {
    if (isUser) {
      return Colors.white;
    }
    return Colors.black87;
  }

  IconData _getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icons.schedule;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.completed:
        return Icons.done_all;
      case MessageStatus.error:
        return Icons.error_outline;
      default:
        return Icons.check;
    }
  }

  Color _getStatusColor(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Colors.grey;
      case MessageStatus.sent:
        return Colors.grey;
      case MessageStatus.completed:
        return Colors.green;
      case MessageStatus.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Now';
    }
  }
}