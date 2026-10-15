#!/usr/bin/env python3
"""Small assembler for the instruction subset used by this course project."""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple


R_OPS = {
    "add": (0b000, 0b0000000),
    "sll": (0b001, 0b0000000),
    "slt": (0b010, 0b0000000),
    "sltu": (0b011, 0b0000000),
    "xor": (0b100, 0b0000000),
    "srl": (0b101, 0b0000000),
    "sra": (0b101, 0b0100000),
    "or": (0b110, 0b0000000),
    "and": (0b111, 0b0000000),
}

I_OPS = {
    "addi": 0b000,
    "slli": 0b001,
    "ori": 0b110,
    "srli": 0b101,
    "srai": 0b101,
}

BRANCH_OPS = {
    "beq": 0b000,
    "bne": 0b001,
    "blt": 0b100,
    "bge": 0b101,
}


def parse_int(text: str) -> int:
    text = text.strip().replace("_", "")
    return int(text, 0)


def parse_reg(text: str) -> int:
    token = text.strip().lower()
    if not token.startswith("x"):
        raise ValueError(f"expected x-register, got {text!r}")
    number = int(token[1:])
    if not 0 <= number <= 31:
        raise ValueError(f"register out of range: {text!r}")
    return number


def split_operands(text: str) -> List[str]:
    result: List[str] = []
    current: List[str] = []
    depth = 0
    for char in text:
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        if char == "," and depth == 0:
            result.append("".join(current).strip())
            current = []
        else:
            current.append(char)
    if current:
        result.append("".join(current).strip())
    return result


def encode_r(funct3: int, funct7: int, rd: int, rs1: int, rs2: int) -> int:
    return (
        (funct7 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (rd << 7)
        | 0x33
    )


def encode_i(funct3: int, rd: int, rs1: int, imm: int) -> int:
    imm &= 0xFFF
    return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0x13


def encode_load_store(funct3: int, rs1: int, rs2_or_rd: int, imm: int, store: bool) -> int:
    imm &= 0xFFF
    if store:
        return (
            ((imm >> 5) & 0x7F) << 25
            | (rs2_or_rd << 20)
            | (rs1 << 15)
            | (funct3 << 12)
            | ((imm & 0x1F) << 7)
            | 0x23
        )
    return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rs2_or_rd << 7) | 0x03


def encode_branch(funct3: int, rs1: int, rs2: int, imm: int) -> int:
    if imm & 1:
        raise ValueError("branch target must be 2-byte aligned")
    imm &= 0x1FFF
    bit12 = (imm >> 12) & 1
    bit11 = (imm >> 11) & 1
    bits10_5 = (imm >> 5) & 0x3F
    bits4_1 = (imm >> 1) & 0xF
    return (
        (bit12 << 31)
        | (bits10_5 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (bits4_1 << 8)
        | (bit11 << 7)
        | 0x63
    )


def encode_jal(rd: int, imm: int) -> int:
    if imm & 1:
        raise ValueError("jump target must be 2-byte aligned")
    imm &= 0x1FFFFF
    bit20 = (imm >> 20) & 1
    bits10_1 = (imm >> 1) & 0x3FF
    bit11 = (imm >> 11) & 1
    bits19_12 = (imm >> 12) & 0xFF
    return (
        (bit20 << 31)
        | (bits10_1 << 21)
        | (bit11 << 20)
        | (bits19_12 << 12)
        | (rd << 7)
        | 0x6F
    )


def parse_memory_operand(text: str) -> Tuple[int, int]:
    match = re.fullmatch(r"(.+?)\((.+?)\)", text.strip())
    if not match:
        raise ValueError(f"expected offset(base), got {text!r}")
    return parse_int(match.group(1)), parse_reg(match.group(2))


def encode_instruction(
    mnemonic: str,
    operands: Sequence[str],
    pc: int,
    symbols: Dict[str, int],
) -> int:
    mnemonic = mnemonic.lower()

    if mnemonic in R_OPS:
        if len(operands) != 3:
            raise ValueError(f"{mnemonic} requires 3 operands")
        funct3, funct7 = R_OPS[mnemonic]
        return encode_r(
            funct3,
            funct7,
            parse_reg(operands[0]),
            parse_reg(operands[1]),
            parse_reg(operands[2]),
        )

    if mnemonic in I_OPS:
        if len(operands) != 3:
            raise ValueError(f"{mnemonic} requires 3 operands")
        rd = parse_reg(operands[0])
        rs1 = parse_reg(operands[1])
        imm = parse_int(operands[2])
        funct3 = I_OPS[mnemonic]
        if mnemonic in {"slli", "srli", "srai"}:
            if not 0 <= imm <= 31:
                raise ValueError("shift amount must be in 0..31")
            if mnemonic == "srai":
                imm |= 0x400
        return encode_i(funct3, rd, rs1, imm)

    if mnemonic == "lw":
        if len(operands) != 2:
            raise ValueError("lw requires 2 operands")
        rd = parse_reg(operands[0])
        imm, rs1 = parse_memory_operand(operands[1])
        return encode_load_store(0b010, rs1, rd, imm, store=False)

    if mnemonic == "sw":
        if len(operands) != 2:
            raise ValueError("sw requires 2 operands")
        rs2 = parse_reg(operands[0])
        imm, rs1 = parse_memory_operand(operands[1])
        return encode_load_store(0b010, rs1, rs2, imm, store=True)

    if mnemonic in BRANCH_OPS:
        if len(operands) != 3:
            raise ValueError(f"{mnemonic} requires 3 operands")
        rs1 = parse_reg(operands[0])
        rs2 = parse_reg(operands[1])
        target = operands[2].strip()
        if target in symbols:
            offset = symbols[target] - pc
        else:
            offset = parse_int(target)
        return encode_branch(BRANCH_OPS[mnemonic], rs1, rs2, offset)

    if mnemonic == "lui":
        if len(operands) != 2:
            raise ValueError("lui requires 2 operands")
        rd = parse_reg(operands[0])
        imm = parse_int(operands[1]) & 0xFFFFF
        return (imm << 12) | (rd << 7) | 0x37

    if mnemonic == "auipc":
        if len(operands) != 2:
            raise ValueError("auipc requires 2 operands")
        rd = parse_reg(operands[0])
        imm = parse_int(operands[1]) & 0xFFFFF
        return (imm << 12) | (rd << 7) | 0x17

    if mnemonic == "jal":
        if len(operands) != 2:
            raise ValueError("jal requires 2 operands")
        rd = parse_reg(operands[0])
        target = operands[1].strip()
        if target in symbols:
            offset = symbols[target] - pc
        else:
            offset = parse_int(target)
        return encode_jal(rd, offset)

    if mnemonic == "mac":
        if len(operands) != 3:
            raise ValueError("mac requires 3 operands")
        return encode_r(
            0b000,
            0b0000000,
            parse_reg(operands[0]),
            parse_reg(operands[1]),
            parse_reg(operands[2]),
        ) & ~0x7F | 0x0B

    raise ValueError(f"unsupported instruction: {mnemonic}")


def assemble_text(source: str) -> Tuple[List[int], Dict[str, int]]:
    parsed: List[Tuple[str, List[str], int]] = []
    symbols: Dict[str, int] = {}
    pc = 0

    for line_number, raw_line in enumerate(source.splitlines(), 1):
        line = raw_line.split("#", 1)[0].split(";", 1)[0].strip()
        if not line:
            continue

        while True:
            label_match = re.match(r"([A-Za-z_.$][\w.$]*):", line)
            if not label_match:
                break
            label = label_match.group(1)
            if label in symbols:
                raise ValueError(f"line {line_number}: duplicate label {label!r}")
            symbols[label] = pc
            line = line[label_match.end():].strip()
            if not line:
                break

        if not line:
            continue

        parts = line.split(None, 1)
        mnemonic = parts[0].lower()
        operands = split_operands(parts[1]) if len(parts) > 1 else []

        if mnemonic == ".word":
            for operand in operands:
                parsed.append((".word", [operand], pc))
                pc += 4
        else:
            parsed.append((mnemonic, operands, pc))
            pc += 4

    words: List[int] = []
    for mnemonic, operands, instruction_pc in parsed:
        if mnemonic == ".word":
            word = parse_int(operands[0]) & 0xFFFF_FFFF
        else:
            word = encode_instruction(mnemonic, operands, instruction_pc, symbols)
        words.append(word & 0xFFFF_FFFF)

    return words, symbols


def words_to_hex(words: Iterable[int]) -> str:
    return "\n".join(f"{word:08x}" for word in words) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("-o", "--output", type=Path, required=True)
    args = parser.parse_args()

    words, _ = assemble_text(args.source.read_text(encoding="utf-8"))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(words_to_hex(words), encoding="ascii")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
