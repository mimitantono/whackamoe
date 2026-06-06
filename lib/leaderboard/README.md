# Leaderboard module

A self-contained, monthly-reset global leaderboard for Flutter games. Backed
by Supabase. One shared backend table serves every game — they're partitioned
by `game_id`.

## What it gives you

- **Monthly reset** — top-10 resets every calendar month (`YYYY-MM` period
  column). Old months stay in the DB.
- **Retro 3-character name entry** — classic arcade `AAA` style, with the
  player's last entered name remembered for next time.
- **Auto-detected country flag** — from the device locale (no API calls).
- **Top-10 screen** — gold/silver/bronze top-3 styling, optional difficulty
  tabs, monthly period label.
- **Portable** — the whole folder drops into another game with one config
  change.

## Adding it to a new game

### 1. Set up Supabase (one-time, all games share this)

Run this SQL in your Supabase project's SQL editor:

```sql
create table leaderboard_scores (
  id uuid primary key default gen_random_uuid(),
  game_id text not null,
  difficulty text,
  player_name text not null check (
    char_length(player_name) between 1 and 6
  ),
  score int not null check (score >= 0),
  country_code text check (country_code is null or char_length(country_code) = 2),
  period text not null,
  device_id text,
  created_at timestamptz default now()
);

create index leaderboard_scores_top_idx
  on leaderboard_scores (game_id, coalesce(difficulty, ''), period, score desc);

alter table leaderboard_scores enable row level security;

create policy "anyone can read scores"
  on leaderboard_scores for select using (true);

create policy "anyone can submit a score"
  on leaderboard_scores for insert with check (true);
```

### 2. Copy files into the new game

From an existing game, copy:

- `lib/leaderboard/` (the whole folder)
- `lib/config.dart.example` (template for secrets)

### 3. Add dependencies

```bash
flutter pub add supabase_flutter uuid shared_preferences country_picker
```

### 4. Create `lib/config.dart` and gitignore it

Copy `config.dart.example` to `config.dart` and fill in your Supabase
project URL and anon key (both available in **Settings → API** in the
Supabase dashboard).

Add this line to `.gitignore`:

```
lib/config.dart
```

### 5. Initialize Supabase in `main.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Config.supabaseUrl,
    anonKey: Config.supabaseAnonKey,
  );
  runApp(const MyGameApp());
}
```

### 6. Show the dialog after game over

```dart
import '../leaderboard/leaderboard_service.dart';
import '../leaderboard/new_high_score_dialog.dart';

Future<void> _handleGameOver() async {
  final qualifies = await LeaderboardService.qualifies(
    gameId: 'my_new_game',
    difficulty: widget.difficulty.name, // or null if no difficulties
    score: _score,
  );
  if (!mounted) return;

  if (qualifies) {
    await showNewHighScoreDialog(
      context,
      gameId: 'my_new_game',
      difficulty: widget.difficulty.name,
      score: _score,
    );
    if (!mounted) return;
  }
  // ...your existing game-over screen
}
```

### 7. Add a Leaderboard button (usually on the start screen)

```dart
import '../leaderboard/leaderboard_screen.dart';

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => LeaderboardScreen(
      gameId: 'my_new_game',
      difficulty: _selected.name,
      // Optional: tabs to switch between difficulties
      difficultyTabs: [
        for (final d in Difficulty.values)
          (label: d.label, value: d.name),
      ],
    ),
  ),
);
```

### 8. Wire CI to inject the config

In `.github/workflows/deploy-web.yml`, add this step before `flutter pub get`:

```yaml
- name: Create config.dart
  run: |
    cat > lib/config.dart << EOF
    class Config {
      static const supabaseUrl = '${{ secrets.SUPABASE_URL }}';
      static const supabaseAnonKey = '${{ secrets.SUPABASE_ANON_KEY }}';
    }
    EOF
```

`SUPABASE_URL` and `SUPABASE_ANON_KEY` are set once in **Settings → Secrets
and variables → Actions** on the GitHub repo. The same values work for every
game.

## API reference

### `LeaderboardService`

```dart
// Does this score qualify for the top-10 this month?
static Future<bool> qualifies({
  required String gameId,
  String? difficulty,
  required int score,
});

// Submit a score. Country is auto-detected from device locale.
static Future<void> submit({
  required String gameId,
  String? difficulty,
  required String playerName,
  required int score,
  String? countryCode,
});

// Fetch the top N for the current month.
static Future<List<LeaderboardEntry>> top({
  required String gameId,
  String? difficulty,
  int limit = 10,
});
```

### `showNewHighScoreDialog(...)`

Shows the retro name-entry dialog and submits to Supabase on confirm. Pass
`rememberedName` and `onNameRemembered` to persist the last-used name
locally across games.

### `LeaderboardScreen`

A full screen showing the top-10 for the current month. Pass
`difficultyTabs` to let players switch between difficulties.

### `CountryHelper`

```dart
String? detect();             // device locale → 'US', 'VN', etc.
String? toFlagEmoji(String?); // 'VN' → '🇻🇳'
```

## Design choices

- **Monthly reset**: keeps competition fresh, gives new players a real
  chance at the top-10, and stops legendary scores from blocking the
  board forever. Old months are still in the DB if you want to surface
  all-time bests later.
- **Device locale for country**: no API calls, no privacy concerns, no
  rate limits. Slightly less accurate than IP geolocation but plenty
  good enough for retro flag flair.
- **3-character name limit (in the UI)**: classic arcade feel. The DB
  allows up to 6 if you want a longer-name variant later.
- **One shared table**: a single Supabase project supports every game.
  Cheaper, simpler, easier to monitor.
