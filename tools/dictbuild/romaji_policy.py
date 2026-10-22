"""Particle-aware romaji for expressions, phrase cards, and a few known words.

The default converter in romaji.py reads every kana literally, so the topic
particle は becomes "ha", the object particle を becomes "wo", and an ideographic
comma in a phrase becomes a comma ("hai,genkidesu").  This module rewrites only
the cases that can be told apart from a real "ha" / "wo":

* を is "o" when it is not inside a dictionary word (in modern Japanese it is
  almost only the object particle).
* は is "wa" only when the whole reading segments into dictionary words and
  particles with nothing left over, and that は is not itself inside a word
  (入る stays "hairu", 花 stays "hana", ご飯 stays "gohan").
* こんにちは / こんばんは are "konnichiwa" / "konbanwa" even though JMdict tags
  them as interjections rather than expressions.
* 、 in those same cards becomes a space, not a comma.

Ordinary words are not passed through here.  歯 is still "ha".  都をどり keeps
the historical "wo" because that card is not an expression or a phrase.
"""

from romaji import kana_to_romaji

# Whole-reading overrides.  The second spelling (こんにちわ) already ends in わ.
GREETINGS = {
    'こんにちは': 'konnichiwa',
    'こんばんは': 'konbanwa',
    # 派手 is read はで, so a greedy match turns the first half of this
    # reduplicated conjunction into "deha".  The whole word is "dewadewa".
    'ではでは': 'dewadewa',
}

# One-kana words that are safe to treat as grammatical particles when checking
# that a reading segmented completely.  ね / し / く / た are also common nouns
# and verb endings, so they are not in this set: allowing them makes idioms
# such as 根掘り葉掘り look fully segmented and turns 葉 into "wa".
ONE_CHAR_PARTICLES = set('でにとのがもへやかよて')

PUNCT = set('、。！？・　 ')


# Kanji whose on/kun reading is the mora は.  A reading taken from a card whose
# headword uses one of these, and does not write the particle は/を in kana, is
# a lexical fragment: 木の葉 is "konoha", not "konowa".  It may be consumed only
# while the card being converted itself contains that kanji, so 彼は (no 葉)
# is never swallowed by the uncommon noun 枯葉.
LEXICAL_HA_KANJI = frozenset('葉刃歯端羽波覇')

# Rare nouns that share a reading with a grammatical pattern.  Expressions
# almost always mean the pattern (では "dewa"), and the noun card is not
# eligible, so these readings are never consumed as one word.
GRAMMATICAL_FRAGMENTS = frozenset({
    'では', 'には', 'とは', 'からは', 'へは', 'よりは', 'までは', 'などは',
})


class Lexicon(object):
    """Map a kana reading to 0 (some non-expression card is a common word) or 1.

    lexical maps a reading that contains は onto the kanji that license it.
    """

    def __init__(self):
        self.cost = {}
        self.lexical = {}

    def add(self, reading, common):
        if not reading or reading in ('は', 'を'):
            return
        cost = 0 if common else 1
        prev = self.cost.get(reading)
        if prev is None or cost < prev:
            self.cost[reading] = cost

    def add_lexical(self, reading, kanji):
        if (not reading or len(reading) < 2 or reading in GRAMMATICAL_FRAGMENTS
                or '、' in reading or '。' in reading or 'は' not in reading):
            return
        have = self.lexical.get(reading)
        if have is None:
            self.lexical[reading] = set(kanji)
        else:
            have.update(kanji)

    def __contains__(self, reading):
        return reading in self.cost

    def __len__(self):
        return len(self.cost)


def _reading_parts(reading):
    return [part.strip() for part in (reading or '').split(';') if part.strip()]


def mechanical_romaji(reading):
    """Literal kana romaji for a card's reading field ('; '-joined alternatives)."""
    return '; '.join(kana_to_romaji(part) for part in _reading_parts(reading))


def _acceptable(frag, lex):
    """Longest-match may consume frag.  Uncommon words that contain は or を are
    rejected so a particle is not swallowed by a rare reading (出端 では is
    "deha"; the conjunction では is "dewa").  Common words are kept, which is
    what protects ご飯, 花 and 入る."""
    if len(frag) < 2 or frag not in lex.cost:
        return False
    if '、' in frag or '。' in frag:
        return False
    if frag.endswith('は') and frag != 'はは':
        # A word-final は inside a longer phrase is the topic particle
        # (親は, 帰りは, 又は).  母 is the one common word that really ends in
        # はは.  木の葉 and the other kanji readings stay on the lexical path.
        return False
    if ('は' in frag or 'を' in frag) and lex.cost[frag] != 0:
        return False
    return True


def _lexical_length(text, index, lex, headword):
    """Length of a lexical は-fragment licensed by this card's headword."""
    if not headword:
        return 0
    limit = min(48, len(text) - index)
    for length in range(limit, 1, -1):
        frag = text[index:index + length]
        kanji = lex.lexical.get(frag)
        if kanji and any(k in headword for k in kanji):
            return length
    return 0


def _longest_word(text, index, lex, headword, depth=0):
    limit = min(48, len(text) - index)
    lexical = _lexical_length(text, index, lex, headword)
    best = 0
    for length in range(limit, 1, -1):
        frag = text[index:index + length]
        if length == lexical or _acceptable(frag, lex):
            best = length
            break
    if best == 0 or depth > 8 or text[index] != 'は':
        return best
    # Mid-phrase, a dictionary word that starts with は (花 はな, 箱 はこ)
    # will swallow the topic particle.  Keep the word when it is a licensed
    # fragment, at the start of the phrase, after を, or when it is はなは
    # (花は).  Otherwise leave the は for the particle pass.
    if index == 0 or text[index - 1] in PUNCT or text[index - 1] == 'を':
        return best
    if best == lexical and lexical > 0:
        return best
    # 花は (はなは): the word is real and the next は is the particle.
    if best == 2 and index + 2 < len(text) and text[index + 2] == 'は':
        return best
    # はな in はなさけ swallows the particle because なさけ, starting one kana
    # later, runs past the short match.  入る (はいる) does not: いる stops
    # where はいる stops.
    nxt = _longest_word(text, index + 1, lex, headword, depth + 1)
    if nxt > best - 1:
        # 花よ / 箱よ: the kana after the noun is the vocative, not a longer word.
        if index + best < len(text) and text[index + best] in 'よね':
            return best
        return 0
    return best


def phrase_romaji(text, lex, headword=''):
    """Romaji for one reading alternative (no ';' inside)."""
    if text in GREETINGS:
        return GREETINGS[text]
    if not text:
        return ''
    n = len(text)
    consumed = [False] * n
    i = 0
    while i < n:
        length = _longest_word(text, i, lex, headword)
        if length:
            for k in range(i, i + length):
                consumed[k] = True
            i += length
        else:
            i += 1

    full = True
    for i, ch in enumerate(text):
        if consumed[i] or ch in PUNCT or ch in ONE_CHAR_PARTICLES or ch in 'はを':
            continue
        full = False
        break

    out = []
    buf = []

    def flush():
        if not buf:
            return
        chunk = ''.join(buf)
        buf[:] = []
        if chunk in GREETINGS:
            out.append(GREETINGS[chunk])
        else:
            out.append(kana_to_romaji(chunk))

    i = 0
    while i < n:
        if consumed[i]:
            j = i + 1
            while j < n and consumed[j]:
                j += 1
            buf.append(text[i:j])
            i = j
            continue
        ch = text[i]
        if ch == 'を':
            flush()
            out.append('o')
            i += 1
            continue
        if ch == 'は':
            # A leading は (歯, 覇, 羽, 鱧) and は before っ (張っている) are
            # "ha".  The particle card whose whole reading is は is "wa".
            followed_by_sokuon = (i + 1 < n and text[i + 1] == 'っ')
            at_edge = i == 0 or text[i - 1] in PUNCT
            # をは is を plus a word that starts with は (馳せる), not two particles.
            after_wo = i > 0 and text[i - 1] == 'を'
            if text == 'は' or (full and not at_edge and not followed_by_sokuon and not after_wo):
                flush()
                out.append('wa')
            else:
                buf.append(ch)
            i += 1
            continue
        if ch == '、':
            flush()
            out.append(' ')
            i += 1
            continue
        buf.append(ch)
        i += 1
    flush()
    return ''.join(out)


def adjusted_romaji(reading, lex, headword=''):
    """Like mechanical_romaji, but with particle and comma fixes applied."""
    return '; '.join(phrase_romaji(part, lex, headword) for part in _reading_parts(reading))


def card_is_eligible(card):
    """Expressions, particles, hand-made phrase cards, and the two greetings.

    card is a dict with meaning, reading, card_id and card_type.  JMdict ids are
    ent_seq (>= 1000000).  The hand-made phrase cards copied from 1.x are
    card_type 3 with ids below that.
    """
    reading = card.get('reading') or ''
    for part in _reading_parts(reading):
        if part in GREETINGS:
            return True
    meaning = card.get('meaning') or ''
    # Conjunctions such as では / 又は / 或いは are the same particle は.
    if ('<dfn>expression</dfn>' in meaning or '<dfn>particle</dfn>' in meaning
            or '<dfn>conjunction</dfn>' in meaning):
        return True
    try:
        card_id = int(card.get('card_id') or 0)
    except (TypeError, ValueError):
        card_id = 0
    return card_id < 1000000 and str(card.get('card_type')) == '3'


def _is_curated_phrase(card):
    """Hand-made phrase cards (ids below 1000000, card_type 3).

    Their whole reading is a sentence ("しゃしんをとります"), not a dictionary
    word, so it must not become one lexicon atom.
    """
    try:
        card_id = int(card.get('card_id') or 0)
    except (TypeError, ValueError):
        return False
    return card_id < 1000000 and str(card.get('card_type')) == '3'


def _lexical_kanji(headword):
    if not headword or any(ch in headword for ch in 'はを'):
        return None
    found = {ch for ch in LEXICAL_HA_KANJI if ch in headword}
    return found or None


def build_lexicon(cards):
    """Lexicon of non-expression readings.

    cards: iterable of dicts with reading, meaning, ptag, headword, card_id,
    card_type.
    A reading used only by particle cards (をば, ものは, …) is left out so the
    segmenter can split it into を + the rest.  Readings that occur only on
    expression cards are left out too, so the expression itself is not one opaque
    chunk (それはどうも must be able to break before は).
    """
    owners = {}
    lex = Lexicon()
    for card in cards:
        meaning = card.get('meaning') or ''
        is_exp = '<dfn>expression</dfn>' in meaning
        is_prt = '<dfn>particle</dfn>' in meaning
        common = bool(card.get('ptag'))
        phrase = _is_curated_phrase(card)
        kanji = _lexical_kanji(card.get('headword') or '')
        for part in _reading_parts(card.get('reading') or ''):
            if kanji:
                lex.add_lexical(part, kanji)
            if phrase:
                continue
            owners.setdefault(part, []).append((is_exp, is_prt, common))
    for reading, infos in owners.items():
        if not reading or reading in ('は', 'を'):
            continue
        non_exp = [info for info in infos if not info[0]]
        if not non_exp:
            continue
        if ('は' in reading or 'を' in reading) and all(info[1] for info in non_exp):
            continue
        lex.add(reading, any(info[2] for info in non_exp))
    return lex


def transfer_case(stored, baseline, adjusted):
    """Copy ASCII case from stored onto adjusted.

    Used when the stored romaji matches the literal converter except for letter
    case (内線番号XX… keeps "XX").  Returns None when the strings are not the
    same letters, so a hand-tuned reading is left alone.
    """
    if stored == baseline:
        return adjusted
    if stored.lower() != baseline.lower() or len(stored) != len(baseline):
        return None
    import difflib
    out = []
    si = 0
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(a=baseline, b=adjusted).get_opcodes():
        if tag == 'equal':
            out.append(stored[si:si + (i2 - i1)])
            si += i2 - i1
        elif tag == 'replace':
            out.append(adjusted[j1:j2])
            si += i2 - i1
        elif tag == 'delete':
            si += i2 - i1
        elif tag == 'insert':
            out.append(adjusted[j1:j2])
    if si != len(stored):
        return None
    return ''.join(out)


def romaji_for_card(card, lex):
    """Return (romaji, status).

    status is 'unchanged', 'adjusted', or 'left-alone' (hand-tuned romaji that
    is not a case-only variant of the literal converter).
    """
    stored = card.get('romaji') or ''
    if not card_is_eligible(card):
        return stored, 'unchanged'
    baseline = mechanical_romaji(card.get('reading') or '')
    adjusted = adjusted_romaji(card.get('reading') or '', lex, card.get('headword') or '')
    if stored == baseline:
        return adjusted, ('adjusted' if adjusted != stored else 'unchanged')
    cased = transfer_case(stored, baseline, adjusted)
    if cased is not None:
        return cased, ('adjusted' if cased != stored else 'unchanged')
    return stored, 'left-alone'


def apply_to_cards(cards):
    """Apply the policy to a dict or list of card dicts, in place.

    Dictionary cards still hold the literal converter's romaji.  A curated card
    whose stored romaji is hand-tuned, or already adjusted, is left alone.
    Returns a small count report.
    """
    seq = list(cards.values()) if isinstance(cards, dict) else list(cards)
    lex = build_lexicon(seq)
    adjusted = left = misses = 0
    for card in seq:
        new, status = romaji_for_card(card, lex)
        if status == 'left-alone':
            left += 1
            continue
        old = card.get('romaji') or ''
        if new == old:
            continue
        content = card.get('content')
        if content:
            rebuilt = rebuild_search_bracket(content, card.get('reading') or '', new)
            if rebuilt is None:
                misses += 1
            else:
                card['content'] = rebuilt
        card['romaji'] = new
        adjusted += 1
    return {'adjusted': adjusted, 'left_alone': left, 'bracket_misses': misses}


def rebuild_search_bracket(content, reading, new_romaji):
    """Replace the romaji inside a card's FTS content, keeping the glosses.

    Content looks like: headword [ reading / romaji / optional-nospace ] glosses.
    The space-less romaji is included only when it differs, matching cards.py.
    Returns None if the bracket is not the shape this builder writes.
    """
    if content is None:
        return None
    start = content.find(' [ ')
    end = content.find(' ] ', start + 3 if start >= 0 else 0)
    if start < 0 or end < 0:
        return None
    inside = content[start + 3:end]
    if not inside.startswith(reading + ' / '):
        return None
    parts = new_romaji.split('; ')
    nospace = '; '.join(part.replace(' ', '') for part in parts)
    bits = [reading, new_romaji]
    if nospace != new_romaji:
        bits.append(nospace)
    return content[:start] + ' [ ' + ' / '.join(bits) + ' ] ' + content[end + 3:]
