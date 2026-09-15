import 'package:flutter/material.dart';

import '../../theme/palettes.dart';
import '../app_scope.dart';
import '../widgets/progress_ring.dart';

/// شاشة البداية.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[palette.gradient.first, palette.gradient.last],
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ScaleTransition(
                scale: CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    shape: BoxShape.circle,
                  ),
                  child: const AppLogomark(size: 92, color: Colors.white),
                ),
              ),
              const SizedBox(height: 26),
              FadeTransition(
                opacity: _controller,
                child: Text(
                  context.tr('app.name'),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontFamily: 'ReadexPro',
                      ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _controller,
                child: Text(
                  context.tr('app.tagline'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withAlpha(220)),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withAlpha(220)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
