1. **Fix Background Recording Logic:**
   - I will use `replace_with_git_merge_diff` to edit `Arexanstools.lua` inside the `startBackgroundRecordingForPlayer` function. The current logic `(sampleTime - recData.lastTime) < ...` causes it to freeze if a frame is dropped because `recData.lastTime` is updated inside the block that might not be reached. I will fix the condition and ensure `SAMPLE_INTERVAL` defaults properly, and I will explicitly use `RunService.Heartbeat` to capture frames when the character is moving or jumping.

2. **Clean Failed Recordings on Save:**
   - I will use `replace_with_git_merge_diff` to edit the `saveBgRecordButton.MouseButton1Click` event handler in `Arexanstools.lua` (around line 16290).
   - I will wrap `bgData.frames` with the existing `optimizeRecordingFramesLowLag` function: `optimizeRecordingFramesLowLag(bgData.frames, false)` so that the saved recording automatically strips out idle time, lag spikes, and cleans up the path to be "perfect".

3. **Verify Edit & Run Tests:**
   - I will run `luac5.3 -p Arexanstools.lua` in the bash session to verify the syntax across the project and confirm no regressions exist.

4. **Complete pre-commit steps to ensure proper testing, verification, review, and reflection are done.**
