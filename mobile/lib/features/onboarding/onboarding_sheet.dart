import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/dusol_ui.dart';

class OnboardingSheet extends StatefulWidget {
  const OnboardingSheet({super.key});

  static const preferenceKey = 'sig_sols_onboarding_done';

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  final _controller = PageController();
  var _page = 0;

  static const _pages = [
    (
      icon: Icons.map_outlined,
      title: 'Explorez les sols',
      body:
          'Visualisez les points de sol, les parcelles et les couches satellites du Togo.',
    ),
    (
      icon: Icons.layers_outlined,
      title: 'Analysez sur la carte',
      body:
          'Heatmap pH, trajectoire et proximité — directement sur la carte interactive.',
    ),
    (
      icon: Icons.draw_outlined,
      title: 'Dessinez une parcelle',
      body:
          'Tracez votre zone puis lancez une analyse Sentinel, météo et fertilité.',
    ),
  ];

  Future<void> _finish() async {
    await (await SharedPreferences.getInstance()).setBool(
      OnboardingSheet.preferenceKey,
      true,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SizedBox(
          height: 420,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Passer'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (_, index) {
                    final page = _pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.heroGradient,
                            border: Border.all(
                              color: AppTheme.gold500.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: Icon(page.icon, size: 48, color: AppTheme.gold300),
                        ).dusolPop(),
                        const SizedBox(height: 28),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                children: [
                  ...List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: AppMotion.fast,
                      width: index == _page ? 22 : 8,
                      height: 8,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: index == _page
                            ? AppTheme.gold500
                            : AppTheme.gold500.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _page == _pages.length - 1
                        ? _finish
                        : () => _controller.nextPage(
                              duration: AppMotion.normal,
                              curve: AppMotion.easeOut,
                            ),
                    child: Text(
                      _page == _pages.length - 1 ? 'Commencer' : 'Suivant',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
