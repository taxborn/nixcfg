"""Counter regressions: guest CPU time, cache accounting and link resets."""

import unittest

from stats import cpu_counters, cpu_usage, memory, rates


class CountersTest(unittest.TestCase):
    def test_guest_ticks_are_not_counted_twice(self):
        self.assertEqual(cpu_counters("cpu 10 2 3 40 5 1 2 0 8 1\n"), {"cpu": (63, 45)})

    def test_usage_requires_two_samples(self):
        self.assertIsNone(cpu_usage({}, {"cpu": (100, 20)})["cpu"])
        self.assertEqual(cpu_usage({"cpu": (100, 20)}, {"cpu": (200, 60)})["cpu"], 60)
        self.assertIsNone(cpu_usage({"cpu": (100, 20)}, {"cpu": (50, 10)})["cpu"])

    def test_memory_uses_available_including_reclaimable_cache(self):
        result = memory("MemTotal: 1000 kB\nMemFree: 100 kB\nMemAvailable: 600 kB\nSwapTotal: 100 kB\nSwapFree: 80 kB\n")
        self.assertEqual(result["percent"], 40)
        self.assertEqual(result["swapUsed"], 20 * 1024)

    def test_network_reset_and_new_interface_do_not_spike(self):
        self.assertEqual(rates({"eth0": (100, 100)}, {"eth0": (300, 150)}, 2),
                         [{"name": "eth0", "down": 100, "up": 25}])
        self.assertEqual(rates({"eth0": (100, 100)}, {"eth0": (0, 0)}, 2)[0]["down"], 0)
        self.assertEqual(rates({}, {"eth1": (90000, 60000)}, 2)[0]["up"], 0)
        self.assertEqual(rates({}, {}, 0), [])


if __name__ == "__main__":
    unittest.main()
