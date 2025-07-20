class ParsedResponse {
  final String? summary;
  final String? detailedAnswer;
  final String? additionalInfo;
  final String rawContent;

  const ParsedResponse({
    this.summary,
    this.detailedAnswer,
    this.additionalInfo,
    required this.rawContent,
  });

  bool get isStructured => summary != null || detailedAnswer != null || additionalInfo != null;
}

class ResponseParser {
  static ParsedResponse parse(String content) {
    if (!content.contains('<response>') && !content.contains('<summary>')) {
      return ParsedResponse(rawContent: content);
    }

    String? summary;
    String? detailedAnswer;
    String? additionalInfo;

    summary = _extractTag(content, 'summary');
    detailedAnswer = _extractTag(content, 'detailed_answer');
    additionalInfo = _extractTag(content, 'additional_info');

    return ParsedResponse(
      summary: summary,
      detailedAnswer: detailedAnswer,
      additionalInfo: additionalInfo,
      rawContent: content,
    );
  }

  static String? _extractTag(String content, String tagName) {
    final startTag = '<$tagName>';
    final endTag = '</$tagName>';
    
    final startIndex = content.indexOf(startTag);
    if (startIndex == -1) return null;
    
    final contentStart = startIndex + startTag.length;
    final endIndex = content.indexOf(endTag, contentStart);
    if (endIndex == -1) return null;
    
    return content.substring(contentStart, endIndex).trim();
  }

  static String cleanContent(String content) {
    return content
        .replaceAll(RegExp(r'</?response>'), '')
        .replaceAll(RegExp(r'</?summary>'), '')
        .replaceAll(RegExp(r'</?detailed_answer>'), '')
        .replaceAll(RegExp(r'</?additional_info>'), '')
        .trim();
  }
}