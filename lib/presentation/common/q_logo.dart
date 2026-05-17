import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// Q + "radar" 텍스트를 합친 완성된 Qradar 로고 위젯
class QradarLogo extends StatelessWidget {
  final double size;

  const QradarLogo({super.key, this.size = 110});

  @override
  Widget build(BuildContext context) {
    // "radar" 텍스트 크기는 Q 사이즈에 비례
    final fontSize = size * 0.38;
    // Q 꼬리 하단 여백 보정 (QLogo 높이 기준 ~11%)
    final bottomPadding = size * 0.00;
    // Q와 radar 겹침 오프셋 (Q 폭 기준 ~9%)
    final overlapOffset = size * 0.05;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        QLogo(size: size),
        Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Transform.translate(
            offset: Offset(-overlapOffset, 0),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.primaryBright, AppColors.primaryDeep],
              ).createShader(bounds),
              child: Text(
                'radar',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class QLogo extends StatefulWidget {
  final double size;
  final bool animate;

  /// 로고 색상 주입. `null`이면 팔레트의 `primaryBright`(브랜드 기본).
  /// 미드나잇 블록(헤더) 위나 비활성 네비 탭 등에서 컨텍스트별로 지정.
  final Color? color;

  const QLogo({
    super.key,
    this.size = 160,
    this.animate = false,
    this.color,
  });

  @override
  State<QLogo> createState() => _QLogoState();
}

class _QLogoState extends State<QLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(QLogo old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _QLogoPainter(
          ringRotation: widget.animate ? _controller.value * 2 * pi : 0,
          color: widget.color ?? AppColors.primaryBright,
        ),
      ),
    );
  }
}

class _QLogoPainter extends CustomPainter {
  final double ringRotation;
  final Color color;

  const _QLogoPainter({this.ringRotation = 0, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final qRingOuter = r * 0.75;
    final qRingInner = r * 0.50;
    final qColor = color;

    // ── Q 링 (회전) ───────────────────────────────────────────────────────
    const gapStartDeg = 0.0;
    const gapEndDeg = 52.0;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(ringRotation);
    canvas.translate(-cx, -cy);

    final ringPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: qRingOuter))
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: qRingInner))
      ..fillType = PathFillType.evenOdd;

    final wedge = Path()
      ..moveTo(cx, cy)
      ..lineTo(
        cx + (qRingOuter + 4) * cos(gapStartDeg * pi / 180),
        cy + (qRingOuter + 4) * sin(gapStartDeg * pi / 180),
      )
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: qRingOuter + 4),
        gapStartDeg * pi / 180,
        (gapEndDeg - gapStartDeg) * pi / 180,
        false,
      )
      ..close();

    final ringWithGap = Path.combine(PathOperation.difference, ringPath, wedge);
    canvas.drawPath(
      ringWithGap,
      Paint()
        ..color = qColor
        ..style = PaintingStyle.fill,
    );

    canvas.restore();

    // ── Q 꼬리 (고정) ─────────────────────────────────────────────────────
    const tailAngle = 45.0 * pi / 180;
    final hwAbs = r * 0.12;

    final tailStart = Offset(
      cx + qRingOuter * 0.40 * cos(tailAngle),
      cy + qRingOuter * 0.40 * sin(tailAngle),
    );
    final tailEnd = Offset(
      cx + qRingOuter * 1.48 * cos(tailAngle),
      cy + qRingOuter * 1.48 * sin(tailAngle),
    );

    // 수평("-") 마감: 항상 같은 y, x는 hwAbs/sin(tailAngle)으로 계산
    final sinT = sin(tailAngle);
    // sin이 너무 작으면(꼬리가 수평에 가까울 때) 과도하게 넓어지므로 최소값 보정
    final safeSin = sinT.sign * sinT.abs().clamp(0.25, 1.0);
    final hwH = hwAbs / safeSin.abs();

    final startRight = Offset(tailStart.dx + hwH, tailStart.dy);
    final startLeft = Offset(tailStart.dx - hwH, tailStart.dy);
    final endRight = Offset(tailEnd.dx + hwH, tailEnd.dy);
    final endLeft = Offset(tailEnd.dx - hwH, tailEnd.dy);

    final tailPath = Path()
      ..moveTo(startRight.dx, startRight.dy)
      ..lineTo(endRight.dx, endRight.dy)
      ..lineTo(endLeft.dx, endLeft.dy)
      ..lineTo(startLeft.dx, startLeft.dy)
      ..close();

    canvas.drawPath(
      tailPath,
      Paint()
        ..color = qColor
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_QLogoPainter old) =>
      old.ringRotation != ringRotation || old.color != color;
}
