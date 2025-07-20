import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/model_runner.dart';
import '../models/ai_model.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ModelRunner _modelRunner = ModelRunner();
  final TextEditingController _inputController = TextEditingController();

  String _output = '';
  bool _isModelLoaded = false;
  bool _isProcessing = false;
  AIModel? _currentModel;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    try {
      _currentModel =
          await _modelRunner.loadModel(AppConstants.defaultModelPath);
      setState(() {
        _isModelLoaded = true;
      });
    } catch (e) {
      setState(() {
        _output = 'Error loading model: ${e.toString()}';
      });
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _runInference() async {
    if (!_isModelLoaded || _currentModel == null) {
      setState(() {
        _output = 'Model not loaded. Please wait for initialization.';
      });
      return;
    }

    if (_inputController.text.isEmpty) {
      setState(() {
        _output = 'Please enter some input text.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _output = 'Processing...';
    });

    try {
      final result = await _modelRunner.runInference(
          _currentModel!, _inputController.text);
      setState(() {
        _output = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _output = 'Error during inference: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
            const ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              if (_isModelLoaded && !_isProcessing) {
                _runInference();
              }
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('NaseerAI - Qwen2'),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          body: RawKeyboardListener(
            focusNode: FocusNode(),
            autofocus: true,
            onKey: (RawKeyEvent event) {
              // Additional keyboard handling if needed
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Qwen2 1.5B Instruct Model Status',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _isModelLoaded
                                    ? Icons.check_circle
                                    : Icons.error,
                                color:
                                    _isModelLoaded ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(_isModelLoaded
                                  ? 'Qwen2 Ready'
                                  : 'Loading Qwen2...'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        // Handle Ctrl+Enter
                        if (event.logicalKey == LogicalKeyboardKey.enter &&
                            HardwareKeyboard.instance.isControlPressed) {
                          if (_isModelLoaded && !_isProcessing) {
                            _runInference();
                          }
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextFormField(
                      controller: _inputController,
                      autofocus: true,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      enableIMEPersonalizedLearning: false,
                      decoration: const InputDecoration(
                        labelText: 'Chat with Qwen2 AI',
                        border: OutlineInputBorder(),
                        hintText:
                            'Try: "Hello", "Explain quantum physics", "Write a poem", "Help me code"...',
                        helperText:
                            'Qwen2 1.5B Instruct is running locally on your device. Ctrl+Enter to generate',
                      ),
                      maxLines: 3,
                      onFieldSubmitted: (value) {
                        if (value.isNotEmpty &&
                            _isModelLoaded &&
                            !_isProcessing) {
                          _runInference();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed:
                        _isModelLoaded && !_isProcessing ? _runInference : null,
                    child: _isProcessing
                        ? const CircularProgressIndicator()
                        : const Text('Generate Response'),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Output',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                if (_output.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: () => _copyToClipboard(_output),
                                    tooltip: 'Copy to clipboard',
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  _output.isEmpty
                                      ? 'No output yet...'
                                      : _output,
                                  style:
                                      const TextStyle(fontFamily: 'monospace'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}
