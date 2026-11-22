/// Tier 2 D5 — transisi layar yang dirancang, dan penghormatan pada preferensi
/// "kurangi animasi" sistem (WCAG 2.3.3 / accessibility).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whoosh_ramah/theme.dart';
import 'package:whoosh_ramah/transisi.dart';

class _HalamanSatu extends StatelessWidget {
  const _HalamanSatu();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            TransisiHalaman.masuk<void>(halaman: const _HalamanDua(), nama: 'dua'),
          ),
          child: const Text('buka'),
        ),
      ),
    );
  }
}

class _HalamanDua extends StatelessWidget {
  const _HalamanDua();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('halaman dua')));
}

/// Bungkus seluruh aplikasi (termasuk rute yang di-push) dengan preferensi
/// animasi sistem tertentu. Lewat `builder`, bukan `home`, agar MediaQuery
/// menaungi Navigator — rute baru adalah saudara rute pertama, bukan anaknya.
Widget _aplikasi(Widget home, {required bool kurangiAnimasi}) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: kurangiAnimasi),
      child: child!,
    ),
    home: home,
  );
}

void main() {
  test('rute memakai durasi maju 300ms dan kembali 240ms', () {
    final rute = TransisiHalaman.masuk<void>(halaman: const SizedBox(), nama: 'tes')
        as PageRouteBuilder<void>;
    expect(rute.transitionDuration, const Duration(milliseconds: 300));
    expect(rute.reverseTransitionDuration, const Duration(milliseconds: 240));
    expect(rute.settings.name, 'tes');
    expect(rute.opaque, isTrue);
  });

  testWidgets('durasiGerak: normal 320ms, nol saat animasi dimatikan', (tester) async {
    late Duration normal;
    late Duration hemat;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            normal = durasiGerak(context);
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Builder(
                builder: (dalam) {
                  hemat = durasiGerak(dalam);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(normal, const Duration(milliseconds: 320));
    expect(hemat, Duration.zero);
  });

  testWidgets('halaman baru masuk dengan fade + slide + scale, lalu tenang', (tester) async {
    await tester.pumpWidget(_aplikasi(const _HalamanSatu(), kurangiAnimasi: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('buka'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // Di tengah transisi: belum penuh, sudah bergerak naik.
    final geser = tester.widget<SlideTransition>(
      find.ancestor(of: find.byType(_HalamanDua), matching: find.byType(SlideTransition)),
    );
    final pudar = tester.widget<FadeTransition>(
      find.ancestor(of: find.byType(_HalamanDua), matching: find.byType(FadeTransition)),
    );
    final skala = tester.widget<ScaleTransition>(
      find.ancestor(of: find.byType(_HalamanDua), matching: find.byType(ScaleTransition)),
    );
    expect(geser.position.value.dy, greaterThan(0));
    expect(geser.position.value.dy, lessThan(0.035));
    expect(pudar.opacity.value, greaterThan(0));
    expect(pudar.opacity.value, lessThan(1));
    expect(skala.scale.value, greaterThan(0.985));
    expect(skala.scale.value, lessThan(1));

    await tester.pumpAndSettle();
    expect(find.text('halaman dua'), findsOneWidget);
    expect(
      tester
          .widget<SlideTransition>(
            find.ancestor(of: find.byType(_HalamanDua), matching: find.byType(SlideTransition)),
          )
          .position
          .value,
      Offset.zero,
    );
    expect(
      tester
          .widget<FadeTransition>(
            find.ancestor(of: find.byType(_HalamanDua), matching: find.byType(FadeTransition)),
          )
          .opacity
          .value,
      1,
    );
  });

  testWidgets('animasi dimatikan: halaman langsung tampil tanpa slide/scale', (tester) async {
    await tester.pumpWidget(_aplikasi(const _HalamanSatu(), kurangiAnimasi: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('buka'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('halaman dua'), findsOneWidget);
    expect(
      find.ancestor(of: find.byType(_HalamanDua), matching: find.byType(SlideTransition)),
      findsNothing,
    );
    expect(
      find.ancestor(of: find.byType(_HalamanDua), matching: find.byType(ScaleTransition)),
      findsNothing,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('kembali memakai rute yang sama dan bisa di-pop', (tester) async {
    await tester.pumpWidget(_aplikasi(const _HalamanSatu(), kurangiAnimasi: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('halaman dua'), findsOneWidget);

    Navigator.of(tester.element(find.text('halaman dua'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // Transisi balik lebih cepat (240ms) daripada transisi masuk (300ms).
    expect(find.text('halaman dua'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('halaman dua'), findsNothing);
    expect(find.text('buka'), findsOneWidget);
  });
}