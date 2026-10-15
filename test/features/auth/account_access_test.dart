import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/account_access.dart';

void main() {
  testWidgets(
    'account replacement while permission is pending rejects the action',
    (tester) async {
      String? owner = 'first';
      final permission = Completer<bool>();
      late BuildContext actionContext;
      await tester.pumpWidget(
        MaterialApp(
          home: AccountAccess(
            signedIn: true,
            accountId: 'first',
            currentAccountId: () => owner,
            requestAccount: ({resumeLocation}) => permission.future,
            child: Builder(
              builder: (context) {
                actionContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final action = AccountAccess.require(actionContext);
      owner = 'other';
      permission.complete(true);
      expect(await action, isFalse);
    },
  );

  testWidgets('member action rejects an account departure before invocation', (
    tester,
  ) async {
    String? owner = 'first';
    var requests = 0;
    late BuildContext actionContext;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountAccess(
          signedIn: true,
          accountId: 'first',
          currentAccountId: () => owner,
          requestAccount: ({resumeLocation}) async {
            requests++;
            return true;
          },
          child: Builder(
            builder: (context) {
              actionContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(await AccountAccess.require(actionContext), isTrue);
    expect(requests, 1);
    owner = 'other';
    expect(await AccountAccess.require(actionContext), isFalse);
    owner = null;
    expect(await AccountAccess.require(actionContext), isFalse);
    expect(requests, 1);
  });
  testWidgets(
    'guest cancellation and setup retry retain the shared policy result',
    (tester) async {
      var permitted = false;
      late BuildContext actionContext;
      await tester.pumpWidget(
        MaterialApp(
          home: AccountAccess(
            signedIn: false,
            requestAccount: ({resumeLocation}) async => permitted,
            child: Builder(
              builder: (context) {
                actionContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(await AccountAccess.require(actionContext), isFalse);
      permitted = true;
      expect(await AccountAccess.require(actionContext), isTrue);
    },
  );
}
