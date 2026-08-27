import 'package:flutter/material.dart';

import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';

import '../../domain/sky_catalog.dart';
import '../../services/follow_sky_turning_controller.dart';
import '../../services/full_moon_instrument_data_provider.dart';
import '../../services/sky_instrument_data_provider.dart';
import '../follow_sky_observation_presentation_model.dart';
import 'follow_sky_observation_presentation.dart';

/// Resolves catalog/provider data once per opened occurrence, then hands the
/// generic immutable model to the one shared presentation shell.
class FollowSkyObservationPresentationLoader extends StatefulWidget {
  const FollowSkyObservationPresentationLoader({
    super.key,
    required this.catalog,
    required this.skyEventId,
    required this.clientEventId,
    required this.completionIdentity,
    required this.localDate,
    required this.scheduledTimeSnapshot,
    required this.intentionSnapshot,
    required this.onCommitCompletion,
    this.onWriteJournalResponse,
    this.instrumentProvider,
    this.now,
  });

  final SkyCatalog catalog;
  final String skyEventId;
  final String clientEventId;
  final String completionIdentity;
  final DateTime localDate;
  final DateTime scheduledTimeSnapshot;
  final String? intentionSnapshot;
  final FollowSkyCompletionCommit onCommitCompletion;
  final MaatJournalResponseBlockWriter? onWriteJournalResponse;
  final SkyInstrumentDataProvider? instrumentProvider;
  final DateTime Function()? now;

  @override
  State<FollowSkyObservationPresentationLoader> createState() =>
      _FollowSkyObservationPresentationLoaderState();
}

class _FollowSkyObservationPresentationLoaderState
    extends State<FollowSkyObservationPresentationLoader> {
  late Future<FollowSkyObservationPresentationModel> _model;

  @override
  void initState() {
    super.initState();
    _model = _resolve();
  }

  @override
  void didUpdateWidget(
    covariant FollowSkyObservationPresentationLoader oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog != widget.catalog ||
        oldWidget.skyEventId != widget.skyEventId ||
        oldWidget.intentionSnapshot != widget.intentionSnapshot ||
        oldWidget.instrumentProvider != widget.instrumentProvider) {
      _model = _resolve();
    }
  }

  Future<FollowSkyObservationPresentationModel> _resolve() async {
    final provider =
        widget.instrumentProvider ?? FullMoonInstrumentDataProvider();
    try {
      return await FollowSkyObservationPresentationModelFactory(
        instrumentProvider: provider,
      ).build(
        catalog: widget.catalog,
        skyEventId: widget.skyEventId,
        intention: widget.intentionSnapshot,
      );
    } on Object {
      if (provider is CatalogSkyInstrumentDataProvider) rethrow;
      return FollowSkyObservationPresentationModelFactory(
        instrumentProvider: const CatalogSkyInstrumentDataProvider(),
      ).build(
        catalog: widget.catalog,
        skyEventId: widget.skyEventId,
        intention: widget.intentionSnapshot,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FollowSkyObservationPresentationModel>(
      future: _model,
      builder: (context, snapshot) {
        final model = snapshot.data;
        if (model != null) {
          return FollowSkyObservationPresentation(
            model: model,
            now: widget.now,
            clientEventId: widget.clientEventId,
            completionIdentity: widget.completionIdentity,
            skyEventId: widget.skyEventId,
            localDate: widget.localDate,
            scheduledTimeSnapshot: widget.scheduledTimeSnapshot,
            intentionSnapshot: widget.intentionSnapshot,
            onWriteJournalResponse: widget.onWriteJournalResponse,
            onCommitCompletion: widget.onCommitCompletion,
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'This sky instrument could not open. Your calendar event is unchanged.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9E9A94), height: 1.4),
              ),
            ),
          );
        }
        return const Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Color(0xFFA4B1FF),
            ),
          ),
        );
      },
    );
  }
}
