import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/models/permintaan.dart';
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

DateTime _jam(int h, int m) => DateTime(2026, 11, 22, h, m);

Permintaan _dokumen({StatusPermintaan status = StatusPermintaan.bertemu}) => Permintaan(
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
    // Muat font Nunito yang dibundel agar pengukuran lebar stabil (bukan Ahem).
    final loader = FontLoader('Nunito');
    for (final berat in const ['SemiBold', 'Bold', 'ExtraBold', 'Black']) {
      loader.addFont(rootBundle.load('assets/fonts/Nunito-$berat.ttf'));
    }
    await loader.load();
  });

  final dokumen = _dokumen();

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
  };

  for (final scale in const [1.3, 1.5]) {
    for (final entry in layar.entries) {
      testWidgets('text scale $scale: layar ${entry.key} tanpa overflow', (tester) async {
        await _render(tester, entry.value(), scale: scale);
      });
    }
  }
}
