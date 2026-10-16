// lib/widgets/video_brand_background.dart
// Vidéo en boucle (muette) en arrière-plan, avec un voile bleu VelQix pour que
// le texte blanc reste lisible. Tant que la vidéo n'est pas prête (ou si elle
// ne peut pas être lue), un fond bleu dégradé VelQix reste affiché.

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';

class VideoBrandBackground extends StatefulWidget {
  final Widget child;
  final String asset;
  const VideoBrandBackground({
    super.key,
    required this.child,
    this.asset = 'assets/videos/login_bg.mp4',
  });

  @override
  State<VideoBrandBackground> createState() => _VideoBrandBackgroundState();
}

class _VideoBrandBackgroundState extends State<VideoBrandBackground> {
  VideoPlayerController? _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.asset(
        widget.asset,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _c = c;
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0); // obligatoire pour l'autoplay sur navigateur
      if (!mounted) return;
      setState(() => _ready = true);
      // Respecte « réduire les animations » : image fixe au lieu de la lecture
      if (!MediaQuery.of(context).disableAnimations) await c.play();
    } catch (e) {
      debugPrint('Vidéo de fond indisponible : $e');
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Repli : dégradé bleu (visible pendant le chargement ou en cas d'erreur)
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
          child: SizedBox.expand(),
        ),

        // Vidéo plein cadre (recadrée comme « cover »), en fondu à l'apparition
        if (c != null)
          AnimatedOpacity(
            opacity: _ready ? 1 : 0,
            duration: const Duration(milliseconds: 600),
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _ready ? c.value.size.width : 1,
                  height: _ready ? c.value.size.height : 1,
                  child: VideoPlayer(c),
                ),
              ),
            ),
          ),

        // Voile bleu : la vidéo est très claire, le texte blanc doit rester lisible
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryDark.withOpacity(0.82),
                AppTheme.primary.withOpacity(0.62),
                AppTheme.primaryLight.withOpacity(0.50),
              ],
            ),
          ),
        ),

        widget.child,
      ],
    );
  }
}
