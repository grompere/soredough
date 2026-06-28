# 🥖 Sore Dough

This is a really well baked workout tracker app.

Sore Dough is a native iOS app for people who take their training seriously but don't take themselves too seriously. Track your workouts, monitor your progress, and let AI handle the tedious parts — all wrapped in a warm, carb-loaded theme.

## Features

### 🏋️ Workout Logging
Start a session, add exercises, log your sets with weight and reps, and mark them done as you go. Sore Dough shows how your current performance compares to your last session — so you always know if you're rising to the occasion.

### 🥐 Pre-Baked Templates
Save your go-to routines as reusable templates. When it's time to train, pick a template and get straight to work — no need to rebuild your workout from scratch every time.

### 🧁 AI Workout Import
Got a program from your coach in plain text? Paste it in and let Google Gemini parse it into a structured template. It handles trainer shorthand like `2x8@135` and `10@30s, 6@50s` so you don't have to.

### 📈 Progress Tracking
Interactive charts (built with Swift Charts) show your weight progression per exercise over time. Toggle between rep counts, tap to inspect individual data points, and check your estimated 1RM — all with summary cards for your all-time and 30-day bests.

### 🍪 Cookie Cutter Exports
Define custom export formats with whatever columns you need, then let Gemini intelligently transform your workout data to match. Useful for coaches, spreadsheets, or anyone with opinions about CSV column names.

### 🏷️ Tags
Organize sessions and exercises with color-coded tags. Add them, delete them with a satisfying jitter animation, and filter by them.

### 🔀 Exercise Renaming & Merging
Renamed "Bench Press" to "Flat Bench" three months ago and now your history is split? Merge them back together and your charts will knead the data into one clean timeline.

## Tech Stack

- **SwiftUI** + **SwiftData** — native all the way down
- **Swift Charts** — for progress visualization
- **Google Gemini API** — powers the AI import and export features (bring your own API key)
- **Zero third-party dependencies** — just Apple frameworks and vibes

## Requirements

- iOS 17.0+
- iPhone
- Xcode 15+

## Building

```bash
git clone https://github.com/grompere/soredough.git
```

Open `IronLog 2.xcodeproj` in Xcode, select your team under Signing & Capabilities, and hit Run.

The project includes a `project.yml` for [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you prefer to regenerate the Xcode project from spec.

## License

MIT — see [LICENSE](LICENSE) for details.
