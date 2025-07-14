import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../widgets/chat_message_widget.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/suggestions_widget.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  
  String? _sessionId;
  List<ChatMessage> _messages = [];
  List<String> _suggestions = [];
  bool _isLoading = false;
  bool _isTyping = false;
  StreamSubscription<ChatMessage>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize chat service
      await _chatService.initialize();
      
      // Create new session
      _sessionId = _chatService.createSession();
      
      // Listen to message stream
      _messageSubscription = _chatService
          .getMessageStream(_sessionId!)
          .listen(_onNewMessage);
      
      // Get initial suggestions
      _suggestions = _chatService.getSuggestions(_sessionId!);
      
      // Add welcome message
      await _sendWelcomeMessage();
      
    } catch (e) {
      _showErrorSnackBar('Failed to initialize chat: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendWelcomeMessage() async {
    final welcomeMessage = ChatMessage(
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      content: 'Hello! I\'m NaseerAI, your offline AI assistant. I can help you with questions about water purification, renewable energy, science, technology, and much more. What would you like to know?',
      type: MessageType.system,
      timestamp: DateTime.now(),
      status: MessageStatus.completed,
    );

    setState(() {
      _messages = [welcomeMessage];
    });
  }

  void _onNewMessage(ChatMessage message) {
    setState(() {
      // Update or add message
      final existingIndex = _messages.indexWhere((msg) => msg.id == message.id);
      if (existingIndex != -1) {
        _messages[existingIndex] = message;
      } else {
        _messages.add(message);
      }

      // Update typing state
      _isTyping = _messages.any((msg) => msg.isStreaming);
      
      // Update suggestions after assistant response
      if (message.isAssistant && message.isCompleted) {
        _suggestions = _chatService.getSuggestions(_sessionId!);
      }
    });

    // Auto-scroll to bottom
    _scrollToBottom();
  }

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty || _sessionId == null) return;

    try {
      // Clear input
      _inputController.clear();
      
      // Send message through chat service
      await _chatService.sendMessage(_sessionId!, content.trim());
      
      // Update suggestions
      setState(() {
        _suggestions = _chatService.getSuggestions(_sessionId!);
      });
      
    } catch (e) {
      _showErrorSnackBar('Failed to send message: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _copyMessage(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _messages.clear();
              });
              _sendWelcomeMessage();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NaseerAI Chat'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearChat,
            tooltip: 'Clear chat',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'model_status':
                  _showModelStatus();
                  break;
                case 'about':
                  _showAboutDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'model_status',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Text('Model Status'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.help_outline),
                    SizedBox(width: 8),
                    Text('About'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing AI model...'),
                ],
              ),
            )
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < _messages.length) {
                        final message = _messages[index];
                        return ChatMessageWidget(
                          message: message,
                          onCopy: () => _copyMessage(message.content),
                        );
                      } else {
                        // Show typing indicator
                        return const TypingIndicator();
                      }
                    },
                  ),
                ),
                
                // Suggestions
                if (_suggestions.isNotEmpty && !_isTyping)
                  SuggestionsWidget(
                    suggestions: _suggestions,
                    onSuggestionTapped: _sendMessage,
                  ),
                
                // Input area
                ChatInputWidget(
                  controller: _inputController,
                  onSend: _sendMessage,
                  enabled: !_isTyping,
                ),
              ],
            ),
    );
  }

  void _showModelStatus() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Model Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _chatService.isModelLoaded ? Icons.check_circle : Icons.error,
                  color: _chatService.isModelLoaded ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _chatService.isModelLoaded ? 'Model Loaded' : 'Model Not Loaded',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Model: Phi-2 (Offline)'),
            const SizedBox(height: 8),
            Text('Session: ${_sessionId?.substring(0, 12)}...'),
            const SizedBox(height: 8),
            Text('Messages: ${_messages.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: 'NaseerAI Chat',
        applicationVersion: '1.0.0',
        applicationIcon: const Icon(Icons.chat, size: 48),
        children: const [
          Text(
            'An offline AI chatbot powered by Phi-2 model. '
            'No internet connection required - all processing happens on your device.',
          ),
          SizedBox(height: 16),
          Text(
            'Features:\n'
            '• Real-time streaming responses\n'
            '• Water purification guidance\n'
            '• Renewable energy information\n'
            '• Science and technology topics\n'
            '• Complete offline functionality',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _scrollController.dispose();
    _inputController.dispose();
    
    // Clean up session
    if (_sessionId != null) {
      _chatService.deleteSession(_sessionId!);
    }
    
    super.dispose();
  }
}