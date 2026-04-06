// Import package firebase_database untuk mengakses Firebase Realtime Database
import "package:firebase_database/firebase_database.dart";

// Class ShoppingService berisi method-method untuk mengakses data di Firebase
class GoldService {
  // Membuat referensi ke node 'shopping_list' di Firebase Realtime Database
  // Semua data akan disimpan di bawah node ini
  final DatabaseReference _database = FirebaseDatabase.instance.ref(
    'harga_emas',
  );

  // Method untuk mengambil data daftar belanja secara realtime
  // Mengembalikan Stream yang akan otomatis update saat data berubah
  Stream<DatabaseEvent> getPriceList() {
    // onValue mengembalikan stream yang mendengarkan perubahan data
    return _database.onValue;
  }
}