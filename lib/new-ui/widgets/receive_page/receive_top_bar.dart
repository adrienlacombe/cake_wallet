import 'package:cake_wallet/new-ui/pages/receive_page.dart';
import 'package:cake_wallet/new-ui/widgets/modern_button.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class ModalTopBar extends StatelessWidget {
  const ModalTopBar({super.key, required this.title, required this.onLeadingPressed, required this.onTrailingPressed});

  final String title;
  final VoidCallback onLeadingPressed;
  final VoidCallback onTrailingPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ModernButton(size: 52, onPressed: onLeadingPressed, icon: Icon(Icons.close)),

          Text(title, style: TextStyle(fontSize: 22)),
          ModernButton(size: 52, onPressed: onTrailingPressed, icon: Icon(Icons.share)),
        ],
      ),
    );
  }
}
