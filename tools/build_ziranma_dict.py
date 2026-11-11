#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build the offline Chinese dictionary using pinned, verified public data.

Python 3.10+; standard library only. See LICENSE-ChineseData.md for licenses,
source hashes, the project encoding contract, and online/offline commands.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import unicodedata
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CACHE = Path(tempfile.gettempdir()) / "easycontroller-ziranma-sources"
FORMAT_VERSION = 2


class BuildError(ValueError):
    """Invalid source, encoding, or generated artifact."""


@dataclass(frozen=True)
class Source:
    filename: str
    repository: str
    commit: str
    path: str
    sha256: str
    license: str

    @property
    def url(self) -> str:
        return (f"https://raw.githubusercontent.com/{self.repository}/"
                f"{self.commit}/{self.path}")


# Never follow a moving branch at build time. License evidence is verified too.
SOURCES = (
    Source("pinyin.txt", "mozillazg/pinyin-data",
           "fe29ad32bdf352b31a02b9936e537f575432e9a6", "pinyin.txt",
           "2342a6f98c85dbc3c8d26aef31744876a36326c6466e51e9a0f16898c36c2011", "MIT"),
    Source("pinyin-data.LICENSE", "mozillazg/pinyin-data",
           "fe29ad32bdf352b31a02b9936e537f575432e9a6", "LICENSE",
           "9c048697be2502a16e8bcb282d5d465a07295b2def0ffb05a269c5d39dbe1586", "MIT"),
    Source("large_pinyin.txt", "mozillazg/phrase-pinyin-data",
           "4afa3226ce53c9138b939e83c3bb294dbe0da511", "large_pinyin.txt",
           "7e34c0e09ad398a7a07c0964bebb9677ace2114ed9d1c2ccdfce939102db2134", "MIT"),
    Source("phrase-pinyin-data.LICENSE", "mozillazg/phrase-pinyin-data",
           "4afa3226ce53c9138b939e83c3bb294dbe0da511", "LICENSE",
           "89ac55df747e4776088c3e77531ef61b973a1a59dd8e6a4548a58996da9a4f70", "MIT"),
    Source("zh_cn_50k.txt", "hermitdave/FrequencyWords",
           "525f9b560de45753a5ea01069454e72e9aa541c6", "content/2018/zh_cn/zh_cn_50k.txt",
           "25599e00347b893e55c3058a748819b3fe19403291cd12f7c03af128e7f3fe45",
           "CC-BY-SA-4.0"),
    Source("FrequencyWords.README.md", "hermitdave/FrequencyWords",
           "525f9b560de45753a5ea01069454e72e9aa541c6", "README.md",
           "a92fcc50e27f7b2d5860ec1c1ce794dc4c892d945bfa4c8c3136cdfd213ee710",
           "License evidence: content is CC-BY-SA-4.0; code is MIT"),
)

# Standard Ziranma double pinyin, including ing=y, un=p, and uai=y.
# Zero-initial syllables follow the original Natural Code spelling below.
INITIALS = {s: s for s in "b p m f d t n l g k h j q x r z c s y w".split()}
INITIALS.update({"zh": "v", "ch": "i", "sh": "u"})
FINALS = {
    "a": "a", "o": "o", "e": "e", "i": "i", "u": "u", "v": "v",
    "ai": "l", "an": "j", "ang": "h", "ao": "k", "ei": "z",
    "en": "f", "eng": "g", "er": "r", "ong": "s", "iong": "s",
    "ou": "b", "ia": "w", "ua": "w", "ie": "x", "iao": "c",
    "ian": "m", "iang": "d", "uang": "d", "in": "n", "ing": "y",
    "iu": "q", "uan": "r", "un": "p", "ue": "t", "ve": "t",
    "ui": "v", "uo": "o", "uai": "y",
}
ZERO_INITIAL = {
    "a": "aa", "o": "oo", "e": "ee", "ai": "ai", "an": "an",
    "ao": "ao", "ang": "ah", "ei": "ei", "en": "en", "eng": "eg",
    "er": "er", "ou": "ou",
}

# Upstream 嗯 is syllabic n/ng, outside the two-key contract. Its familiar IME
# spelling en is an explicit project override; no other readings are invented.
CHARACTER_OVERRIDES = {"嗯": "en"}

# Project-authored additions, MIT at input; combined output is CC-BY-SA.
# Existing corpus counts are kept; absent terms receive a floor of 1.
WOW_PINYIN = {
    "你好": "ni hao", "谢谢": "xie xie", "组队": "zu dui",
    "副本": "fu ben", "治疗": "zhi liao", "坦克": "tan ke",
    "任务": "ren wu", "拍卖行": "pai mai hang",
    "魔兽世界": "mo shou shi jie", "集合": "ji he",
    "加血": "jia xue", "拉怪": "la guai", "没蓝": "mei lan",
    "等一下": "deng yi xia", "辛苦了": "xin ku le",
    "开怪": "kai guai", "开打": "kai da", "停手": "ting shou",
    "打断": "da duan", "驱散": "qu san", "复活": "fu huo",
    "救我": "jiu wo", "喝水": "he shui", "补蓝": "bu lan",
    "回蓝": "hui lan", "满蓝": "man lan", "没血": "mei xue",
    "血量": "xue liang", "血条": "xue tiao", "法力": "fa li",
    "仇恨": "chou hen", "嘲讽": "chao feng", "转火": "zhuan huo",
    "控怪": "kong guai", "羊怪": "yang guai", "标记": "biao ji",
    "跟上": "gen shang", "跟随": "gen sui", "过来": "guo lai",
    "准备好了": "zhun bei hao le", "准备好了吗": "zhun bei hao le ma",
    "稍等": "shao deng", "马上来": "ma shang lai", "我来了": "wo lai le",
    "不好意思": "bu hao yi si", "没关系": "mei guan xi",
    "对不起": "dui bu qi", "再见": "zai jian",
    "好的": "hao de", "收到": "shou dao", "一起": "yi qi",
    "团长": "tuan zhang", "队长": "dui zhang", "队友": "dui you",
    "公会": "gong hui", "团队": "tuan dui", "小队": "xiao dui",
    "团队副本": "tuan dui fu ben", "地下城": "di xia cheng",
    "随机副本": "sui ji fu ben", "英雄副本": "ying xiong fu ben",
    "史诗副本": "shi shi fu ben", "大秘境": "da mi jing",
    "钥匙": "yao shi", "集合石": "ji he shi", "传送门": "chuan song men",
    "传送": "chuan song", "进本": "jin ben", "出本": "chu ben",
    "重置": "chong zhi", "重来": "chong lai", "跑尸": "pao shi",
    "灭团": "mie tuan", "战复": "zhan fu", "释放灵魂": "shi fang ling hun",
    "装备": "zhuang bei", "武器": "wu qi", "饰品": "shi pin",
    "拾取": "shi qu", "需求": "xu qiu", "贪婪": "tan lan",
    "分解": "fen jie", "修理": "xiu li", "耐久": "nai jiu",
    "背包": "bei bao", "背包满了": "bei bao man le", "交易": "jiao yi",
    "金币": "jin bi", "附魔": "fu mo", "宝石": "bao shi",
    "药水": "yao shui", "合剂": "he ji", "食物": "shi wu",
    "烹饪": "peng ren", "邮箱": "you xiang", "炉石": "lu shi",
    "坐骑": "zuo qi", "飞行": "fei xing", "联盟": "lian meng",
    "部落": "bu luo", "暴风城": "bao feng cheng",
    "奥格瑞玛": "ao ge rui ma", "艾泽拉斯": "ai ze la si",
    "战场": "zhan chang", "竞技场": "jing ji chang",
    "排队": "pai dui", "输出": "shu chu", "近战": "jin zhan",
    "远程": "yuan cheng", "法师": "fa shi", "牧师": "mu shi",
    "战士": "zhan shi", "猎人": "lie ren", "术士": "shu shi",
    "圣骑士": "sheng qi shi", "德鲁伊": "de lu yi",
    "萨满": "sa man", "潜行者": "qian xing zhe", "武僧": "wu seng",
    "死亡骑士": "si wang qi shi", "恶魔猎手": "e mo lie shou",
    "唤魔师": "huan mo shi", "接任务": "jie ren wu",
    "交任务": "jiao ren wu", "任务完成": "ren wu wan cheng",
}


def normalize_pinyin(syllable: str) -> str:
    """Remove tone marks/numbers while preserving ü as v (nǚ -> nv)."""
    text = unicodedata.normalize("NFD", syllable.strip().lower().replace("u:", "v"))
    text = text.replace("u\u0308", "v")
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"[0-5]$", "", text)


def encode_syllable(syllable: str) -> str:
    spelling = normalize_pinyin(syllable)
    if spelling in ZERO_INITIAL:
        return ZERO_INITIAL[spelling]
    initial = spelling[:2] if spelling.startswith(("zh", "ch", "sh")) else spelling[:1]
    final = spelling[len(initial):]
    if initial not in INITIALS or final not in FINALS:
        raise BuildError(f"Unsupported two-key pinyin syllable: {syllable!r}")
    return INITIALS[initial] + FINALS[final]


def encode_reading(reading: tuple[str, ...] | list[str]) -> str:
    return "".join(encode_syllable(syllable) for syllable in reading)


def is_han(text: str) -> bool:
    def is_character(c: str) -> bool:
        n = ord(c)
        return (n == 0x3007 or 0x3400 <= n <= 0x4DBF or 0x4E00 <= n <= 0x9FFF
                or 0xF900 <= n <= 0xFAFF or 0x20000 <= n <= 0x2FA1F
                or 0x30000 <= n <= 0x3347F)
    return bool(text) and all(is_character(c) for c in text)


def verify_source(source: Source, data: bytes) -> None:
    actual = hashlib.sha256(data).hexdigest()
    if actual != source.sha256:
        raise BuildError(f"SHA-256 mismatch for {source.filename}: "
                         f"expected {source.sha256}, got {actual}")


def load_sources(cache_dir: Path, offline: bool = False) -> dict[str, str]:
    cache_dir = Path(cache_dir)
    cache_dir.mkdir(parents=True, exist_ok=True)
    result = {}
    for source in SOURCES:
        destination = cache_dir / source.filename
        if destination.exists():
            data = destination.read_bytes()
            verify_source(source, data)
        else:
            if offline:
                raise BuildError(f"Offline source missing: {destination}; "
                                 "populate this cache with an online build first")
            print(f"Downloading {source.url}", file=sys.stderr)
            request = urllib.request.Request(source.url, headers={
                "User-Agent": "EasyController-Ziranma-builder/1"})
            with urllib.request.urlopen(request, timeout=45) as response:
                data = response.read()
            verify_source(source, data)
            temporary = None
            try:
                with tempfile.NamedTemporaryFile(dir=cache_dir, delete=False) as handle:
                    temporary = Path(handle.name)
                    handle.write(data)
                os.replace(temporary, destination)
            finally:
                if temporary is not None:
                    temporary.unlink(missing_ok=True)
        result[source.filename] = data.decode("utf-8-sig")
    return result


def parse_characters(text: str) -> tuple[dict[str, str], dict[str, str]]:
    readings, unsupported = {}, {}
    for number, line in enumerate(text.splitlines(), 1):
        body = line.split("#", 1)[0].strip()
        if not body:
            continue
        match = re.fullmatch(r"U\+([0-9A-Fa-f]+):\s*(.+)", body)
        if not match:
            raise BuildError(f"Invalid pinyin.txt line {number}")
        character = chr(int(match[1], 16))
        if not is_han(character):
            continue
        alternatives = match[2].split(",")
        if character in CHARACTER_OVERRIDES:
            alternatives = [CHARACTER_OVERRIDES[character]]
        for alternative in alternatives:
            try:
                encode_syllable(alternative)
            except BuildError:
                continue
            readings[character] = normalize_pinyin(alternative)
            break
        else:
            unsupported[character] = match[2]
    return readings, unsupported


def parse_frequencies(text: str) -> dict[str, int]:
    frequencies = {}
    for number, line in enumerate(text.splitlines(), 1):
        if not line.strip():
            continue
        parts = line.rsplit(None, 1)
        if len(parts) != 2 or not parts[1].isdigit() or int(parts[1]) <= 0:
            raise BuildError(f"Invalid frequency line {number}")
        word, count = parts[0], int(parts[1])
        if is_han(word):
            frequencies[word] = max(count, frequencies.get(word, 0))
    return frequencies


def parse_phrases(text: str, wanted: set[str] | None = None) -> dict[str, tuple[str, ...]]:
    readings = {}
    for line in text.splitlines():
        body = line.split("#", 1)[0].strip()
        if not body:
            continue
        word, separator, pronunciation = body.partition(":")
        if not separator or len(word) < 2 or not is_han(word):
            continue
        if wanted is not None and word not in wanted:
            continue
        syllables = tuple(normalize_pinyin(s) for s in pronunciation.split())
        # Erhua/foreign readings without one syllable per character cannot be
        # represented by full codes; fragments/characters still work.
        if len(syllables) != len(word):
            continue
        try:
            encode_reading(syllables)
        except BuildError:
            continue
        readings[word] = syllables
    return readings


def resolve_reading(word: str, characters: dict[str, str],
                    phrases: dict[str, tuple[str, ...]]) -> tuple[str, ...] | None:
    if word in phrases:
        return phrases[word]
    # Prefer contextual fragments. Minimize isolated characters, then fragment
    # count, then prefer longer left fragments. No polyphonic Cartesian product.
    best = {len(word): ((0, 0, ()), ())}
    for start in range(len(word) - 1, -1, -1):
        options = []
        for end in range(len(word), start, -1):
            if end not in best:
                continue
            fragment = word[start:end]
            span = end - start
            reading = phrases.get(fragment) if span > 1 else (
                (characters[fragment],) if fragment in characters else None)
            if reading is None:
                continue
            cost, tail = best[end]
            score = (cost[0] + (span == 1), cost[1] + 1, (-span,) + cost[2])
            options.append((score, reading + tail))
        if options:
            best[start] = min(options)
    return best[0][1] if 0 in best else None


def validate_dictionary(dictionary: dict[str, list[str]],
                        frequencies: dict[str, int] | None = None,
                        minimum_characters: int = 6000,
                        minimum_phrases: int = 20000) -> dict[str, int]:
    characters, phrases = set(), set()
    entries = 0
    for code, candidates in dictionary.items():
        if not re.fullmatch(r"(?:[a-z]{2})+", code) or not candidates:
            raise BuildError(f"Invalid/empty dictionary code: {code!r}")
        if len(candidates) != len(set(candidates)):
            raise BuildError(f"Duplicate candidate for {code}")
        if frequencies is not None:
            expected = sorted(candidates, key=lambda word: (-frequencies.get(word, 0), word))
            if candidates != expected:
                raise BuildError(f"Candidates not ordered by frequency: {code}")
        for word in candidates:
            if not is_han(word) or len(code) != 2 * len(word):
                raise BuildError(f"Invalid full-code candidate: {code!r} / {word!r}")
            (characters if len(word) == 1 else phrases).add(word)
            entries += 1
    if len(characters) < minimum_characters or len(phrases) < minimum_phrases:
        raise BuildError(f"Insufficient coverage: {len(characters)} characters, "
                         f"{len(phrases)} phrases")
    for word, pinyin in WOW_PINYIN.items():
        code = encode_reading(pinyin.split())
        if word not in dictionary.get(code, []):
            raise BuildError(f"Required WoW term missing: {word} ({code})")
    return {"characters": len(characters), "phrases": len(phrases),
            "candidates": len(characters) + len(phrases), "entries": entries,
            "codes": len(dictionary), "wow_terms": len(WOW_PINYIN)}


def build_dictionary(sources: dict[str, str]) -> tuple[dict[str, list[str]], dict]:
    characters, unsupported = parse_characters(sources["pinyin.txt"])
    frequencies = parse_frequencies(sources["zh_cn_50k.txt"])
    words = {word for word in frequencies if len(word) > 1} | set(WOW_PINYIN)
    wanted = {word[start:end] for word in words for start in range(len(word))
              for end in range(start + 2, len(word) + 1)}
    phrases = parse_phrases(sources["large_pinyin.txt"], wanted)
    phrases.update({word: tuple(pinyin.split()) for word, pinyin in WOW_PINYIN.items()})
    for word in WOW_PINYIN:
        frequencies.setdefault(word, 1)
    buckets = defaultdict(set)
    for character, reading in characters.items():
        buckets[encode_syllable(reading)].add(character)
    unresolved = []
    exact, segmented = 0, 0
    for word in sorted(words):
        reading = resolve_reading(word, characters, phrases)
        if reading is None:
            unresolved.append(word)
            continue
        buckets[encode_reading(reading)].add(word)
        if word in phrases:
            exact += 1
        else:
            segmented += 1
    dictionary = {code: sorted(candidates, key=lambda w: (-frequencies.get(w, 0), w))
                  for code, candidates in sorted(buckets.items())}
    stats = validate_dictionary(dictionary, frequencies)
    stats.update({"exact_phrase_readings": exact, "segmented_phrase_readings": segmented,
                  "unsupported_characters": unsupported, "unresolved_words": unresolved})
    return dictionary, stats


def render_lua(dictionary: dict[str, list[str]], stats: dict) -> bytes:
    # All keys/values are restricted to ASCII letters / Han. No escaping,
    # executable source data, or runtime indexing is necessary.
    lines = [
        "-- SPDX-License-Identifier: CC-BY-SA-4.0",
        "-- Generated by tools/build_ziranma_dict.py; do not edit by hand.",
        "-- Sources, MIT notices, attribution and rebuild: LICENSE-ChineseData.md",
        "-- FrequencyWords / Hermit Dave, OpenSubtitles 2018; readings / mozillazg.",
        "-- Adapted: Han filtering, contextual readings, full codes, frequency order, WoW terms.",
        "-- Standard Ziranma: ing=y, un=p, uai=y. No abbreviated codes.",
        "local _, CK = ...",
        "CK.ZIRANMA_SOURCES = {",
        f'    format_version = {FORMAT_VERSION},',
        '    license = "CC-BY-SA-4.0",',
        '    license_url = "https://creativecommons.org/licenses/by-sa/4.0/",',
        '    notices = "LICENSE-ChineseData.md",',
        '    encoding = "ziranma",',
    ]
    for key in ("characters", "phrases", "candidates", "entries", "codes", "wow_terms"):
        lines.append(f"    {key} = {stats[key]},")
    lines.append("    sources = {")
    for source in SOURCES:
        if source.filename not in {"pinyin.txt", "large_pinyin.txt", "zh_cn_50k.txt"}:
            continue
        lines.extend([
            "        {",
            f'            repository = "https://github.com/{source.repository}",',
            f'            commit = "{source.commit}",',
            f'            path = "{source.path}",',
            f'            sha256 = "{source.sha256}",',
            f'            license = "{source.license}",',
            "        },",
        ])
    lines.extend(["    },", "}", "CK.ZIRANMA_DICT = {"])
    for code, candidates in sorted(dictionary.items()):
        lines.append(f'    ["{code}"] = "{" ".join(candidates)}",')
    lines.extend(["}", ""])
    return "\n".join(lines).encode("utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-dir", type=Path, default=DEFAULT_CACHE,
                        help="verified cache, default: system temp/easycontroller-ziranma-sources")
    parser.add_argument("--offline", action="store_true", help="use verified cached files only")
    parser.add_argument("--output", type=Path, default=ROOT / "Dict_zhCN.lua")
    parser.add_argument("--check", action="store_true",
                        help="rebuild in memory and require byte-identical output; write nothing")
    args = parser.parse_args(argv)
    try:
        dictionary, stats = build_dictionary(load_sources(args.cache_dir, args.offline))
        data = render_lua(dictionary, stats)
        if args.check:
            if not args.output.exists() or args.output.read_bytes() != data:
                raise BuildError(f"Generated dictionary differs from {args.output}")
        else:
            args.output.write_bytes(data)  # Fixed UTF-8 / LF on Windows and Unix.
        stats.update({"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                      "output": str(args.output), "checked": args.check})
        print(json.dumps(stats, ensure_ascii=False, sort_keys=True, indent=2))
        return 0
    except (BuildError, OSError, urllib.error.URLError) as error:
        print(f"Dictionary build failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
