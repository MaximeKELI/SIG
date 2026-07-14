import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          'Chargez la heatmap pH, votre trajectoire et les résultats de proximité directement sur la carte.',
    ),
    (
      icon: Icons.draw_outlined,
      title: 'Dessinez une parcelle',
      body:
          'Touchez la carte pour dessiner votre zone puis lancez une analyse Sentinel, météo et fertilité.',
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
          height: 390,
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
                        Icon(
                          page.icon,
                          size: 88,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          page.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(page.body, textAlign: TextAlign.center),
                      ],
                    );
                  },
                ),
              ),
              Row(
                children: [
                  ...List.generate(
                    _pages.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color:
                            index == _page
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed:
                        _page == _pages.length - 1
                            ? _finish
                            : () => _controller.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
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
