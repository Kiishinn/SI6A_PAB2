import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../services/note_service.dart';
import '../services/fcm_service.dart';
import '../widgets/note_dialog.dart';
import 'subscribe_screen.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';

class NoteListScreen extends StatelessWidget {
  final NoteService _noteService = NoteService();
  final FcmService _fcmService = FcmService();

  NoteListScreen({super.key});

  // Tampilkan dialog tambah note
  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NoteDialog(),
    );
  }

  // Tampilkan dialog edit note
  void _showEditDialog(BuildContext context, Note note) {
    showDialog(
      context: context,
      builder: (context) => NoteDialog(note: note),
    );
  }

  // Konfirmasi dan hapus note
  void _deleteNote(BuildContext context, Note note) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(dialogL10n.deleteNote),
          content: Text(dialogL10n.deleteConfirm(note.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(dialogL10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                _noteService.deleteNote(note.id!);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.noteDeleted)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(dialogL10n.delete),
            ),
          ],
        );
      },
    );
  }

  // Copy FCM Token to clipboard
  Future<void> _copyFcmToken(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await Clipboard.setData(ClipboardData(text: token));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.fcmTokenCopied),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        debugPrint('FCM Token: $token');
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorOccurred),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorOccurred + ': $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = Localizations.maybeLocaleOf(context)?.languageCode ?? 'id';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.appTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: l10n.language,
            onSelected: (code) => MainApp.setLocale(Locale(code)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'id',
                child: Row(
                  children: [
                    if (currentLocale == 'id')
                      const Icon(Icons.check, size: 18, color: Colors.blue)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(l10n.languageIndonesian),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'en',
                child: Row(
                  children: [
                    if (currentLocale == 'en')
                      const Icon(Icons.check, size: 18, color: Colors.blue)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(l10n.languageEnglish),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscribeScreen(),
                ),
              );
            },
            icon: const Icon(Icons.subscriptions),
            tooltip: l10n.subscribeTooltip,
          ),
          IconButton(
            onPressed: () => _copyFcmToken(context),
            icon: const Icon(Icons.copy),
            tooltip: l10n.copyFcmToken,
          ),
        ],
      ),
      // Floating Action Button untuk tambah note
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Note>>(
        stream: _noteService.getNotes(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    '${l10n.errorOccurred}: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }

          final notes = snapshot.data ?? [];

          // Empty state
          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.note_add, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noNotes,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.addNoteHint,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // List notes
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tampilkan gambar jika ada
                    if (note.imageBase64 != null &&
                        note.imageBase64!.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Image.memory(
                          base64Decode(note.imageBase64!),
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            note.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Description
                          Text(
                            note.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Tanggal upload
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('dd MMM yyyy, HH:mm')
                                    .format(note.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Action buttons (Edit & Delete)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: () =>
                                    _showEditDialog(context, note),
                                icon: const Icon(Icons.edit,
                                    color: Colors.blue),
                                tooltip: l10n.editNote,
                              ),
                              IconButton(
                                onPressed: () =>
                                    _deleteNote(context, note),
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
                                tooltip: l10n.delete,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
