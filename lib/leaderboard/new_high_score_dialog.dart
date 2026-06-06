import 'package:country_picker/country_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'country_helper.dart';
import 'leaderboard_service.dart';

/// Shows the retro 3-character name entry. Returns true if the score was
/// submitted, false if the user dismissed.
Future<bool> showNewHighScoreDialog(
  BuildContext context, {
  required String gameId,
  String? difficulty,
  required int score,
  String? rememberedName,
  String? rememberedCountryCode,
  void Function(String name)? onNameRemembered,
  void Function(String code)? onCountryRemembered,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _NewHighScoreDialog(
      gameId: gameId,
      difficulty: difficulty,
      score: score,
      rememberedName: rememberedName,
      rememberedCountryCode: rememberedCountryCode,
      onNameRemembered: onNameRemembered,
      onCountryRemembered: onCountryRemembered,
    ),
  );
  return result ?? false;
}

class _NewHighScoreDialog extends StatefulWidget {
  final String gameId;
  final String? difficulty;
  final int score;
  final String? rememberedName;
  final String? rememberedCountryCode;
  final void Function(String name)? onNameRemembered;
  final void Function(String code)? onCountryRemembered;

  const _NewHighScoreDialog({
    required this.gameId,
    required this.difficulty,
    required this.score,
    this.rememberedName,
    this.rememberedCountryCode,
    this.onNameRemembered,
    this.onCountryRemembered,
  });

  @override
  State<_NewHighScoreDialog> createState() => _NewHighScoreDialogState();
}

class _NewHighScoreDialogState extends State<_NewHighScoreDialog> {
  late final TextEditingController _ctrl;
  late String? _countryCode;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.rememberedName ?? '');
    _countryCode = widget.rememberedCountryCode ?? CountryHelper.detect();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim().toUpperCase();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await LeaderboardService.submit(
        gameId: widget.gameId,
        difficulty: widget.difficulty,
        playerName: name,
        score: widget.score,
        countryCode: _countryCode,
      );
      widget.onNameRemembered?.call(name);
      if (_countryCode != null) widget.onCountryRemembered?.call(_countryCode!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      debugPrint('[Leaderboard] submit failed: $e\n$st');
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = kDebugMode ? 'Failed: $e' : 'Submission failed. Try again?';
        });
      }
    }
  }

  void _openCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        backgroundColor: const Color(0xFF0D0D1A),
        textStyle: const TextStyle(color: Colors.white),
        searchTextStyle: const TextStyle(color: Colors.white),
        inputDecoration: InputDecoration(
          hintText: 'Search',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFFD700)),
          ),
        ),
        bottomSheetHeight: 500,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      onSelect: (country) {
        setState(() => _countryCode = country.countryCode);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final flag = CountryHelper.toFlagEmoji(_countryCode) ?? '🏳️';
    return Dialog(
      backgroundColor: const Color(0xFF0D0D1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFFFD700), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '★ NEW HIGH SCORE ★',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.score}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ENTER YOUR INITIALS  ',
                  style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2),
                ),
                GestureDetector(
                  onTap: _openCountryPicker,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: Colors.white38, size: 16),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                maxLength: 3,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(3),
                ],
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 12,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFFD700), width: 2),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFFD700), width: 2),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Skip', style: TextStyle(color: Colors.white38, fontSize: 14)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('SUBMIT',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
