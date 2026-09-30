# Lockscreen

`LockScreen.qml` + wrapper, `LockScreenContent.qml` (shell: state +
gesture + composition). Views: `LockSleepView`, `LockAuthView`
(`LockPowerButtons` nested inside auth to inherit visibility), gesture
in `LockDragArea` (`dragDy`/`dragging`/`reset()`).

Auth signals (`validatePassword`, `wakeUp`…) live in the content item
and are forwarded by the views.
