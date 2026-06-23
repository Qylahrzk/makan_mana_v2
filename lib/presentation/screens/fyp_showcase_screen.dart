import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../widgets/curved_header_painter.dart';

class FypShowcaseScreen extends StatelessWidget {
  const FypShowcaseScreen({super.key});

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 110,
      leading: Center(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
      titleSpacing: 0,
      title: const Text(
        'MakanMana Recommends',
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -0.5,
          shadows: [
            Shadow(
              offset: Offset(0, 1.5),
              blurRadius: 4.0,
              color: Colors.black26,
            ),
          ],
        ),
      ),
      flexibleSpace: Stack(
        children: [
          ClipPath(
            clipper: const HeaderCurveClipper(),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.oceanGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -1,
            left: -1,
            right: -1,
            child: CustomPaint(
              size: const Size(double.infinity, 48),
              painter: CurvedHeaderPainter.adaptive(context),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
    );
  }

  Widget _buildPipelineCard(BuildContext context) {
    final steps = [
      _PipelineStep(
        label: 'User Preferences',
        sub: 'Cuisine · Diet · Facilities · Budget · Distance',
        color: AppColors.adaptivePrimary(context),
      ),
      _PipelineStep(
        label: 'Knowledge-Based Filtering',
        sub: 'Rule-based hard & soft matching',
        color: AppColors.adaptiveSecondary(context),
      ),
      _PipelineStep(
        label: 'LDA Topic Modelling',
        sub: 'Restaurant review topic profiles',
        color: const Color(0xFF00ACC1),
      ),
      _PipelineStep(
        label: 'Hybrid Score Fusion',
        sub: 'Weighted combination + ranking',
        color: const Color(0xFF4CAF50),
      ),
      _PipelineStep(
        label: 'Explainable Recommendation',
        sub: 'Top-N with match analysis',
        color: AppColors.adaptivePrimary(context),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommendation Pipeline',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.adaptiveOnSurface(context),
            ),
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final step = entry.value;
            final isLast = idx == steps.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: step.color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 22,
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.8),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.adaptiveOnSurface(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.sub,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.adaptiveTextSecondary(context),
                          ),
                        ),
                        if (!isLast) const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShowcaseCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.adaptiveOnSurface(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.adaptiveTextSecondary(context),
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✓ ',
                    style: TextStyle(
                      color: AppColors.adaptivePrimary(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.adaptiveTextSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplainabilityCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.hub_rounded,
            color: AppColors.adaptivePrimary(context),
            size: 24,
          ),
          const SizedBox(height: 12),
          Text(
            'Why "explainable"?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.adaptiveOnSurface(context),
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.adaptiveTextSecondary(context),
              ),
              children: [
                const TextSpan(
                  text: 'Every recommendation is accompanied by a ',
                ),
                TextSpan(
                  text: 'match analysis',
                  style: TextStyle(
                    color: AppColors.adaptivePrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(
                  text:
                      ' showing the contribution of each scoring dimension, plus human-readable reasons. This transparency is what makes the system suitable for trust-critical food discovery — and what makes it presentable as an FYP deliverable.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.adaptivePrimary(context),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.smartRecommend);
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'See it in action',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 110 + 16,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.adaptiveSecondary(
                        context,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'FYP SHOWCASE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.adaptiveSecondary(context),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.adaptiveOnSurface(context),
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                      children: [
                        const TextSpan(text: 'How '),
                        TextSpan(
                          text: 'MakanMana',
                          style: TextStyle(
                            foreground: Paint()
                              ..shader =
                                  const LinearGradient(
                                    colors: AppColors.freshMakanGradient,
                                  ).createShader(
                                    const Rect.fromLTWH(0, 0, 200, 70),
                                  ),
                          ),
                        ),
                        const TextSpan(text: ' Recommends'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A look under the hood at the hybrid AI engine combining knowledge-based filtering and LDA topic modelling.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.adaptiveTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildPipelineCard(context),
                  const SizedBox(height: 16),
                  _buildShowcaseCard(
                    context: context,
                    icon: Icons.filter_alt_rounded,
                    title: 'Knowledge-Based Filtering',
                    desc:
                        'Matches restaurants against your structured preferences.',
                    color: AppColors.adaptivePrimary(context),
                    items: [
                      'Favourite cuisines',
                      'Dietary restrictions (Halal, Vegetarian, Vegan)',
                      'Facilities (Parking, WiFi, A/C)',
                      'Dining vibe (Family, Romantic, Scenic)',
                      'Budget level & maximum distance',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildShowcaseCard(
                    context: context,
                    icon: Icons.layers_rounded,
                    title: 'LDA Topic Modelling',
                    desc:
                        'Latent Dirichlet Allocation discovers hidden dining themes from thousands of restaurant reviews.',
                    color: AppColors.adaptiveSecondary(context),
                    items: [
                      'Topic 1 — Casual Dining & Variety',
                      'Topic 2 — Malay Breakfast & Local Staples',
                      'Topic 3 — Local Snacks & Specialty Bites',
                      'Each restaurant gets a topic probability vector',
                      'Similar restaurants computed via topic distance',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildShowcaseCard(
                    context: context,
                    icon: Icons.call_merge_rounded,
                    title: 'Hybrid Score Fusion',
                    desc:
                        'Combines structured matching with semantic similarity for ranked, explainable results.',
                    color: AppColors.adaptiveTertiary(context),
                    items: [
                      'Cuisine match · 28%',
                      'Topic similarity · 20%',
                      'Distance proximity · 20%',
                      'Budget alignment · 17%',
                      'Facility coverage · 15%',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildExplainabilityCard(context),
                  const SizedBox(height: 24),
                  _buildActionButton(context),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineStep {
  final String label;
  final String sub;
  final Color color;

  const _PipelineStep({
    required this.label,
    required this.sub,
    required this.color,
  });
}
