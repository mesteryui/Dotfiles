# Lockscreen

11 files. `LockScreen.qml` (`Scope` per screen + IPC `lockscreen`,
driven by `AuthService`/`LockState`) + `LockScreenWrapper.qml`
(`FocusScope`) + `LockScreenContent.qml` (state + gesture +
composition).

- Views: `LockSleepView.qml` (idle/clock), `LockAuthView.qml`
  (password; `LockPowerButtons.qml` nested inside auth to inherit
  visibility). Both take `dragDy`/`dragging` and forward
  `wakeUp`/`validatePassword`.
- Gesture: `LockDragArea.qml` (exposes `dragDy`/`dragging`,
  `reset()`, `wakeUp` signal; drag-up wakes, progress resets when
  going back to sleep).
- Pieces: `LockScreenBackground.qml`, `LockScreenClock.qml`,
  `LockScreenMprisCard.qml`, `LockScreenPasswordInput.qml`
  (emits password, shake on failure via `triggerShake()`).

Auth signals (`validatePassword(password)`,
`togglePasswordVisibility`, `wakeUp`, `sleepRequested`) live in
the content item and are forwarded by the views.
