import 'package:flutter/material.dart';

class AnimatedDialog {
  /// Non-nullable title with a default empty string.
  final String title;

  /// Required child widget; must not be null.
  final Widget child;

  /// Optional text for the first button. If this is `null`, no button is shown.
  final String? button1Text;

  /// Optional callback for the first button.
  final VoidCallback? onPressedButton1;

  /// Optional text for the second button. If this is `null`, no button is shown.
  final String? button2Text;

  /// Optional callback for the second button.
  final VoidCallback? onPressedButton2;

  AnimatedDialog.show(
      BuildContext context, {
        this.title = '',
        required this.child,
        this.button1Text,
        this.onPressedButton1,
        this.button2Text,
        this.onPressedButton2,
      }) {
    final List<Widget> actionButtons = [];

    if (button1Text != null) {
      actionButtons.add(
        TextButton(
          onPressed: onPressedButton1,
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: Text(button1Text!),
        ),
      );
    }
    if (button2Text != null) {
      actionButtons.add(
        TextButton(
          onPressed: onPressedButton2,
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: Text(button2Text!),
        ),
      );
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 300),
      // Return a minimal widget instead of `null`.
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, dialogChild) {
        final fadeTween = CurveTween(curve: Curves.fastOutSlowIn);
        final fadeAnimation = fadeTween.animate(animation);

        return Transform.scale(
          scale: fadeAnimation.value,
          child: AlertDialog(
            title: Text(title),
            content: Container(
              width: MediaQuery.of(context).size.width / 3,
              child: child,
            ),
            actions: actionButtons,
          ),
        );
      },
    );
  }
}
