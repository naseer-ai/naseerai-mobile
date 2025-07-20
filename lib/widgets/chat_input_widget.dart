import 'package:flutter/material.dart';

class ChatInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final VoidCallback? onStop;
  final VoidCallback? onShowSuggestions;
  final VoidCallback? onShowCapsules;
  final bool enabled;
  final bool isStreaming;
  final bool showSuggestionsButton;
  final bool showCapsulesButton;

  const ChatInputWidget({
    super.key,
    required this.controller,
    required this.onSend,
    this.onStop,
    this.onShowSuggestions,
    this.onShowCapsules,
    this.enabled = true,
    this.isStreaming = false,
    this.showSuggestionsButton = false,
    this.showCapsulesButton = false,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _handleSend() {
    final text = widget.controller.text.trim();
    if (text.isNotEmpty && widget.enabled && !widget.isStreaming) {
      widget.onSend(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Capsules button (left side)
            if (widget.showCapsulesButton && widget.onShowCapsules != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onShowCapsules,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.archive_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            
            // Input field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    // Text input
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        enabled: widget.enabled,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Ask me anything...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (!widget.isStreaming && widget.enabled)
                            ? (_) => _handleSend()
                            : null,
                      ),
                    ),

                    // Suggestions button (when suggestions are hidden)
                    if (widget.showSuggestionsButton &&
                        widget.onShowSuggestions != null)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onShowSuggestions,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.lightbulb_outline,
                              size: 20,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),

                    // Future: Attachment button for file uploads
                    // Currently disabled for this version
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send/Stop button
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: widget.isStreaming
                  ? FloatingActionButton.small(
                      onPressed: widget.onStop,
                      backgroundColor: Colors.red.shade600,
                      elevation: 4,
                      heroTag: "stop_button",
                      child: const Icon(
                        Icons.stop,
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  : FloatingActionButton.small(
                      onPressed:
                          widget.enabled && _hasText ? _handleSend : null,
                      backgroundColor: _getButtonColor(theme),
                      elevation: _getButtonElevation(),
                      heroTag: "send_button",
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _getButtonIcon(theme),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getButtonColor(ThemeData theme) {
    if (!widget.enabled) {
      return theme.colorScheme.surfaceContainerHighest;
    }
    if (_hasText) {
      return theme.colorScheme.primary;
    }
    return theme.colorScheme.surfaceContainerHighest;
  }

  double _getButtonElevation() {
    if (!widget.enabled) return 0;
    if (_hasText) return 6;
    return 2;
  }

  Widget _getButtonIcon(ThemeData theme) {
    if (!widget.enabled) {
      return SizedBox(
        width: 18,
        height: 18,
        key: const ValueKey('loading'),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return Icon(
      Icons.send_rounded,
      key: const ValueKey('send'),
      color: _hasText
          ? Colors.white
          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
      size: 20,
    );
  }
}
