# 在 VS Code 中验证 EasyController

项目已配好 wowlua 客户端模拟器、断点启动项和测试任务。这里的客户端版本是 **WoW Forever / camelot / Interface 16001**。

本机已验证的工具是 VS Code 扩展 `wowlua.wowlua 0.12.0` 和命令行程序 `wowlua 0.13.10`。命令行程序位于 `C:\Users\Pillar\.wowlua\bin\wowlua.exe`，工作区的 `.vscode/settings.json` 已设置该路径。其他电脑需要将 `wowlua.path` 改为自己的可执行文件位置。

## 打开可以点击的键盘界面

1. VS Code 用“文件 → 打开文件夹”打开整个 `EasyControllerWowForever` 仓库。
2. `Ctrl+Shift+P` 执行 **Developer: Reload Window**，使扩展读取新配置。
3. 打开“运行和调试”（`Ctrl+Shift+D`），选择 **EasyController: emulator (WoW Forever)**，按 **F5**。
4. 右侧会打开 **wowlua: UI**。若没有，`Ctrl+Shift+P` 执行 **wowlua: Show UI**。
5. 打开“调试控制台”（`Ctrl+Shift+Y`），逐行执行下面的 Lua：

```lua
ControllerKeyboard.Guide:SetSeen()
ControllerKeyboard.Config:Close("preview")
ControllerKeyboard:SetChineseInput("ziranma")
ControllerKeyboard:SetInputMethod("stick")
ControllerKeyboard:OpenStandalone()
```

前两行收起首次引导，随后启用自然码并打开双摇杆键盘。界面上的字母、候选、翻页、中 / EN、ABC、退格等按钮均可点击。在调试控制台执行的指令只作用于模拟器中的插件。

在键盘上依次点 **n、i、h、k**，编码应显示 `ni hk`，第一候选应为 **你好**。点“你好”，上方消息栏出现中文，编码栏清空；选字不会发送。还可以点中 / EN、ABC、左右翻页，检查标点与退格。

也可以从调试控制台一次输入编码：

```lua
for ch in ("nihk"):gmatch(".") do ControllerKeyboard:TypeChar(ch) end
```

调试控制台支持以 `/` 开头的游戏命令，例如 `/ec ime ziranma`、`/ec mode stick`。以上 `OpenStandalone()` 路径用于直接查看插件键盘；游戏内聊天框的打开、关闭及频道操作可以另行验证。

本次界面截图保存为 `dist/chinese-input-vscode.png`，可以在 VS Code 中直接打开。

## 运行已配置的测试

`Ctrl+Shift+P` → **Tasks: Run Task**，选择以下任务：

| 任务                                        | 验证内容                                                       |
| ------------------------------------------- | -------------------------------------------------------------- |
| EasyController: wowlua check                | 项目清单、加载配置和源代码检查                                 |
| EasyController: wowlua emulator tests       | 加载完整插件及 Blizzard UI，运行 6 项界面 / 输入测试并生成截图 |
| EasyController: Lua 5.1 regressions         | 117 项 Lua 回归及 49 个运行时 Lua 文件的语法检查               |
| EasyController: Python and dictionary tests | 22 项发布和中文词库测试                                        |

wowlua 模拟器测试覆盖：键盘打开、触屏式候选点击、手柄 A 先选字不发送、B 取消编码并保留文字、中英文切换和截图。

VS Code 左侧“测试”视图也会发现 `tests/chinese-input.test.wowlua`，可以点 **Run Test** 或 **Debug Test**。现有 `tools/test_*.lua` 使用项目自己的 Lua 5.1 运行器，从任务菜单运行。

如果从集成终端执行，请在仓库根目录使用：

```powershell
& "$env:USERPROFILE\.wowlua\bin\wowlua.exe" check
& "$env:USERPROFILE\.wowlua\bin\wowlua.exe" test --flavor camelot
uv run --no-project --python 3.12 --with lupa python tools/run_lua_tests.py
uv run --no-project --python 3.12 --with lupa python -B -X utf8 -m unittest discover -s tools -p 'test_*.py' -v
```

## 下断点看选字过程

在这些函数的第一条执行语句左侧单击，添加断点：

- `Message.lua` → `CK:TypeChar`：输入一个字母，追踪组词刷新。
- `ChineseIME.lua` → `I:Commit`：选择候选，查看消费的编码和剩余编码。
- `ChineseInput.lua` → `CK:AcceptIMECandidate`：查看中文如何进入消息缓冲区。
- `Input.lua` → `CK:PrepareSend`：查看 A 选字与发送之间的处理。

使用 **EasyController: emulator (WoW Forever)** 启动后，在 UI 点击对应按钮便会命中断点。也可以选 **EasyController: debug Chinese input test** 启动自动化测试。暂停后，按 F10 单步跳过、F11 进入函数、F5 继续。

推荐添加到“监视”的表达式：

```lua
ControllerKeyboard:GetText()
ControllerKeyboard.ChineseIME:GetCode()
ControllerKeyboard.state.suggestions
ControllerKeyboard.state.selected
ControllerKeyboard.imePage
ControllerKeyboard.imeSendHandled
```

## 工具与实际游戏的验证范围

wowlua 在独立进程中模拟客户端，可加载本机游戏的 Blizzard UI、字体和纹理。本次已经成功加载 WoW Forever 1.60.1 的界面，6 项模拟器测试通过，并实际生成、检查了中文候选截图。

模拟器里鼠标点击可验证触屏点按所调用的按钮逻辑，`mock.pressKey` 可验证手柄按键绑定。掌机真实摇杆、触屏驱动映射以及实际服务器下的战斗保护仍应进入游戏验证。

工作区配置通过 `build.src: "."` 沿用仓库现有文件结构和加载顺序；模拟器产物位于 `dist/wowlua/`。安装包继续由 `tools/package.py` 生成。

如果 F5 启动报找不到 `wowlua`，检查工作区设置里的 `wowlua.path`；若界面没有自动出现，执行 **wowlua: Show UI**。第一次运行会从本机游戏安装中提取 Blizzard UI、字体或纹理，耗时会比后续运行长。
