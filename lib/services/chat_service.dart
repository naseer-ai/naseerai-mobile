import 'dart:async';
import 'dart:math';
import '../models/chat_message.dart';
import '../models/ai_model.dart';
import 'model_runner.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final ModelRunner _modelRunner = ModelRunner();
  final Map<String, ChatSession> _sessions = {};
  final Map<String, StreamController<ChatMessage>> _streamControllers = {};
  
  AIModel? _currentModel;
  bool _isModelLoaded = false;

  // Getters
  bool get isModelLoaded => _isModelLoaded;
  AIModel? get currentModel => _currentModel;

  // Initialize the chat service
  Future<void> initialize() async {
    try {
      _currentModel = await _modelRunner.loadModel('assets/models/phi2_demo_placeholder.tflite');
      _isModelLoaded = true;
      print('Chat service initialized successfully');
    } catch (e) {
      print('Error initializing chat service: $e');
      _isModelLoaded = false;
    }
  }

  // Create a new chat session
  String createSession() {
    final sessionId = _generateSessionId();
    final session = ChatSession(
      id: sessionId,
      createdAt: DateTime.now(),
      lastActivity: DateTime.now(),
      messages: [],
    );
    
    _sessions[sessionId] = session;
    _streamControllers[sessionId] = StreamController<ChatMessage>.broadcast();
    
    print('Created new chat session: $sessionId');
    return sessionId;
  }

  // Get a session by ID
  ChatSession? getSession(String sessionId) {
    return _sessions[sessionId];
  }

  // Get all sessions
  List<ChatSession> getAllSessions() {
    return _sessions.values.toList();
  }

  // Get message stream for a session
  Stream<ChatMessage> getMessageStream(String sessionId) {
    final controller = _streamControllers[sessionId];
    if (controller != null) {
      return controller.stream;
    }
    return const Stream.empty();
  }

  // Send a message and get streaming response
  Future<void> sendMessage(String sessionId, String content) async {
    final session = _sessions[sessionId];
    if (session == null) {
      throw Exception('Session not found: $sessionId');
    }

    // Create user message
    final userMessage = ChatMessage(
      id: _generateMessageId(),
      content: content,
      type: MessageType.user,
      timestamp: DateTime.now(),
      status: MessageStatus.completed,
    );

    // Add user message to session
    _sessions[sessionId] = session.addMessage(userMessage);
    
    // Emit user message to stream
    _streamControllers[sessionId]?.add(userMessage);

    // Generate AI response with streaming
    await _generateStreamingResponse(sessionId, content);
  }

  // Generate streaming AI response
  Future<void> _generateStreamingResponse(String sessionId, String userMessage) async {
    final session = _sessions[sessionId];
    if (session == null) return;

    try {
      // Create initial AI message
      final aiMessageId = _generateMessageId();
      final initialAiMessage = ChatMessage(
        id: aiMessageId,
        content: '',
        type: MessageType.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.streaming,
      );

      // Add to session and emit
      _sessions[sessionId] = session.addMessage(initialAiMessage);
      _streamControllers[sessionId]?.add(initialAiMessage);

      // Generate full response from AI
      String fullResponse;
      if (_isModelLoaded && _currentModel != null) {
        fullResponse = await _modelRunner.runInference(_currentModel!, userMessage);
      } else {
        fullResponse = _getFallbackResponse(userMessage);
      }

      // Simulate streaming by sending chunks
      await _streamResponse(sessionId, aiMessageId, fullResponse);

    } catch (e) {
      // Handle error
      final errorMessage = ChatMessage(
        id: _generateMessageId(),
        content: 'Sorry, I encountered an error processing your message.',
        type: MessageType.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.error,
        error: e.toString(),
      );

      final updatedSession = session.addMessage(errorMessage);
      _sessions[sessionId] = updatedSession;
      _streamControllers[sessionId]?.add(errorMessage);
    }
  }

  // Stream response word by word
  Future<void> _streamResponse(String sessionId, String messageId, String fullResponse) async {
    final session = _sessions[sessionId];
    if (session == null) return;

    final words = fullResponse.split(' ');
    String currentContent = '';

    for (int i = 0; i < words.length; i++) {
      currentContent += (i > 0 ? ' ' : '') + words[i];
      
      final updatedMessage = ChatMessage(
        id: messageId,
        content: currentContent,
        type: MessageType.assistant,
        timestamp: DateTime.now(),
        status: i == words.length - 1 ? MessageStatus.completed : MessageStatus.streaming,
      );

      // Update session
      _sessions[sessionId] = session.updateMessage(messageId, updatedMessage);
      
      // Emit updated message
      _streamControllers[sessionId]?.add(updatedMessage);

      // Add delay for streaming effect
      if (i < words.length - 1) {
        await Future.delayed(Duration(milliseconds: 50 + Random().nextInt(100)));
      }
    }
  }

  // Get fallback response when AI model is not available
  String _getFallbackResponse(String input) {
    final lowerInput = input.toLowerCase();
    
    if (lowerInput.contains('water') && (lowerInput.contains('clean') || lowerInput.contains('purify'))) {
      return '''Natural water purification methods include:

• **Solar disinfection (SODIS)**: Clear plastic bottles filled with water exposed to sunlight for 6+ hours can kill bacteria and viruses through UV radiation.

• **Sand filtration**: Multiple layers of fine sand, gravel, and charcoal can filter out particles and some contaminants.

• **Boiling**: Using wood, solar cookers, or any heat source to boil water for 1-3 minutes kills most pathogens.

• **Clay pot filters**: Ceramic filters made from clay and organic materials can remove bacteria and particles.

• **For saltwater**: Solar stills using clear plastic over a container can collect evaporated freshwater through condensation.

• **Plant-based**: Moringa seeds, banana peels, or sand/gravel combinations can help clarify muddy water.

These methods use readily available natural elements like sunlight, sand, plants, and heat sources.''';
    }

    if (lowerInput.contains('hello') || lowerInput.contains('hi')) {
      return "Hello! I'm NaseerAI, your offline AI assistant. I can help you with questions about water purification, renewable energy, science, technology, and much more. What would you like to know?";
    }

    if (lowerInput.contains('renewable') || lowerInput.contains('energy')) {
      return '''Renewable energy harnesses natural, replenishing resources:

**Solar Energy:**
• Photovoltaic cells convert sunlight directly to electricity
• Solar thermal systems heat water or generate steam
• Concentrated solar power uses mirrors to focus heat

**Wind Energy:**
• Wind turbines capture kinetic energy from air movement
• Works best in areas with consistent 15+ mph winds

**Hydroelectric:**
• Uses flowing or falling water to spin turbines
• Most established renewable technology

**Geothermal:**
• Taps earth's internal heat for electricity or heating
• Provides consistent baseload power

These sources are sustainable because they naturally replenish faster than we consume them.''';
    }

    return "I'm designed to provide comprehensive answers on topics like water purification, renewable energy, science, and technology. Feel free to ask me anything! For example, you could ask about 'How to clean water with natural elements?' or 'What is solar energy?'";
  }

  // Get suggested questions based on conversation context
  List<String> getSuggestions(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return _getDefaultSuggestions();

    // Analyze recent messages to provide contextual suggestions
    final recentMessages = session.messages.take(5).toList();
    final hasWaterTopic = recentMessages.any((msg) => 
      msg.content.toLowerCase().contains('water'));
    final hasEnergyTopic = recentMessages.any((msg) => 
      msg.content.toLowerCase().contains('energy'));

    if (hasWaterTopic) {
      return [
        "How does solar disinfection work?",
        "What materials are needed for sand filtration?",
        "Tell me about plant-based water filters",
        "How to make a solar still?",
      ];
    }

    if (hasEnergyTopic) {
      return [
        "How do solar panels work?",
        "What is wind energy efficiency?",
        "Explain geothermal energy",
        "Benefits of hydroelectric power",
      ];
    }

    return _getDefaultSuggestions();
  }

  List<String> _getDefaultSuggestions() {
    return [
      "How to clean water with natural elements?",
      "Explain renewable energy sources",
      "What is artificial intelligence?",
      "How does solar disinfection work?",
      "Tell me about sustainable technologies",
      "What are natural filtration methods?",
    ];
  }

  // Delete a session
  void deleteSession(String sessionId) {
    _sessions.remove(sessionId);
    _streamControllers[sessionId]?.close();
    _streamControllers.remove(sessionId);
    print('Deleted chat session: $sessionId');
  }

  // Clear all sessions
  void clearAllSessions() {
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _sessions.clear();
    _streamControllers.clear();
    print('Cleared all chat sessions');
  }

  // Generate unique session ID
  String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  // Generate unique message ID
  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  // Dispose resources
  void dispose() {
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
    _sessions.clear();
  }
}