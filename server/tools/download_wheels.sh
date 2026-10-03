#!/usr/bin/env bash
# Downloads every Python package the server needs into server/wheels/,
# so "docker compose build" can install them WITHOUT internet.
#
# The connection to PyPI is slow in Iran: just run this script again if it
# stops - files that are already downloaded are skipped.
#
#   ./tools/download_wheels.sh                       # from pypi.org
#   PIP_INDEX_URL=https://some-mirror/simple ./tools/download_wheels.sh
#   HTTPS_PROXY=http://127.0.0.1:10809 ./tools/download_wheels.sh   # through your VPN
set -e
cd "$(dirname "$0")/.."
INDEX=${PIP_INDEX_URL:-https://pypi.org/simple}
echo "Downloading into wheels/ from $INDEX ..."
python3 -m pip download -r requirements.txt -d wheels \
  --only-binary=:all: \
  --platform manylinux2014_x86_64 --platform manylinux_2_17_x86_64 --platform manylinux_2_28_x86_64 \
  --python-version 3.12 --implementation cp --abi cp312 --abi abi3 --abi none \
  --timeout 300 --retries 20 \
  -i "$INDEX"
echo
echo "Done: $(ls wheels/*.whl | wc -l) packages in wheels/. Now run:  docker compose build api"
