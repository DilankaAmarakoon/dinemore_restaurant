import 'package:flutter/material.dart';

class RestartWidget extends StatefulWidget {
  final Widget child;

  const RestartWidget({
    super.key,
    required this.child,
  });

  static void restartApp(BuildContext context) {
    final RestartWidgetState? state =
    context.findAncestorStateOfType<RestartWidgetState>();
    state?.restartApp();
  }

  @override
  State<RestartWidget> createState() => RestartWidgetState();
}

class RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();

  void restartApp() {
    setState(() {
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}