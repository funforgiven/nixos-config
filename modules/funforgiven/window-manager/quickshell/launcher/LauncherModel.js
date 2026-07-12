// Pointer-selection behavior adapted from the MIT-licensed legacy-v4 snapshot
// a48885b9fec485c903c955749a7da6e30147cd38; see THIRD_PARTY_NOTICES.md.

function text(value) {
    if (value === null || value === undefined) {
        return "";
    }
    return String(value).trim();
}

function folded(value) {
    return text(value).toLowerCase();
}

function compareText(left, right) {
    left = folded(left);
    right = folded(right);
    if (left < right) {
        return -1;
    }
    if (left > right) {
        return 1;
    }
    return 0;
}

function textList(value) {
    if (value === null || value === undefined) {
        return [];
    }
    var values = Array.isArray(value) ? value : [value];
    return values.map(text).filter(function (item) {
        return item.length > 0;
    });
}

function normalizeApplication(application) {
    application = application && typeof application === "object" ? application : {};
    var id = text(application.id || application.desktopId);
    if (id.length === 0) {
        return null;
    }

    return {
        id: id,
        name: text(application.name) || id,
        genericName: text(application.genericName),
        comment: text(application.comment),
        keywords: textList(application.keywords),
        iconPath: text(application.iconPath)
    };
}

function subsequenceScore(haystack, needle) {
    haystack = folded(haystack);
    needle = folded(needle).replace(/\s+/g, "");
    if (needle.length === 0) {
        return 0;
    }

    var cursor = -1;
    var gaps = 0;
    for (var index = 0; index < needle.length; index += 1) {
        var next = haystack.indexOf(needle[index], cursor + 1);
        if (next < 0) {
            return -1;
        }
        gaps += next - cursor - 1;
        cursor = next;
    }
    return gaps;
}

function applicationScore(application, query) {
    query = folded(query);
    if (query.length === 0) {
        return 0;
    }

    var name = folded(application.name);
    var genericName = folded(application.genericName);
    var id = folded(application.id);
    var comment = folded(application.comment);
    var keywords = application.keywords.map(folded).join(" ");
    var haystack = [name, genericName, id, comment, keywords].join(" ");

    if (name === query) {
        return 0;
    }
    if (id === query) {
        return 1;
    }
    if (name.indexOf(query) === 0) {
        return 10;
    }

    var words = name.split(/[\s._-]+/);
    for (var wordIndex = 0; wordIndex < words.length; wordIndex += 1) {
        if (words[wordIndex].indexOf(query) === 0) {
            return 20 + wordIndex;
        }
    }

    var tokens = query.split(/\s+/).filter(function (token) {
        return token.length > 0;
    });
    var tokenScore = 0;
    for (var tokenIndex = 0; tokenIndex < tokens.length; tokenIndex += 1) {
        var tokenPosition = haystack.indexOf(tokens[tokenIndex]);
        if (tokenPosition < 0) {
            tokenScore = -1;
            break;
        }
        tokenScore += tokenPosition;
    }
    if (tokenScore >= 0) {
        return 40 + tokenScore;
    }

    var fuzzyName = subsequenceScore(name, query);
    var fuzzyGeneric = subsequenceScore(genericName, query);
    var fuzzyId = subsequenceScore(id, query);
    var fuzzyScores = [fuzzyName, fuzzyGeneric, fuzzyId].filter(function (score) {
        return score >= 0;
    });
    if (fuzzyScores.length === 0) {
        return null;
    }
    return 100 + Math.min.apply(Math, fuzzyScores);
}

function filterApplications(applications, query, limit) {
    applications = Array.isArray(applications) ? applications : [];
    var seen = Object.create(null);
    var ranked = [];

    for (var index = 0; index < applications.length; index += 1) {
        var application = normalizeApplication(applications[index]);
        if (application === null || seen[application.id]) {
            continue;
        }
        seen[application.id] = true;

        var score = applicationScore(application, query);
        if (score !== null) {
            ranked.push({
                application: application,
                score: score
            });
        }
    }

    ranked.sort(function (left, right) {
        if (left.score !== right.score) {
            return left.score - right.score;
        }
        var nameOrder = compareText(left.application.name, right.application.name);
        return nameOrder !== 0 ? nameOrder : compareText(left.application.id, right.application.id);
    });

    var result = ranked.map(function (rankedApplication) {
        return rankedApplication.application;
    });
    var boundedLimit = Number(limit);
    return Number.isSafeInteger(boundedLimit) && boundedLimit > 0
        ? result.slice(0, boundedLimit)
        : result;
}

function moveSelection(currentIndex, delta, count) {
    count = Number(count);
    delta = Number(delta);
    if (!Number.isSafeInteger(count) || count <= 0 || !Number.isSafeInteger(delta)) {
        return -1;
    }

    currentIndex = Number(currentIndex);
    if (!Number.isSafeInteger(currentIndex) || currentIndex < 0 || currentIndex >= count) {
        currentIndex = delta < 0 ? 0 : -1;
    }
    return ((currentIndex + delta) % count + count) % count;
}

function pointerMovedEnough(previous, current, threshold) {
    if (!previous || !current) {
        return false;
    }
    var dx = Number(current.x) - Number(previous.x);
    var dy = Number(current.y) - Number(previous.y);
    threshold = Math.max(0, Number(threshold) || 0);
    return isFinite(dx) && isFinite(dy) && Math.sqrt(dx * dx + dy * dy) >= threshold;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        applicationScore: applicationScore,
        filterApplications: filterApplications,
        moveSelection: moveSelection,
        pointerMovedEnough: pointerMovedEnough,
        subsequenceScore: subsequenceScore
    };
}
