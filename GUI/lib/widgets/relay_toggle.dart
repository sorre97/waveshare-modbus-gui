import 'package:flutter/material.dart';
import '../theme.dart';

/// Custom pill-shaped toggle that mirrors the mockup design.
class RelayToggle extends StatelessWidget {
  final bool value;
  final VoidCallback onTap;
  final double scale;

  const RelayToggle({
    super.key,
    required this.value,
    required this.onTap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final w = 64.0 * scale;
    final h = 32.0 * scale;
    final knob = 24.0 * scale;
    final pad = 4.0 * scale;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: w,
        height: h,
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: value ? const Color(0x334ADE80) : kSurfaceContainerHighest,
          border: Border.all(
            color: value ? const Color(0x664ADE80) : Colors.white10,
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knob,
            height: knob,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? kPrimary : kOutline,
              boxShadow: value
                  ? [
                      BoxShadow(
                        color: kPrimary.withValues(alpha: 0.8),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
