import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hidden developer screen (admin-only) for publishing new profile backgrounds
/// to the live catalog without an app update. Uploads media to the
/// `profile-backgrounds` Storage bucket and inserts a row into
/// `profile_backgrounds`. Writes are gated by RLS (`is_admin()`), so this
/// screen is only useful to admin accounts.
class DevStudioScreen extends ConsumerStatefulWidget {
  const DevStudioScreen({super.key});

  @override
  ConsumerState<DevStudioScreen> createState() => _DevStudioScreenState();
}

class _DevStudioScreenState extends ConsumerState<DevStudioScreen> {
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _sortCtrl = TextEditingController(text: '0');
  final _styleCtrl = TextEditingController(
    text: '{"gradient_colors":["#0D2A42","#071520"],'
        '"gradient_begin":"topLeft","gradient_end":"bottomRight"}',
  );

  BackgroundKind _kind = BackgroundKind.gradient;
  CosmeticRarity _rarity = CosmeticRarity.common;
  bool _published = true;

  PlatformFile? _mainFile;
  PlatformFile? _thumbFile;
  bool _publishing = false;
  bool _slugEdited = false;

  static const _bucket = 'profile-backgrounds';

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_syncSlug);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_syncSlug);
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _priceCtrl.dispose();
    _sortCtrl.dispose();
    _styleCtrl.dispose();
    super.dispose();
  }

  void _syncSlug() {
    if (_slugEdited) return;
    final slug = _nameCtrl.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    _slugCtrl.text = slug;
  }

  bool get _needsFile => _kind != BackgroundKind.gradient;
  bool get _needsThumb =>
      _kind == BackgroundKind.animatedWebp || _kind == BackgroundKind.lottie;

  Future<void> _pickMain() async {
    final type = _kind == BackgroundKind.lottie
        ? FileType.custom
        : FileType.image;
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: type,
      allowedExtensions: _kind == BackgroundKind.lottie ? ['json'] : null,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() => _mainFile = res.files.first);
  }

  Future<void> _pickThumb() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() => _thumbFile = res.files.first);
  }

  String _kindDb(BackgroundKind k) => switch (k) {
        BackgroundKind.gradient => 'gradient',
        BackgroundKind.image => 'image',
        BackgroundKind.animatedWebp => 'animated_webp',
        BackgroundKind.lottie => 'lottie',
      };

  String _rarityDb(CosmeticRarity r) => switch (r) {
        CosmeticRarity.common => 'common',
        CosmeticRarity.rare => 'rare',
        CosmeticRarity.epic => 'epic',
        CosmeticRarity.legendary => 'legendary',
      };

  String _contentType(String ext) => switch (ext.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'json' => 'application/json',
        _ => 'image/jpeg',
      };

  String? _validate() {
    if (_nameCtrl.text.trim().isEmpty) return 'Укажите название';
    if (_slugCtrl.text.trim().isEmpty) return 'Укажите slug';
    if (int.tryParse(_priceCtrl.text.trim()) == null) {
      return 'Цена DP должна быть числом';
    }
    if (int.tryParse(_sortCtrl.text.trim()) == null) {
      return 'Порядок должен быть числом';
    }
    if (_kind == BackgroundKind.gradient) {
      try {
        jsonDecode(_styleCtrl.text);
      } catch (_) {
        return 'style_config — некорректный JSON';
      }
    } else if (_mainFile?.bytes == null) {
      return 'Выберите файл фона';
    }
    if (_needsThumb && _thumbFile?.bytes == null) {
      return 'Для анимированного фона нужна статичная превью';
    }
    return null;
  }

  Future<String> _upload(PlatformFile file, String folder, String slug) async {
    final ext = (file.extension ?? 'jpg').toLowerCase();
    final path = '$folder/$slug.$ext';
    final storage = SupabaseService.client.storage.from(_bucket);
    await storage.uploadBinary(
      path,
      file.bytes!,
      fileOptions: FileOptions(upsert: true, contentType: _contentType(ext)),
    );
    return storage.getPublicUrl(path);
  }

  Future<void> _publish() async {
    final err = _validate();
    if (err != null) {
      _toast(err);
      return;
    }
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final slug = _slugCtrl.text.trim();
      String? imageUrl;
      String? thumbUrl;

      if (_needsFile) {
        imageUrl = await _upload(_mainFile!, _kindDb(_kind), slug);
      }
      if (_needsThumb) {
        thumbUrl = await _upload(_thumbFile!, 'thumbs', slug);
      } else if (_kind == BackgroundKind.image && _thumbFile?.bytes != null) {
        thumbUrl = await _upload(_thumbFile!, 'thumbs', slug);
      }

      final row = <String, dynamic>{
        'slug': slug,
        'name': _nameCtrl.text.trim(),
        'kind': _kindDb(_kind),
        'rarity': _rarityDb(_rarity),
        'price_dp': int.parse(_priceCtrl.text.trim()),
        'sort_order': int.parse(_sortCtrl.text.trim()),
        'is_published': _published,
        'image_url': ?imageUrl,
        'thumbnail_url': ?thumbUrl,
        'style_config': _kind == BackgroundKind.gradient
            ? jsonDecode(_styleCtrl.text)
            : <String, dynamic>{},
      };

      await SupabaseService.client.from('profile_backgrounds').insert(row);

      ref.invalidate(allProfileBackgroundsProvider);
      ref.invalidate(profileBackgroundsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Фон опубликован')),
      );
      _resetForm();
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: ${e.message}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _resetForm() {
    setState(() {
      _nameCtrl.clear();
      _slugCtrl.clear();
      _slugEdited = false;
      _priceCtrl.text = '0';
      _sortCtrl.text = '0';
      _mainFile = null;
      _thumbFile = null;
      _kind = BackgroundKind.gradient;
      _rarity = CosmeticRarity.common;
      _published = true;
    });
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: c.textPrimary),
          title: Text('Dev Studio · Фоны',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _section(c, 'НОВЫЙ ФОН'),
            _field(c, 'Название', _nameCtrl),
            _field(c, 'Slug', _slugCtrl,
                onChanged: (_) => _slugEdited = true),
            const SizedBox(height: 12),
            _kindDropdown(c),
            const SizedBox(height: 12),
            _rarityDropdown(c),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(c, 'Цена DP', _priceCtrl, number: true)),
                const SizedBox(width: 12),
                Expanded(
                    child: _field(c, 'Порядок', _sortCtrl, number: true)),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _published,
              activeColor: c.accent,
              onChanged: (v) => setState(() => _published = v),
              title: Text('Опубликован',
                  style: TextStyle(color: c.textPrimary, fontSize: 14)),
              subtitle: Text('Виден всем в магазине',
                  style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ),
            const SizedBox(height: 8),
            if (_kind == BackgroundKind.gradient)
              _field(c, 'style_config (JSON)', _styleCtrl, maxLines: 4)
            else ...[
              _filePicker(c, 'Файл фона', _mainFile, _pickMain),
              const SizedBox(height: 10),
              _filePicker(
                c,
                _needsThumb ? 'Превью (обязательно)' : 'Превью (опц.)',
                _thumbFile,
                _pickThumb,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _publishing ? null : _publish,
              child: _publishing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('ОПУБЛИКОВАТЬ'),
            ),
            const SizedBox(height: 32),
            _section(c, 'СУЩЕСТВУЮЩИЕ ФОНЫ'),
            _existingList(c),
          ],
        ),
      ),
    );
  }

  Widget _section(SieColors c, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
      );

  Widget _field(SieColors c, String label, TextEditingController ctrl,
      {bool number = false, int maxLines = 1, ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        maxLines: maxLines,
        keyboardType: number ? TextInputType.number : null,
        style: TextStyle(color: c.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: c.textSecondary),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: c.border),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: c.accent),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _kindDropdown(SieColors c) => DropdownButtonFormField<BackgroundKind>(
        value: _kind,
        dropdownColor: c.surface,
        decoration: _dropDeco(c, 'Тип'),
        style: TextStyle(color: c.textPrimary, fontSize: 14),
        items: const [
          DropdownMenuItem(
              value: BackgroundKind.gradient, child: Text('Градиент')),
          DropdownMenuItem(
              value: BackgroundKind.image, child: Text('Картинка')),
          DropdownMenuItem(
              value: BackgroundKind.animatedWebp,
              child: Text('Анимированный WebP')),
          DropdownMenuItem(
              value: BackgroundKind.lottie, child: Text('Lottie')),
        ],
        onChanged: (v) => setState(() {
          _kind = v ?? BackgroundKind.gradient;
          _mainFile = null;
          _thumbFile = null;
        }),
      );

  Widget _rarityDropdown(SieColors c) =>
      DropdownButtonFormField<CosmeticRarity>(
        value: _rarity,
        dropdownColor: c.surface,
        decoration: _dropDeco(c, 'Редкость'),
        style: TextStyle(color: c.textPrimary, fontSize: 14),
        items: const [
          DropdownMenuItem(
              value: CosmeticRarity.common, child: Text('Common')),
          DropdownMenuItem(value: CosmeticRarity.rare, child: Text('Rare')),
          DropdownMenuItem(value: CosmeticRarity.epic, child: Text('Epic')),
          DropdownMenuItem(
              value: CosmeticRarity.legendary, child: Text('Legendary')),
        ],
        onChanged: (v) => setState(() => _rarity = v ?? CosmeticRarity.common),
      );

  InputDecoration _dropDeco(SieColors c, String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.border),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.accent),
          borderRadius: BorderRadius.circular(10),
        ),
      );

  Widget _filePicker(
      SieColors c, String label, PlatformFile? file, VoidCallback onPick) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.upload_file, size: 20, color: c.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                file?.name ?? label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: file != null ? c.textPrimary : c.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            if (file != null)
              Text('${(file.size / 1024).toStringAsFixed(0)} KB',
                  style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _existingList(SieColors c) {
    final async = ref.watch(allProfileBackgroundsProvider);
    return async.when(
      loading: () => Center(child: CircularProgressIndicator(color: c.accent)),
      error: (e, _) => Text('Ошибка загрузки: $e',
          style: TextStyle(color: c.textSecondary)),
      data: (bgs) => Column(
        children: [
          for (final bg in bgs) _existingRow(c, bg),
        ],
      ),
    );
  }

  Widget _existingRow(SieColors c, CosmeticAsset bg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bg.name,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${_kindDb(bg.backgroundKind)} · ${bg.rarityLabel} · '
                  '${bg.priceDP} DP',
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: c.textSecondary, size: 20),
            onPressed: () => _delete(bg),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(CosmeticAsset bg) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить фон?'),
        content: Text('«${bg.name}» будет удалён из каталога.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.client
          .from('profile_backgrounds')
          .delete()
          .eq('id', bg.id);
      ref.invalidate(allProfileBackgroundsProvider);
      ref.invalidate(profileBackgroundsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Фон удалён')));
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: ${e.message}')));
    }
  }
}
