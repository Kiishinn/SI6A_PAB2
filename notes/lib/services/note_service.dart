import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';

class NoteService {
  final CollectionReference _notesCollection =
      FirebaseFirestore.instance.collection('notes');

  // Mengambil semua notes sebagai stream (realtime)
  Stream<List<Note>> getNotes() {
    return _notesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList();
    });
  }

  // Menambahkan note baru
  Future<void> addNote(Note note) async {
    await _notesCollection.add(note.toMap());
  }

  // Mengupdate note
  Future<void> updateNote(String id, Note note) async {
    await _notesCollection.doc(id).update(note.toMap());
  }

  // Menghapus note
  Future<void> deleteNote(String id) async {
    await _notesCollection.doc(id).delete();
  }
}
