# Phase 0.3: Comprehensive Test Matrix

## 🎯 **Test Overview**
**Goal**: Validate all Phase 0.3 notification features work correctly  
**Time**: ~30-60 minutes  
**Pass Rate Target**: ≥90% (20/22 tests)

---

## 📋 **Pre-Test Setup**

### **Before Starting:**
- [ ] App is running in debug mode
- [ ] Console is open and visible
- [ ] Debug panel accessible (bug icon in app bar)
- [ ] User is logged in to Supabase
- [ ] Device notifications are enabled

### **Initial State Check:**
```dart
// Run this first to see current state:
await Notify.debugCompareDeviceAndDatabase();
```

**Expected**: Clear console output showing sync status

---

## 🧪 **Test Categories**

### **Category 1: Basic Scheduling (3 tests)**

#### **Test 1.1: Create Event Tomorrow**
**Steps:**
1. Tap "+" button in main calendar
2. Set title: "Test Event Tomorrow"
3. Set date: Tomorrow
4. Set time: 9:00 AM
5. Tap "Save"

**Expected Results:**
- [ ] Event appears in calendar
- [ ] Console shows: "SCHEDULING NOTIFICATION"
- [ ] Console shows: "Notification ID: XXXXXX (hash-based)"
- [ ] Console shows: "Scheduling in LOCAL timezone"
- [ ] Notification appears in device settings

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 1.2: App Restart Persistence**
**Steps:**
1. Kill app completely (swipe up, force close)
2. Restart app
3. Wait for "Rescheduling X active notifications" message
4. Check device notifications still exist

**Expected Results:**
- [ ] Console shows: "Rescheduling X active notifications"
- [ ] Console shows: "✅ Rescheduled X notifications"
- [ ] Same notification still pending on device
- [ ] No duplicate notifications created

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 1.3: Notification Fires**
**Steps:**
1. Create event for 2 minutes from now
2. Wait for notification to fire
3. Tap notification

**Expected Results:**
- [ ] Notification appears at correct time
- [ ] Notification shows correct title
- [ ] Tapping notification opens app
- [ ] Console shows notification was delivered

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

### **Category 2: Timezone & DST (3 tests)**

#### **Test 2.1: Local Timezone Display**
**Steps:**
1. Create event for tomorrow 2:00 PM
2. Check device notification settings
3. Verify time shows as 2:00 PM local

**Expected Results:**
- [ ] Device settings show 2:00 PM (not UTC)
- [ ] Console shows: "Scheduling in LOCAL timezone: [timezone]"
- [ ] Time matches device's current timezone

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 2.2: Timezone Change**
**Steps:**
1. Create event for tomorrow 3:00 PM
2. Change device timezone to different zone
3. Check notification time adjusts

**Expected Results:**
- [ ] Notification time updates to new timezone
- [ ] Still shows 3:00 PM in new timezone
- [ ] No duplicate notifications

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 2.3: DST Transition** (Simulate)
**Steps:**
1. Create event for tomorrow 10:00 AM
2. Manually change device date to DST transition day
3. Check notification still fires at correct local time

**Expected Results:**
- [ ] Notification fires at 10:00 AM local time
- [ ] No time drift due to DST
- [ ] Console shows correct local timezone

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

### **Category 3: Event Editing (2 tests)**

#### **Test 3.1: Change Event Time**
**Steps:**
1. Create event for tomorrow 1:00 PM
2. Edit event to change time to 3:00 PM
3. Save changes
4. Check notifications

**Expected Results:**
- [ ] Only ONE notification exists (no duplicates)
- [ ] Notification shows 3:00 PM time
- [ ] Console shows: "[edit-event] ✅ Rescheduled notification"
- [ ] Old 1:00 PM notification cancelled

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 3.2: Change Event Title**
**Steps:**
1. Create event with title "Original Title"
2. Edit to change title to "Updated Title"
3. Save changes

**Expected Results:**
- [ ] Notification title updates to "Updated Title"
- [ ] Same notification ID (stable hash)
- [ ] Console shows reschedule with new title

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

### **Category 4: Event Deletion (2 tests)**

#### **Test 4.1: Delete Event**
**Steps:**
1. Create event for tomorrow
2. Delete the event
3. Check notifications

**Expected Results:**
- [ ] Notification cancelled from device
- [ ] Console shows: "Cancelled notification XXXXXX"
- [ ] No orphaned notifications remain

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 4.2: End Flow**
**Steps:**
1. Create a flow with recurring events
2. End the flow
3. Check all flow notifications cancelled

**Expected Results:**
- [ ] All flow notifications cancelled
- [ ] Console shows multiple cancellation messages
- [ ] No flow notifications remain

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

### **Category 5: Recurring Flows (2 tests)**

#### **Test 5.1: Schedule Recurring Flow**
**Steps:**
1. Create flow with rule "Every Monday at 9 AM"
2. Save flow
3. Check notifications scheduled

**Expected Results:**
- [ ] Console shows: "[flow] Scheduled X notifications for next 30 days"
- [ ] 4-5 Monday notifications scheduled
- [ ] All show "Flow: [FlowName] - [EventTitle]"
- [ ] All use `NotificationType.flowStep`

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 5.2: First Occurrence Fires**
**Steps:**
1. Wait for first Monday notification to fire
2. Check remaining notifications still scheduled

**Expected Results:**
- [ ] First Monday notification fires correctly
- [ ] Remaining Monday notifications still pending
- [ ] No duplicates created
- [ ] Console shows successful delivery

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

### **Category 6: Edge Cases (3 tests)**

#### **Test 6.1: Past Event**
**Steps:**
1. Try to create event for yesterday
2. Check if notification is skipped

**Expected Results:**
- [ ] Event created successfully
- [ ] No notification scheduled (past event)
- [ ] Console shows: "Skipping past event"

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 6.2: All-Day Event**
**Steps:**
1. Create all-day event for tomorrow
2. Check notification defaults to 9:00 AM

**Expected Results:**
- [ ] Notification scheduled for 9:00 AM
- [ ] Console shows: "default 9:00 AM"
- [ ] Notification fires at correct time

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 6.3: Rapid Edit/Delete**
**Steps:**
1. Create event
2. Immediately edit time
3. Immediately delete event
4. Check for orphaned notifications

**Expected Results:**
- [ ] No orphaned notifications
- [ ] No duplicate notifications
- [ ] Console shows proper cancellation
- [ ] Clean state after operations

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

### **Category 7: Debug Tools (7 tests)**

#### **Test 7.1: Test Now Button**
**Steps:**
1. Open debug panel
2. Tap "Test Now" button
3. Check immediate notification

**Expected Results:**
- [ ] Immediate notification appears
- [ ] SnackBar shows "Test notification sent!"
- [ ] Console shows test notification logs

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 7.2: Test in 10 sec Button**
**Steps:**
1. Tap "Test in 10 sec" button
2. Wait 10 seconds
3. Check notification fires

**Expected Results:**
- [ ] Notification appears after 10 seconds
- [ ] SnackBar shows "Scheduled in 10 seconds"
- [ ] Console shows scheduling logs

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 7.3: Show Pending Button**
**Steps:**
1. Tap "Show Pending" button
2. Check console output

**Expected Results:**
- [ ] Console shows device notifications
- [ ] Shows notification IDs, titles, bodies
- [ ] Count matches device settings

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 7.4: Show Database Button**
**Steps:**
1. Tap "Show Database" button
2. Check console output

**Expected Results:**
- [ ] Console shows database notifications
- [ ] Shows notification_type column
- [ ] Shows all notification details

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 7.5: Compare Device vs DB Button**
**Steps:**
1. Tap "Compare Device vs DB" button
2. Check comprehensive output

**Expected Results:**
- [ ] Shows permissions check
- [ ] Shows database contents
- [ ] Shows device contents
- [ ] Shows sync comparison
- [ ] Provides recommendations

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 7.6: Reschedule All Button**
**Steps:**
1. Tap "Reschedule All" button
2. Check console output

**Expected Results:**
- [ ] Console shows: "🔄 Force rescheduling all notifications..."
- [ ] Shows reschedule progress
- [ ] SnackBar shows "Rescheduled all"
- [ ] All notifications rescheduled

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

#### **Test 7.7: Cancel All Button**
**Steps:**
1. Tap "Cancel All" button
2. Check all notifications cleared

**Expected Results:**
- [ ] All device notifications cancelled
- [ ] All database notifications marked inactive
- [ ] Console shows cancellation count
- [ ] SnackBar shows "Cancelled all"

**Pass/Fail**: ☐ **PASS** / ☐ **FAIL**

---

## 📊 **Test Results Summary**

### **Overall Results:**
- **Total Tests**: 22
- **Passed**: ___ / 22
- **Failed**: ___ / 22
- **Pass Rate**: ___%

### **Category Breakdown:**
| Category | Tests | Passed | Failed | Pass Rate |
|----------|-------|--------|--------|-----------|
| Basic Scheduling | 3 | ___ | ___ | ___% |
| Timezone & DST | 3 | ___ | ___ | ___% |
| Event Editing | 2 | ___ | ___ | ___% |
| Event Deletion | 2 | ___ | ___ | ___% |
| Recurring Flows | 2 | ___ | ___ | ___% |
| Edge Cases | 3 | ___ | ___ | ___% |
| Debug Tools | 7 | ___ | ___ | ___% |

---

## 🐛 **Issues Found**

### **Critical Issues (Block Phase 0.3):**
- [ ] None

### **High Priority Issues:**
- [ ] None

### **Medium Priority Issues:**
- [ ] None

### **Low Priority Issues:**
- [ ] None

---

## 📝 **Test Notes**

### **What Worked Well:**
- 
- 
- 

### **Areas for Improvement:**
- 
- 
- 

### **Unexpected Behavior:**
- 
- 
- 

---

## ✅ **Phase 0.3 Completion Criteria**

### **Must Pass (90%+):**
- [ ] All basic scheduling tests (3/3)
- [ ] All timezone tests (3/3)
- [ ] All editing tests (2/2)
- [ ] All deletion tests (2/2)
- [ ] All debug tool tests (7/7)

### **Should Pass (80%+):**
- [ ] Recurring flow tests (2/2)
- [ ] Edge case tests (3/3)

### **Overall Pass Rate:**
- [ ] ≥90% (20/22 tests) ✅ **PHASE 0.3 COMPLETE**
- [ ] 80-89% (18-21 tests) ⚠️ **Minor issues to fix**
- [ ] <80% (<18 tests) ❌ **Major issues to fix**

---

## 🚀 **Next Steps**

### **If Pass Rate ≥90%:**
1. ✅ Phase 0.3 is complete!
2. ✅ Update documentation
3. ✅ Ready for Phase 1.1

### **If Pass Rate 80-89%:**
1. ⚠️ Fix failed tests
2. ⚠️ Re-run test matrix
3. ⚠️ Document fixes

### **If Pass Rate <80%:**
1. ❌ Major debugging needed
2. ❌ Check console logs
3. ❌ Use debug tools to diagnose

---

## 💡 **Testing Tips**

1. **Start with "Compare Device vs DB"** - gives complete picture
2. **Keep console open** - very detailed logging
3. **Test one category at a time** - easier to track
4. **Use "Cancel All" → "Reschedule All"** to reset between tests
5. **Take screenshots** of any failures for debugging
6. **Check device notification settings** regularly
7. **Test on real device** for best results

---

## 📞 **Need Help?**

If you encounter issues:
1. Check console output first
2. Use debug tools to diagnose
3. Share console logs or test results
4. Focus on critical tests first

**Good luck with testing!** 🧪✨

