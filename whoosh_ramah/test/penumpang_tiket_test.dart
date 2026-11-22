import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:whoosh_ramah/main.dart';
import 'package:whoosh_ramah/models/permintaan.dart';
import 'package:whoosh_ramah/screens/penumpang_pesan_screen.dart';
import 'package:whoosh_ramah/screens/penumpang_status_screen.dart';
import 'package:whoosh_ramah/screens/penumpang_tiket_screen.dart';
import 'package:whoosh_ramah/services/permintaan_service.dart';
import 'package:whoosh_ramah/theme.dart';
import 'package:whoosh_ramah/widgets/pill_button.dart';

/// Service palsu untuk tombol sekunder: permintaan terakhir penumpang demo.
/// `streamPermintaan` ikut dipalsukan karena layar status membukanya lagi.
class _FakeTiketService extends PermintaanService {
  _FakeTiketService(this._terbaru, {this.gagal = false, this.stream});

  final Permintaan? _terbaru;
  final bool gagal;
  final Stream<Permintaan?>? stream;

  int pencarian = 0;

  @override
  Stream<Permintaan?> streamTerbaruPenumpang(String idPenumpang) {
    pencarian++;
    final khusus = stream;
    if (khusus != null) return khusus;
    if (gagal) return Stream<Permintaan?>.error(Exception('jaringan putus'));
    return Stream<Permintaan?>.value(_terbaru);
  }

  @override
  Stream<Permintaan?> streamPermintaan(String id) => Stream<Permintaan?>.value(_terbaru);
}

Permintaan _permintaan() => const Permintaan(
      id: 'req-1',
      jenisBantuan: JenisBantuan.kursiRoda,
      titikJemput: 'Lobi utama',
      status: StatusPermintaan.bertemu,
      sumber: 'aplikasi',
      namaPenumpang: 'Siti Aminah',
      petugas: 'Rina',
      gerbong: '5',
      kursi: '7A',
      stasiunTujuan: 'Tegalluar',
    );

void main() {
  Future<void> buka(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const PenumpangTiketScreen()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> bukaDengan(WidgetTester tester, PermintaanService service) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: PenumpangTiketScreen(service: service)),
    );
    await tester.pumpAndSettle();
  }

  /// Habiskan timer SnackBar (4 dtk) agar tidak ada timer menggantung di akhir tes.
  Future<void> habiskanSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  /// Gulir pilihan jadwal ke dalam pandangan dulu: daftar di dalam lembar
  /// bisa lebih tinggi daripada area gulirnya, sementara tombolnya dipaku.
  Future<void> pilihJadwal(WidgetTester tester, String kode) async {
    await tester.ensureVisible(find.text(kode));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kode));
    await tester.pumpAndSettle();
  }

  testWidgets('Layar tiket: kartu tiket, tombol, dan menu bawah tampil', (tester) async {
    // Font lokal terdaftar di tema (bukan google_fonts).
    expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, 'Plus Jakarta Sans');

    await buka(tester);

    expect(find.text('Halo, Bu Siti'), findsOneWidget);
    expect(find.text('Siap berangkat hari ini?'), findsOneWidget);
    expect(find.text('Whoosh G1123'), findsOneWidget);
    expect(find.text('Tiket contoh'), findsOneWidget);

    // Jam & stasiun.
    expect(find.text('08.10'), findsOneWidget);
    expect(find.text('08.56'), findsOneWidget);
    expect(find.text('Halim'), findsOneWidget);
    expect(find.text('Tegalluar'), findsOneWidget);

    // Tiga kotak info sesuai desain (Tanggal / Gerbong / Kursi).
    expect(find.text('Tanggal'), findsOneWidget);
    expect(find.text('Gerbong'), findsOneWidget);
    expect(find.text('Kursi'), findsOneWidget);
    expect(find.text('22 Nov'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('7A'), findsOneWidget);

    // Catatan gratis + dua tombol sekunder desain.
    expect(find.text('Gratis untuk lansia, difabel & ibu hamil'), findsOneWidget);
    expect(find.text('QR tiket'), findsOneWidget);
    expect(find.text('Ubah jadwal'), findsOneWidget);

    // Tombol + menu bawah.
    expect(find.text('Butuh pendampingan'), findsOneWidget);
    expect(find.text('Lihat status pendampingan'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Tiket'), findsOneWidget);
    expect(find.text('Bantuan'), findsOneWidget);
    expect(find.text('Akun'), findsOneWidget);
  });

  testWidgets('Layar tiket: "Butuh pendampingan" membuka layar pesan', (tester) async {
    await buka(tester);

    await tester.tap(find.text('Butuh pendampingan'));
    await tester.pumpAndSettle();

    expect(find.byType(PenumpangPesanScreen), findsOneWidget);
    expect(find.text('Pesan pendamping'), findsOneWidget);
  });

  testWidgets('Layar tiket dapat dibuka dari layar pilih peran', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const WhooshRamahApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Penumpang'));
    await tester.pumpAndSettle();

    expect(find.byType(PenumpangTiketScreen), findsOneWidget);
    expect(find.text('Butuh pendampingan'), findsOneWidget);
  });

  testWidgets('Tier 1 A2: tombol sekunder membuka status pendampingan terakhir', (tester) async {
    final service = _FakeTiketService(_permintaan());
    await bukaDengan(tester, service);

    await tester.tap(find.text('Lihat status pendampingan'));
    await tester.pumpAndSettle();

    expect(service.pencarian, 1);
    expect(find.byType(PenumpangStatusScreen), findsOneWidget);
    expect(find.text('Pendampingan Anda'), findsOneWidget);
    expect(find.text('Petugas menuju Anda'), findsOneWidget);
  });

  testWidgets('Tier 1 A2: belum ada permintaan -> SnackBar, bukan layar kosong', (tester) async {
    await bukaDengan(tester, _FakeTiketService(null));

    await tester.tap(find.text('Lihat status pendampingan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Belum ada permintaan pendampingan. Tekan "Butuh pendampingan" untuk memesan.'),
      findsOneWidget,
    );
    expect(find.byType(PenumpangStatusScreen), findsNothing);
    // Tombol kembali bisa ditekan (tidak terkunci di keadaan memuat).
    expect(find.text('Lihat status pendampingan'), findsOneWidget);
    await habiskanSnackBar(tester);
  });

  testWidgets('Tier 1 A2: jaringan gagal -> SnackBar dan tombol pulih', (tester) async {
    await bukaDengan(tester, _FakeTiketService(null, gagal: true));

    await tester.tap(find.text('Lihat status pendampingan'));
    await tester.pumpAndSettle();

    expect(find.text('Gagal memuat status. Periksa koneksi Anda.'), findsOneWidget);
    expect(find.text('Lihat status pendampingan'), findsOneWidget);
    await habiskanSnackBar(tester);
  });

  testWidgets('Tier 1 A2: saat mencari, tombol nonaktif dan berlabel "Memuat status…"', (tester) async {
    final ctrl = StreamController<Permintaan?>();
    addTearDown(ctrl.close);
    await bukaDengan(tester, _FakeTiketService(null, stream: ctrl.stream));

    await tester.tap(find.text('Lihat status pendampingan'));
    await tester.pump();

    expect(find.text('Memuat status…'), findsOneWidget);
    expect(find.text('Lihat status pendampingan'), findsNothing);
    final tombol = tester.widget<OutlinedButton>(
      find.ancestor(of: find.text('Memuat status…'), matching: find.byType(OutlinedButton)),
    );
    expect(tombol.onPressed, isNull);

    // Ketukan kedua saat memuat tidak memicu pencarian baru.
    await tester.tap(find.text('Memuat status…'), warnIfMissed: false);
    await tester.pump();

    // Habiskan timer timeout 8 dtk -> SnackBar gagal, lalu timer SnackBar.
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('Gagal memuat status. Periksa koneksi Anda.'), findsOneWidget);
    await habiskanSnackBar(tester);
  });

  testWidgets('Tier 2 D1: tombol bundar merah di hero memesan pendamping', (tester) async {
    await buka(tester);

    final handle = tester.ensureSemantics();
    // Label eksplisit untuk pembaca layar, bukan sekadar ikon kursi roda.
    expect(find.bySemanticsLabel('Pesan pendamping'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Pesan pendamping'));
    handle.dispose();
    await tester.pumpAndSettle();

    expect(find.byType(PenumpangPesanScreen), findsOneWidget);
  });

  testWidgets('Tier 2 D1: "QR tiket" menampilkan QR asli dan kode bisa disalin', (tester) async {
    final salinan = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          salinan.add((call.arguments as Map<dynamic, dynamic>)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await buka(tester);
    await tester.tap(find.text('QR tiket'));
    await tester.pumpAndSettle();

    // QR sungguhan (bukan gambar tempelan) + kode yang sama dengan data tiket.
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('WR-G1123-57A'), findsOneWidget);
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.size, 208);
    expect(qr.errorCorrectionLevel, QrErrorCorrectLevel.M);
    // Data QR tidak bisa dibaca dari luar widget, jadi isi kode diverifikasi
    // lewat label semantiknya (dibaca TalkBack) dan lewat pelukis QR asli.
    expect(qr.semanticsLabel, contains('WR-G1123-57A'));
    expect(qr.semanticsLabel, contains('Siti Aminah'));
    expect(qr.semanticsLabel, contains('G1123'));
    expect(
      find.descendant(
        of: find.byType(QrImageView),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is QrPainter,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Salin kode tiket'));
    await tester.pumpAndSettle();

    expect(salinan, <String>['WR-G1123-57A']);
    expect(find.text('Kode WR-G1123-57A disalin.'), findsOneWidget);
    await habiskanSnackBar(tester);
  });

  testWidgets('Tier 2 D1: "Ubah jadwal" memperbarui kartu tiket', (tester) async {
    await buka(tester);
    await tester.tap(find.text('Ubah jadwal'));
    await tester.pumpAndSettle();

    // Jadwal saat ini ditandai, kereta lain tersedia.
    expect(find.text('Saat ini'), findsOneWidget);
    expect(find.text('G1127'), findsOneWidget);
    expect(find.text('G1131'), findsOneWidget);
    expect(find.text('G1135'), findsOneWidget);

    await pilihJadwal(tester, 'G1127');
    await tester.tap(find.text('Simpan jadwal'));
    await tester.pumpAndSettle();

    expect(find.text('Whoosh G1127'), findsOneWidget);
    expect(find.text('09.05'), findsOneWidget);
    expect(find.text('09.51'), findsOneWidget);
    expect(find.text('2C'), findsOneWidget);
    expect(find.text('Whoosh G1123'), findsNothing);
    expect(
      find.text('Jadwal diperbarui: G1127, berangkat 09.05.'),
      findsOneWidget,
    );
    await habiskanSnackBar(tester);
  });

  testWidgets('Tier 2 D1: batal mengubah jadwal membiarkan tiket apa adanya', (tester) async {
    await buka(tester);
    await tester.tap(find.text('Ubah jadwal'));
    await tester.pumpAndSettle();

    await pilihJadwal(tester, 'G1131');
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.text('Whoosh G1123'), findsOneWidget);
    expect(find.text('08.10'), findsOneWidget);
    expect(find.text('Whoosh G1131'), findsNothing);
  });

  testWidgets('Tier 2 D1: tombol simpan nonaktif selama jadwal belum berubah', (tester) async {
    await buka(tester);
    await tester.tap(find.text('Ubah jadwal'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih jadwal lain'), findsOneWidget);
    expect(find.text('Simpan jadwal'), findsNothing);
    final tombol = tester.widget<PillButton>(
      find.ancestor(of: find.text('Pilih jadwal lain'), matching: find.byType(PillButton)),
    );
    expect(tombol.onPressed, isNull);

    // Memilih kereta yang sama tetap tidak mengaktifkan tombol.
    await pilihJadwal(tester, 'G1123');
    expect(find.text('Pilih jadwal lain'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
  });

  testWidgets('Tier 2 D1: tombol lembar dipaku — tetap terlihat setelah daftar digulir', (tester) async {
    await buka(tester);
    await tester.tap(find.text('Ubah jadwal'));
    await tester.pumpAndSettle();

    final simpan = find.text('Pilih jadwal lain');
    final batal = find.text('Batal');
    // Sama dengan ukuran permukaan yang dipasang `buka()`.
    const layar = Size(420, 1600);
    final posisiAwal = tester.getTopLeft(simpan);
    expect(posisiAwal.dy, lessThan(layar.height));
    expect(tester.getBottomLeft(batal).dy, lessThanOrEqualTo(layar.height));

    // Gulir daftar sampai mentok: pilihan terakhir terlihat, tombol tidak bergeser.
    await tester.drag(find.text('G1123'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(simpan), posisiAwal);
    expect(tester.getBottomLeft(batal).dy, lessThanOrEqualTo(layar.height));

    await tester.tap(batal);
    await tester.pumpAndSettle();
    expect(find.text('Whoosh G1123'), findsOneWidget);
  });
}
