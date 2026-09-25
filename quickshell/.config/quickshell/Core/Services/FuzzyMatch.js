// --- FuzzyMatch.js ---
// Algoritmo puro de fuzzy matching. Sin imports de Quickshell/Qt a propósito:
// así se puede testear con `qjs`/node y reusar en cualquier singleton o
// componente sin arrastrar dependencias.
//
// Estrategia por token (la query se divide por espacios; todos los tokens
// deben matchear):
//   exacto (1000) > prefijo (500) > prefijo-de-palabra (300) >
//   substring (200) > subsecuencia fuzzy (0-150, DP óptimo) > typo-1 (45)
// con bonus por límite de palabra / camelCase / consecutivas y penalización
// por dispersión y longitud. Multi-campo con pesos:
//   getTexts puede devolver string[] (peso 1) o [{text, weight}].

function norm(s) {
    var t = String(s == null ? "" : s).toLowerCase();
    try {
        if (t.normalize)
            t = t.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    } catch (e) {}
    // Fallback / refuerzo si normalize no existe en el motor QML.
    t = t.replace(/[áàäâ]/g, "a").replace(/[éèëê]/g, "e")
         .replace(/[íìïî]/g, "i").replace(/[óòöô]/g, "o")
         .replace(/[úùüû]/g, "u").replace(/[ñ]/g, "n").replace(/[ç]/g, "c");
    return t;
}

function isSep(ch) {
    return ch === " " || ch === "-" || ch === "_" || ch === "/" || ch === "." || ch === "\\" || ch === ":";
}

function wordStarts(text) {
    // Índices donde empieza una palabra (para prefijo-de-palabra).
    var out = [0];
    for (var i = 1; i < text.length; i++) {
        if (isSep(text[i - 1]))
            out.push(i);
    }
    return out;
}

function levDist(a, b, maxDist) {
    // Levenshtein acotado: corta si supera maxDist.
    var n = a.length, m = b.length;
    if (Math.abs(n - m) > maxDist)
        return maxDist + 1;
    var prev = [], cur = [], i, j;
    for (j = 0; j <= m; j++)
        prev[j] = j;
    for (i = 1; i <= n; i++) {
        cur[0] = i;
        var rowMin = cur[0];
        for (j = 1; j <= m; j++) {
            var cost = a[i - 1] === b[j - 1] ? 0 : 1;
            var v = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost);
            cur[j] = v;
            if (v < rowMin)
                rowMin = v;
        }
        if (rowMin > maxDist)
            return maxDist + 1;
        var tmp = prev; prev = cur; cur = tmp;
    }
    return prev[m];
}

function boundaryBonus(ti, text, camel) {
    if (ti === 0)
        return 15;
    var prev = text[ti - 1];
    if (isSep(prev))
        return 12;
    if (camel && camel[ti])
        return 12; // camelCase: minuscula -> MAYUSCULA (del original)
    return 0;
}

function camelMap(orig, normalized) {
    // Marca posiciones límite camelCase según el texto ORIGINAL.
    // Si las longitudes difieren (normalización), se ignora.
    var o = String(orig == null ? "" : orig);
    var out = [];
    if (o.length !== normalized.length)
        return out;
    for (var i = 1; i < o.length; i++) {
        var p = o[i - 1], c = o[i];
        if (p >= "a" && p <= "z" && c >= "A" && c <= "Z")
            out[i] = true;
    }
    return out;
}

function rangeIndices(a, b) {
    var out = [];
    for (var i = a; i < b; i++)
        out.push(i);
    return out;
}

// Score de UN token contra UN texto. Devuelve {matched, score, indices}.
function tokenScore(qTok, text) {
    var q = norm(qTok);
    var t = norm(text);
    var camel = camelMap(text, t);
    var m = t.length, n = q.length;
    if (n === 0)
        return { matched: true, score: 0, indices: [] };
    if (m === 0)
        return { matched: false, score: -1, indices: [] };

    var lenPen = Math.min(m, 40) * 0.3;

    // 1) Exacto.
    if (t === q)
        return { matched: true, score: 1000 - lenPen, indices: rangeIndices(0, m) };

    // 2) Prefijo.
    if (t.indexOf(q) === 0) {
        return { matched: true, score: 500 - lenPen + Math.max(0, 20 - m * 0.2),
                 indices: rangeIndices(0, Math.min(n, m)) };
    }

    // 3) Prefijo de palabra (vsc -> Visual Studio Code por iniciales).
    var starts = wordStarts(t);
    for (var s = 0; s < starts.length; s++) {
        var st = starts[s];
        if (t.indexOf(q, st) === st && q.length >= 2) {
            return { matched: true, score: 300 - lenPen + (st === 0 ? 10 : 0),
                     indices: rangeIndices(st, st + Math.min(n, m - st)) };
        }
        // Iniciales: cada letra del token abre una palabra ("vsc").
        if (q.length >= 2 && q.length <= starts.length) {
            var ok = true, idx = [];
            for (var k = 0; k < q.length; k++) {
                if (t[starts[k]] !== q[k]) { ok = false; break; }
                idx.push(starts[k]);
            }
            if (ok)
                return { matched: true, score: 250 - lenPen, indices: idx };
        }
    }

    // 4) Substring.
    var sub = t.indexOf(q);
    if (sub >= 0) {
        return { matched: true, score: 200 - lenPen - sub * 0.5,
                 indices: rangeIndices(sub, sub + n) };
    }

    // 5) Subsecuencia fuzzy con DP óptimo (O(n*m), bonus consecutivas+límite).
    var res = fuzzyDP(q, t, camel);
    if (res.matched) {
        var span = res.last - res.first + 1;
        var sc = res.score - (span - n) * 2 - lenPen;
        return { matched: true, score: sc, indices: res.indices };
    }

    // 6) Typo-1: query de una palabra contra prefijos de palabra del texto.
    if (n >= 4 && q.indexOf(" ") < 0) {
        var words = t.split(/[\s\-_/.]+/);
        var maxD = n >= 8 ? 2 : 1;
        for (var w = 0; w < words.length; w++) {
            var word = words[w];
            if (word === "")
                continue;
            var cand = word.slice(0, n + 1);
            if (cand === "")
                continue;
            if (levDist(q, cand.slice(0, n), maxD) <= maxD ||
                levDist(q, cand, maxD) <= maxD) {
                var at = t.indexOf(word);
                return { matched: true, score: 45 - lenPen,
                         indices: rangeIndices(at, at + Math.min(n, word.length)) };
            }
        }
    }

    return { matched: false, score: -1, indices: [] };
}

// DP limpio de subsecuencia (separado para legibilidad y testeo).
function fuzzyDP(q, t, camel) {
    var n = q.length, m = t.length;
    var NEG = -1e9;
    var dp = [], from = [], i, ti;
    var bb = function (ti) { return boundaryBonus(ti, t, camel); };
    for (i = 0; i < n; i++) {
        dp.push([]); from.push([]);
        for (ti = 0; ti < m; ti++) {
            dp[i][ti] = NEG; from[i][ti] = -1;
        }
    }
    for (ti = 0; ti < m; ti++) {
        if (t[ti] === q[0])
            dp[0][ti] = 10 + bb(ti);
    }
    for (i = 1; i < n; i++) {
        var best = NEG, bestJ = -1;
        for (ti = 0; ti < m; ti++) {
            // best = max dp[i-1][prev] con prev < ti
            if (ti > 0 && dp[i - 1][ti - 1] > best) {
                best = dp[i - 1][ti - 1];
                bestJ = ti - 1;
            }
            if (t[ti] !== q[i] || best <= NEG / 2)
                continue;
            var base = 10 + bb(ti);
            var useConsec = ti > 0 && dp[i - 1][ti - 1] > NEG / 2;
            var scoreConsec = useConsec ? dp[i - 1][ti - 1] + base + 12 : NEG;
            var scoreJump = best <= NEG / 2 ? NEG : best + base;
            if (scoreConsec >= scoreJump) {
                dp[i][ti] = scoreConsec;
                from[i][ti] = ti - 1;
            } else {
                dp[i][ti] = scoreJump;
                from[i][ti] = bestJ;
            }
        }
    }
    var last = -1, bestEnd = NEG;
    for (ti = 0; ti < m; ti++) {
        if (dp[n - 1][ti] > bestEnd) {
            bestEnd = dp[n - 1][ti];
            last = ti;
        }
    }
    if (last < 0)
        return { matched: false };
    var idx = [], cur = last;
    for (i = n - 1; i >= 0; i--) {
        idx.unshift(cur);
        if (i > 0)
            cur = from[i][cur];
    }
    return { matched: true, score: bestEnd, indices: idx, first: idx[0], last: idx[idx.length - 1] };
}

/**
 * @param {string} query
 * @param {string} text
 * @returns {{matched: boolean, score: number, indices: number[]}}
 */
function fuzzyMatch(query, text) {
    if (query == null || String(query).trim().length === 0) {
        return { matched: true, score: 0, indices: [] };
    }
    if (text == null || String(text).length === 0) {
        return { matched: false, score: -1, indices: [] };
    }
    var toks = String(query).trim().split(/\s+/);
    if (toks.length === 1)
        return tokenScore(toks[0], text);
    // Multi-token: todos deben matchear; suma + bonus si salen en orden.
    var total = 0, allIdx = [], pos = -1, ordered = true;
    for (var k = 0; k < toks.length; k++) {
        var r = tokenScore(toks[k], text);
        if (!r.matched)
            return { matched: false, score: -1, indices: [] };
        total += r.score;
        for (var j = 0; j < r.indices.length; j++)
            allIdx.push(r.indices[j]);
        if (r.indices.length > 0) {
            if (r.indices[0] < pos)
                ordered = false;
            pos = r.indices[r.indices.length - 1];
        }
    }
    if (ordered)
        total += 20;
    allIdx.sort(function (a, b) { return a - b; });
    return { matched: true, score: total, indices: allIdx };
}

function asFields(entry) {
    // Acepta string | {text, weight} | [text, weight].
    if (typeof entry === "string")
        return { text: entry, weight: 1 };
    if (entry != null && typeof entry === "object") {
        if (typeof entry.length === "number" && typeof entry.text === "undefined") {
            return { text: entry[0] != null ? String(entry[0]) : "", weight: Number(entry[1]) || 1 };
        }
        return { text: entry.text != null ? String(entry.text) : "", weight: Number(entry.weight) || 1 };
    }
    return { text: "", weight: 1 };
}

/**
 * Filtra y ordena una lista arbitraria por relevancia de fuzzy match.
 *
 * @param {string} query
 * @param {Array<any>} items
 * @param {(item: any) => string} getText  extrae el string a matchear de cada item
 * @returns {Array<{item: any, score: number, indices: number[]}>}
 */
function filterFuzzy(query, items, getText) {
    if (!items) return [];

    if (!query || String(query).trim().length === 0) {
        // Sin query: devolver todo tal cual vino, sin reordenar ni puntuar.
        return items.map(function (item) { return { item: item, score: 0, indices: [] }; });
    }

    var results = [];
    for (var i = 0; i < items.length; i++) {
        var item = items[i];
        var text = getText(item);
        if (text == null)
            text = "";
        else
            text = String(text);
        var result = fuzzyMatch(query, text);
        if (result.matched) {
            results.push({ item: item, score: result.score, indices: result.indices });
        }
    }

    // Mayor score primero; a empate, conserva el orden original (sort estable).
    results.sort(function (a, b) { return b.score - a.score; });
    return results;
}

/**
 * Filtra por múltiples campos, tomando el mejor score ponderado entre ellos.
 * getTexts puede devolver string[] (compat) o [{text, weight}].
 *
 * @param {string} query
 * @param {Array<any>} items
 * @param {(item: any) => Array} getTexts
 */
function filterFuzzyMulti(query, items, getTexts) {
    if (!items) return [];

    if (!query || String(query).trim().length === 0) {
        return items.map(function (item) { return { item: item, score: 0, indices: [] }; });
    }

    var results = [];
    for (var i = 0; i < items.length; i++) {
        var item = items[i];
        var texts = getTexts(item) || [];
        var best = null;
        for (var f = 0; f < texts.length; f++) {
            var fld = asFields(texts[f]);
            if (!fld.text)
                continue;
            var result = fuzzyMatch(query, fld.text);
            if (result.matched) {
                var w = { score: result.score * fld.weight, indices: result.indices };
                if (!best || w.score > best.score)
                    best = w;
            }
        }
        if (best) {
            results.push({ item: item, score: best.score, indices: best.indices });
        }
    }

    results.sort(function (a, b) { return b.score - a.score; });
    return results;
}

/**
 * Parte `text` en segmentos según qué caracteres matchearon, para que la UI
 * pueda resaltarlos (ej: negrita, color distinto) sin que este módulo tenga
 * que asumir nada sobre rich text / StyledText.
 *
 * @param {string} text
 * @param {number[]} indices  los `indices` que devuelve fuzzyMatch()
 * @returns {Array<{text: string, matched: boolean}>}
 */
function highlightSegments(text, indices) {
    if (!indices || indices.length === 0) {
        return [{ text: text, matched: false }];
    }

    var segments = [];
    var indexSet = {};
    for (var k = 0; k < indices.length; k++)
        indexSet[indices[k]] = true;
    var current = "";
    var currentMatched = null;
    var i;

    for (i = 0; i < text.length; i++) {
        var isMatched = !!indexSet[i];
        if (currentMatched === null) {
            currentMatched = isMatched;
        }
        if (isMatched !== currentMatched) {
            segments.push({ text: current, matched: currentMatched });
            current = "";
            currentMatched = isMatched;
        }
        current += text[i];
    }
    if (current.length > 0) {
        segments.push({ text: current, matched: currentMatched });
    }

    return segments;
}

// Exports estilo CommonJS-ish para que Quickshell (`.import "FuzzyMatch.js" as FuzzyMatch`)
// pueda acceder a las funciones vía FuzzyMatch.fuzzyMatch(...) etc. — Quickshell/QML
// expone directamente las funciones top-level de un módulo .js, no hace falta module.exports.
