/// Tier 3 E5 — golden test layar utama.
///
/// Merekam hasil render piksel-per-piksel supaya perubahan desain yang tidak
/// disengaja (warna, jarak, font, kontras) terlihat sebagai diff gambar.
///
/// Menjalankan/memperbarui golden (lakukan di macOS, lihat README):
///   flutter test --tags golden --update-goldens
/// Memeriksa saja:
///   flutter test --tags golden
///
/// Semua tes di file ini bertanda `golden` agar CI Linux bisa melewatinya
/// (`--exclude-tags golden`) — perenderan font fallback berbeda antar OS.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/models/permintaan.dart';
import 'package:whoosh_ramah/screens/penumpang_status_screen.dart';
import 'package:whoosh_ramah/screens/penumpang_tiket_screen.dart';
import 'package:whoosh_ramah/screens/pilih_peran_screen.dart';
import 'package:whoosh_ramah/services/permintaan_service.dart';
import 'package:whoosh_ramah/theme.dart';

DateTime _jam(int jam, int menit) => DateTime(2026, 11, 22, jam, menit);

/// Satu dokumen tetap dengan jam riwayat tetap (tidak ada `DateTime.now()`),
/// supaya gambar golden tidak berubah tiap kali tes dijalankan.
class _TetapService extends PermintaanService {
  _TetapService(this._doc);

  final Permintaan? _doc;

  @override
  Stream<Permintaan?> streamPermintaan(String id) =>
      Stream<Permintaan?>.value(_doc);

  @override
  Stream<Permintaan?> streamTerbaruPenumpang(String idPenumpang) =>
      Stream<Permintaan?>.value(_doc);
}

Permintaan _statusBertemu() => Permintaan(
      id: 'golden-status',
      jenisBantuan: JenisBantuan.kursiRoda,
      titikJemput: 'Lobi utama',
      status: StatusPermintaan.bertemu,
      sumber: 'aplikasi',
      namaPenumpang: 'Siti Aminah',
      idPenumpang: 'demo-siti',
      petugas: 'Rina',
      kereta: 'G1123',
      jamBerangkat: '08.10',
      stasiunAsal: 'Halim',
      stasiunTujuan: 'Tegalluar',
      gerbong: '5',
      kursi: '7A',
      catatan: 'membawa satu koper besar',
      riwayat: <RiwayatStatus>[
        RiwayatStatus(status: 'menunggu', waktu: _jam(7, 30)),
        RiwayatStatus(status: 'ditugaskan', waktu: _jam(7, 33)),
        RiwayatStatus(status: 'bertemu', waktu: _jam(7, 42)),
      ],
      dibuatPada: _jam(7, 30),
      diperbaruiPada: _jam(7, 42),
      tibaPada: _jam(7, 40),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Font Plus Jakarta Sans dibundel: tanpa ini teks dirender dengan Ahem
    // (kotak-kotak).
    final loader = FontLoader('Plus Jakarta Sans');
    for (final berat in const ['Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$berat.ttf'));
    }
    await loader.load();
    // Ikon Material juga harus dimuat manual di tes; tanpa ini semua ikon
    // tampil sebagai kotak kosong dan golden tidak menyerupai aplikasi asli.
    final ikon = FontLoader('MaterialIcons');
    ikon.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await ikon.load();
  });

  /// Render satu layar pada ukuran ponsel tetap, skala teks 1.0, DPR 1.0,
  /// lalu bandingkan dengan berkas golden.
  Future<void> rekam(
    WidgetTester tester,
    Widget layar,
    String nama,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, debugShowCheckedModeBanner: false, home: layar),
    );
    // Dekode PNG logo terjadi di async sungguhan, bukan fake async zone tes;
    // tanpa precacheImage di runAsync, ubin logo tampil kosong di golden.
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/logo/logo_kereta_512.png'),
        tester.element(find.byType(MaterialApp)),
      );
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$nama.png'),
    );
  }

  testWidgets('golden: layar pilih peran', (tester) async {
    await rekam(tester, const PilihPeranScreen(), 'pilih_peran');
  }, tags: 'golden');

  testWidgets('golden: layar tiket penumpang', (tester) async {
    await rekam(
      tester,
      PenumpangTiketScreen(service: _TetapService(null)),
      'penumpang_tiket',
    );
  }, tags: 'golden');

  testWidgets('golden: layar status penumpang (bertemu)', (tester) async {
    await rekam(
      tester,
      PenumpangStatusScreen(
        idPermintaan: 'golden-status',
        service: _TetapService(_statusBertemu()),
      ),
      'penumpang_status',
    );
  }, tags: 'golden');
}