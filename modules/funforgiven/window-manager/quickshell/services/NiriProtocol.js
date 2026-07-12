var MAX_SAFE_INTEGER = 9007199254740991;

function isUint(value, maximum) {
    return typeof value === "number"
        && isFinite(value)
        && Math.floor(value) === value
        && value >= 0
        && value <= maximum;
}

function isId(value) {
    return isUint(value, MAX_SAFE_INTEGER);
}

function eventStream() {
    return "EventStream";
}

function focusWorkspace(id) {
    if (!isId(id)) {
        return null;
    }

    return {
        Action: {
            FocusWorkspace: {
                reference: {
                    Id: id
                }
            }
        }
    };
}

function focusWindow(id) {
    if (!isId(id)) {
        return null;
    }

    return {
        Action: {
            FocusWindow: {
                id: id
            }
        }
    };
}

function focusMonitor(output) {
    if (typeof output !== "string" || output.trim().length === 0) {
        return null;
    }

    return {
        Action: {
            FocusMonitor: {
                output: output
            }
        }
    };
}

function replyResult(reply) {
    if (reply === null || typeof reply !== "object" || Array.isArray(reply)) {
        return {
            ok: false,
            error: "niri returned a malformed action reply"
        };
    }

    if (Object.prototype.hasOwnProperty.call(reply, "Ok")) {
        return { ok: true, error: "" };
    }

    if (Object.prototype.hasOwnProperty.call(reply, "Err")) {
        return {
            ok: false,
            error: typeof reply.Err === "string"
                ? reply.Err
                : JSON.stringify(reply.Err)
        };
    }

    return {
        ok: false,
        error: "niri returned an unknown action reply"
    };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        eventStream: eventStream,
        focusMonitor: focusMonitor,
        focusWindow: focusWindow,
        focusWorkspace: focusWorkspace,
        isId: isId,
        replyResult: replyResult
    };
}
