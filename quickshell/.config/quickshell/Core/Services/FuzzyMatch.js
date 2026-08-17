// --- FuzzyMatch.js ---
// Algoritmo puro de fuzzy matching. Sin imports de Quickshell/Qt a propósito:
// así se puede testear con `qjs`/node y reusar en cualquier singleton o
// componente sin arrastrar dependencias.
//
// Estrategia: subsequence match (los caracteres de `query` deben aparecer en
// `text`, en orden, no necesariamente contiguos) + scoring que premia:
//   - coincidencias consecutivas (escalando, no lineal)
//   - coincidencia justo después de un separador (espacio, -, _, /, .)
//   - transición camelCase (fooBar → matchear la B cuenta como "límite")
//   - coincidencia en la posición 0
// y penaliza levemente:
//   - separación entre el primer y último char matcheado (span más ancho
//     que la query = match más "disperso" = menos relevante)
//   - longitud total del texto (a igualdad de score, favorece textos cortos)

/**
 * @param {string} query
 * @param {string} text
 * @returns {{matched: boolean, score: number, indices: number[]}}
 */
function fuzzyMatch(query, text) {
    if (!query || query.length === 0) {
        return { matched: true, score: 0, indices: [] };
    }
    if (!text || text.length === 0) {
        return { matched: false, score: -1, indices: [] };
    }

    const q = query.toLowerCase();
    const t = text.toLowerCase();

    let qi = 0;
    let score = 0;
    const indices = [];
    let prevMatchIndex = -1;
    let consecutiveRun = 0;

    for (let ti = 0; ti < t.length && qi < q.length; ti++) {
        if (t[ti] !== q[qi]) continue;

        let charScore = 10;

        if (prevMatchIndex === ti - 1) {
            consecutiveRun++;
            charScore += consecutiveRun * 8; // corridas largas pesan cada vez más
        } else {
            consecutiveRun = 0;
        }

        if (ti === 0) {
            charScore += 15;
        } else {
            const prevChar = text[ti - 1];
            if (/[\s\-_/.]/.test(prevChar)) {
                charScore += 12; // arranca palabra/segmento
            } else if (/[a-z]/.test(prevChar) && /[A-Z]/.test(text[ti])) {
                charScore += 12; // camelCase boundary
            }
        }

        score += charScore;
        indices.push(ti);
        prevMatchIndex = ti;
        qi++;
    }

    if (qi < q.length) {
        // No se pudo matchear toda la query como subsecuencia
        return { matched: false, score: -1, indices: [] };
    }

    const span = indices[indices.length - 1] - indices[0] + 1;
    score -= (span - q.length) * 2;   // penaliza dispersión
    score -= Math.min(text.length, 40) * 0.3; // penaliza textos largos, con tope

    return { matched: true, score, indices };
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

    if (!query || query.trim().length === 0) {
        // Sin query: devolver todo tal cual vino, sin reordenar ni puntuar.
        return items.map(item => ({ item, score: 0, indices: [] }));
    }

    const results = [];
    for (let i = 0; i < items.length; i++) {
        const item = items[i];
        const text = getText(item) ?? "";
        const result = fuzzyMatch(query, text);
        if (result.matched) {
            results.push({ item, score: result.score, indices: result.indices });
        }
    }

    // Mayor score primero; a empate, conserva el orden original (sort estable).
    results.sort((a, b) => b.score - a.score);
    return results;
}

/**
 * Filtra por múltiples campos, tomando el mejor score entre ellos.
 * Útil para keybinds donde querés matchear tanto la combinación ("Super+Q")
 * como la descripción ("Cerrar ventana").
 *
 * @param {string} query
 * @param {Array<any>} items
 * @param {(item: any) => string[]} getTexts  extrae varios strings candidatos por item
 */
function filterFuzzyMulti(query, items, getTexts) {
    if (!items) return [];

    if (!query || query.trim().length === 0) {
        return items.map(item => ({ item, score: 0, indices: [] }));
    }

    const results = [];
    for (let i = 0; i < items.length; i++) {
        const item = items[i];
        const texts = getTexts(item) || [];
        let best = null;
        for (const text of texts) {
            const result = fuzzyMatch(query, text ?? "");
            if (result.matched && (!best || result.score > best.score)) {
                best = result;
            }
        }
        if (best) {
            results.push({ item, score: best.score, indices: best.indices });
        }
    }

    results.sort((a, b) => b.score - a.score);
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

    const segments = [];
    const indexSet = new Set(indices);
    let current = "";
    let currentMatched = null;

    for (let i = 0; i < text.length; i++) {
        const isMatched = indexSet.has(i);
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
