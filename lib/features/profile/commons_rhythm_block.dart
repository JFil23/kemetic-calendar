import 'package:flutter/material.dart';
import '../../data/commons_models.dart';
import 'commons_question_block.dart';

const _profileGoldText = Color(0xFFF1CF7A);
const _profileSerifFont = 'CormorantGaramond';
const _profileSerifFallback = ['GentiumPlus', 'Georgia', 'serif'];

/// Same public metrics and pulse-row presentation used by Commons and Pages.
class CommonsRhythmBlock extends StatelessWidget {
  const CommonsRhythmBlock({
    super.key,
    this.summary,
    this.loading = false,
    this.errorMessage,
    this.pane = false,
  });
  final CommonsRhythmSummary? summary;
  final bool loading, pane;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (!pane) return _buildSection();
    final data = summary;
    if (data == null) return const SizedBox.shrink();
    return buildCommonsCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'PUBLIC RHYTHM',
            style: TextStyle(
              color: _profileGoldText,
              fontSize: 6.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: _buildCommonsPulseRow(
              count: data.activeUsersTodayLabel,
              text: "People keeping Ma’at",
            ),
          ),
          Expanded(
            child: _buildCommonsPulseRow(
              count: data.flowsKeptTodayLabel,
              text: 'Flow steps recorded',
            ),
          ),
          Expanded(
            child: _buildCommonsPulseRow(
              count: data.publicFragmentsTodayLabel,
              text: 'Public fragments shared',
              quiet: data.publicFragmentsTodayLabel == '0',
            ),
          ),
          Expanded(
            child: _buildCommonsPulseRow(
              count: data.publicRoomsOpenLabel,
              text: 'Practices open to join',
              quiet: data.publicRoomsOpenLabel == '0',
            ),
          ),
          if (data.topFlowTitle?.trim().isNotEmpty == true)
            Expanded(
              child: _buildCommonsPulseRow(
                count: data.topFlowCountLabel ?? '',
                text: 'Top flow: ${data.topFlowTitle}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection() {
    final rhythm = this.summary;
    if (loading && rhythm == null) {
      return buildCommonsSection(
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
    return buildCommonsSection(
      numeral: 'I',
      title: 'Public Rhythm',
      note: errorMessage,
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

  Widget _buildCommonsPulseRow({
    required String count,
    required String text,
    bool quiet = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: pane ? 0 : 16,
        vertical: pane ? 0 : 15,
      ),
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
            width: pane ? 28 : 62,
            child: Text(
              count,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: quiet
                    ? Colors.white.withValues(alpha: 0.58)
                    : _profileGoldText,
                fontFamily: _profileSerifFont,
                fontFamilyFallback: _profileSerifFallback,
                fontSize: pane ? (quiet ? 10 : 12) : (quiet ? 18 : 30),
                fontWeight: quiet ? FontWeight.w500 : FontWeight.w700,
                fontStyle: quiet ? FontStyle.italic : FontStyle.normal,
                height: 1,
              ),
            ),
          ),
          SizedBox(width: pane ? 7 : 14),
          Expanded(
            child: Text(
              text,
              maxLines: pane ? 1 : null,
              overflow: pane ? TextOverflow.ellipsis : null,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontFamily: _profileSerifFont,
                fontFamilyFallback: _profileSerifFallback,
                fontSize: pane ? 8.5 : 18,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
