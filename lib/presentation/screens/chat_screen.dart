// ============================================================
// FILE: lib/presentation/screens/chat_screen.dart
//
// Changes vs previous version:
//  1. ChatMessage now stores restaurants list from API response
//  2. AI bubble renders restaurant mini-cards below the reply text
//     (tappable → RestaurantDetailScreen via repo lookup)
//  3. Markdown-like formatting (bold names) rendered cleanly
//  4. FIX: Safe parsing for cuisine_type (handles both String and List)
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
    ('Recommend halal cafe', 'Find me a halal cafe in Terengganu'),
    ('Best seafood restaurant', 'Best seafood restaurant in Terengganu'),
    ('Romantic dinner spots', 'Romantic dinner spots with scenic view'),
    ('Budget Malay food', 'Budget Malay food under RM15'),
    (
      'Family friendly with parking',
      'Family-friendly restaurants with parking',
    ),
    ('Top rated restaurants', 'What are the highest rated restaurants?'),
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

  // ── Open restaurant detail screen ─────────────────────────────────────────
  // Looks up the full Restaurant object from the repo so the detail screen
  // has LDA topic data, coordinates, etc.
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

  // Minimal Restaurant from the chat preview dict (fallback)
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
      isRomantic: false,
      hasScenicView: false,
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

  // ── BUILD ──────────────────────────────────────────────────────────────────

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
      appBar: _buildAppBar(),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 16,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Food Assistant',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                'Powered by Gemini + LDA',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        BlocBuilder<ChatCubit, ChatState>(
          builder: (context, state) {
            if (state is ChatInitial) return const SizedBox();
            return GestureDetector(
              onTap: _showClearDialog,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                  ),
                ),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          color: Theme.of(context).colorScheme.surfaceContainer,
        ),
      ),
    );
  }

  // ── Welcome screen ────────────────────────────────────────────────────────

  Widget _buildWelcome() {
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.restaurant_rounded,
              size: 30,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ask me anything',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'about Terengganu restaurants',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'I know ~990 restaurants in the dataset. Ask for recommendations, '
            'halal options, scenic spots, and more.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
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
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.2),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          activePrefs.join(' · '),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondary.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'My answers will match these automatically.',
                          style: TextStyle(
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

          const SizedBox(height: 24),
          Text(
            'Try asking:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((s) {
              final (label, prompt) = s;
              return GestureDetector(
                onTap: () => _sendText(prompt),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 13,
                        color: AppColors.primary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────

  Widget _buildMessageList(List<ChatMessageModel> messages) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: messages.length,
      itemBuilder: (_, i) => _buildBubble(messages[i]),
    );
  }

  // ── Single bubble ─────────────────────────────────────────────────────────

  Widget _buildBubble(ChatMessageModel msg) {
    if (msg.isTyping) return _buildTypingBubble();
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: AppColors.primary,
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
                // ── Text bubble ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primary
                        : msg.isError
                        ? Colors.red.withValues(alpha: 0.08)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: !isUser
                        ? Border.all(
                            color: msg.isError
                                ? Colors.red.withValues(alpha: 0.25)
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                          )
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.isError
                            ? '${msg.text}\n\nPlease try again.'
                            : msg.text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: isUser
                              ? Colors.white
                              : msg.isError
                              ? Colors.red[700]
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        msg.timeLabel,
                        style: TextStyle(
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

                // ── Restaurant mini-cards (AI messages only) ──────────
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

  // ── Typing bubble ─────────────────────────────────────────────────────────

  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                color: Theme.of(context).colorScheme.surfaceContainer,
              ),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        final sending = state is ChatSending;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.surfaceContainer,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          focusNode: _focusNode,
                          enabled: !sending,
                          maxLines: 4,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => sending ? null : _send(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: sending
                                ? 'AI is thinking...'
                                : 'Ask about restaurants...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.38),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: sending ? null : _send,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: sending
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.primary,
                    shape: BoxShape.circle,
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
                          size: 18,
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
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'All messages will be deleted.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
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
            child: Text(
              'Clear',
              style: TextStyle(
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
// Shown below an AI reply bubble when the API returns restaurant suggestions.
// Tapping opens the full RestaurantDetailScreen.

class _RestaurantMiniCard extends StatelessWidget {
  final Map<String, dynamic> preview;
  final VoidCallback onTap;

  const _RestaurantMiniCard({required this.preview, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = preview['name'] as String? ?? '';
    final rating = (preview['rating'] as num?)?.toDouble() ?? 0.0;

    // SAFE PARSING FOR CUISINE (Handles both String and List<dynamic>)
    String cuisine = '';
    final rawCuisine = preview['cuisine_type'];
    if (rawCuisine is List) {
      cuisine = rawCuisine.join(', ');
    } else if (rawCuisine is String) {
      cuisine = rawCuisine;
    }

    final location = preview['municipality'] as String? ?? '';
    final isHalal = preview['is_halal'] == true;
    final price = preview['price_level'] as int?;

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
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cuisine icon container
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _cuisineEmoji(cuisine),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
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
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 12, color: AppColors.star),
                      const SizedBox(width: 2),
                      Text(
                        AppUtils.formatRating(rating),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (isHalal) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Halal',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (priceStr.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(priceStr, style: const TextStyle(fontSize: 9)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: AppColors.primary.withValues(alpha: 0.5),
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

// ─── Typing Dots ──────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
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
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}
