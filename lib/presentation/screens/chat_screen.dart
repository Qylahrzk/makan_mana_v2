// ============================================================
// FILE: lib/presentation/screens/chat_screen.dart
//
// UPDATED: Warm peachy gradient background + improved styling
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_colors.dart';
import '../../core/nav_tab_proxy.dart';
import '../../core/app_utils.dart';
import '../../data/restaurant_repository.dart';
import '../../logic/cubits/chat_cubit.dart';
import '../../logic/cubits/user_preferences_cubit.dart';
import '../../models/chat_message_model.dart';
import '../../models/restaurant_model.dart';
import 'restaurant_detail_screen.dart';
import '../widgets/premium_background.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startChat(BuildContext context, String initialMessage) {
    final text = initialMessage.trim();
    if (text.isEmpty) return;

    _textCtrl.clear();
    _focusNode.unfocus();

    // Reset ChatCubit
    context.read<ChatCubit>().clearChat();

    // Push the active chat screen fullscreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveConversationScreen(initialMessage: text),
      ),
    ).then((_) {
      // Reset ChatCubit on return to tab
      if (context.mounted) {
        context.read<ChatCubit>().clearChat();
      }
    });
  }

  void _send() {
    _startChat(context, _textCtrl.text);
  }

  static const List<(String, String)> _suggestions = [
    ('✅ Halal cafe', 'Find me a halal cafe in Terengganu'),
    ('🦞 Best seafood', 'Best seafood restaurant in Terengganu'),
    ('🕯️ Romantic spots', 'Romantic dinner spots with scenic view'),
    ('💰 Budget eats', 'Budget Malay food under RM15'),
  ];

  Widget _buildWelcome() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),

          // ── Top Header Row (MakanBot Title & Subtitle) ───────────
          Row(
            children: [
              _buildHeaderCircleButton(
                context: context,
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () {
                  context.findAncestorStateOfType<NavTabProxy>()?.switchTab(0);
                },
                isDark: isDark,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'MakanBot',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Free Plan',
                      style: TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              _buildHeaderCircleButton(
                context: context,
                icon: Icons.grid_view_rounded,
                onTap: () => _showGridMenu(context),
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ── Title RichText ───────────────────────────────────────
          RichText(
            textAlign: TextAlign.left,
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 32,
                fontWeight: FontWeight.w900,
                height: 1.15,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              children: [
                TextSpan(text: 'Your '),
                TextSpan(
                  text: '✨ Smart\n',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkSecondary
                        : AppColors.secondary,
                  ),
                ),
                TextSpan(
                  text: 'Assistant ',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkSecondary
                        : AppColors.secondary,
                  ),
                ),
                TextSpan(text: 'for\nDaily Dining'),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Mascot on Right, Speech Bubble on Left overlapping ────
          SizedBox(
            height: 170,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Mascot on the Right (partially off-screen)
                Positioned(
                  right: -25,
                  top: 0,
                  bottom: 0,
                  width: 140,
                  child: Image.asset(
                    'assets/images/chatbot.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.centerRight,
                  ),
                ),

                // Speech Bubble on the Left
                Positioned(
                  left: 0,
                  right: 95, // Overlaps the mascot's left side slightly
                  top: 15,
                  child: CustomPaint(
                    painter: SpeechBubblePainter(
                      bgColor: isDark
                          ? AppColors.darkSurface.withValues(alpha: 0.75)
                          : Colors.white.withValues(alpha: 0.90),
                      borderColor: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : AppColors.secondary.withValues(alpha: 0.15),
                      isDark: isDark,
                      isTailOnLeft: false, // Tail on the right, pointing right
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 14,
                        right: 24, // tailWidth (10) + 14
                        top: 12,
                        bottom: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Hi! I'm Tutu, your makanbot! 👋",
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.darkOnSurface
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Ask me anything to find the perfect restaurant in Terengganu!",
                            style: TextStyle(
                              fontFamily: 'OpenSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : Colors.grey[600],
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Suggested section label (Left Aligned) ───────────────
          Text(
            'SUGGESTED QUESTIONS',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: (isDark ? AppColors.darkOnSurface : AppColors.textPrimary)
                  .withValues(alpha: 0.45),
            ),
          ),

          const SizedBox(height: 8),

          // ── Left-aligned Suggestions Chips (Wrap layout, baseline aligned) ──
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 10,
            children: _suggestions.map((item) {
              final (label, prompt) = item;
              final parts = label.split(' ');
              final emoji = parts.first;
              final text = parts.skip(1).join(' ');

              return GestureDetector(
                onTap: () => _startChat(context, prompt),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : AppColors.secondary.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.15 : 0.03,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        text,
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkOnSurface
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTabInputBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    // Position exactly above the floating bottom navigation bar
    final double navBarHeight = 68.0 + (bottomPad > 0 ? bottomPad + 6 : 14);

    final showSend = _textCtrl.text.trim().isNotEmpty;
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final double bottomPadding = isKeyboardOpen ? 8 : (8 + navBarHeight);

    final itemBgColor = isDark
        ? const Color(0xFF1B1929).withValues(alpha: 0.8)
        : Colors.white;
    final itemBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.secondary.withValues(alpha: 0.15);
    final itemShadow = isDark
        ? null
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ];

    return Container(
      // Only bottom padding to push it above the floating navbar
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
      color: Colors.transparent, // Fully transparent container background
      child: Row(
        children: [
          // Left Standalone [+] Button
          GestureDetector(
            onTap: () {
              _focusNode.requestFocus();
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: itemBgColor,
                border: Border.all(color: itemBorderColor, width: 1.5),
                boxShadow: itemShadow,
              ),
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Right Capsule Input Field
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: itemBgColor,
                border: Border.all(color: itemBorderColor, width: 1.5),
                boxShadow: itemShadow,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      onChanged: (_) {
                        setState(() {});
                      },
                      style: TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 14,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        filled: false,
                        hintText: 'Type a message..',
                        hintStyle: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 14,
                          color: isDark ? Colors.white30 : Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Right End Icon (Voice Waveform or Send Button)
                  showSend
                      ? GestureDetector(
                          onTap: _send,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: AppColors.freshMakanGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Voice feature is coming soon!',
                                ),
                                duration: const Duration(seconds: 2),
                                backgroundColor: AppColors.adaptiveSecondary(
                                  context,
                                ),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: _VoiceWaveformIcon(),
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: PremiumGradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(child: _buildWelcome()),
              _buildTabInputBar(context),
            ],
          ),
        ),
      ),
    );
  }
}

class ActiveConversationScreen extends StatefulWidget {
  final String initialMessage;
  const ActiveConversationScreen({super.key, required this.initialMessage});

  @override
  State<ActiveConversationScreen> createState() =>
      _ActiveConversationScreenState();
}

class _ActiveConversationScreenState extends State<ActiveConversationScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendText(widget.initialMessage);
    });
  }

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
      backgroundColor: Colors.transparent,
      extendBody: true,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(isDark),
      body: PremiumGradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: BlocConsumer<ChatCubit, ChatState>(
                  listener: (context, state) {
                    if (state is! ChatInitial) _scrollToBottom();
                  },
                  builder: (context, state) {
                    if (state is ChatInitial) {
                      return const Center(child: CircularProgressIndicator());
                    }
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
              BlocBuilder<ChatCubit, ChatState>(
                builder: (context, state) {
                  return _buildInputBar();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                _buildHeaderCircleButton(
                  context: context,
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () {
                    context.read<ChatCubit>().clearChat();
                    Navigator.pop(context);
                  },
                  isDark: isDark,
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'MakanBot',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Free Plan',
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildHeaderCircleButton(
                  context: context,
                  icon: Icons.grid_view_rounded,
                  onTap: () =>
                      _showGridMenu(context, onClear: _showClearDialog),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(List<ChatMessageModel> messages) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length,
      itemBuilder: (_, i) => _buildBubble(messages[i]),
    );
  }

  Widget _buildBubble(ChatMessageModel msg) {
    if (msg.isTyping) return _buildTypingBubble();
    final isUser = msg.isUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activePrimary = isDark ? AppColors.darkPrimary : AppColors.primary;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;

    final userBubbleColor = activePrimary;
    final botBubbleColor = isDark
        ? AppColors.darkSurface
        : const Color(0xFFF4FAFA);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bot avatar
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    activeSecondary,
                    activeSecondary.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: activeSecondary.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? LinearGradient(
                            colors: [
                              userBubbleColor,
                              userBubbleColor.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser
                        ? null
                        : msg.isError
                        ? AppColors.error.withValues(alpha: 0.08)
                        : botBubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    border: !isUser
                        ? Border.all(
                            color: msg.isError
                                ? AppColors.error.withValues(alpha: 0.25)
                                : activeSecondary.withValues(alpha: 0.15),
                            width: 1,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
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

                if (!isUser &&
                    msg.hasPartialMatch &&
                    msg.relaxedCriteria.isNotEmpty)
                  _buildPartialMatchBanner(msg.relaxedCriteria),

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

  Widget _buildModelBadge(ChatMessageModel msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;

    final parts = <String>[];
    if (msg.modelUsed.isNotEmpty) parts.add('⚡ ${msg.modelUsed}');
    if (msg.searchUsed) parts.add('🔍 Searched online');
    if (parts.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: activeSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeSecondary.withValues(alpha: 0.18)),
      ),
      child: Text(
        parts.join('  ·  '),
        style: TextStyle(
          fontFamily: 'OpenSans',
          fontSize: 10,
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

  Widget _buildTypingBubble() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSecondary = isDark
        ? AppColors.darkSecondary
        : AppColors.secondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  activeSecondary,
                  activeSecondary.withValues(alpha: 0.75),
                ],
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
              color: isDark ? AppColors.darkSurface : const Color(0xFFF4FAFA),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                color: activeSecondary.withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
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

  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        final sending = state is ChatSending;
        final hasText = _textCtrl.text.trim().isNotEmpty;

        final itemBgColor = isDark
            ? const Color(0xFF1B1929).withValues(alpha: 0.8)
            : Colors.white;
        final itemBorderColor = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.secondary.withValues(alpha: 0.15);
        final itemShadow = isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ];

        return Container(
          // Use bottom padding for safe area since there is no bottom navigation bar here
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            8 + MediaQuery.of(context).padding.bottom,
          ),
          color: Colors.transparent, // Fully transparent background
          child: Row(
            children: [
              // Left Standalone [+] Button
              GestureDetector(
                onTap: () => _showUpgradeBottomSheet(context),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: itemBgColor,
                    border: Border.all(color: itemBorderColor, width: 1.5),
                    boxShadow: itemShadow,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Right Capsule Input Field
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: itemBgColor,
                    border: Border.all(color: itemBorderColor, width: 1.5),
                    boxShadow: itemShadow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          focusNode: _focusNode,
                          enabled: !sending,
                          maxLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => sending ? null : _send(),
                          onChanged: (_) {
                            setState(() {});
                          },
                          style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            filled: false,
                            hintText: sending
                                ? 'Makanbot is thinking...'
                                : 'Type a message..',
                            hintStyle: TextStyle(
                              fontFamily: 'OpenSans',
                              fontSize: 14,
                              color: isDark ? Colors.white30 : Colors.grey[400],
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Right End Icon (Sending indicator, Send button or Voice waveform)
                      if (sending)
                        const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      else if (hasText)
                        GestureDetector(
                          onTap: _send,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: AppColors.freshMakanGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () => _showUpgradeBottomSheet(context),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: _VoiceWaveformIcon(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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

void _showUpgradeBottomSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final activePrimary = isDark ? AppColors.darkPrimary : AppColors.primary;
  final activeSecondary = isDark
      ? AppColors.darkSecondary
      : AppColors.secondary;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: activePrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    color: activePrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Makanbot',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '+',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: activePrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock the full power of AI-assisted dining',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'OpenSans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            _buildUpgradeFeatureItem(
              context,
              icon: Icons.mic_rounded,
              title: 'Speech-to-Text Voice Search',
              description:
                  'Talk to Makanbot naturally instead of typing to get recommendations on the fly.',
              color: activeSecondary,
            ),
            const SizedBox(height: 16),
            _buildUpgradeFeatureItem(
              context,
              icon: Icons.cloud_upload_rounded,
              title: 'Smart Photos & File Uploads',
              description:
                  'Attach menus, receipts, screenshots, or restaurant pictures to extract insights.',
              color: activePrimary,
            ),
            const SizedBox(height: 16),
            _buildUpgradeFeatureItem(
              context,
              icon: Icons.auto_awesome_rounded,
              title: 'Priority AI & Unlimited Chats',
              description:
                  'Get instant peak-hour priority responses and personalized taste mapping.',
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: AppColors.freshMakanGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: activePrimary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Thank you! Makanbot+ subscription model integration coming soon.',
                      ),
                      backgroundColor: activeSecondary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Upgrade to Makanbot+ for RM9.90/mo',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe Later',
                style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildUpgradeFeatureItem(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String description,
  required Color color,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              style: TextStyle(
                fontFamily: 'OpenSans',
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : Colors.grey[600],
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

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

    final rawFilters = preview['matched_filters'] as List<dynamic>? ?? [];
    final matchedFilters = rawFilters.map((e) => e.toString()).toList();

    String cuisine = '';
    final rawCuisine = preview['cuisine_type'];
    if (rawCuisine is List) {
      cuisine = (rawCuisine).join(', ');
    } else if (rawCuisine is String) {
      cuisine = rawCuisine;
    }

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

            // ── Explainability chips ───────────────────────────────────────
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

class _MatchedChips extends StatelessWidget {
  final List<String> filters;
  const _MatchedChips({required this.filters});

  @override
  Widget build(BuildContext context) {
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

// ─── Custom Speech Bubble Painter ────────────────────────────────────────────
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
      // Draw the bubble path clockwise with a left-pointing tail
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
      // Draw the bubble path clockwise with a right-pointing tail
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

    // Draw shadow
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
      6.0,
      true,
    );

    // Draw fill
    canvas.drawPath(path, paint);

    // Draw border
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

// ─── Header & Menu Helpers ───────────────────────────────────────────────────

Widget _buildHeaderCircleButton({
  required BuildContext context,
  required IconData icon,
  required VoidCallback onTap,
  required bool isDark,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.5),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.secondary.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: isDark ? Colors.white : AppColors.textPrimary,
          size: 18,
        ),
      ),
    ),
  );
}

void _showGridMenu(BuildContext context, {VoidCallback? onClear}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          top: 16,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.star_rounded, color: AppColors.primary),
              title: Text(
                'Upgrade to MakanBot+',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              subtitle: const Text(
                'Voice chat, menu upload & unlimited answers',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showUpgradeBottomSheet(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.delete_sweep_rounded,
                color: AppColors.error,
              ),
              title: Text(
                'Clear Conversation',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              subtitle: const Text('Reset chat history and start fresh'),
              onTap: () {
                Navigator.pop(ctx);
                if (onClear != null) {
                  onClear();
                } else if (context.mounted) {
                  context.read<ChatCubit>().clearChat();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat history cleared.')),
                  );
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

// ─── Custom Voice Waveform Icon ──────────────────────────────────────────────

class _VoiceWaveformIcon extends StatelessWidget {
  const _VoiceWaveformIcon();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white60 : Colors.grey[600]!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _bar(8, color),
        const SizedBox(width: 2.5),
        _bar(14, color),
        const SizedBox(width: 2.5),
        _bar(20, color),
        const SizedBox(width: 2.5),
        _bar(14, color),
        const SizedBox(width: 2.5),
        _bar(8, color),
      ],
    );
  }

  Widget _bar(double height, Color color) {
    return Container(
      width: 2.5,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.25),
      ),
    );
  }
}
