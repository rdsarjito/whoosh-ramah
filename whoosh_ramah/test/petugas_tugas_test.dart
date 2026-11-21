import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/models/permintaan.dart';
import 'package:whoosh_ramah/screens/petugas_tugas_screen.dart';
import 'package:whoosh_ramah/services/permintaan_service.dart';
import 'package:whoosh_ramah/theme.dart';

class _FakeListService extends PermintaanService {
  _FakeListService(this._list);
  final List<Permintaan> _list;

  @override
  Stream<List<Permintaan>> streamSemua() => Stream<List<Permintaan>>.value(_list);
}

class _StreamListService extends PermintaanService {
  _StreamListService(this._stream);
  final Stream<List<Permintaan>> _stream;

  @override
  Stream<List<Permintaan>> streamSemua() => _stream;
}

Permintaan _kamera(String id, {StatusPermintaan status = StatusPermintaan.menunggu}) => Permintaan(
      id: id,
      jenisBantuan: JenisBantuan.kursiRoda,
      titikJemput: 'Stasiun Halim - Pintu Masuk Utara',
      status: status,
      sumber: 'kamera_ai',
      keyakinan: 0.87,
      dibuatPada: DateTime.now(),
      diperbaruiPada: DateTime.now(),
    );

Permintaan _aplikasi(
  String id, {
  StatusPermintaan status = StatusPermintaan.menunggu,
  String nama = 'Siti Aminah',
}) =>
    Permintaan(
      id: id,
      jenisBantuan: JenisBantuan.kursiRoda,
      titikJemput: 'Lobi utama',
      status: status,
      sumber: 'aplikasi',
      namaPenumpang: nama,
      kereta: 'G1123',
      jamBerangkat: '08.10',
      gerbong: '5',
      kursi: '7A',
      stasiunTujuan: 'Tegalluar',
      dibuatPada: DateTime.now(),
      diperbaruiPada: DateTime.now(),
    );

void main() {
  Future<void> buka(WidgetTester tester, PermintaanService service) async {
    await tester.binding.setSurfaceSize(const Size(700, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: PetugasTugasScreen(service: service)),
    );
    // Dua pump: cukup untuk stream statis, tanpa menggantung bila stream
    // belum mengirim data (spinner animasi terus).
    await tester.pump();
    await tester.pump();
  }

  testWidgets('Langkah 6: ringkasan angka + kartu kamera & aplikasi', (tester) async {
    final list = <Permintaan>[
      _kamera('cam1'),
      _aplikasi('app1', status: StatusPermintaan.ditugaskan),
      _aplikasi('app2', nama: 'Budi Hartono'),
    ];
    await buka(tester, _FakeListService(list));

    // Ringkasan: Baru 2, Berjalan 1, Selesai 0. "Baru" juga muncul sebagai
    // badge status pada kartu kamera yang masih menunggu.
    expect(find.text('Baru'), findsNWidgets(2));
    expect(find.text('Berjalan'), findsOneWidget);
    expect(find.text('Selesai hari ini'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    // Badge sumber selalu bertext.
    expect(find.text('Kamera AI'), findsOneWidget);
    expect(find.text('Aplikasi'), findsNWidgets(2));

    // Kartu kamera.
    expect(find.text('Penumpang belum diketahui'), findsOneWidget);
    expect(find.text('Pintu Masuk Utara · keyakinan 87%'), findsOneWidget);

    // Kartu aplikasi.
    expect(find.text('Siti Aminah · Kursi roda'), findsOneWidget);
    // Dua kartu aplikasi memakai detail perjalanan yang sama.
    expect(find.text('Lobi utama · G1123 08.10 · Gerbong 5, Kursi 7A'), findsNWidgets(2));
    expect(find.text('Budi Hartono · Kursi roda'), findsOneWidget);

    // Status badge + waktu relatif.
    expect(find.text('Ditugaskan ke Anda'), findsOneWidget);
    expect(find.text('Menunggu petugas'), findsOneWidget);
    expect(find.text('baru saja'), findsWidgets);
  });

  testWidgets('Langkah 6: tanpa tugas menampilkan pesan kosong', (tester) async {
    await buka(tester, _FakeListService(const <Permintaan>[]));

    expect(find.text('TUGAS MASUK'), findsOneWidget);
    expect(
      find.text('Belum ada tugas aktif. Tugas baru akan muncul di sini secara otomatis.'),
      findsOneWidget,
    );
  });

  testWidgets('Langkah 6: dokumen baru memicu SnackBar tugas baru', (tester) async {
    final ctrl = StreamController<List<Permintaan>>();
    addTearDown(ctrl.close);
    await buka(tester, _StreamListService(ctrl.stream));

    ctrl.add(<Permintaan>[_aplikasi('app1')]);
    await tester.pumpAndSettle();
    expect(find.text('Tugas baru dari Aplikasi'), findsNothing);

    ctrl.add(<Permintaan>[_aplikasi('app1'), _kamera('cam1')]);
    await tester.pumpAndSettle();
    expect(find.text('Tugas baru dari Kamera AI'), findsOneWidget);

    // Habiskan timer sorotan (3 dtk) + SnackBar agar tak ada timer menggantung.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
