import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Indica si el dispositivo solicita reducir el movimiento.
bool hqReduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Entrada breve con deslizamiento, escala y opacidad.
class PlayfulEntrance extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final double distance;

  const PlayfulEntrance({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.distance = 18,
  });

  @override
  State<PlayfulEntrance> createState() => _PlayfulEntranceState();
}

class _PlayfulEntranceState extends State<PlayfulEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (hqReduceMotion(context)) return widget.child;
    final move = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return FadeTransition(
      opacity: fade,
      child: AnimatedBuilder(
        animation: move,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.distance * (1 - move.value)),
          child: Transform.scale(
            scale: 0.96 + (0.04 * move.value),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Respuesta elástica al tocar un control.
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const BouncyTap({super.key, required this.child, this.onTap});

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
        onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
        onTapUp: widget.onTap == null
            ? null
            : (_) {
                _setPressed(false);
                widget.onTap?.call();
              },
        child: AnimatedScale(
          scale: hqReduceMotion(context) || !_pressed ? 1 : 0.94,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Conserva el estado de las pestañas y anima solo la vista activa.
class PlayfulIndexedStack extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const PlayfulIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final reduced = hqReduceMotion(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          IgnorePointer(
            ignoring: i != index,
            // El fundido/deslizamiento va FUERA del TickerMode: si el
            // TickerMode apagara el ticker de la pantalla saliente, su
            // AnimatedOpacity no podría bajar de 1 a 0 y las vistas quedarían
            // superpuestas para siempre.
            child: AnimatedOpacity(
              opacity: i == index ? 1 : 0,
              duration: Duration(milliseconds: reduced ? 0 : 260),
              curve: Curves.easeOut,
              child: AnimatedSlide(
                offset: i == index || reduced
                    ? Offset.zero
                    : Offset(i < index ? -0.035 : 0.035, 0),
                duration: Duration(milliseconds: reduced ? 0 : 330),
                curve: Curves.easeOutCubic,
                child: TickerMode(
                  enabled: i == index,
                  child: children[i],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Estrella decorativa para momentos de bienvenida.
class Twinkle extends StatefulWidget {
  final Color color;
  final double size;
  final int delayMs;

  const Twinkle({
    super.key,
    required this.color,
    this.size = 18,
    this.delayMs = 0,
  });

  @override
  State<Twinkle> createState() => _TwinkleState();
}

class _TwinkleState extends State<Twinkle> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted && !hqReduceMotion(context)) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (hqReduceMotion(context)) {
      return Icon(Icons.auto_awesome, size: widget.size, color: widget.color);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.rotate(
          angle: math.pi * 0.16 * t,
          child: Transform.scale(
            scale: 0.72 + (0.36 * t),
            child: Opacity(
              opacity: 0.58 + (0.42 * t),
              child: Icon(
                Icons.auto_awesome,
                size: widget.size,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}
