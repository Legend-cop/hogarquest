import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../db/photo_store.dart';

/// Muestra una foto dando prioridad a la copia local (funciona sin internet).
/// Si no hay copia local, usa la URL del servidor (cacheada para verla offline
/// tras la primera visualizacion con conexion).
class FotoWidget extends StatelessWidget {
  final String url;
  final String local;
  final double size;
  final BoxFit fit;
  final Widget placeholder;

  const FotoWidget({
    required this.url,
    this.local = '',
    this.size = 42,
    this.fit = BoxFit.cover,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (PhotoStore.existe(local)) {
      return Image.file(
        File(local),
        width: size,
        height: size,
        fit: fit,
      );
    }
    if (url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: fit,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      );
    }
    return placeholder;
  }
}
