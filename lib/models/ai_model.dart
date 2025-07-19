enum ModelType {
  textClassification,
  imageClassification,
  textGeneration,
  objectDetection,
  custom,
}

enum ModelStatus {
  unloaded,
  loading,
  loaded,
  error,
}

class AIModel {
  final String id;
  final String name;
  final String modelPath;
  final ModelType type;
  final String version;
  final Map<String, dynamic> metadata;

  ModelStatus _status = ModelStatus.unloaded;
  Object? _interpreter;
  DateTime? _loadedAt;
  String? _errorMessage;

  AIModel({
    required this.id,
    required this.name,
    required this.modelPath,
    required this.type,
    this.version = '1.0.0',
    this.metadata = const {},
  });

  ModelStatus get status => _status;
  Object? get interpreter => _interpreter;
  DateTime? get loadedAt => _loadedAt;
  String? get errorMessage => _errorMessage;

  bool get isLoaded => _status == ModelStatus.loaded;
  bool get isLoading => _status == ModelStatus.loading;
  bool get hasError => _status == ModelStatus.error;

  void setStatus(ModelStatus status) {
    _status = status;
    if (status == ModelStatus.loaded) {
      _loadedAt = DateTime.now();
      _errorMessage = null;
    } else if (status == ModelStatus.error) {
      _loadedAt = null;
    }
  }

  void setInterpreter(Object interpreter) {
    _interpreter = interpreter;
  }

  void setError(String error) {
    _errorMessage = error;
    setStatus(ModelStatus.error);
  }

  Map<String, dynamic> getInputShape() {
    return metadata['input_shape'] ?? {};
  }

  Map<String, dynamic> getOutputShape() {
    return metadata['output_shape'] ?? {};
  }

  List<String> getLabels() {
    return List<String>.from(metadata['labels'] ?? []);
  }

  double getConfidenceThreshold() {
    return metadata['confidence_threshold']?.toDouble() ?? 0.5;
  }

  factory AIModel.fromJson(Map<String, dynamic> json) {
    return AIModel(
      id: json['id'] as String,
      name: json['name'] as String,
      modelPath: json['model_path'] as String,
      type: ModelType.values.firstWhere(
        (e) => e.toString() == 'ModelType.${json['type']}',
        orElse: () => ModelType.custom,
      ),
      version: json['version'] as String? ?? '1.0.0',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model_path': modelPath,
      'type': type.toString().split('.').last,
      'version': version,
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'AIModel(id: $id, name: $name, type: $type, status: $_status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
