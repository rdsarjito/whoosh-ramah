import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';

import 'firebase_options.dart';
import 'screens/gagal_init_screen.dart';
import 'screens/pilih_peran_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _jalankan();
}

/// Menginisialisasi Firebase lalu membuka aplikasi. Bila gagal (mis. internet
/// putus saat demo), tampilkan layar "Coba lagi" alih-alih membiarkan exception
/// tak tertangani membuat aplikasi tidak terbuka.
Future<void> _jalankan() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    runApp(const WhooshRamahApp());
  } catch (e) {
    runApp(AplikasiGagalInit(pesan: '$e', onCobaLagi: _jalankan));
  }
}

/// Widget akar aplikasi Whoosh Ramah.
///
/// Langkah 3: menyiapkan Firebase & tema, lalu membuka layar pilih peran
/// (layar 0). Alur penumpang/petugas/keluarga diisi pada langkah berikutnya.
class WhooshRamahApp extends StatelessWidget {
  const WhooshRamahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whoosh Ramah',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: const PilihPeranScreen(),
    );
  }
}
