import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/models/permintaan.dart';
import 'package:whoosh_ramah/screens/keluarga_pantau_screen.dart';
import 'package:whoosh_ramah/services/permintaan_service.dart';
import 'package:whoosh_ramah/theme.dart';

/// Service palsu: hanya `streamTerbaruPenumpang` yang dipakai layar ini.
class _FakeKeluargaService extends PermintaanService {
  _FakeKeluargaService(this._stream);

  final Stream<Permintaan?> _stream;

  @override
  Stream<Permintaan?> streamTerbaruPenumpang(String idPenumpang) => _stream;
}

/// Langganan pertama gagal, berikutnya berhasil — menguji tombol "Coba lagi".
class _GagalLaluPulihService extends PermintaanService {
  _GagalLaluPulihService(this._pulih);

  final Permintaan? _pulih;
  int langganan = 0;

  @override
  Stream<Permintaan?> streamTerbaruPenumpang(String idPenumpang) {
    langganan++;
    if (langganan == 1) return Stream<Permintaan?>.error(Exception('offline'));
    return Stream<Permintaan?>.value(_pulih);
  }
}

DateTime _jam(int h, int m) => DateTime(2026, 11, 22, h, m);

Permintaan _siti({StatusPermintaan status = StatusPermintaan.diKursi}) => Permintaan(
      id: 'abc',
      jenisBantuan: JenisBantuan.kursiRoda,
      titikJemput: 'Lobi utama',
      status: status,
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
      riwayat: [
        RiwayatStatus(status: 'menunggu', waktu: _jam(7, 30)),
        RiwayatStatus(status: 'ditugaskan', waktu: _jam(7, 33)),
        RiwayatStatus(status: 'bertemu', waktu: _jam(7, 42)),
        RiwayatStatus(status: 'di_kursi', waktu: _jam(8, 4)),
      ],
      dibuatPada: _jam(7, 30),
      diperbaruiPada: _jam(8, 4),
    );

void main() {
  Future<void> bukaDengan(WidgetTester tester, PermintaanService service) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: KeluargaPantauScreen(service: service),
      ),
    );
    // Dua pump: cukup untuk stream statis, tanpa menggantung bila stream
    // belum mengirim data (spinner animasi terus).
    await tester.pump();
    await tester.pump();
  }

  Future<void> buka(WidgetTester tester, Stream<Permintaan?> stream) async {
    await bukaDengan(tester, _FakeKeluargaService(stream));
  }

  testWidgets('Langkah 7: kartu status, progres, dan riwayat terbaru di atas', (tester) async {
    await buka(tester, Stream<Permintaan?>.value(_siti()));

    // Hero.
    expect(find.text('Perjalanan Ibu Siti'), findsOneWidget);
    expect(find.text('Dibagikan oleh Siti Aminah · diperbarui otomatis'), findsOneWidget);
    expect(find.text('Ganti peran'), findsOneWidget);

    // Kartu status saat ini (label teks besar + petugas).
    expect(find.text('STATUS SAAT INI · 08.04'), findsOneWidget);
    expect(find.text('Sudah duduk di Gerbong 5, Kursi 7A'), findsOneWidget);
    expect(find.text('Siti Aminah'), findsOneWidget); // nama penumpang di kartu status
    expect(find.text('Didampingi Rina, Petugas Layanan · Stasiun Halim'), findsOneWidget);

    // Progres perjalanan.
    expect(find.text('Halim'), findsOneWidget);
    expect(find.text('Tegalluar'), findsOneWidget);
    expect(find.text('Berangkat 08.10'), findsOneWidget);
    expect(find.text('Tiba ± 08.56'), findsOneWidget);
    expect(find.text('G1123 · Gerbong 5, Kursi 7A'), findsOneWidget);

    // Riwayat berjam, terbaru di atas + baris berikutnya.
    expect(find.text('RIWAYAT'), findsOneWidget);
    expect(find.text('Sudah di kursi 7A'), findsOneWidget);
    expect(find.text('Bertemu petugas'), findsOneWidget);
    expect(find.text('Petugas ditugaskan'), findsOneWidget);
    expect(find.text('Permintaan dibuat'), findsOneWidget);
    expect(find.text('Berikutnya: dijemput di Tegalluar'), findsOneWidget);
    expect(find.text('08.04'), findsOneWidget); // jam di riwayat
    expect(find.text('07.42'), findsOneWidget);
    expect(find.text('07.33'), findsOneWidget);

    final yDiKursi = tester.getTopLeft(find.text('08.04')).dy;
    final yBertemu = tester.getTopLeft(find.text('07.42')).dy;
    final yDitugaskan = tester.getTopLeft(find.text('07.33')).dy;
    expect(yDiKursi, lessThan(yBertemu));
    expect(yBertemu, lessThan(yDitugaskan));

    // Tombol bawah.
    expect(find.text('Hubungi petugas'), findsOneWidget);
    expect(find.text('Anda mendapat notifikasi setiap status berubah'), findsOneWidget);
  });

  testWidgets('Langkah 7: empty state "Siti belum memesan pendampingan"', (tester) async {
    await buka(tester, Stream<Permintaan?>.value(null));

    expect(find.text('Siti belum memesan pendampingan'), findsOneWidget);
    expect(find.text('Perjalanan Ibu Siti'), findsOneWidget);
  });

  testWidgets('Langkah 7: perubahan status diumumkan lewat SemanticsService', (tester) async {
    final diumumkan = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMessageHandler(SystemChannels.accessibility.name, (data) async {
      final decoded = SystemChannels.accessibility.codec.decodeMessage(data);
      if (decoded is Map && decoded['type'] == 'announce') {
        final isi = decoded['data'] as Map;
        diumumkan.add(isi['message'] as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMessageHandler(SystemChannels.accessibility.name, null),
    );

    final ctrl = StreamController<Permintaan?>();
    addTearDown(ctrl.close);
    await buka(tester, ctrl.stream);

    // Data awal: tidak diumumkan.
    ctrl.add(_siti(status: StatusPermintaan.bertemu));
    await tester.pumpAndSettle();
    expect(diumumkan, isEmpty);

    // Status berubah -> diumumkan (dijadwalkan setelah frame).
    ctrl.add(_siti());
    await tester.pumpAndSettle();
    expect(
      diumumkan,
      contains('Status: Penumpang sudah duduk di kursi.'),
    );

    expect(find.text('Sudah duduk di Gerbong 5, Kursi 7A'), findsOneWidget);
  });

  testWidgets('Tier 1 B2: gagal memuat -> "Coba lagi" berlangganan ulang lalu pulih', (tester) async {
    final service = _GagalLaluPulihService(_siti());
    await bukaDengan(tester, service);

    expect(find.text('Gagal memuat pantauan. Periksa koneksi Anda.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(service.langganan, 1);

    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    await tester.pump();

    expect(service.langganan, 2);
    expect(find.text('Gagal memuat pantauan. Periksa koneksi Anda.'), findsNothing);
    expect(find.text('Sudah duduk di Gerbong 5, Kursi 7A'), findsOneWidget);
  });
}
