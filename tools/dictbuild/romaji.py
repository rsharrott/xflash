"""Kana -> romaji (modified Hepburn, ASCII only), matching the style of the
2010 jFlash data: long vowels are written out (ou, uu, aa for katakana ー),
small tsu doubles the next consonant (cch for っち), ん is "n"."""

_BASE = {
    'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o',
    'か': 'ka', 'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko',
    'が': 'ga', 'ぎ': 'gi', 'ぐ': 'gu', 'げ': 'ge', 'ご': 'go',
    'さ': 'sa', 'し': 'shi', 'す': 'su', 'せ': 'se', 'そ': 'so',
    'ざ': 'za', 'じ': 'ji', 'ず': 'zu', 'ぜ': 'ze', 'ぞ': 'zo',
    'た': 'ta', 'ち': 'chi', 'つ': 'tsu', 'て': 'te', 'と': 'to',
    'だ': 'da', 'ぢ': 'ji', 'づ': 'zu', 'で': 'de', 'ど': 'do',
    'な': 'na', 'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no',
    'は': 'ha', 'ひ': 'hi', 'ふ': 'fu', 'へ': 'he', 'ほ': 'ho',
    'ば': 'ba', 'び': 'bi', 'ぶ': 'bu', 'べ': 'be', 'ぼ': 'bo',
    'ぱ': 'pa', 'ぴ': 'pi', 'ぷ': 'pu', 'ぺ': 'pe', 'ぽ': 'po',
    'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo',
    'や': 'ya', 'ゆ': 'yu', 'よ': 'yo',
    'ら': 'ra', 'り': 'ri', 'る': 'ru', 'れ': 're', 'ろ': 'ro',
    'わ': 'wa', 'ゐ': 'i', 'ゑ': 'e', 'を': 'wo', 'ん': 'n',
    'ゔ': 'vu', 'ゕ': 'ka', 'ゖ': 'ke',
    'ぁ': 'a', 'ぃ': 'i', 'ぅ': 'u', 'ぇ': 'e', 'ぉ': 'o',
    'ゃ': 'ya', 'ゅ': 'yu', 'ょ': 'yo', 'ゎ': 'wa',
}
# Two-kana combinations (checked before single kana).
_DIGRAPH = {}
for k, r in (('き', 'k'), ('ぎ', 'g'), ('に', 'n'), ('ひ', 'h'), ('び', 'b'),
             ('ぴ', 'p'), ('み', 'm'), ('り', 'r')):
    _DIGRAPH[k + 'ゃ'] = r + 'ya'
    _DIGRAPH[k + 'ゅ'] = r + 'yu'
    _DIGRAPH[k + 'ょ'] = r + 'yo'
    _DIGRAPH[k + 'ぇ'] = r + 'ye'
for k, r in (('し', 'sh'), ('ち', 'ch'), ('じ', 'j'), ('ぢ', 'j')):
    _DIGRAPH[k + 'ゃ'] = r + 'a'
    _DIGRAPH[k + 'ゅ'] = r + 'u'
    _DIGRAPH[k + 'ょ'] = r + 'o'
    _DIGRAPH[k + 'ぇ'] = r + 'e'
_DIGRAPH.update({
    'てぃ': 'ti', 'でぃ': 'di', 'とぅ': 'tu', 'どぅ': 'du',
    'てゅ': 'tyu', 'でゅ': 'dyu', 'ふゅ': 'fyu',
    'ふぁ': 'fa', 'ふぃ': 'fi', 'ふぇ': 'fe', 'ふぉ': 'fo',
    'うぃ': 'wi', 'うぇ': 'we', 'うぉ': 'wo', 'いぇ': 'ye',
    'ゔぁ': 'va', 'ゔぃ': 'vi', 'ゔぇ': 've', 'ゔぉ': 'vo', 'ゔゅ': 'vyu',
    'つぁ': 'tsa', 'つぃ': 'tsi', 'つぇ': 'tse', 'つぉ': 'tso',
    'くぁ': 'kwa', 'くぃ': 'kwi', 'くぇ': 'kwe', 'くぉ': 'kwo', 'ぐぁ': 'gwa',
    'すぃ': 'si', 'ずぃ': 'zi',
})
_PUNCT = {'・': ' ', '、': ',', '。': '.', '　': ' ', '〜': '~', '～': '~',
          '＝': '=', '！': '!', '？': '?', '（': '(', '）': ')'}


def _to_hiragana(text):
    out = []
    for ch in text:
        o = ord(ch)
        if 0x30A1 <= o <= 0x30F6:  # katakana -> hiragana
            out.append(chr(o - 0x60))
        elif ch in 'ヷヸヹヺ':
            out.append({'ヷ': 'わ゛', 'ヸ': 'ゐ゛', 'ヹ': 'ゑ゛', 'ヺ': 'を゛'}[ch])
        else:
            out.append(ch)
    return ''.join(out)


def _fullwidth_ascii(ch):
    o = ord(ch)
    if 0xFF01 <= o <= 0xFF5E:
        return chr(o - 0xFEE0)
    return None


def kana_to_romaji(text):
    """Convert a kana string to lower-case ASCII romaji. Non-kana characters
    (kanji, Latin letters, digits) are passed through (full-width ASCII is
    narrowed)."""
    s = _to_hiragana(text)
    out = []
    i = 0
    sokuon = False
    while i < len(s):
        ch = s[i]
        if ch in 'っッ':
            sokuon = True
            i += 1
            continue
        if ch == 'ー':
            # repeat the previous vowel
            prev = ''.join(out)
            for c in reversed(prev):
                if c in 'aeiou':
                    out.append(c)
                    break
            i += 1
            continue
        pair = s[i:i + 2]
        if pair in _DIGRAPH:
            rom = _DIGRAPH[pair]
            i += 2
        elif ch in _BASE:
            rom = _BASE[ch]
            i += 1
        elif ch in _PUNCT:
            rom = _PUNCT[ch]
            i += 1
        else:
            fw = _fullwidth_ascii(ch)
            rom = (fw if fw is not None else ch).lower()
            i += 1
        if sokuon:
            if rom.startswith('ch'):
                rom = 'c' + rom
            elif rom and rom[0] in 'bcdfghjklmpqrstvwxyz':
                rom = rom[0] + rom
            sokuon = False
        out.append(rom)
    return ''.join(out)


if __name__ == '__main__':
    for w in ['かける', 'おねえさん', 'いっちょう', 'スマート', 'にほん', 'しゃしん',
              'ちょっと', 'ティーシャツ', 'げんいん', 'ヴァイオリン', 'がっこう']:
        print(w, kana_to_romaji(w))
