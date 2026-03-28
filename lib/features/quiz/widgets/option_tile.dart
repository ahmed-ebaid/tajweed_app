import 'package:flutter/material.dart';

/// A single answer option tile in the quiz. Shows visual feedback
/// (green = correct, red = wrong) after an answer is selected.
class OptionTile extends StatelessWidget {
  final String text;
  final int index;
  final int? selectedIndex;
  final int correctIndex;
  final VoidCallback onTap;

  const OptionTile({
    super.key,
    required this.text,
    required this.index,
    required this.selectedIndex,
    required this.correctIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Theme.of(context).dividerColor;
    Color bgColor = Theme.of(context).colorScheme.surface;
    Color textColor = Theme.of(context).textTheme.bodyLarge!.color!;

    if (selectedIndex != null) {
      if (index == correctIndex) {
        borderColor = const Color(0xFF1D9E75);
        bgColor = const Color(0xFFE1F5EE);
        textColor = const Color(0xFF0F6E56);
      } else if (index == selectedIndex) {
        borderColor = const Color(0xFFA32D2D);
        bgColor = const Color(0xFFFCEBEB);
        textColor = const Color(0xFFA32D2D);
      } else {
        textColor = textColor.withOpacity(0.4);
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                String.fromCharCode(65 + index), // A, B, C, D
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 14, color: textColor)),
            ),
            if (selectedIndex != null && index == correctIndex)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF1D9E75), size: 18),
            if (selectedIndex != null &&
                index == selectedIndex &&
                index != correctIndex)
              const Icon(Icons.cancel_rounded,
                  color: Color(0xFFA32D2D), size: 18),
          ],
        ),
      ),
    );
  }
}
