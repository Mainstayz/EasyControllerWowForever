#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Offline tests: python -B -m unittest discover -s tools -p test_ziranma_dict.py.

Optional: make MIT-licensed lupa.lua51 importable to test a real Lua 5.1 load.
No network, game installation, or input-method engine is required.
"""
import hashlib
import io
from pathlib import Path
import re
import tempfile
import unittest
from unittest import mock

import build_ziranma_dict as builder


class EncodingTests(unittest.TestCase):
    def test_zero_initials(self):
        examples = {"a": "aa", "o": "oo", "e": "ee", "ai": "ai", "an": "an",
                    "ao": "ao", "ang": "ah", "ei": "ei", "en": "en",
                    "eng": "eg", "er": "er", "ou": "ou"}
        for spelling, code in examples.items():
            with self.subTest(spelling=spelling):
                self.assertEqual(builder.encode_syllable(spelling), code)

    def test_initials_and_standard_ziranma_finals(self):
        examples = {
            "zhi": "vi", "chi": "ii", "shi": "ui", "hai": "hl", "han": "hj",
            "hang": "hh", "hao": "hk", "hei": "hz", "hen": "hf", "heng": "hg",
            "hong": "hs", "xiong": "xs", "hou": "hb", "jia": "jw", "hua": "hw",
            "jie": "jx", "jiao": "jc", "jian": "jm", "jiang": "jd", "huang": "hd",
            "jin": "jn", "jing": "jy", "jiu": "jq", "huan": "hr", "hun": "hp",
            "xue": "xt", "nve": "nt", "hui": "hv", "huo": "ho", "guai": "gy",
            "yi": "yi", "ya": "ya", "wo": "wo", "yu": "yu", "yuan": "yr",
        }
        for spelling, code in examples.items():
            with self.subTest(spelling=spelling):
                self.assertEqual(builder.encode_syllable(spelling), code)

    def test_tones_and_umlaut(self):
        for spelling in ("lǜ", "lü4", "lv4", "LU:4", "lu\u0308\u0300"):
            self.assertEqual(builder.normalize_pinyin(spelling), "lv")
            self.assertEqual(builder.encode_syllable(spelling), "lv")
        self.assertEqual(builder.encode_syllable("nǚ"), "nv")
        self.assertEqual(builder.encode_syllable("nüè"), "nt")
        self.assertEqual(builder.encode_syllable("xuě"), "xt")
        self.assertEqual(builder.encode_syllable("ê"), "ee")

    def test_invalid_syllables_fail_explicitly(self):
        for syllable in ("", "n", "ng", "hng", "tunwa", "hello", "ni hao", "ni6"):
            with self.subTest(syllable=syllable), self.assertRaises(builder.BuildError):
                builder.encode_syllable(syllable)


class SourceTests(unittest.TestCase):
    def test_character_coverage_and_exception(self):
        readings, skipped = builder.parse_characters(
            "# fixture\nU+4F60: nǐ # 你\nU+55EF: ń,ńg # 嗯\n"
            "U+54FC: hng,hēng # 哼\nU+20000: hē # supplementary Han\n"
            "U+E815: yè # private use\nU+74F2: túnwǎ # unsupported\n")
        self.assertEqual(readings, {"你": "ni", "嗯": "en", "哼": "heng", "𠀀": "he"})
        self.assertEqual(skipped, {"瓲": "túnwǎ"})

    def test_frequency_filter_and_duplicate_counts(self):
        result = builder.parse_frequencies(
            "你 30\n你好 20\nyou 99\n你们! 80\n你 好 70\n你好 10\n𠀀 2\n")
        self.assertEqual(result, {"你": 30, "你好": 20, "𠀀": 2})
        for line in ("你好\n", "你好 nope\n", "你好 -1\n", "你好 0\n"):
            with self.assertRaises(builder.BuildError):
                builder.parse_frequencies(line)

    def test_exact_and_contextual_polyphones(self):
        characters = {"还": "hai", "给": "gei", "我": "wo", "们": "men",
                      "银": "yin", "行": "xing", "音": "yin", "乐": "le"}
        phrases = builder.parse_phrases(
            "# fixture\n银行: yín háng\n音乐: yīn yuè\n还给: huán gěi\n"
            "坏例: huài\n坏词: no such\n")
        self.assertEqual(builder.resolve_reading("银行", characters, phrases), ("yin", "hang"))
        self.assertEqual(builder.resolve_reading("音乐", characters, phrases), ("yin", "yue"))
        self.assertEqual(builder.resolve_reading("还给我们", characters, phrases),
                         ("huan", "gei", "wo", "men"))
        self.assertIsNone(builder.resolve_reading("未知", characters, phrases))
        self.assertNotIn("坏例", phrases)
        self.assertNotIn("坏词", phrases)

    def test_every_source_has_pinned_revision_hash_and_https(self):
        self.assertEqual(len({source.filename for source in builder.SOURCES}), 6)
        for source in builder.SOURCES:
            self.assertRegex(source.commit, r"^[0-9a-f]{40}$")
            self.assertRegex(source.sha256, r"^[0-9a-f]{64}$")
            self.assertTrue(source.url.startswith("https://raw.githubusercontent.com/"))
            self.assertIn(source.commit, source.url)

    def test_offline_missing_source_never_uses_network(self):
        with tempfile.TemporaryDirectory() as temporary:
            with mock.patch.object(builder.urllib.request, "urlopen") as request:
                with self.assertRaisesRegex(builder.BuildError, "Offline source missing"):
                    builder.load_sources(Path(temporary), offline=True)
                request.assert_not_called()

    def test_corrupt_cache_is_rejected_before_network(self):
        with tempfile.TemporaryDirectory() as temporary:
            (Path(temporary) / builder.SOURCES[0].filename).write_bytes(b"corrupt")
            with mock.patch.object(builder.urllib.request, "urlopen") as request:
                with self.assertRaisesRegex(builder.BuildError, "SHA-256 mismatch"):
                    builder.load_sources(Path(temporary))
                request.assert_not_called()

    def test_download_verified_once_then_offline_cache(self):
        data = b"test source\n"
        source = builder.Source("fixture.txt", "example/data", "0" * 40, "fixture.txt",
                                hashlib.sha256(data).hexdigest(), "MIT")
        with tempfile.TemporaryDirectory() as temporary:
            with mock.patch.object(builder, "SOURCES", (source,)):
                with mock.patch.object(builder.urllib.request, "urlopen", return_value=io.BytesIO(data)) as request:
                    self.assertEqual(builder.load_sources(Path(temporary)), {"fixture.txt": "test source\n"})
                    request.assert_called_once()
                with mock.patch.object(builder.urllib.request, "urlopen") as request:
                    self.assertEqual(builder.load_sources(Path(temporary), offline=True),
                                     {"fixture.txt": "test source\n"})
                    request.assert_not_called()

    def test_bad_download_is_not_cached(self):
        with tempfile.TemporaryDirectory() as temporary:
            with mock.patch.object(builder.urllib.request, "urlopen", return_value=io.BytesIO(b"wrong")):
                with self.assertRaisesRegex(builder.BuildError, "SHA-256 mismatch"):
                    builder.load_sources(Path(temporary))
            self.assertEqual(list(Path(temporary).iterdir()), [])


class ArtifactTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = builder.ROOT / "Dict_zhCN.lua"
        cls.data = cls.path.read_bytes()
        cls.text = cls.data.decode("utf-8")
        header, body = cls.text.split("CK.ZIRANMA_DICT = {\n")
        if not body.endswith("}\n"):
            raise AssertionError("Missing dictionary table terminator")
        cls.dictionary = {}
        for line in body[:-2].splitlines():
            match = re.fullmatch(r'    \["([a-z]+)"\] = "([^"\\]+)",', line)
            if not match:
                raise AssertionError(f"Nonliteral dictionary row: {line[:100]}")
            if match[1] in cls.dictionary:
                raise AssertionError(f"Duplicate code {match[1]}")
            cls.dictionary[match[1]] = match[2].split(" ")
        cls.header = header

    def test_contract_coverage_and_metadata(self):
        stats = builder.validate_dictionary(self.dictionary)
        for key in ("characters", "phrases", "candidates", "entries", "codes", "wow_terms"):
            self.assertIn(f"    {key} = {stats[key]},", self.header)
        self.assertGreaterEqual(stats["characters"], 6000)
        self.assertGreaterEqual(stats["phrases"], 20000)
        self.assertGreater(max(map(len, self.dictionary.values())), 200)
        self.assertIn("龘", self.dictionary["da"])
        self.assertIn("〇", self.dictionary["ly"])
        self.assertIn("嗯", self.dictionary["en"])
        self.assertEqual(list(self.dictionary), sorted(self.dictionary))
        self.assertNotIn(b"\r", self.data)
        self.assertFalse(self.data.startswith(b"\xef\xbb\xbf"))
        self.assertIn("local _, CK = ...\n", self.header)
        self.assertIn('encoding = "ziranma"', self.header)

    def test_all_gb2312_common_characters_retained(self):
        expected = set()
        for lead in range(0xB0, 0xF8):
            for trail in range(0xA1, 0xFF):
                try:
                    character = bytes((lead, trail)).decode("gb2312")
                except UnicodeDecodeError:
                    continue
                if builder.is_han(character):
                    expected.add(character)
        actual = {word for words in self.dictionary.values() for word in words if len(word) == 1}
        self.assertEqual(len(expected), 6763)
        self.assertEqual(expected - actual, set())

    def test_required_chat_words_with_independent_codes(self):
        examples = {
            "你好": "nihk", "谢谢": "xxxx", "组队": "zudv", "副本": "fubf",
            "治疗": "vilc", "坦克": "tjke", "任务": "rfwu", "拍卖行": "plmlhh",
            "魔兽世界": "moubuijx", "集合": "jihe", "加血": "jwxt",
            "拉怪": "lagy", "没蓝": "mzlj", "等一下": "dgyixw", "辛苦了": "xnkule",
        }
        for word, code in examples.items():
            with self.subTest(word=word):
                self.assertIn(word, self.dictionary.get(code, []))

    def test_frequent_candidates_and_polyphonic_words(self):
        self.assertEqual(self.dictionary["ni"][0], "你")
        self.assertEqual(self.dictionary["de"][0], "的")
        self.assertEqual(self.dictionary["nihk"][0], "你好")
        examples = {"银行": "ynhh", "音乐": "ynyt", "重庆": "isqy", "长大": "vhda",
                    "了解": "lcjx", "还给": "hrgz", "女儿": "nver", "绿色": "lvse"}
        for word, code in examples.items():
            with self.subTest(word=word):
                self.assertIn(word, self.dictionary.get(code, []))

    def test_validator_rejects_bad_frequency_order(self):
        broken = {"ni": ["尼", "你"]}
        with self.assertRaisesRegex(builder.BuildError, "not ordered by frequency"):
            builder.validate_dictionary(broken, {"你": 100, "尼": 1})

    def test_lua51_load_when_available(self):
        try:
            from lupa.lua51 import LuaRuntime
        except ImportError:
            self.skipTest("optional MIT-licensed lupa.lua51 is not installed")
        lua = LuaRuntime(unpack_returned_tuples=True)
        load = lua.eval("function(text, CK) local f, err = loadstring(text, '@Dict_zhCN.lua'); "
                        "assert(f, err); f('EasyController', CK); return CK end")
        namespace = load(self.text, lua.table())
        actual = {key: value.split(" ") for key, value in namespace.ZIRANMA_DICT.items()}
        self.assertEqual(actual, self.dictionary)
        self.assertEqual(namespace.ZIRANMA_SOURCES.phrases,
                         sum(len(word) > 1 for words in actual.values() for word in words))


if __name__ == "__main__":
    unittest.main()
