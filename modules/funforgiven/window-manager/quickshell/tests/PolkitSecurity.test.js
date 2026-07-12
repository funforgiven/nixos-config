const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const polkitDirectory = path.join(__dirname, "..", "polkit");
const dialog = fs.readFileSync(path.join(polkitDirectory, "PolkitDialog.qml"), "utf8");
const overlay = fs.readFileSync(path.join(polkitDirectory, "PolkitOverlay.qml"), "utf8");
const backendPatch = fs.readFileSync(path.join(polkitDirectory, "quickshell-0.3-polkit-conversation.patch"), "utf8");

test("native polkit is a conditional singleton with one backend agent", () => {
    assert.match(overlay, /^pragma Singleton/m);
    assert.equal((overlay.match(/\bPolkitAgent\s*\{/g) || []).length, 1);
    assert.match(overlay, /LazyLoader\s*\{[\s\S]*?active:\s*root\.enabled/);
    assert.match(overlay, /WlrLayershell\.keyboardFocus:\s*runtime\.authenticationActive[\s\S]*?WlrKeyboardFocus\.Exclusive[\s\S]*?WlrKeyboardFocus\.None/);
    assert.doesNotMatch(overlay, /^\s*(?:focusable|aboveWindows):/m);
});

test("authentication responses are not logged, persisted, copied, or aliased", () => {
    assert.doesNotMatch(dialog, /\bconsole\s*\./);
    assert.doesNotMatch(dialog, /\b(clipboardText|PersistentProperties|FileView|JsonAdapter)\b/);
    assert.doesNotMatch(dialog, /\b(?:const|let|var)\s+\w+\s*=\s*responseLoader\.item\.text\b/);
    assert.match(dialog, /root\.flow\.submit\(responseLoader\.item\.text\);[^\n]*\n\s*root\.clearSensitiveInput\(\);/);
    assert.match(dialog, /responseLoader\.item\.text\s*=\s*"";[\s\S]*?responseLoader\.active\s*=\s*false;/);
    assert.match(dialog, /Qt\.Key_Copy[\s\S]*?Qt\.Key_Cut[\s\S]*?Qt\.Key_Undo[\s\S]*?Qt\.Key_Redo/);
    assert.doesNotMatch(dialog, /identitySelector\.currentIndex\s*=/);
});

test("every terminal or retry signal clears the response editor", () => {
    for (const signal of [
        "AuthenticationFailed",
        "AuthenticationRequestCancelled",
        "AuthenticationSucceeded",
        "CanRetryChanged",
        "IsCompletedChanged"
    ]) {
        const handler = new RegExp(`function on${signal}\\(\\) \\{[\\s\\S]*?root\\.clearSensitiveInput\\(\\);[\\s\\S]*?\\n        \\}`);
        assert.match(dialog, handler);
    }
});

test("the pinned backend patch guards FIFO, flow identity, and request lifetime", () => {
    assert.match(backendPatch, /if \(!this->bActiveFlow\.value\(\)\)/);
    assert.match(backendPatch, /finishAuthenticationRequest\(AuthFlow\* flow\)/);
    assert.match(backendPatch, /this->bActiveFlow\.value\(\) != flow/);
    assert.match(backendPatch, /while \(!this->queuedRequests\.empty\(\)\)/);
    assert.match(backendPatch, /obj && !obj->isGroup\(\)/);
    assert.match(backendPatch, /QTimer::singleShot\(0, this/);
    assert.match(backendPatch, /retryAuthentication/);
    assert.match(backendPatch, /g_cancellable_disconnect/);
    assert.match(backendPatch, /g_idle_add_full/);
    assert.match(backendPatch, /CancellationStatePtr/);
    assert.match(backendPatch, /std::exchange\(this->task, nullptr\)/);
    assert.match(backendPatch, /registration_generation/);
    assert.match(backendPatch, /qs_polkit_agent_detach/);
});
