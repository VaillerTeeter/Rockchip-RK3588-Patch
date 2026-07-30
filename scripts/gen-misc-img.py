#!/usr/bin/env python3
"""
Generate misc.img for Rockchip RK3588 Android.

The misc partition stores the Android bootloader_message structure,
used by bootloader/recovery to communicate boot commands.

Partition layout (48KB = 0xC000):
  0x000000 - 0x003FFF  (16KB): bootloader_message_ab slot 0
  0x004000 - 0x007FFF  (16KB): bootloader_message_ab slot 1 (backup copy)
  0x008000 - 0x00BFFF  (16KB): reserved / zeros

Each slot layout:
  0x0000  command[32]     "boot-recovery" or "boot-once" etc.
  0x0020  status[32]      "OKAY" / "ERR" etc.
  0x0040  recovery[768]   recovery arguments (e.g. "recovery\n--wipe_all")
  0x0340  stage[32]       stage indicator
  0x0360  reserved[224]   reserved
  0x0440  reserved2[0x1BC0]  reserved padding to 16KB slot size

Usage:
  python3 scripts/gen-misc-img.py                  # empty misc.img (normal boot)
  python3 scripts/gen-misc-img.py --wipe-all       # recovery + wipe_all
  python3 scripts/gen-misc-img.py --cmd CMD --recovery ARGS  # custom
  python3 scripts/gen-misc-img.py -o /path/to/misc.img       # custom output
"""

import argparse
import struct
import sys
import os

# This matches the config.cfg misc partition size
MISC_PARTITION_SIZE = 0xC000  # 48KB

# Each slot in bootloader_message_ab is 16KB
SLOT_SIZE = 0x4000  # 16KB

# bootloader_message struct offsets
OFFSET_COMMAND = 0x0000
OFFSET_STATUS = 0x0020
OFFSET_RECOVERY = 0x0040
OFFSET_STAGE = 0x0340
OFFSET_RESERVED = 0x0360

SIZE_COMMAND = 32
SIZE_STATUS = 32
SIZE_RECOVERY = 768  # 0x300
SIZE_STAGE = 32
SIZE_RESERVED = 224  # 0xE0

# Padding from end of reserved to end of 16KB slot
OFFSET_RESERVED2 = 0x0440  # == OFFSET_RESERVED + SIZE_RESERVED


def pack_field(field_bytes, size):
    """Pack a bytes field into exactly 'size' bytes, zero-padded or truncated."""
    if isinstance(field_bytes, str):
        field_bytes = field_bytes.encode("utf-8")
    if len(field_bytes) > size:
        field_bytes = field_bytes[:size]
    return field_bytes.ljust(size, b"\x00")


def build_slot(command: bytes, status: bytes, recovery: bytes, stage: bytes):
    """Build one 16KB bootloader_message_ab slot."""
    buf = bytearray(SLOT_SIZE)

    buf[OFFSET_COMMAND:OFFSET_COMMAND + SIZE_COMMAND] = pack_field(command, SIZE_COMMAND)
    buf[OFFSET_STATUS:OFFSET_STATUS + SIZE_STATUS] = pack_field(status, SIZE_STATUS)
    buf[OFFSET_RECOVERY:OFFSET_RECOVERY + SIZE_RECOVERY] = pack_field(recovery, SIZE_RECOVERY)
    buf[OFFSET_STAGE:OFFSET_STAGE + SIZE_STAGE] = pack_field(stage, SIZE_STAGE)
    buf[OFFSET_RESERVED:OFFSET_RESERVED + SIZE_RESERVED] = pack_field(b"", SIZE_RESERVED)

    return bytes(buf)


def build_misc_image(command: bytes, status: bytes, recovery: bytes, stage: bytes):
    """Build a complete misc.img with two slots."""
    slot0 = build_slot(command, status, recovery, stage)
    slot1 = build_slot(command, status, recovery, stage)

    buf = bytearray(MISC_PARTITION_SIZE)
    buf[0:SLOT_SIZE] = slot0
    buf[SLOT_SIZE:2 * SLOT_SIZE] = slot1

    return bytes(buf)


def main():
    parser = argparse.ArgumentParser(
        description="Generate misc.img for Rockchip RK3588 Android"
    )
    parser.add_argument(
        "-o", "--output",
        default="misc.img",
        help="Output file path (default: misc.img)",
    )
    parser.add_argument(
        "--wipe-all",
        action="store_true",
        help="Generate misc.img that triggers recovery with --wipe_all",
    )
    parser.add_argument(
        "--cmd",
        default=b"",
        help="Bootloader command field content (default: empty)",
    )
    parser.add_argument(
        "--status",
        default=b"",
        help="Status field content (default: empty)",
    )
    parser.add_argument(
        "--recovery",
        default=b"",
        help="Recovery argument field content (default: empty)",
    )
    parser.add_argument(
        "--stage",
        default=b"",
        help="Stage field content (default: empty)",
    )

    args = parser.parse_args()

    if args.wipe_all:
        command = b"boot-recovery"
        recovery = b"recovery\n--wipe_all"
    else:
        command = args.cmd if isinstance(args.cmd, bytes) else args.cmd.encode()
        recovery = args.recovery if isinstance(args.recovery, bytes) else args.recovery.encode()

    status = args.status if isinstance(args.status, bytes) else args.status.encode()
    stage = args.stage if isinstance(args.stage, bytes) else args.stage.encode()

    image = build_misc_image(command, status, recovery, stage)

    with open(args.output, "wb") as f:
        f.write(image)

    print(f"Generated {args.output} ({len(image)} bytes, {len(image)//1024}KB)")
    if command:
        print(f"  command:  {command.decode('utf-8', errors='replace')}")
    if recovery:
        print(f"  recovery: {recovery.decode('utf-8', errors='replace')}")


if __name__ == "__main__":
    main()