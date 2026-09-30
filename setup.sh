#!/bin/sh
# Strata for Linux: the first run installs everything and starts the model; later runs just start it.
# Needs only an NVIDIA driver (or, experimental: an AMD RX 7900 XT/XTX with the amdgpu driver, see docs/AMD_HIP.md).
# Python (with venv) is installed through apt/dnf if it is missing (asks for sudo).
cd "$(dirname "$0")" || exit 1
# Python 3.10+ that can make a venv WITH pip: Debian/Ubuntu ship `venv` without `ensurepip` (that is the separate
# python3-venv package), and a venv made without it has no pip
ok_py() { "$1" -c 'import sys, venv, ensurepip; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; }
# a .venv from an earlier run that failed half-way has a python but no pip: start it again
if [ -x .venv/bin/python ] && ! .venv/bin/python -c 'import sys' >/dev/null 2>&1; then
  echo "The copied Python environment does not work on this PC. Creating a new one ..."
  rm -rf .venv
fi
if [ -x .venv/bin/python ] && ! .venv/bin/python -m pip --version >/dev/null 2>&1; then
  rm -rf .venv
fi
offline=0
exporting=0
for a in "$@"; do
  case "$a" in
    --offline|--bundle|--bundle=*) offline=1 ;;
    --export-offline|--export-offline=*) exporting=1; offline=0 ;;
  esac
done
# A copied pack at ./offline means this PC has no internet, same as START-HERE.bat. Exporting must stay online.
if [ "$exporting" = 0 ] && [ -f offline/OFFLINE.json ]; then
  offline=1
  case " $* " in
    *" --offline "*|*" --bundle "*|*" --bundle="*) ;;
    *) set -- --offline "$@" ;;
  esac
fi
if [ "$offline" = 1 ]; then
  py312=""
  for c in python3.12 python3 python; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(0 if sys.version_info[:2]==(3, 12) else 1)' 2>/dev/null; then
      py312=$c
      break
    fi
  done
  if [ -z "$py312" ]; then
    echo "Offline mode needs Python 3.12 (the pack's wheels are built for it)."
    echo "Windows: START-HERE.bat installs it from offline/python. Linux: install Python 3.12 from this PC's package archive, then run ./setup.sh again."
    exit 1
  fi
fi
if [ "$offline" = 1 ] && [ -x .venv/bin/python ] && ! .venv/bin/python -c 'import sys; sys.exit(0 if sys.version_info[:2]==(3, 12) else 1)' 2>/dev/null; then
  echo "This offline pack needs a Python 3.12 environment. Creating it again ..."
  rm -rf .venv
fi
if [ ! -x .venv/bin/python ]; then
  if [ "$offline" = 1 ]; then
    PY=$py312
  else
    PY=""
    for c in python3 python; do
      if command -v $c >/dev/null 2>&1 && ok_py $c; then
        PY=$c; break
      fi
    done
    if [ -z "$PY" ]; then
      echo "Python 3.10+ with venv is needed; installing it (sudo will ask for your password) ..."
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y python3 python3-venv python3-pip
      elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y python3 python3-pip
      elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm python python-pip
      fi
      PY=python3
      if ! ok_py $PY; then
        echo "Please install Python 3.10 or newer with venv (Ubuntu/Debian: sudo apt install python3-venv), then run"
        echo "./setup.sh again."
        exit 1
      fi
    fi
  fi
  # a private environment inside this folder (system Python stays untouched; newer distros refuse global pip)
  $PY -m venv .venv || { rm -rf .venv; echo "could not create .venv: sudo apt install python3-venv"; exit 1; }
fi
exec .venv/bin/python setup.py "$@"
