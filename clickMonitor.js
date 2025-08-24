// clickMonitor.js - FiveM client-side JS for anti-cheat
// Detects suspicious mouse interactions when no UI/NUI should be focused.
// If player repeatedly clicks while no UI focus is present, a cheat menu may be active.

let spamCounter = 0;

// heartbeat ping response
onNet('cc_t:ping', () => {
  console.log('[HB] pong -> server');
  emitNet('cc_t:pong');
});
const CLICK_THRESHOLD = 8; // clicks in timeframe to trigger detection
const WINDOW_MS = 3000; // timeframe in ms
let windowStart = Date.now();

// Helper to reset spam window
function resetWindow() {
  spamCounter = 0;
  windowStart = Date.now();
}

setTick(() => {
  // Left mouse click released
  if (IsControlJustReleased(0, 24)) {
    const uiFocused = IsNuiFocusKeepingInput(); // any NUI currently capturing input
    if (!uiFocused) {
      spamCounter += 1;
    } else {
      // legit UI interaction, reset
      resetWindow();
    }
    // Force cursor bottom-left when no UI
    if (!uiFocused) {
      SetCursorLocation(0.0, 0.95);
    }
  }

  // check timeframe
  if (Date.now() - windowStart > WINDOW_MS) {
    // new window
    resetWindow();
  }

  if (spamCounter >= CLICK_THRESHOLD) {
    emitNet('cc_t:click_cheat');
    resetWindow();
  }
});
