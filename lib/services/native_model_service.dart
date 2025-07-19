import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/cpp_model.dart';
import '../models/ai_model.dart';

class NativeModelService {
  static final NativeModelService _instance = NativeModelService._internal();
  factory NativeModelService() => _instance;
  NativeModelService._internal();

  final Map<String, CppModel> _loadedModels = {};
  CppModel? _activeModel;

  Future<List<String>> getAvailableModelFiles() async {
    try {
      // First try to find models in the project's model_files directory
      final currentDir = Directory.current.path;
      var modelDir = Directory('$currentDir/model_files');
      
      // If not found, fallback to app documents directory
      if (!await modelDir.exists()) {
        final appDir = await getApplicationDocumentsDirectory();
        modelDir = Directory('${appDir.path}/model_files');
        
        if (!await modelDir.exists()) {
          await modelDir.create(recursive: true);
          return [];
        }
      }

      final files = await modelDir.list().toList();
      final modelFiles = files
          .whereType<File>()
          .map((file) => file.path)
          .where((path) => _isSupportedModelFile(path))
          .toList();

      return modelFiles;
    } catch (e) {
      return [];
    }
  }

  bool _isSupportedModelFile(String path) {
    final supportedExtensions = ['.gguf', '.bin', '.safetensors', '.pt', '.pth'];
    return supportedExtensions.any((ext) => path.toLowerCase().endsWith(ext));
  }

  Future<CppModel?> loadModel(String modelPath) async {
    try {
      final modelId = _getModelIdFromPath(modelPath);
      
      if (_loadedModels.containsKey(modelId)) {
        _activeModel = _loadedModels[modelId];
        return _activeModel;
      }

      final modelName = _getModelNameFromPath(modelPath);
      final model = CppModel.fromModelFile(modelPath, modelName);

      final libraryInitialized = await model.initializeNativeLibrary();
      if (!libraryInitialized) {
        // Fallback: still create model but it will use pattern responses
        model.setStatus(ModelStatus.loaded);
        _loadedModels[modelId] = model;
        _activeModel = model;
        return model;
      }

      final modelLoaded = await model.loadModel();
      if (modelLoaded) {
        _loadedModels[modelId] = model;
        _activeModel = model;
        return model;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<String> generateResponse(String prompt, {int maxTokens = 256}) async {
    if (_activeModel == null) {
      return _getDefaultResponse(prompt);
    }

    try {
      return await _activeModel!.generateResponse(prompt, maxTokens: maxTokens);
    } catch (e) {
      return _getDefaultResponse(prompt);
    }
  }

  String _getDefaultResponse(String prompt) {
    final lowerPrompt = prompt.toLowerCase().trim();
    
    if (lowerPrompt.contains('hello') || lowerPrompt.contains('hi')) {
      return "Hello! I'm NaseerAI running in local mode. While I don't have a language model loaded, I can still provide basic assistance and emergency guidance. How can I help you?";
    }
    
    if (lowerPrompt.contains('emergency') || lowerPrompt.contains('help')) {
      return "I understand you may need emergency assistance. Even without a full language model, I can provide basic guidance:\n\n• For immediate safety: move to secure location\n• For medical emergencies: apply basic first aid\n• For communication: try visual or audio signals\n• Conserve resources: water, food, battery power\n\nWhat specific situation do you need help with?";
    }
    
    // Handle specific AI/technology questions
    if (lowerPrompt.contains('artificial intelligence') || lowerPrompt.contains('ai') || lowerPrompt.contains('machine learning')) {
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
    
    // Enhanced fallback with contextual awareness
    if (lowerPrompt.contains('water') && (lowerPrompt.contains('clean') || lowerPrompt.contains('purify'))) {
      return "Water purification methods without advanced equipment:\n\n• Solar disinfection: Clear bottles in sunlight for 6+ hours\n• Boiling: Heat water for 1-3 minutes if fuel available\n• Sand filtration: Layers of sand, gravel, and cloth\n• Plant filters: Moringa seeds or banana peels can help clarify water\n\nWhich method would work best with your available materials?";
    }
    
    if (lowerPrompt.contains('battery') || lowerPrompt.contains('power')) {
      return "Battery conservation strategies:\n\n• Lower screen brightness to minimum\n• Turn off WiFi, Bluetooth, GPS\n• Use airplane mode between essential communications\n• Close background apps\n• Save power for emergency contacts only\n\nYour phone can last 2-5 days with careful power management.";
    }
    
    if (lowerPrompt.contains('food') || lowerPrompt.contains('hungry')) {
      return "Food preservation and management without refrigeration:\n\n• Keep food cool using evaporation (wet cloth wrapping)\n• Salt, sugar, or vinegar can preserve foods longer\n• Eat perishables first, canned/dried items last\n• Small frequent meals conserve energy\n\nWhat food supplies do you currently have available?";
    }
    
    return "I'm operating in emergency mode with built-in survival protocols. I can help with water purification, power conservation, food preservation, basic medical care, and communication strategies. What immediate challenge are you facing?";
  }

  Future<bool> unloadModel() async {
    if (_activeModel != null) {
      _activeModel!.unloadModel();
      _activeModel = null;
      return true;
    }
    return false;
  }

  Future<void> unloadAllModels() async {
    for (final model in _loadedModels.values) {
      model.unloadModel();
    }
    _loadedModels.clear();
    _activeModel = null;
  }

  CppModel? get activeModel => _activeModel;
  
  List<CppModel> get loadedModels => _loadedModels.values.toList();

  bool get hasActiveModel => _activeModel != null && _activeModel!.isLoaded;

  Map<String, dynamic> getModelStatus() {
    if (_activeModel == null) {
      return {
        'has_active_model': false,
        'model_info': null,
        'library_status': 'not_loaded',
      };
    }

    return {
      'has_active_model': true,
      'model_info': _activeModel!.getModelInfo(),
      'library_status': _activeModel!.isNativeLibraryAvailable ? 'available' : 'unavailable',
    };
  }

  String _getModelIdFromPath(String path) {
    return path.split('/').last.replaceAll(RegExp(r'\.(gguf|bin|safetensors|pt|pth)$'), '');
  }

  String _getModelNameFromPath(String path) {
    return path.split('/').last
        .replaceAll(RegExp(r'\.(gguf|bin|safetensors|pt|pth)$'), '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
  }

  Future<String> getModelDirectory() async {
    // First try to find models in the project's model_files directory
    final currentDir = Directory.current.path;
    final projectModelDir = '$currentDir/model_files';
    
    if (await Directory(projectModelDir).exists()) {
      return projectModelDir;
    }
    
    // Fallback to app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/model_files';
  }

  Future<bool> isModelFileExists(String fileName) async {
    final modelDir = await getModelDirectory();
    final file = File('$modelDir/$fileName');
    return await file.exists();
  }

  Future<Map<String, dynamic>> getSystemInfo() async {
    final modelDir = await getModelDirectory();
    final dir = Directory(modelDir);
    final exists = await dir.exists();
    
    final availableFiles = exists ? await getAvailableModelFiles() : [];
    
    return {
      'model_directory': modelDir,
      'directory_exists': exists,
      'available_models': availableFiles.length,
      'model_files': availableFiles.map((path) => path.split('/').last).toList(),
      'platform': Platform.operatingSystem,
      'native_library_support': _checkNativeLibrarySupport(),
    };
  }

  bool _checkNativeLibrarySupport() {
    if (Platform.isAndroid || Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return true;
    }
    return false;
  }
}