import unittest

from assemble import assemble_text


class AssembleTests(unittest.TestCase):
    def test_base_r_type(self):
        words, _ = assemble_text("add x3, x1, x2\n")
        self.assertEqual(words, [0x002081B3])

    def test_shift_immediate(self):
        words, _ = assemble_text("srai x5, x6, 3\n")
        self.assertEqual(words, [0x40335293])

    def test_load_and_store(self):
        words, _ = assemble_text("lw x5, 8(x6)\nsw x5, 8(x6)\n")
        self.assertEqual(words, [0x00832283, 0x00532423])

    def test_branch_label(self):
        words, _ = assemble_text(
            "beq x1, x2, target\n"
            "ori x5, x0, 1\n"
            "target:\n"
            "ori x6, x0, 2\n"
        )
        self.assertEqual(words[0], 0x00208463)

    def test_jump_label(self):
        words, _ = assemble_text(
            "jal x1, target\n"
            "lui x2, 0x12345\n"
            "target:\n"
            "ori x3, x0, 7\n"
        )
        self.assertEqual(words[0], 0x008000EF)

    def test_custom_mac(self):
        words, _ = assemble_text("mac x3, x1, x2\n")
        self.assertEqual(words, [0x0020818B])


if __name__ == "__main__":
    unittest.main()

