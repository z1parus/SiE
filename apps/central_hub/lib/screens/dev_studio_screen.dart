import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DevStudioScreen — admin panel with tabs: Backgrounds | DP | Tips
// ─────────────────────────────────────────────────────────────────────────────
class DevStudioScreen extends ConsumerStatefulWidget {
  const DevStudioScreen({super.key});

  @override
  ConsumerState<DevStudioScreen> createState() => _DevStudioScreenState();
}

class _DevStudioScreenState extends ConsumerState<DevStudioScreen>
    with TickerProviderStateMixin {
  late final TabController _tabs;

  // ── Backgrounds tab state ────────────────────────────────────
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
  double _overlayOpacity = 0.0;

  PlatformFile? _mainFile;
  PlatformFile? _thumbFile;
  bool _publishing = false;
  bool _slugEdited = false;

  // ── DP tab state ─────────────────────────────────────────────
  final _usernameCtrl = TextEditingController();
  final _dpValueCtrl = TextEditingController();
  Map<String, dynamic>? _foundUser;
  bool _searching = false;
  bool _settingDp = false;
  String? _dpStatusMsg;

  // ── Tips tab state ────────────────────────────────────────────
  final _tipTitleCtrl = TextEditingController();
  final _tipDescCtrl = TextEditingController();
  Tip? _editingTip;
  bool _savingTip = false;

  static const _bucket = 'profile-backgrounds';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _nameCtrl.addListener(_syncSlug);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.removeListener(_syncSlug);
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _priceCtrl.dispose();
    _sortCtrl.dispose();
    _styleCtrl.dispose();
    _usernameCtrl.dispose();
    _dpValueCtrl.dispose();
    _tipTitleCtrl.dispose();
    _tipDescCtrl.dispose();
    super.dispose();
  }

  // ── Slug auto-sync ───────────────────────────────────────────
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

  // ── File pickers ─────────────────────────────────────────────
  Future<void> _pickMain() async {
    final type =
        _kind == BackgroundKind.lottie ? FileType.custom : FileType.image;
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: type,
      allowedExtensions: _kind == BackgroundKind.lottie ? ['json'] : null,
    );
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;

    // Offer crop for static images only
    if (_kind == BackgroundKind.image && file.bytes != null && mounted) {
      final cropped = await Navigator.push<Uint8List?>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _CropDialog(imageBytes: file.bytes!),
        ),
      );
      if (!mounted) return;
      if (cropped != null) {
        final croppedName = file.name.replaceAll(RegExp(r'\.[^.]+$'), '.png');
        setState(() => _mainFile = PlatformFile(
              name: croppedName,
              size: cropped.length,
              bytes: cropped,
            ));
        return;
      }
    }
    setState(() => _mainFile = file);
  }

  Future<void> _pickThumb() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() => _thumbFile = res.files.first);
  }

  // ── Helpers ──────────────────────────────────────────────────
  String _kindDb(BackgroundKind k) => switch (k) {
        BackgroundKind.gradient => 'gradient',
        BackgroundKind.image => 'image',
        BackgroundKind.animatedWebp => 'animated_webp',
        BackgroundKind.lottie => 'lottie',
      };

  // Supabase Storage reserves the 'image/' path prefix for its Image
  // Transformation API, so we use 'img' as the upload folder instead.
  String _kindFolder(BackgroundKind k) => switch (k) {
        BackgroundKind.gradient => 'gradient',
        BackgroundKind.image => 'img',
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

  // ── Validation ───────────────────────────────────────────────
  String? _validate() {
    if (_nameCtrl.text.trim().isEmpty) return t.devStudio.validation.nameRequired;
    if (_slugCtrl.text.trim().isEmpty) return t.devStudio.validation.slugRequired;
    if (int.tryParse(_priceCtrl.text.trim()) == null) {
      return t.devStudio.validation.priceMustBeNumber;
    }
    if (int.tryParse(_sortCtrl.text.trim()) == null) {
      return t.devStudio.validation.sortMustBeNumber;
    }
    if (_kind == BackgroundKind.gradient) {
      try {
        jsonDecode(_styleCtrl.text);
      } catch (_) {
        return t.devStudio.validation.styleConfigInvalidJson;
      }
    } else if (_mainFile?.bytes == null) {
      return t.devStudio.validation.selectBackgroundFile;
    }
    if (_needsThumb && _thumbFile?.bytes == null) {
      return t.devStudio.validation.thumbRequired;
    }
    return null;
  }

  // ── Upload ───────────────────────────────────────────────────
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

  // ── Publish background ───────────────────────────────────────
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
        imageUrl = await _upload(_mainFile!, _kindFolder(_kind), slug);
      }
      if (_needsThumb) {
        thumbUrl = await _upload(_thumbFile!, 'thumbs', slug);
      } else if (_kind == BackgroundKind.image && _thumbFile?.bytes != null) {
        thumbUrl = await _upload(_thumbFile!, 'thumbs', slug);
      }

      final baseStyle = _kind == BackgroundKind.gradient
          ? Map<String, dynamic>.from(jsonDecode(_styleCtrl.text) as Map)
          : <String, dynamic>{};
      if (_overlayOpacity > 0) baseStyle['overlay_opacity'] = _overlayOpacity;

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
        'style_config': baseStyle,
      };

      await SupabaseService.client.from('profile_backgrounds').insert(row);
      ref.invalidate(allProfileBackgroundsProvider);
      ref.invalidate(profileBackgroundsProvider);
      messenger.showSnackBar(
          SnackBar(content: Text(t.devStudio.backgrounds.published)));
      _resetForm();
    } on PostgrestException catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(t.devStudio.backgrounds.error(message: e.message))));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(t.devStudio.backgrounds.error(message: '$e'))));
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
      _overlayOpacity = 0.0;
      _mainFile = null;
      _thumbFile = null;
      _kind = BackgroundKind.gradient;
      _rarity = CosmeticRarity.common;
      _published = true;
    });
  }

  // ── DP management ────────────────────────────────────────────
  Future<void> _searchUser() async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) return;
    setState(() {
      _searching = true;
      _foundUser = null;
      _dpStatusMsg = null;
    });
    try {
      final result = await SupabaseService.client
          .from('profiles')
          .select('id, username, design_points')
          .eq('username', username)
          .maybeSingle();
      setState(() {
        _foundUser = result;
        if (result != null) {
          _dpValueCtrl.text = result['design_points'].toString();
        } else {
          _dpStatusMsg = t.devStudio.dp.userNotFound(username: username);
        }
      });
    } catch (e) {
      setState(() => _dpStatusMsg = t.devStudio.dp.searchError(error: '$e'));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _setUserDp() async {
    final newDp = int.tryParse(_dpValueCtrl.text.trim());
    if (newDp == null || _foundUser == null) return;
    setState(() {
      _settingDp = true;
      _dpStatusMsg = null;
    });
    try {
      await SupabaseService.client.rpc('admin_set_user_dp', params: {
        'p_username': _foundUser!['username'],
        'p_new_dp': newDp,
      });
      setState(() {
        _foundUser = {..._foundUser!, 'design_points': newDp};
        _dpStatusMsg = t.devStudio.dp.dpUpdated(dp: newDp);
      });
    } on PostgrestException catch (e) {
      setState(() => _dpStatusMsg = t.devStudio.dp.error(message: e.message));
    } catch (e) {
      setState(() => _dpStatusMsg = t.devStudio.dp.error(message: '$e'));
    } finally {
      if (mounted) setState(() => _settingDp = false);
    }
  }

  // ── Delete background ────────────────────────────────────────
  Future<void> _delete(CosmeticAsset bg) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.devStudio.backgrounds.deleteTitle),
        content: Text(t.devStudio.backgrounds.deleteBody(name: bg.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.devStudio.common.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.devStudio.common.delete)),
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
      messenger.showSnackBar(SnackBar(content: Text(t.devStudio.backgrounds.deleted)));
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t.devStudio.backgrounds.error(message: e.message))));
    }
  }

  // ── Tips CRUD ────────────────────────────────────────────────
  Future<void> _saveTip() async {
    final title = _tipTitleCtrl.text.trim();
    final desc = _tipDescCtrl.text.trim();
    if (title.isEmpty || desc.isEmpty) {
      _toast(t.devStudio.tips.fillTitleAndDescription);
      return;
    }
    setState(() => _savingTip = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_editingTip != null) {
        await SupabaseService.client.from('tips').update({
          'title': title,
          'description': desc,
        }).eq('id', _editingTip!.id);
        messenger.showSnackBar(SnackBar(content: Text(t.devStudio.tips.updated)));
      } else {
        await SupabaseService.client.from('tips').insert({
          'title': title,
          'description': desc,
          'is_active': true,
        });
        messenger.showSnackBar(SnackBar(content: Text(t.devStudio.tips.created)));
      }
      _resetTipForm();
      ref.invalidate(allTipsProvider);
      ref.invalidate(tipsProvider);
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t.devStudio.tips.error(message: e.message))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t.devStudio.tips.error(message: '$e'))));
    } finally {
      if (mounted) setState(() => _savingTip = false);
    }
  }

  void _editTip(Tip tip) {
    setState(() {
      _editingTip = tip;
      _tipTitleCtrl.text = tip.title;
      _tipDescCtrl.text = tip.description;
    });
  }

  void _resetTipForm() {
    setState(() {
      _tipTitleCtrl.clear();
      _tipDescCtrl.clear();
      _editingTip = null;
    });
  }

  Future<void> _toggleTipActive(Tip tip, bool value) async {
    try {
      await SupabaseService.client
          .from('tips')
          .update({'is_active': value})
          .eq('id', tip.id);
      ref.invalidate(allTipsProvider);
      ref.invalidate(tipsProvider);
    } on PostgrestException catch (e) {
      _toast(t.devStudio.tips.error(message: e.message));
    }
  }

  Future<void> _deleteTip(Tip tip) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.devStudio.tips.deleteTitle),
        content: Text(t.devStudio.tips.deleteBody(title: tip.title)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.devStudio.common.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.devStudio.common.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.client.from('tips').delete().eq('id', tip.id);
      ref.invalidate(allTipsProvider);
      ref.invalidate(tipsProvider);
      messenger.showSnackBar(SnackBar(content: Text(t.devStudio.tips.deleted)));
      if (_editingTip?.id == tip.id) _resetTipForm();
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t.devStudio.tips.error(message: e.message))));
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ────────────────────────────────────────────────────
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
          title: Text(
            t.devStudio.title,
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: c.accent,
            indicatorWeight: 1.5,
            labelColor: c.accent,
            unselectedLabelColor: c.textSecondary,
            labelStyle: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(text: t.devStudio.tabs.backgrounds),
              Tab(text: t.devStudio.tabs.dp),
              Tab(text: t.devStudio.tabs.tips),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _backgroundsTab(c),
            _dpTab(c),
            _tipsTab(c),
          ],
        ),
      ),
    );
  }

  // ── Backgrounds tab ──────────────────────────────────────────
  Widget _backgroundsTab(SieColors c) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _section(c, t.devStudio.backgrounds.sectionNew),
          _field(c, t.devStudio.backgrounds.fieldName, _nameCtrl),
          _field(c, t.devStudio.backgrounds.fieldSlug, _slugCtrl, onChanged: (_) => _slugEdited = true),
          const SizedBox(height: 12),
          _kindDropdown(c),
          const SizedBox(height: 12),
          _rarityDropdown(c),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _field(c, t.devStudio.backgrounds.fieldPrice, _priceCtrl, number: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: _field(c, t.devStudio.backgrounds.fieldSort, _sortCtrl, number: true)),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _published,
            activeColor: c.accent,
            onChanged: (v) => setState(() => _published = v),
            title: Text(t.devStudio.backgrounds.publishedTitle,
                style: TextStyle(color: c.textPrimary, fontSize: 14)),
            subtitle: Text(t.devStudio.backgrounds.publishedSubtitle,
                style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ),
          const SizedBox(height: 8),
          if (_kind == BackgroundKind.gradient)
            _field(c, t.devStudio.backgrounds.fieldStyleConfig, _styleCtrl, maxLines: 4)
          else ...[
            _filePicker(c, t.devStudio.backgrounds.fileBackground, _mainFile, _pickMain),
            const SizedBox(height: 10),
            _filePicker(
              c,
              _needsThumb ? t.devStudio.backgrounds.thumbRequired : t.devStudio.backgrounds.thumbOptional,
              _thumbFile,
              _pickThumb,
            ),
          ],
          // Overlay slider
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                t.devStudio.backgrounds.overlay(percent: (_overlayOpacity * 100).round()),
                style:
                    TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              if (_overlayOpacity > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t.devStudio.backgrounds.overlayActive,
                      style: TextStyle(
                          color: c.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1),
                    ),
                  ),
                ),
            ],
          ),
          Slider(
            value: _overlayOpacity,
            min: 0.0,
            max: 0.5,
            divisions: 10,
            activeColor: c.accent,
            inactiveColor: c.border,
            label: '${(_overlayOpacity * 100).round()}%',
            onChanged: (v) => setState(() => _overlayOpacity = v),
          ),
          // Mini preview with overlay for image kind
          if (_kind == BackgroundKind.image &&
              _mainFile?.bytes != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_mainFile!.bytes!, fit: BoxFit.cover),
                    if (_overlayOpacity > 0)
                      ColoredBox(
                        color: Colors.black
                            .withValues(alpha: _overlayOpacity),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.devStudio.backgrounds.overlayPreview,
              style:
                  TextStyle(color: c.textSecondary, fontSize: 11),
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
                : Text(t.devStudio.backgrounds.publishButton),
          ),
          const SizedBox(height: 32),
          _section(c, t.devStudio.backgrounds.sectionExisting),
          _existingList(c),
        ],
      );

  // ── DP management tab ────────────────────────────────────────
  Widget _dpTab(SieColors c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(c, t.devStudio.dp.sectionSearch),
            Row(
              children: [
                Expanded(
                    child: _field(c, t.devStudio.dp.fieldUsername, _usernameCtrl)),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onPressed: _searching ? null : _searchUser,
                  child: _searching
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(t.devStudio.dp.searchButton,
                          style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            if (_dpStatusMsg != null) ...[
              const SizedBox(height: 12),
              Text(_dpStatusMsg!,
                  style: TextStyle(color: c.textSecondary, fontSize: 13)),
            ],
            if (_foundUser != null) ...[
              const SizedBox(height: 20),
              _section(c, t.devStudio.dp.sectionFound),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            color: c.accent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _foundUser!['username'] ?? '—',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.palette_outlined,
                            color: c.dp, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          t.devStudio.dp.currentBalance(dp: _foundUser!['design_points']),
                          style: TextStyle(
                              color: c.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _section(c, t.devStudio.dp.sectionSetBalance),
              Row(
                children: [
                  Expanded(
                    child: _field(c, t.devStudio.dp.fieldNewDp, _dpValueCtrl,
                        number: true),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.dp,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onPressed: _settingDp ? null : _setUserDp,
                    child: _settingDp
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : Text(t.devStudio.dp.applyButton,
                            style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ],
        ),
      );

  // ── Tips management tab ──────────────────────────────────────
  Widget _tipsTab(SieColors c) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _section(c, _editingTip != null ? t.devStudio.tips.sectionEdit : t.devStudio.tips.sectionNew),
          _field(c, t.devStudio.tips.fieldTitle, _tipTitleCtrl),
          _field(c, t.devStudio.tips.fieldDescription, _tipDescCtrl, maxLines: 3),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _savingTip ? null : _saveTip,
                  child: _savingTip
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_editingTip != null ? t.devStudio.tips.saveButton : t.devStudio.tips.publishButton),
                ),
              ),
              if (_editingTip != null) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.textSecondary,
                    side: BorderSide(color: c.border),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _resetTipForm,
                  child: Text(t.devStudio.tips.cancelButton),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
          _section(c, t.devStudio.tips.sectionExisting),
          _tipsList(c),
        ],
      );

  Widget _tipsList(SieColors c) {
    final async = ref.watch(allTipsProvider);
    return async.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: c.accent)),
      error: (e, _) => Text(t.devStudio.common.loadError(error: '$e'),
          style: TextStyle(color: c.textSecondary)),
      data: (tips) {
        if (tips.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              t.devStudio.tips.empty,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          );
        }
        return Column(
          children: [for (final tip in tips) _tipRow(c, tip)],
        );
      },
    );
  }

  Widget _tipRow(SieColors c, Tip tip) => Container(
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
                  Text(tip.title,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    tip.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: tip.isActive,
              activeColor: c.accent,
              onChanged: (v) => _toggleTipActive(tip, v),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  color: c.textSecondary, size: 18),
              onPressed: () => _editTip(tip),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: c.textSecondary, size: 18),
              onPressed: () => _deleteTip(tip),
            ),
          ],
        ),
      );

  // ── Shared widgets ───────────────────────────────────────────
  Widget _section(SieColors c, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5),
        ),
      );

  Widget _field(
    SieColors c,
    String label,
    TextEditingController ctrl, {
    bool number = false,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) =>
      Padding(
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

  Widget _kindDropdown(SieColors c) =>
      DropdownButtonFormField<BackgroundKind>(
        value: _kind,
        dropdownColor: c.surface,
        decoration: _dropDeco(c, t.devStudio.kind.label),
        style: TextStyle(color: c.textPrimary, fontSize: 14),
        items: [
          DropdownMenuItem(
              value: BackgroundKind.gradient, child: Text(t.devStudio.kind.gradient)),
          DropdownMenuItem(
              value: BackgroundKind.image, child: Text(t.devStudio.kind.image)),
          DropdownMenuItem(
              value: BackgroundKind.animatedWebp,
              child: Text(t.devStudio.kind.animatedWebp)),
          DropdownMenuItem(
              value: BackgroundKind.lottie, child: Text(t.devStudio.kind.lottie)),
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
        decoration: _dropDeco(c, t.devStudio.rarity.label),
        style: TextStyle(color: c.textPrimary, fontSize: 14),
        items: [
          DropdownMenuItem(
              value: CosmeticRarity.common, child: Text(t.devStudio.rarity.common)),
          DropdownMenuItem(
              value: CosmeticRarity.rare, child: Text(t.devStudio.rarity.rare)),
          DropdownMenuItem(
              value: CosmeticRarity.epic, child: Text(t.devStudio.rarity.epic)),
          DropdownMenuItem(
              value: CosmeticRarity.legendary, child: Text(t.devStudio.rarity.legendary)),
        ],
        onChanged: (v) =>
            setState(() => _rarity = v ?? CosmeticRarity.common),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                  style:
                      TextStyle(color: c.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _existingList(SieColors c) {
    final async = ref.watch(allProfileBackgroundsProvider);
    return async.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: c.accent)),
      error: (e, _) => Text(t.devStudio.common.loadError(error: '$e'),
          style: TextStyle(color: c.textSecondary)),
      data: (bgs) => Column(
        children: [for (final bg in bgs) _existingRow(c, bg)],
      ),
    );
  }

  Widget _existingRow(SieColors c, CosmeticAsset bg) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    t.devStudio.backgrounds.rowSubtitle(kind: _kindDb(bg.backgroundKind), rarity: bg.rarityLabel, price: bg.priceDP),
                    style:
                        TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: c.textSecondary, size: 20),
              onPressed: () => _delete(bg),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Crop Dialog — card-shaped interactive crop with pan/zoom
// ─────────────────────────────────────────────────────────────────────────────
class _CropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const _CropDialog({required this.imageBytes});

  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  final _repaintKey = GlobalKey();
  bool _cropping = false;

  static const double _cardW = 300;
  static const double _cardH = 150;
  static const double _cardRadius = 20;

  Future<void> _crop() async {
    setState(() => _cropping = true);
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.pop(context, data?.buffer.asUint8List());
    } catch (e) {
      if (mounted) setState(() => _cropping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context, null),
                  ),
                  Expanded(
                    child: Text(
                      t.devStudio.crop.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // Instructions
            Text(
              t.devStudio.crop.instruction,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              t.devStudio.crop.hint,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            // Crop area
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glow border
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_cardRadius),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x44C8A84B),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFC8A84B),
                          width: 1.5,
                        ),
                      ),
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(_cardRadius),
                          child: SizedBox(
                            width: _cardW,
                            height: _cardH,
                            child: InteractiveViewer(
                              minScale: 0.3,
                              maxScale: 6.0,
                              child: Image.memory(
                                widget.imageBytes,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_cardW.toInt()} × ${_cardH.toInt()} · 2:1',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            // Action buttons
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => Navigator.pop(context, null),
                      child: Text(t.devStudio.crop.cancel),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC8A84B),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _cropping ? null : _crop,
                      child: _cropping
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : Text(
                              t.devStudio.crop.crop,
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
