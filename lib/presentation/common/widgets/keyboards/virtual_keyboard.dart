import 'package:flutter/material.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_semantic_colors.dart';
import 'package:telepos/l10n/app_localizations.dart';

class VirtualKeyboard extends StatefulWidget {
  const VirtualKeyboard({
    super.key,
    required this.onKeyPressed,
    this.onBackspace,
    this.onEnter,
    this.onClose,
    this.showClose = true,
  });

  final ValueChanged<String> onKeyPressed;

  final VoidCallback? onBackspace;

  final VoidCallback? onEnter;

  final VoidCallback? onClose;

  final bool showClose;

  @override
  State<VirtualKeyboard> createState() => _VirtualKeyboardState();
}

class _VirtualKeyboardState extends State<VirtualKeyboard> {
  bool _isShiftPressed = false;
  bool _isCapsLock = false;

  static const List<List<String>> _lowerKeys = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
  ];

  static const List<List<String>> _upperKeys = [
    ['!', '@', '#', '\$', '%', '^', '&', '*', '(', ')'],
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  List<List<String>> get _currentKeys =>
      (_isShiftPressed || _isCapsLock) ? _upperKeys : _lowerKeys;

  void _handleKeyPress(String key) {
    widget.onKeyPressed(key);
    if (_isShiftPressed && !_isCapsLock) {
      setState(() => _isShiftPressed = false);
    }
  }

  void _toggleShift() {
    setState(() {
      if (_isCapsLock) {
        _isCapsLock = false;
        _isShiftPressed = false;
      } else if (_isShiftPressed) {
        _isCapsLock = true;
      } else {
        _isShiftPressed = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: context.semantic.canvas)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showClose)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.keyboard_hide),
                  tooltip: AppLocalizations.of(context)!.keyboardHide,
                ),
              ],
            ),

          _buildRow(_currentKeys[0]),
          const SizedBox(height: 4),

          _buildRow(_currentKeys[1]),
          const SizedBox(height: 4),

          _buildRow(_currentKeys[2]),
          const SizedBox(height: 4),

          _buildBottomRow(),
          const SizedBox(height: 4),

          _buildSpaceRow(),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) => _buildKey(key)).toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSpecialKey(
          icon: _isCapsLock ? Icons.keyboard_capslock : Icons.arrow_upward,
          onTap: _toggleShift,
          isActive: _isShiftPressed || _isCapsLock,
          width: 64,
        ),
        ..._currentKeys[3].map((key) => _buildKey(key)),
        _buildSpecialKey(
          icon: Icons.backspace_outlined,
          onTap: widget.onBackspace,
          width: 64,
        ),
      ],
    );
  }

  Widget _buildSpaceRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildKey(','),
        _buildKey('.'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => _handleKeyPress(' '),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(AppLocalizations.of(context)!.keyboardSpace),
              ),
            ),
          ),
        ),
        _buildSpecialKey(
          icon: Icons.keyboard_return,
          onTap: widget.onEnter,
          width: 80,
          color: AppColors.primary,
          iconColor: AppColors.white,
        ),
      ],
    );
  }

  Widget _buildKey(String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        width: 40,
        height: 48,
        child: ElevatedButton(
          onPressed: () => _handleKeyPress(key),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            elevation: 1,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(key, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    required IconData icon,
    VoidCallback? onTap,
    double width = 48,
    bool isActive = false,
    Color? color,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        width: width,
        height: 48,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                color ??
                (isActive ? AppColors.primary : context.semantic.canvas),
            foregroundColor:
                iconColor ??
                (isActive
                    ? AppColors.white
                    : Theme.of(context).colorScheme.onSurface),
            elevation: isActive ? 2 : 1,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }
}
