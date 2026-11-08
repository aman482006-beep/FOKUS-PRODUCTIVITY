import 'package:flutter/material.dart';

/// A single tool entry.
class ToolItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Widget Function(VoidCallback onBack) pageBuilder;
  final String category;

  const ToolItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.pageBuilder,
    required this.category,
  });
}
