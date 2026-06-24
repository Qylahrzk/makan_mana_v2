import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import '../../core/app_utils.dart';
import '../../core/restaurant_image.dart';
import '../../data/restaurant_repository.dart';
import '../../logic/cubits/chat_cubit.dart';
import '../../logic/cubits/user_preferences_cubit.dart';
import '../../models/chat_message_model.dart';
import '../../models/restaurant_model.dart';
import 'restaurant_detail_screen.dart';
import '../widgets/premium_background.dart';
import '../widgets/gradient_divider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final prefs = context.read<UserPreferencesCubit>().current;
    context.read<ChatCubit>().sendMessage(
      trimmed,
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

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    _focusNode.unfocus();
    _sendText(text);
  }

  void _startChat(String initialMessage) {
    _sendText(initialMessage);
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
      isCrowded: p['is_crowded'] == true,
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

  static const List<(String, String)> _suggestions = [
    ('✅ Halal cafe', 'Find me a halal cafe in Terengganu'),
    ('🦞 Best seafood', 'Best seafood restaurant in Terengganu'),
    ('🕯️ Romantic dinner', 'Romantic dinner spots with scenic view'),
    ('💰 Budget Malay food', 'Budget Malay food under RM15'),
    ('👨‍👩‍👧‍👦 Family + parking', 'Family friendly restaurant with parking'),
    ('⭐ Top rated', 'Top rated restaurant in Terengganu'),
  ];

  Widget _buildWelcome() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // ── Main Heading ───────────────────────────────────────────────
          Text(
            'Makan mana rini?',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimary,
              height: 1.2,
            ),
          ),

          if (!isKeyboardOpen) ...[
            const SizedBox(height: 12),

            // ── Mascot + Speech Bubble ─────────────────────────────────
            SizedBox(
              height: 115,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: -20,
                    top: -10,
                    bottom: 0,
                    width: 180,
                    child: Image.asset(
                      'assets/images/chatbot.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 85,
                    top: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : AppColors.secondary.withValues(alpha: 0.15),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.1 : 0.04,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Hi! I'm Tutu 👋",
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "I'm your personal food recommender. Ask me anything to find your perfect spot!",
                            style: TextStyle(
                              fontFamily: 'OpenSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : Colors.grey[700],
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ── Suggestion Chips ───────────────────────────────────────
            Text(
              'QUICK START',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.35)
                    : AppColors.secondary.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 3.2,
              ),
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final (label, prompt) = _suggestions[index];
                final parts = label.split(' ');
                final emoji = parts.first;
                final text = parts.skip(1).join(' ');

                return GestureDetector(
                  onTap: () => _startChat(prompt),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.secondary.withValues(alpha: 0.1),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.08 : 0.02,
                          ),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _startChat(prompt),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'OpenSans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildStickyAppBar(BuildContext context, bool isDark) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // Logo/Icon (left)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : AppColors.secondary.withValues(alpha: 0.12),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title + Subtitle (center, expanded)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'MakanBot',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        'Free Plan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.grey[600],
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Menu Button (right)
                GestureDetector(
                  onTap: () => _showGridMenu(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.4),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.secondary.withValues(alpha: 0.12),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.grid_view_rounded,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGridMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.star_rounded,
                  color: AppColors.primary,
                ),
                title: Text(
                  'Upgrade to MakanBot+',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text('Voice chat & menu uploads'),
                onTap: () => Navigator.pop(ctx),
              ),
              GradientDivider(height: 16, thickness: 0.5),
              ListTile(
                leading: const Icon(
                  Icons.delete_sweep_rounded,
                  color: AppColors.error,
                ),
                title: Text(
                  'Clear Chat',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text('Delete conversation history'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<ChatCubit>().clearChat();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageList(List<ChatMessageModel> messages) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      itemCount: messages.length,
      itemBuilder: (_, i) => _buildMessageBubble(messages[i]),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg) {
    if (msg.isTyping) return _buildTypingState();
    final isUser = msg.isUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activePrimary = isDark ? AppColors.darkPrimary : AppColors.primary;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bot avatar (only for bot messages)
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    activeSecondary,
                    activeSecondary.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Message content
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? activePrimary
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.white.withValues(alpha: 0.7)),
                    borderRadius: BorderRadius.circular(18),
                    border: isUser
                        ? null
                        : Border.all(
                            color: activeSecondary.withValues(alpha: 0.15),
                            width: 1,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isUser ? 0.08 : 0.03,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
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
                          height: 1.4,
                          color: msg.isError
                              ? AppColors.error
                              : (isUser
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white
                                          : AppColors.textPrimary)),
                        ),
                      ),
                      if (!isUser &&
                          !msg.isError &&
                          msg.modelUsed.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildModelBadge(msg, activeSecondary),
                      ],
                    ],
                  ),
                ),

                // Timestamp (below message, aligned with bubble)
                Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    left: isUser ? 0 : 10,
                    right: isUser ? 10 : 0,
                  ),
                  child: Text(
                    msg.timeLabel,
                    style: TextStyle(
                      fontFamily: 'OpenSans',
                      fontSize: 10,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.grey[500],
                    ),
                  ),
                ),

                // Partial match banner
                if (!isUser &&
                    msg.hasPartialMatch &&
                    msg.relaxedCriteria.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildPartialMatchBanner(msg.relaxedCriteria),
                ],

                // Restaurant cards (hybrid layout)
                if (!isUser && msg.restaurants.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...msg.restaurants.take(3).map((r) {
                    final rawFilters =
                        r['matched_filters'] as List<dynamic>? ?? [];
                    final matchedFilters = rawFilters
                        .map((e) => e.toString())
                        .toList();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RestaurantCompactCard(
                        restaurant: _previewToRestaurant(r),
                        matchedFilters: matchedFilters,
                        onTap: () => _openRestaurant(r),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          if (isUser) const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildModelBadge(ChatMessageModel msg, Color activeSecondary) {
    final parts = <String>[];
    if (msg.modelUsed.isNotEmpty) parts.add('⚡ ${msg.modelUsed}');
    if (msg.searchUsed) parts.add('🔍');
    if (parts.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: activeSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activeSecondary.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        parts.join(' · '),
        style: TextStyle(
          fontFamily: 'OpenSans',
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: activeSecondary,
        ),
      ),
    );
  }

  Widget _buildPartialMatchBanner(List<String> relaxedCriteria) {
    final relaxedStr = relaxedCriteria
        .map((c) => c.replaceAll('_', ' '))
        .join(', ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 13, color: Colors.amber),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Relaxed: $relaxedStr',
              style: const TextStyle(
                fontFamily: 'OpenSans',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;

    // Extract the user's last query
    String queryText = "";
    final stateMessages = context.read<ChatCubit>().currentMessages;
    for (int idx = stateMessages.length - 1; idx >= 0; idx--) {
      if (stateMessages[idx].isUser) {
        queryText = stateMessages[idx].text;
        break;
      }
    }
    if (queryText.length > 35) {
      queryText = '${queryText.substring(0, 32)}...';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STATE 1: Searching
          if (queryText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 42, bottom: 6),
              child: _buildStatusPill(
                icon: Icons.check_circle_rounded,
                label: 'Searching',
                value: queryText,
                bgColor: const Color(0xFFECFDF5),
                borderColor: const Color(0xFFA7F3D0),
                textColor: const Color(0xFF047857),
              ),
            ),

          // STATE 2: Generating
          Padding(
            padding: const EdgeInsets.only(left: 42, bottom: 8),
            child: _buildStatusPill(
              icon: Icons.auto_awesome_rounded,
              label: 'Generating answer',
              bgColor: isDark
                  ? const Color(0xFF1F2937).withValues(alpha: 0.6)
                  : const Color(0xFFFEF3C7),
              borderColor: isDark
                  ? Colors.amber.withValues(alpha: 0.3)
                  : const Color(0xFFFCD34D),
              textColor: isDark ? Colors.amber[200]! : const Color(0xFFB45309),
            ),
          ),

          // STATE 3: Typing bubble with dots
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      activeSecondary,
                      activeSecondary.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: activeSecondary.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: const _TypingDots(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required IconData icon,
    required String label,
    String value = '',
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'OpenSans',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isChatActive, bool sending) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;

    final double bottomPad = MediaQuery.of(context).viewPadding.bottom;
    final double navBarHeight = 68.0 + (bottomPad > 0 ? bottomPad + 6 : 14);
    final double bottomPadding = isKeyboardOpen ? 8.0 : (navBarHeight + 80.0);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      focusNode: _focusNode,
                      enabled: !sending,
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sending ? null : _send(),
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: sending
                            ? 'MakanBot is searching...'
                            : 'Ask about restaurants...',
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFAAAAAA),
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  if (_textCtrl.text.isNotEmpty)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        _textCtrl.clear();
                        setState(() {});
                      },
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: sending
                        ? null
                        : (_textCtrl.text.trim().isNotEmpty
                              ? _send
                              : () {
                                  // Voice assistant action placeholder
                                }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _textCtrl.text.trim().isNotEmpty
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: sending
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: _textCtrl.text.trim().isNotEmpty
                                    ? Colors.white
                                    : AppColors.primary,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              _textCtrl.text.trim().isNotEmpty
                                  ? Icons.send_rounded
                                  : Icons.mic_rounded,
                              size: 18,
                              color: _textCtrl.text.trim().isNotEmpty
                                  ? Colors.white
                                  : AppColors.primary,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return BlocConsumer<ChatCubit, ChatState>(
      listener: (context, state) {
        if (state is! ChatInitial) {
          _scrollToBottom();
        }
      },
      builder: (context, state) {
        final messages = switch (state) {
          ChatLoaded() => state.messages,
          ChatSending() => state.messages,
          ChatError() => state.messages,
          _ => <ChatMessageModel>[],
        };
        final bool isChatActive = messages.isNotEmpty;
        final bool sending = state is ChatSending;

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          resizeToAvoidBottomInset: true,
          appBar: _buildStickyAppBar(context, isDark),
          body: PremiumGradientBackground(
            style: 'soft',
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: isChatActive
                        ? _buildMessageList(messages)
                        : _buildWelcome(),
                  ),
                  _buildInputBar(isChatActive, sending),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final activeSecondary = isDark
              ? AppColors.darkSecondary
              : AppColors.secondary;
          final t = (_ctrl.value + i / 3.0) % 1.0;
          final opacity = t < 0.5
              ? 0.3 + (t / 0.5) * 0.7
              : 1.0 - ((t - 0.5) / 0.5) * 0.7;
          return Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: activeSecondary.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}

class SpeechBubblePainter extends CustomPainter {
  final Color bgColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double tailWidth;
  final double tailHeight;
  final bool isDark;
  final bool isTailOnLeft;

  SpeechBubblePainter({
    required this.bgColor,
    required this.borderColor,
    this.borderWidth = 1.5,
    this.borderRadius = 16,
    this.tailWidth = 10,
    this.tailHeight = 12,
    required this.isDark,
    this.isTailOnLeft = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final double w = size.width;
    final double h = size.height;
    final double tailCenterY = h * 0.45;

    if (isTailOnLeft) {
      path.moveTo(tailWidth + borderRadius, 0);
      path.lineTo(w - borderRadius, 0);
      path.arcToPoint(
        Offset(w, borderRadius),
        radius: Radius.circular(borderRadius),
        clockwise: true,
      );
      path.lineTo(w, h - borderRadius);
      path.arcToPoint(
        Offset(w - borderRadius, h),
        radius: Radius.circular(borderRadius),
        clockwise: true,
      );
      path.lineTo(tailWidth + borderRadius, h);
      path.arcToPoint(
        Offset(tailWidth, h - borderRadius),
        radius: Radius.circular(borderRadius),
        clockwise: true,
      );
      path.lineTo(tailWidth, tailCenterY + tailHeight / 2);
      path.lineTo(0, tailCenterY);
      path.lineTo(tailWidth, tailCenterY - tailHeight / 2);
      path.lineTo(tailWidth, borderRadius);
      path.arcToPoint(
        Offset(tailWidth + borderRadius, 0),
        radius: Radius.circular(borderRadius),
        clockwise: true,
      );
    } else {
      path.moveTo(borderRadius, 0);
      path.lineTo(w - tailWidth - borderRadius, 0);
      path.arcToPoint(
        Offset(w - tailWidth, borderRadius),
        radius: Radius.circular(borderRadius),
        clockwise: true,
      );
      path.lineTo(w - tailWidth, tailCenterY - tailHeight / 2);
      path.lineTo(w, tailCenterY);
      path.lineTo(w - tailWidth, tailCenterY + tailHeight / 2);
      path.lineTo(w - tailWidth, h - borderRadius);
      path.arcToPoint(
        Offset(w - tailWidth - borderRadius, h),
        radius: Radius.circular(borderRadius),
        clockwise: true,
      );
      path.lineTo(borderRadius, h);
      path.arcToPoint(
        Offset(0, h - borderRadius),
        radius: Radius.circular(borderRadius),
        clockwise: true,
      );
      path.lineTo(0, borderRadius);
      path.arcToPoint(
        Offset(borderRadius, 0),
        radius: Radius.circular(borderRadius),
        clockwise: true,
      );
    }
    path.close();

    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
      6.0,
      true,
    );

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant SpeechBubblePainter oldDelegate) {
    return oldDelegate.bgColor != bgColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isTailOnLeft != isTailOnLeft;
  }
}

class VoiceAssistantOverlay extends StatefulWidget {
  const VoiceAssistantOverlay({super.key});

  @override
  State<VoiceAssistantOverlay> createState() => _VoiceAssistantOverlayState();
}

class _VoiceAssistantOverlayState extends State<VoiceAssistantOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _waveController;
  String _statusText = "Listening...";
  String _transcribedText = "";
  bool _isThinking = false;
  bool _isCompleted = false;

  final String _simulatedInput =
      "Show me the best seafood restaurant near the beach";

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _startSimulation();
  }

  void _startSimulation() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || _isCompleted) return;

    setState(() {
      _statusText = "Transcribing...";
    });

    for (int i = 1; i <= _simulatedInput.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted || _isCompleted) return;
      setState(() {
        _transcribedText = _simulatedInput.substring(0, i);
      });
    }

    if (!mounted || _isCompleted) return;

    setState(() {
      _isThinking = true;
      _statusText = "Thinking...";
    });

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || _isCompleted) return;

    _submitQuery(_simulatedInput);
  }

  void _submitQuery(String text) {
    if (_isCompleted) return;
    _isCompleted = true;
    Navigator.pop(context, text);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;
    final activePrimary = isDark ? AppColors.darkPrimary : AppColors.primary;

    return Scaffold(
      // Use AppColors for overlay background
      backgroundColor: isDark
          ? AppColors.darkBackground.withValues(alpha: 0.95)
          : AppColors.background.withValues(alpha: 0.95),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 10,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                  Text(
                    'Voice Assistant',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AIAura(size: 200, isRapid: _isThinking),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _isThinking
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : activeSecondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusText.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: _isThinking
                            ? AppColors.primary
                            : activeSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _transcribedText.isEmpty
                          ? "Say something..."
                          : _transcribedText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: _transcribedText.isEmpty
                            ? (isDark ? Colors.white30 : Colors.grey[400])
                            : (isDark ? Colors.white : AppColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 40,
              left: 32,
              right: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                      child: Icon(
                        Icons.keyboard_rounded,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_transcribedText.isNotEmpty) {
                        _submitQuery(_transcribedText);
                      } else {
                        _submitQuery(_simulatedInput);
                      }
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!_isThinking)
                          ...List.generate(2, (index) {
                            final delay = index * 0.5;
                            return AnimatedBuilder(
                              animation: _waveController,
                              builder: (context, child) {
                                final val =
                                    (_waveController.value + delay) % 1.0;
                                final scale = 1.0 + (val * 1.2);
                                final opacity = (1.0 - val) * 0.4;
                                return Transform.scale(
                                  scale: scale,
                                  child: Opacity(
                                    opacity: opacity,
                                    child: Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: activePrimary.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }),
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: AppColors.freshMakanGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: activePrimary.withValues(alpha: 0.35),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isThinking
                                ? Icons.auto_awesome_rounded
                                : Icons.mic_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AIAura extends StatefulWidget {
  final double size;
  final bool isRapid;
  const AIAura({super.key, this.size = 180, this.isRapid = false});

  @override
  State<AIAura> createState() => _AIAuraState();
}

class _AIAuraState extends State<AIAura> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isRapid ? 1200 : 2000),
    )..repeat();

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant AIAura oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRapid != widget.isRapid) {
      _pulseController.duration = Duration(
        milliseconds: widget.isRapid ? 1200 : 2000,
      );
      _pulseController.repeat();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoGradients = AppColors.logoGradient;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(3, (index) {
            final delayFraction = index / 3.0;
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final progress = (_pulseController.value + delayFraction) % 1.0;
                final scale = 1.0 + (progress * 0.7);
                final opacity = (1.0 - progress) * 0.35;

                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: widget.size * 0.8,
                      height: widget.size * 0.8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(colors: logoGradients),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          RotationTransition(
            turns: _rotateController,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse =
                    1.0 +
                    (widget.isRapid
                        ? (sin(_pulseController.value * 2 * pi) * 0.05)
                        : (sin(_pulseController.value * 2 * pi) * 0.03));
                return Transform.scale(
                  scale: pulse,
                  child: Container(
                    width: widget.size * 0.8,
                    height: widget.size * 0.8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(colors: logoGradients),
                      boxShadow: [
                        BoxShadow(
                          color: logoGradients[0].withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                        BoxShadow(
                          color: logoGradients[2].withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            width: widget.size * 0.65,
            height: widget.size * 0.65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
          ),
          Container(
            width: widget.size * 0.5,
            height: widget.size * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Image.asset(
              'assets/images/main_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantCompactCard extends StatelessWidget {
  final Restaurant restaurant;
  final List<String> matchedFilters;
  final VoidCallback onTap;

  const _RestaurantCompactCard({
    required this.restaurant,
    required this.matchedFilters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;

    final mainCuisine = restaurant.cuisineTypes.isNotEmpty
        ? restaurant.cuisineTypes.first
        : 'Other';
    final imageUrl = RestaurantImage.getUrl(mainCuisine, seed: restaurant.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: activeSecondary.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // Left Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 72,
                  height: 72,
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05),
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 72,
                  height: 72,
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    size: 24,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Middle Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 12, color: AppColors.star),
                      const SizedBox(width: 4),
                      Text(
                        AppUtils.formatRating(restaurant.rating),
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      if (restaurant.isHalal) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
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
                              fontSize: 8,
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: activeSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restaurant.municipality,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 11,
                            color: activeSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right Arrow
            Icon(
              Icons.chevron_right_rounded,
              color: activeSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
