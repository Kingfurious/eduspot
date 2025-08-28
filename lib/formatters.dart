// START OF FILE formatters.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Needed for advanced formatting if desired

// Utility function for formatting timestamp
String formatTimestamp(dynamic timestamp) {
  if (timestamp is Timestamp) {
    final date = timestamp.toDate();
    // Using a simple format, can be customized with 'intl' package
    // Example: return DateFormat('dd/MM/yyyy HH:mm').format(date);
    return '${date.day}/${date.month}/${date.year} ${DateFormat('HH:mm').format(date)}'; // Using DateFormat for time
  } else if (timestamp is DateTime) {
    // Handle if it's already a DateTime object
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${DateFormat('HH:mm').format(timestamp)}';
  }
  // Fallback for other types or null
  return 'Invalid date';
}

// You could add other formatting utilities here if needed in the future.
// For example, formatting numbers, currency, etc.

// END OF FILE formatters.dart