import 'package:flutter/foundation.dart';

enum MessageType {
  user,
  assistant,
  system,
}

enum MessageStatus {
  sending,
  sent,
  streaming,
  completed,
  error,
}

class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final MessageStatus status;
  final String? error;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.status = MessageStatus.completed,
    this.error,
    this.metadata,
  });

  ChatMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    MessageStatus? status,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'error': error,
      'metadata': metadata,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.user,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.completed,
      ),
      error: json['error'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  bool get isUser => type == MessageType.user;
  bool get isAssistant => type == MessageType.assistant;
  bool get isSystem => type == MessageType.system;
  bool get isStreaming => status == MessageStatus.streaming;
  bool get isCompleted => status == MessageStatus.completed;
  bool get hasError => status == MessageStatus.error;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage &&
        other.id == id &&
        other.content == content &&
        other.type == type &&
        other.timestamp == timestamp &&
        other.status == status &&
        other.error == error &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      content,
      type,
      timestamp,
      status,
      error,
      metadata,
    );
  }

  @override
  String toString() {
    return 'ChatMessage('
        'id: $id, '
        'content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}, '
        'type: $type, '
        'timestamp: $timestamp, '
        'status: $status'
        ')';
  }
}

class ChatSession {
  final String id;
  final DateTime createdAt;
  final DateTime lastActivity;
  final List<ChatMessage> messages;
  final Map<String, dynamic>? metadata;

  const ChatSession({
    required this.id,
    required this.createdAt,
    required this.lastActivity,
    required this.messages,
    this.metadata,
  });

  ChatSession copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? lastActivity,
    List<ChatMessage>? messages,
    Map<String, dynamic>? metadata,
  }) {
    return ChatSession(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      lastActivity: lastActivity ?? this.lastActivity,
      messages: messages ?? this.messages,
      metadata: metadata ?? this.metadata,
    );
  }

  ChatSession addMessage(ChatMessage message) {
    return copyWith(
      messages: [...messages, message],
      lastActivity: DateTime.now(),
    );
  }

  ChatSession updateMessage(String messageId, ChatMessage updatedMessage) {
    final updatedMessages = messages.map((msg) {
      return msg.id == messageId ? updatedMessage : msg;
    }).toList();
    
    return copyWith(
      messages: updatedMessages,
      lastActivity: DateTime.now(),
    );
  }

  ChatSession removeMessage(String messageId) {
    final updatedMessages = messages.where((msg) => msg.id != messageId).toList();
    return copyWith(
      messages: updatedMessages,
      lastActivity: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'lastActivity': lastActivity.toIso8601String(),
      'messages': messages.map((msg) => msg.toJson()).toList(),
      'metadata': metadata,
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActivity: DateTime.parse(json['lastActivity'] as String),
      messages: (json['messages'] as List<dynamic>)
          .map((msgJson) => ChatMessage.fromJson(msgJson as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'ChatSession('
        'id: $id, '
        'createdAt: $createdAt, '
        'messages: ${messages.length}'
        ')';
  }
}