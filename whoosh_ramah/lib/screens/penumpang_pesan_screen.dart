import 'package:material_ui/material_ui.dart';

import '../data/dummy.dart';
import '../models/permintaan.dart';
import '../services/permintaan_service.dart';
import '../theme.dart';
import '../widgets/hero_back_button.dart';
import '../widgets/hero_header.dart';
import 'penumpang_status_screen.dart';

/// Layar 2 — Pesan pendamping (design/Penumpang-Pesan.dc.html).
///
/// Penumpang memilih 1 dari 6 [JenisBantuan], 1 dari 3 titik jemput
/// ([DummyData.titikJemput]), dan boleh menambah catatan. Tombol "Kirim
/// permintaan" aktif setelah jenis bantuan & titik jemput dipilih; saat ditekan
/// layar menampilkan loading, memanggil [PermintaanService.buatPermintaan], lalu
/// `pushReplacement` ke layar status. Bila gagal, muncul SnackBar agar pengguna
/// bisa mencoba lagi.
class PenumpangPesanScreen extends StatefulWidget {
  const PenumpangPesanScreen({super.key, this.service});

  /// Opsional: injeksi service (memudahkan pengujian). Default dibuat malas
  /// saat kirim, sehingga membangun layar ini tidak menyentuh Firestore.
  final PermintaanService? service;

  @override
  State<PenumpangPesanScreen> createState() => _PenumpangPesanScreenState();
}

class _PenumpangPesanScreenState extends State<PenumpangPesanScreen> {
  final TextEditingController _catatan = TextEditingController();

  JenisBantuan? _jenis;
  String? _jemput;
  bool _loading = false;

  PermintaanService? _lazy;
  PermintaanService get _svc => widget.service ?? (_lazy ??= PermintaanService());

  // Ikon Material untuk tiap jenis bantuan (ikon garis pada design didekati
  // dengan ikon Material sesuai kesepakatan Langkah 3).
  static const Map<JenisBantuan, IconData> _ikonBantuan = <JenisBantuan, IconData>{
    JenisBantuan.kursiRoda: Icons.accessible,
    JenisBantuan.tunanetra: Icons.blind,
    JenisBantuan.tuli: Icons.hearing_disabled,
    JenisBantuan.lansia: Icons.elderly,
    JenisBantuan.hamil: Icons.pregnant_woman,
    JenisBantuan.porter: Icons.luggage,
  };

  static const Map<String, IconData> _ikonJemput = <String, IconData>{
    'Lobi utama': Icons.meeting_room,
    'Area parkir': Icons.local_parking,
    'Kereta pengumpan': Icons.train,
  };

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    final jenis = _jenis;
    final jemput = _jemput;
    if (jenis == null || jemput == null || _loading) return;

    setState(() => _loading = true);
    try {
      final catatan = _catatan.text.trim();
      final id = await _svc.buatPermintaan(
        jenisBantuan: jenis,
        titikJemput: jemput,
        catatan: catatan.isEmpty ? null : catatan,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PenumpangStatusScreen(idPermintaan: id)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengirim permintaan. Silakan coba lagi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = DummyData.tiket;
    final ringkasanTiket =
        '${t.kereta} · ${t.stasiunAsal} ${t.jamBerangkat} · Gerbong ${t.gerbong}, Kursi ${t.kursi}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            HeroHeader(
              color: AppColors.pinkHero,
              borderRadius: 32,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      HeroBackButton(label: 'Kembali ke tiket', onTap: () => Navigator.maybePop(context)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Pesan pendamping',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        ringkasanTiket,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF5A4A50),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Heading('Bantuan apa yang Anda perlukan?'),
                    const SizedBox(height: 10),
                    _gridBantuan(),
                    const SizedBox(height: 16),
                    const _Heading('Di mana kami menjemput Anda?'),
                    const SizedBox(height: 10),
                    _gridJemput(),
                    const SizedBox(height: 16),
                    const _Heading('Catatan untuk petugas (opsional)'),
                    const SizedBox(height: 8),
                    _catatanField(),
                  ],
                ),
              ),
            ),
            _submit(),
          ],
        ),
      ),
    );
  }

  /// Grid 3 kolom jenis bantuan; kotak dipilih satu per satu.
  Widget _gridBantuan() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final w = (constraints.maxWidth - 2 * spacing) / 3;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final jenis in JenisBantuan.values)
              SizedBox(
                width: w,
                child: _ChoiceBox(
                  label: jenis.label,
                  icon: _ikonBantuan[jenis] ?? Icons.accessibility,
                  selected: _jenis == jenis,
                  onTap: () => setState(() => _jenis = jenis),
                  minHeight: 104,
                  radius: 22,
                  iconSize: 24,
                  labelSize: 15,
                  gap: 8,
                  badgeSize: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Grid 3 kolom titik jemput.
  Widget _gridJemput() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final w = (constraints.maxWidth - 2 * spacing) / 3;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final titik in DummyData.titikJemput)
              SizedBox(
                width: w,
                child: _ChoiceBox(
                  label: titik,
                  icon: _ikonJemput[titik] ?? Icons.place,
                  selected: _jemput == titik,
                  onTap: () => setState(() => _jemput = titik),
                  minHeight: 92,
                  radius: 20,
                  iconSize: 26,
                  labelSize: 14,
                  gap: 6,
                  showBadge: false,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _catatanField() {
    return TextField(
      controller: _catatan,
      minLines: 2,
      maxLines: 4,
      enabled: !_loading,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Contoh: saya membawa satu koper besar',
        hintStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7080)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: _border(AppColors.outlineSoft),
        enabledBorder: _border(AppColors.outlineSoft),
        focusedBorder: _border(AppColors.redPrimary),
        disabledBorder: _border(AppColors.outlineSoft),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.choice),
        borderSide: BorderSide(color: color, width: 2),
      );

  Widget _submit() {
    final canSubmit = _jenis != null && _jemput != null;
    final active = canSubmit && !_loading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      child: Semantics(
        button: true,
        enabled: active,
        label: 'Kirim permintaan',
        onTap: active ? _kirim : null,
        child: GestureDetector(
          key: const Key('tombol_kirim'),
          onTap: active ? _kirim : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: canSubmit ? AppColors.redPrimary : AppColors.redPrimary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(32),
              boxShadow: canSubmit && !_loading
                  ? const [BoxShadow(color: Color(0x47E11D2E), blurRadius: 22, offset: Offset(0, 10))]
                  : null,
            ),
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Kirim permintaan',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward, size: 22, color: Colors.white),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Judul bagian (18px, tebal 900).
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
      ),
    );
  }
}

/// Kotak pilihan (jenis bantuan / titik jemput).
///
/// Terpilih: latar merah muda + garis merah 2px + badge centang, sehingga tidak
/// hanya mengandalkan warna (bagian 8). [Semantics] menandai `selected` dan
/// memberi label jelas untuk TalkBack.
class _ChoiceBox extends StatelessWidget {
  const _ChoiceBox({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.minHeight,
    required this.radius,
    required this.iconSize,
    required this.labelSize,
    required this.gap,
    required this.padding,
    this.showBadge = true,
    this.badgeSize = 44,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final double minHeight;
  final double radius;
  final double iconSize;
  final double labelSize;
  final double gap;
  final EdgeInsetsGeometry padding;
  final bool showBadge;
  final double badgeSize;

  static const Color _ikonNonAktif = Color(0xFF4A5060);

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppColors.redPrimary : AppColors.outlineSoft;
    final bg = selected ? AppColors.pinkHero : Colors.white;

    Widget ikon;
    if (showBadge) {
      ikon = Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          color: selected ? AppColors.redPrimary : AppColors.innerGray,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: iconSize, color: selected ? Colors.white : _ikonNonAktif),
      );
    } else {
      ikon = Icon(icon, size: iconSize, color: selected ? AppColors.redPrimary : _ikonNonAktif);
    }

    final visual = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ikon,
            SizedBox(height: gap),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                height: 1.2,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: selected
            ? Stack(
                children: [
                  visual,
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.redPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              )
            : visual,
      ),
    );
  }
}
