import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
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
    this.fotoLocal,
  });

  final User user;
  final double radius;
  final String? foto;
  final String? fotoLocal;

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

  /// Color de la paleta según una clave de color ('verde', 'naranja', ...).
  static Color? colorPorClave(String? clave) {
    final c = User.claveColor(clave);
    if (c == null) return null;
    return _paleta[User.nombresPaleta.indexOf(c)];
  }

  /// Color estable por nombre (solo de respaldo para usuarios sin color).
  static Color colorDeNombre(String nombre) {
    final nombreNormal = nombre.trim().toLowerCase();
    if (nombreNormal.isEmpty) return _paleta.first;
    var h = 0;
    for (final c in nombreNormal.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _paleta[h % _paleta.length];
  }

  /// Color del usuario: el guardado si existe, si no el del nombre.
  static Color colorDe(User u) =>
      colorPorClave(u.colorTema) ?? colorDeNombre(u.nombre);

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

  /// Ruta local de la foto si existe en disco (funciona sin internet).
  String? _rutaLocal() {
    if (kIsWeb) return null; // en web no existe el sistema de archivos local
    final local = widget.fotoLocal ?? widget.user.fotoLocal;
    if (local.isEmpty) return null;
    if (!File(local).existsSync()) return null;
    return local;
  }

  @override
  Widget build(BuildContext context) {
    final local = _rutaLocal();
    if (local != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: FileImage(File(local)),
        onBackgroundImageError: (_, _) {
          if (mounted) setState(() => _fallo = true);
        },
      );
    }
    final url = _fotoUrl;
    if (url.isNotEmpty && !_fallo) {
      // CachedNetworkImageProvider guarda en disco: la foto se ve offline
      // tras la primera carga con internet.
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: CachedNetworkImageProvider(url),
        onBackgroundImageError: (_, _) {
          if (mounted) setState(() => _fallo = true);
        },
      );
    }
    final nombre = widget.user.nombre;
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: UserAvatar.colorDe(widget.user),
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
