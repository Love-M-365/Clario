import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_data_provider.dart';

class AvatarPromptScreen extends StatefulWidget {
  const AvatarPromptScreen({super.key});

  @override
  State<AvatarPromptScreen> createState() => _AvatarPromptScreenState();
}

class _AvatarPromptScreenState extends State<AvatarPromptScreen> {
  final _promptController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final currentPrompt =
        Provider.of<UserDataProvider>(context, listen: false).baseAvatarPrompt;
    if (currentPrompt != null) {
      _promptController.text = currentPrompt;
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _saveAndGenerate() async {
    final newPrompt = _promptController.text.trim();
    if (newPrompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar description cannot be empty.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final provider = Provider.of<UserDataProvider>(context, listen: false);

    try {
      await provider.saveBasePromptAndGenerateAvatars(newPrompt);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar prompt saved and avatars generated!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();

        // 🟡 NEW — detect Imagen "no image" or safety filter messages
        if (errorMsg.contains('Imagen returned no images') ||
            errorMsg.contains('no images generated') ||
            errorMsg.contains('safety') ||
            errorMsg.contains('blocked')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ Your avatar description triggered content safety filters.\n'
                'Please try a simpler, neutral description.\n\n'
                'Tip: Avoid words like "boy", "girl", "sad", "angry", or looks-related terms.',
              ),
              backgroundColor: Colors.orangeAccent,
              duration: Duration(seconds: 6),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // 🟡 Regular error handler for genuine backend issues
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMsg'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Your Avatar Description'),
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Describe your desired avatar:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Be descriptive but neutral. Example:\n'
              '"A friendly cartoon student with glasses and short brown hair, simple background"',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _promptController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Enter description here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor ??
                      theme.colorScheme.surfaceVariant.withOpacity(0.3),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Save & Generate Avatars'),
                    onPressed: _saveAndGenerate,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
