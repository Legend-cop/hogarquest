import 'package:flutter/material.dart';

import '../db/server_config.dart';
import '../models/user.dart';

/// Avatar de usuario: foto de perfil si existe, si no iniciales del nombre
/// sobre un color determinista (sin emojis, que llegan corruptos de los datos).
class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 20,
    this.foto,
  });

  final User user;
  final double radius;
  final String? foto;

  /// Color estable por nombre, para que cada persona siempre tenga el mismo.
  static const _paleta = [
    Color(0xFF2E7D32), // verde
    Color(0xFF1565C0), // azul
    Color(0xFF6A1B9A), // morado
    Color(0xFFC62828), // rojo
    Color(0xFFEF6C00), // naranja
    Color(0xFF00838F), // cian
    Color(0xFFAD1457), // rosado
    Color(0xFF5D4037), // café
  ];

  static Color colorDe(String nombre) {
    final nombreNormal = nombre.trim().toLowerCase();
    if (nombreNormal.isEmpty) return _paleta.first;
    var h = 0;
    for (final c in nombreNormal.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _paleta[h % _paleta.length];
  }

  static String iniciales(String nombre) {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    final primero =
        String.fromCharCodes(partes.first.runes.take(1)).toUpperCase();
    if (partes.length == 1) return primero;
    final segundo =
        String.fromCharCodes(partes.last.runes.take(1)).toUpperCase();
    return '$primero$segundo';
  }

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  bool _fallo = false;

  String get _fotoUrl {
    final f = widget.foto ?? widget.user.foto;
    if (f.isEmpty) return '';
    if (f.startsWith('http')) return f;
    return '${ServerConfig.baseUrl}$f';
  }

  @override
  Widget build(BuildContext context) {
    final url = _fotoUrl;
    if (url.isNotEmpty && !_fallo) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, _) {
          if (mounted) setState(() => _fallo = true);
        },
      );
    }
    final nombre = widget.user.nombre;
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: UserAvatar.colorDe(nombre),
      child: Text(
        UserAvatar.iniciales(nombre),
        style: TextStyle(
          fontSize: widget.radius * 0.8,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
