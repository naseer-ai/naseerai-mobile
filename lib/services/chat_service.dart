import 'dart:async';
import 'dart:math';
import '../models/chat_message.dart';
import '../models/ai_model.dart';
import '../models/search_result.dart';
import 'native_model_service.dart';
import 'capsule_search_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

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
      // Create initial AI message with "sending" status during generation
      final aiMessageId = _generateMessageId();
      final initialAiMessage = ChatMessage(
        id: aiMessageId,
        content: '',
        type: MessageType.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.sending, // Use sending status during generation
      );

      // Add to session and emit
      _sessions[sessionId] = session.addMessage(initialAiMessage);
      _streamControllers[sessionId]?.add(initialAiMessage);

      String fullResponse;

      try {
        // Use optimized response generation with timeout
        fullResponse = await _generateOptimizedResponse(userMessage).timeout(
          _responseTimeout,
          onTimeout: () =>
              "Response timed out after ${_responseTimeout.inSeconds} seconds. Please try a shorter message.",
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
      final capsuleResults =
          await _capsuleSearchService.search(userMessage, maxResults: 5);

      print('📊 Search results: ${capsuleResults.results.length} total');
      for (int i = 0; i < capsuleResults.results.length; i++) {
        final result = capsuleResults.results[i];
        final cleanedContent = _cleanTextContent(result.content);
        final contentPreview = cleanedContent.length > 100
            ? cleanedContent.substring(0, 100)
            : cleanedContent;
        print(
            '  [$i] Similarity: ${(result.similarity * 100).toStringAsFixed(1)}% - $contentPreview...');
      }

      // Only use capsule response if we have highly relevant results
      if (capsuleResults.hasResults &&
          _hasHighlyRelevantResults(capsuleResults)) {
        print(
            '🔄 Found highly relevant capsule data, using capsule-based response...');
        final capsuleResponse =
            await _addEmergencyContextWithCapsules(userMessage, capsuleResults);

        // If capsule response is substantial, use it
        if (capsuleResponse.length > 100 &&
            !capsuleResponse.contains("I don't have specific information")) {
          print(
              '✅ Using capsule-based response (${capsuleResponse.length} chars)');
          return capsuleResponse;
        } else {
          final previewLength =
              capsuleResponse.length > 100 ? 100 : capsuleResponse.length;
          print(
              '⚠️ Capsule response not substantial enough: ${capsuleResponse.substring(0, previewLength)}...');
        }
      } else {
        print(
            '📊 Capsule results not highly relevant. HasResults: ${capsuleResults.hasResults}, HighlyRelevant: ${_hasHighlyRelevantResults(capsuleResults)}');
      }

      // Step 2: Ensure model is loaded and ready
      if (!_modelPersistentlyLoaded) {
        await _loadAndPersistModel();
      }

      // Step 3: If we have relevant capsule data, enhance the prompt with context
      String enhancedPrompt = userMessage;
      if (capsuleResults.hasResults && _hasRelevantResults(capsuleResults)) {
        enhancedPrompt = _createEnhancedPrompt(userMessage, capsuleResults);
        print(
            '📝 Enhanced prompt with ${capsuleResults.results.length} relevant knowledge pieces');
      }

      // Step 4: Try to use the native model service with enhanced prompt
      print('🤖 Attempting response generation with native model service...');

      String rawResponse =
          await _nativeModelService.generateResponse(enhancedPrompt);

      // Check response quality and retry if needed
      int qualityScore = _evaluateResponseQuality(rawResponse, userMessage);
      int retryCount = 0;
      const maxRetries = 2;

      while (qualityScore < 50 && retryCount < maxRetries) {
        print(
            '🔄 Response quality low ($qualityScore%), retrying with different approach...');

        // Try with a more focused prompt
        final retryPrompt =
            _createFocusedRetryPrompt(userMessage, capsuleResults);
        rawResponse = await _nativeModelService.generateResponse(retryPrompt);
        qualityScore = _evaluateResponseQuality(rawResponse, userMessage);
        retryCount++;
      }

      // Post-process the response to improve quality
      final response = _postProcessResponse(rawResponse, userMessage);

      // Check if we got a real response (not a fallback message)
      if (response.isNotEmpty &&
          !response.contains('having trouble generating') &&
          !response.contains('install knowledge capsules') &&
          !response.contains(
              'For true emergencies, please contact local emergency services') &&
          !response
              .contains('السلام عليكم') && // Arabic greeting indicates fallback
          !response.contains('بسم الله') && // Basmala indicates fallback
          !response.contains('check the Capsules section') &&
          !response.contains('visit the Capsules section') &&
          !response.contains('explore the Capsules section')) {
        return response;
      }

      // Step 5: If model fails but we have capsules, use capsule-only response
      if (capsuleResults.hasResults) {
        print('📚 Falling back to capsule-only response');
        return await _addEmergencyContextWithCapsules(
            userMessage, capsuleResults);
      }

      // Step 6: If we got a fallback, try direct llama service with system prompt
      if (_isModelLoaded && _useNativeModel) {
        print('🦙 Trying direct LlamaService response generation...');
        final systemPromptedMessage =
            assistantSystemPrompt + '\n\nUser: $userMessage\n\nNaseerAI:';
        final llamaResponse = await _nativeModelService.llamaService
            .generateResponse(systemPromptedMessage);
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

  /// Create enhanced prompt with proper system context and length optimization
  String _createEnhancedPrompt(
      String userMessage, CapsuleSearchResult capsuleResults) {
    // Start with optimized system prompt for small models
    String fullPrompt = assistantSystemPrompt + '\n\n';

    // Add capsule context if available - but keep it concise for small models
    if (capsuleResults.results.isNotEmpty) {
      final relevantInfo = <String>[];
      int totalLength = 0;
      const maxContextLength = 300; // Limit context for small models

      for (final result in capsuleResults.results) {
        if (result.similarity > 0.3 && relevantInfo.length < 2) {
          // Max 2 results
          final cleanedContent = _cleanTextContent(result.content);
          if (cleanedContent.isNotEmpty &&
              totalLength + cleanedContent.length < maxContextLength) {
            // Truncate if too long
            final truncatedContent = cleanedContent.length > 150
                ? cleanedContent.substring(0, 150) + "..."
                : cleanedContent;
            relevantInfo.add(truncatedContent);
            totalLength += truncatedContent.length;
          }
        }
      }

      if (relevantInfo.isNotEmpty) {
        fullPrompt += 'CONTEXT: ';
        fullPrompt += relevantInfo.join(' | ');
        fullPrompt += '\n\n';
      }
    }

    // Add conversation history for context (last 2 messages max)
    final session = _sessions.values.firstWhere(
        (s) => s.messages.any((m) => m.content == userMessage),
        orElse: () => ChatSession(
            id: '',
            createdAt: DateTime.now(),
            lastActivity: DateTime.now(),
            messages: []));

    if (session.messages.length > 2) {
      final recentMessages = session.messages.length > 4
          ? session.messages.sublist(session.messages.length - 4)
          : session.messages; // Last 2 exchanges
      for (int i = 0; i < recentMessages.length - 1; i += 2) {
        if (i + 1 < recentMessages.length) {
          final userMsg = recentMessages[i];
          final aiMsg = recentMessages[i + 1];
          if (userMsg.type == MessageType.user &&
              aiMsg.type == MessageType.assistant) {
            fullPrompt +=
                'User: ${userMsg.content.length > 100 ? userMsg.content.substring(0, 100) + "..." : userMsg.content}\n';
            fullPrompt +=
                'NaseerAI: ${aiMsg.content.length > 100 ? aiMsg.content.substring(0, 100) + "..." : aiMsg.content}\n\n';
          }
        }
      }
    }

    // Add current user message with clear formatting
    fullPrompt += 'User: $userMessage\n\nNaseerAI: ';

    return fullPrompt;
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
          final availableModelsAfterCopy =
              await _getAvailableModelsWithCorrectPath();
          if (availableModelsAfterCopy.isNotEmpty) {
            availableModels.addAll(availableModelsAfterCopy);
          }
        }
      }

      if (availableModels.isNotEmpty) {
        // Load the first available model with timeout
        final modelPath = availableModels.first;

        final loadSuccess =
            await _nativeModelService.loadModel(modelPath).timeout(
          _modelLoadTimeout,
          onTimeout: () {
            print(
                'Model loading timed out after ${_modelLoadTimeout.inSeconds} seconds');
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
        return await _addEmergencyContextWithCapsules(
            userMessage, capsuleResults);
      }

      // Use intelligent pattern-based responses with system prompt from native model service
      final systemPromptedMessage =
          assistantSystemPrompt + '\n\nUser: $userMessage\n\nNaseerAI:';
      return await _nativeModelService.generateResponse(systemPromptedMessage);
    } catch (e) {
      print('Error in fallback response: $e');
      return "I'm ready to help with your question. Let me use my local AI knowledge to provide you with the best answer I can.";
    }
  }

  /// Stream response by breaking it into chunks for better UX (ANR-safe)
  Future<void> _streamResponse(
      String sessionId, String messageId, String fullResponse) async {
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
          final endIndex =
              (i + batchSize > words.length) ? words.length : i + batchSize;
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
            status: endIndex == words.length
                ? MessageStatus.completed
                : MessageStatus.streaming,
          );

          _sessions[sessionId] =
              session.updateMessage(messageId, updatedMessage);
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
      if (result.similarity > 0.2) {
        // Moderate threshold for enhancement
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
      if (result.similarity > 0.4) {
        // High similarity threshold
        highlyRelevantCount++;
      }
    }

    // Need at least 2 highly relevant results to use capsule-only response
    return highlyRelevantCount >= 2;
  }

  /// Generate emergency response using capsule knowledge
  Future<String> _addEmergencyContextWithCapsules(
      String userMessage, CapsuleSearchResult capsuleResults) async {
    try {
      if (capsuleResults.results.isEmpty) {
        return "I don't have specific information about that in my local knowledge base.";
      }

      // Extract relevant context from search results
      final relevantInfo = <String>[];
      for (final result in capsuleResults.results) {
        if (result.similarity > 0.3) {
          // Higher threshold for emergency context
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
<summary>Information from local knowledge base (Capsules)</summary>
<detailed_answer>
Based on your question about "$userMessage", here's relevant information from my offline knowledge:

$contextualInfo

This information is stored locally and doesn't require internet access.
</detailed_answer>
</response>
      '''
          .trim();
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
        .replaceAll(RegExp(r'\n\s*'), ' ') // Replace newlines with spaces
        .replaceAll(
            RegExp(r'\s+'), ' ') // Replace multiple spaces with single space
        .trim();

    // Additional cleaning for better readability
    cleaned = cleaned
        .replaceAll(
            RegExp(r'\s+([.,!?;:])'), r'$1') // Fix spacing before punctuation
        .replaceAll(
            RegExp(r'([.,!?;:])\s*'), r'$1 ') // Ensure space after punctuation
        // Remove markdown formatting artifacts and unwanted symbols
        .replaceAll(RegExp(r'\$\d+'), '') // Remove $1, $2, etc.
        .replaceAll(RegExp(r'[●•]'), '•') // Normalize bullet points
        .replaceAll(
            RegExp(r'\*\s*'), '• ') // Convert asterisks to bullet points
        .replaceAll(RegExp(r'[-−]\s*'), '• ') // Convert dashes to bullet points
        .replaceAll(RegExp(r'\d+\.\s*'),
            '• ') // Convert numbered lists to bullet points
        .replaceAll(RegExp(r'#{1,6}\s*'), '') // Remove markdown headers
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1') // Remove bold formatting
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1') // Remove italic formatting
        .replaceAll(RegExp(r'`(.*?)`'), r'$1') // Remove code formatting
        .trim();

    return cleaned;
  }

  /// Post-process model responses to improve quality for small models
  String _postProcessResponse(String response, String userMessage) {
    if (response.isEmpty) return response;

    String processed = response;

    // 1. Remove common model artifacts
    processed = processed
        .replaceAll(
            RegExp(r'^(User:|NaseerAI:|Assistant:)\s*', multiLine: true), '')
        .replaceAll(
            RegExp(r'<\|.*?\|>', multiLine: true), '') // Remove special tokens
        .replaceAll(RegExp(r'\[INST\].*?\[/INST\]', multiLine: true),
            '') // Remove instruction tokens
        .replaceAll(
            RegExp(r'###.*?###', multiLine: true), '') // Remove section markers
        .trim();

    // 2. Fix repetitive content
    processed = _removeRepetition(processed);

    // 3. Ensure proper sentence structure
    processed = _improveSentenceStructure(processed);

    // 4. Add context-specific improvements
    processed = _addContextSpecificImprovements(processed, userMessage);

    // 5. Ensure proper length (not too short, not too long)
    if (processed.length < 20) {
      processed =
          "I understand you're asking about $userMessage. Let me provide some helpful information: $processed";
    } else if (processed.length > 1000) {
      // Truncate very long responses but keep them coherent
      final sentences = processed.split(RegExp(r'[.!?]+\s+'));
      processed = '';
      for (final sentence in sentences) {
        if (processed.length + sentence.length > 800) break;
        processed += sentence + '. ';
      }
      processed = processed.trim();
    }

    return processed;
  }

  /// Remove repetitive content from responses
  String _removeRepetition(String text) {
    final sentences = text.split(RegExp(r'[.!?]+\s+'));
    final uniqueSentences = <String>[];
    final seenContent = <String>{};

    for (final sentence in sentences) {
      final normalizedSentence = sentence.toLowerCase().trim();
      if (normalizedSentence.length > 10 &&
          !seenContent.contains(normalizedSentence)) {
        seenContent.add(normalizedSentence);
        uniqueSentences.add(sentence.trim());
      }
    }

    return uniqueSentences.join('. ').trim();
  }

  /// Improve sentence structure and flow
  String _improveSentenceStructure(String text) {
    String improved = text;

    // Fix common grammar issues
    improved = improved
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces
        .replaceAll(RegExp(r'\.+'), '.') // Multiple periods
        .replaceAll(RegExp(r'\?+'), '?') // Multiple question marks
        .replaceAll(RegExp(r'!+'), '!') // Multiple exclamation marks
        .replaceAll(RegExp(r',\s*,'), ',') // Double commas
        .replaceAll(RegExp(r'^\s*[,.]'), '') // Leading punctuation
        .trim();

    // Ensure sentences start with capital letters
    final sentences = improved.split(RegExp(r'(?<=[.!?])\s+'));
    final correctedSentences = sentences.map((sentence) {
      if (sentence.isNotEmpty) {
        return sentence[0].toUpperCase() + sentence.substring(1);
      }
      return sentence;
    }).toList();

    return correctedSentences.join(' ').trim();
  }

  /// Add context-specific improvements based on user message
  String _addContextSpecificImprovements(String response, String userMessage) {
    String improved = response;

    // For medical/emergency questions, ensure safety disclaimers
    final medicalKeywords = [
      'pain',
      'injury',
      'hurt',
      'blood',
      'emergency',
      'accident',
      'burn',
      'cut',
      'wound'
    ];
    final ismedical = medicalKeywords.any((keyword) =>
        userMessage.toLowerCase().contains(keyword) ||
        response.toLowerCase().contains(keyword));

    if (ismedical &&
        !response.contains('emergency') &&
        !response.contains('seek medical')) {
      improved +=
          '\n\nNote: For serious injuries or emergencies, seek immediate professional medical help.';
    }

    // For unclear responses, add helpful context
    if (response.length < 50 ||
        response.contains('I don\'t know') ||
        response.contains('unclear')) {
      improved =
          'Based on your question about "${userMessage.length > 50 ? userMessage.substring(0, 50) + "..." : userMessage}", $improved';
    }

    return improved.trim();
  }

  /// Evaluate response quality on a scale of 0-100
  int _evaluateResponseQuality(String response, String userMessage) {
    if (response.isEmpty) return 0;

    int score = 50; // Base score

    // Length evaluation
    if (response.length < 20) {
      score -= 30; // Too short
    } else if (response.length > 50 && response.length < 300) {
      score += 20; // Good length
    } else if (response.length > 500) {
      score -= 10; // Too long for small models
    }

    // Content quality checks
    final lowercaseResponse = response.toLowerCase();
    final lowercaseQuestion = userMessage.toLowerCase();

    // Check for relevance (question keywords in response)
    final questionWords =
        lowercaseQuestion.split(' ').where((w) => w.length > 3).toSet();
    final responseWords = lowercaseResponse.split(' ').toSet();
    final matchingWords = questionWords.intersection(responseWords).length;
    score += (matchingWords * 5).clamp(0, 20);

    // Penalize poor quality indicators
    if (lowercaseResponse.contains('i don\'t know')) score -= 20;
    if (lowercaseResponse.contains('unclear') ||
        lowercaseResponse.contains('confusing')) score -= 15;
    if (lowercaseResponse.contains('error') ||
        lowercaseResponse.contains('cannot')) score -= 10;

    // Reward good quality indicators
    if (lowercaseResponse.contains('steps') ||
        lowercaseResponse.contains('follow')) score += 10;
    if (lowercaseResponse.contains('first') ||
        lowercaseResponse.contains('then')) score += 5;
    if (RegExp(r'\d+\.').hasMatch(response)) score += 10; // Numbered lists

    // Check for repetition
    final sentences = response.split(RegExp(r'[.!?]+'));
    final uniqueSentences = sentences.toSet().length;
    if (uniqueSentences < sentences.length * 0.8) score -= 15; // Too repetitive

    // Check sentence structure
    if (!RegExp(r'^[A-Z]').hasMatch(response.trim()))
      score -= 5; // Doesn't start with capital
    if (!RegExp(r'[.!?]$').hasMatch(response.trim()))
      score -= 5; // Doesn't end properly

    return score.clamp(0, 100);
  }

  /// Create a focused retry prompt for better quality
  String _createFocusedRetryPrompt(
      String userMessage, CapsuleSearchResult capsuleResults) {
    // Shorter, more direct prompt for retry attempts
    String prompt = '''
You are NaseerAI. Give a direct, helpful answer to this question.

Question: $userMessage

Instructions:
- Be specific and practical
- Use numbered steps if helpful
- Keep it clear and concise
- Don't repeat yourself

Answer: ''';

    // Add minimal context if available
    if (capsuleResults.results.isNotEmpty) {
      final bestResult = capsuleResults.results.first;
      if (bestResult.similarity > 0.3) {
        final context = _cleanTextContent(bestResult.content);
        if (context.length < 200) {
          prompt = prompt.replaceFirst('Answer: ',
              'Context: ${context.substring(0, context.length.clamp(0, 150))}...\n\nAnswer: ');
        }
      }
    }

    return prompt;
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
    // Very simple, direct questions that should work with any language model
    return [
      "Burns Treatment",
      "Cuts and Scrapes Treatment",
    ];
  }

  // Get available capsules from the capsule search service
  List<String> getAvailableCapsules() {
    return _capsuleSearchService.getAvailableCapsules();
  }

  // System prompt for NaseerAI - optimized for small models
  final String assistantSystemPrompt = '''
You are NaseerAI, an expert offline medical and emergency assistant.

CRITICAL INSTRUCTIONS:
1. Always give direct, practical answers
2. Use numbered steps for clarity
3. Be specific and actionable
4. Stay focused on the question asked
5. Never mention internet or online resources

RESPONSE FORMAT:
For medical/emergency questions:
1. [Immediate action needed]
2. [Step-by-step instructions]
3. [When to seek further help]

For other questions:
- Give direct, helpful answers
- Use simple, clear language
- Provide specific examples

You have access to medical first aid knowledge. Always prioritize safety.
''';
}
