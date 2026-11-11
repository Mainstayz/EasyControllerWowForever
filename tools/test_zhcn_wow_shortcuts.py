"""Validate the hand-maintained WoW shortcuts, including silent Lua key collisions."""
import json
from pathlib import Path
import re
import unittest

from build_ziranma_dict import is_han
import package

ROOT = Path(__file__).resolve().parent.parent
PATH = ROOT / "Dict_zhCN_WoW.lua"


def read_shortcuts():
    text = PATH.read_text(encoding="utf-8")
    body = text.split("CK.ZHCN_WOW_SHORTCUTS = {\n", 1)[1]
    if not body.endswith("}\n"):
        raise AssertionError("Missing shortcut table terminator")
    shortcuts = {}
    for line in body[:-2].splitlines():
        if not line.strip() or line.lstrip().startswith("--"):
            continue
        match = re.fullmatch(r'    \["([a-z]{2,32})"\] = "([^"\\]+)",', line)
        if not match:
            raise AssertionError(f"Invalid literal shortcut row: {line}")
        code, value = match.groups()
        if code in shortcuts:
            raise AssertionError(f"Duplicate shortcut code: {code}")
        words = value.split(" ")
        if len(words) != len(set(words)) or not all(is_han(word) for word in words):
            raise AssertionError(f"Invalid/duplicate shortcut candidates: {code}")
        shortcuts[code] = words
    return shortcuts


class ShortcutDataTests(unittest.TestCase):
    def test_format_and_coverage(self):
        shortcuts = read_shortcuts()
        self.assertGreaterEqual(len(shortcuts), 200)
        self.assertTrue(any(len(code) == 3 for code in shortcuts))
        self.assertTrue(any(len(code) > 4 for code in shortcuts))
        self.assertNotIn(b"\r", PATH.read_bytes())
        self.assertFalse(PATH.read_bytes().startswith(b"\xef\xbb\xbf"))

    def test_requested_classes_dungeons_and_ambiguities(self):
        shortcuts = read_shortcuts()
        examples = {
            "ss": "术士", "zs": "战士", "fs": "法师", "ms": "牧师",
            "lr": "猎人", "dz": "盗贼", "qs": "圣骑士", "sm": "萨满",
            "xd": "德鲁伊", "ws": "武僧", "dk": "死亡骑士",
            "dh": "恶魔猎手", "hms": "唤魔师", "ah": "哀嚎洞穴",
            "ny": "怒焰裂谷", "xs": "血色修道院", "mld": "玛拉顿",
            "stsm": "斯坦索姆", "klz": "卡拉赞", "bwl": "黑翼之巢",
            "naxx": "纳克萨玛斯", "icc": "冰冠堡垒", "jhs": "集合石",
            "dd": "打断", "dmj": "大秘境", "zbhl": "准备好了",
            "swkj": "死亡矿井", "aqlfx": "安其拉废墟", "aqlsd": "安其拉神殿",
        }
        for code, word in examples.items():
            with self.subTest(code=code):
                self.assertEqual(shortcuts[code][0], word)
        self.assertIn("怒焰峡谷", shortcuts["ny"])
        self.assertIn("能源舰", shortcuts["ny"])
        self.assertIn("拍卖行", shortcuts["ah"])
        self.assertIn("太阳之井高地", shortcuts["sw"])
        self.assertIn("魔枢", shortcuts["ms"])
        self.assertIn("毁灭术", shortcuts["hms"])
        self.assertIn("闪电大厅", shortcuts["sd"])

    def test_game_emulator_and_release_load_the_shortcuts(self):
        toc = (ROOT / "EasyController.toc").read_text(encoding="utf-8")
        runtime = [line.strip().replace("\\", "/") for line in toc.splitlines()
                   if line.strip() and not line.startswith("#")]
        self.assertLess(runtime.index(PATH.name), runtime.index("ChineseInput.lua"))
        config = json.loads((ROOT / "wowlua.json").read_text(encoding="utf-8"))
        self.assertEqual(config["build"]["load-order"].count(PATH.name), 1)
        self.assertLess(config["build"]["load-order"].index(PATH.name),
                        config["build"]["load-order"].index("ChineseInput.lua"))
        self.assertIn("docs/zhCN-wow-shortcuts.md", package.EXTRA)


if __name__ == "__main__":
    unittest.main()
