-- Phase 0.3: Add notification_type column to scheduled_notifications table
-- Run this in Supabase SQL Editor

-- Add notification_type column with default value
ALTER TABLE scheduled_notifications 
ADD COLUMN IF NOT EXISTS notification_type VARCHAR(20) DEFAULT 'event_start';

-- Add index for faster queries by notification type
CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_type 
ON scheduled_notifications(user_id, notification_type, is_active);

-- Add comment explaining the column
COMMENT ON COLUMN scheduled_notifications.notification_type IS 
'Type of notification: event_start, reminder_10min, daily_review, flow_step';

-- Verify the column was added
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'scheduled_notifications' 
AND column_name = 'notification_type';

