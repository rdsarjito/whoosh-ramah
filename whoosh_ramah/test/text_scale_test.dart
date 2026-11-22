import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/models/permintaan.dart';
import 'package:whoosh_ramah/screens/gagal_init_screen.dart';
import 'package:whoosh_ramah/screens/keluarga_pantau_screen.dart';
import 'package:whoosh_ramah/screens/penumpang_pesan_screen.dart';
import 'package:whoosh_ramah/screens/penumpang_status_screen.dart';
import 'package:whoosh_ramah/screens/penumpang_tiket_screen.dart';
import 'package:whoosh_ramah/screens/petugas_detail_screen.dart';
import 'package:whoosh_ramah/screens/petugas_tugas_screen.dart';
import 'package:whoosh_ramah/screens/pilih_peran_screen.dart';
import 'package:whoosh_ramah/services/permintaan_service.dart';
import 'package:whoosh_ramah/theme.dart';

class _SatuDokumenService extends PermintaanService {
  _SatuDokumenService(this._doc);

  final Permintaan? _doc;

  @override
  Stream<Permintaan?> streamPermintaan(String id) => Stream<Permintaan?>.value(_doc);

  @override
  Stream<Permintaan?> streamTerbaruPenumpang(String idPenumpang) =>
      Stream<Permintaan?>.value(_doc);
}

class _DaftarService extends PermintaanService {
  _DaftarService(this._list);

  final List<Permintaan> _list;

  @override
  Stream<List<Permintaan>> streamSemua() => Stream<List<Permintaan>>.value(_list);
}

/// Selalu gagal: menguji state error + tombol "Coba lagi" pada teks besar.
class _GagalService extends PermintaanService {
  @override
  Stream<Permintaan?> streamPermintaan(String id) =>
      Stream<Permintaan?>.error(Exception('offline'));

  @override
  Stream<Permintaan?> streamTerbaruPenumpang(String idPenumpang) =>
      Stream<Permintaan?>.error(Exception('offline'));

  @override
  Stream<List<Permintaan>> streamSemua() =>
      Stream<List<Permintaan>>.error(Exception('offline'));
}

/// Tidak pernah mengirim data: menguji kerangka skeleton (Tier 2 D4) pada
/// teks besar. Future yang tidak selesai dipakai agar tidak ada controller
/// yang perlu ditutup di akhir tes.
class _MemuatService extends PermintaanService {
  @override
  Stream<Permintaan?> streamPermintaan(String id) =>
      Stream<Permintaan?>.fromFuture(Completer<Permintaan?>().future);

  @override
  Stream<Permintaan?> streamTerbaruPenumpang(String idPenumpang) =>
      Stream<Permintaan?>.fromFuture(Completer<Permintaan?>().future);

  @override
  Stream<List<Permintaan>> streamSemua() =>
      Stream<List<Permintaan>>.fromFuture(Completer<List<Permintaan>>().future);
}

DateTime _jam(int h, int m) => DateTime(2026, 11, 22, h, m);

Permintaan _dokumen({
  StatusPermintaan status = StatusPermintaan.bertemu,
  DateTime? tibaPada,
}) =>
    Permintaan(
      id: 'x',
      jenisBantuan: JenisBantuan.kursiRoda,
      titikJemput: 'Stasiun Halim - Pintu Masuk Utara',
      status: status,
      sumber: 'kamera_ai',
      keyakinan: 0.87,
      namaPenumpang: 'Siti Aminah',
      idPenumpang: 'demo-siti',
      petugas: 'Rina',
      kereta: 'G1123',
      jamBerangkat: '08.10',
      stasiunAsal: 'Halim',
      stasiunTujuan: 'Tegalluar',
      gerbong: '5',
      kursi: '7A',
      catatan: 'Tolong bawa kursi roda lipat dan temani sampai gerbong.',
      riwayat: [
        RiwayatStatus(status: 'menunggu', waktu: _jam(7, 30)),
        RiwayatStatus(status: 'ditugaskan', waktu: _jam(7, 33)),
        RiwayatStatus(status: 'bertemu', waktu: _jam(7, 42)),
      ],
      dibuatPada: _jam(7, 30),
      diperbaruiPada: _jam(7, 42),
      tibaPada: tibaPada,
    );

/// Render [home] pada ukuran HP dengan textScaler tertentu dan pastikan tidak
/// ada overflow (RenderFlex dsb) yang dilaporkan framework.
Future<void> _render(
  WidgetTester tester,
  Widget home, {
  double scale = 1.3,
  Size size = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pump();
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Muat font Plus Jakarta Sans yang dibundel agar pengukuran lebar stabil
    // (bukan Ahem).
    final loader = FontLoader('Plus Jakarta Sans');
    for (final berat in const ['Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$berat.ttf'));
    }
    await loader.load();
  });

  final dokumen = _dokumen();
  final sudahTiba = _dokumen(tibaPada: _jam(7, 50));

  final layar = <String, Widget Function()>{
    'pilih peran': () => const PilihPeranScreen(),
    'tiket': () => const PenumpangTiketScreen(),
    'pesan pendamping': () => const PenumpangPesanScreen(),
    'status penumpang': () => PenumpangStatusScreen(
          idPermintaan: 'x',
          service: _SatuDokumenService(dokumen),
        ),
    'daftar tugas petugas': () => PetugasTugasScreen(
          service: _DaftarService([dokumen, _dokumen(status: StatusPermintaan.menunggu)]),
        ),
    'detail tugas petugas': () => PetugasDetailScreen(
          idPermintaan: 'x',
          service: _SatuDokumenService(dokumen),
        ),
    'pantau keluarga': () => KeluargaPantauScreen(service: _SatuDokumenService(dokumen)),
    // Tier 1: layar darurat gagal-init.
    'gagal init': () => GagalInitScreen(
          pesan: 'firebase_core: jaringan tidak tersedia',
          onCobaLagi: () async {},
        ),
    // Tier 1 A1: kabar tiba di layar penumpang & petugas.
    'status penumpang (sudah tiba)': () => PenumpangStatusScreen(
          idPermintaan: 'x',
          service: _SatuDokumenService(sudahTiba),
        ),
    'detail tugas petugas (sudah tiba)': () => PetugasDetailScreen(
          idPermintaan: 'x',
          service: _SatuDokumenService(sudahTiba),
        ),
    // Tier 1 B2: state error + tombol "Coba lagi".
    'status penumpang (gagal)': () => PenumpangStatusScreen(
          idPermintaan: 'x',
          service: _GagalService(),
        ),
    'daftar tugas petugas (gagal)': () => PetugasTugasScreen(service: _GagalService()),
    'detail tugas petugas (gagal)': () => PetugasDetailScreen(
          idPermintaan: 'x',
          service: _GagalService(),
        ),
    'pantau keluarga (gagal)': () => KeluargaPantauScreen(service: _GagalService()),
    // Tier 2 D4: kerangka skeleton saat data pertama belum tiba.
    'status penumpang (memuat)': () => PenumpangStatusScreen(
          idPermintaan: 'x',
          service: _MemuatService(),
        ),
    'daftar tugas petugas (memuat)': () => PetugasTugasScreen(service: _MemuatService()),
    'detail tugas petugas (memuat)': () => PetugasDetailScreen(
          idPermintaan: 'x',
          service: _MemuatService(),
        ),
    'pantau keluarga (memuat)': () => KeluargaPantauScreen(service: _MemuatService()),
  };

  for (final scale in const [1.3, 1.5]) {
    for (final entry in layar.entries) {
      testWidgets('text scale $scale: layar ${entry.key} tanpa overflow', (tester) async {
        await _render(tester, entry.value(), scale: scale);
      });
    }
  }

  // Tier 2 D1: dua lembar bawah tiket. Tombolnya dipaku di dasar lembar, jadi
  // pada teks besar ia harus tetap di dalam layar — bukan ikut tergulir.
  for (final scale in const [1.3, 1.5]) {
    for (final lembar in const <String, String>{
      'QR tiket': 'Tutup',
      'Ubah jadwal': 'Batal',
    }.entries) {
      testWidgets('text scale $scale: lembar ${lembar.key} tanpa overflow', (tester) async {
        const ukuran = Size(390, 844);
        await tester.binding.setSurfaceSize(ukuran);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const PenumpangTiketScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text(lembar.key));
        await tester.pumpAndSettle();
        await tester.tap(find.text(lembar.key));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Judul lembar terlihat, tombol utama tidak terdorong keluar layar.
        expect(find.text(lembar.key), findsWidgets);
        final bawah = tester.getBottomLeft(find.text(lembar.value)).dy;
        expect(bawah, lessThanOrEqualTo(ukuran.height));
        expect(bawah, greaterThan(0));
      });
    }
  }
}
