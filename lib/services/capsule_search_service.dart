import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/search_result.dart';
import '../utils/constants.dart';

class CapsuleSearchService {
  static const String _capsulesPath = 'capsules/';
  static const double _similarityThreshold =
      0.05; // Lower threshold for our approach
  static const int _maxResults = 5;

  final Map<String, List<Map<String, dynamic>>> _embeddingsCache = {};
  bool _isInitialized = false;

  static final CapsuleSearchService _instance =
      CapsuleSearchService._internal();
  factory CapsuleSearchService() => _instance;
  CapsuleSearchService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadAllEmbeddings();
      _isInitialized = true;
      print(
          'CapsuleSearchService initialized with ${_embeddingsCache.length} capsules');
    } catch (e) {
      print('Failed to initialize CapsuleSearchService: $e');
    }
  }

  Future<void> _loadAllEmbeddings() async {
    try {
      print('📦 Loading capsule embeddings...');
      final dir = Directory(AppConstants.capsulesDir);
      List<String> capsuleFiles = [];
      if (await dir.exists()) {
        capsuleFiles = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .map((f) => f.path)
            .toList();
        print(
            '📂 Found ${capsuleFiles.length} capsule files in ${AppConstants.capsulesDir}');
        for (final file in capsuleFiles) {
          print('  - Capsule: $file');
        }
        for (final filePath in capsuleFiles) {
          print('� Loading capsule file: $filePath');
          await _loadEmbeddingFile(filePath, isFile: true);
        }
      } else {
        print('❌ Capsules directory not found: ${AppConstants.capsulesDir}');
      }
      if (capsuleFiles.isEmpty) {
        print('❌ No capsule embedding files found to load');
      }
    } catch (e) {
      print('❌ Error loading embeddings: $e');
    }
  }

  Future<void> _loadEmbeddingFile(String filePath, {bool isFile = true}) async {
    try {
      final jsonContent = await File(filePath).readAsString();
      final Map<String, dynamic> data = json.decode(jsonContent);

      final List<dynamic> embeddings = data['embeddings'] ?? [];
      final List<dynamic> sentences = data['sentences'] ?? [];

      if (embeddings.length != sentences.length) {
        print('Warning: Embeddings and sentences count mismatch in $filePath');
        return;
      }

      final fileName = path.basenameWithoutExtension(filePath);
      final processedEmbeddings = <Map<String, dynamic>>[];

      for (int i = 0; i < embeddings.length; i++) {
        final embedding = List<double>.from(embeddings[i].cast<double>());
        final rawSentence = sentences[i].toString().trim();

        // Clean up the sentence by removing excessive newlines and spaces
        final cleanedSentence = rawSentence
            .replaceAll(RegExp(r'\n\s*'), ' ') // Replace newlines with spaces
            .replaceAll(RegExp(r'\s+'),
                ' ') // Replace multiple spaces with single space
            .trim();

        if (cleanedSentence.isNotEmpty &&
            cleanedSentence.split(' ').length > 3) {
          // Only keep sentences with more than 3 words
          processedEmbeddings.add({
            'content': cleanedSentence,
            'embedding': embedding,
            'metadata': {
              'source': fileName,
              'index': i,
              'file_path': filePath,
            }
          });
        }
      }

      _embeddingsCache[fileName] = processedEmbeddings;
      print('Loaded ${processedEmbeddings.length} embeddings from: $fileName');
    } catch (e) {
      print('Error loading embedding file $filePath: $e');
    }
  }

  Future<CapsuleSearchResult> search(String query,
      {int maxResults = _maxResults}) async {
    await initialize();

    if (query.trim().isEmpty) {
      return CapsuleSearchResult(
        results: [],
        query: query,
        totalResults: 0,
      );
    }

    final queryEmbedding = await _generateQueryEmbedding(query);
    final allResults = <SearchResult>[];

    // Search through all loaded capsules using hybrid approach
    for (final entry in _embeddingsCache.entries) {
      final capsuleName = entry.key;
      final embeddings = entry.value;

      for (final item in embeddings) {
        // Calculate semantic similarity
        final semanticSimilarity = _calculateCosineSimilarity(
            queryEmbedding, List<double>.from(item['embedding']));

        // Calculate keyword-based similarity
        final keywordSimilarity =
            _calculateKeywordSimilarity(query, item['content']);

        // Combine both scores with weights
        final combinedScore =
            (semanticSimilarity * 0.4) + (keywordSimilarity * 0.6);

        // Use a lower threshold since we're combining scores
        if (combinedScore >= _similarityThreshold || keywordSimilarity > 0.2) {
          allResults.add(SearchResult(
            content: item['content'],
            similarity: combinedScore,
            source: item['metadata']['source'] ?? capsuleName,
            metadata: {
              ...item['metadata'],
              'semantic_score': semanticSimilarity,
              'keyword_score': keywordSimilarity,
              'combined_score': combinedScore,
            },
          ));
        }
      }
    }

    // Sort by combined similarity score and take top results
    allResults.sort((a, b) => b.similarity.compareTo(a.similarity));
    final topResults = allResults.take(maxResults).toList();

    return CapsuleSearchResult(
      results: topResults,
      query: query,
      totalResults: allResults.length,
    );
  }

  Future<List<double>> _generateQueryEmbedding(String query) async {
    // Simple approximation of query embedding using TF-IDF-like approach
    // In a production system, you'd use the same embedding model that was used for the documents
    final words = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'));
    final wordFreq = <String, int>{};

    // Count word frequencies
    for (final word in words) {
      if (word.isNotEmpty) {
        wordFreq[word] = (wordFreq[word] ?? 0) + 1;
      }
    }

    // Generate embedding based on word frequencies and positions
    final embedding = List.generate(384, (i) {
      double value = 0.0;
      for (final entry in wordFreq.entries) {
        final word = entry.key;
        final freq = entry.value;
        // Create a deterministic but distributed representation
        final hashBase = word.hashCode.abs();
        final dimension = (hashBase + i * 17) % 384;
        if (dimension == i) {
          value += freq * 0.1; // Term frequency weight
        }
        // Add positional encoding
        value += math.sin(i * math.pi / 384) * 0.01 * freq;
      }
      return value;
    });

    return _normalizeVector(embedding);
  }

  double _calculateKeywordSimilarity(String query, String content) {
    // Extract meaningful words from query and content
    final queryWords = _extractMeaningfulWords(query);
    final contentWords = _extractMeaningfulWords(content);

    if (queryWords.isEmpty || contentWords.isEmpty) return 0.0;

    // Count matches
    int exactMatches = 0;
    int partialMatches = 0;

    for (final queryWord in queryWords) {
      if (contentWords.contains(queryWord)) {
        exactMatches++;
      } else {
        // Check for partial matches (contains)
        for (final contentWord in contentWords) {
          if (contentWord.contains(queryWord) ||
              queryWord.contains(contentWord)) {
            partialMatches++;
            break;
          }
        }
      }
    }

    // Calculate similarity score
    final exactScore = exactMatches / queryWords.length;
    final partialScore = partialMatches / queryWords.length * 0.5;

    return exactScore + partialScore;
  }

  List<String> _extractMeaningfulWords(String text) {
    // Remove special characters and split into words
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2) // Ignore short words
        .where((word) => !_isStopWord(word)) // Remove common stop words
        .toList();

    return words;
  }

  bool _isStopWord(String word) {
    const stopWords = {
      'the',
      'and',
      'for',
      'are',
      'but',
      'not',
      'you',
      'can',
      'her',
      'was',
      'one',
      'our',
      'had',
      'by',
      'what',
      'were',
      'they',
      'we',
      'when',
      'your',
      'said',
      'each',
      'which',
      'she',
      'how',
      'other',
      'than',
      'now',
      'very',
      'my',
      'be',
      'has',
      'he',
      'in',
      'will',
      'on',
      'it',
      'of',
      'an',
      'as',
      'is',
      'his',
      'have',
      'that',
      'to',
      'a',
      'with',
      'at',
      'this',
      'or',
      'from',
      'if',
      'all'
    };
    return stopWords.contains(word);
  }

  double _calculateCosineSimilarity(List<double> vec1, List<double> vec2) {
    if (vec1.length != vec2.length) return 0.0;

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      norm1 += vec1[i] * vec1[i];
      norm2 += vec2[i] * vec2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;

    return dotProduct / (math.sqrt(norm1) * math.sqrt(norm2));
  }

  List<double> _normalizeVector(List<double> vector) {
    double norm = 0.0;
    for (final value in vector) {
      norm += value * value;
    }
    norm = math.sqrt(norm);

    if (norm == 0.0) return vector;

    return vector.map((value) => value / norm).toList();
  }

  void refresh() {
    _embeddingsCache.clear();
    _isInitialized = false;
  }

  // Get list of available capsule names
  List<String> getAvailableCapsules() {
    return _embeddingsCache.keys.toList();
  }
}
