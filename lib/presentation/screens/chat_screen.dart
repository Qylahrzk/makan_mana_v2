// ============================================================
// FILE: lib/presentation/screens/chat_screen.dart
//
// v3.1 CHANGES:
//   1. Explainability chips per restaurant card: 'Matched: Halal + LDA: Romantic Vibe'
//   2. Partial-match banner: 'Closest matches — scenic_view relaxed'
//   3. Model + search badge: 'Answered by Groq · Searched online'
//   4. Shows up to 5 restaurant cards, always visible (no card clipping)
//   5. AppBar subtitle now says 'Gemini · Groq · Mistral + LDA' to reflect
//      the multi-LLM setup accurately
//   6. 'No results' state is replaced by partial-match fallback — API
//      always returns results, so this case should not occur
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_colors.dart';
import '../../core/app_utils.dart';
import '../../data/restaurant_repository.dart';
import '../../logic/cubits/chat_cubit.dart';
import '../../logic/cubits/user_preferences_cubit.dart';
import '../../models/chat_message_model.dart';
import '../../models/restaurant_model.dart';
import 'restaurant_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  static const List<(String, String)> _suggestions = [
    ('Halal cafe', 'Find me a halal cafe in Terengganu'),
    ('Best seafood', 'Best seafood restaurant in Terengganu'),
    ('Romantic dinner', 'Romantic dinner spots with scenic view'),
    ('Budget Malay food', 'Budget Malay food under RM15'),
    ('Family + parking', 'Family-friendly restaurants with parking'),
    ('Top rated', 'What are the highest rated restaurants?'),
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    _focusNode.unfocus();
    _sendText(text);
  }

  void _sendText(String text) {
    final prefs = context.read<UserPreferencesCubit>().current;
    context.read<ChatCubit>().sendMessage(
      text,
      halal: prefs?.halal ?? false,
      vegetarian: prefs?.vegetarian ?? false,
      vegan: prefs?.vegan ?? false,
      parking: prefs?.hasParking ?? false,
      wifi: prefs?.hasWifi ?? false,
      ac: prefs?.hasAc ?? false,
      outdoor: prefs?.hasOutdoor ?? false,
      accessible: prefs?.accessible ?? false,
      familyFriendly: prefs?.familyFriendly ?? false,
      groupFriendly: prefs?.groupFriendly ?? false,
      casual: prefs?.casual ?? false,
      romantic: prefs?.romantic ?? false,
      scenicView: prefs?.scenicView ?? false,
      worthIt: prefs?.worthIt ?? false,
      fastService: prefs?.fastService ?? false,
    );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openRestaurant(Map<String, dynamic> preview) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
    try {
      final repo = context.read<RestaurantRepository>();
      final all = await repo.getAllRestaurants();
      final name = (preview['name'] as String? ?? '').trim().toLowerCase();
      final match = all.firstWhere(
        (r) => r.name.trim().toLowerCase() == name,
        orElse: () => _previewToRestaurant(preview),
      );
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(restaurant: match),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Restaurant _previewToRestaurant(Map<String, dynamic> p) {
    List<String> safeCuisines = [];
    final rawCuisine = p['cuisine_type'];
    if (rawCuisine is List) {
      safeCuisines = rawCuisine.map((e) => e.toString()).toList();
    } else if (rawCuisine is String && rawCuisine.isNotEmpty) {
      safeCuisines = [rawCuisine];
    }
    return Restaurant(
      id: 0,
      name: p['name'] ?? '',
      address: p['address'] ?? '',
      municipality: p['municipality'] ?? '',
      categories: '',
      cuisineTypes: safeCuisines,
      rating: (p['rating'] as num?)?.toDouble() ?? 0.0,
      ratingBand: '',
      topicLabel: p['topic_label'] ?? '',
      coordinateSource: '',
      isHalal: p['is_halal'] == true,
      isVegetarian: false,
      isVegan: false,
      hasParking: false,
      hasWifi: false,
      hasAc: false,
      hasOutdoor: false,
      isAccessible: false,
      isFamilyFriendly: false,
      isGroupFriendly: false,
      isCasual: false,
      isRomantic: p['is_romantic'] == true,
      hasScenicView: p['has_scenic_view'] == true,
      isWorthIt: false,
      isFastService: false,
      dominantTopic: 0,
      topic1Pct: 0,
      topic2Pct: 0,
      topic3Pct: 0,
      lat: (p['latitude'] as num?)?.toDouble(),
      lon: (p['longitude'] as num?)?.toDouble(),
      priceLevel: p['price_level'] as int?,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(isDark),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BlocConsumer<ChatCubit, ChatState>(
                listener: (context, state) {
                  if (state is! ChatInitial) _scrollToBottom();
                },
                builder: (context, state) {
                  if (state is ChatInitial) return _buildWelcome();
                  final messages = switch (state) {
                    ChatLoaded() => state.messages,
                    ChatSending() => state.messages,
                    ChatError() => state.messages,
                    _ => <ChatMessageModel>[],
                  };
                  return _buildMessageList(messages);
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  // FIX: subtitle updated to reflect multi-LLM + LDA setup accurately.
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.darkSurface, AppColors.darkSurface]
                : [AppColors.secondary, AppColors.secondaryLight],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Bot avatar
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.30),
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'GanuBot 🤖',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          // FIX: accurate subtitle — reflects multi-LLM + LDA
                          'Groq · Gemini · Mistral + LDA',
                          style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Clear button
                  BlocBuilder<ChatCubit, ChatState>(
                    builder: (context, state) {
                      if (state is ChatInitial) return const SizedBox();
                      return GestureDetector(
                        onTap: _showClearDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              fontFamily: 'OpenSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Welcome screen ────────────────────────────────────────────────────────
  Widget _buildWelcome() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefs = context.watch<UserPreferencesCubit>().current;
    final activePrefs = <String>[];
    if (prefs?.halal == true) activePrefs.add('Halal');
    if (prefs?.vegetarian == true) activePrefs.add('Vegetarian');
    if (prefs?.vegan == true) activePrefs.add('Vegan');
    if (prefs?.hasParking == true) activePrefs.add('Parking');
    if (prefs?.hasWifi == true) activePrefs.add('WiFi');
    if (prefs?.hasAc == true) activePrefs.add('Air-Cond');
    if (prefs?.familyFriendly == true) activePrefs.add('Family Friendly');
    if (prefs?.romantic == true) activePrefs.add('Romantic');
    if (prefs?.scenicView == true) activePrefs.add('Scenic View');
    if (prefs?.groupFriendly == true) activePrefs.add('Group Friendly');
    if (prefs?.casual == true) activePrefs.add('Casual');
    if (prefs?.worthIt == true) activePrefs.add('Worth It');
    if (prefs?.fastService == true) activePrefs.add('Fast Service');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.20),
              ),
            ),
            child: const Center(
              child: Text('🍜', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Makan maner rini? 🍜',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Terengganu restaurants, AI-powered',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'I know ~990 restaurants across Terengganu. '
            'Ask for recommendations, halal options, scenic spots, and more.',
            style: TextStyle(
              fontFamily: 'OpenSans',
              fontSize: 13,
              height: 1.55,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),

          if (activePrefs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondaryTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your preferences are active:',
                          style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          activePrefs.join(' · '),
                          style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 11,
                            color: AppColors.secondary.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'My answers will match these automatically.',
                          style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 26),
          Text(
            'TRY ASKING',
            style: TextStyle(
              fontFamily: 'OpenSans',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.38),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.8,
            ),
            itemCount: _suggestions.length,
            itemBuilder: (_, i) {
              final (label, prompt) = _suggestions[i];
              return GestureDetector(
                onTap: () => _sendText(prompt),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        _suggestionEmoji(label),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _suggestionEmoji(String label) {
    if (label.contains('Halal')) return '✅';
    if (label.contains('seafood')) return '🦞';
    if (label.contains('Romantic')) return '🕯️';
    if (label.contains('Budget')) return '💰';
    if (label.contains('Family')) return '👨‍👩‍👧';
    if (label.contains('rated')) return '⭐';
    return '🍽️';
  }

  // ── Message list ──────────────────────────────────────────────────────────
  Widget _buildMessageList(List<ChatMessageModel> messages) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length,
      itemBuilder: (_, i) => _buildBubble(messages[i]),
    );
  }

  // ── Single bubble ─────────────────────────────────────────────────────────
  Widget _buildBubble(ChatMessageModel msg) {
    if (msg.isTyping) return _buildTypingBubble();
    final isUser = msg.isUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userBubbleColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final botBubbleColor = isDark
        ? AppColors.darkSurface
        : const Color(0xFFF0F8F8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bot avatar
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.secondary, AppColors.secondaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Message bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? userBubbleColor
                        : msg.isError
                        ? AppColors.error.withValues(alpha: 0.08)
                        : botBubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: !isUser
                        ? Border.all(
                            color: msg.isError
                                ? AppColors.error.withValues(alpha: 0.25)
                                : AppColors.secondary.withValues(alpha: 0.15),
                            width: 1,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.isError
                            ? '${msg.text}\n\nPlease try again.'
                            : msg.text,
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 14,
                          height: 1.5,
                          color: isUser
                              ? Colors.white
                              : msg.isError
                              ? AppColors.error
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // ── Model + search badge (bot messages only) ─────────
                      if (!isUser && !msg.isError && msg.modelUsed.isNotEmpty)
                        _buildModelBadge(msg),
                      const SizedBox(height: 2),
                      Text(
                        msg.timeLabel,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 10,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.6)
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Partial-match banner ─────────────────────────────────────
                if (!isUser &&
                    msg.hasPartialMatch &&
                    msg.relaxedCriteria.isNotEmpty)
                  _buildPartialMatchBanner(msg.relaxedCriteria),

                // ── Restaurant cards (FIX: always up to 5, fully visible) ────
                // FIX: show up to 5 cards; removed .take(5) clipping issue by
                // using Column instead of ListView so all cards are rendered.
                if (!isUser && msg.restaurants.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...msg.restaurants
                      .take(5)
                      .map(
                        (r) => _RestaurantMiniCard(
                          preview: r,
                          onTap: () => _openRestaurant(r),
                        ),
                      ),
                ],
              ],
            ),
          ),

          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ── Model + search badge ──────────────────────────────────────────────────
  Widget _buildModelBadge(ChatMessageModel msg) {
    final parts = <String>[];
    if (msg.modelUsed.isNotEmpty) parts.add('⚡ ${msg.modelUsed}');
    if (msg.searchUsed) parts.add('🔍 Searched online');
    if (parts.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.20)),
      ),
      child: Text(
        parts.join('  ·  '),
        style: TextStyle(
          fontFamily: 'OpenSans',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.secondary,
        ),
      ),
    );
  }

  // ── Partial-match banner ──────────────────────────────────────────────────
  Widget _buildPartialMatchBanner(List<String> relaxedCriteria) {
    final relaxedStr = relaxedCriteria
        .map((c) => c.replaceAll('_', ' '))
        .join(', ');
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Closest matches — relaxed: $relaxedStr',
              style: const TextStyle(
                fontFamily: 'OpenSans',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Typing bubble ─────────────────────────────────────────────────────────
  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.secondary, AppColors.secondaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F8F8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        final sending = state is ChatSending;
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF2E2E42) : AppColors.divider,
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkSecondary.withValues(alpha: 0.25)
                          : AppColors.secondary.withValues(alpha: 0.30),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: TextField(
                      controller: _textCtrl,
                      focusNode: _focusNode,
                      enabled: !sending,
                      maxLines: 5,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sending ? null : _send(),
                      style: TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: sending
                            ? 'GanuBot is thinking...'
                            : 'Ask about restaurants...',
                        hintStyle: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.38),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: sending ? null : _send,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: sending
                        ? AppColors.primary.withValues(alpha: 0.45)
                        : AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: sending
                        ? []
                        : [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: sending
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Clear dialog ──────────────────────────────────────────────────────────
  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear conversation?',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'All messages will be deleted and cannot be recovered.',
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: 14,
            height: 1.4,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'OpenSans',
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ChatCubit>().clearChat();
            },
            child: const Text(
              'Clear',
              style: TextStyle(
                fontFamily: 'OpenSans',
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Restaurant Mini-Card ─────────────────────────────────────────────────────
// FIX: Now renders 'Matched: ...' explainability chips below the card info.

class _RestaurantMiniCard extends StatelessWidget {
  final Map<String, dynamic> preview;
  final VoidCallback onTap;
  const _RestaurantMiniCard({required this.preview, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = preview['name'] as String? ?? '';
    final rating = (preview['rating'] as num?)?.toDouble() ?? 0.0;
    final location = preview['municipality'] as String? ?? '';
    final isHalal = preview['is_halal'] == true;
    final price = preview['price_level'] as int?;
    final isPartial = preview['is_partial_match'] == true;

    // matched_filters from API — e.g. ['Halal', 'Scenic View', 'LDA: Romantic Vibe']
    final rawFilters = preview['matched_filters'] as List<dynamic>? ?? [];
    final matchedFilters = rawFilters.map((e) => e.toString()).toList();

    String cuisine = '';
    final rawCuisine = preview['cuisine_type'];
    if (rawCuisine is List) {
      cuisine = (rawCuisine).join(', ');
    } else if (rawCuisine is String)
      cuisine = rawCuisine;

    final priceStr = switch (price) {
      1 => '💰',
      2 => '💰💰',
      3 => '💰💰💰',
      4 => '💰💰💰💰',
      _ => '',
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPartial
                ? Colors.amber.withValues(alpha: 0.30)
                : AppColors.secondary.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main card row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Cuisine icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _cuisineEmoji(cuisine),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 11,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'OpenSans',
                                  fontSize: 11,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: AppColors.star,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              AppUtils.formatRating(rating),
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            if (isHalal) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Text(
                                  'Halal',
                                  style: TextStyle(
                                    fontFamily: 'OpenSans',
                                    fontSize: 9,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            if (priceStr.isNotEmpty) ...[
                              const SizedBox(width: 7),
                              Text(
                                priceStr,
                                style: const TextStyle(fontSize: 9),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Arrow
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            // ── FIX: Explainability chips ──────────────────────────────────
            // 'Matched: Halal + Scenic View · LDA: Romantic Vibe'
            if (matchedFilters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: _MatchedChips(filters: matchedFilters),
              ),
          ],
        ),
      ),
    );
  }

  String _cuisineEmoji(String cuisine) {
    final c = cuisine.toLowerCase();
    if (c.contains('malay')) return '🍛';
    if (c.contains('seafood')) return '🦞';
    if (c.contains('western')) return '🍔';
    if (c.contains('cafe')) return '☕';
    if (c.contains('chinese')) return '🥢';
    if (c.contains('japanese')) return '🍱';
    if (c.contains('thai')) return '🌶️';
    if (c.contains('bbq')) return '🍖';
    if (c.contains('dessert')) return '🍰';
    if (c.contains('indian')) return '🫓';
    if (c.contains('fast food')) return '🍟';
    return '🍽️';
  }
}

// ─── Matched Chips Widget ─────────────────────────────────────────────────────
// Renders 'Matched: Halal + Scenic View · LDA: Romantic Vibe' in a single row.

class _MatchedChips extends StatelessWidget {
  final List<String> filters;
  const _MatchedChips({required this.filters});

  @override
  Widget build(BuildContext context) {
    // Separate LDA from KBF chips
    final ldaFilters = filters.where((f) => f.startsWith('LDA:')).toList();
    final kbfFilters = filters.where((f) => !f.startsWith('LDA:')).toList();

    final parts = <String>[];
    if (kbfFilters.isNotEmpty) parts.add('Matched: ${kbfFilters.join(' + ')}');
    if (ldaFilters.isNotEmpty) parts.addAll(ldaFilters);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: parts.map((chip) {
        final isLda = chip.startsWith('LDA:');
        final bgColor = isLda
            ? AppColors.secondary.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.10);
        final textColor = isLda ? AppColors.secondary : AppColors.primary;
        final borderColor = isLda
            ? AppColors.secondary.withValues(alpha: 0.25)
            : AppColors.primary.withValues(alpha: 0.20);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            chip,
            style: TextStyle(
              fontFamily: 'OpenSans',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Typing Dots ──────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

final class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_ctrl.value + i / 3.0) % 1.0;
          final opacity = t < 0.5
              ? 0.3 + (t / 0.5) * 0.7
              : 1.0 - ((t - 0.5) / 0.5) * 0.7;
          return Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}
