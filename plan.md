1. **Modify `startBackgroundRecordingForPlayer` for Summit Auto-Save:**
   - I will use `replace_with_git_merge_diff` to edit the `startBackgroundRecordingForPlayer` function in `Arexanstools.lua`.
   - I will increase `maxFrames` from 60 seconds to 5 minutes to ensure it captures the full run without memory leaking.
   - I will add a check: `if isNearAutoPerfectSummit and isNearAutoPerfectSummit(c_hrp.Position) then`.
   - If true and `#recData.frames > 20`, it will pass `recData.frames` through `optimizeRecordingFramesLowLag`, save the cleaned frames to `savedRecordings` as `BG Winner [PlayerName]`, call `updateRecordingsList()`, send a notification to the user, and clear the player's buffer to prevent duplicate saves.

2. **Verify Edits:**
   - I will run `luac5.3 -p Arexanstools.lua` in the bash session to verify the syntax across the project and confirm no regressions exist.

3. **Complete pre-commit steps to ensure proper testing, verification, review, and reflection are done.**
