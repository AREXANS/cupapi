1. **Explore & Define Background Recording Logic:**
   - I will use `replace_with_git_merge_diff` to add `backgroundRecordings = {}`, `isBackgroundRecordingEnabled = false`, and `backgroundRecordingConnections = {}` near the other global variables in `Arexanstools.lua` (around line 650).
   - I will use `replace_with_git_merge_diff` to add `startBackgroundRecordingForPlayer(player)` and `stopBackgroundRecordingForPlayer(player)` functions, as well as `PlayerAdded` and `PlayerRemoving` connections. These will be added right before `startRecording` (around line 15000) in `Arexanstools.lua`.

2. **Add Background Recording UI:**
   - I will use `replace_with_git_merge_diff` on `Arexanstools.lua` inside `setupRekamanTab` (around line 15725) to add a new `makeCompactToggle` inside `compactTogglesRow` for "BG Record".
   - I will use `replace_with_git_merge_diff` on `Arexanstools.lua` inside `setupRekamanTab` (around line 15632) to add a new "Save BG Record" action button using `UI.createIconButton` in `actionIconsScrollFrame`.
   - I will use `replace_with_git_merge_diff` on `Arexanstools.lua` inside `setupRekamanTab` (around line 16160) to bind a `MouseButton1Click` event to the new button which prompts for a username and transfers the data into `savedRecordings`.

3. **Verify Edit & Run Tests:**
   - I will run `luac5.3 -p Arexanstools.lua` to verify the Lua syntax across the project and confirm no regressions exist.

4. **Complete pre-commit steps to ensure proper testing, verification, review, and reflection are done.**
