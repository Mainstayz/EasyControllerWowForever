"""Run the addon's Lua 5.1 regressions and check runtime-file syntax.

Use a system Lua 5.1 interpreter, or the optional Lupa development dependency:
    uv run --no-project --python 3.12 --with lupa python tools/run_lua_tests.py
No Python dependency is needed by the addon or its release package.
"""
import json
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main():
    os.chdir(ROOT)
    tests = sorted((ROOT / "tools").glob("test_*.lua"))
    toc = (ROOT / "EasyController.toc").read_text(encoding="utf-8")
    files = [line.strip().replace("\\", "/") for line in toc.splitlines()
             if line.strip() and not line.startswith("#") and line.strip().endswith(".lua")]
    interpreter = shutil.which("lua5.1") or shutil.which("lua51")
    if interpreter:
        chunk = "for _, p in ipairs({" + ",".join(map(json.dumps, files)) + "}) do assert(loadfile(p)) end"
        subprocess.run([interpreter, "-e", chunk], check=True)
        print(f"Lua 5.1 syntax: {len(files)} runtime files passed", flush=True)
        for test in tests:
            subprocess.run([interpreter, test.as_posix()], check=True)
        return
    try:
        from lupa.lua51 import LuaRuntime
    except ImportError as error:
        raise SystemExit("Lua 5.1 or Lupa is required; see the command in tools/run_lua_tests.py") from error
    runtime = LuaRuntime(unpack_returned_tuples=True)
    compile_file = runtime.eval("function(path) local f, err = loadfile(path); assert(f, err) end")
    for filename in files:
        compile_file(filename)
    print(f"Lua 5.1 syntax: {len(files)} runtime files passed", flush=True)
    for test in tests:
        print(f"\nRunning {test.relative_to(ROOT).as_posix()}", flush=True)
        runtime = LuaRuntime(unpack_returned_tuples=True)
        runtime.execute(test.read_text(encoding="utf-8"), name=test.name)
        runtime.execute("io.flush()")
    print(f"\nAll {len(tests)} Lua regression scripts passed", flush=True)


if __name__ == "__main__":
    main()
