import 'package:flutter/material.dart';

/// Actions that can appear in the home AppBar or its overflow menu.
enum HomeToolbarAction {
  connect,
  profiles,
  snippets,
  discovery,
  keys,
}

extension HomeToolbarActionX on HomeToolbarAction {
  IconData get icon => switch (this) {
        HomeToolbarAction.connect => Icons.add,
        HomeToolbarAction.profiles => Icons.person,
        HomeToolbarAction.snippets => Icons.code,
        HomeToolbarAction.discovery => Icons.search,
        HomeToolbarAction.keys => Icons.key,
      };

  String get label => switch (this) {
        HomeToolbarAction.connect => 'Connect',
        HomeToolbarAction.profiles => 'Profiles',
        HomeToolbarAction.snippets => 'Snippets',
        HomeToolbarAction.discovery => 'Network Discovery',
        HomeToolbarAction.keys => 'Keys',
      };

  String get tooltip => label;

  static List<HomeToolbarAction> get displayOrder => HomeToolbarAction.values;

  static Set<HomeToolbarAction> get defaultPinned => {
        HomeToolbarAction.connect,
        HomeToolbarAction.profiles,
      };

  static HomeToolbarAction? fromStorageKey(String key) {
    for (final HomeToolbarAction action in HomeToolbarAction.values) {
      if (action.name == key) {
        return action;
      }
    }
    return null;
  }
}
