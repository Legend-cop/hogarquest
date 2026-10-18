import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

/// Selector de color del avatar con la paleta de HogarQuest: chips con el
/// color real de cada opción. Sincronizado con un [TextEditingController]:
/// si el valor guardado no es un color de la paleta (texto libre antiguo),
/// no hay chip seleccionado y el avatar usa su color por nombre.
class ColorAvatarPicker extends StatefulWidget {
  const ColorAvatarPicker({
    super.key,
    required this.controller,
    this.label = 'Color del avatar',
  });

  final TextEditingController controller;
  final String label;

  @override
  State<ColorAvatarPicker> createState() => _ColorAvatarPickerState();
}

class _ColorAvatarPickerState extends State<ColorAvatarPicker> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_alCambiar);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final actual = User.claveColor(widget.controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final nombre in User.nombresPaleta)
              _chip(nombre, actual == nombre),
          ],
        ),
        if (actual == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Sin color elegido: el avatar usará un color según tu nombre.',
              style: TextStyle(color: textoSuaveTema(context), fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _chip(String nombre, bool seleccionado) {
    final color = UserAvatar.colorPorClave(nombre) ?? Colors.grey;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => widget.controller.text = nombre,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: seleccionado
                ? Border.all(color: Colors.white, width: 3)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (seleccionado) ...[
                const Icon(Icons.check_circle, size: 14, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                nombre[0].toUpperCase() + nombre.substring(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
