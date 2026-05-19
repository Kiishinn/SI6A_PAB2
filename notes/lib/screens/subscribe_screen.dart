import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/fcm_service.dart';

class SubscribeScreen extends StatefulWidget {
  const SubscribeScreen({super.key});

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> {
  final FcmService _fcmService = FcmService();
  final TextEditingController _topicController = TextEditingController();

  // Suggested topics
  final List<String> _suggestedTopics = [
    'keuangan',
    'berita',
    'olahraga',
    'teknologi',
    'kesehatan',
  ];

  // Currently subscribed topics
  List<String> _subscribedTopics = [];

  // Custom topics added by user
  List<String> _customTopics = [];

  // Loading states
  final Set<String> _loadingTopics = {};

  static const String _prefsKey = 'subscribed_topics';
  static const String _customPrefsKey = 'custom_topics';

  @override
  void initState() {
    super.initState();
    _loadSavedTopics();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  /// Load saved topics from SharedPreferences
  Future<void> _loadSavedTopics() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _subscribedTopics = prefs.getStringList(_prefsKey) ?? ['notes', 'berita'];
      _customTopics = prefs.getStringList(_customPrefsKey) ?? [];
    });
  }

  /// Save subscribed topics to SharedPreferences
  Future<void> _saveTopic() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _subscribedTopics);
    await prefs.setStringList(_customPrefsKey, _customTopics);
  }

  /// Toggle subscription for a topic
  Future<void> _toggleSubscription(String topic, bool subscribe) async {
    setState(() {
      _loadingTopics.add(topic);
    });

    bool success;
    if (subscribe) {
      // Subscribe via FCM (mobile) or API (web)
      if (kIsWeb) {
        success = await _fcmService.subscribeTokenToTopic(topic);
      } else {
        success = await _fcmService.subscribeToTopic(topic);
      }

      if (success) {
        setState(() {
          if (!_subscribedTopics.contains(topic)) {
            _subscribedTopics.add(topic);
          }
        });
        await _saveTopic();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil subscribe ke topic "$topic"'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal subscribe ke topic "$topic"'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Unsubscribe
      if (kIsWeb) {
        // Web doesn't support unsubscribe directly, just remove locally
        success = true;
      } else {
        success = await _fcmService.unsubscribeFromTopic(topic);
      }

      if (success) {
        setState(() {
          _subscribedTopics.remove(topic);
        });
        await _saveTopic();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil unsubscribe dari topic "$topic"'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }

    setState(() {
      _loadingTopics.remove(topic);
    });
  }

  /// Add custom topic and subscribe
  Future<void> _addCustomTopic() async {
    final topic = _topicController.text.trim().toLowerCase();

    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama topic tidak boleh kosong'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if already exists
    if (_suggestedTopics.contains(topic) || _customTopics.contains(topic)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Topic "$topic" sudah ada'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Add to custom topics
    setState(() {
      _customTopics.add(topic);
    });

    // Subscribe to it
    await _toggleSubscription(topic, true);

    _topicController.clear();
  }

  /// Remove custom topic and unsubscribe
  Future<void> _removeCustomTopic(String topic) async {
    await _toggleSubscription(topic, false);
    setState(() {
      _customTopics.remove(topic);
      _subscribedTopics.remove(topic);
    });
    await _saveTopic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Subscribe Topics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        kIsWeb
                            ? 'Subscribe topic via REST API (Web mode)'
                            : 'Subscribe/unsubscribe topic FCM secara langsung',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Input custom topic
            const Text(
              'Tambah Topic Custom',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _topicController,
                    decoration: InputDecoration(
                      hintText: 'Masukkan nama topic...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _addCustomTopic(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _addCustomTopic,
                  icon: const Icon(Icons.add),
                  label: const Text('Subscribe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Suggested Topics
            const Text(
              'Suggested Topics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Column(
                children: _suggestedTopics.map((topic) {
                  final isSubscribed = _subscribedTopics.contains(topic);
                  final isLoading = _loadingTopics.contains(topic);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSubscribed
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      child: Icon(
                        _getTopicIcon(topic),
                        color: isSubscribed ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      topic.substring(0, 1).toUpperCase() + topic.substring(1),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch(
                            value: isSubscribed,
                            activeColor: Colors.green,
                            onChanged: (value) =>
                                _toggleSubscription(topic, value),
                          ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Custom Topics
            if (_customTopics.isNotEmpty) ...[
              const Text(
                'Custom Topics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Column(
                  children: _customTopics.map((topic) {
                    final isSubscribed = _subscribedTopics.contains(topic);
                    final isLoading = _loadingTopics.contains(topic);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSubscribed
                            ? Colors.blue.shade100
                            : Colors.grey.shade200,
                        child: Icon(
                          Icons.tag,
                          color: isSubscribed ? Colors.blue : Colors.grey,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        topic.substring(0, 1).toUpperCase() +
                            topic.substring(1),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLoading)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Switch(
                              value: isSubscribed,
                              activeColor: Colors.green,
                              onChanged: (value) =>
                                  _toggleSubscription(topic, value),
                            ),
                          IconButton(
                            onPressed: () => _removeCustomTopic(topic),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            tooltip: 'Hapus topic',
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Subscribed topics summary
            Card(
              color: Colors.green.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Topics Aktif (${_subscribedTopics.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _subscribedTopics.map((topic) {
                        return Chip(
                          label: Text(
                            topic,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.green.shade100,
                          avatar: const Icon(Icons.notifications_active,
                              size: 16),
                        );
                      }).toList(),
                    ),
                    if (_subscribedTopics.isEmpty)
                      Text(
                        'Belum ada topic yang di-subscribe',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get icon for suggested topic
  IconData _getTopicIcon(String topic) {
    switch (topic) {
      case 'keuangan':
        return Icons.attach_money;
      case 'berita':
        return Icons.newspaper;
      case 'olahraga':
        return Icons.sports_soccer;
      case 'teknologi':
        return Icons.computer;
      case 'kesehatan':
        return Icons.health_and_safety;
      default:
        return Icons.tag;
    }
  }
}
