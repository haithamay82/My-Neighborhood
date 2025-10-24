import 'package:flutter/material.dart';
import 'dart:math' as math;

/// רקע אנימטיבי עם תמונות מטושטשות שזזות
class AnimatedBackground extends StatefulWidget {
  final Widget child;
  final List<String> backgroundImages;
  final Duration animationDuration;
  final double blurRadius;

  const AnimatedBackground({
    super.key,
    required this.child,
    this.backgroundImages = const [],
    this.animationDuration = const Duration(seconds: 20),
    this.blurRadius = 10.0,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // רקע אנימטיבי
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                    const Color(0xFF0F3460),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // תמונות רקע אנימטיביות - תנועה משמאל לימין
                  ...List.generate(8, (index) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final animationOffset = _animation.value * (screenWidth + 200) - 100;
                    
                    return Positioned(
                      left: animationOffset + (index * 150),
                      top: 50 + (index * 80) % 300,
                      child: Transform.rotate(
                        angle: _animation.value * 0.5 * math.pi + index,
                        child: Container(
                          width: 120 + (index * 20),
                          height: 120 + (index * 20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.purple.withOpacity(0.4),
                                Colors.blue.withOpacity(0.3),
                                Colors.pink.withOpacity(0.2),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  // תמונות מטושטשות נוספות - תנועה משמאל לימין
                  ...List.generate(6, (index) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final animationOffset = (_animation.value * (screenWidth + 300) - 150) * (index % 2 == 0 ? 1 : -1);
                    
                    return Positioned(
                      left: animationOffset + (index * 200),
                      top: 100 + (index * 120) % 400,
                      child: Transform.scale(
                        scale: 0.5 + (math.sin(_animation.value * 2 * math.pi + index) * 0.3),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.cyan.withOpacity(0.2),
                                Colors.pink.withOpacity(0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
        // תוכן האפליקציה
        widget.child,
      ],
    );
  }
}
