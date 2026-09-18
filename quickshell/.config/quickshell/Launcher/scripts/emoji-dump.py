#!/usr/bin/env python3
"""Runtime emoji/symbol source for Launcher/EmojiService.qml.

The picker catalog is NOT stored in JS: this script generates it live
from real libraries as TSV:

    CH \\t NAME \\t GROUP \\t KEYWORDS   (one entry per line)
    #VERSION \\t <emoji-lib-version|missing>  (--all only, first line)
    #SYN \\t WORD \\t EXPANSION ...      (query synonyms, --all only)
    #SECTION \\t emojis|symbols          (section markers, --all only)

  CH    = the character(s) to copy
  NAME  = English name (CLDR-style from the `emoji` package, or
          unicodedata names for symbols), lowercased by the consumer
  GROUP = broad bucket: caras | gente | cosas | simbolos

Sources:
  - emojis:  the `emoji` PyPI package (EMOJI_DATA, fully-qualified only,
             no skin-tone modifiers). `pip install emoji`
  - symbols: the Python STDLIB `unicodedata` module (arrows, math,
             currency, dingbats…), selected by Unicode block + name
             patterns below. No hardcoded characters, always available.

Usage:
  python3 emoji-dump.py            # emojis only (TSV to stdout)
  python3 emoji-dump.py --all      # emojis + symbols (what the service uses)
  python3 emoji-dump.py --symbols  # symbols only
  python3 emoji-dump.py --count    # emoji count (premise check)
  python3 emoji-dump.py --version  # `emoji` package version
"""

import sys
import unicodedata

SKIN_TONES = ("\U0001F3FB", "\U0001F3FC", "\U0001F3FD", "\U0001F3FE", "\U0001F3FF")

# Exact-name overrides (checked before the word rules).
EXACT_GROUP = {
    "star-struck": "caras",
    "shooting star": "cosas",
    "kiss mark": "caras",
    "fire extinguisher": "cosas",
    "fire engine": "cosas",
    "firecracker": "cosas",
    "fireworks": "cosas",
    "sparkler": "cosas",
}

CARAS_WORDS = {
    "face", "ghost", "alien", "robot", "skull", "clown", "ogre", "goblin",
    "poo", "kiss", "kisses", "hug", "monkey", "gorilla", "grinning",
    "smiling", "smiley", "tears", "crying", "cry", "laugh", "laughing",
    "joy", "wink", "yum",
}

GENTE_WORDS = {
    "person", "people", "man", "woman", "men", "women", "boy", "girl",
    "baby", "babies", "child", "children", "adult", "family", "families",
    "couple", "bride", "groom", "prince", "princess", "hand", "hands",
    "finger", "fingers", "thumb", "thumbs", "fist", "clap", "palm",
    "palms", "handshake", "muscle", "arm", "arms", "leg", "legs", "foot",
    "feet", "ear", "ears", "nose", "lips", "mouth", "tongue", "tooth",
    "teeth", "eye", "eyes", "brain", "heart", "hearts", "bust", "busts",
    "selfie", "selfies", "pregnant", "dance", "dancing", "dancer",
    "dancers", "walk", "walking", "run", "running", "swim", "swimming",
    "surf", "surfing", "bike", "biking", "lift", "lifting", "yoga",
    "santa", "claus", "angel", "mage", "fairy", "vampire", "zombie",
    "ninja", "pilot", "astronaut", "firefighter", "judge", "farmer",
    "cook", "artist", "guard", "detective", "worker", "scientist",
    "student", "teacher", "singer", "superhero", "supervillain",
    "bride", "superhero",
}

SIMBOLOS_WORDS = {
    "arrow", "arrows", "symbol", "symbols", "warning", "prohibited",
    "information", "question", "exclamation", "check", "cross",
    "plus", "minus", "multiply", "multiplied", "division", "divide",
    "equal", "equals", "infinity", "percent", "percentage", "copyright",
    "registered", "trademark", "button", "buttons", "keycap", "input",
    "number", "numbers", "hash", "asterisk", "om", "yin", "yang",
    "star", "stars", "sparkle", "sparkles", "fire", "flame", "hundred",
    "ideograph", "cool", "free", "new", "up", "sos", "vs", "abc",
    "abcd", "cl", "chart", "heavy", "eight", "seven", "wavy", "currency",
    "dollar", "yen", "euro", "copyright",
}

# Extra search words, used BOTH ways: if a NAME token is in here its
# expansion is indexed with the entry, and the pairs are also emitted
# as `#SYN` lines so the service expands QUERY tokens the same way
# (e.g. typing "lol" also tries "laugh"/"joy").
SYNONYMS = {
    "smile": "smiling grinning happy",
    "happy": "smile smiling",
    "sad": "cry crying tears",
    "cry": "crying tears",
    "tears": "cry crying",
    "crying": "cry tears",
    "laugh": "laughing grin",
    "kiss": "kissing",
    "love": "heart hearts kiss",
    "lol": "laugh joy",
    "tux": "penguin",
    "cool": "sunglasses",
    "funny": "laugh grin",
    "angry": "rage mad",
    "party": "celebrate birthday",
    "think": "thinking",
    "ok": "check yes",
    "x": "cross close",
    "tv": "television",
    "car": "automobile",
    "bike": "bicycle",
    "plane": "airplane",
    "soccer": "football",
    "photo": "camera",
    "pc": "computer",
    "phone": "mobile cell",
}


def stems(token):
    """Morphological variants so queries find inflected names and back:
    smile<->smiling, heart<->hearts, baby<->babies, love<->loved..."""
    out = [token]
    t = token

    def add(w):
        if w and len(w) > 1 and w not in out:
            out.append(w)

    def doubled(s):
        return (len(s) >= 2 and s[-1] == s[-2] and s[-1] not in "aeiou"
                and s[-1].isalpha())

    if len(t) > 4 and t.endswith("ies"):
        add(t[:-3] + "y")
    elif (len(t) > 4 and t.endswith("es") and not t.endswith("ss")):
        add(t[:-1])
        if t.endswith(("ses", "xes", "zes", "ches", "shes")):
            add(t[:-2])
    elif (len(t) > 3 and t.endswith("s")
          and not t.endswith(("ss", "us", "is"))):
        add(t[:-1])
    if len(t) > 5 and t.endswith("ing"):
        stem = t[:-3]
        add(stem)
        add(stem + "e")
        if doubled(stem):
            add(stem[:-1])
        if t.endswith("ying"):
            add(t[:-4] + "y")
    elif len(t) > 4 and t.endswith("ed"):
        stem = t[:-2]
        add(stem)
        add(stem + "e")
        if doubled(stem):
            add(stem[:-1])
        if t.endswith("ied"):
            add(t[:-3] + "y")
    return out


def keywords(name):
    """Search words: name tokens, their stems, plus synonym expansions."""
    toks = words(name)
    extra = []
    for w in toks:
        for s in stems(w):
            if s not in toks and s not in extra:
                extra.append(s)
        if w in SYNONYMS:
            for s in SYNONYMS[w].split():
                if s not in toks and s not in extra:
                    extra.append(s)
    return " ".join(toks + extra)

# (start, end, [UPPERCASE name patterns] or None = all named chars)
SYMBOL_SPECS = [
    (0x00A0, 0x00FF, ["MULTIPLICATION", "DIVISION", "COPYRIGHT",
                       "REGISTERED", "DEGREE", "PLUS-MINUS", "SECTION",
                       "PARAGRAPH", "MIDDLE DOT", "POUND SIGN", "YEN SIGN",
                       "CENT SIGN"]),
    (0x2000, 0x206F, ["PER MILLE", "DOUBLE EXCLAMATION", "EXCLAMATION QUESTION",
                       "DOUBLE QUESTION", "DAGGER", "BULLET", "ASTERISM",
                       "REFERENCE MARK"]),
    (0x20A0, 0x20CF, None),  # currency symbols, all
    (0x2190, 0x21FF, ["ARROW"]),
    (0x2200, 0x22FF, ["FOR ALL", "COMPLEMENT", "PARTIAL DIFFERENTIAL",
                       "THERE EXISTS", "EMPTY SET", "NABLA", "ELEMENT OF",
                       "NOT AN ELEMENT", "CONTAINS AS", "MINUS SIGN",
                       "PLUS SIGN", "DIVISION SIGN", "MULTIPLICATION SIGN",
                       "EQUAL TO", "NOT EQUAL", "IDENTICAL TO",
                       "LESS-THAN", "GREATER-THAN", "INFINITY", "INTEGRAL",
                       "SQUARE ROOT", "CUBE ROOT", "PROPORTIONAL TO",
                       "ANGLE", "LOGICAL", "N-ARY", "DOT OPERATOR", "RATIO",
                       "BECAUSE", "THEREFORE", "TILDE OPERATOR",
                       "INTERSECTION", "UNION", "SUBSET", "SUPERSET",
                       "CIRCLED PLUS", "CIRCLED TIMES", "PERCENT",
                       "DEGREE", "PRIME", "DOUBLE PRIME"]),
    (0x25A0, 0x25FF, ["SQUARE", "CIRCLE", "TRIANGLE", "DIAMOND", "LOZENGE"]),
    (0x2700, 0x27BF, ["CHECK MARK", "BALLOT", "CROSS MARK", "MULTIPLICATION X",
                       "STAR", "SPARKLE", "PENCIL", "SCISSORS", "HEART",
                       "MUSICAL NOTE", "MUSICAL NOTES", "ANCHOR", "SNOWFLAKE",
                       "UMBRELLA", "TELEPHONE", "AIRPLANE", "ENVELOPE",
                       "FLOWER", "SUN WITH", "CLOUD WITH", "UMBRELLA WITH"]),
    (0x2B00, 0x2BFF, ["ARROW", "BLACK STAR", "WHITE STAR", "BLACK CIRCLE",
                       "WHITE CIRCLE", "BLACK SQUARE", "WHITE SQUARE"]),
]


def words(text):
    return [w for w in "".join(c if c.isalnum() else " " for c in text.lower()).split() if w]


def classify(name):
    """Broad group for an `emoji`-package English name."""
    low = name.lower()
    if low in EXACT_GROUP:
        return EXACT_GROUP[low]
    toks = set(words(low))
    if toks & CARAS_WORDS:
        return "caras"
    if toks & GENTE_WORDS:
        return "gente"
    if toks & SIMBOLOS_WORDS:
        return "simbolos"
    return "cosas"


def iter_emojis():
    import emoji  # pip install emoji

    for ch, data in emoji.EMOJI_DATA.items():
        if data.get("status") != 2:  # 2 = fully-qualified
            continue
        if any(t in ch for t in SKIN_TONES):
            continue
        name = data.get("en", "").strip()
        if not name or len(ch) > 12:
            continue
        name = name.strip(":").replace("_", " ")
        if not name:
            continue
        yield ch, name, classify(name)


def iter_symbols():
    for start, end, patterns in SYMBOL_SPECS:
        for cp in range(start, end + 1):
            ch = chr(cp)
            if unicodedata.category(ch).startswith("C"):
                continue
            try:
                uname = unicodedata.name(ch)
            except ValueError:
                continue
            if patterns is not None and not any(p in uname for p in patterns):
                continue
            name = uname.lower().replace("-", " ")
            yield ch, name, "simbolos"


GROUP_RANK = {"caras": 0, "gente": 1, "cosas": 2, "simbolos": 3}


def emit_version(out):
    try:
        import emoji

        out.write(f"#VERSION\t{getattr(emoji, '__version__', 'unknown')}\n")
    except ImportError:
        out.write("#VERSION\tmissing\n")


def emit(pairs):
    out = sys.stdout
    for ch, name, group in pairs:
        name = name.replace("\t", " ").replace("\n", " ")
        out.write(f"{ch}\t{name}\t{group}\t{keywords(name)}\n")


def main():
    args = sys.argv[1:]
    if "--version" in args:
        try:
            import emoji

            print(getattr(emoji, "__version__", "unknown"))
        except ImportError:
            print("missing")
        return 0
    if "--count" in args:
        try:
            print(sum(1 for _ in iter_emojis()))
        except ImportError:
            print(0)
        return 0
    if "--symbols" in args:
        # Sin dependencias externas: solo stdlib.
        emit(sorted(iter_symbols(), key=lambda e: e[1]))
        return 0
    try:
        if "--all" in args:
            # Browse order: faces first, symbols last (stable within group).
            emojis = sorted(iter_emojis(),
                            key=lambda e: (GROUP_RANK[e[2]], e[1]))
            symbols = sorted(iter_symbols(), key=lambda e: e[1])
            out = sys.stdout
            emit_version(out)
            for word in sorted(SYNONYMS):
                out.write(f"#SYN\t{word}\t{SYNONYMS[word]}\n")
            out.write("#SECTION\temojis\n")
            emit(emojis)
            out.write("#SECTION\tsymbols\n")
            emit(symbols)
        else:
            emit(sorted(iter_emojis()))
    except ImportError:
        # Sin la librería `emoji`: degradado elegante (sinónimos + stdlib),
        # exit 0 para que el servicio lo consuma igual (lib=0 en el conteo).
        print("emoji-dump: python package `emoji` not installed", file=sys.stderr)
        if "--all" in args:
            out = sys.stdout
            emit_version(out)
            for word in sorted(SYNONYMS):
                out.write(f"#SYN\t{word}\t{SYNONYMS[word]}\n")
            out.write("#SECTION\temojis\n")
            out.write("#SECTION\tsymbols\n")
            emit(sorted(iter_symbols(), key=lambda e: e[1]))
            return 0
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
