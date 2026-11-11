# 中文词库数据许可、来源与复现

本文件的构建、完整双拼编码和统计规则适用于 `Dict_zhCN.lua`。
独立的国服游戏简写表 `Dict_zhCN_WoW.lua` 由项目维护，按主项目 MIT License 提供；
其词表范围、公开参考来源和名称处理见 [国服魔兽常用语简写](docs/zhCN-wow-shortcuts.md)。
简写不会混入下面的通用双拼数据，也不参与其构建摘要。

`Dict_zhCN.lua` 是离线构建的数据文件，适用 **CC-BY-SA-4.0**：
<https://creativecommons.org/licenses/by-sa/4.0/>，法律文本：
<https://creativecommons.org/licenses/by-sa/4.0/legalcode>。
分发这份数据及其修改版本时须保留作者和来源说明、许可链接以及修改说明；
修改后再分发的数据适用该许可的相同方式共享条款。请将本文件随数据一起分发。

`tools/build_ziranma_dict.py` 和 `tools/test_ziranma_dict.py` 是项目新增代码，
按主项目的 MIT License 提供。项目编写的游戏短语和少量读音修正作为输入也按 MIT 提供；
合成的数据成品按上述 CC-BY-SA-4.0 分发。主项目根目录 `LICENSE` 保持原样。
下面分别保留两份 mozillazg 数据的完整 MIT 声明。

## 署名及修改说明

- 单字读音：**mozillazg / pinyin-data**，`pinyin.txt`，文件内版本 `0.16.0`，MIT。
  <https://github.com/mozillazg/pinyin-data>
- 词组读音：**mozillazg / phrase-pinyin-data**，`large_pinyin.txt`，文件内版本 `0.20.0`，MIT。
  <https://github.com/mozillazg/phrase-pinyin-data>
- 中文词语及频次：**Hermit Dave / FrequencyWords**，`content/2018/zh_cn/zh_cn_50k.txt`，
  来自 OpenSubtitles 2018 / OPUS，内容为 CC-BY-SA-4.0。
  <https://github.com/hermitdave/FrequencyWords>，原始语料链接见该仓库 README：
  <http://opus.nlpl.eu/OpenSubtitles2018.php>。
  FrequencyWords 根目录的 MIT `LICENSE` 针对代码；所用**内容**的 CC-BY-SA-4.0 声明
  来自下面固定提交的 README。本工具没有使用它的生成代码。

本项目对数据的修改：过滤为不含空格的纯汉字词条；去掉拼音声调；保留 `ü` 为 `v`；
优先使用整词和词组片段读音处理多音字；转换成完整双拼编码；按原始出现次数排序；
补充 125 条有明确读音的 WoW/聊天常用语；加入 `嗯=en` 的输入法拼写修正。
没有引入 GPL 代码。构建器只使用 Python 标准库，运行游戏插件不需要 Python 或网络。

## 固定来源和校验摘要

构建器固定到完整 Git 提交，不读取分支最新内容。以下摘要均为**下载原始字节**的 SHA-256。
数据及许可证据共 6 个文件都必须通过校验；已存在的缓存也会重新校验。
若缓存损坏，请移走该缓存文件后重新在线下载；离线模式不会下载或接受损坏文件。

### `pinyin.txt`

- 仓库：<https://github.com/mozillazg/pinyin-data>
- 提交：`fe29ad32bdf352b31a02b9936e537f575432e9a6`
- 仓库内路径：`pinyin.txt`
- 缓存文件名：`pinyin.txt`；字节数：`985559`
- 许可/证据：MIT
- SHA-256：`2342a6f98c85dbc3c8d26aef31744876a36326c6466e51e9a0f16898c36c2011`
- 固定下载地址：<https://raw.githubusercontent.com/mozillazg/pinyin-data/fe29ad32bdf352b31a02b9936e537f575432e9a6/pinyin.txt>

### `pinyin-data.LICENSE`

- 仓库：<https://github.com/mozillazg/pinyin-data>
- 提交：`fe29ad32bdf352b31a02b9936e537f575432e9a6`
- 仓库内路径：`LICENSE`
- 缓存文件名：`pinyin-data.LICENSE`；字节数：`1076`
- 许可/证据：MIT
- SHA-256：`9c048697be2502a16e8bcb282d5d465a07295b2def0ffb05a269c5d39dbe1586`
- 固定下载地址：<https://raw.githubusercontent.com/mozillazg/pinyin-data/fe29ad32bdf352b31a02b9936e537f575432e9a6/LICENSE>

### `large_pinyin.txt`

- 仓库：<https://github.com/mozillazg/phrase-pinyin-data>
- 提交：`4afa3226ce53c9138b939e83c3bb294dbe0da511`
- 仓库内路径：`large_pinyin.txt`
- 缓存文件名：`large_pinyin.txt`；字节数：`9148802`
- 许可/证据：MIT
- SHA-256：`7e34c0e09ad398a7a07c0964bebb9677ace2114ed9d1c2ccdfce939102db2134`
- 固定下载地址：<https://raw.githubusercontent.com/mozillazg/phrase-pinyin-data/4afa3226ce53c9138b939e83c3bb294dbe0da511/large_pinyin.txt>

### `phrase-pinyin-data.LICENSE`

- 仓库：<https://github.com/mozillazg/phrase-pinyin-data>
- 提交：`4afa3226ce53c9138b939e83c3bb294dbe0da511`
- 仓库内路径：`LICENSE`
- 缓存文件名：`phrase-pinyin-data.LICENSE`；字节数：`1066`
- 许可/证据：MIT
- SHA-256：`89ac55df747e4776088c3e77531ef61b973a1a59dd8e6a4548a58996da9a4f70`
- 固定下载地址：<https://raw.githubusercontent.com/mozillazg/phrase-pinyin-data/4afa3226ce53c9138b939e83c3bb294dbe0da511/LICENSE>

### `zh_cn_50k.txt`

- 仓库：<https://github.com/hermitdave/FrequencyWords>
- 提交：`525f9b560de45753a5ea01069454e72e9aa541c6`
- 仓库内路径：`content/2018/zh_cn/zh_cn_50k.txt`
- 缓存文件名：`zh_cn_50k.txt`；字节数：`565895`
- 许可/证据：CC-BY-SA-4.0
- SHA-256：`25599e00347b893e55c3058a748819b3fe19403291cd12f7c03af128e7f3fe45`
- 固定下载地址：<https://raw.githubusercontent.com/hermitdave/FrequencyWords/525f9b560de45753a5ea01069454e72e9aa541c6/content/2018/zh_cn/zh_cn_50k.txt>

### `FrequencyWords.README.md`

- 仓库：<https://github.com/hermitdave/FrequencyWords>
- 提交：`525f9b560de45753a5ea01069454e72e9aa541c6`
- 仓库内路径：`README.md`
- 缓存文件名：`FrequencyWords.README.md`；字节数：`913`
- 许可/证据：License evidence: content is CC-BY-SA-4.0; code is MIT
- SHA-256：`a92fcc50e27f7b2d5860ec1c1ce794dc4c892d945bfa4c8c3136cdfd213ee710`
- 固定下载地址：<https://raw.githubusercontent.com/hermitdave/FrequencyWords/525f9b560de45753a5ea01069454e72e9aa541c6/README.md>

## 编码、排序及覆盖规则

本文件遵循标准自然码双拼：`zh=v, ch=i, sh=u`，其余声母原样；
韵母 `a/e/o/i/u/v` 使用原键，其余如下。

| 韵母 | 键 | 韵母 | 键 | 韵母 | 键 |
| --- | --- | --- | --- | --- | --- |
| ai | l | an | j | ang | h |
| ao | k | ei | z | en | f |
| eng | g | er/uan | r | ong/iong | s |
| ou | b | ia/ua | w | ie | x |
| iao | c | ian | m | iang/uang | d |
| in | n | ing | y | iu | q |
| un | p | ue/ve | t | ui | v |
| uo | o | uai | y | | |

韵母采用自然码的 `ing=y`、`un=p`、`uai=y`，成品元数据标记为 `ziranma`。
例如“重庆”为 `isqy`，“军事”为 `jpui`。构建器、编码回归测试和键位说明使用同一套标准映射。

零声母分别为 `a=aa,o=oo,e=ee,ai=ai,an=an,ao=ao,ang=ah,ei=ei,en=en,eng=eg,er=er,ou=ou`。
`yi/ya/wo/yu` 等保留 `y/w` 声母，`lv/nv` 使用 `v`。每个汉字对应两个 ASCII 字母，
词语使用完整逐字编码；`Dict_zhCN.lua` 不含首字母简拼、单键缩写或运行时索引构建。
例如“你好”为 `nihk`，“拍卖行”为 `plmlhh`，“加血”为 `jwxt`。

单字保留上游第一个可编码读音，没有按候选数、Unicode 基本区或词频截断生僻字；
扩展区汉字和异体字也保留。词语优先整词读音，其次使用上下文片段，最后单字读音。
片段分解先减少孤立单字，再减少片段数，并优先更长的左侧片段。
“银行、音乐、长大、重庆、了解、还给”等多音词有独立测试。
儿化等不满足“一个汉字一个音节”的整词读音不直接采用，改用可编码片段和单字。
`zh_cn` 词频表以简体中文为主；本构建没有另行做繁简转换，源中的少量繁体/异体形式仍保留。

候选按**词条自身的原始出现次数降序**排列。词频相同按 Unicode 码位顺序排列，
使不同 Python 版本/系统的结果稳定；没有按拼音字母顺序重排高频词。
无词频记录的单字频次视为 0；缺少语料词频的游戏词频次取 1，已有词频保持原值。
原表重复词条取最大频次，不重复累计。不按候选数截断；最长单字候选串含 810 个字。

固定来源包含 44,440 条单字读音，其中 70 条是私用区码位（`U+E815` 至 `U+E864` 内），
无法用通用 Unicode 字体确定字形，予以过滤。还有 3 个字符只有契约无法编码的读音：
`㕶`（`ň,ňg`）、`瓲`（`túnwǎ`）、`𠮾`（`ǹ,ǹg`）。构建 JSON 会明确报告这些例外。
`嗯` 的上游读音也是 `n/ng`，采用常用输入法拼写 `en` 保留。
其他可编码汉字全部保留，GB2312 的 6,763 个汉字全部覆盖。
固定词频表的 38,883 条纯中文多字词全部成功编码，额外加入 56 条原表没有的游戏/聊天词。

## 成品统计

| 项目 | 数值 |
| --- | ---: |
| 不同单字 | 44,367 |
| 不同多字词/短语 | 38,939 |
| 不同候选合计 | 83,306 |
| 完整编码键 | 29,982 |
| 显式 WoW/聊天常用语 | 125（已包括在词数内） |
| 整词读音（含游戏修正） | 24,655 |
| 片段/单字补足读音 | 14,284 |
| 无法编码的词语 | 0 |
| UTF-8 文件大小 | 1,072,551 字节（约 1.023 MiB） |

成品 `Dict_zhCN.lua` 的 SHA-256：
`8ac7068c0b2eb050f3c360d7ce44dc06e7c68fc9e1e01db4b762690d7e15183b`。
文件为无 BOM 的 UTF-8、固定 LF 换行，不含生成时间或机器路径；同版本工具及上述输入
可逐字节复现。`CK.ZIRANMA_SOURCES` 记录来源、提交、摘要、编码版本及字词数。
`CK.ZIRANMA_DICT` 直接包含 `完整编码 -> 空格分隔候选`，加载时没有额外转换步骤。

## 复现与验证

需要 Python 3.10 或更高版本。以下命令在仓库根目录运行。
首次联网构建会下载并校验上列 6 个文件，默认缓存为
`tempfile.gettempdir()/easycontroller-ziranma-sources`（Windows 通常在 `%TEMP%` 下）。
不安装任何构建依赖：

```powershell
python -B -X utf8 tools/build_ziranma_dict.py
```

使用 `--cache-dir "C:\Temp\ziranma-sources"` 可指定持久缓存；此参数在后续命令中保持一致。
下载地址和缓存文件名已在上面逐项列出，也可在另一台机器下载原始文件并按缓存名复制。
准备好六个校验通过的缓存文件后，可完全断网重建：

```powershell
python -B -X utf8 tools/build_ziranma_dict.py --offline
```

验证重新构建的字节与现有成品一致、但不改写成品：

```powershell
python -B -X utf8 tools/build_ziranma_dict.py --offline --check
```

可用 `--output "C:\Temp\Dict_zhCN.lua"` 将重建结果写到临时目录。
构建及检查都会输出字数、词数、未编码例外、文件字节数和 SHA-256 的 JSON；
来源缺失、摘要不匹配、编码异常或覆盖量不足都会以非零退出码失败。

执行离线测试：

```powershell
python -B -X utf8 -m unittest discover -s tools -p test_ziranma_dict.py -v
```

测试覆盖零声母、声韵母映射、声调及 `ü`、整词/片段多音读音、过滤规则、
缓存下载与摘要拒绝、完全离线行为、频率排序、候选格式和去重、全部 GB2312 汉字、
最低覆盖量、15 条要求的聊天语以及 125 条显式游戏词。

本次还使用临时安装的 **Lupa 2.8（MIT，捆绑 Lua 亦为 MIT）** 实际运行 Lua 5.1
`loadstring`，传入插件的 `...` 参数并逐条比对整个字典。可选复现命令如下：

```powershell
python -m pip install --only-binary=:all: --no-deps --target "$env:TEMP\easycontroller-ziranma-validation" lupa==2.8
$env:PYTHONPATH = "$env:TEMP\easycontroller-ziranma-validation"
python -B -X utf8 -m unittest discover -s tools -p test_ziranma_dict.py -v
```

18 项测试全部通过，包含 Lua 5.1 加载检查；没有 Lupa 时仅跳过实际 Lua 加载这 1 项，
其余测试不需要第三方库。没有安装到游戏或发布成品。

## 保留的上游 MIT 声明

以下原文来自已固定并校验的两份 LICENSE。

### mozillazg/pinyin-data

```text
The MIT License (MIT)

Copyright (c) 2016 mozillazg

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### mozillazg/phrase-pinyin-data

```text
MIT License

Copyright (c) 2017 mozillazg

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
