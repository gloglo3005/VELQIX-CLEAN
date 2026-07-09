import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../services/app_translations.dart';
import 'property_detail_screen.dart';

// ─── Un message de la conversation ────────────────────────────────────────────
class _ChatEntry {
  final String role; // 'user' | 'assistant'
  final String text;
  final List<PropertyModel> properties;
  final bool isError;

  _ChatEntry({
    required this.role,
    required this.text,
    this.properties = const [],
    this.isError = false,
  });
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatEntry> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Message d'accueil (clé déjà présente dans app_translations.dart)
    _messages.add(_ChatEntry(role: 'assistant', text: tr('ai_hello_reply')));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatEntry(role: 'user', text: text));
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    // Historique envoyé au backend : uniquement role + content,
    // dans le même format que ChatRequestBody côté serveur (ai.ts)
    final history = _messages
        .where((m) => !m.isError)
        .map((m) => {'role': m.role, 'content': m.text})
        .toList();
    // On retire le dernier élément (le message qu'on vient d'ajouter) car
    // il est déjà envoyé séparément dans le champ "message"
    if (history.isNotEmpty) history.removeLast();

    try {
      final res = await ApiService.instance.post('/ai/chat', {
        'message': text,
        'history': history,
      });

      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        final replyText = data['text'] as String? ?? '';
        final rawProperties = (data['properties'] as List?) ?? [];
        final properties = rawProperties
            .map((p) => PropertyModel.fromJson(p as Map<String, dynamic>))
            .toList();

        setState(() {
          _messages.add(_ChatEntry(
            role: 'assistant',
            text: replyText,
            properties: properties,
          ));
        });
      } else {
        setState(() {
          _messages.add(_ChatEntry(
            role: 'assistant',
            text: res['message'] as String? ?? tr('ai_not_understood'),
            isError: true,
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(_ChatEntry(
          role: 'assistant',
          text: tr('ai_not_understood'),
          isError: true,
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('VelqIA', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessage(_messages[index]),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('L\'assistant réfléchit…', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatEntry entry) {
    final isUser = entry.role == 'user';

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              color: isUser
                  ? AppTheme.primary
                  : entry.isError
                      ? AppTheme.error.withOpacity(0.08)
                      : AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: isUser ? null : Border.all(color: AppTheme.divider),
            ),
            child: Text(
              entry.text,
              style: TextStyle(
                color: isUser
                    ? Colors.white
                    : entry.isError
                        ? AppTheme.error
                        : AppTheme.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ),
        if (entry.properties.isNotEmpty) _buildPropertiesRow(entry.properties),
      ],
    );
  }

  Widget _buildPropertiesRow(List<PropertyModel> properties) {
    return SizedBox(
      height: 172,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        itemCount: properties.length,
        itemBuilder: (context, index) {
          final p = properties[index];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: p)),
            ),
            child: Container(
              width: 150,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: p.firstImage.isNotEmpty
                        ? Image.network(
                            p.firstImage,
                            height: 90, width: double.infinity, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 90, color: AppTheme.divider,
                              child: const Icon(Icons.image_not_supported_outlined),
                            ),
                          )
                        : Container(
                            height: 90, color: AppTheme.divider,
                            child: const Icon(Icons.home_outlined),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          p.adresse.short,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${p.prix.toInt()} FCFA',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Maison à Lomé, voiture à louer…',
                  filled: true,
                  fillColor: AppTheme.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primary,
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 19),
                onPressed: _isLoading ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}