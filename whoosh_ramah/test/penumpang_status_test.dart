import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/models/permintaan.dart';
import 'package:whoosh_ramah/screens/penumpang_status_screen.dart';
import 'package:whoosh_ramah/services/permintaan_service.dart';
import 'package:whoosh_ramah/theme.dart';

/// Service palsu: hanya `streamPermintaan` yang dipakai layar status, jadi
/// konstruktor super tidak menyentuh Firestore (init `_db` bersifat malas).
class _FakeService extends PermintaanService {
  _FakeService(this._data);

  final Permintaan? _data;

  @override
  Stream<Permintaan?> streamPermintaan(String id) => Stream<Permintaan?>.value(_data);
}

/// Service yang stream-nya tidak pernah emit, untuk menguji state loading.
class _LoadingService extends PermintaanService {
  final StreamController<Permintaan?> _controller = StreamController<Permintaan?>();

  @override
  Stream<Permintaan?> streamPermintaan(String id) => _controller.stream;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> buka(WidgetTester tester, Permintaan? data) async {
    await tester.binding.setSurfaceSize(const Size(420, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PenumpangStatusScreen(idPermintaan: 'x', service: _FakeService(data)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Langkah 5: state loading saat data belum tiba', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PenumpangStatusScreen(idPermintaan: 'x', service: _LoadingService()),
      ),
    );
    await tester.pump(); // satu frame; jangan settle (spinner beranimasi terus)

    expect(find.text('Pendampingan Anda'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Langkah 5: status bertemu -> kartu petugas, timeline aktif, tombol bawah', (tester) async {
    const p = Permintaan(
      id: 'abc',
      jenisBantuan: JenisBantuan.kursiRoda,
      titikJemput: 'Lobi utama',
      status: StatusPermintaan.bertemu,
      sumber: 'aplikasi',
      petugas: 'Rina',
      gerbong: '5',
      kursi: '7A',
      stasiunTujuan: 'Tegalluar',
      riwayat: [
        RiwayatStatus(status: 'menunggu'),
        RiwayatStatus(status: 'ditugaskan'),
        RiwayatStatus(status: 'bertemu'),
      ],
    );
    await buka(tester, p);

    // Judul + pill status (contoh pesan yang juga diumumkan ke TalkBack).
    expect(find.text('Pendampingan Anda'), findsOneWidget);
    expect(find.text('Petugas menuju Anda'), findsOneWidget);

    // Kartu petugas muncul setelah status >= ditugaskan.
    expect(find.text('Rina'), findsOneWidget);
    expect(find.text('Petugas Layanan · Stasiun Halim'), findsOneWidget);
    expect(find.text('Lobi utama'), findsOneWidget);

    // Langkah aktif disorot + "· sekarang"; langkah terakhir dinamis.
    expect(find.text('Bertemu petugas · sekarang'), findsOneWidget);
    expect(find.text('Dijemput petugas di Tegalluar'), findsOneWidget);

    // Tombol bawah.
    expect(find.text('Saya sudah sampai di lobi'), findsOneWidget);
    expect(find.text('Bagikan ke keluarga'), findsOneWidget);
  });

  testWidgets('Langkah 5: status menunggu -> "Mencari petugas…", tanpa kartu petugas', (tester) async {
    const p = Permintaan(
      id: 'def',
      jenisBantuan: JenisBantuan.kursiRoda,
      titikJemput: 'Lobi utama',
      status: StatusPermintaan.menunggu,
      sumber: 'aplikasi',
    );
    await buka(tester, p);

    // "Mencari petugas…" muncul di pill hero dan di kartu (pengganti kartu petugas).
    expect(find.text('Mencari petugas…'), findsWidgets);
    expect(find.text('Rina'), findsNothing);
    // Langkah pertama aktif.
    expect(find.text('Permintaan diterima · sekarang'), findsOneWidget);
  });

  testWidgets('Langkah 5: dokumen tidak ditemukan ditangani rapi', (tester) async {
    await buka(tester, null);
    expect(find.text('Permintaan tidak ditemukan.'), findsOneWidget);
  });
}
