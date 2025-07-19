import 'dart:async';
import 'dart:math';
import '../models/chat_message.dart';
import '../models/ai_model.dart';
import 'model_runner.dart';
import 'native_model_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final ModelRunner _modelRunner = ModelRunner();
  final NativeModelService _nativeModelService = NativeModelService();
  final Map<String, ChatSession> _sessions = {};
  final Map<String, StreamController<ChatMessage>> _streamControllers = {};
  
  AIModel? _currentModel;
  bool _isModelLoaded = false;
  bool _useNativeModel = false;

  // Getters
  bool get isModelLoaded => _isModelLoaded;
  AIModel? get currentModel => _currentModel;
  bool get isUsingNativeModel => _useNativeModel;

  // Initialize the chat service with preference for native models
  Future<void> initialize() async {
    try {
      // First try to load a native C++ model
      final availableNativeModels = await _nativeModelService.getAvailableModelFiles();
      if (availableNativeModels.isNotEmpty) {
        final firstModel = availableNativeModels.first;
        final nativeModel = await _nativeModelService.loadModel(firstModel);
        if (nativeModel != null) {
          _currentModel = nativeModel;
          _isModelLoaded = true;
          _useNativeModel = true;
          return;
        }
      }

      // Fallback to TFLite model
      _currentModel = await _modelRunner.loadModel('assets/models/phi2_demo_placeholder.tflite');
      _isModelLoaded = true;
      _useNativeModel = false;
    } catch (e) {
      _isModelLoaded = false;
      _useNativeModel = false;
    }
  }

  // Load a specific native model
  Future<bool> loadNativeModel(String modelPath) async {
    try {
      final nativeModel = await _nativeModelService.loadModel(modelPath);
      if (nativeModel != null) {
        _currentModel = nativeModel;
        _isModelLoaded = true;
        _useNativeModel = true;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get available native model files
  Future<List<String>> getAvailableNativeModels() async {
    return await _nativeModelService.getAvailableModelFiles();
  }

  // Get model status and system information
  Future<Map<String, dynamic>> getModelStatus() async {
    final nativeStatus = _nativeModelService.getModelStatus();
    final systemInfo = await _nativeModelService.getSystemInfo();
    
    return {
      'current_model_type': _useNativeModel ? 'native_cpp' : 'tflite',
      'is_loaded': _isModelLoaded,
      'model_info': _currentModel?.toJson(),
      'native_model_status': nativeStatus,
      'system_info': systemInfo,
    };
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
    
    // Session created successfully
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
        // Add emergency context to the prompt for AI models
        String contextualPrompt = _addEmergencyContext(userMessage);
        
        if (_useNativeModel) {
          fullResponse = await _nativeModelService.generateResponse(contextualPrompt);
        } else {
          fullResponse = await _modelRunner.runInference(_currentModel!, contextualPrompt);
        }
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

  // Add emergency context to prompts for AI models
  String _addEmergencyContext(String userMessage) {
    return '''You are NaseerAI, an emergency assistance AI designed for Gaza crisis support. You must provide:

1. IMMEDIATE, actionable solutions using available materials
2. Offline-first guidance (no internet required)
3. Clear, stress-appropriate language
4. Life safety prioritization

Context: User is in emergency/crisis situation with limited resources.

User message: $userMessage

Response format:
<response>
<summary>One-sentence actionable summary</summary>
<detailed_answer>Step-by-step solution with available materials</detailed_answer>
<additional_info>Critical related emergency information</additional_info>
</response>''';
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

    // Handle specific AI/technology questions
    if (lowerInput.contains('artificial intelligence') || lowerInput.contains('ai') || lowerInput.contains('machine learning')) {
      return '''**Artificial Intelligence (AI)** is the simulation of human intelligence in machines that are programmed to think, learn, and problem-solve like humans.

**Key Components:**
• **Machine Learning**: Systems that improve through experience and data
• **Natural Language Processing**: Understanding and generating human language  
• **Computer Vision**: Interpreting visual information
• **Reasoning**: Drawing conclusions from available information

**Types of AI:**
• **Narrow AI**: Specialized for specific tasks (like voice assistants, image recognition)
• **General AI**: Human-level intelligence across all domains (theoretical)
• **Superintelligence**: Beyond human cognitive abilities (hypothetical)

**Applications:**
• Medical diagnosis and drug discovery
• Autonomous vehicles and transportation
• Language translation and communication
• Scientific research and data analysis
• Resource optimization and conservation

AI systems learn from patterns in data to make predictions and decisions, helping solve complex problems more efficiently than traditional computing methods.''';
    }

    // Enhanced fallback with emergency awareness
    String inputLower = input.toLowerCase();
    
    // Check for emergency context first
    if (inputLower.contains('emergency') || inputLower.contains('help') || inputLower.contains('urgent')) {
      return '''I understand you need assistance. While I'm running in offline mode, I can still provide guidance on:

• **Emergency safety protocols** - immediate danger response
• **Medical first aid** - injury treatment with available materials  
• **Resource management** - water purification, power conservation
• **Communication methods** - signaling for help without internet

What specific situation do you need help with? Please describe your immediate concern.''';
    }
    
    // Contextual suggestions based on input analysis
    if (inputLower.contains('water') || inputLower.contains('thirsty') || inputLower.contains('drink')) {
      return "I can help with water purification using natural methods. Ask me about solar disinfection, sand filtration, or emergency water collection techniques.";
    }
    
    if (inputLower.contains('power') || inputLower.contains('battery') || inputLower.contains('energy')) {
      return "I can guide you on battery conservation, alternative charging methods, and energy management strategies for emergency situations.";
    }
    
    if (inputLower.contains('safe') || inputLower.contains('protect') || inputLower.contains('danger')) {
      return "I can provide safety protocols for various emergency situations. Please describe what type of danger or safety concern you're facing.";
    }
    
    return "I can provide practical, offline solutions for emergency situations, resource management, and survival techniques. What specific challenge are you facing or what would you like to learn about?";
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
      "How to purify water without electricity?",
      "Emergency first aid for bleeding wounds",
      "Battery conservation during power outages",
      "Safe shelter during bombing attacks",
      "Food preservation without refrigeration",
      "Signal for help without internet",
      "Treat injuries with household items",
      "Stay warm without heating systems",
    ];
  }

  // Delete a session
  void deleteSession(String sessionId) {
    _sessions.remove(sessionId);
    _streamControllers[sessionId]?.close();
    _streamControllers.remove(sessionId);
    // Session deleted successfully
  }

  // Clear all sessions
  void clearAllSessions() {
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _sessions.clear();
    _streamControllers.clear();
    // All sessions cleared successfully
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