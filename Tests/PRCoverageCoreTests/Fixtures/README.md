# Fixtures

Real output captured from `Example/` during the milestone 1 spike (Xcode 27.0, Tuist 4.212.0, iOS 26.5 simulator).

**Path substitution:** the absolute checkout path `/Users/gytis/Documents/Projects/swift-pr-coverage/` was replaced with `/Users/runner/work/repo/repo/` (the GitHub Actions `$GITHUB_WORKSPACE` shape). In the JSON files the escaped form `\/Users\/...\/` was replaced the same way. Nothing else was edited; JSON is byte-for-byte what `xccov` printed (minified, `\/`-escaped slashes).

| File | Command | Notes |
|---|---|---|
| `xccov-file-Calculator.json` | `xccov view --archive --file <abs> --json` | Fully covered file. Lines 12 and 15 carry `subranges`. |
| `xccov-file-PriceFormatter.json` | same | Partly covered: lines 30–45 have `executionCount: 0`; line 16 is covered but has a subrange with count 0 (untested ternary branch). |
| `xccov-file-CartModel.json` | same | Partly covered: `clear()` (lines 19–21) uncovered. |
| `xccov-archive.json` | `xccov view --archive --json` | Full dump, all 8 instrumented files, `codeCoverageMode: .relevant` (no test files). |
| `xccov-file-list.txt` | `xccov view --archive --file-list` | Full run. Includes `Example/Derived/Sources/*`. |
| `xccov-file-list-core-cached.txt` | same, `tuist test App` with `Core` served from the binary cache | `Core/Sources/*` and `Derived/Sources/TuistBundle+Core.swift` are absent. Test file present because the per-project `App` scheme instruments all targets. |
| `test-results-summary-passed.json` | `xcresulttool get test-results summary --path <bundle> --compact` | Green run: `"result":"Passed"`. |
| `test-results-summary-failed.json` | same | Run where `AppTests` could not launch its host app: `"result":"Failed"`, `failedTests: 1`. |
| `git-diff-unified0.diff` | `git diff -M --unified=0 base...HEAD -- '*.swift'` | Synthetic base → current `Example/`. Covers an edit, a pure insertion, a 1-line hunk with no count (`@@ -20 +24 @@`), a rename with edits (`Math.swift` → `Calculator.swift`), a deleted file (`+++ /dev/null`), a new file (`--- /dev/null`), a test file and a Tuist manifest. Paths are repo-relative (`Example/...`). |

## Expected analysis (diff ∩ `xccov-archive.json`, prefix `/Users/runner/work/repo/repo/` stripped)

| File | Covered | Uncovered | Not executable | No data |
|---|---|---|---|---|
| `Example/App/Sources/CartModel.swift` | 24 | 19–21 | 22 | |
| `Example/Core/Sources/Calculator.swift` | 11–16 | | 10 | |
| `Example/Core/Sources/PriceFormatter.swift` | | 30–36, 38–45 | 3, 29, 37 | |
| `Example/Core/Tests/CoreTests.swift` | | | | 8–12 (test file, should be excluded by default) |
| `Example/Workspace.swift` | | | | 1–9 (Tuist manifest, should be excluded by default) |
| `Example/App/Sources/Legacy.swift` | deleted, no added lines | | | |
