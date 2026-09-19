import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flows_repo.dart';
import 'package:mobile/features/profile/flow_post_picker_page.dart';

void main() {
  FlowRow row(String ownerId) => FlowRow.fromRow(<String, dynamic>{
    'id': 41,
    'user_id': ownerId,
    'name': 'The Reading House',
    'color': 0x3FA98A,
    'active': true,
    'is_saved': false,
    'start_date': null,
    'end_date': null,
    'notes': 'maat=the-reading-house;reading_house_state=held_house',
    'rules': const <Object?>[],
    'visible_in_active_list': true,
  });

  test('host-owned filed house remains eligible for profile publishing', () {
    expect(canUserPublishFlow(row('host-user'), 'host-user'), isTrue);
  });

  test('accepted member cannot publish a host-owned filed house', () {
    expect(canUserPublishFlow(row('host-user'), 'reader-user'), isFalse);
    expect(canUserPublishFlow(row('host-user'), null), isFalse);
  });
}
