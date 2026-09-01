#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-v0.1.1}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${ROOT_DIR}/application/edge_agent/build"
OUT_DIR="${ROOT_DIR}/application/edge_agent/releases/esp32_steamakers_ai/${VERSION}"
IMAGE_NAME="esp-claw-steamakers-ai-${VERSION}.bin"

if [[ -z "${IDF_PATH:-}" ]]; then
    echo "Error: exporta primer l'entorn d'ESP-IDF 5.5.4." >&2
    exit 1
fi

for file in \
    bootloader/bootloader.bin \
    partition_table/partition-table.bin \
    ota_data_initial.bin \
    edge_agent.bin \
    system.bin \
    storage.bin; do
    if [[ ! -f "${BUILD_DIR}/${file}" ]]; then
        echo "Error: falta ${BUILD_DIR}/${file}; executa idf.py build." >&2
        exit 1
    fi
done

mkdir -p "${OUT_DIR}"

python -m esptool --chip esp32s3 merge_bin \
    --flash_mode dio --flash_freq 80m --flash_size 16MB \
    --output "${OUT_DIR}/${IMAGE_NAME}" \
    0x0 "${BUILD_DIR}/bootloader/bootloader.bin" \
    0x9000 "${BUILD_DIR}/partition_table/partition-table.bin" \
    0x10000 "${BUILD_DIR}/ota_data_initial.bin" \
    0x20000 "${BUILD_DIR}/edge_agent.bin" \
    0xa20000 "${BUILD_DIR}/system.bin" \
    0xcaa000 "${BUILD_DIR}/storage.bin"

(
    cd "${OUT_DIR}"
    shasum -a 256 "${IMAGE_NAME}" > SHA256SUMS.txt
)

echo "Paquet generat a ${OUT_DIR}"
