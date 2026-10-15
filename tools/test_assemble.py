"""汇编器单元测试。

每个测试给定一段汇编源码，并比较生成的机器码是否与标准 RISC-V 编码一致。
这些测试不依赖 ModelSim，可快速发现字段顺序或立即数偏移错误。
"""

import unittest

from assemble import assemble_text


class AssembleTests(unittest.TestCase):
    """覆盖 R/I/S/B/J 和定制指令的关键编码格式。"""

    def test_base_r_type(self):
        """验证 R 型 add 的 rd、rs1、rs2 字段布局。"""
        words, _ = assemble_text("add x3, x1, x2\n")
        self.assertEqual(words, [0x002081B3])

    def test_shift_immediate(self):
        """验证 srai 的 funct7 和 shamt 立即数字段。"""
        words, _ = assemble_text("srai x5, x6, 3\n")
        self.assertEqual(words, [0x40335293])

    def test_load_and_store(self):
        """验证 lw/sw 的 offset(base) 编码。"""
        words, _ = assemble_text("lw x5, 8(x6)\nsw x5, 8(x6)\n")
        self.assertEqual(words, [0x00832283, 0x00532423])

    def test_branch_label(self):
        """验证分支标签相对当前 PC 的偏移和 B 型位段拆分。"""
        words, _ = assemble_text(
            "beq x1, x2, target\n"
            "ori x5, x0, 1\n"
            "target:\n"
            "ori x6, x0, 2\n"
        )
        self.assertEqual(words[0], 0x00208463)

    def test_jump_label(self):
        """验证 jal 标签偏移和 J 型位段拆分。"""
        words, _ = assemble_text(
            "jal x1, target\n"
            "lui x2, 0x12345\n"
            "target:\n"
            "ori x3, x0, 7\n"
        )
        self.assertEqual(words[0], 0x008000EF)

    def test_custom_mac(self):
        """验证定制 mac 使用 custom-0 opcode。"""
        words, _ = assemble_text("mac x3, x1, x2\n")
        self.assertEqual(words, [0x0020818B])


if __name__ == "__main__":
    unittest.main()

