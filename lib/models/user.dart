class User {
  final int? id;
  final String nombre;
  final String avatar;
  final String foto;
  final int edad;
  final String colorTema;
  final int nivel;
  final int puntos;
  final int racha;
  final String password;
  final String salt;
  final String rol;
  final bool activo;
  final List<int>? insigniasObtenidas;

  const User({
    this.id,
    required this.nombre,
    this.avatar = '',
    this.foto = '',
    this.edad = 0,
    this.colorTema = '',
    this.nivel = 1,
    this.puntos = 0,
    this.racha = 0,
    required this.password,
    this.salt = '',
    this.rol = 'integrante',
    this.activo = true,
    this.insigniasObtenidas,
  });

  bool get esAdmin => rol == 'admin';

  /// Paleta de colores para los integrantes (cada uno con uno distinto).
  static const List<String> nombresPaleta = [
    'verde', 'azul', 'morado', 'rojo', 'naranja', 'cian', 'rosado', 'cafe',
  ];

  /// Normaliza el color guardado (ej: 'Rojo', 'Café', 'cafe') a una clave.
  static String? claveColor(String? tema) {
    final t = (tema ?? '').trim().toLowerCase();
    if (t.isEmpty) return null;
    for (final n in nombresPaleta) {
      if (t == n) return n;
    }
    if (t.startsWith('cafe') || t.startsWith('marr') || t == 'café') {
      return 'cafe';
    }
    if (t.startsWith('naran') || t.startsWith('anaranj') || t == 'orange') {
      return 'naranja';
    }
    if (t.startsWith('ros') || t == 'pink') return 'rosado';
    if (t.startsWith('cian') || t == 'cyan') return 'cian';
    if (t.startsWith('rojo') || t == 'red') return 'rojo';
    if (t.startsWith('verde') || t == 'green') return 'verde';
    if (t.startsWith('azul') || t == 'blue') return 'azul';
    if (t.startsWith('mora') || t == 'purple' || t == 'violeta') return 'morado';
    return null;
  }

  /// Elige un color de la paleta que ningún integrante esté usando todavía.
  static String colorLibre(List<User> usuarios) {
    final usados = <String>{
      for (final u in usuarios)
        if (claveColor(u.colorTema) != null) claveColor(u.colorTema)!,
    };
    for (final n in nombresPaleta) {
      if (!usados.contains(n)) return n;
    }
    return nombresPaleta.first;
  }

  User copyWith({
    int? id,
    String? nombre,
    String? avatar,
    String? foto,
    int? edad,
    String? colorTema,
    int? nivel,
    int? puntos,
    int? racha,
    String? password,
    String? salt,
    String? rol,
    bool? activo,
    List<int>? insigniasObtenidas,
  }) {
    return User(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      avatar: avatar ?? this.avatar,
      foto: foto ?? this.foto,
      edad: edad ?? this.edad,
      colorTema: colorTema ?? this.colorTema,
      nivel: nivel ?? this.nivel,
      puntos: puntos ?? this.puntos,
      racha: racha ?? this.racha,
      password: password ?? this.password,
      salt: salt ?? this.salt,
      rol: rol ?? this.rol,
      activo: activo ?? this.activo,
      insigniasObtenidas: insigniasObtenidas ?? this.insigniasObtenidas,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'avatar': avatar,
      'foto': foto,
      'edad': edad,
      'color_tema': colorTema,
      'nivel': nivel,
      'puntos': puntos,
      'racha': racha,
      'password': password,
      'salt': salt,
      'rol': rol,
      'activo': activo ? 1 : 0,
      'insignias_obtenidas': insigniasObtenidas,
    };
  }

  factory User.fromMap(Map<String, Object?> map) {
    return User(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      avatar: (map['avatar'] as String?) ?? '',
      foto: (map['foto'] as String?) ?? '',
      edad: (map['edad'] as int?) ?? 0,
      colorTema: (map['color_tema'] as String?) ?? '',
      nivel: (map['nivel'] as int?) ?? 1,
      puntos: (map['puntos'] as int?) ?? 0,
      racha: (map['racha'] as int?) ?? 0,
      password: (map['password'] as String?) ?? '',
      salt: (map['salt'] as String?) ?? '',
      rol: (map['rol'] as String?) ?? 'integrante',
      activo: (map['activo'] as int?) != 0,
      insigniasObtenidas: (map['insignias_obtenidas'] as List?)?.cast<int>(),
    );
  }
}
