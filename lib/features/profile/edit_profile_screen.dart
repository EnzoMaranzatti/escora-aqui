import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';

/// Round avatar: the picked photo, else the first letter of the name.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.photo, required this.name, this.size = 52});

  final String? photo;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty || name == 'você' ? 'E' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: AppColors.petroleo600, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: photo != null
          ? Image.file(File(photo!), width: size, height: size, fit: BoxFit.cover, cacheWidth: (size * 3).round())
          : Text(
              letter,
              style: AppType.cardTitle(size: size * .4, color: AppColors.white),
            ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late String _name = store.fullName.isEmpty && store.name != 'você' ? store.name : store.fullName;
  late String _email = store.email;
  late String _phone = store.userPhone;
  late String _birth = store.birthDate == null ? '' : _fmt(store.birthDate!);
  late String? _avatar = store.avatar;
  final _touched = <String>{};
  bool _saving = false;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Parsed birth date, or null when empty or invalid.
  DateTime? get _birthDate {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(_birth);
    if (m == null) return null;
    final (d, mo, y) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    final date = DateTime(y, mo, d);
    if (date.day != d || date.month != mo || y < 1900 || date.isAfter(DateTime.now())) return null;
    return date;
  }

  String? get _nameError => _name.trim().isEmpty ? 'Preencha este campo para continuar.' : null;
  String? get _emailError => _emailRe.hasMatch(_email.trim()) ? null : 'Confira o e-mail. Ele precisa ter @ e domínio.';
  String? get _phoneError {
    final n = Fmt.digits(_phone).length;
    return n == 0 || n == 10 || n == 11 ? null : 'Confira o número com DDD.';
  }

  String? get _birthError => _birth.isEmpty || _birthDate != null ? null : 'Confira a data. Use dia/mês/ano.';

  bool get _valid => _nameError == null && _emailError == null && _phoneError == null && _birthError == null;

  String? _err(String field, String? error) => _touched.contains(field) ? error : null;

  Future<void> _pickPhoto() async {
    if (_avatar != null) {
      final choice = await showAppSheet<String>(
        context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Foto de perfil', style: AppType.title()),
            const SizedBox(height: 12),
            InfoRow(
              icon: PhosphorIconsRegular.image,
              title: 'Escolher outra foto',
              onTap: () => Navigator.pop(context, 'pick'),
            ),
            const Hairline(indent: 40),
            InfoRow(
              icon: PhosphorIconsRegular.trash,
              title: 'Remover foto',
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      );
      if (choice == 'remove') return setState(() => _avatar = null);
      if (choice != 'pick') return;
    }
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800);
      if (f != null && mounted) setState(() => _avatar = f.path);
    } catch (_) {}
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_valid) {
      setState(() => _touched.addAll(['name', 'email', 'phone', 'birth']));
      return;
    }
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    store.updateProfile(
      fullName: _name.trim(),
      email: _email.trim(),
      phone: _phone,
      birthDate: _birthDate,
      avatar: _avatar,
    );
    HapticFeedback.lightImpact();
    Toast.show(context, 'Dados atualizados.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'Meus dados',
      primary: 'Salvar',
      onPrimary: _save,
      loading: _saving,
      children: [
        Center(
          child: Semantics(
            button: true,
            label: _avatar == null ? 'Adicionar foto de perfil' : 'Trocar foto de perfil',
            excludeSemantics: true,
            child: Pressable(
              onTap: _pickPhoto,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ProfileAvatar(photo: _avatar, name: _name, size: 92),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.cinza100),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(PhosphorIconsRegular.camera, size: 17, color: AppColors.petroleo600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _avatar == null ? 'Adicionar foto' : 'Trocar foto',
                    style: AppType.label(size: 14, color: AppColors.petroleo700),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppTextField(
          label: 'Nome completo',
          hint: 'Seu nome',
          initialValue: _name,
          capitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.next,
          error: _err('name', _nameError),
          onChanged: (v) => setState(() => _name = v),
          onFocusLost: () => setState(() => _touched.add('name')),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'E-mail',
          hint: 'seu@email.com',
          initialValue: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          error: _err('email', _emailError),
          onChanged: (v) => setState(() => _email = v),
          onFocusLost: () => setState(() => _touched.add('email')),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Celular (opcional)',
          hint: '(17) 99999-9999',
          help: 'Usado só quando você se inscreve em um voluntariado.',
          initialValue: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [MaskFormatter.phone()],
          textInputAction: TextInputAction.next,
          error: _err('phone', _phoneError),
          onChanged: (v) => setState(() => _phone = v),
          onFocusLost: () => setState(() => _touched.add('phone')),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Data de nascimento (opcional)',
          hint: 'dd/mm/aaaa',
          initialValue: _birth,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.birthday],
          inputFormatters: [MaskFormatter('##/##/####')],
          textInputAction: TextInputAction.done,
          error: _err('birth', _birthError),
          onChanged: (v) => setState(() => _birth = v),
          onFocusLost: () => setState(() => _touched.add('birth')),
        ),
      ],
    );
  }
}
