import 'package:material_ui/material_ui.dart';

/// Ilustrasi kereta cepat di peron (mengikuti SVG pada design/*.dc.html).
///
/// Dekoratif: diberi label semantik "Ilustrasi kereta cepat di peron" agar
/// pembaca layar (TalkBack/VoiceOver) dapat menyampaikannya (bagian 8).
class TrainIllustration extends StatelessWidget {
  const TrainIllustration({super.key, this.color = const Color(0xFFE11D2E)});

  /// Warna lajur merah pada badan kereta (merah penumpang secara default).
  final Color color;

  static const double _nativeWidth = 346;
  static const double _nativeHeight = 112;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ilustrasi kereta cepat di peron',
      child: AspectRatio(
        aspectRatio: _nativeWidth / _nativeHeight,
        child: CustomPaint(
          painter: _TrainPainter(color),
          size: Size.zero, // ukuran ditentukan AspectRatio
        ),
      ),
    );
  }
}

class _TrainPainter extends CustomPainter {
  _TrainPainter(this.stripeColor);

  final Color stripeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / TrainIllustration._nativeWidth;
    canvas.save();
    canvas.scale(scale, scale);

    final body = Path()
      ..moveTo(0, 34)
      ..lineTo(236, 34)
      ..cubicTo(280, 34, 320, 56, 338, 84)
      ..cubicTo(341, 89, 338, 94, 332, 94)
      ..lineTo(0, 94)
      ..close();

    // Peron (pink) + badan kereta putih.
    _rrect(canvas, 0, 100, 346, 7, 3.5, const Color(0xFFF7B6C0));
    canvas.drawPath(body, Paint()..color = Colors.white);

    // Lajur merah mengikuti bentuk badan (clip-path pada SVG).
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(const Rect.fromLTRB(0, 72, 346, 81), Paint()..color = stripeColor);
    canvas.restore();

    // Jendela (4) + pintu.
    const windowColor = Color(0xFF2B3445);
    for (final x in const [14.0, 58.0, 102.0, 146.0]) {
      _rrect(canvas, x, 46, 34, 16, 6, windowColor);
    }
    _rrect(canvas, 194, 44, 24, 44, 5, const Color(0xFFEEF0F5));

    // Kaca kokot (hidung kereta).
    final nose = Path()
      ..moveTo(240, 44)
      ..cubicTo(266, 46, 292, 58, 308, 70)
      ..lineTo(248, 70)
      ..cubicTo(243, 70, 240, 67, 240, 63)
      ..close();
    canvas.drawPath(nose, Paint()..color = windowColor);

    // Bogie/roda.
    _rrect(canvas, 30, 94, 46, 7, 3.5, const Color(0xFF3A4252));
    _rrect(canvas, 196, 94, 46, 7, 3.5, const Color(0xFF3A4252));

    canvas.restore();
  }

  void _rrect(Canvas canvas, double x, double y, double w, double h, double r, Color color) {
    final rect = Rect.fromLTWH(x, y, w, h);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrainPainter oldDelegate) => oldDelegate.stripeColor != stripeColor;
}
