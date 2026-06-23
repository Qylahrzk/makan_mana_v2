import 'package:flutter/material.dart';

/// NavTabProxy
///
/// Abstract interface that MainNavScreen's state implements.
/// HomeScreen uses findAncestorStateOfType<NavTabProxy>()
/// to switch tabs without a circular import.
///
/// Place in: lib/core/nav_tab_proxy.dart

abstract class NavTabProxy<T extends StatefulWidget> extends State<T> {
  void switchTab(int index, {String? cuisine});
}
