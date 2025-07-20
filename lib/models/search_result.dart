class SearchResult {
  final String content;
  final double similarity;
  final String source;
  final Map<String, dynamic>? metadata;

  const SearchResult({
    required this.content,
    required this.similarity,
    required this.source,
    this.metadata,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      content: json['content'] as String,
      similarity: (json['similarity'] as num).toDouble(),
      source: json['source'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'similarity': similarity,
      'source': source,
      'metadata': metadata,
    };
  }
}

class CapsuleSearchResult {
  final List<SearchResult> results;
  final String query;
  final int totalResults;

  const CapsuleSearchResult({
    required this.results,
    required this.query,
    required this.totalResults,
  });

  bool get hasResults => results.isNotEmpty;
  
  String get formattedContext {
    if (results.isEmpty) return '';
    
    final buffer = StringBuffer();
    buffer.writeln('=== RELEVANT KNOWLEDGE FROM CAPSULES ===');
    buffer.writeln('Query: $query');
    buffer.writeln('Found ${results.length} relevant pieces of information:\n');
    
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      buffer.writeln('[$i] Source: ${result.source}');
      buffer.writeln('Relevance: ${(result.similarity * 100).toStringAsFixed(1)}%');
      buffer.writeln('Content: ${result.content}');
      buffer.writeln('---');
    }
    
    buffer.writeln('=== END CAPSULE KNOWLEDGE ===\n');
    return buffer.toString();
  }
}