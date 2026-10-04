import 'package:mobile/core/theme/app_fonts.dart';
import 'commons_practice_card.dart';
import 'commons_rhythm_block.dart';
import '../../data/commons_question_selection.dart';
import 'commons_question_block.dart';
// lib/features/profile/profile_page.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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
import '../../data/flow_appearance.dart';
import '../../data/insight_post_model.dart';
import '../../data/profile_feed_item_model.dart';
import '../../data/shared_practice_models.dart';
import '../../utils/kemetic_date_format.dart';
import '../../services/app_haptics.dart';
import '../../services/navigation_trace.dart';
import '../../services/restoration_coordinator.dart';
import '../../widgets/keyboard_aware.dart';
import 'follow_list_page.dart';
import '../calendar/calendar_page.dart';
import '../calendar/calendar_invalidation.dart';
import 'package:mobile/features/onboarding/guided_onboarding_overlay.dart';
import '../onboarding/onboarding_progress.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/shared/kemetic_text.dart';
import '../../widgets/kemetic_app_bar_action.dart';
import 'profile_backdrop_timeline.dart';
import 'flow_post_caption_sheet.dart';
import 'flow_post_share_actions.dart';
import 'posted_flow_artifact.dart';
import 'haw_profile_icon.dart';
import 'profile_flow_post_tile.dart';
import 'social_flow_post_tile.dart';

const Color _profileGoldLight = Color(0xFFF7E09A);
const Color _profileGoldMid = Color(0xFFE8BE54);
const Color _profileGoldBase = Color(0xFFCA9221);
const Color _profileGoldDeep = Color(0xFF7A5310);
const Color _profileGoldText = Color(0xFFF1CF7A);
const Color _profileGregorianBlueLight = Color(0xFFBFE0FF);
const Color _profileSurface = Color(0xFF0B0906);
const Color _profileLine = Color(0xFF241F17);
const Color _profileLineSoft = Color(0xFF1A160F);
const Color _profileBone = Color(0xFFF2ECE0);
const Color _profileHigh = Color(0xFFC8C4BC);
const Color _profileMid = Color(0xFF9E9A94);
const Color _profileLow = Color(0xFF6A6660);
const Color _profileHeroHigh = Color(0xFFE6E0D6);
const Color _profileHeroMid = Color(0xFFD0CBC2);
const Color _profileHeroLow = Color(0xFFB5B0A8);
const Color _profileSpecGold = Color(0xFFD4AE43);
const int _profileFeedPageSize = 18;
const double _profileFeedColumnGap = 12;
const double _profileFeedTabsHeaderExtent = 39;

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
const String _profileSansFont = AppFonts.ui;
const List<String> _profileSerifFallback = ['GentiumPlus', 'Georgia', 'serif'];

enum _SocialFeedTab { todaysCommons, forYou }

class ProfilePage extends StatefulWidget {
  final String userId;
  final bool isMyProfile;
  final bool openedFromCalendar;
  final bool initialFeedRevealed;
  final bool initialCommons;

  const ProfilePage({
    super.key,
    required this.userId,
    this.isMyProfile = false,
    this.openedFromCalendar = false,
    this.initialFeedRevealed = false,
    this.initialCommons = false,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  static const double _feedRevealViewportThreshold = 0.74;
  static const double _feedPullToCloseThreshold = 96;
  final _repo = ProfileRepo(Supabase.instance.client);
  final _commonsRepo = CommonsRepo(Supabase.instance.client);
  late final PageController _postPageController;
  late final PageController _commonsPracticePageController;
  late final ScrollController _profileScrollController;
  late final ScrollController _feedScrollController;
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
  CommonsHomeSnapshot? _commonsHome;
  bool _feedCloseInFlight = false;
  bool _commonsLoading = false;
  bool _commonsAnswerEditing = false;
  bool _commonsAnswerSaving = false;
  bool _commonsAnswerDeleting = false;
  String? _commonsErrorMessage;
  int _activePostIndex = 0;
  String? _activeProfilePostKey;
  int? _legacyFlowPostIndex;
  int _activeCommonsPracticeIndex = 0;
  final Set<String> _requestedFlowPostIds = <String>{};
  final Set<String> _clearedFlowPostRequestIds = <String>{};
  final Set<String> _togetherRequestBusyIds = <String>{};
  final Set<String> _requestedCommonsRoomIds = <String>{};
  final Set<String> _clearedCommonsRoomRequestIds = <String>{};
  final Set<String> _commonsRequestBusyIds = <String>{};
  final Set<String> _optimisticLikedCommonsRoomIds = <String>{};
  final Set<String> _commonsLikeBusyIds = <String>{};
  final Set<String> _commonsQuoteLikeBusyIds = <String>{};
  final Set<String> _savedFlowPostIds = <String>{};
  int _profileLoadSerial = 0;
  double _feedTopPullDistance = 0;
  Timer? _continuitySaveDebounce;
  StreamSubscription<CalendarInvalidated>? _flowLifecycleSub;
  bool _continuityRestored = false;
  bool _buildTraceRecorded = false;
  double? _pendingProfileScrollOffset;
  double? _pendingFeedScrollOffset;
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

  bool _flowPostRequestIsPending(FlowPost post) {
    return _requestedFlowPostIds.contains(post.id) ||
        (!_clearedFlowPostRequestIds.contains(post.id) &&
            post.viewerTogetherRequestStatus?.trim().toLowerCase() ==
                'pending');
  }

  Future<void> _toggleTogetherRequest(FlowPost post) async {
    if (!post.viewerCanRequestTogether ||
        _ownsPost(post) ||
        _togetherRequestBusyIds.contains(post.id)) {
      return;
    }
    final wasPending = _flowPostRequestIsPending(post);
    setState(() {
      _togetherRequestBusyIds.add(post.id);
      if (wasPending) {
        _requestedFlowPostIds.remove(post.id);
        _clearedFlowPostRequestIds.add(post.id);
      } else {
        _requestedFlowPostIds.add(post.id);
        _clearedFlowPostRequestIds.remove(post.id);
      }
    });
    try {
      if (wasPending) {
        await _repo.cancelTogetherRequest(post.id);
      } else {
        await _repo.requestTogether(post.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasPending) {
          _requestedFlowPostIds.add(post.id);
          _clearedFlowPostRequestIds.remove(post.id);
        } else {
          _requestedFlowPostIds.remove(post.id);
          _clearedFlowPostRequestIds.add(post.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasPending
                ? 'Could not remove that request.'
                : 'Could not send that request.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _togetherRequestBusyIds.remove(post.id));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    NavigationTrace.instance.record(
      'ProfilePage initState',
      state: _navigationTraceProfileState(),
    );
    WidgetsBinding.instance.addObserver(this);
    _postPageController = PageController();
    _commonsPracticePageController = PageController(viewportFraction: 0.92);
    _profileScrollController = ScrollController()
      ..addListener(_handleProfileScroll);
    _feedScrollController = ScrollController()..addListener(_handleFeedScroll);
    _seedPostedContentFromMemory();
    _feedRevealed = widget.initialFeedRevealed;
    if (_feedRevealed) {
      unawaited(_loadFeedPage(reset: true));
      unawaited(_loadCommonsHome());
    }
    _flowLifecycleSub = CalendarInvalidationBus.instance.stream
        .where(
          (event) =>
              event.reason == CalendarInvalidationReason.flowEndedCommitted,
        )
        .listen((_) {
          if (_isViewingOwnProfile) {
            unawaited(_loadProfile(showSpinner: false));
          }
        });
    unawaited(_restoreContinuityState());
    _loadProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flowLifecycleSub?.cancel();
    _continuitySaveDebounce?.cancel();
    unawaited(_persistContinuityState());
    _profileScrollController
      ..removeListener(_handleProfileScroll)
      ..dispose();
    _feedScrollController
      ..removeListener(_handleFeedScroll)
      ..dispose();
    _postPageController.dispose();
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

    final feedRevealed =
        widget.initialFeedRevealed || state['feedRevealed'] == true;
    _pendingProfileScrollOffset = (state['profileScrollOffset'] as num?)
        ?.toDouble();
    _pendingFeedScrollOffset = (state['feedScrollOffset'] as num?)?.toDouble();
    final rawFeedTab = (state['selectedFeedTab'] as String?)?.trim();
    final activePostIndex = (state['activePostIndex'] as num?)?.toInt();
    final activeProfilePostKey = state['activeProfilePostKey'] as String?;

    setState(() {
      _feedRevealed = feedRevealed;
      _selectedFeedTab =
          !widget.initialCommons && rawFeedTab == _SocialFeedTab.forYou.name
          ? _SocialFeedTab.forYou
          : _SocialFeedTab.todaysCommons;
      _showGregorianFeedDates = state['showGregorianFeedDates'] == true;
      if (activePostIndex != null && activePostIndex >= 0) {
        _activePostIndex = activePostIndex;
      }
      _activeProfilePostKey = activeProfilePostKey;
      // Old releases stored the flow-only index. Resolve that flow in the
      // combined sequence once its existing repository has hydrated.
      _legacyFlowPostIndex = activeProfilePostKey == null
          ? activePostIndex
          : null;
      _reconcilePostSelection();
      _continuityRestored = true;
    });

    if (feedRevealed && !widget.initialFeedRevealed) {
      unawaited(_loadFeedPage(reset: true));
    }
    _syncPostsPager();
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
    final posts = _profilePosts;
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
          if (posts.isNotEmpty)
            'activeProfilePostKey':
                _activeProfilePostKey ??
                _profilePostKey(posts[_clampPostIndex(posts.length)]),
          if (profileOffset != null && profileOffset.isFinite)
            'profileScrollOffset': math.max(0, profileOffset),
          if (feedOffset != null && feedOffset.isFinite)
            'feedScrollOffset': math.max(0, feedOffset),
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
    }

    final cachedInsights = _repo.getCachedInsightPostsSync(widget.userId);
    if (cachedInsights != null) {
      _insightPosts = cachedInsights;
      _insightPostsLoading = false;
    }
  }

  Future<void> _loadProfile({bool showSpinner = true}) async {
    final loadSerial = ++_profileLoadSerial;
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
    final userId = _currentUserId;
    if (userId == null) return;
    final storage = OnboardingProgressStorage();
    final progress = loadedProgress ?? await storage.load(userId);
    if (!mounted || !progress.completedOnboarding) {
      return;
    }
    const helper = OnboardingHelperRegistry.profileCommunityFeed;
    final helperService = OnboardingHelperCompletionService.instance;
    await helperService.hydrateUser(userId);
    if (!mounted || !helperService.shouldShowHelperSync(userId, helper.id)) {
      return;
    }
    _profileCommunityHelperPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(() async {
        if (!mounted || _feedRevealed) return;
        await helperService.hydrateUser(userId);
        if (!mounted ||
            !helperService.shouldShowHelperSync(userId, helper.id)) {
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
    setState(() {
      _posts = posts;
      _postsLoading = false;
      _reconcilePostSelection();
    });
    _syncPostsPager();
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
    setState(() {
      _insightPosts = posts;
      _insightPostsLoading = false;
      _reconcilePostSelection();
    });
    _syncPostsPager();
  }

  String _profilePostKey(ProfileFeedItem item) =>
      '${item.kind.name}:${item.id}';

  void _reconcilePostSelection() {
    final posts = _profilePosts;
    if (_legacyFlowPostIndex != null && !_postsLoading) {
      if (_posts.isNotEmpty) {
        final index = _clampPostIndex(_posts.length, _legacyFlowPostIndex);
        _activeProfilePostKey = _profilePostKey(
          ProfileFeedItem.flow(_posts[index]),
        );
      }
      _legacyFlowPostIndex = null;
    }
    final selected = posts.indexWhere(
      (post) => _profilePostKey(post) == _activeProfilePostKey,
    );
    _activePostIndex = selected >= 0 ? selected : _clampPostIndex(posts.length);
    if (selected < 0 && !_postsLoading && !_insightPostsLoading) {
      // A removed post falls back to its nearest surviving neighbour.
      _activeProfilePostKey = null;
    }
  }

  void _syncPostsPager() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_postPageController.hasClients && _profilePosts.isNotEmpty) {
        final currentPage = (_postPageController.page ?? 0).round();
        if (currentPage != _activePostIndex) {
          _postPageController.jumpToPage(_activePostIndex);
        }
      }
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
    if (!_feedLoading) {
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
    _feedCloseInFlight = false;
    setState(() => _feedRevealed = false);
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

    if (reset) {
      _feedLoading = true;
    } else {
      _feedLoadingMore = true;
    }
    final nextOffset = reset ? 0 : _feedItems.length;
    if (reset && _feedItems.isEmpty) {
      try {
        final local = await _repo.getProfileFeedResult(
          limit: _profileFeedPageSize,
          cachedOnly: true,
        );
        if (!mounted) return;
        setState(() => _feedItems = local.data);
      } catch (_) {}
    }
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
      });
      return;
    }

    final loaded = result.data;

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

    setState(() {
      _feedItems = merged;
      _feedLoading = false;
      _feedLoadingMore = false;
      _feedHasMore = loaded.length >= _profileFeedPageSize;
      _feedErrorMessage = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyPendingContinuityAfterFrame();
      _maybeLoadMoreFeed();
    });
  }

  ({String id, String text}) _commonsQuestionSeed() =>
      commonsQuestionSeed(DateTime.now());

  CommonsQuestion _activeCommonsQuestion() =>
      activeCommonsQuestion(_commonsHome, DateTime.now());

  Future<void> _loadCommonsHome({bool force = false}) async {
    if (_commonsLoading && !force) return;
    final seed = _commonsQuestionSeed();
    if (!mounted) return;
    setState(() {
      _commonsLoading = true;
      _commonsErrorMessage = null;
    });
    if (_commonsHome == null) {
      try {
        final local = await _commonsRepo.getCommonsHome(
          localDate: DateTime.now(),
          questionId: seed.id,
          questionText: seed.text,
          cachedOnly: true,
        );
        if (!mounted) return;
        setState(() => _commonsHome = local);
      } catch (_) {}
    }
    try {
      final snapshot = await _commonsRepo.getCommonsHome(
        localDate: DateTime.now(),
        questionId: seed.id,
        questionText: seed.text,
        strict: _commonsHome != null,
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
        _requestedCommonsRoomIds.clear();
        _clearedCommonsRoomRequestIds.clear();
        _optimisticLikedCommonsRoomIds.clear();
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

  Future<void> _toggleCommonsRoomRequest(CommonsPracticeRoom room) async {
    if (!room.viewerCanRequestJoin ||
        _commonsRequestBusyIds.contains(room.id)) {
      return;
    }
    final wasRequested =
        _requestedCommonsRoomIds.contains(room.id) ||
        (!_clearedCommonsRoomRequestIds.contains(room.id) &&
            room.viewerRequestStatus == 'pending');
    setState(() {
      _commonsRequestBusyIds.add(room.id);
      if (wasRequested) {
        _requestedCommonsRoomIds.remove(room.id);
        _clearedCommonsRoomRequestIds.add(room.id);
      } else {
        _requestedCommonsRoomIds.add(room.id);
        _clearedCommonsRoomRequestIds.remove(room.id);
      }
    });
    try {
      if (wasRequested) {
        await _commonsRepo.cancelJoinSharedPractice(roomId: room.id);
      } else {
        await _commonsRepo.requestJoinSharedPractice(roomId: room.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasRequested) {
          _requestedCommonsRoomIds.add(room.id);
          _clearedCommonsRoomRequestIds.remove(room.id);
        } else {
          _requestedCommonsRoomIds.remove(room.id);
          _clearedCommonsRoomRequestIds.add(room.id);
        }
      });
      _showCommonsActionSnack(
        wasRequested
            ? 'Could not remove that request.'
            : 'Could not send that request.',
      );
    } finally {
      if (mounted) {
        setState(() => _commonsRequestBusyIds.remove(room.id));
      }
    }
  }

  Future<void> _toggleCommonsRoomLike(CommonsPracticeRoom room) async {
    if (_commonsLikeBusyIds.contains(room.id)) return;
    setState(() {
      _commonsLikeBusyIds.add(room.id);
      if (!_optimisticLikedCommonsRoomIds.add(room.id)) {
        _optimisticLikedCommonsRoomIds.remove(room.id);
      }
    });
    try {
      await _commonsRepo.togglePracticeLike(roomId: room.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!_optimisticLikedCommonsRoomIds.add(room.id)) {
          _optimisticLikedCommonsRoomIds.remove(room.id);
        }
      });
      _showCommonsActionSnack('Could not update that like.');
    } finally {
      if (mounted) {
        setState(() => _commonsLikeBusyIds.remove(room.id));
      }
    }
  }

  Future<void> _toggleCommonsQuoteLike(SharedPracticeQuotePost post) async {
    if (_commonsQuoteLikeBusyIds.contains(post.id)) return;
    setState(() => _commonsQuoteLikeBusyIds.add(post.id));
    try {
      await _commonsRepo.toggleQuoteLike(quotePostId: post.id);
      await _loadCommonsHome(force: true);
    } catch (_) {
      if (mounted) _showCommonsActionSnack('Could not update that like.');
    } finally {
      if (mounted) {
        setState(() => _commonsQuoteLikeBusyIds.remove(post.id));
      }
    }
  }

  Future<void> _commentOnCommonsQuote(SharedPracticeQuotePost post) async {
    final controller = TextEditingController();
    final body = await showEditableDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF15110A),
        title: const Text(
          'Comment on quote',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          maxLength: 1000,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Write a comment'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    controller.dispose();
    final clean = body?.trim();
    if (!mounted || clean == null || clean.isEmpty) return;
    try {
      await _commonsRepo.addQuoteComment(quotePostId: post.id, bodyText: clean);
      await _loadCommonsHome(force: true);
    } catch (_) {
      if (mounted) _showCommonsActionSnack('Could not post that comment.');
    }
  }

  List<CommonsPracticeRoom> _commonsPracticeRooms() {
    final home = _commonsHome;
    if (home == null) return const <CommonsPracticeRoom>[];
    final rooms = <CommonsPracticeRoom>[];
    final seen = <String>{};
    for (final room in <CommonsPracticeRoom>[
      ...home.mySharedPractices,
      ...home.publicSharedPractices,
    ]) {
      if (room.id.isEmpty || !seen.add(room.id)) continue;
      if (room.visibility != SharedPracticeRoomVisibility.public ||
          room.memberCount < 2 ||
          room.status.trim().toLowerCase() != 'active') {
        continue;
      }
      rooms.add(room);
    }
    return rooms;
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

  List<Map<String, dynamic>> _flowPayloadEvents(FlowPost post) {
    final rawEvents = post.payloadJson?['events'];
    if (rawEvents is! List) return const [];
    return rawEvents
        .whereType<Map>()
        .map((event) => Map<String, dynamic>.from(event))
        .toList();
  }

  int _clampPostIndex(int length, [int? desired]) {
    if (length == 0) return 0;
    final target = desired ?? _activePostIndex;
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

  void _openFindPeople() {
    unawaited(openDetailRoute<void>(context, '/profile-search'));
  }

  void _openSettings() {
    context.go('/settings');
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
        ? const Color(0xFF070604)
        : showBackdrop
        ? Colors.transparent
        : const Color(0xFF000000);
    final appBarSystemOverlayStyle = SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    );

    final page = Scaffold(
      backgroundColor: const Color(0xFF000000),
      extendBodyBehindAppBar: showBackdrop,
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
            tooltip: 'Find People',
            icon: const KemeticAppBarSearchIcon(gradient: _profileGoldGradient),
            onPressed: _openFindPeople,
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
          if (showBackdrop && !_feedRevealed) ...[
            if (loadingProfileShell) ...[
              const Positioned.fill(child: ProfileDayCycleBackdrop()),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.52),
                          Colors.black.withValues(alpha: 0.44),
                          Colors.black.withValues(alpha: 0.74),
                          _profileSurface,
                        ],
                        stops: const [0.0, 0.34, 0.72, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
          body,
        ],
      ),
    );
    return KeyboardAwareEditableSurface(child: page);
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
            child: _buildHeroSection(profile, topInset: topInset, bio: bio),
          ),
          ColoredBox(color: _profileSurface, child: _buildPostsSection()),
        ],
      ),
    );
  }

  Widget _buildFeedMode() {
    const bottomPadding = 32.0;
    final appBarBottom = MediaQuery.paddingOf(context).top + kToolbarHeight;
    const heroExtent = 168.0;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleFeedScrollNotification,
      child: Padding(
        padding: EdgeInsets.only(top: appBarBottom),
        child: CustomScrollView(
          controller: _feedScrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPersistentHeader(
              delegate: _ProfileFeedHeroHeaderDelegate(
                extent: heroExtent,
                header: _buildFeedHeader(),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileFeedTabsHeaderDelegate(
                extent: _profileFeedTabsHeaderExtent,
                child: _buildPinnedSocialFeedTabs(),
              ),
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: _profileSurface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, bottomPadding),
                  child: _buildFeedPanel(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(
    UserProfile profile, {
    required double topInset,
    required String bio,
  }) {
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.hardEdge,
      children: <Widget>[
        const Positioned.fill(child: ProfileDayCycleBackdrop()),
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x850B0906),
                    Color(0x700B0906),
                    Color(0xBD0B0906),
                    _profileSurface,
                  ],
                  stops: <double>[0.0, 0.34, 0.72, 1.0],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(22, topInset + 32, 22, 22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (profile.handle != null &&
                      profile.handle!.trim().isNotEmpty) ...[
                    Text(
                      '@${profile.handle}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _profileHeroHigh,
                        fontFamily: _profileSerifFont,
                        fontFamilyFallback: _profileSerifFallback,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w400,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    profile.effectiveName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _profileBone,
                      fontSize: 42,
                      fontWeight: FontWeight.w500,
                      height: 1.02,
                      fontFamily: _profileSerifFont,
                      fontFamilyFallback: _profileSerifFallback,
                    ),
                  ),
                  if (profile.avatarGlyphIds.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _buildGlyphSignature(profile),
                  ],
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      bio,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _profileHeroMid,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        height: 1.32,
                        fontFamily: _profileSerifFont,
                        fontFamilyFallback: _profileSerifFallback,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildStats(profile),
                  const SizedBox(height: 20),
                  _buildActionCluster(),
                ],
              ),
            ),
          ),
        ),
      ],
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

    return SizedBox(
      width: 250,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 15, 0, 13),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: _profileSpecGold.withValues(alpha: 0.28)),
            bottom: BorderSide(color: _profileSpecGold.withValues(alpha: 0.28)),
          ),
        ),
        child: Column(
          children: [
            MeduGlyphText(
              glyphs,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _profileSpecGold,
                fontSize: 22,
                fontWeight: FontWeight.w400,
                letterSpacing: 5.28,
                height: 1,
              ),
            ),
            if (meaning.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                meaning,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _profileHeroHigh,
                  fontFamily: _profileSerifFont,
                  fontFamilyFallback: _profileSerifFallback,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  height: 1.2,
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
      if (_isViewingOwnProfile)
        (
          label: 'Active Flows',
          value: (profile.activeFlowsCount ?? 0).toString(),
          onTap: _onActiveFlowsTap,
          enabled: true,
        ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          if (index > 0) const SizedBox(width: 34),
          _buildStatItem(
            label: stats[index].label,
            value: stats[index].value,
            onTap: stats[index].onTap,
            enabled: stats[index].enabled,
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    final numberColor = enabled ? _profileBone : _profileMid;
    final labelColor = enabled
        ? _profileHeroLow
        : _profileHeroLow.withValues(alpha: .6);

    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: numberColor,
                fontSize: 25,
                fontWeight: FontWeight.w500,
                height: 1,
                fontFamily: _profileSerifFont,
                fontFamilyFallback: _profileSerifFallback,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: TextStyle(
                color: labelColor,
                fontFamily: _profileSansFont,
                fontSize: 8.5,
                height: 1.1,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.53,
              ),
            ),
          ],
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
      onPressed: _followUpdating ? null : _toggleFollow,
      busy: _followUpdating,
      backgroundColor: Colors.transparent,
      foregroundColor: _profileHigh,
      borderColor: const Color(0xFF332C1D),
      fullWidth: fullWidth,
      pill: true,
      fontSize: 18,
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
      leading: const HawProfileIcon(
        HawProfileIconKind.edit,
        color: _profileHigh,
      ),
      onPressed: () {
        unawaited(openDetailRoute<void>(context, '/profile/me/edit'));
      },
      foregroundColor: _profileHigh,
      backgroundColor: Colors.white.withValues(alpha: 0.02),
      borderColor: const Color(0xFF332C1D),
      fullWidth: fullWidth,
    );
  }

  Widget _buildSettingsButton({bool fullWidth = false}) {
    return _buildActionButton(
      label: 'Settings',
      leading: const HawProfileIcon(
        HawProfileIconKind.settings,
        color: _profileHigh,
      ),
      onPressed: _openSettings,
      foregroundColor: _profileHigh,
      backgroundColor: Colors.white.withValues(alpha: 0.02),
      borderColor: const Color(0xFF332C1D),
      fullWidth: fullWidth,
    );
  }

  Widget _buildPostButton({bool fullWidth = false}) {
    return _buildActionButton(
      label: 'Post',
      leading: const HawProfileIcon(
        HawProfileIconKind.post,
        color: _profileSpecGold,
      ),
      onPressed: () => unawaited(_openPostChooser()),
      backgroundColor: _profileSpecGold.withValues(alpha: 0.09),
      foregroundColor: _profileBone,
      borderColor: _profileSpecGold.withValues(alpha: 0.5),
      fullWidth: fullWidth,
    );
  }

  Widget _buildActionCluster() {
    if (!_isViewingOwnProfile) {
      return SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            _buildFollowButton(),
            Positioned(right: 0, child: _buildProfileSafetyMenu()),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPostButton(fullWidth: true),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(child: _buildEditButton(fullWidth: true)),
            const SizedBox(width: 9),
            Expanded(child: _buildSettingsButton(fullWidth: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    Widget? leading,
    bool busy = false,
    Color foregroundColor = _profileHigh,
    Color? iconColor,
    Color backgroundColor = Colors.transparent,
    Color borderColor = const Color(0xFF332C1D),
    bool fullWidth = false,
    bool pill = false,
    double fontSize = 17,
  }) {
    const buttonHeight = 49.0;
    final hasLeading = busy || leading != null || icon != null;

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
        else if (leading != null)
          leading
        else if (icon != null)
          Icon(icon, size: 18, color: iconColor ?? foregroundColor),
        if (hasLeading) const SizedBox(width: 9),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
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
            padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 12),
            child: child,
          );

    final radius = BorderRadius.circular(pill ? 999 : 14);
    final interactive = Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: radius,
          border: Border.all(color: borderColor),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: DefaultTextStyle(
            style: TextStyle(color: foregroundColor),
            child: buttonContent,
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

  List<ProfileFeedItem> get _profilePosts {
    return [
      ..._posts.map(ProfileFeedItem.flow),
      ..._insightPosts.map(ProfileFeedItem.insight),
    ]..sort((a, b) {
      final byPublication = b.createdAt.compareTo(a.createdAt);
      return byPublication != 0 ? byPublication : a.id.compareTo(b.id);
    });
  }

  Widget _buildPostsSection() {
    final posts = _profilePosts;
    return Column(
      key: const ValueKey('profile-posts-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 26),
        _buildPostedSectionHeader(
          'Posts',
          countLabel: posts.isNotEmpty
              ? '${_activePostIndex + 1} of ${posts.length}'
              : null,
        ),
        const SizedBox(height: 11),
        _buildPostsPreview(posts),
        const SizedBox(height: 26),
        _buildFeedRevealHint(),
      ],
    );
  }

  Widget _buildProfilePostCard(ProfileFeedItem item) {
    return switch (item.kind) {
      ProfileFeedItemKind.flow => _buildPostCard(
        item.flowPost!,
        onTap: () => _openPostDetails(item.flowPost!),
      ),
      ProfileFeedItemKind.insight => _buildInsightPostCard(
        item.insightPost!,
        onReadMore: () => _openInsightPost(item.insightPost!),
        inPager: true,
      ),
    };
  }

  Widget _buildPostedSectionHeader(String title, {String? countLabel}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFB89A55),
              fontFamily: _profileSansFont,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.09,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(child: Container(height: 1, color: _profileLineSoft)),
          if (countLabel != null) ...<Widget>[
            const SizedBox(width: 11),
            Text(
              countLabel,
              style: const TextStyle(
                color: _profileLow,
                fontFamily: _profileSerifFont,
                fontFamilyFallback: _profileSerifFallback,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostsPreview(List<ProfileFeedItem> posts) {
    if (posts.isEmpty && (_postsLoading || _insightPostsLoading)) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_profileGoldMid),
        ),
      );
    }

    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          decoration: BoxDecoration(
            color: _profileSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _profileLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isViewingOwnProfile ? 'Nothing posted yet' : 'No posts yet',
                style: const TextStyle(
                  color: _profileBone,
                  fontFamily: _profileSerifFont,
                  fontFamilyFallback: _profileSerifFallback,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _isViewingOwnProfile
                    ? 'Post a flow or insight to share it on your profile.'
                    : 'Check back later for posts.',
                style: const TextStyle(
                  color: _profileMid,
                  fontFamily: _profileSerifFont,
                  fontFamilyFallback: _profileSerifFallback,
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          key: const ValueKey<String>('profile-posts-pager'),
          height: 392,
          child: PageView.builder(
            controller: _postPageController,
            physics: const BouncingScrollPhysics(),
            padEnds: false,
            itemCount: posts.length,
            findChildIndexCallback: (key) {
              final index = posts.indexWhere(
                (post) => ValueKey(_profilePostKey(post)) == key,
              );
              return index < 0 ? null : index;
            },
            onPageChanged: (index) {
              setState(() {
                _activePostIndex = index;
                _activeProfilePostKey = _profilePostKey(posts[index]);
              });
              _scheduleContinuitySave();
            },
            itemBuilder: (context, index) {
              final post = posts[index];
              return Padding(
                key: ValueKey(_profilePostKey(post)),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _buildProfilePostCard(post),
              );
            },
          ),
        ),
        if (posts.length > 1) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < posts.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 7),
                  Semantics(
                    button: true,
                    selected: _activePostIndex == i,
                    label: 'Show post ${i + 1} of ${posts.length}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _postPageController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 6,
                        width: _activePostIndex == i ? 18 : 6,
                        decoration: BoxDecoration(
                          color: _activePostIndex == i
                              ? _profileSpecGold
                              : const Color(0xFF332C1D),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
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

  Widget _buildFeedRevealHint() {
    return GestureDetector(
      key: _feedRevealHintKey,
      onTap: () {
        unawaited(_revealFeed());
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            const HawProfileIcon(
              HawProfileIconKind.caretUp,
              color: _profileSpecGold,
              size: 15,
            ),
            const SizedBox(height: 5),
            Text(
              'Swipe up to reveal feed',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _profileHigh,
                fontFamily: _profileSerifFont,
                fontFamilyFallback: _profileSerifFallback,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedHeader() {
    final isCommons = _selectedFeedTab == _SocialFeedTab.todaysCommons;
    return Column(
      key: const ValueKey('feed_header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isCommons ? 'Commons' : 'For You',
          style: const TextStyle(
            color: Color(0xFFF2ECE0),
            fontFamily: _profileSerifFont,
            fontFamilyFallback: _profileSerifFallback,
            fontSize: 30,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          isCommons
              ? 'What practitioners are restoring across the rhythm.'
              : 'Flows and insights chosen for your rhythm.',
          style: TextStyle(
            color: _profileHigh,
            fontFamily: _profileSerifFont,
            fontFamilyFallback: _profileSerifFallback,
            fontSize: 15,
            fontStyle: FontStyle.italic,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const HawProfileIcon(
              HawProfileIconKind.caretDown,
              color: Color(0xFF8A8378),
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              'Pull down at the top to return to profile',
              style: const TextStyle(
                color: Color(0xFF8A8378),
                fontFamily: _profileSansFont,
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _selectFeedTab(_SocialFeedTab tab) async {
    if (_selectedFeedTab == tab) return;
    unawaited(AppHaptics.lightImpact(reason: 'profile_social_feed_tab'));
    setState(() {
      _selectedFeedTab = tab;
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
        color: _profileSurface,
        border: Border(bottom: const BorderSide(color: _profileLine)),
      ),
      child: Align(alignment: Alignment.center, child: _buildSocialFeedTabs()),
    );
  }

  Widget _buildSocialFeedTabButton({
    required _SocialFeedTab tab,
    required String label,
  }) {
    final selected = _selectedFeedTab == tab;
    final color = selected ? _profileSpecGold : _profileLow;
    return InkWell(
      onTap: () => unawaited(_selectFeedTab(tab)),
      child: SizedBox(
        height: _profileFeedTabsHeaderExtent,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontFamily: _profileSansFont,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.2,
                height: 1,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Align(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 2,
                  width: selected ? 70 : 0,
                  color: selected ? _profileSpecGold : Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedPanel() {
    return AnimatedSwitcher(
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
          KeyedSubtree(
            key: const ValueKey('for_you_feed_list'),
            child: _buildFeedGrid(_feedItems),
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
        _buildCommonsGroupQuotesSection(),
        _buildCommonsDiscoverSection(),
      ],
    );
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
    unawaited(openUtilityRoute<void>(context, '/journal'));
  }

  void _openFlowsForCommons() {
    context.go('/flows');
  }

  Widget _buildCommonsRhythmSection() => CommonsRhythmBlock(
    summary: _commonsHome?.rhythm,
    loading: _commonsLoading,
    errorMessage: _commonsErrorMessage,
  );

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

  Widget _buildCommonsQuestionSection() => CommonsQuestionBlock(
    question: _activeCommonsQuestion(),
    composer: _buildCommonsAnswerComposer(_activeCommonsQuestion()),
    editing: _commonsAnswerEditing,
    loading: _commonsLoading,
    answerBuilder: (answer, isMine) =>
        _buildCommonsAnswerCard(answer, isMine: isMine),
  );

  Widget _buildCommonsAnswerComposer(CommonsQuestion question) {
    final myAnswer = question.myAnswer;
    final shouldCompose = _commonsAnswerEditing || myAnswer == null;
    if (!shouldCompose) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          buildCommonsCompactButton(
            'Edit answer',
            primary: true,
            onPressed: () {
              _commonsAnswerController.text = myAnswer.bodyText;
              setState(() => _commonsAnswerEditing = true);
            },
          ),
          buildCommonsCompactButton(
            'Answer privately',
            onPressed: _openJournalForCommonsQuestion,
          ),
        ],
      );
    }

    return CommonsAnswerComposer(
      controller: _commonsAnswerController,
      saving: _commonsAnswerSaving,
      onSave: () => unawaited(_saveCommonsAnswer()),
      onCancel: () {
        _commonsAnswerController.text = myAnswer?.bodyText ?? '';
        setState(() => _commonsAnswerEditing = false);
      },
    );
  }

  Widget _buildCommonsAnswerCard(CommonsAnswer answer, {bool isMine = false}) =>
      CommonsAnswerCard(
        answer: answer,
        isMine: isMine,
        onAction: (value) {
          if (value == 'edit') {
            _commonsAnswerController.text = answer.bodyText;
            setState(() => _commonsAnswerEditing = true);
          } else if (value == 'delete') {
            unawaited(_deleteCommonsAnswer(answer));
          } else if (value == 'report') {
            unawaited(_reportCommonsAnswer(answer));
          } else if (value == 'block') {
            unawaited(_blockCommonsAnswerAuthor(answer));
          }
        },
      );

  Widget _buildCommonsReflectionSection() {
    final fragments = _commonsInsightFragments();
    return buildCommonsSection(
      numeral: 'III',
      title: 'Reflection Stream',
      note: 'Fragments shared with consent. No counts, no acclaim.',
      children: fragments.isEmpty
          ? [
              buildCommonsEmptyState(
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
    return buildCommonsCard(
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
              buildCommonsCompactButton(
                'Open',
                onPressed: () => _openInsightPost(post),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommonsPracticeTogetherSection() {
    final rooms = _commonsPracticeRooms();
    if (_commonsLoading && rooms.isEmpty) {
      return buildCommonsSection(
        numeral: 'IV',
        title: 'Practice Together',
        children: [
          buildCommonsEmptyState(
            'Public group flows are loading.',
            'Commons shows flows that people are already practicing together.',
          ),
        ],
      );
    }

    return buildCommonsSection(
      numeral: 'IV',
      title: 'Practice Together',
      children: rooms.isEmpty
          ? [
              buildCommonsEmptyState(
                'No public group flows yet.',
                'Private groups stay with their members. Public groups appear here after a second person joins.',
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
    return 318 + ((textScale - 1.0).clamp(0.0, 0.4) * 120);
  }

  Widget _buildCommonsPracticeRoomCard(CommonsPracticeRoom room) {
    final liked =
        room.likedByMe ^ _optimisticLikedCommonsRoomIds.contains(room.id);
    final likeCount = math.max(
      0,
      room.likesCount +
          (liked == room.likedByMe
              ? 0
              : liked
              ? 1
              : -1),
    );
    return CommonsPracticeCard(
      room: room,
      liked: liked,
      likeCount: likeCount,
      onLike: _commonsLikeBusyIds.contains(room.id)
          ? null
          : () => unawaited(_toggleCommonsRoomLike(room)),
      onOpen: () =>
          context.push('/shared-practice/${Uri.encodeComponent(room.id)}'),
      viewerAction: _buildCommonsPracticeViewerAction(room),
    );
  }

  Widget _buildCommonsPracticeViewerAction(CommonsPracticeRoom room) {
    if (room.viewerIsMember || room.viewerRequestStatus == 'approved') {
      return buildCommonsCompactButton(
        'Open flow',
        primary: true,
        onPressed: () =>
            context.push('/shared-practice/${Uri.encodeComponent(room.id)}'),
      );
    }
    if (!room.viewerCanRequestJoin) return const SizedBox.shrink();
    final requested =
        _requestedCommonsRoomIds.contains(room.id) ||
        (!_clearedCommonsRoomRequestIds.contains(room.id) &&
            room.viewerRequestStatus == 'pending');
    return buildCommonsCompactButton(
      requested ? 'Requested' : 'Practice Together',
      primary: !requested,
      onPressed: _commonsRequestBusyIds.contains(room.id)
          ? null
          : () => unawaited(_toggleCommonsRoomRequest(room)),
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

  Widget _buildCommonsGroupQuotesSection() {
    final posts =
        _commonsHome?.groupQuotePosts ?? const <SharedPracticeQuotePost>[];
    if (posts.isEmpty) return const SizedBox.shrink();
    return buildCommonsSection(
      numeral: 'V',
      title: 'From Group Conversations',
      note:
          'Quotes selected by group members. The conversation itself stays private.',
      children: <Widget>[
        for (var index = 0; index < posts.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: 12),
          _buildCommonsGroupQuoteCard(posts[index]),
        ],
      ],
    );
  }

  Widget _buildCommonsGroupQuoteCard(SharedPracticeQuotePost post) {
    return buildCommonsCard(
      borderColor: const Color(0xFF30D5C8).withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _buildCommonsStatusPill(
                'Group quote',
                color: const Color(0xFF30D5C8),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  post.flowTitle ?? 'Group flow',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.46),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '“${post.bodyText}”',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontFamily: _profileSerifFont,
              fontFamilyFallback: _profileSerifFallback,
              fontSize: 21,
              fontStyle: FontStyle.italic,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            post.authorLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (post.comments.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            for (final comment in post.comments.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(
                  TextSpan(
                    text: '${comment.authorLabel}: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    children: <InlineSpan>[
                      TextSpan(
                        text: comment.bodyText,
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ),
          ],
          const Divider(color: Color(0xFF2E2920), height: 22),
          Row(
            children: <Widget>[
              TextButton.icon(
                key: ValueKey<String>('commons_group_quote_like_${post.id}'),
                onPressed: _commonsQuoteLikeBusyIds.contains(post.id)
                    ? null
                    : () => unawaited(_toggleCommonsQuoteLike(post)),
                icon: Icon(
                  post.likedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                ),
                label: Text(
                  post.likesCount > 0 ? '${post.likesCount}' : 'Like',
                ),
              ),
              TextButton.icon(
                key: ValueKey<String>('commons_group_quote_comment_${post.id}'),
                onPressed: () => unawaited(_commentOnCommonsQuote(post)),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                label: Text(
                  post.comments.isEmpty ? 'Comment' : '${post.comments.length}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommonsDiscoverSection() {
    final items = _commonsDiscoverItems();
    return buildCommonsSection(
      numeral: 'VI',
      title: 'Discover Practices',
      note: 'Public flows and insights from the wider rhythm.',
      children: _feedLoading && _feedItems.isEmpty
          ? [
              buildCommonsEmptyState(
                'Discover practices are loading.',
                'Public posts will appear here when they are available.',
              ),
            ]
          : items.isEmpty
          ? [
              buildCommonsEmptyState(
                'No discoverable practices yet.',
                _feedErrorMessage ??
                    'Follow practitioners or return after more public posts are available.',
              ),
            ]
          : [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 18),
                _buildCommonsDiscoverPost(items[i]),
              ],
            ],
    );
  }

  Widget _buildCommonsDiscoverPost(ProfileFeedItem item) {
    // Discover and For You intentionally render the same post component.
    // Flow and insight taps both open their canonical detail routes.
    return _buildFeedItemTile(item);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _buildFeedItemTile(items[i]),
          if (i != items.length - 1)
            const SizedBox(height: _profileFeedColumnGap),
        ],
      ],
    );
  }

  Widget _buildFeedItemTile(ProfileFeedItem item) {
    switch (item.kind) {
      case ProfileFeedItemKind.flow:
        return _buildFeedFlowTile(item);
      case ProfileFeedItemKind.insight:
        return _buildFeedInsightTile(item);
    }
  }

  Color _flowPostAccent(FlowPost post, FlowAppearance appearance) {
    return appearance.accentArgb == null
        ? Color(0xFF000000 | (post.color & 0x00FFFFFF))
        : Color(appearance.accentArgb!);
  }

  String _flowPostRelationshipLabel(FlowPost post) {
    if (_ownsPost(post)) return 'You';
    if (post.isFollowingAuthor) return 'Following';
    return '';
  }

  Widget _buildFeedFlowTile(ProfileFeedItem item) {
    final post = item.flowPost!;
    final appearance = FlowAppearance.fromJson(post.payloadJson?['appearance']);
    final accent = _flowPostAccent(post, appearance);
    final canRequestTogether =
        !_ownsPost(post) && post.viewerCanRequestTogether;
    final requestPending = _flowPostRequestIsPending(post);
    return SocialFlowPostTile(
      post: post,
      appearance: appearance,
      accent: accent,
      relationshipLabel: _flowPostRelationshipLabel(post),
      events: _flowPayloadEvents(post),
      postedDateLabel: _formatPostDate(post.createdAt, compact: true),
      isOwner: _ownsPost(post),
      onOpenAuthor: () => _openFeedAuthorProfile(post.userId),
      onOpenFlow: () => _openFeedFlowPost(post),
      onShare: () => FlowPostShareActions.open(context, post),
      onSaveOrEdit: _ownsPost(post)
          ? () => unawaited(_editPostCaption(post))
          : () => unawaited(_savePost(post)),
      onTogether: canRequestTogether
          ? () => unawaited(_toggleTogetherRequest(post))
          : null,
      togetherLabel: requestPending ? 'Requested' : 'Together',
    );
  }

  Widget _buildFeedInsightTile(ProfileFeedItem item) {
    final post = item.insightPost!;
    final relationship = _ownsInsightPost(post)
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: _profileGoldMid.withValues(alpha: 0.12)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFeedAuthorHeader(
              userId: post.userId,
              displayName: post.authorLabel,
              handle: post.authorHandle,
              showHandle: showHandle,
              avatarUrl: post.authorAvatarUrl,
              avatarGlyphIds: post.authorAvatarGlyphIds,
              relationshipLabel: relationship,
              relationshipColor: _profileGoldText.withValues(alpha: 0.66),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => _openInsightPost(post),
              borderRadius: BorderRadius.circular(17),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0B08),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: _profileGoldMid.withValues(alpha: 0.30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INSIGHT · ${post.nodeTitle}'.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _profileGoldText.withValues(alpha: 0.78),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _insightPreviewText(post.bodyText),
                      maxLines: 7,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF2ECE0),
                        fontFamily: _profileSerifFont,
                        fontFamilyFallback: _profileSerifFallback,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        height: 1.28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'From a saved node insight · ${_formatPostDate(post.entryDate, compact: true)}',
                      style: TextStyle(
                        color: const Color(0xFFA69A83).withValues(alpha: 0.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Posted ${_formatPostDate(post.createdAt, compact: true)}',
              style: TextStyle(
                color: _postDateTextColor(0.50),
                fontFamily: _profileSerifFont,
                fontFamilyFallback: _profileSerifFallback,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
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
    String? relationshipLabel,
    Color? relationshipColor,
  }) {
    return SocialPostAuthorHeader(
      displayName: displayName,
      handle: handle,
      showHandle: showHandle,
      avatarUrl: avatarUrl,
      avatarGlyphIds: avatarGlyphIds,
      avatarRadius: avatarRadius,
      nameFontSize: nameFontSize + 3,
      handleFontSize: handleFontSize,
      relationshipLabel: relationshipLabel,
      relationshipColor: relationshipColor,
      onTap: () => _openFeedAuthorProfile(userId),
    );
  }

  Widget _buildPostCard(FlowPost post, {required VoidCallback onTap}) {
    final appearance = FlowAppearance.fromJson(post.payloadJson?['appearance']);
    final ownsPost = _ownsPost(post);
    final canRequestTogether = !ownsPost && post.viewerCanRequestTogether;
    final requestPending = _flowPostRequestIsPending(post);
    final profile = _profile!;
    return ProfileFlowPostTile(
      post: post,
      appearance: appearance,
      accent: _flowPostAccent(post, appearance),
      relationshipLabel: _flowPostRelationshipLabel(post),
      authorDisplayName: profile.effectiveName,
      authorHandle: profile.handle,
      authorAvatarUrl: profile.avatarUrl,
      authorAvatarGlyphIds: profile.avatarGlyphIds,
      events: _flowPayloadEvents(post),
      postedDateLabel: _formatPostDate(post.createdAt, compact: true),
      isOwner: ownsPost,
      onOpenAuthor: () {},
      onOpenFlow: onTap,
      onOpenMenu: (anchor) => unawaited(
        ownsPost
            ? _openOwnedPostActions(post, anchor)
            : _openVisitorPostActions(post, anchor),
      ),
      onShare: () => FlowPostShareActions.open(context, post),
      onSave: ownsPost
          ? null
          : _savedFlowPostIds.contains(post.id)
          ? () {}
          : () => unawaited(_savePost(post)),
      isSaved: _savedFlowPostIds.contains(post.id),
      onTogether: canRequestTogether
          ? () => unawaited(_toggleTogetherRequest(post))
          : null,
      togetherLabel: requestPending ? 'Requested' : 'Together',
    );
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

  String _formatPostDate(DateTime date, {bool compact = false}) {
    if (!_useGregorianPostDates) {
      return formatKemeticDate(
        date,
        includeGregorianYear: !compact,
        useShortMonthName: compact,
      );
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

  void _openPostDetails(FlowPost post) {
    final initialIndex = _posts.indexWhere(
      (candidate) => candidate.id == post.id,
    );
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

  Future<void> _openPostChooser() async {
    final choice = await showModalBottomSheet<_ProfilePostKind>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xB3000000),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Material(
          color: const Color(0xFF0D0A06),
          elevation: 18,
          shadowColor: const Color(0xB3000000),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            side: BorderSide(color: _profileLine),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  child: Container(
                    width: 43,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3325),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Post',
                  style: TextStyle(
                    color: _profileBone,
                    fontFamily: _profileSerifFont,
                    fontFamilyFallback: _profileSerifFallback,
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                _buildPostChooserOption(
                  sheetContext,
                  kind: _ProfilePostKind.flow,
                  title: 'A flow',
                  subtitle: 'Share one of your flows with a line about it.',
                ),
                _buildPostChooserOption(
                  sheetContext,
                  kind: _ProfilePostKind.insight,
                  title: 'An insight',
                  subtitle: 'Post something you wrote inside a node page.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _ProfilePostKind.flow:
        _openPostPicker();
        return;
      case _ProfilePostKind.insight:
        _openInsightPostPicker();
        return;
    }
  }

  Widget _buildPostChooserOption(
    BuildContext sheetContext, {
    required _ProfilePostKind kind,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _profileLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(sheetContext).pop(kind),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: _profileBone,
                    fontFamily: _profileSerifFont,
                    fontFamilyFallback: _profileSerifFallback,
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _profileMid,
                    fontFamily: _profileSerifFont,
                    fontFamilyFallback: _profileSerifFallback,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPostPicker() {
    unawaited(openDetailRoute<void>(context, '/profile/flow-post-picker'));
  }

  void _openInsightPostPicker() {
    unawaited(openDetailRoute<void>(context, '/profile/insight-post-picker'));
  }

  Future<void> _editPostCaption(FlowPost post) async {
    final appearance = FlowAppearance.fromJson(post.payloadJson?['appearance']);
    final caption = await showFlowPostCaptionSheet(
      context: context,
      initialCaption: post.sharedNote,
      actionLabel: 'Save caption',
      preview: PostedFlowArtifact(
        name: post.name,
        color: post.color,
        notes: post.notes,
        startDate: post.startDate,
        endDate: post.endDate,
        events: _flowPayloadEvents(post),
        appearance: appearance,
      ),
    );
    if (caption == null || !mounted) return;

    final updated = await _repo.updateFlowPostSharedNote(
      post,
      sharedNote: caption,
    );
    if (!mounted) return;
    if (!updated) {
      _showError('Could not update this caption.');
      return;
    }
    await _loadPosts();
    if (_feedRevealed) {
      await _loadFeedPage(reset: true);
    }
  }

  Future<T?> _showProfileOverflowMenu<T>({
    required Rect anchor,
    required List<_ProfileOverflowMenuChoice<T>> choices,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss post menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 140),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
      pageBuilder: (overlayContext, animation, secondaryAnimation) {
        final media = MediaQuery.of(overlayContext);
        final menuHeight = (choices.length * 43.2) + choices.length - 1 + 2;
        final minimumTop = media.padding.top + 8;
        final maximumTop = math.max(
          minimumTop,
          media.size.height - media.padding.bottom - menuHeight - 8,
        );
        final top = (anchor.bottom + 6).clamp(minimumTop, maximumTop);

        return Stack(
          children: <Widget>[
            Positioned(
              top: top,
              right: 16,
              width: 172,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF17130D),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xFF332B1E)),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x8C000000),
                        blurRadius: 35,
                        offset: Offset(0, 15),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: const Color(0xFF17130D),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (
                            var index = 0;
                            index < choices.length;
                            index++
                          ) ...<Widget>[
                            InkWell(
                              onTap: () => Navigator.of(
                                overlayContext,
                              ).pop(choices[index].value),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    choices[index].label,
                                    style: TextStyle(
                                      color: choices[index].destructive
                                          ? const Color(0xFFC98F82)
                                          : const Color(0xFFE7DFD2),
                                      fontFamily: _profileSerifFont,
                                      fontFamilyFallback: _profileSerifFallback,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (index != choices.length - 1)
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: Color(0xFF2A2318),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openOwnedPostActions(FlowPost post, Rect anchor) async {
    final action = await _showProfileOverflowMenu<_OwnedPostAction>(
      anchor: anchor,
      choices: const <_ProfileOverflowMenuChoice<_OwnedPostAction>>[
        _ProfileOverflowMenuChoice<_OwnedPostAction>(
          label: 'Edit caption',
          value: _OwnedPostAction.edit,
        ),
        _ProfileOverflowMenuChoice<_OwnedPostAction>(
          label: 'Share',
          value: _OwnedPostAction.share,
        ),
        _ProfileOverflowMenuChoice<_OwnedPostAction>(
          label: 'Remove post',
          value: _OwnedPostAction.remove,
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _OwnedPostAction.edit:
        await _editPostCaption(post);
        return;
      case _OwnedPostAction.share:
        await FlowPostShareActions.open(context, post);
        return;
      case _OwnedPostAction.remove:
        break;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0F),
        title: const Text(
          'Delete this post?',
          style: TextStyle(color: Color(0xFFF2ECE0)),
        ),
        content: const Text(
          'The flow itself stays in My Flows. This removes only the social post.',
          style: TextStyle(color: Color(0xFFA69A83)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete post'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _removePost(post.id);
  }

  Future<void> _openVisitorPostActions(FlowPost post, Rect anchor) async {
    if (_ownsPost(post) || _profileSafetyUpdating) return;
    final action = await _showProfileOverflowMenu<_VisitorPostAction>(
      anchor: anchor,
      choices: const <_ProfileOverflowMenuChoice<_VisitorPostAction>>[
        _ProfileOverflowMenuChoice<_VisitorPostAction>(
          label: 'Save flow',
          value: _VisitorPostAction.save,
        ),
        _ProfileOverflowMenuChoice<_VisitorPostAction>(
          label: 'Share',
          value: _VisitorPostAction.share,
        ),
        _ProfileOverflowMenuChoice<_VisitorPostAction>(
          label: 'Report',
          value: _VisitorPostAction.report,
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _VisitorPostAction.save:
        await _savePost(post);
        return;
      case _VisitorPostAction.share:
        await FlowPostShareActions.open(context, post);
        return;
      case _VisitorPostAction.report:
        await _reportFlowPost(post);
        return;
    }
  }

  Future<void> _reportFlowPost(FlowPost post) async {
    if (_profileSafetyUpdating || _ownsPost(post)) return;
    setState(() => _profileSafetyUpdating = true);
    final ok = await _repo.reportContent(
      contentType: 'flow_post',
      contentId: post.id,
      reportedUserId: post.userId,
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

  Future<void> _savePost(FlowPost post) async {
    final flowId = await _repo.saveFlowPostToMyFlows(post);
    if (!mounted) return;
    if (flowId == null) {
      _showError('Could not save this flow.');
      return;
    }
    setState(() => _savedFlowPostIds.add(post.id));
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
    await _loadInsightPosts();
    if (_feedRevealed) {
      await _loadFeedPage(reset: true);
    }
  }
}

enum _ProfilePostKind { flow, insight }

enum _OwnedPostAction { edit, share, remove }

enum _VisitorPostAction { save, share, report }

class _ProfileOverflowMenuChoice<T> {
  const _ProfileOverflowMenuChoice({
    required this.label,
    required this.value,
    this.destructive = false,
  });

  final String label;
  final T value;
  final bool destructive;
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

class _ProfileFeedHeroHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileFeedHeroHeaderDelegate({
    required this.extent,
    required this.header,
  });

  final double extent;
  final Widget header;

  @override
  double get minExtent => 0;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRect(
      key: const ValueKey<String>('profile-feed-pyramid-hero'),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Transform.translate(
            offset: Offset(0, shrinkOffset * 0.34),
            child: const ProfileDayCycleBackdrop(
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x660B0906),
                  Color(0x520B0906),
                  Color(0xBD0B0906),
                  Color(0xFF0B0906),
                ],
                stops: <double>[0.0, 0.38, 0.72, 1.0],
              ),
            ),
          ),
          Positioned(left: 20, right: 20, bottom: 15, child: header),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileFeedHeroHeaderDelegate oldDelegate) {
    return extent != oldDelegate.extent || header != oldDelegate.header;
  }
}
