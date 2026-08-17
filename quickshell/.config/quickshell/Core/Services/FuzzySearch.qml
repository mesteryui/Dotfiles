// --- FuzzySearch (Singleton) ---
// Envoltorio delgado sobre FuzzyMatch.js para que cualquier menú del shell
// pueda hacer fuzzy search sin reimplementar el algoritmo.
//
// Ubicación sugerida: Core/Services/FuzzySearch.qml (mismo lugar que
// ConfigService, I18nService, etc.) para que el import ya te quede
// consistente con el resto del proyecto:
//
//     import qs.Core.Services as Services
//     Services.FuzzySearch.filter(query, items, item => item.name)
//
// Si en tu qmldir de Core/Services registrás los singletons explícitamente,
// acordate de agregar la línea correspondiente ahí también.

pragma Singleton
import QtQuick
import Quickshell
import "FuzzyMatch.js" as FuzzyMatch

Singleton {
    id: root

    /**
     * Matchea una sola query contra un solo string.
     * Útil para casos puntuales (ej: resaltar un único item ya conocido).
     *
     * @param query string tipeado por el usuario
     * @param text string contra el que se compara
     * @return { matched: bool, score: real, indices: list<int> }
     */
    function match(query, text) {
        return FuzzyMatch.fuzzyMatch(query, text);
    }

    /**
     * Filtra y ordena por relevancia una lista de items.
     *
     * @param query string tipeado por el usuario
     * @param items array de items (cualquier forma: objetos, strings, model roles)
     * @param getText function(item) -> string, el campo a matchear
     * @return array de { item, score, indices }, ordenado de más a menos relevante.
     *         Si querés solo los items (sin metadata), mapealo vos:
     *         Services.FuzzySearch.filter(q, items, getText).map(r => r.item)
     */
    function filter(query, items, getText) {
        return FuzzyMatch.filterFuzzy(query, items, getText);
    }

    /**
     * Igual que filter(), pero matchea contra varios campos por item y se
     * queda con el mejor score entre ellos. Pensado para casos como keybinds,
     * donde querés que la búsqueda encuentre tanto por combinación de teclas
     * como por descripción.
     *
     * @param getTexts function(item) -> string[]
     */
    function filterMulti(query, items, getTexts) {
        return FuzzyMatch.filterFuzzyMulti(query, items, getTexts);
    }

    /**
     * Devuelve solo los items (sin score/indices), ya ordenados. Azúcar
     * sintáctico para el caso más común: bindear directo a un model.
     */
    function filterItems(query, items, getText) {
        return FuzzyMatch.filterFuzzy(query, items, getText).map(r => r.item);
    }

    function filterItemsMulti(query, items, getTexts) {
        return FuzzyMatch.filterFuzzyMulti(query, items, getTexts).map(r => r.item);
    }

    /**
     * Parte un string en segmentos {text, matched} según los indices de un
     * match previo, para poder resaltar en la UI (negrita, color, etc.).
     */
    function highlightSegments(text, indices) {
        return FuzzyMatch.highlightSegments(text, indices);
    }
}
