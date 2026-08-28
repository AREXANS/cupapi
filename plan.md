1. **Move Summit Detection Outside Movement Condition:**
   - I will use `replace_with_git_merge_diff` to edit the `startBackgroundRecordingForPlayer` function in `Arexanstools.lua`.
   - I will extract the `isNearAutoPerfectSummit` logic block and place it outside the `if hSpeed > 0.5 or isJumpingOrFalling then` block, executing it at every interval tick, ensuring the summit is detected even if the player stops moving immediately upon arrival.

2. **Verify Edits:**
   - I will run `luac5.3 -p Arexanstools.lua` in the bash session to verify the syntax across the project and confirm no regressions exist.

3. **Complete pre-commit steps to ensure proper testing, verification, review, and reflection are done.**
