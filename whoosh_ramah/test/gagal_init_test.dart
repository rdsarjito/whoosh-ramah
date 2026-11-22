// Tier 1 B1 — Firebase gagal init tidak boleh membuat aplikasi buntu.
//
// Layar darurat menjelaskan masalah dengan bahasa manusia, menampilkan pesan
// teknis, dan menyediakan "Coba lagi" yang benar-benar memanggil ulang init.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/screens/gagal_init_screen.dart';
import 'package:whoosh_ramah/theme.dart';

void main() {
  Future<void> buka(
    WidgetTester tester,
    Future<void> Function() onCobaLagi, {
    String pesan = 'firebase_core: jaringan tidak tersedia',
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GagalInitScreen(pesan: pesan, onCobaLagi: onCobaLagi),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan judul, penjelasan, pesan teknis, dan tombol Coba lagi', (tester) async {
    await buka(tester, () async {});

    expect(find.text('Tidak bisa terhubung'), findsOneWidget);
    expect(
      find.text(
        'Whoosh Ramah butuh internet untuk memuat permintaan pendampingan. '
        'Periksa koneksi Anda, lalu coba lagi.',
      ),
      findsOneWidget,
    );
    expect(find.text('firebase_core: jaringan tidak tersedia'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('"Coba lagi" memanggil ulang inisialisasi', (tester) async {
    var panggilan = 0;
    await buka(tester, () async => panggilan++);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(panggilan, 1);
    // Bila init gagal lagi, layar tetap ada dan tombol bisa ditekan ulang.
    expect(find.text('Coba lagi'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(panggilan, 2);
  });

  testWidgets('selama mencoba: spinner, tombol nonaktif, ketukan ganda diabaikan', (tester) async {
    final selesai = Completer<void>();
    var panggilan = 0;
    await buka(tester, () {
      panggilan++;
      return selesai.future;
    });

    await tester.tap(find.text('Coba lagi'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Coba lagi'), findsNothing);

    // Ketukan kedua saat spinner tidak menambah panggilan.
    await tester.tap(find.byType(CircularProgressIndicator), warnIfMissed: false);
    await tester.pump();
    expect(panggilan, 1);

    selesai.complete();
    await tester.pumpAndSettle();
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('AplikasiGagalInit membungkus layar dengan tema aplikasi', (tester) async {
    await tester.pumpWidget(
      AplikasiGagalInit(pesan: 'init gagal', onCobaLagi: () async {}),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GagalInitScreen), findsOneWidget);
    expect(find.text('Tidak bisa terhubung'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.textTheme.bodyMedium?.fontFamily, 'Plus Jakarta Sans');
  });
}