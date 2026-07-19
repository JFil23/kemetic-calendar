// lib/features/profile/profile_page.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/daily_reflection_question.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/navigation_fallback.dart';
import '../../main.dart' show Events;
import '../../data/profile_avatar_glyphs.dart';
import '../../data/commons_models.dart';
import '../../data/commons_repo.dart';
import '../../data/profile_model.dart';
import '../../data/profile_repo.dart';
import '../../data/flow_post_model.dart';
import '../../data/insight_post_model.dart';
import '../../data/profile_feed_item_model.dart';
import '../../data/shared_practice_models.dart';
import '../../data/shared_practice_repo.dart';
import '../../utils/detail_sanitizer.dart';
import '../../utils/kemetic_date_format.dart';
import '../../services/app_haptics.dart';
import '../../services/navigation_trace.dart';
import '../../services/restoration_coordinator.dart';
import '_post_glossy_helper.dart';
import 'follow_list_page.dart';
import '../calendar/calendar_page.dart';
import '../calendar/kemetic_month_metadata.dart' show getMonthById;
import 'package:mobile/features/onboarding/guided_onboarding_overlay.dart';
import '../onboarding/onboarding_progress.dart';
import '../onboarding/onboarding_review_config.dart';
import '../shared_practice/shared_practice_calendar_chooser_sheet.dart';
import 'flow_post_engagement_row.dart';
import 'package:mobile/shared/glossy_text.dart';
import '../../widgets/kemetic_app_bar_action.dart';
import '../../widgets/profile_avatar.dart';
import 'profile_backdrop_timeline.dart';

const Color _profileGoldLight = Color(0xFFF7E09A);
const Color _profileGoldMid = Color(0xFFE8BE54);
const Color _profileGoldBase = Color(0xFFCA9221);
const Color _profileGoldDeep = Color(0xFF7A5310);
const Color _profileGoldText = Color(0xFFF1CF7A);
const Color _profileGregorianBlue = Color(0xFF4DA3FF);
const Color _profileGregorianBlueLight = Color(0xFFBFE0FF);
const int _profileFeedPageSize = 18;
const double _profileFeedColumnGap = 12;
const double _profileFeedTabsHeaderExtent = 64;
const Set<String> _profileFeedKeywordStopWords = <String>{
  'a',
  'about',
  'all',
  'am',
  'an',
  'and',
  'any',
  'are',
  'as',
  'at',
  'be',
  'been',
  'being',
  'but',
  'by',
  'community',
  'dated',
  'day',
  'days',
  'did',
  'do',
  'flow',
  'flows',
  'follow',
  'following',
  'for',
  'from',
  'have',
  'i',
  'if',
  'in',
  'insight',
  'insights',
  'into',
  'is',
  'it',
  'its',
  'like',
  'me',
  'more',
  'my',
  'no',
  'note',
  'notes',
  'of',
  'on',
  'or',
  'our',
  'out',
  'over',
  'post',
  'posted',
  'posts',
  'read',
  'she',
  'so',
  'than',
  'that',
  'the',
  'their',
  'them',
  'then',
  'there',
  'they',
  'this',
  'through',
  'to',
  'under',
  'up',
  'us',
  'was',
  'we',
  'were',
  'what',
  'when',
  'where',
  'which',
  'while',
  'will',
  'with',
  'within',
  'yes',
  'you',
  'your',
};

const Gradient _profileGoldGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    _profileGoldBase,
    _profileGoldLight,
    _profileGoldMid,
    _profileGoldDeep,
  ],
  stops: [0.0, 0.42, 0.74, 1.0],
);
const String _profileSerifFont = 'CormorantGaramond';
const List<String> _profileSerifFallback = ['GentiumPlus', 'Georgia', 'serif'];

enum _SocialFeedTab { todaysCommons, forYou }

class ProfilePage extends StatefulWidget {
  final String userId;
  final bool isMyProfile;
  final bool openedFromCalendar;

  const ProfilePage({
    super.key,
    required this.userId,
    this.isMyProfile = false,
    this.openedFromCalendar = false,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _feedRevealViewportThreshold = 0.74;
  static const double _feedPullToCloseThreshold = 96;
  final _repo = ProfileRepo(Supabase.instance.client);
  final _commonsRepo = CommonsRepo(Supabase.instance.client);
  late final PageController _postPageController;
  late final PageController _insightPostPageController;
  late final PageController _commonsPracticePageController;
  late final ScrollController _profileScrollController;
  late final ScrollController _feedScrollController;
  late final AnimationController _feedBloomController;
  final TextEditingController _commonsAnswerController =
      TextEditingController();
  final GlobalKey _feedRevealHintKey = GlobalKey();
  final GlobalKey _profileBasicsOnboardingKey = GlobalKey(
    debugLabel: 'profile_basics_onboarding',
  );
  UserProfile? _profile;
  bool _loading = true;
  bool _cacheHydrating = true;
  bool _isFollowing = false;
  bool _followUpdating = false;
  bool _profileSafetyUpdating = false;
  List<FlowPost> _posts = const [];
  List<InsightPost> _insightPosts = const [];
  List<ProfileFeedItem> _feedItems = const [];
  bool _postsLoading = true;
  bool _insightPostsLoading = true;
  bool _feedRevealed = false;
  bool _feedLoading = false;
  bool _feedLoadingMore = false;
  bool _feedHasMore = true;
  String? _feedErrorMessage;
  _SocialFeedTab _selectedFeedTab = _SocialFeedTab.todaysCommons;
  bool _showGregorianFeedDates = false;
  ProfileFeedItem? _expandedFeedItem;
  CommonsHomeSnapshot? _commonsHome;
  bool _feedCloseInFlight = false;
  bool _commonsLoading = false;
  bool _commonsAnswerEditing = false;
  bool _commonsAnswerSaving = false;
  bool _commonsAnswerDeleting = false;
  String? _commonsErrorMessage;
  int _activePostIndex = 0;
  int _activeInsightPostIndex = 0;
  int _activeCommonsPracticeIndex = 0;
  final Set<String> _commonsJoiningRoomIds = <String>{};
  final Set<String> _commonsVisibilityUpdatingRoomIds = <String>{};
  int _profileLoadSerial = 0;
  double _feedTopPullDistance = 0;
  Timer? _continuitySaveDebounce;
  bool _continuityRestored = false;
  bool _buildTraceRecorded = false;
  double? _pendingProfileScrollOffset;
  double? _pendingFeedScrollOffset;
  String? _pendingExpandedFeedIdentity;
  bool _profileBasicsOnboardingPrompted = false;
  bool _profileCommunityHelperPrompted = false;

  String get _surfaceKey => 'profile:${widget.userId}';

  bool get _isViewingOwnProfile {
    final currentId = Supabase.instance.client.auth.currentUser?.id;
    return widget.isMyProfile ||
        (currentId != null && currentId == widget.userId);
  }

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  String _navigationTraceUserId(String? userId) {
    final trimmed = userId?.trim();
    if (trimmed == null || trimmed.isEmpty) return '<empty>';
    final currentUserId = _currentUserId;
    if (currentUserId != null && currentUserId == trimmed) {
      return '<currentUser>';
    }
    return '<id:${trimmed.length}>';
  }

  Map<String, Object?> _navigationTraceProfileState() {
    return <String, Object?>{
      'userId': _navigationTraceUserId(widget.userId),
      'isMyProfile': widget.isMyProfile,
      'openedFromCalendar': widget.openedFromCalendar,
      'currentUserIdPresent': _currentUserId != null,
      'mounted': mounted,
    };
  }

  bool _ownsPost(FlowPost post) {
    final currentUserId = _currentUserId;
    return currentUserId != null && currentUserId == post.userId;
  }

  bool _ownsInsightPost(InsightPost post) {
    final currentUserId = _currentUserId;
    return currentUserId != null && currentUserId == post.userId;
  }

  @override
  void initState() {
    super.initState();
    NavigationTrace.instance.record(
      'ProfilePage initState',
      state: _navigationTraceProfileState(),
    );
    WidgetsBinding.instance.addObserver(this);
    _postPageController = PageController(viewportFraction: 0.96);
    _insightPostPageController = PageController(viewportFraction: 0.96);
    _commonsPracticePageController = PageController(viewportFraction: 0.92);
    _profileScrollController = ScrollController()
      ..addListener(_handleProfileScroll);
    _feedScrollController = ScrollController()..addListener(_handleFeedScroll);
    _feedBloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _seedPostedContentFromMemory();
    unawaited(_restoreContinuityState());
    _loadProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _continuitySaveDebounce?.cancel();
    unawaited(_persistContinuityState());
    _feedBloomController.dispose();
    _profileScrollController
      ..removeListener(_handleProfileScroll)
      ..dispose();
    _feedScrollController
      ..removeListener(_handleFeedScroll)
      ..dispose();
    _postPageController.dispose();
    _insightPostPageController.dispose();
    _commonsPracticePageController.dispose();
    _commonsAnswerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_persistContinuityState());
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  Future<void> _restoreContinuityState() async {
    final state = await RestorationCoordinator.instance.readSurfaceState(
      _surfaceKey,
    );
    if (!mounted || state == null) {
      _continuityRestored = true;
      return;
    }

    final feedRevealed = state['feedRevealed'] == true;
    _pendingProfileScrollOffset = (state['profileScrollOffset'] as num?)
        ?.toDouble();
    _pendingFeedScrollOffset = (state['feedScrollOffset'] as num?)?.toDouble();
    _pendingExpandedFeedIdentity = (state['expandedFeedItem'] as String?)
        ?.trim();
    final rawFeedTab = (state['selectedFeedTab'] as String?)?.trim();
    final activePostIndex = (state['activePostIndex'] as num?)?.toInt();
    final activeInsightIndex = (state['activeInsightPostIndex'] as num?)
        ?.toInt();

    setState(() {
      _feedRevealed = feedRevealed;
      _selectedFeedTab = rawFeedTab == _SocialFeedTab.forYou.name
          ? _SocialFeedTab.forYou
          : _SocialFeedTab.todaysCommons;
      _showGregorianFeedDates = state['showGregorianFeedDates'] == true;
      if (activePostIndex != null && activePostIndex >= 0) {
        _activePostIndex = activePostIndex;
      }
      if (activeInsightIndex != null && activeInsightIndex >= 0) {
        _activeInsightPostIndex = activeInsightIndex;
      }
      _continuityRestored = true;
    });

    if (feedRevealed) {
      _feedBloomController.value = 1;
      unawaited(_loadFeedPage(reset: true));
    }
    _applyPendingContinuityAfterFrame();
  }

  void _handleFeedScroll() {
    if (_selectedFeedTab == _SocialFeedTab.forYou) {
      _maybeLoadMoreFeed();
    }
    _scheduleContinuitySave();
  }

  void _scheduleContinuitySave() {
    if (!_continuityRestored) {
      return;
    }
    _continuitySaveDebounce?.cancel();
    _continuitySaveDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persistContinuityState());
    });
  }

  Future<void> _persistContinuityState() async {
    final profileOffset = _profileScrollController.hasClients
        ? _profileScrollController.offset
        : _pendingProfileScrollOffset;
    final feedOffset = _feedScrollController.hasClients
        ? _feedScrollController.offset
        : _pendingFeedScrollOffset;
    await RestorationCoordinator.instance
        .saveSurfaceState(_surfaceKey, <String, dynamic>{
          'kind': 'profile',
          'userId': widget.userId,
          'isMyProfile': _isViewingOwnProfile,
          'feedRevealed': _feedRevealed,
          'selectedFeedTab': _selectedFeedTab.name,
          'showGregorianFeedDates': _showGregorianFeedDates,
          'activePostIndex': _activePostIndex,
          'activeInsightPostIndex': _activeInsightPostIndex,
          if (profileOffset != null && profileOffset.isFinite)
            'profileScrollOffset': math.max(0, profileOffset),
          if (feedOffset != null && feedOffset.isFinite)
            'feedScrollOffset': math.max(0, feedOffset),
          if (_expandedFeedItem != null)
            'expandedFeedItem': _feedItemIdentity(_expandedFeedItem!),
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        });
  }

  void _applyPendingContinuityAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final profileOffset = _pendingProfileScrollOffset;
      if (profileOffset != null && _profileScrollController.hasClients) {
        final max = _profileScrollController.position.maxScrollExtent;
        _profileScrollController.jumpTo(profileOffset.clamp(0.0, max));
        _pendingProfileScrollOffset = null;
      }

      final feedOffset = _pendingFeedScrollOffset;
      if (feedOffset != null && _feedScrollController.hasClients) {
        final max = _feedScrollController.position.maxScrollExtent;
        _feedScrollController.jumpTo(feedOffset.clamp(0.0, max));
        _pendingFeedScrollOffset = null;
      }
    });
  }

  void _seedPostedContentFromMemory() {
    final cachedPosts = _repo.getCachedFlowPostsSync(widget.userId);
    if (cachedPosts != null) {
      _posts = cachedPosts;
      _postsLoading = false;
      _activePostIndex = _clampPostIndex(cachedPosts.length);
    }

    final cachedInsights = _repo.getCachedInsightPostsSync(widget.userId);
    if (cachedInsights != null) {
      _insightPosts = cachedInsights;
      _insightPostsLoading = false;
      _activeInsightPostIndex = _clampInsightPostIndex(cachedInsights.length);
    }
  }

  Future<void> _loadProfile({bool showSpinner = true}) async {
    final loadSerial = ++_profileLoadSerial;

    if (onboardingReviewSessionRequested &&
        widget.userId == kOnboardingReviewHelperUserId) {
      setState(() {
        _profile = UserProfile(
          id: kOnboardingReviewHelperUserId,
          handle: 'review',
          displayName: 'Review Profile',
          avatarGlyphIds: const ['maat', 'increase', 'me'],
          bio: 'Onboarding review profile',
          activeFlowsCount: 1,
          totalFlowEventsCount: 1,
          followersCount: 0,
          followingCount: 0,
          createdAt: DateTime(2026),
        );
        _isFollowing = false;
        _loading = false;
        _cacheHydrating = false;
        _postsLoading = false;
        _insightPostsLoading = false;
        _feedLoading = false;
      });
      _maybeShowProfileCommunityHelper();
      return;
    }

    unawaited(_restoreCachedPostedContent(loadSerial));

    NavigationTrace.instance.record(
      'Profile cache hydration start',
      state: _navigationTraceProfileState(),
    );
    final cachedProfile = _repo.getCachedProfileSync(widget.userId);
    var cacheSource = 'none';
    if (cachedProfile != null) {
      cacheSource = 'memory';
      setState(() {
        _profile = cachedProfile;
        _loading = false;
        _cacheHydrating = false;
      });
    } else if (showSpinner) {
      final restored = await _repo.restoreCachedProfile(widget.userId);
      if (!mounted || loadSerial != _profileLoadSerial) return;
      if (restored != null) {
        cacheSource = 'disk';
        setState(() {
          _profile = restored;
          _loading = false;
          _cacheHydrating = false;
        });
      } else if (_profile == null) {
        setState(() {
          _loading = true;
          _cacheHydrating = false;
        });
      }
    } else if (_cacheHydrating) {
      setState(() => _cacheHydrating = false);
    }
    NavigationTrace.instance.record(
      'Profile cache hydration done',
      state: <String, Object?>{
        ..._navigationTraceProfileState(),
        'cacheSource': cacheSource,
        'hasProfile': _profile != null,
      },
    );

    NavigationTrace.instance.record(
      'Profile live load start',
      state: _navigationTraceProfileState(),
    );
    final profileFuture = _repo.getProfile(widget.userId);
    final followFuture = _isViewingOwnProfile
        ? Future<bool>.value(false)
        : _repo.isFollowing(widget.userId);
    final postsFuture = _repo.getFlowPosts(widget.userId);
    final insightPostsFuture = _repo.getInsightPosts(widget.userId);

    final profile = await profileFuture;
    final isFollowing = await followFuture;

    if (!mounted || loadSerial != _profileLoadSerial) return;

    if (profile == null) {
      setState(() {
        _isFollowing = isFollowing;
        _loading = false;
        _cacheHydrating = false;
      });
      NavigationTrace.instance.record(
        'Profile live load done',
        state: <String, Object?>{
          ..._navigationTraceProfileState(),
          'hasProfile': false,
        },
      );
      return;
    }

    setState(() {
      _profile = profile;
      _isFollowing = isFollowing;
      _loading = false;
      _cacheHydrating = false;
    });
    NavigationTrace.instance.record(
      'Profile live load done',
      state: <String, Object?>{
        ..._navigationTraceProfileState(),
        'hasProfile': true,
      },
    );
    _maybeShowProfileOnboarding(profile);

    unawaited(() async {
      final posts = await postsFuture;
      if (!mounted || loadSerial != _profileLoadSerial) return;
      _applyPosts(posts);
    }());

    unawaited(() async {
      final posts = await insightPostsFuture;
      if (!mounted || loadSerial != _profileLoadSerial) return;
      _applyInsightPosts(posts);
    }());
  }

  Future<void> _maybeShowProfileOnboarding(UserProfile profile) async {
    if (!_isViewingOwnProfile || _profileBasicsOnboardingPrompted) return;
    final userId = _currentUserId;
    if (userId == null) return;
    final storage = OnboardingProgressStorage();
    final progress = await storage.load(userId);
    if (!mounted ||
        progress.completedOnboarding ||
        progress.currentStep != TrueOnboardingStep.profileBasics) {
      if (progress.completedOnboarding) {
        unawaited(_maybeShowProfileCommunityHelper(progress));
      }
      return;
    }

    if (!hasCompletedProfileBasics(
      avatarGlyphIds: profile.avatarGlyphIds,
      displayName: profile.displayName,
      handle: profile.handle,
    )) {
      context.go('/profile/me/edit?requireCompletion=1&onboarding=1');
      return;
    }

    _profileBasicsOnboardingPrompted = true;
    await storage.save(
      userId,
      progress.copyWith(hasCompletedProfileBasics: true),
    );
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GuidedOnboardingController.instance.show(
        CoachmarkTarget(
          key: _profileBasicsOnboardingKey,
          title: 'Create your glyph avatar.',
          body:
              'Your glyph avatar becomes your mark inside ḥꜣw. Complete your basic profile so your flows, reflections, and shared activity have a clear identity.',
          instruction:
              'Your required profile basics are saved. Continue to Ma’at Flows.',
          placement: CoachmarkPlacement.below,
          showNextButton: true,
          onNext: () async {
            GuidedOnboardingController.instance.clear();
            await storage.update(
              userId,
              (current) => current.copyWith(
                hasCompletedProfileBasics: true,
                currentStep: TrueOnboardingStep.firstMaatFlow,
              ),
            );
            if (!mounted) return;
            context.go('/');
          },
        ),
      );
    });
  }

  Future<void> _maybeShowProfileCommunityHelper([
    OnboardingProgress? loadedProgress,
  ]) async {
    if (!_isViewingOwnProfile || _profileCommunityHelperPrompted) return;
    final reviewMode = onboardingReviewSessionRequested;
    final userId =
        _currentUserId ?? (reviewMode ? kOnboardingReviewHelperUserId : null);
    if (userId == null) return;
    if (!reviewMode) {
      final storage = OnboardingProgressStorage();
      final progress = loadedProgress ?? await storage.load(userId);
      if (!mounted || !progress.completedOnboarding) {
        return;
      }
    }
    const helper = OnboardingHelperRegistry.profileCommunityFeed;
    final helperService = OnboardingHelperCompletionService.instance;
    if (!reviewMode) {
      await helperService.hydrateUser(userId);
    }
    if (!mounted ||
        (!reviewMode &&
            !helperService.shouldShowHelperSync(userId, helper.id))) {
      return;
    }
    _profileCommunityHelperPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(() async {
        if (!mounted || _feedRevealed) return;
        if (!reviewMode) {
          await helperService.hydrateUser(userId);
        }
        if (!mounted ||
            (!reviewMode &&
                !helperService.shouldShowHelperSync(userId, helper.id))) {
          return;
        }
        NavigationTrace.instance.record(
          'helper overlay shown',
          state: <String, Object?>{
            'destination': 'profile',
            'helperId': helper.id,
          },
        );
        GuidedOnboardingController.instance.show(
          CoachmarkTarget(
            key: _feedRevealHintKey,
            title: helper.title,
            body: helper.body,
            placement: CoachmarkPlacement.auto,
            variant: CoachmarkVariant.helperBubble,
            showDismissButton: true,
            dismissLabel: 'Got it',
            helperId: helper.id,
            helperUserId: userId,
            sourceWidget: helper.sourceWidget,
            onDismiss: () async {
              if (reviewMode) {
                GuidedOnboardingController.instance.clear();
                return;
              }
              final completion = helperService.markHelperCompleted(
                userId,
                helper.id,
              );
              GuidedOnboardingController.instance.clear();
              await completion;
              unawaited(
                Events.trackIfAuthed(
                  helper.analyticsEvent,
                  const <String, dynamic>{},
                ),
              );
            },
          ),
        );
      }());
    });
  }

  Future<void> _markProfileCommunityHelperSeen({
    bool clearActiveHelper = true,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;
    const helper = OnboardingHelperRegistry.profileCommunityFeed;
    final helperService = OnboardingHelperCompletionService.instance;
    if (!await helperService.shouldShowHelper(userId, helper.id)) {
      return;
    }
    final completion = helperService.markHelperCompleted(userId, helper.id);
    if (clearActiveHelper &&
        GuidedOnboardingController.instance.target?.variant ==
            CoachmarkVariant.helperBubble) {
      GuidedOnboardingController.instance.clear();
    }
    await completion;
    unawaited(
      Events.trackIfAuthed(helper.analyticsEvent, const <String, dynamic>{}),
    );
  }

  Future<void> _restoreCachedPostedContent(int loadSerial) async {
    final cachedPosts = _repo.getCachedFlowPostsSync(widget.userId);
    if (cachedPosts != null && _postsLoading && mounted) {
      _applyPosts(cachedPosts);
    }

    final cachedInsights = _repo.getCachedInsightPostsSync(widget.userId);
    if (cachedInsights != null && _insightPostsLoading && mounted) {
      _applyInsightPosts(cachedInsights);
    }

    if (cachedPosts != null && cachedInsights != null) return;

    final results = await Future.wait<dynamic>([
      cachedPosts == null
          ? _repo.restoreCachedFlowPosts(widget.userId)
          : Future<List<FlowPost>?>.value(null),
      cachedInsights == null
          ? _repo.restoreCachedInsightPosts(widget.userId)
          : Future<List<InsightPost>?>.value(null),
    ]);
    if (!mounted || loadSerial != _profileLoadSerial) return;

    final restoredPosts = results[0] as List<FlowPost>?;
    if (restoredPosts != null && _postsLoading) {
      _applyPosts(restoredPosts);
    }

    final restoredInsights = results[1] as List<InsightPost>?;
    if (restoredInsights != null && _insightPostsLoading) {
      _applyInsightPosts(restoredInsights);
    }
  }

  Future<void> _loadPosts() async {
    if (_posts.isEmpty) {
      setState(() => _postsLoading = true);
    }
    final posts = await _repo.getFlowPosts(widget.userId);
    if (!mounted) return;
    _applyPosts(posts);
  }

  void _applyPosts(List<FlowPost> posts) {
    final activeIndex = _clampPostIndex(posts.length);
    setState(() {
      _posts = posts;
      _postsLoading = false;
      _activePostIndex = activeIndex;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || posts.isEmpty || !_postPageController.hasClients) return;
      final currentPage = (_postPageController.page ?? activeIndex.toDouble())
          .round();
      if (currentPage != activeIndex) {
        _postPageController.jumpToPage(activeIndex);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeRevealFeedFromViewport();
    });
  }

  Future<void> _loadInsightPosts() async {
    if (_insightPosts.isEmpty) {
      setState(() => _insightPostsLoading = true);
    }
    final posts = await _repo.getInsightPosts(widget.userId);
    if (!mounted) return;
    _applyInsightPosts(posts);
  }

  void _applyInsightPosts(List<InsightPost> posts) {
    final activeIndex = _clampInsightPostIndex(posts.length);
    setState(() {
      _insightPosts = posts;
      _insightPostsLoading = false;
      _activeInsightPostIndex = activeIndex;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || posts.isEmpty || !_insightPostPageController.hasClients) {
        return;
      }
      final currentPage =
          (_insightPostPageController.page ?? activeIndex.toDouble()).round();
      if (currentPage != activeIndex) {
        _insightPostPageController.jumpToPage(activeIndex);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeRevealFeedFromViewport();
    });
  }

  void _handleProfileScroll() {
    if (!_feedRevealed) {
      _maybeRevealFeedFromViewport();
    }
    if (_feedRevealed && _selectedFeedTab == _SocialFeedTab.forYou) {
      _maybeLoadMoreFeed();
    }
    _scheduleContinuitySave();
  }

  void _maybeRevealFeedFromViewport() {
    if (_feedRevealed) return;
    final revealContext = _feedRevealHintKey.currentContext;
    if (revealContext == null) return;
    final renderObject = revealContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final center = renderObject.localToGlobal(
      Offset(0, renderObject.size.height / 2),
    );
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final revealLine = viewportHeight * _feedRevealViewportThreshold;
    if (center.dy <= revealLine) {
      _revealFeed();
    }
  }

  Future<void> _revealFeed() async {
    if (_feedRevealed || _feedCloseInFlight) return;
    _feedTopPullDistance = 0;
    unawaited(AppHaptics.mediumImpact(reason: 'profile_feed_reveal'));
    setState(() => _feedRevealed = true);
    unawaited(_markProfileCommunityHelperSeen());
    _scheduleContinuitySave();
    unawaited(_feedBloomController.forward(from: 0));
    if (_feedItems.isEmpty && !_feedLoading) {
      unawaited(_loadFeedPage(reset: true));
    }
    if (_commonsHome == null && !_commonsLoading) {
      unawaited(_loadCommonsHome());
    }
  }

  Future<void> _closeFeed() async {
    if (!_feedRevealed || _feedCloseInFlight) return;
    _feedCloseInFlight = true;
    _feedTopPullDistance = 0;
    unawaited(AppHaptics.mediumImpact(reason: 'profile_feed_close'));
    await _feedBloomController.reverse(from: _feedBloomController.value);
    if (!mounted) return;
    _feedCloseInFlight = false;
    setState(() {
      _feedRevealed = false;
      _expandedFeedItem = null;
    });
    _scheduleContinuitySave();
  }

  void _updateFeedPullDistance(double pullDistance) {
    final clampedPull = pullDistance.clamp(0.0, _feedPullToCloseThreshold);
    _feedTopPullDistance = math.max(_feedTopPullDistance, clampedPull);
  }

  void _maybeCloseFeedFromPull() {
    if (_feedTopPullDistance < _feedPullToCloseThreshold) return;
    if (_feedCloseInFlight) return;
    unawaited(_closeFeed());
  }

  bool _handleFeedScrollNotification(ScrollNotification notification) {
    if (!_feedRevealed || _feedCloseInFlight) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.depth != 0) return false;

    switch (notification) {
      case ScrollStartNotification():
        _feedTopPullDistance = 0;
        return false;
      case ScrollUpdateNotification():
        final pullDistance = math.max(
          0.0,
          notification.metrics.minScrollExtent - notification.metrics.pixels,
        );
        if (pullDistance > 0) {
          _updateFeedPullDistance(pullDistance);
          _maybeCloseFeedFromPull();
        }
        return false;
      case OverscrollNotification():
        final atTop =
            notification.metrics.pixels <=
            notification.metrics.minScrollExtent + 0.5;
        if (!atTop) return false;
        _updateFeedPullDistance(
          _feedTopPullDistance + notification.overscroll.abs(),
        );
        _maybeCloseFeedFromPull();
        return false;
      case ScrollEndNotification():
        if (_feedTopPullDistance >= _feedPullToCloseThreshold) {
          unawaited(_closeFeed());
        } else {
          _feedTopPullDistance = 0;
        }
        return false;
      default:
        return false;
    }
  }

  void _toggleFeedDateMode() {
    if (!mounted) return;
    setState(() {
      _showGregorianFeedDates = !_showGregorianFeedDates;
    });
    _scheduleContinuitySave();
  }

  Future<void> _loadFeedPage({bool reset = false}) async {
    if (_feedLoading || _feedLoadingMore) return;
    if (!reset && !_feedHasMore) return;

    final nextOffset = reset ? 0 : _feedItems.length;
    if (reset) {
      setState(() {
        _feedLoading = true;
        _feedHasMore = true;
        _feedErrorMessage = null;
      });
    } else {
      setState(() => _feedLoadingMore = true);
    }

    final result = await _repo.getProfileFeedResult(
      limit: _profileFeedPageSize,
      offset: nextOffset,
    );
    if (!mounted) return;
    if (result.hasError) {
      setState(() {
        _feedLoading = false;
        _feedLoadingMore = false;
        _feedHasMore = false;
        _feedErrorMessage = result.errorMessage;
        if (reset) {
          _expandedFeedItem = null;
          _pendingExpandedFeedIdentity = null;
        }
      });
      return;
    }

    final loaded = result.data;

    final expandedIdentity = _expandedFeedItem == null
        ? null
        : _feedItemIdentity(_expandedFeedItem!);
    final merged = reset
        ? <ProfileFeedItem>[]
        : List<ProfileFeedItem>.from(_feedItems);
    final seenIds = merged
        .map((item) => '${item.kind.name}:${item.id}')
        .toSet();
    for (final item in loaded) {
      final key = '${item.kind.name}:${item.id}';
      if (seenIds.add(key)) {
        merged.add(item);
      }
    }

    final updatedExpanded = expandedIdentity == null
        ? null
        : _findFeedItemByIdentity(merged, expandedIdentity);
    final pendingExpanded = _pendingExpandedFeedIdentity == null
        ? null
        : _findFeedItemByIdentity(merged, _pendingExpandedFeedIdentity!);
    setState(() {
      _feedItems = merged;
      _feedLoading = false;
      _feedLoadingMore = false;
      _feedHasMore = loaded.length >= _profileFeedPageSize;
      _feedErrorMessage = null;
      if (pendingExpanded != null) {
        _expandedFeedItem = pendingExpanded;
        _pendingExpandedFeedIdentity = null;
      } else if (updatedExpanded != null) {
        _expandedFeedItem = updatedExpanded;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyPendingContinuityAfterFrame();
      _maybeLoadMoreFeed();
    });
  }

  String _commonsQuestionId(DailyReflectionQuestion? question) {
    if (question != null) {
      return 'daily-reflection:${question.kYear}:${question.dayKey}';
    }
    final now = DateUtils.dateOnly(DateTime.now());
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return 'daily-reflection:${now.year}-$month-$day';
  }

  ({String id, String text}) _commonsQuestionSeed() {
    final daily = dailyReflectionQuestionForDate(DateTime.now());
    return (
      id: _commonsQuestionId(daily),
      text: _withoutWrappingQuotes(daily?.question ?? ''),
    );
  }

  CommonsQuestion _activeCommonsQuestion() {
    final seed = _commonsQuestionSeed();
    final questions = _commonsHome?.questions ?? const <CommonsQuestion>[];
    for (final question in questions) {
      if (question.id == seed.id) {
        return CommonsQuestion(
          id: question.id,
          question: question.question.trim().isEmpty
              ? seed.text
              : question.question,
          answers: question.answers,
          myAnswer: question.myAnswer,
        );
      }
    }
    return CommonsQuestion(id: seed.id, question: seed.text);
  }

  Future<void> _loadCommonsHome({bool force = false}) async {
    if (_commonsLoading && !force) return;
    final seed = _commonsQuestionSeed();
    if (!mounted) return;
    setState(() {
      _commonsLoading = true;
      _commonsErrorMessage = null;
    });
    try {
      final snapshot = await _commonsRepo.getCommonsHome(
        localDate: DateTime.now(),
        questionId: seed.id,
        questionText: seed.text,
      );
      if (!mounted) return;
      final question = snapshot.questions.isNotEmpty
          ? snapshot.questions.first
          : CommonsQuestion(id: seed.id, question: seed.text);
      if (!_commonsAnswerEditing &&
          !_commonsAnswerSaving &&
          question.myAnswer != null) {
        _commonsAnswerController.text = question.myAnswer!.bodyText;
      }
      setState(() {
        _commonsHome = snapshot.questions.isEmpty
            ? snapshot.copyWith(questions: <CommonsQuestion>[question])
            : snapshot;
        _commonsLoading = false;
        _commonsErrorMessage = null;
        final practiceCount = _commonsPracticeRooms().length;
        if (practiceCount == 0) {
          _activeCommonsPracticeIndex = 0;
        } else if (_activeCommonsPracticeIndex >= practiceCount) {
          _activeCommonsPracticeIndex = practiceCount - 1;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commonsLoading = false;
        _commonsErrorMessage = 'Commons could not load. Pull back later.';
      });
    }
  }

  Future<void> _saveCommonsAnswer() async {
    if (_commonsAnswerSaving) return;
    final question = _activeCommonsQuestion();
    final body = _commonsAnswerController.text.trim();
    if (question.question.trim().isEmpty) {
      _showCommonsActionSnack('No Commons question is available today.');
      return;
    }
    if (body.isEmpty) {
      _showCommonsActionSnack('Write an answer before saving.');
      return;
    }
    setState(() => _commonsAnswerSaving = true);
    try {
      await _commonsRepo.answerQuestion(
        questionId: question.id,
        questionText: question.question,
        body: body,
      );
      if (!mounted) return;
      setState(() {
        _commonsAnswerSaving = false;
        _commonsAnswerEditing = false;
      });
      unawaited(_loadCommonsHome(force: true));
    } catch (e) {
      if (!mounted) return;
      setState(() => _commonsAnswerSaving = false);
      _showCommonsActionSnack(
        'Could not save your answer. Your draft stayed here.',
      );
    }
  }

  Future<void> _deleteCommonsAnswer(CommonsAnswer answer) async {
    if (_commonsAnswerDeleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0F),
        title: const Text(
          'Delete answer?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This removes your public Commons answer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _commonsAnswerDeleting = true);
    try {
      await _commonsRepo.deleteAnswer(answer.id);
      if (!mounted) return;
      _commonsAnswerController.clear();
      setState(() {
        _commonsAnswerDeleting = false;
        _commonsAnswerEditing = false;
      });
      unawaited(_loadCommonsHome(force: true));
    } catch (e) {
      if (!mounted) return;
      setState(() => _commonsAnswerDeleting = false);
      _showCommonsActionSnack('Could not delete that answer.');
    }
  }

  Future<void> _reportCommonsAnswer(CommonsAnswer answer) async {
    final ok = await _repo.reportContent(
      contentType: 'commons_question_answer',
      contentId: answer.id,
      reportedUserId: answer.userId,
      reason: 'user_report',
    );
    if (!mounted) return;
    _showCommonsActionSnack(ok ? 'Report sent.' : 'Could not send report.');
  }

  Future<void> _blockCommonsAnswerAuthor(CommonsAnswer answer) async {
    final ok = await _repo.blockUser(answer.userId);
    if (!mounted) return;
    _showCommonsActionSnack(ok ? 'User blocked.' : 'Could not block user.');
    if (ok) unawaited(_loadCommonsHome(force: true));
  }

  List<CommonsPracticeRoom> _commonsPracticeRooms() {
    final home = _commonsHome;
    if (home == null) return const <CommonsPracticeRoom>[];
    final rooms = <CommonsPracticeRoom>[];
    final seen = <String>{};
    for (final room in [
      ...home.mySharedPractices,
      ...home.publicSharedPractices,
    ]) {
      if (room.id.isEmpty || !seen.add(room.id)) continue;
      rooms.add(room);
    }
    return rooms;
  }

  Future<void> _updateCommonsPracticeVisibility(
    CommonsPracticeRoom room,
    SharedPracticeRoomVisibility visibility,
  ) async {
    if (_commonsVisibilityUpdatingRoomIds.contains(room.id)) return;
    setState(() => _commonsVisibilityUpdatingRoomIds.add(room.id));
    try {
      await _commonsRepo.setPracticeVisibility(
        roomId: room.id,
        visibility: visibility,
        joinPolicy: visibility == SharedPracticeRoomVisibility.public
            ? SharedPracticeJoinPolicy.ownerApproval
            : SharedPracticeJoinPolicy.closed,
      );
      if (!mounted) return;
      _showCommonsActionSnack('${visibility.label} visibility saved.');
      unawaited(_loadCommonsHome(force: true));
    } catch (e) {
      if (!mounted) return;
      _showCommonsActionSnack('Could not update that shared practice.');
    } finally {
      if (mounted) {
        setState(() => _commonsVisibilityUpdatingRoomIds.remove(room.id));
      }
    }
  }

  Future<void> _requestJoinCommonsPractice(CommonsPracticeRoom room) async {
    if (_commonsJoiningRoomIds.contains(room.id)) return;
    final controller = TextEditingController();
    final message = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0F),
        title: const Text('Ask to join', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 500,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Optional note',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: _profileGoldMid.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: _profileGoldMid),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (message == null) return;
    setState(() => _commonsJoiningRoomIds.add(room.id));
    try {
      final request = await _commonsRepo.requestJoinSharedPractice(
        roomId: room.id,
        message: message,
      );
      if (!mounted) return;
      _showCommonsActionSnack(
        request.status == 'approved'
            ? 'You joined this shared practice.'
            : 'Join request sent.',
      );
      unawaited(_loadCommonsHome(force: true));
    } catch (e) {
      if (!mounted) return;
      _showCommonsActionSnack('Could not send that join request.');
    } finally {
      if (mounted) {
        setState(() => _commonsJoiningRoomIds.remove(room.id));
      }
    }
  }

  void _maybeLoadMoreFeed() {
    if (_selectedFeedTab != _SocialFeedTab.forYou) return;
    if (!_feedRevealed || _feedLoading || _feedLoadingMore || !_feedHasMore) {
      return;
    }
    if (!_feedScrollController.hasClients) return;
    if (_feedScrollController.position.extentAfter > 720) return;
    unawaited(_loadFeedPage());
  }

  String _feedItemIdentity(ProfileFeedItem item) =>
      '${item.kind.name}:${item.id}';

  ProfileFeedItem? _findFeedItemByIdentity(
    Iterable<ProfileFeedItem> items,
    String identity,
  ) {
    for (final item in items) {
      if (_feedItemIdentity(item) == identity) {
        return item;
      }
    }
    return null;
  }

  Future<void> _expandFeedItem(ProfileFeedItem item) async {
    if (!_feedRevealed) return;
    final resolved =
        _findFeedItemByIdentity(_feedItems, _feedItemIdentity(item)) ?? item;
    unawaited(AppHaptics.mediumImpact(reason: 'profile_feed_expand_post'));
    if (mounted) {
      setState(() {
        _expandedFeedItem = resolved;
      });
      _scheduleContinuitySave();
    }
    if (_feedScrollController.hasClients) {
      unawaited(
        _feedScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  Future<void> _openCommonsDiscoverItem(ProfileFeedItem item) async {
    if (!_feedRevealed) return;
    if (_selectedFeedTab != _SocialFeedTab.forYou) {
      setState(() => _selectedFeedTab = _SocialFeedTab.forYou);
      _scheduleContinuitySave();
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
    }
    await _expandFeedItem(item);
  }

  void _collapseExpandedFeedItem() {
    if (!mounted || _expandedFeedItem == null) return;
    setState(() {
      _expandedFeedItem = null;
    });
    _scheduleContinuitySave();
  }

  String _normalizedFeedPhrase(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  Set<String> _feedTokensFromText(
    String value, {
    int minLength = 2,
    int? limit,
  }) {
    final tokens = <String>{};
    for (final match in RegExp(r'[a-z0-9]+').allMatches(value.toLowerCase())) {
      final token = match.group(0)!;
      if (token.length < minLength) continue;
      if (_profileFeedKeywordStopWords.contains(token)) continue;
      tokens.add(token);
      if (limit != null && tokens.length >= limit) break;
    }
    return tokens;
  }

  int _sharedTokenCount(Set<String> a, Set<String> b) {
    var count = 0;
    for (final token in a) {
      if (b.contains(token)) {
        count += 1;
      }
    }
    return count;
  }

  bool _containsAllTokens(Set<String> haystack, Set<String> needles) {
    if (needles.isEmpty) return false;
    for (final token in needles) {
      if (!haystack.contains(token)) {
        return false;
      }
    }
    return true;
  }

  List<Map<String, dynamic>> _flowRuleMaps(FlowPost post) {
    final rawRules = post.payloadJson?['rules'];
    final source = rawRules is List ? rawRules : post.rules;
    return source
        .whereType<Map>()
        .map((rule) => Map<String, dynamic>.from(rule))
        .toList();
  }

  List<Map<String, dynamic>> _flowPayloadEvents(FlowPost post) {
    final rawEvents = post.payloadJson?['events'];
    if (rawEvents is! List) return const [];
    return rawEvents
        .whereType<Map>()
        .map((event) => Map<String, dynamic>.from(event))
        .toList();
  }

  Set<String> _flowTokens(FlowPost post) {
    final tokens = <String>{};
    tokens.addAll(_feedTokensFromText(cleanFlowTitle(post.name)));
    tokens.addAll(_feedTokensFromText(cleanFlowOverview(post.notes)));
    tokens.addAll(_feedTokensFromText(cleanFlowDetail(post.notes)));
    for (final event in _flowPayloadEvents(post)) {
      tokens.addAll(
        _feedTokensFromText(cleanFlowTitle(event['title'] as String?)),
      );
      tokens.addAll(
        _feedTokensFromText(cleanFlowDetail(event['detail'] as String?)),
      );
      tokens.addAll(_feedTokensFromText((event['location'] as String?) ?? ''));
    }
    return tokens;
  }

  Set<String> _flowFocusTerms(FlowPost post) {
    final tokens = <String>{};
    tokens.addAll(_feedTokensFromText(cleanFlowTitle(post.name)));
    tokens.addAll(_feedTokensFromText(cleanFlowOverview(post.notes)));
    for (final token in _flowTokens(post)) {
      tokens.add(token);
      if (tokens.length >= 12) break;
    }
    return tokens;
  }

  Set<String> _insightTokens(InsightPost post) {
    final tokens = <String>{};
    tokens.addAll(_feedTokensFromText(post.nodeTitle));
    tokens.addAll(_feedTokensFromText(post.nodeId.replaceAll('-', ' ')));
    tokens.addAll(_feedTokensFromText(post.bodyText, limit: 18));
    return tokens;
  }

  Set<String> _insightFocusTerms(InsightPost post) {
    final tokens = <String>{};
    tokens.addAll(_feedTokensFromText(post.nodeTitle));
    tokens.addAll(_feedTokensFromText(post.nodeId.replaceAll('-', ' ')));
    for (final token in _feedTokensFromText(post.bodyText)) {
      tokens.add(token);
      if (tokens.length >= 12) break;
    }
    return tokens;
  }

  bool _sameInsightNode(InsightPost a, InsightPost b) {
    final aNodeId = a.nodeId.trim().toLowerCase();
    final bNodeId = b.nodeId.trim().toLowerCase();
    if (aNodeId.isNotEmpty && aNodeId == bNodeId) return true;
    final aTitle = _normalizedFeedPhrase(a.nodeTitle);
    final bTitle = _normalizedFeedPhrase(b.nodeTitle);
    return aTitle.isNotEmpty && aTitle == bTitle;
  }

  int _scoreRelatedFeedItem(
    ProfileFeedItem selected,
    ProfileFeedItem candidate,
  ) {
    if (_feedItemIdentity(selected) == _feedItemIdentity(candidate)) return 0;

    switch (selected.kind) {
      case ProfileFeedItemKind.insight:
        final selectedInsight = selected.insightPost!;
        final focusTerms = _insightFocusTerms(selectedInsight);
        if (candidate.kind == ProfileFeedItemKind.insight) {
          final candidateInsight = candidate.insightPost!;
          var score =
              _sharedTokenCount(focusTerms, _insightTokens(candidateInsight)) *
              18;
          if (_sameInsightNode(selectedInsight, candidateInsight)) {
            score += 220;
          }
          return score;
        }

        final candidateFlow = candidate.flowPost!;
        final flowTokens = _flowTokens(candidateFlow);
        var score = _sharedTokenCount(focusTerms, flowTokens) * 14;
        final nodeTitleTokens = _feedTokensFromText(selectedInsight.nodeTitle);
        if (_containsAllTokens(flowTokens, nodeTitleTokens)) {
          score += 72;
        }
        final nodeIdTokens = _feedTokensFromText(
          selectedInsight.nodeId.replaceAll('-', ' '),
        );
        if (_containsAllTokens(flowTokens, nodeIdTokens)) {
          score += 92;
        }
        return score;

      case ProfileFeedItemKind.flow:
        final selectedFlow = selected.flowPost!;
        final focusTerms = _flowFocusTerms(selectedFlow);
        if (candidate.kind == ProfileFeedItemKind.flow) {
          final candidateFlow = candidate.flowPost!;
          final candidateTokens = _flowTokens(candidateFlow);
          var score = _sharedTokenCount(focusTerms, candidateTokens) * 16;
          final titleTokens = _feedTokensFromText(
            cleanFlowTitle(selectedFlow.name),
          );
          if (_containsAllTokens(candidateTokens, titleTokens)) {
            score += 82;
          }
          return score;
        }

        final candidateInsight = candidate.insightPost!;
        final candidateTokens = _insightTokens(candidateInsight);
        var score = _sharedTokenCount(focusTerms, candidateTokens) * 12;
        final nodeTitleTokens = _feedTokensFromText(candidateInsight.nodeTitle);
        if (_containsAllTokens(focusTerms, nodeTitleTokens)) {
          score += 54;
        }
        return score;
    }
  }

  List<ProfileFeedItem> _rankRelatedFeedItems(
    ProfileFeedItem selected,
    ProfileFeedItemKind kind, {
    int limit = 6,
  }) {
    final scored = <({ProfileFeedItem item, int score})>[];
    final selectedIdentity = _feedItemIdentity(selected);
    final seen = <String>{};

    for (final item in _feedItems) {
      final identity = _feedItemIdentity(item);
      if (identity == selectedIdentity ||
          item.kind != kind ||
          !seen.add(identity)) {
        continue;
      }
      final score = _scoreRelatedFeedItem(selected, item);
      if (score <= 0) continue;
      scored.add((item: item, score: score));
    }

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return b.item.createdAt.compareTo(a.item.createdAt);
    });

    return [for (final entry in scored.take(limit)) entry.item];
  }

  List<ProfileFeedItem> _generalFeedFallback(
    ProfileFeedItem selected, {
    int limit = 8,
  }) {
    final selectedIdentity = _feedItemIdentity(selected);
    final results = <ProfileFeedItem>[];
    for (final item in _feedItems) {
      if (_feedItemIdentity(item) == selectedIdentity) continue;
      results.add(item);
      if (results.length >= limit) break;
    }
    return results;
  }

  String? _insightTopicLabel(InsightPost post) {
    final title = post.nodeTitle.trim();
    if (title.isNotEmpty && title.toLowerCase() != 'insight') {
      return title;
    }
    final focusTerms = _insightFocusTerms(post).toList();
    if (focusTerms.isEmpty) return null;
    return focusTerms.first;
  }

  List<_FeedRelatedSection> _relatedSectionsForFeedItem(
    ProfileFeedItem selected,
  ) {
    switch (selected.kind) {
      case ProfileFeedItemKind.insight:
        final post = selected.insightPost!;
        final topic = _insightTopicLabel(post);
        final relatedInsights = _rankRelatedFeedItems(
          selected,
          ProfileFeedItemKind.insight,
        );
        final relatedFlows = _rankRelatedFeedItems(
          selected,
          ProfileFeedItemKind.flow,
        );
        final sections = <_FeedRelatedSection>[
          if (relatedInsights.isNotEmpty)
            _FeedRelatedSection(
              title: 'Related Insights',
              subtitle: topic == null
                  ? 'More insights on the same thread.'
                  : 'More insights touching $topic.',
              items: relatedInsights,
            ),
          if (relatedFlows.isNotEmpty)
            _FeedRelatedSection(
              title: 'Relevant Flows',
              subtitle: topic == null
                  ? 'Flows that echo this idea.'
                  : 'Flows that echo $topic.',
              items: relatedFlows,
            ),
        ];
        if (sections.isNotEmpty) return sections;

        final fallback = _generalFeedFallback(selected);
        if (fallback.isEmpty) return const [];
        return [
          _FeedRelatedSection(
            title: 'More From The Feed',
            subtitle: 'No close match yet. Browse the nearest posts instead.',
            items: fallback,
          ),
        ];

      case ProfileFeedItemKind.flow:
        final post = selected.flowPost!;
        final title = cleanFlowTitle(post.name);
        final relatedFlows = _rankRelatedFeedItems(
          selected,
          ProfileFeedItemKind.flow,
        );
        final relatedInsights = _rankRelatedFeedItems(
          selected,
          ProfileFeedItemKind.insight,
        );
        final sections = <_FeedRelatedSection>[
          if (relatedFlows.isNotEmpty)
            _FeedRelatedSection(
              title: 'Similar Flows',
              subtitle: title.isEmpty
                  ? 'Flows carrying a similar cadence or theme.'
                  : 'Flows carrying a similar cadence to $title.',
              items: relatedFlows,
            ),
          if (relatedInsights.isNotEmpty)
            _FeedRelatedSection(
              title: 'Related Insights',
              subtitle: title.isEmpty
                  ? 'Insights linked to this flow’s language.'
                  : 'Insights linked to $title.',
              items: relatedInsights,
            ),
        ];
        if (sections.isNotEmpty) return sections;

        final fallback = _generalFeedFallback(selected);
        if (fallback.isEmpty) return const [];
        return [
          _FeedRelatedSection(
            title: 'More From The Feed',
            subtitle: 'No close match yet. Browse the next nearest posts.',
            items: fallback,
          ),
        ];
    }
  }

  int _clampPostIndex(int length, [int? desired]) {
    if (length == 0) return 0;
    final target = desired ?? _activePostIndex;
    if (target < 0) return 0;
    if (target >= length) return length - 1;
    return target;
  }

  int _clampInsightPostIndex(int length, [int? desired]) {
    if (length == 0) return 0;
    final target = desired ?? _activeInsightPostIndex;
    if (target < 0) return 0;
    if (target >= length) return length - 1;
    return target;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _toggleFollow() async {
    if (_followUpdating || _isViewingOwnProfile) return;
    setState(() => _followUpdating = true);

    final success = _isFollowing
        ? await _repo.unfollowUser(widget.userId)
        : await _repo.followUser(widget.userId);

    if (!success) {
      _showError('Could not update follow status. Please try again.');
    } else {
      await _loadProfile(showSpinner: false);
    }

    if (mounted) {
      setState(() => _followUpdating = false);
    }
  }

  Future<void> _reportProfile() async {
    if (_profileSafetyUpdating || _isViewingOwnProfile) return;
    setState(() => _profileSafetyUpdating = true);
    final ok = await _repo.reportContent(
      contentType: 'profile',
      contentId: widget.userId,
      reportedUserId: widget.userId,
      reason: 'user_report',
    );
    if (!mounted) return;
    setState(() => _profileSafetyUpdating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Report sent.'
              : 'Could not send report. Please contact support.',
        ),
        backgroundColor: ok ? _profileGoldBase : Colors.red,
      ),
    );
  }

  Future<void> _confirmBlockProfile() async {
    if (_profileSafetyUpdating || _isViewingOwnProfile) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0F),
        title: const Text('Block user?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Their posts and comments will be hidden from your refreshed feeds.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Block user'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _blockProfile();
  }

  Future<void> _blockProfile() async {
    setState(() => _profileSafetyUpdating = true);
    final ok = await _repo.blockUser(widget.userId);
    if (!mounted) return;
    setState(() => _profileSafetyUpdating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'User blocked.'
              : 'Could not block user. Please contact support.',
        ),
        backgroundColor: ok ? _profileGoldBase : Colors.red,
      ),
    );
    if (ok) {
      context.go('/profile/me');
    }
  }

  Future<void> _openCalendarQuickAdd() async {
    await CalendarPage.openQuickAddFromAnyContext(context);
  }

  Future<void> _openMyProfileAction() async {
    NavigationTrace.instance.record('Profile app-bar tap fired');
    if (_isViewingOwnProfile) return;

    await CalendarPage.openProfileFromAnyContext(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_buildTraceRecorded) {
      _buildTraceRecorded = true;
      NavigationTrace.instance.record(
        'ProfilePage build first frame',
        state: _navigationTraceProfileState(),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NavigationTrace.instance.record(
          'ProfilePage first frame completed',
          state: _navigationTraceProfileState(),
        );
      });
    }
    final loadingProfileShell =
        _profile == null && (_cacheHydrating || _loading);
    final showBackdrop = _profile != null || loadingProfileShell;
    final title = _profile?.handle ?? 'Profile';
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey<Object>(
          loadingProfileShell
              ? 'profile_loading_shell'
              : _profile == null
              ? 'profile_missing'
              : _feedRevealed
              ? 'profile_feed_mode'
              : 'profile_mode',
        ),
        child: loadingProfileShell
            ? _buildProfileLoadingShell()
            : _profile == null
            ? _buildNoProfile()
            : _feedRevealed
            ? _buildFeedMode()
            : _buildProfile(),
      ),
    );
    final appBarBackground = _feedRevealed
        ? const Color(0xFF000000)
        : showBackdrop
        ? Colors.transparent
        : const Color(0xFF000000);
    final appBarSystemOverlayStyle = _feedRevealed
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: const Color(0xFF000000),
          )
        : SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
          );

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      extendBodyBehindAppBar: showBackdrop && !_feedRevealed,
      appBar: AppBar(
        backgroundColor: appBarBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: appBarSystemOverlayStyle,
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: _profileGoldIcon(Icons.close),
          onPressed: () => popOrGo(context, '/'),
        ),
        title: _feedRevealed
            ? _buildFeedDateModeToggle()
            : Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
        actions: [
          KemeticAppBarAction(
            tooltip: 'New note',
            icon: _profileGoldIcon(Icons.add, size: 23),
            onPressed: () {
              unawaited(_openCalendarQuickAdd());
            },
          ),
          KemeticAppBarAction(
            tooltip: 'Search notes',
            icon: const KemeticAppBarSearchIcon(gradient: _profileGoldGradient),
            onPressed: () {
              unawaited(CalendarPage.openSearchFromAnyContext(context));
            },
          ),
          KemeticAppBarAction(
            tooltip: 'Today',
            icon: const KemeticAppBarTodayIcon(gradient: _profileGoldGradient),
            onPressed: () {
              NavigationTrace.instance.record('Today app-bar tap fired');
              CalendarPage.openMainCalendarAtToday(context);
            },
          ),
          if (_feedRevealed)
            KemeticAppBarAction(
              tooltip: 'Profile',
              icon: const KemeticAppBarProfileIcon(),
              onPressed: () {
                NavigationTrace.instance.record('Profile app-bar tap fired');
                unawaited(_closeFeed());
              },
            )
          else if (!_isViewingOwnProfile)
            KemeticAppBarAction(
              tooltip: 'My Profile',
              icon: const KemeticAppBarProfileIcon(),
              onPressed: _openMyProfileAction,
            ),
          const SizedBox(width: 20),
        ],
      ),
      body: Stack(
        children: [
          if (showBackdrop) ...[
            const Positioned.fill(child: ProfileDayCycleBackdrop()),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                        const Color(0xFF000000),
                      ],
                      stops: const [0.0, 0.22, 0.58, 0.8],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top + kToolbarHeight + 24,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.72),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          body,
        ],
      ),
    );
  }

  Widget _profileSkeletonBar({
    required double widthFactor,
    double height = 14,
    double radius = 999,
  }) {
    return Align(
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
        ),
      ),
    );
  }

  Widget _profileSkeletonTile({double minHeight = 92}) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _profileGoldMid.withValues(alpha: 0.16)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _profileSkeletonBar(widthFactor: 0.42, height: 22),
          const SizedBox(height: 10),
          _profileSkeletonBar(widthFactor: 0.66, height: 12),
        ],
      ),
    );
  }

  Widget _buildProfileLoadingShell() {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final height = MediaQuery.sizeOf(context).height;
    final heroHeight = (height * 0.54).clamp(420.0, 560.0);
    const bottomPadding = 32.0;

    return SingleChildScrollView(
      controller: _profileScrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: heroHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _profileSkeletonBar(widthFactor: 0.46, height: 34),
                  const SizedBox(height: 10),
                  _profileSkeletonBar(widthFactor: 0.32, height: 16),
                  const SizedBox(height: 18),
                  Container(
                    height: 74,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: _profileGoldMid.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Center(
                      child: _profileSkeletonBar(widthFactor: 0.44, height: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 460;
                    final spacing = 10.0;
                    final columns = compact ? 2 : 4;
                    final itemWidth =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (var i = 0; i < 4; i++)
                          SizedBox(
                            width: itemWidth,
                            child: _profileSkeletonTile(
                              minHeight: compact ? 82 : 92,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < (_isViewingOwnProfile ? 2 : 1); i++)
                      Container(
                        width: _isViewingOwnProfile ? 146 : 132,
                        height: useExpandedTouchTargets(context)
                            ? kMinInteractiveDimension
                            : 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _profileGoldMid.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Center(
                          child: _profileSkeletonBar(
                            widthFactor: 0.56,
                            height: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.only(top: 18),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: _profileGoldMid.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _profileSkeletonBar(widthFactor: 0.34, height: 16),
                      const SizedBox(height: 12),
                      _profileSkeletonTile(minHeight: 130),
                      const SizedBox(height: 22),
                      _profileSkeletonBar(widthFactor: 0.38, height: 16),
                      const SizedBox(height: 12),
                      _profileSkeletonTile(minHeight: 130),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoProfile() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Profile not found',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    final profile = _profile!;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final height = MediaQuery.sizeOf(context).height;
    final heroHeight = (height * 0.72).clamp(560.0, 680.0);
    final bio = profile.bio?.trim() ?? '';
    const bottomPadding = 32.0;

    return SingleChildScrollView(
      controller: _profileScrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
            key: _profileBasicsOnboardingKey,
            child: _buildHeroSection(
              profile,
              topInset: topInset,
              height: heroHeight,
              bio: bio,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.only(top: 18),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: _profileGoldMid.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  child: _buildPostsSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedMode() {
    const bottomPadding = 32.0;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleFeedScrollNotification,
      child: CustomScrollView(
        controller: _feedScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverToBoxAdapter(child: _buildFeedHeader()),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _ProfileFeedTabsHeaderDelegate(
              extent: _profileFeedTabsHeaderExtent,
              child: _buildPinnedSocialFeedTabs(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, bottomPadding),
            sliver: SliverToBoxAdapter(child: _buildFeedBloomPanel()),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(
    UserProfile profile, {
    required double topInset,
    required double height,
    required String bio,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topInset + 72, 20, 28),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (profile.handle != null &&
                    profile.handle!.trim().isNotEmpty) ...[
                  Text(
                    '@${profile.handle}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  profile.effectiveName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w600,
                    height: 0.96,
                    fontFamily: _profileSerifFont,
                    fontFamilyFallback: _profileSerifFallback,
                    shadows: [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 18,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                if (profile.avatarGlyphIds.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _buildGlyphSignature(profile),
                ],
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      height: 1.32,
                      fontFamily: _profileSerifFont,
                      fontFamilyFallback: _profileSerifFallback,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _buildStats(profile),
                const SizedBox(height: 18),
                _buildActionCluster(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileGoldTextWidget(
    String text, {
    required TextStyle style,
    int? maxLines,
    TextOverflow? overflow,
    bool? softWrap,
    TextAlign? textAlign,
  }) {
    return GlossyText(
      text: text,
      style: style,
      gradient: _profileGoldGradient,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textAlign: textAlign,
    );
  }

  Widget _profileGoldIcon(IconData icon, {double? size}) {
    return GlossyIcon(icon: icon, gradient: _profileGoldGradient, size: size);
  }

  Widget _buildGlyphSignature(UserProfile profile) {
    final glyphs = profileGlyphPhraseGlyphs(profile.avatarGlyphIds);
    final meaning = profileGlyphPhraseMeaning(profile.avatarGlyphIds);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: _profileGoldMid.withValues(alpha: 0.26)),
            bottom: BorderSide(color: _profileGoldMid.withValues(alpha: 0.26)),
          ),
        ),
        child: Column(
          children: [
            Text(
              glyphs,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _profileGoldText,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.1,
                fontFamily: 'GentiumPlus',
                fontFamilyFallback: [
                  'Noto Sans Egyptian Hieroglyphs',
                  'Apple Symbols',
                  'Segoe UI Symbol',
                  'Arial Unicode MS',
                  'NotoSans',
                ],
              ),
            ),
            if (meaning.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                meaning,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStats(UserProfile profile) {
    final stats = [
      (
        label: 'Followers',
        value: (profile.followersCount ?? 0).toString(),
        onTap: () => _openFollowList(profile, FollowListType.followers),
        enabled: true,
      ),
      (
        label: 'Following',
        value: (profile.followingCount ?? 0).toString(),
        onTap: () => _openFollowList(profile, FollowListType.following),
        enabled: true,
      ),
      (
        label: 'Active Flows',
        value: (profile.activeFlowsCount ?? 0).toString(),
        onTap: _onActiveFlowsTap,
        enabled: _isViewingOwnProfile,
      ),
      (
        label: 'Flow Events',
        value: (profile.totalFlowEventsCount ?? 0).toString(),
        onTap: null,
        enabled: true,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _profileGoldMid.withValues(alpha: 0.18)),
          bottom: BorderSide(color: _profileGoldMid.withValues(alpha: 0.18)),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var index = 0; index < stats.length; index++) ...[
            if (index > 0)
              Container(
                width: 1,
                height: 44,
                color: _profileGoldMid.withValues(alpha: 0.16),
              ),
            Expanded(
              child: _buildStatItem(
                label: stats[index].label,
                value: stats[index].value,
                onTap: stats[index].onTap,
                enabled: stats[index].enabled,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    final numberColor = enabled
        ? _profileGoldText
        : _profileGoldBase.withValues(alpha: 0.6);
    final labelColor = enabled
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(3),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: numberColor,
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      fontFamily: _profileSerifFont,
                      fontFamilyFallback: _profileSerifFallback,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFeedAuthorProfile(String userId) async {
    final trimmed = userId.trim();
    if (!mounted || trimmed.isEmpty) return;
    if (trimmed == widget.userId) {
      await _closeFeed();
      return;
    }
    unawaited(
      openDetailRoute<void>(
        context,
        '/profile/${Uri.encodeComponent(trimmed)}',
      ),
    );
  }

  void _openFollowList(UserProfile profile, FollowListType type) {
    final segment = type == FollowListType.followers
        ? 'followers'
        : 'following';
    unawaited(
      openDetailRoute<void>(
        context,
        '/profile/${Uri.encodeComponent(profile.id)}/$segment',
      ),
    );
  }

  void _onActiveFlowsTap() {
    if (!_isViewingOwnProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only view your own active flows.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    unawaited(CalendarPage.openMyFlowsFromAnyContext(context));
  }

  Widget _buildFollowButton({bool fullWidth = false}) {
    final isFollowing = _isFollowing;
    return _buildActionButton(
      label: isFollowing ? 'Following' : 'Follow',
      icon: isFollowing
          ? Icons.check_circle_outline_rounded
          : Icons.person_add_alt_1_rounded,
      onPressed: _followUpdating ? null : _toggleFollow,
      filled: !isFollowing,
      busy: _followUpdating,
      backgroundColor: isFollowing ? const Color(0xFF0B0B0E) : _profileGoldBase,
      foregroundColor: isFollowing ? _profileGoldText : const Color(0xFF1C1204),
      borderColor: _profileGoldMid,
      fullWidth: fullWidth,
    );
  }

  Widget _buildProfileSafetyMenu() {
    return SizedBox(
      width: 46,
      height: useExpandedTouchTargets(context) ? kMinInteractiveDimension : 40,
      child: OutlinedButton(
        onPressed: _profileSafetyUpdating
            ? null
            : () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: const Color(0xFF0D0D0F),
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.flag_outlined,
                            color: Colors.white70,
                          ),
                          title: const Text(
                            'Report user',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            _reportProfile();
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.block,
                            color: Colors.redAccent,
                          ),
                          title: const Text(
                            'Block user',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            _confirmBlockProfile();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: _profileGoldText,
          side: BorderSide(color: _profileGoldMid.withValues(alpha: 0.42)),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: _profileSafetyUpdating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_profileGoldText),
                ),
              )
            : _profileGoldIcon(Icons.more_horiz_rounded, size: 20),
      ),
    );
  }

  Widget _buildEditButton({bool fullWidth = false}) {
    return _buildActionButton(
      label: 'Edit Profile',
      icon: Icons.edit_outlined,
      onPressed: () {
        unawaited(openDetailRoute<void>(context, '/profile/me/edit'));
      },
      filled: true,
      backgroundColor: _profileGoldBase,
      foregroundColor: const Color(0xFF1C1204),
      borderColor: _profileGoldMid,
      fullWidth: fullWidth,
    );
  }

  Widget _buildFindPeopleButton({bool fullWidth = false}) {
    return _buildActionButton(
      label: 'Find People',
      icon: Icons.people_outline_rounded,
      onPressed: () {
        unawaited(openDetailRoute<void>(context, '/profile-search'));
      },
      foregroundColor: _profileGoldText,
      borderColor: _profileGoldMid.withValues(alpha: 0.42),
      fullWidth: fullWidth,
    );
  }

  Widget _buildPostFlowButton({bool fullWidth = false}) {
    return _buildActionButton(
      label: 'Post Flow',
      icon: Icons.upload_rounded,
      onPressed: _openPostPicker,
      foregroundColor: _profileGoldText,
      borderColor: _profileGoldMid.withValues(alpha: 0.42),
      fullWidth: fullWidth,
    );
  }

  Widget _buildPostInsightButton({bool fullWidth = false}) {
    return _buildActionButton(
      label: 'Post Insight',
      icon: Icons.auto_stories_outlined,
      onPressed: _openInsightPostPicker,
      foregroundColor: _profileGoldText,
      borderColor: _profileGoldMid.withValues(alpha: 0.42),
      fullWidth: fullWidth,
    );
  }

  Widget _buildActionCluster() {
    if (!_isViewingOwnProfile) {
      return Row(
        children: [
          Expanded(child: _buildFollowButton(fullWidth: true)),
          const SizedBox(width: 8),
          _buildProfileSafetyMenu(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEditButton(fullWidth: true),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildFindPeopleButton(fullWidth: true)),
            const SizedBox(width: 8),
            Expanded(child: _buildPostFlowButton(fullWidth: true)),
          ],
        ),
        const SizedBox(height: 8),
        _buildPostInsightButton(fullWidth: true),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool filled = false,
    bool busy = false,
    Color foregroundColor = _profileGoldText,
    Color backgroundColor = const Color(0xFF0B0B0E),
    Color borderColor = _profileGoldMid,
    bool fullWidth = false,
  }) {
    final buttonHeight = useExpandedTouchTargets(context)
        ? kMinInteractiveDimension
        : 40.0;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        else
          Icon(icon, size: 17),
        const SizedBox(width: 8),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: _profileSerifFont,
            fontFamilyFallback: _profileSerifFallback,
          ),
        ),
      ],
    );

    final buttonContent = fullWidth
        ? SizedBox(
            width: double.infinity,
            height: buttonHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: child,
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: child,
          );

    if (filled) {
      final radius = BorderRadius.circular(3);
      final interactive = Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: _profileGoldGradient,
            borderRadius: radius,
            border: Border.all(
              color: _profileGoldLight.withValues(alpha: 0.52),
            ),
            boxShadow: [
              BoxShadow(
                color: _profileGoldDeep.withValues(alpha: 0.34),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: DefaultTextStyle(
              style: TextStyle(color: foregroundColor),
              child: IconTheme(
                data: IconThemeData(color: foregroundColor),
                child: buttonContent,
              ),
            ),
          ),
        ),
      );
      return withMinimumTouchTarget(
        context,
        interactive,
        alignment: Alignment.center,
        fallback: BoxConstraints(minHeight: buttonHeight),
      );
    }

    final radius = BorderRadius.circular(3);
    final interactive = Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: radius,
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: DefaultTextStyle(
            style: TextStyle(color: foregroundColor),
            child: IconTheme(
              data: IconThemeData(color: foregroundColor),
              child: buttonContent,
            ),
          ),
        ),
      ),
    );
    return withMinimumTouchTarget(
      context,
      interactive,
      alignment: Alignment.center,
      fallback: BoxConstraints(minHeight: buttonHeight),
    );
  }

  Widget _buildPostsSection() {
    final hasMultiplePosts = _posts.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Posted Flows',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (!_postsLoading && hasMultiplePosts)
              Text(
                '${_activePostIndex + 1} / ${_posts.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPostedFlowPreview(),
        const SizedBox(height: 22),
        _buildPostedInsightsSection(),
        const SizedBox(height: 18),
        _buildFeedRevealHint(),
      ],
    );
  }

  Widget _buildPostedInsightsSection() {
    final hasMultiplePosts = _insightPosts.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Posted Insights',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (!_insightPostsLoading && hasMultiplePosts)
              Text(
                '${_activeInsightPostIndex + 1} / ${_insightPosts.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPostedInsightPreview(),
      ],
    );
  }

  Widget _buildPostedFlowPreview() {
    if (_postsLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_profileGoldMid),
        ),
      );
    }

    if (_posts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0F),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _profileGoldMid.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isViewingOwnProfile
                  ? 'Nothing posted yet'
                  : 'No posted flows yet',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isViewingOwnProfile
                  ? 'Post a flow to share it on your profile.'
                  : 'Check back later for posted flows.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final hasMultiplePosts = _posts.length > 1;
    if (!hasMultiplePosts) {
      return _buildPostCard(_posts.first, onTap: () => _openPostDetails(0));
    }

    final pagerHeight = _postPagerHeight(context);
    return Column(
      children: [
        SizedBox(
          height: pagerHeight,
          child: PageView.builder(
            controller: _postPageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _posts.length,
            onPageChanged: (index) {
              setState(() {
                _activePostIndex = index;
              });
              _scheduleContinuitySave();
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildPostCard(
                  _posts[index],
                  onTap: () => _openPostDetails(index),
                  inPager: true,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < _posts.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _activePostIndex == i ? 18 : 8,
                decoration: BoxDecoration(
                  color: _activePostIndex == i
                      ? _profileGoldMid
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
          ],
        ),
      ],
    );
  }

  double _postPagerHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    double height;
    if (width < 360) {
      height = 336;
    } else if (width < 390) {
      height = 320;
    } else if (width < 430) {
      height = 304;
    } else {
      height = 286;
    }

    if (textScale > 1.05) height += 18;
    if (textScale > 1.15) height += 18;
    return height;
  }

  Widget _buildFeedDateModeToggle() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleFeedDateMode,
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GlossyText(
            text: 'ḥꜣw',
            gradient: _showGregorianFeedDates ? whiteGloss : goldGloss,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 0,
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
        ),
      ),
    );
  }

  Widget _buildPostedInsightPreview() {
    if (_insightPostsLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_profileGoldMid),
        ),
      );
    }

    if (_insightPosts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0F),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _profileGoldMid.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'No posted insights yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isViewingOwnProfile
                  ? 'Write an insight inside a node page, then post it here.'
                  : 'Check back later for posted insights.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final hasMultiplePosts = _insightPosts.length > 1;
    if (!hasMultiplePosts) {
      return _buildInsightPostCard(
        _insightPosts.first,
        onReadMore: () => _openInsightPost(_insightPosts.first),
      );
    }

    final pagerHeight = _postPagerHeight(context);
    return Column(
      children: [
        SizedBox(
          height: pagerHeight,
          child: PageView.builder(
            controller: _insightPostPageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _insightPosts.length,
            onPageChanged: (index) {
              setState(() {
                _activeInsightPostIndex = index;
              });
              _scheduleContinuitySave();
            },
            itemBuilder: (context, index) {
              final post = _insightPosts[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildInsightPostCard(
                  post,
                  onReadMore: () => _openInsightPost(post),
                  inPager: true,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < _insightPosts.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _activeInsightPostIndex == i ? 18 : 8,
                decoration: BoxDecoration(
                  color: _activeInsightPostIndex == i
                      ? _profileGoldMid
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedRevealHint() {
    return GestureDetector(
      key: _feedRevealHintKey,
      onTap: () {
        unawaited(_revealFeed());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: _profileGoldText.withValues(alpha: 0.8),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              'Swipe up to reveal feed',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedHeader() {
    final isCommons = _selectedFeedTab == _SocialFeedTab.todaysCommons;
    return AnimatedBuilder(
      animation: _feedBloomController,
      builder: (context, child) {
        final opacity = Curves.easeOutCubic.transform(
          _feedBloomController.value.clamp(0.0, 1.0),
        );
        final y = (1 - opacity) * 18;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(offset: Offset(0, y), child: child),
        );
      },
      child: Column(
        key: const ValueKey('feed_header'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _profileGoldTextWidget(
            isCommons ? 'Commons' : 'For You',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            isCommons
                ? 'What practitioners are restoring across the rhythm.'
                : 'Flows and insights chosen for your rhythm.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _profileGoldText.withValues(alpha: 0.8),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Pull down at the top to return to profile',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectFeedTab(_SocialFeedTab tab) async {
    if (_selectedFeedTab == tab) return;
    unawaited(AppHaptics.lightImpact(reason: 'profile_social_feed_tab'));
    setState(() {
      _selectedFeedTab = tab;
      if (tab == _SocialFeedTab.todaysCommons) {
        _expandedFeedItem = null;
      }
    });
    _scheduleContinuitySave();
    if (_feedItems.isEmpty && !_feedLoading) {
      unawaited(_loadFeedPage(reset: true));
    }
    if (tab == _SocialFeedTab.todaysCommons &&
        _commonsHome == null &&
        !_commonsLoading) {
      await _loadCommonsHome();
    }
  }

  Widget _buildSocialFeedTabs() {
    return Row(
      children: [
        Expanded(
          child: _buildSocialFeedTabButton(
            tab: _SocialFeedTab.todaysCommons,
            label: 'COMMONS',
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _buildSocialFeedTabButton(
            tab: _SocialFeedTab.forYou,
            label: 'FOR YOU',
          ),
        ),
      ],
    );
  }

  Widget _buildPinnedSocialFeedTabs() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.34),
            Colors.black.withValues(alpha: 0.16),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: _profileGoldMid.withValues(alpha: 0.10)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Align(
          alignment: Alignment.center,
          child: _buildSocialFeedTabs(),
        ),
      ),
    );
  }

  Widget _buildSocialFeedTabButton({
    required _SocialFeedTab tab,
    required String label,
  }) {
    final selected = _selectedFeedTab == tab;
    final color = selected
        ? _profileGoldText
        : Colors.white.withValues(alpha: 0.52);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => unawaited(_selectFeedTab(tab)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 1.5,
              width: selected ? 96 : 0,
              decoration: BoxDecoration(
                color: _profileGoldText.withValues(alpha: selected ? 0.9 : 0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedBloomPanel() {
    final opacityCurve = CurvedAnimation(
      parent: _feedBloomController,
      curve: const Interval(0.0, 0.78, curve: Curves.easeOutCubic),
    );
    final scaleCurve = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.92,
          end: 1.035,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 44,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.035,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 56,
      ),
    ]).animate(_feedBloomController);

    final panelChild = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -92,
          left: -28,
          right: -28,
          height: 220,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _feedBloomController,
              builder: (context, child) {
                final scale = 0.84 + (_feedBloomController.value * 0.44);
                return Transform.scale(scale: scale, child: child);
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.25,
                    colors: [
                      _profileGoldLight.withValues(alpha: 0.22),
                      _profileGoldMid.withValues(alpha: 0.14),
                      _profileGoldDeep.withValues(alpha: 0.09),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.34, 0.58, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _profileGoldMid.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _selectedFeedTab == _SocialFeedTab.todaysCommons
                    ? KeyedSubtree(
                        key: const ValueKey('todays_commons'),
                        child: _buildTodaysCommonsView(),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('for_you_feed'),
                        child: _buildForYouFeedView(),
                      ),
              ),
            ],
          ),
        ),
      ],
    );

    return AnimatedBuilder(
      animation: _feedBloomController,
      builder: (context, child) {
        final opacity = opacityCurve.value.clamp(0.0, 1.0);
        final y = (1 - opacity) * 28;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, y),
            child: Transform.scale(
              scale: scaleCurve.value,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: panelChild,
    );
  }

  Widget _buildForYouFeedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_feedLoading && _feedItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_profileGoldMid),
              ),
            ),
          )
        else if (_feedErrorMessage != null && _feedItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: _profileGoldText.withValues(alpha: 0.72),
                  size: 28,
                ),
                const SizedBox(height: 10),
                const Text(
                  'For You could not load',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _feedErrorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _feedLoading
                      ? null
                      : () => unawaited(_loadFeedPage(reset: true)),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _profileGoldText,
                    side: BorderSide(
                      color: _profileGoldText.withValues(alpha: 0.74),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_feedItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                Icon(
                  Icons.auto_awesome_motion_rounded,
                  color: _profileGoldText.withValues(alpha: 0.72),
                  size: 28,
                ),
                const SizedBox(height: 10),
                const Text(
                  'No recommendations yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'As more flows and insights get posted, they will surface here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _expandedFeedItem == null
                ? KeyedSubtree(
                    key: const ValueKey('for_you_grid'),
                    child: _buildFeedGrid(_feedItems),
                  )
                : KeyedSubtree(
                    key: ValueKey(
                      'for_you_expanded_${_feedItemIdentity(_expandedFeedItem!)}',
                    ),
                    child: _buildExpandedFeedView(_expandedFeedItem!),
                  ),
          ),
        if (_feedLoadingMore) ...[
          const SizedBox(height: 12),
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(_profileGoldMid),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTodaysCommonsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCommonsMasthead(),
        _buildCommonsRhythmSection(),
        _buildCommonsQuestionSection(),
        _buildCommonsReflectionSection(),
        _buildCommonsPracticeTogetherSection(),
        _buildCommonsDiscoverSection(),
      ],
    );
  }

  String _plural(int count, String singular, [String? plural]) {
    return count == 1 ? singular : plural ?? '${singular}s';
  }

  String _withoutWrappingQuotes(String value) {
    var text = value.trim();
    while (text.length >= 2) {
      final first = text.characters.first;
      final last = text.characters.last;
      final wrapped =
          (first == '"' && last == '"') ||
          (first == "'" && last == "'") ||
          (first == '“' && last == '”') ||
          (first == '‘' && last == '’');
      if (!wrapped) break;
      text = text.substring(first.length, text.length - last.length).trim();
    }
    return text;
  }

  String _compactInsightText(String value, {int maxLength = 150}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength).trimRight()}...';
  }

  List<InsightPost> _commonsInsightFragments() {
    final homeFragments = _commonsHome?.fragments ?? const <InsightPost>[];
    if (homeFragments.isNotEmpty) {
      final posts = List<InsightPost>.from(homeFragments)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts.take(3).toList(growable: false);
    }

    final byId = <String, InsightPost>{};
    for (final post in _insightPosts) {
      if (post.bodyText.trim().isNotEmpty) {
        byId[post.id] = post;
      }
    }
    for (final item in _feedItems) {
      if (item.kind != ProfileFeedItemKind.insight) continue;
      final post = item.insightPost!;
      if (post.bodyText.trim().isNotEmpty) {
        byId.putIfAbsent(post.id, () => post);
      }
    }
    final posts = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts.take(3).toList(growable: false);
  }

  List<ProfileFeedItem> _commonsDiscoverItems() {
    final homeDiscover = _commonsHome?.discover ?? const <ProfileFeedItem>[];
    if (homeDiscover.isNotEmpty) {
      return homeDiscover.take(3).toList(growable: false);
    }
    return _feedItems.take(3).toList(growable: false);
  }

  void _openJournalForCommonsQuestion() {
    context.go('/journal');
  }

  void _openFlowsForCommons() {
    context.go('/flows');
  }

  Future<void> _openPracticeTogetherForFlowPost(FlowPost post) async {
    final sourceFlowId = post.sourceFlowId;
    if (sourceFlowId == null || sourceFlowId <= 0) {
      _showCommonsActionSnack('This flow cannot be practiced together yet.');
      return;
    }
    final title = cleanFlowTitle(post.name);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id.trim();
    final authorUserId = post.userId.trim();
    if (currentUserId != null &&
        currentUserId.isNotEmpty &&
        authorUserId.isNotEmpty &&
        authorUserId != currentUserId) {
      try {
        final result = await SharedPracticeRepo(Supabase.instance.client)
            .createJointFlowExperienceFromCommons(
              sourceFlowId: sourceFlowId,
              participantUserIds: <String>[authorUserId],
              calendarTitle: title.isEmpty ? 'Shared Practice' : title,
              context: <String, dynamic>{
                'flow_post_id': post.id,
                'source': 'profile_flow_post',
              },
            );
        if (!mounted || result.sharedPracticeRoomId.trim().isEmpty) return;
        context.push(
          '/shared-practice/${Uri.encodeComponent(result.sharedPracticeRoomId.trim())}',
        );
      } catch (_) {
        if (!mounted) return;
        _showCommonsActionSnack('Could not start shared practice.');
      }
      return;
    }

    final roomId = await showSharedPracticeCalendarChooser(
      context: context,
      sourceFlowId: sourceFlowId,
      flowTitle: title.isEmpty ? 'Ma\'at Flow' : title,
      stepCount: _flowPayloadEvents(post).length,
    );
    if (!mounted || roomId == null || roomId.trim().isEmpty) return;
    context.push('/shared-practice/${Uri.encodeComponent(roomId.trim())}');
  }

  Widget _buildCommonsRhythmSection() {
    final rhythm = _commonsHome?.rhythm;
    if (_commonsLoading && rhythm == null) {
      return _buildCommonsSection(
        numeral: 'I',
        title: 'Public Rhythm',
        children: [
          _buildCommonsPulseRow(
            count: '...',
            text: 'the public rhythm is loading',
            quiet: true,
          ),
        ],
      );
    }

    final summary = rhythm ?? CommonsRhythmSummary.empty();
    return _buildCommonsSection(
      numeral: 'I',
      title: 'Public Rhythm',
      note: _commonsErrorMessage,
      children: [
        _buildCommonsPulseRow(
          count: summary.activeUsersTodayLabel,
          text: 'people kept a Ma\'at flow today.',
        ),
        _buildCommonsPulseRow(
          count: summary.flowsKeptTodayLabel,
          text: 'flow steps were recorded in public rhythm.',
        ),
        _buildCommonsPulseRow(
          count: summary.publicFragmentsTodayLabel,
          text: 'public fragments were shared.',
          quiet: summary.publicFragmentsTodayLabel == '0',
        ),
        _buildCommonsPulseRow(
          count: summary.publicRoomsOpenLabel,
          text: 'public practices are open to join.',
          quiet: summary.publicRoomsOpenLabel == '0',
        ),
        if (summary.topFlowTitle?.trim().isNotEmpty == true)
          _buildCommonsPulseRow(
            count: summary.topFlowCountLabel ?? '',
            text: 'most active flow today: ${summary.topFlowTitle}.',
          ),
      ],
    );
  }

  Widget _buildCommonsMasthead() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        children: [
          Text(
            '𓇳 𓏤 𓆄',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _profileGoldText.withValues(alpha: 0.62),
              fontSize: 16,
              letterSpacing: 5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatPostDate(DateTime.now(), compact: true).toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonsSection({
    required String numeral,
    required String title,
    String? note,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  numeral,
                  style: TextStyle(
                    color: _profileGoldText.withValues(alpha: 0.68),
                    fontFamily: _profileSerifFont,
                    fontFamilyFallback: _profileSerifFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: _profileGoldText,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  color: _profileGoldMid.withValues(alpha: 0.18),
                ),
              ),
            ],
          ),
          if (note != null && note.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                note,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontFamily: _profileSerifFont,
                  fontFamilyFallback: _profileSerifFallback,
                  fontStyle: FontStyle.italic,
                  fontSize: 15,
                  height: 1.32,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCommonsCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    Color? borderColor,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF15110A).withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? _profileGoldMid.withValues(alpha: 0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCommonsPulseRow({
    required String count,
    required String text,
    bool quiet = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF15110A).withValues(alpha: 0.62),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 62,
            child: Text(
              count,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: quiet
                    ? Colors.white.withValues(alpha: 0.58)
                    : _profileGoldText,
                fontFamily: _profileSerifFont,
                fontFamilyFallback: _profileSerifFallback,
                fontSize: quiet ? 18 : 30,
                fontWeight: quiet ? FontWeight.w500 : FontWeight.w700,
                fontStyle: quiet ? FontStyle.italic : FontStyle.normal,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontFamily: _profileSerifFont,
                fontFamilyFallback: _profileSerifFallback,
                fontSize: 18,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonsQuestionSection() {
    final question = _activeCommonsQuestion();
    final questionText = _withoutWrappingQuotes(question.question);
    final hasQuestion = questionText.isNotEmpty;
    final myAnswer = question.myAnswer;
    final answerCount = question.answers
        .where((answer) => answer.id != myAnswer?.id)
        .length;
    return _buildCommonsSection(
      numeral: 'II',
      title: 'Question of the Day',
      children: [
        _buildCommonsCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hasQuestion
                    ? 'FROM TODAY\'S DAILY REFLECTION'
                    : 'DAILY REFLECTION',
                style: TextStyle(
                  color: _profileGoldText.withValues(alpha: 0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                hasQuestion
                    ? questionText
                    : 'No daily reflection question is available today.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontFamily: _profileSerifFont,
                  fontFamilyFallback: _profileSerifFallback,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 16),
              if (hasQuestion)
                _buildCommonsAnswerComposer(question)
              else
                _buildCommonsEmptyState(
                  'No public question is open.',
                  'You can still carry the daily reflection privately in your journal.',
                ),
              if (myAnswer != null && !_commonsAnswerEditing) ...[
                const SizedBox(height: 12),
                _buildCommonsAnswerCard(myAnswer, isMine: true),
              ],
              if (answerCount > 0) ...[
                const SizedBox(height: 14),
                Text(
                  'PUBLIC ANSWERS',
                  style: TextStyle(
                    color: _profileGoldText.withValues(alpha: 0.72),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.7,
                  ),
                ),
                const SizedBox(height: 8),
                for (final answer
                    in question.answers
                        .where((answer) => answer.id != myAnswer?.id)
                        .take(6)) ...[
                  _buildCommonsAnswerCard(answer),
                  const SizedBox(height: 8),
                ],
              ] else if (!_commonsLoading && myAnswer == null) ...[
                const SizedBox(height: 12),
                Text(
                  'No public answers yet.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontFamily: _profileSerifFont,
                    fontFamilyFallback: _profileSerifFallback,
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommonsAnswerComposer(CommonsQuestion question) {
    final myAnswer = question.myAnswer;
    final shouldCompose = _commonsAnswerEditing || myAnswer == null;
    if (!shouldCompose) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildCommonsCompactButton(
            'Edit answer',
            primary: true,
            onPressed: () {
              _commonsAnswerController.text = myAnswer.bodyText;
              setState(() => _commonsAnswerEditing = true);
            },
          ),
          _buildCommonsCompactButton(
            'Answer privately',
            onPressed: _openJournalForCommonsQuestion,
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _profileGoldMid.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _commonsAnswerController,
            enabled: !_commonsAnswerSaving,
            minLines: 3,
            maxLines: 5,
            maxLength: 1200,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontFamily: _profileSerifFont,
              fontFamilyFallback: _profileSerifFallback,
              fontSize: 17,
              height: 1.3,
            ),
            decoration: InputDecoration(
              hintText: 'Answer in the Commons',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontStyle: FontStyle.italic,
              ),
              counterStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.36),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _profileGoldMid.withValues(alpha: 0.18),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _profileGoldText.withValues(alpha: 0.62),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCommonsCompactButton(
                _commonsAnswerSaving ? 'Saving...' : 'Save public answer',
                primary: true,
                onPressed: _commonsAnswerSaving
                    ? null
                    : () => unawaited(_saveCommonsAnswer()),
              ),
              _buildCommonsCompactButton(
                'Cancel',
                onPressed: _commonsAnswerSaving
                    ? null
                    : () {
                        _commonsAnswerController.text =
                            myAnswer?.bodyText ?? '';
                        setState(() => _commonsAnswerEditing = false);
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommonsAnswerCard(CommonsAnswer answer, {bool isMine = false}) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMine
              ? _profileGoldText.withValues(alpha: 0.26)
              : Colors.white.withValues(alpha: 0.09),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isMine ? 'Your answer' : answer.authorLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isMine
                        ? _profileGoldText
                        : Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isMine)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _commonsAnswerController.text = answer.bodyText;
                      setState(() => _commonsAnswerEditing = true);
                    } else if (value == 'delete') {
                      unawaited(_deleteCommonsAnswer(answer));
                    }
                  },
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white.withValues(alpha: 0.58),
                    size: 19,
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                )
              else
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'report') {
                      unawaited(_reportCommonsAnswer(answer));
                    } else if (value == 'block') {
                      unawaited(_blockCommonsAnswerAuthor(answer));
                    }
                  },
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white.withValues(alpha: 0.44),
                    size: 19,
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'report', child: Text('Report')),
                    PopupMenuItem(value: 'block', child: Text('Block user')),
                  ],
                ),
            ],
          ),
          Text(
            answer.bodyText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontFamily: _profileSerifFont,
              fontFamilyFallback: _profileSerifFallback,
              fontSize: 17,
              height: 1.32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonsReflectionSection() {
    final fragments = _commonsInsightFragments();
    return _buildCommonsSection(
      numeral: 'III',
      title: 'Reflection Stream',
      note: 'Fragments shared with consent. No counts, no acclaim.',
      children: fragments.isEmpty
          ? [
              _buildCommonsEmptyState(
                'No fragments have been shared today.',
                'Private reflections stay private unless someone chooses to share a fragment.',
              ),
            ]
          : [
              for (var i = 0; i < fragments.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _buildCommonsFragment(fragments[i]),
              ],
            ],
    );
  }

  Widget _buildCommonsFragment(InsightPost post) {
    return _buildCommonsCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '"${_compactInsightText(post.bodyText)}"',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontFamily: _profileSerifFont,
              fontFamilyFallback: _profileSerifFallback,
              fontStyle: FontStyle.italic,
              fontSize: 19,
              height: 1.34,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: '${post.authorLabel} · ',
                    children: [
                      TextSpan(
                        text: post.nodeTitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildCommonsCompactButton(
                'Open',
                onPressed: () => _openInsightPost(post),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommonsEmptyState(String title, String body) {
    return _buildCommonsCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontFamily: _profileSerifFont,
              fontFamilyFallback: _profileSerifFallback,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontFamily: _profileSerifFont,
              fontFamilyFallback: _profileSerifFallback,
              fontStyle: FontStyle.italic,
              fontSize: 15,
              height: 1.32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonsPracticeTogetherSection() {
    final rooms = _commonsPracticeRooms();
    if (_commonsLoading && rooms.isEmpty) {
      return _buildCommonsSection(
        numeral: 'IV',
        title: 'Practice Together',
        children: [
          _buildCommonsEmptyState(
            'Shared practices are loading.',
            'Your rooms will appear first, followed by public rooms open to join.',
          ),
        ],
      );
    }

    return _buildCommonsSection(
      numeral: 'IV',
      title: 'Practice Together',
      children: rooms.isEmpty
          ? [
              _buildCommonsEmptyState(
                'Start a shared practice or make one public.',
                'Your shared flows appear first. Public practices from other users appear after them.',
              ),
              const SizedBox(height: 10),
              _buildCommonsGhostButton(
                icon: Icons.add_rounded,
                label: 'Start shared flow',
                onPressed: _openFlowsForCommons,
              ),
            ]
          : [
              SizedBox(
                height: _commonsPracticeCarouselHeight(context),
                child: PageView.builder(
                  controller: _commonsPracticePageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: rooms.length,
                  onPageChanged: (index) {
                    setState(() => _activeCommonsPracticeIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildCommonsPracticeRoomCard(rooms[index]),
                    );
                  },
                ),
              ),
              if (rooms.length > 1) ...[
                const SizedBox(height: 10),
                _buildCommonsCarouselDots(
                  count: rooms.length,
                  activeIndex: _activeCommonsPracticeIndex,
                ),
              ],
              const SizedBox(height: 10),
              _buildCommonsGhostButton(
                icon: Icons.add_rounded,
                label: 'Start shared flow',
                onPressed: _openFlowsForCommons,
              ),
            ],
    );
  }

  double _commonsPracticeCarouselHeight(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return 306 + ((textScale - 1.0).clamp(0.0, 0.4) * 120);
  }

  Widget _buildCommonsPracticeRoomCard(CommonsPracticeRoom room) {
    final isUpdating = _commonsVisibilityUpdatingRoomIds.contains(room.id);
    return _buildCommonsCard(
      borderColor: room.viewerCanManage
          ? _profileGoldText.withValues(alpha: 0.36)
          : _profileGoldMid.withValues(alpha: 0.22),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCommonsStatusPill(
                      room.viewerCanManage ? 'Your Flow' : 'Public Flow',
                      color: room.viewerCanManage
                          ? _profileGoldText
                          : const Color(0xFF30D5C8),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      room.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontFamily: _profileSerifFont,
                        fontFamilyFallback: _profileSerifFallback,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => context.push(
                  '/shared-practice/${Uri.encodeComponent(room.id)}',
                ),
                tooltip: 'Open shared practice',
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                color: _profileGoldText,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            [
              if (room.calendarName?.trim().isNotEmpty == true)
                room.calendarName!.trim(),
              '${room.memberCount} ${_plural(room.memberCount, 'member')}',
              room.joinPolicy.label,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (room.viewerCanManage)
            _buildCommonsPracticeVisibilityControls(room, isUpdating)
          else
            _buildCommonsPracticeViewerAction(room),
          const Spacer(),
          if (room.pendingJoinRequestCount > 0 && room.viewerCanManage) ...[
            Text(
              '${room.pendingJoinRequestCount} pending ${_plural(room.pendingJoinRequestCount, 'request')}',
              style: TextStyle(
                color: _profileGoldText.withValues(alpha: 0.82),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            room.viewerCanManage
                ? 'Choose whether this shared flow stays private, invite-only, or appears publicly in Commons.'
                : 'Ask to join public practices. Owners approve requests before the room becomes visible to you.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontFamily: _profileSerifFont,
              fontFamilyFallback: _profileSerifFallback,
              fontStyle: FontStyle.italic,
              fontSize: 14,
              height: 1.24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonsPracticeVisibilityControls(
    CommonsPracticeRoom room,
    bool isUpdating,
  ) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final visibility in SharedPracticeRoomVisibility.values)
          ChoiceChip(
            selected: room.visibility == visibility,
            onSelected: isUpdating
                ? null
                : (_) => unawaited(
                    _updateCommonsPracticeVisibility(room, visibility),
                  ),
            label: Text(visibility.label),
            selectedColor: _profileGoldMid.withValues(alpha: 0.30),
            backgroundColor: Colors.black.withValues(alpha: 0.18),
            disabledColor: Colors.black.withValues(alpha: 0.12),
            labelStyle: TextStyle(
              color: room.visibility == visibility
                  ? _profileGoldText
                  : Colors.white.withValues(alpha: 0.66),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
            side: BorderSide(
              color: room.visibility == visibility
                  ? _profileGoldText.withValues(alpha: 0.48)
                  : _profileGoldMid.withValues(alpha: 0.16),
            ),
          ),
      ],
    );
  }

  Widget _buildCommonsPracticeViewerAction(CommonsPracticeRoom room) {
    if (room.viewerIsMember || room.viewerRequestStatus == 'approved') {
      return _buildCommonsCompactButton(
        'Open room',
        primary: true,
        onPressed: () =>
            context.push('/shared-practice/${Uri.encodeComponent(room.id)}'),
      );
    }
    final requested = room.viewerRequestStatus == 'pending';
    final joining = _commonsJoiningRoomIds.contains(room.id);
    return _buildCommonsCompactButton(
      joining
          ? 'Sending...'
          : requested
          ? 'Requested'
          : room.requestLabel,
      primary: !requested,
      onPressed: requested || joining
          ? null
          : () => unawaited(_requestJoinCommonsPractice(room)),
    );
  }

  Widget _buildCommonsStatusPill(String label, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.48)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildCommonsCarouselDots({
    required int count,
    required int activeIndex,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 7,
            width: i == activeIndex ? 18 : 7,
            decoration: BoxDecoration(
              color: i == activeIndex
                  ? _profileGoldText
                  : Colors.white.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ],
    );
  }

  Widget _buildCommonsDiscoverSection() {
    final items = _commonsDiscoverItems();
    return _buildCommonsSection(
      numeral: 'V',
      title: 'Discover Practices',
      note: 'Public flows and insights from the wider rhythm.',
      children: _feedLoading && _feedItems.isEmpty
          ? [
              _buildCommonsEmptyState(
                'Discover practices are loading.',
                'Public posts will appear here when they are available.',
              ),
            ]
          : items.isEmpty
          ? [
              _buildCommonsEmptyState(
                'No discoverable practices yet.',
                _feedErrorMessage ??
                    'Follow practitioners or return after more public posts are available.',
              ),
            ]
          : [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 18),
                _buildCommonsDiscoverExpandedBlock(items[i]),
              ],
            ],
    );
  }

  Widget _buildCommonsDiscoverExpandedBlock(ProfileFeedItem item) {
    // Commons Discover intentionally embeds the bounded expanded For You block
    // so decoded payloads, internal detail scrolling, engagement, comments, and
    // ownership actions stay shared.
    return SizedBox(
      height: _expandedFeedDetailHeight(context),
      child: _buildExpandedFeedDetailCard(
        item,
        embeddedInCommonsDiscover: true,
        onOpenInForYou: () => unawaited(_openCommonsDiscoverItem(item)),
      ),
    );
  }

  Widget _buildCommonsCompactButton(
    String label, {
    bool primary = false,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: primary
            ? _profileGoldText
            : Colors.white.withValues(alpha: 0.78),
        backgroundColor: primary
            ? _profileGoldMid.withValues(alpha: 0.12)
            : Colors.transparent,
        side: BorderSide(
          color: primary
              ? _profileGoldText.withValues(alpha: 0.48)
              : _profileGoldMid.withValues(alpha: 0.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildCommonsGhostButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 16,
        color: _profileGoldText.withValues(alpha: 0.72),
      ),
      label: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.78),
        side: BorderSide(color: _profileGoldMid.withValues(alpha: 0.2)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        minimumSize: const Size(0, 42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _showCommonsActionSnack(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildFeedGrid(List<ProfileFeedItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth - _profileFeedColumnGap) / 2;
        final (left, right) = _splitFeedItems(items, columnWidth);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildFeedColumn(left)),
            const SizedBox(width: _profileFeedColumnGap),
            Expanded(child: _buildFeedColumn(right)),
          ],
        );
      },
    );
  }

  Widget _buildFeedColumn(List<ProfileFeedItem> items) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _buildFeedItemTile(items[i]),
          if (i != items.length - 1)
            const SizedBox(height: _profileFeedColumnGap),
        ],
      ],
    );
  }

  (List<ProfileFeedItem>, List<ProfileFeedItem>) _splitFeedItems(
    List<ProfileFeedItem> items,
    double columnWidth,
  ) {
    final left = <ProfileFeedItem>[];
    final right = <ProfileFeedItem>[];
    var leftHeight = 0.0;
    var rightHeight = 0.0;

    for (final item in items) {
      final estimatedHeight = _estimateFeedTileHeight(item, columnWidth);
      if (leftHeight <= rightHeight) {
        left.add(item);
        leftHeight += estimatedHeight + _profileFeedColumnGap;
      } else {
        right.add(item);
        rightHeight += estimatedHeight + _profileFeedColumnGap;
      }
    }

    return (left, right);
  }

  double _estimateFeedTileHeight(ProfileFeedItem item, double cardWidth) {
    if (item.kind == ProfileFeedItemKind.insight) {
      return _estimateInsightFeedTileHeight(item.insightPost!, cardWidth);
    }
    final post = item.flowPost!;
    final direction = Directionality.of(context);
    final title = cleanFlowTitle(post.name);
    final titlePainter = TextPainter(
      text: TextSpan(
        text: title.isEmpty ? 'Untitled Flow' : title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.08,
        ),
      ),
      maxLines: 6,
      textDirection: direction,
    )..layout(maxWidth: math.max(0, cardWidth - 28));
    return 264 + titlePainter.size.height;
  }

  double _estimateInsightFeedTileHeight(InsightPost post, double cardWidth) {
    final direction = Directionality.of(context);
    final headingPainter = TextPainter(
      text: TextSpan(
        text: post.nodeTitle,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.08,
        ),
      ),
      maxLines: 4,
      textDirection: direction,
    )..layout(maxWidth: math.max(0, cardWidth - 28));
    final bodyPainter = TextPainter(
      text: TextSpan(
        text: _insightPreviewText(post.bodyText),
        style: const TextStyle(fontSize: 14, height: 1.35),
      ),
      maxLines: 7,
      ellipsis: '…',
      textDirection: direction,
    )..layout(maxWidth: math.max(0, cardWidth - 28));
    return 248 + headingPainter.size.height + bodyPainter.size.height;
  }

  Widget _buildFeedItemTile(ProfileFeedItem item) {
    switch (item.kind) {
      case ProfileFeedItemKind.flow:
        return _buildFeedFlowTile(item);
      case ProfileFeedItemKind.insight:
        return _buildFeedInsightTile(item);
    }
  }

  Widget _buildFeedFlowTile(ProfileFeedItem item) {
    final post = item.flowPost!;
    final accent = Color(0xFF000000 | (post.color & 0x00FFFFFF));
    final title = cleanFlowTitle(post.name);
    final label = _ownsPost(post)
        ? 'Your Flow'
        : post.isFollowingAuthor
        ? 'Following'
        : 'Community';
    final authorHandle = post.authorHandle?.trim();
    final authorDisplayName = post.authorDisplayName?.trim();
    final showHandle =
        authorHandle != null &&
        authorHandle.isNotEmpty &&
        authorDisplayName != null &&
        authorDisplayName.isNotEmpty &&
        authorHandle.toLowerCase() != authorDisplayName.toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _profileGoldMid.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              onTap: () => _expandFeedItem(item),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: glossFromColor(post.color),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.95),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: _buildFeedAuthorHeader(
                userId: post.userId,
                displayName: post.authorLabel,
                handle: post.authorHandle,
                showHandle: showHandle,
                avatarUrl: post.authorAvatarUrl,
                avatarGlyphIds: post.authorAvatarGlyphIds,
              ),
            ),
            InkWell(
              onTap: () => _expandFeedItem(item),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _profileGoldTextWidget(
                      title.isEmpty ? 'Untitled Flow' : title,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: _postDateIconColor(0.42),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Posted ${_formatPostDate(post.createdAt, compact: true)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _postDateTextColor(0.54),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.north_east_rounded,
                          size: 18,
                          color: _profileGoldText.withValues(alpha: 0.86),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _buildForYouFlowTileActions(post, accent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: FlowPostEngagementRow(
                key: ValueKey('feed_${post.id}'),
                post: post,
                lazyComments: true,
                compact: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForYouFlowTileActions(FlowPost post, Color accent) {
    return Row(
      children: [
        Expanded(
          child: _buildForYouTileAction(
            label: _ownsPost(post) ? 'Open' : 'Save',
            accent: accent,
            primary: true,
            onPressed: _ownsPost(post)
                ? () => _openFeedFlowPost(post)
                : () => unawaited(_savePost(post)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildForYouTileAction(
            label: 'Begin',
            accent: accent,
            onPressed: () => _showCommonsActionSnack(
              'Begin Alone will activate a saved flow in a later phase.',
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildForYouTileAction(
            label: 'Together',
            accent: accent,
            onPressed: () => unawaited(_openPracticeTogetherForFlowPost(post)),
          ),
        ),
      ],
    );
  }

  Widget _buildForYouTileAction({
    required String label,
    required Color accent,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: primary
            ? _profileGoldText
            : Colors.white.withValues(alpha: 0.72),
        backgroundColor: primary
            ? accent.withValues(alpha: 0.12)
            : Colors.transparent,
        side: BorderSide(
          color: primary
              ? _profileGoldText.withValues(alpha: 0.42)
              : _profileGoldMid.withValues(alpha: 0.18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }

  Widget _buildFeedInsightTile(ProfileFeedItem item) {
    final post = item.insightPost!;
    final label = _ownsInsightPost(post)
        ? 'Your Insight'
        : post.isFollowingAuthor
        ? 'Following'
        : 'Community';
    final authorHandle = post.authorHandle?.trim();
    final authorDisplayName = post.authorDisplayName?.trim();
    final showHandle =
        authorHandle != null &&
        authorHandle.isNotEmpty &&
        authorDisplayName != null &&
        authorDisplayName.isNotEmpty &&
        authorHandle.toLowerCase() != authorDisplayName.toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _profileGoldMid.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              onTap: () => _expandFeedItem(item),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _profileGoldBase.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _profileGoldMid.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: _profileGoldText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: _buildFeedAuthorHeader(
                userId: post.userId,
                displayName: post.authorLabel,
                handle: post.authorHandle,
                showHandle: showHandle,
                avatarUrl: post.authorAvatarUrl,
                avatarGlyphIds: post.authorAvatarGlyphIds,
              ),
            ),
            InkWell(
              onTap: () => _expandFeedItem(item),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((post.nodeGlyph?.trim().isNotEmpty ?? false))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              post.nodeGlyph!,
                              style: const TextStyle(
                                color: _profileGoldText,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Expanded(
                          child: _profileGoldTextWidget(
                            post.nodeTitle,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.08,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _insightPreviewText(post.bodyText),
                      maxLines: 7,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Dated ${_formatPostDate(post.entryDate, compact: true)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _postDateTextColor(0.56),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Posted ${_formatPostDate(post.createdAt, compact: true)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _postDateTextColor(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _expandFeedItem(item),
                        child: _profileGoldTextWidget(
                          'Read more',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedFeedView(ProfileFeedItem item) {
    final sections = _relatedSectionsForFeedItem(item);
    final detailHeight = _expandedFeedDetailHeight(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: detailHeight,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _buildExpandedFeedDetailCard(item),
          ),
        ),
        const SizedBox(height: 18),
        _profileGoldTextWidget(
          'Similar Posts',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a post below to swap the expanded card while the day-cycle background stays in view.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 13,
            height: 1.3,
          ),
        ),
        if (sections.isEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'No related posts have surfaced yet.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else
          for (int i = 0; i < sections.length; i++) ...[
            const SizedBox(height: 16),
            _buildFeedRelatedSection(sections[i]),
          ],
      ],
    );
  }

  Widget _buildFeedRelatedSection(_FeedRelatedSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _profileGoldTextWidget(
          section.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        if (section.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            section.subtitle!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _buildFeedItemCollection(section.items),
      ],
    );
  }

  Widget _buildFeedItemCollection(List<ProfileFeedItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    if (items.length == 1) {
      return _buildFeedItemTile(items.first);
    }
    return _buildFeedGrid(items);
  }

  double _expandedFeedDetailHeight(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    var detailHeight = (height * 0.5).clamp(360.0, 520.0).toDouble();
    if (textScale > 1.08) detailHeight += 18;
    if (textScale > 1.18) detailHeight += 18;
    return detailHeight.clamp(360.0, 556.0).toDouble();
  }

  Widget _buildExpandedFeedDetailCard(
    ProfileFeedItem item, {
    bool embeddedInCommonsDiscover = false,
    VoidCallback? onOpenInForYou,
  }) {
    switch (item.kind) {
      case ProfileFeedItemKind.flow:
        return _buildExpandedFlowDetailCard(
          item.flowPost!,
          embeddedInCommonsDiscover: embeddedInCommonsDiscover,
          onOpenInForYou: onOpenInForYou,
        );
      case ProfileFeedItemKind.insight:
        return _buildExpandedInsightDetailCard(
          item.insightPost!,
          embeddedInCommonsDiscover: embeddedInCommonsDiscover,
          onOpenInForYou: onOpenInForYou,
        );
    }
  }

  Widget _buildExpandedFlowDetailCard(
    FlowPost post, {
    bool embeddedInCommonsDiscover = false,
    VoidCallback? onOpenInForYou,
  }) {
    final accent = Color(0xFF000000 | (post.color & 0x00FFFFFF));
    final title = cleanFlowTitle(post.name);
    final meta = notesDecode(post.notes);
    final overview = cleanFlowOverview(
      post.notes,
      decodedOverview: meta.overview,
    );
    final scheduleLines = _flowScheduleSummaryLines(post);
    final events = _flowPayloadEvents(post);

    return _buildExpandedFeedCardShell(
      key: ValueKey(
        embeddedInCommonsDiscover
            ? 'commons_expanded_flow_${post.id}'
            : 'expanded_flow_${post.id}',
      ),
      embeddedInCommonsDiscover: embeddedInCommonsDiscover,
      onOpenInForYou: onOpenInForYou,
      topChip: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.32)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: glossFromColor(post.color),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _ownsPost(post) ? 'Your Flow' : 'Posted Flow',
              style: TextStyle(
                color: accent.withValues(alpha: 0.95),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExpandedFeedAuthorRow(
            userId: post.userId,
            displayName: post.authorLabel,
            handle: post.authorHandle,
            displayHandleWhenDistinct:
                (post.authorHandle?.trim().isNotEmpty ?? false) &&
                (post.authorDisplayName?.trim().isNotEmpty ?? false) &&
                post.authorHandle?.toLowerCase() !=
                    post.authorDisplayName?.toLowerCase(),
            avatarUrl: post.authorAvatarUrl,
            avatarGlyphIds: post.authorAvatarGlyphIds,
          ),
          const SizedBox(height: 16),
          _profileGoldTextWidget(
            title.isEmpty ? 'Untitled Flow' : title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 15,
                color: _postDateIconColor(0.46),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Posted ${_formatPostDate(post.createdAt)}',
                  style: TextStyle(
                    color: _postDateTextColor(0.58),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (overview.isNotEmpty) ...[
            _buildExpandedSectionTitle('Overview'),
            const SizedBox(height: 6),
            Text(
              overview,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.48,
              ),
            ),
            const SizedBox(height: 18),
          ],
          _buildExpandedSectionTitle('Schedule'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildExpandedMetaPill(
                meta.kemetic ? 'Kemetic cadence' : 'Gregorian cadence',
              ),
              if (meta.split) _buildExpandedMetaPill('Custom dates'),
              if (events.isNotEmpty)
                _buildExpandedMetaPill(
                  '${events.length} event${events.length == 1 ? '' : 's'}',
                ),
            ],
          ),
          if (scheduleLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final line in scheduleLines) ...[
              Text(
                line,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ],
          if (events.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildExpandedSectionTitle('Events'),
            const SizedBox(height: 8),
            for (final event in events) _buildExpandedFlowEventTile(event),
          ],
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlowPostEngagementRow(
              key: ValueKey('expanded_${post.id}'),
              post: post,
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: _ownsPost(post)
                  ? Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              unawaited(_openPracticeTogetherForFlowPost(post)),
                          icon: _profileGoldIcon(Icons.groups_2_outlined),
                          label: _profileGoldTextWidget(
                            'Practice Together',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _removePost(post.id),
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          label: const Text(
                            'Remove',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: () => _savePost(post),
                          icon: _profileGoldIcon(Icons.bookmark_add_outlined),
                          label: _profileGoldTextWidget(
                            'Save Flow',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              unawaited(_openPracticeTogetherForFlowPost(post)),
                          icon: _profileGoldIcon(Icons.groups_2_outlined),
                          label: _profileGoldTextWidget(
                            'Practice Together',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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

  Widget _buildExpandedInsightDetailCard(
    InsightPost post, {
    bool embeddedInCommonsDiscover = false,
    VoidCallback? onOpenInForYou,
  }) {
    final handle = post.authorHandle?.trim();
    final displayName = post.authorDisplayName?.trim();

    return _buildExpandedFeedCardShell(
      key: ValueKey(
        embeddedInCommonsDiscover
            ? 'commons_expanded_insight_${post.id}'
            : 'expanded_insight_${post.id}',
      ),
      embeddedInCommonsDiscover: embeddedInCommonsDiscover,
      onOpenInForYou: onOpenInForYou,
      topChip: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _profileGoldBase.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _profileGoldMid.withValues(alpha: 0.28)),
        ),
        child: Text(
          _ownsInsightPost(post) ? 'Your Insight' : 'Posted Insight',
          style: const TextStyle(
            color: _profileGoldText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExpandedFeedAuthorRow(
            userId: post.userId,
            displayName: post.authorLabel,
            handle: handle,
            displayHandleWhenDistinct:
                handle != null &&
                handle.isNotEmpty &&
                displayName != null &&
                displayName.isNotEmpty &&
                handle.toLowerCase() != displayName.toLowerCase(),
            avatarUrl: post.authorAvatarUrl,
            avatarGlyphIds: post.authorAvatarGlyphIds,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((post.nodeGlyph?.trim().isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    post.nodeGlyph!,
                    style: const TextStyle(
                      color: _profileGoldText,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Expanded(
                child: _profileGoldTextWidget(
                  post.nodeTitle,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildExpandedMetaPill(
                'Dated ${_formatPostDate(post.entryDate, compact: true)}',
              ),
              _buildExpandedMetaPill(
                'Posted ${_formatPostDate(post.createdAt, compact: true)}',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildExpandedSectionTitle('Insight'),
          const SizedBox(height: 8),
          Text(
            post.bodyText.trim(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.56,
            ),
          ),
        ],
      ),
      footer: _ownsInsightPost(post)
          ? Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _removeInsightPost(post.id),
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  label: const Text(
                    'Remove',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildExpandedFeedCardShell({
    required Key key,
    required Widget topChip,
    required Widget body,
    Widget? footer,
    bool embeddedInCommonsDiscover = false,
    VoidCallback? onOpenInForYou,
  }) {
    final bodyContent = SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: body,
    );

    return Container(
      key: key,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _profileGoldMid.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(child: topChip),
                  const SizedBox(width: 12),
                  if (!embeddedInCommonsDiscover || onOpenInForYou != null)
                    Material(
                      color: Colors.black.withValues(alpha: 0.36),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: embeddedInCommonsDiscover
                            ? onOpenInForYou
                            : _collapseExpandedFeedItem,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            embeddedInCommonsDiscover
                                ? Icons.north_east_rounded
                                : Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.88),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: bodyContent),
            if (footer != null) ...[
              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
              footer,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedFeedAuthorRow({
    required String userId,
    required String displayName,
    required String? handle,
    required bool displayHandleWhenDistinct,
    required String? avatarUrl,
    required List<String> avatarGlyphIds,
  }) {
    return _buildFeedAuthorHeader(
      userId: userId,
      displayName: displayName,
      handle: handle,
      showHandle: displayHandleWhenDistinct,
      avatarUrl: avatarUrl,
      avatarGlyphIds: avatarGlyphIds,
      avatarRadius: 16,
      nameFontSize: 14,
      handleFontSize: 12,
    );
  }

  Widget _buildFeedAuthorHeader({
    required String userId,
    required String displayName,
    required String? handle,
    required bool showHandle,
    required String? avatarUrl,
    required List<String> avatarGlyphIds,
    double avatarRadius = 14,
    double nameFontSize = 13,
    double handleFontSize = 11,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openFeedAuthorProfile(userId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            ProfileAvatar(
              displayName: displayName,
              avatarUrl: avatarUrl,
              avatarGlyphIds: avatarGlyphIds,
              radius: avatarRadius,
              foregroundColor: _profileGoldText,
              backgroundColor: const Color(0xFF111115),
              borderColor: _profileGoldMid.withValues(alpha: 0.24),
              borderWidth: 1,
            ),
            SizedBox(width: avatarRadius >= 16 ? 12 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: nameFontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (showHandle && handle != null)
                    Text(
                      '@$handle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: handleFontSize,
                        fontWeight: FontWeight.w600,
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

  Widget _buildExpandedSectionTitle(String title) {
    return _profileGoldTextWidget(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildExpandedMetaPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _profileGoldMid.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.84),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<String> _flowScheduleSummaryLines(FlowPost post) {
    final rules = _flowRuleMaps(post);
    if (rules.isEmpty) return const [];

    final lines = <String>[];
    for (final rule in rules) {
      final type = (rule['type'] as String? ?? '').trim().toLowerCase();
      switch (type) {
        case 'decan':
          final months = (rule['months'] as List<dynamic>? ?? const [])
              .whereType<num>()
              .map((value) => getMonthById(value.toInt()).displayFull)
              .toList();
          final decans =
              (rule['decans'] as List<dynamic>? ?? const [])
                  .whereType<num>()
                  .map((value) => value.toInt())
                  .toList()
                ..sort();
          final days =
              (rule['daysInDecan'] as List<dynamic>? ?? const [])
                  .whereType<num>()
                  .map((value) => value.toInt())
                  .toList()
                ..sort();
          final monthLabels = months.join(', ');
          final decanLabels = decans
              .map(
                (value) => ['I', 'II', 'III'][(value.toInt() - 1).clamp(0, 2)],
              )
              .join(', ');
          if (monthLabels.isNotEmpty) {
            lines.add('Months: $monthLabels');
          }
          if (decanLabels.isNotEmpty) {
            lines.add(
              days.isEmpty
                  ? 'Decans: $decanLabels (all days)'
                  : 'Decans: $decanLabels',
            );
          }
          if (days.isNotEmpty) {
            lines.add('Days in decan: ${days.join(', ')}');
          }
          break;
        case 'week':
          final weekdays =
              (rule['weekdays'] as List<dynamic>? ?? const [])
                  .whereType<num>()
                  .map((value) => value.toInt())
                  .toList()
                ..sort();
          const weekdayNames = <int, String>{
            DateTime.monday: 'Mon',
            DateTime.tuesday: 'Tue',
            DateTime.wednesday: 'Wed',
            DateTime.thursday: 'Thu',
            DateTime.friday: 'Fri',
            DateTime.saturday: 'Sat',
            DateTime.sunday: 'Sun',
          };
          if (weekdays.isNotEmpty) {
            lines.add(
              'Repeats on: ${weekdays.map((value) => weekdayNames[value] ?? 'Day $value').join(', ')}',
            );
          }
          break;
        case 'dates':
          final dates =
              (rule['dates'] as List<dynamic>? ?? const [])
                  .whereType<num>()
                  .map(
                    (value) => DateUtils.dateOnly(
                      DateTime.fromMillisecondsSinceEpoch(value.toInt()),
                    ),
                  )
                  .toList()
                ..sort();
          if (dates.isEmpty) break;
          String formatDate(DateTime value) =>
              '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
          if (dates.length == 1) {
            lines.add('Occurs on: ${formatDate(dates.first)}');
          } else {
            lines.add('Occurs on ${dates.length} dates');
            lines.add(
              'From ${formatDate(dates.first)} to ${formatDate(dates.last)}',
            );
          }
          break;
        default:
          lines.add('Custom schedule');
          break;
      }
    }
    return lines;
  }

  Widget _buildExpandedFlowEventTile(Map<String, dynamic> event) {
    final title = cleanFlowTitle(event['title'] as String?);
    final detail = cleanFlowDetail(event['detail'] as String?);
    final location = (event['location'] as String?)?.trim();
    final allDay = event['all_day'] as bool? ?? false;
    final startTime = (event['start_time'] as String?)?.trim();
    final endTime = (event['end_time'] as String?)?.trim();
    final offsetDays = (event['offset_days'] as num?)?.toInt();
    final dayNumber = offsetDays == null ? null : offsetDays + 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title.isEmpty ? 'Untitled Event' : title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              if (dayNumber != null)
                Text(
                  'Day $dayNumber',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            allDay
                ? 'All day'
                : startTime == null || startTime.isEmpty
                ? 'Time not listed'
                : endTime != null && endTime.isNotEmpty
                ? '$startTime - $endTime'
                : startTime,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.42,
              ),
            ),
          ],
          if (location != null && location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              location,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostCard(
    FlowPost post, {
    required VoidCallback onTap,
    bool inPager = false,
  }) {
    final title = cleanFlowTitle(post.name);
    final overview = cleanFlowOverview(post.notes);
    final accent = Color(0xFF000000 | (post.color & 0x00FFFFFF));
    final headerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: glossFromColor(post.color),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Posted Flow',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _profileGoldTextWidget(
          title.isEmpty ? 'Untitled Flow' : title,
          maxLines: inPager ? 4 : 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 16,
              color: _postDateIconColor(0.42),
            ),
            const SizedBox(width: 8),
            Text(
              'Posted ${_formatPostDate(post.createdAt)}',
              style: TextStyle(
                color: _postDateTextColor(0.54),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (overview.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            overview,
            maxLines: inPager ? 4 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.22,
            ),
          ),
        ],
      ],
    );

    final fixedActions = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
          child: FlowPostEngagementRow(post: post),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_isViewingOwnProfile)
                TextButton.icon(
                  onPressed: () => _removePost(post.id),
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  label: const Text(
                    'Remove',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => _savePost(post),
                  icon: _profileGoldIcon(Icons.bookmark_add_outlined),
                  label: _profileGoldTextWidget(
                    'Save Flow',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              TextButton(
                onPressed: onTap,
                child: _profileGoldTextWidget(
                  'Open',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final card = Container(
      margin: EdgeInsets.only(bottom: inPager ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _profileGoldMid.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: inPager ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (inPager)
              Expanded(
                child: InkWell(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  onTap: onTap,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                    child: headerContent,
                  ),
                ),
              )
            else
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: headerContent,
                ),
              ),
            fixedActions,
          ],
        ),
      ),
    );
    if (!inPager) return card;
    return SizedBox.expand(child: card);
  }

  Widget _buildInsightPostCard(
    InsightPost post, {
    required VoidCallback onReadMore,
    bool inPager = false,
  }) {
    final headerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _profileGoldBase.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _profileGoldMid.withValues(alpha: 0.28)),
          ),
          child: Text(
            'Posted Insight',
            style: TextStyle(
              color: _profileGoldText.withValues(alpha: 0.96),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((post.nodeGlyph?.trim().isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  post.nodeGlyph!,
                  style: const TextStyle(
                    color: _profileGoldText,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(
              child: _profileGoldTextWidget(
                post.nodeTitle,
                maxLines: inPager ? 3 : 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Dated ${_formatPostDate(post.entryDate)}',
          style: TextStyle(
            color: _postDateTextColor(0.58),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _insightPreviewText(post.bodyText),
          maxLines: inPager ? 9 : 6,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Posted ${_formatPostDate(post.createdAt)}',
          style: TextStyle(
            color: _postDateTextColor(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final fixedActions = Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (_isViewingOwnProfile)
              TextButton.icon(
                onPressed: () => _removeInsightPost(post.id),
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.redAccent,
                  size: 18,
                ),
                label: const Text(
                  'Remove',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            TextButton(
              onPressed: onReadMore,
              child: _profileGoldTextWidget(
                'Read more',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final card = Container(
      margin: EdgeInsets.only(bottom: inPager ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _profileGoldMid.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: inPager ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (inPager)
              Expanded(
                child: InkWell(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  onTap: onReadMore,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                    child: headerContent,
                  ),
                ),
              )
            else
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onReadMore,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: headerContent,
                ),
              ),
            fixedActions,
          ],
        ),
      ),
    );
    if (!inPager) return card;
    return SizedBox.expand(child: card);
  }

  void _openInsightPost(InsightPost post) {
    unawaited(
      openDetailRoute<void>(
        context,
        '/insight-post/${Uri.encodeComponent(post.id)}',
        extra: post,
      ),
    );
  }

  bool get _useGregorianPostDates => _feedRevealed && _showGregorianFeedDates;

  Color _postDateTextColor(double alpha) {
    final base = _useGregorianPostDates
        ? _profileGregorianBlueLight
        : Colors.white;
    return base.withValues(alpha: alpha);
  }

  Color _postDateIconColor(double alpha) {
    final base = _useGregorianPostDates ? _profileGregorianBlue : Colors.white;
    return base.withValues(alpha: alpha);
  }

  String _formatPostDate(DateTime date, {bool compact = false}) {
    if (!_useGregorianPostDates) {
      return formatKemeticDate(date, includeGregorianYear: !compact);
    }

    final local = date.toLocal();
    const shortMonths = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = shortMonths[local.month - 1];
    if (compact) {
      return '$month ${local.day}';
    }
    return '$month ${local.day}, ${local.year}';
  }

  String _insightPreviewText(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? 'Untitled insight' : normalized;
  }

  void _openPostDetails(int initialIndex) {
    final post = _posts[initialIndex];
    unawaited(
      openDetailRoute<void>(
        context,
        '/flow-post/${Uri.encodeComponent(post.id)}',
        extra: <String, Object?>{
          'post': post,
          'posts': _posts,
          'initialIndex': initialIndex,
        },
      ),
    );
  }

  void _openFeedFlowPost(FlowPost post) {
    unawaited(
      openDetailRoute<void>(
        context,
        '/flow-post/${Uri.encodeComponent(post.id)}',
        extra: post,
      ),
    );
  }

  void _openPostPicker() {
    unawaited(openDetailRoute<void>(context, '/profile/flow-post-picker'));
  }

  void _openInsightPostPicker() {
    unawaited(openDetailRoute<void>(context, '/profile/insight-post-picker'));
  }

  Future<void> _savePost(FlowPost post) async {
    final flowId = await _repo.saveFlowPostToMyFlows(post);
    if (!mounted) return;
    if (flowId == null) {
      _showError('Could not save this flow.');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Flow saved to your flows'),
        backgroundColor: _profileGoldBase,
      ),
    );
  }

  Future<void> _removePost(String postId) async {
    final ok = await _repo.deleteFlowPost(postId);
    if (!mounted) return;
    if (!ok) {
      _showError('Unable to remove post. Please try again.');
      return;
    }
    final selected = _expandedFeedItem;
    if (selected != null &&
        selected.kind == ProfileFeedItemKind.flow &&
        selected.id == postId) {
      setState(() {
        _expandedFeedItem = null;
      });
    }
    await _loadPosts();
    if (_feedRevealed) {
      await _loadFeedPage(reset: true);
    }
  }

  Future<void> _removeInsightPost(String postId) async {
    final ok = await _repo.deleteInsightPost(postId);
    if (!mounted) return;
    if (!ok) {
      _showError('Unable to remove insight. Please try again.');
      return;
    }
    final selected = _expandedFeedItem;
    if (selected != null &&
        selected.kind == ProfileFeedItemKind.insight &&
        selected.id == postId) {
      setState(() {
        _expandedFeedItem = null;
      });
    }
    await _loadInsightPosts();
    if (_feedRevealed) {
      await _loadFeedPage(reset: true);
    }
  }
}

class _ProfileFeedTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileFeedTabsHeaderDelegate({
    required this.extent,
    required this.child,
  });

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _ProfileFeedTabsHeaderDelegate oldDelegate) {
    return extent != oldDelegate.extent || child != oldDelegate.child;
  }
}

class _FeedRelatedSection {
  final String title;
  final String? subtitle;
  final List<ProfileFeedItem> items;

  const _FeedRelatedSection({
    required this.title,
    this.subtitle,
    required this.items,
  });
}
