/// Returns the label for the shift that contains [time].
String shiftLabelFor(DateTime time) {
  final hour = time.hour;

  if (hour >= 8 && hour < 12) {
    return 'Morning Shift (8 AM - 12 PM)';
  }
  if (hour >= 12 && hour < 18) {
    return 'Evening Shift (12 PM - 6 PM)';
  }
  return 'Night Shift (6 PM - 8 AM)';
}

/// Uses the device's current local time to determine the active shift.
String currentShiftLabel() => shiftLabelFor(DateTime.now());
