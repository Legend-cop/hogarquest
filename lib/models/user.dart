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
