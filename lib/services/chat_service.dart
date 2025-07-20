import 'dart:async';
import 'dart:math';
import '../models/chat_message.dart';
import '../models/ai_model.dart';
import '../models/search_result.dart';
import 'model_runner.dart';
import 'native_model_service.dart';
import 'capsule_search_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final ModelRunner _modelRunner = ModelRunner();
  final NativeModelService _nativeModelService = NativeModelService.instance;
  final CapsuleSearchService _capsuleSearchService = CapsuleSearchService();
  final Map<String, ChatSession> _sessions = {};
  final Map<String, StreamController<ChatMessage>> _streamControllers = {};
  final Map<String, bool> _streamingCancellation = {};

  AIModel? _currentModel;
  bool _isModelLoaded = false;
  bool _useNativeModel = false;
  
  // Performance optimization: Keep model loaded
  bool _modelPersistentlyLoaded = false;
  String? _loadedModelPath;
  
  // Timeout configuration
  static const Duration _responseTimeout = Duration(seconds: 30);
  static const Duration _modelLoadTimeout = Duration(seconds: 60);

  // Getters
  bool get isModelLoaded => _isModelLoaded;
  AIModel? get currentModel => _currentModel;
  bool get isUsingNativeModel => _useNativeModel;

  // Initialize the chat service with auto-model detection (ANR-safe)
  Future<void> initialize() async {
    try {
      print('🚀 Initializing ChatService...');

      // Initialize capsule search service in background
      await Future.microtask(() async {
        await _capsuleSearchService.initialize();
      });

      // Auto-detect and load model in background to prevent ANR
      _initializeModelInBackground();
      
      print('📋 ChatService initialized - model loading in background');
    } catch (e) {
      print('⚠️ ChatService initialization error: $e');
      _isModelLoaded = false;
      _useNativeModel = false;
      _currentModel = null;
    }
  }

  /// Initialize model in background to prevent UI blocking
  void _initializeModelInBackground() {
    Future.microtask(() async {
      try {
        // Add delay to let UI render first
        await Future.delayed(const Duration(milliseconds: 100));
        
        final modelLoaded = await _nativeModelService.autoLoadBestModel();
        _isModelLoaded = modelLoaded;
        _useNativeModel = modelLoaded;

        if (modelLoaded) {
          _currentModel = _nativeModelService.activeModel;
          print('✅ Background model loading completed successfully');
        } else {
          print('📋 Using intelligent fallback responses');
        }
      } catch (e) {
        print('⚠️ Background model loading error: $e');
        _isModelLoaded = false;
        _useNativeModel = false;
        _currentModel = null;
      }
    });
  }

  // Load a specific native model
  Future<bool> loadNativeModel(String modelPath) async {
    try {
      final success = await _nativeModelService.loadModel(modelPath);
      if (success) {
        _currentModel = _nativeModelService.activeModel;
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

    // Reset cancellation flag for this session
    _streamingCancellation[sessionId] = false;

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

  // Stop streaming for a session
  void stopStreaming(String sessionId) {
    _streamingCancellation[sessionId] = true;

    // Find the currently streaming message and mark it as completed
    final session = _sessions[sessionId];
    if (session != null) {
      final streamingMessage = session.messages.lastWhere(
        (msg) => msg.status == MessageStatus.streaming,
        orElse: () => ChatMessage(
          id: '',
          content: '',
          type: MessageType.assistant,
          timestamp: DateTime.now(),
          status: MessageStatus.completed,
        ),
      );

      if (streamingMessage.id.isNotEmpty) {
        final stoppedMessage = ChatMessage(
          id: streamingMessage.id,
          content: '${streamingMessage.content} [Response stopped]',
          type: MessageType.assistant,
          timestamp: streamingMessage.timestamp,
          status: MessageStatus.completed,
        );

        _sessions[sessionId] =
            session.updateMessage(streamingMessage.id, stoppedMessage);
        _streamControllers[sessionId]?.add(stoppedMessage);
      }
    }
  }

  // Check if streaming is active for a session
  bool isStreaming(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return false;

    return session.messages.any((msg) => msg.status == MessageStatus.streaming);
  } // Generate streaming AI response

  Future<void> _generateStreamingResponse(
      String sessionId, String userMessage) async {
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

      String fullResponse;

      try {
        // Use optimized response generation with timeout
        fullResponse = await _generateOptimizedResponse(userMessage).timeout(
          _responseTimeout,
          onTimeout: () => "Response timed out after ${_responseTimeout.inSeconds} seconds. Please try a shorter message.",
        );
      } catch (e) {
        print('Error generating response: $e');
        fullResponse = await _generateFallbackResponse(userMessage);
      }

      // Check if streaming was cancelled
      if (_streamingCancellation[sessionId] == true) {
        return;
      }

      // Simulate streaming by breaking response into chunks
      await _streamResponse(sessionId, aiMessageId, fullResponse);

    } catch (e) {
      print('Error in _generateStreamingResponse: $e');
      // Send error message
      final errorMessage = ChatMessage(
        id: _generateMessageId(),
        content: 'Sorry, I encountered an error. Please try again.',
        type: MessageType.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.completed,
      );
      _sessions[sessionId] = session.addMessage(errorMessage);
      _streamControllers[sessionId]?.add(errorMessage);
    }
  }

  /// Optimized response generation with semantic search integration
  Future<String> _generateOptimizedResponse(String userMessage) async {
    try {
      // Step 1: Search capsules for relevant knowledge FIRST
      print('🔍 Searching local knowledge capsules for: "$userMessage"');
      final capsuleResults = await _capsuleSearchService.search(userMessage, maxResults: 5);
      
      print('📊 Search results: ${capsuleResults.results.length} total');
      for (int i = 0; i < capsuleResults.results.length; i++) {
        final result = capsuleResults.results[i];
        final cleanedContent = _cleanTextContent(result.content);
        final contentPreview = cleanedContent.length > 100 ? cleanedContent.substring(0, 100) : cleanedContent;
        print('  [$i] Similarity: ${(result.similarity * 100).toStringAsFixed(1)}% - $contentPreview...');
      }

      // Only use capsule response if we have highly relevant results
      if (capsuleResults.hasResults && _hasHighlyRelevantResults(capsuleResults)) {
        print('🔄 Found highly relevant capsule data, using capsule-based response...');
        final capsuleResponse = await _addEmergencyContextWithCapsules(userMessage, capsuleResults);
        
        // If capsule response is substantial, use it
        if (capsuleResponse.length > 100 && !capsuleResponse.contains("I don't have specific information")) {
          print('✅ Using capsule-based response (${capsuleResponse.length} chars)');
          return capsuleResponse;
        } else {
          final previewLength = capsuleResponse.length > 100 ? 100 : capsuleResponse.length;
          print('⚠️ Capsule response not substantial enough: ${capsuleResponse.substring(0, previewLength)}...');
        }
      } else {
        print('📊 Capsule results not highly relevant. HasResults: ${capsuleResults.hasResults}, HighlyRelevant: ${_hasHighlyRelevantResults(capsuleResults)}');
      }
      
      // Step 2: Ensure model is loaded and ready
      if (!_modelPersistentlyLoaded) {
        await _loadAndPersistModel();
      }

      // Step 3: If we have relevant capsule data, enhance the prompt with context
      String enhancedPrompt = userMessage;
      if (capsuleResults.hasResults && _hasRelevantResults(capsuleResults)) {
        enhancedPrompt = _createEnhancedPrompt(userMessage, capsuleResults);
        print('📝 Enhanced prompt with ${capsuleResults.results.length} relevant knowledge pieces');
      }

      // Step 4: Try to use the native model service with enhanced prompt
      print('🤖 Attempting response generation with native model service...');
      final response = await _nativeModelService.generateResponse(enhancedPrompt);
      
      // Check if we got a real response (not a fallback message)
      if (response.isNotEmpty && 
          !response.contains('having trouble generating') && 
          !response.contains('install knowledge capsules') &&
          !response.contains('For true emergencies, please contact local emergency services') &&
          !response.contains('السلام عليكم') && // Arabic greeting indicates fallback
          !response.contains('بسم الله') && // Basmala indicates fallback
          !response.contains('check the Capsules section') &&
          !response.contains('visit the Capsules section') &&
          !response.contains('explore the Capsules section')) {
        return response;
      }

      // Step 5: If model fails but we have capsules, use capsule-only response
      if (capsuleResults.hasResults) {
        print('📚 Falling back to capsule-only response');
        return await _addEmergencyContextWithCapsules(userMessage, capsuleResults);
      }

      // Step 6: If we got a fallback, try direct llama service
      if (_isModelLoaded && _useNativeModel) {
        print('🦙 Trying direct LlamaService response generation...');
        final llamaResponse = await _nativeModelService.llamaService.generateResponse(enhancedPrompt);
        if (llamaResponse.isNotEmpty && !llamaResponse.contains('Error:')) {
          return llamaResponse;
        }
      }

      // Step 7: Final fallback
      return response; // Return the fallback message
    } catch (e) {
      print('❌ Error in optimized response generation: $e');
      return await _generateFallbackResponse(userMessage);
    }
  }

  /// Create enhanced prompt by combining user message with relevant capsule context
  String _createEnhancedPrompt(String userMessage, CapsuleSearchResult capsuleResults) {
    if (capsuleResults.results.isEmpty) {
      return userMessage;
    }

    // Extract top relevant information
    final relevantInfo = <String>[];
    for (final result in capsuleResults.results) {
      if (result.similarity > 0.25 && relevantInfo.length < 3) { // Reasonable threshold for prompt enhancement
        final cleanedContent = _cleanTextContent(result.content);
        if (cleanedContent.isNotEmpty) {
          relevantInfo.add(cleanedContent);
        }
      }
    }

    if (relevantInfo.isEmpty) {
      return userMessage;
    }

    // Create enhanced prompt using emergency format
    return '''
Context from local knowledge base:
${relevantInfo.join('\n\n')}

User Question: $userMessage

Please provide a helpful response based on the context above and your knowledge. Format your response using the emergency response format with <response>, <summary>, <detailed_answer>, and <additional_info> tags.
''';
  }

  /// Load model once and keep it loaded for better performance
  Future<void> _loadAndPersistModel() async {
    try {
      if (_modelPersistentlyLoaded) return;

      print('🔄 Loading model for persistent use...');
      
      // Get available models
      final availableModels = await _getAvailableModelsWithCorrectPath();
      
      if (availableModels.isEmpty) {
        // Try to copy model from host system
        final copySuccess = await _copyModelFromHost();
        if (copySuccess) {
          final availableModelsAfterCopy = await _getAvailableModelsWithCorrectPath();
          if (availableModelsAfterCopy.isNotEmpty) {
            availableModels.addAll(availableModelsAfterCopy);
          }
        }
      }

      if (availableModels.isNotEmpty) {
        // Load the first available model with timeout
        final modelPath = availableModels.first;
        _loadedModelPath = modelPath;
        
        final loadSuccess = await _nativeModelService.loadModel(modelPath).timeout(
          _modelLoadTimeout,
          onTimeout: () {
            print('Model loading timed out after ${_modelLoadTimeout.inSeconds} seconds');
            return false;
          },
        );

        if (loadSuccess) {
          _modelPersistentlyLoaded = true;
          _isModelLoaded = true;
          _useNativeModel = true;
          _currentModel = _nativeModelService.activeModel;
          print('✅ Model loaded and ready for persistent use');
        }
      }
    } catch (e) {
      print('Error loading persistent model: $e');
      _modelPersistentlyLoaded = false;
    }
  }

  /// Generate fallback response when model is not available
  Future<String> _generateFallbackResponse(String userMessage) async {
    try {
      // Search capsules for relevant knowledge
      final capsuleResults = await _capsuleSearchService.search(userMessage);
      
      if (capsuleResults.hasResults && _hasRelevantResults(capsuleResults)) {
        // Use capsule knowledge for response
        return await _addEmergencyContextWithCapsules(userMessage, capsuleResults);
      }

      // Use intelligent pattern-based responses from native model service
      return await _nativeModelService.generateResponse(userMessage);
    } catch (e) {
      print('Error in fallback response: $e');
      return "I'm ready to help with your question. Let me use my local AI knowledge to provide you with the best answer I can.";
    }
  }

  /// Stream response by breaking it into chunks for better UX (ANR-safe)
  Future<void> _streamResponse(String sessionId, String messageId, String fullResponse) async {
    try {
      final session = _sessions[sessionId];
      if (session == null) return;

      // Use microtask to prevent blocking UI thread
      await Future.microtask(() async {
        // Break response into words for streaming effect
        final words = fullResponse.split(' ');
        String currentContent = '';
        
        // Process in smaller batches to prevent ANR
        const batchSize = 5; // Process 5 words at a time
        
        for (int i = 0; i < words.length; i += batchSize) {
          // Check if streaming was cancelled
          if (_streamingCancellation[sessionId] == true) {
            return;
          }

          // Process batch of words
          final endIndex = (i + batchSize > words.length) ? words.length : i + batchSize;
          for (int j = i; j < endIndex; j++) {
            currentContent += words[j];
            if (j < words.length - 1) currentContent += ' ';
          }

          // Update message with current content
          final updatedMessage = ChatMessage(
            id: messageId,
            content: currentContent,
            type: MessageType.assistant,
            timestamp: DateTime.now(),
            status: endIndex == words.length ? MessageStatus.completed : MessageStatus.streaming,
          );

          _sessions[sessionId] = session.updateMessage(messageId, updatedMessage);
          _streamControllers[sessionId]?.add(updatedMessage);

          // Small delay between batches to allow UI updates
          if (endIndex < words.length) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      });
    } catch (e) {
      print('Error streaming response: $e');
    }
  }

  /// Dispose method to clean up resources
  void dispose() {
    // Unload model to free memory
    if (_modelPersistentlyLoaded) {
      _nativeModelService.unloadModel();
      _modelPersistentlyLoaded = false;
    }
    
    // Close all stream controllers
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
    _sessions.clear();
  }

  // Helper methods
  String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  // Check if capsule search results are relevant enough for enhancement
  bool _hasRelevantResults(CapsuleSearchResult capsuleResults) {
    if (capsuleResults.results.isEmpty) return false;
    
    // Check if any result has a reasonable similarity score
    for (final result in capsuleResults.results) {
      if (result.similarity > 0.2) { // Moderate threshold for enhancement
        return true;
      }
    }
    return false;
  }

  // Check if capsule search results are highly relevant (for direct capsule response)
  bool _hasHighlyRelevantResults(CapsuleSearchResult capsuleResults) {
    if (capsuleResults.results.isEmpty) return false;
    
    // Require higher similarity AND keyword relevance for direct capsule responses
    int highlyRelevantCount = 0;
    for (final result in capsuleResults.results) {
      if (result.similarity > 0.4) { // High similarity threshold
        highlyRelevantCount++;
      }
    }
    
    // Need at least 2 highly relevant results to use capsule-only response
    return highlyRelevantCount >= 2;
  }

  /// Generate emergency response using capsule knowledge
  Future<String> _addEmergencyContextWithCapsules(String userMessage, CapsuleSearchResult capsuleResults) async {
    try {
      if (capsuleResults.results.isEmpty) {
        return "I don't have specific information about that in my local knowledge base.";
      }

      // Extract relevant context from search results
      final relevantInfo = <String>[];
      for (final result in capsuleResults.results) {
        if (result.similarity > 0.3) { // Higher threshold for emergency context
          // Clean the content to ensure proper formatting
          final cleanedContent = _cleanTextContent(result.content);
          if (cleanedContent.isNotEmpty) {
            relevantInfo.add(cleanedContent);
          }
        }
      }

      if (relevantInfo.isEmpty) {
        return "I found some information in my knowledge base but it doesn't seem directly relevant to your question.";
      }

      // Create emergency-focused response using CLAUDE.md format
      final contextualInfo = relevantInfo.take(3).join('\n\n'); // Top 3 results
      
      return '''
<response>
<summary>Emergency information from local knowledge base</summary>
<detailed_answer>
Based on your question about "$userMessage", here's relevant information from my offline knowledge:

$contextualInfo

This information is stored locally and doesn't require internet access.
</detailed_answer>
<additional_info>
This response was generated using pre-loaded emergency data capsules designed for offline use during crisis situations.
</additional_info>
</response>
      '''.trim();
    } catch (e) {
      print('Error generating capsule-based response: $e');
      return "I encountered an error accessing my local knowledge base. Please try rephrasing your question.";
    }
  }

  Future<List<String>> _getAvailableModelsWithCorrectPath() async {
    return await _nativeModelService.getAvailableModelFiles();
  }

  Future<bool> _copyModelFromHost() async {
    // Simple placeholder - in real implementation this would copy models
    return false;
  }

  /// Clean text content to ensure proper formatting
  String _cleanTextContent(String content) {
    if (content.isEmpty) return content;
    
    // Clean up the text by removing excessive newlines and spaces
    String cleaned = content
        .replaceAll(RegExp(r'\n\s*'), ' ')  // Replace newlines with spaces
        .replaceAll(RegExp(r'\s+'), ' ')    // Replace multiple spaces with single space
        .trim();
    
    // Additional cleaning for better readability
    cleaned = cleaned
        .replaceAll(RegExp(r'\s+([.,!?;:])'), r'$1')  // Fix spacing before punctuation
        .replaceAll(RegExp(r'([.,!?;:])\s*'), r'$1 ')  // Ensure space after punctuation
        .trim();
    
    return cleaned;
  }

  // Delete a session
  void deleteSession(String sessionId) {
    _sessions.remove(sessionId);
    final controller = _streamControllers.remove(sessionId);
    controller?.close();
    _streamingCancellation.remove(sessionId);
  }

  // Get suggestions for the user
  List<String> getSuggestions(String sessionId) {
    return [
      "What can you help me with?",
      "Tell me about emergency procedures",
      "How can I conserve resources?",
      "What should I do in an emergency?",
    ];
  }
}

