# Home Base for iPhone

The live version of Home Base. It connects to Apple Health with HealthKit, so your Garmin runs, sleep, HRV, heart rate, steps, weight and MacroFactor food update on their own, even while the app is closed.

## What's in this first version

- **Today:** readiness (sleep, HRV and resting heart rate compared with your last 4 weeks), tiles with 2-week trends, recent runs, and every Apple Health type with its latest value.
- **Log to Apple Health:** water, weight, caffeine, body fat, waist and mindful minutes, saved straight to Health.
- **Connections:** Apple Health status (live), Garmin and MacroFactor through Health, and CIBC marked as next.
- **Train:** strength logging (last session's numbers, warm-up sets, rest timer, history), runs from your watch plus hand-entered runs, and premade splits with today's plan. Finished lifts and hand-entered runs are saved to Apple Health as workouts.
- **Money:** placeholder until the Plaid server exists.
- **No AI.** AI features stay in the web version only.

## Run it on your iPhone

You need a Mac with Xcode 16 or newer and your iPhone with a cable.

1. Install XcodeGen once: `brew install xcodegen`
2. In this `ios` folder, run `xcodegen`. That creates `HomeBase.xcodeproj`.
3. Open `HomeBase.xcodeproj` in Xcode.
4. Click the HomeBase target, open **Signing & Capabilities**, and pick your Apple ID under **Team**. If Xcode says the bundle identifier is taken, change `com.davidrevoredo.homebase` to something unique.
5. Plug in your iPhone, pick it as the run destination at the top, and press Run.
6. On the iPhone, the first time: Settings, General, VPN & Device Management, trust your developer certificate. (iOS may also ask you to turn on Developer Mode.)
7. In Home Base, tap **Connect** on Today and allow everything in the Apple Health sheet.

With a free Apple ID the app stops opening after 7 days and you re-run it from Xcode. A paid Apple Developer Program membership ($99 USD a year) removes that and is needed for TestFlight, for putting it on your wife's iPhone easily, and for the App Store.

## How the live connection works

- `HealthStore` asks for read and write access, then loads 90 days of daily values with HealthKit statistics queries. Totals like steps are de-duplicated by Apple Health itself, so the iPhone and the watch aren't counted twice.
- Observer queries with background delivery watch sleep, workouts, steps, HRV, resting heart rate, weight, calories and water. When Garmin Connect or MacroFactor writes new data, iOS wakes Home Base and it refreshes.
- Apple never tells an app whether it may *read* a type. If a number stays empty, check the Health app: your picture, Apps, Home Base.

## Files

- `project.yml`: the XcodeGen project (bundle id, iOS 17, HealthKit entitlements, Health permission text).
- `HomeBase/Health/`: the HealthKit connection, metric catalog and readiness formula.
- `HomeBase/Views/`: Today, quick logs, Settings and Connections.
- `HomeBase/Train/`: strength logging, runs and splits (workouts are stored on the iPhone with SwiftData).
