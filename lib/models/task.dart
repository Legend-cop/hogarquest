import 'package:flutter/material.dart';

class Task {
  final int? id;
  final String titulo;
  final String descripcion;
  final int puntos;
  final String dificultad;
  final DateTime? fechaLimite;
  final String frecuencia;
  final String estado;
  final String dia;
  final String categoria;

  const Task({
    this.id,
    required this.titulo,
    this.descripcion = '',
    required this.puntos,
    this.dificultad = 'media',
    this.fechaLimite,
    this.frecuencia = 'unica',
    this.estado = 'activa',
    this.dia = '',
    this.categoria = 'General',
  });

  bool get activa => estado == 'activa';

  Task copyWith({
    int? id,
    String? titulo,
    String? descripcion,
    int? puntos,
    String? dificultad,
    DateTime? fechaLimite,
    String? frecuencia,
    String? estado,
    String? dia,
    String? categoria,
  }) {
    return Task(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      puntos: puntos ?? this.puntos,
      dificultad: dificultad ?? this.dificultad,
      fechaLimite: fechaLimite ?? this.fechaLimite,
      frecuencia: frecuencia ?? this.frecuencia,
      estado: estado ?? this.estado,
      dia: dia ?? this.dia,
      categoria: categoria ?? this.categoria,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'puntos': puntos,
      'dificultad': dificultad,
      'fecha_limite': fechaLimite?.toIso8601String(),
      'frecuencia': frecuencia,
      'estado': estado,
      'dia': dia,
      'categoria': categoria,
    };
  }

  factory Task.fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as int?,
      titulo: map['titulo'] as String,
      descripcion: (map['descripcion'] as String?) ?? '',
      puntos: (map['puntos'] as int?) ?? 0,
      dificultad: (map['dificultad'] as String?) ?? 'media',
      fechaLimite: map['fecha_limite'] != null
          ? DateTime.tryParse(map['fecha_limite'] as String)
          : null,
      frecuencia: (map['frecuencia'] as String?) ?? 'unica',
      estado: (map['estado'] as String?) ?? 'activa',
      dia: (map['dia'] as String?) ?? '',
      categoria: (map['categoria'] as String?) ?? 'General',
    );
  }
}

/// Metadatos de las categorías de tarea (color y icono para la UI).
class CategoriaTarea {
  static const List<String> nombres = [
    'General',
    'Escuela',
    'Limpieza',
    'Fe',
    'Responsabilidad',
    'Salud',
    'Orden',
    'Otro',
  ];

  static const Map<String, int> _color = {
    'General': 0xFF9E9E9E,
    'Escuela': 0xFF42A5F5,
    'Limpieza': 0xFF26C6DA,
    'Fe': 0xFFAB47BC,
    'Responsabilidad': 0xFF66BB6A,
    'Salud': 0xFFef5350,
    'Orden': 0xFFFFA726,
    'Otro': 0xFF789262,
  };

  static int colorDe(String c) => _color[c] ?? 0xFF9E9E9E;

  static IconData iconoDe(String c) {
    switch (c) {
      case 'Escuela':
        return Icons.school;
      case 'Limpieza':
        return Icons.cleaning_services;
      case 'Fe':
        return Icons.auto_stories;
      case 'Responsabilidad':
        return Icons.handshake;
      case 'Salud':
        return Icons.favorite;
      case 'Orden':
        return Icons.checklist_rtl;
      case 'Otro':
        return Icons.label;
      default:
        return Icons.category;
    }
  }
}
