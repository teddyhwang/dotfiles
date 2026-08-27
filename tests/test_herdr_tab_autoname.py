import importlib.machinery
import importlib.util
import pathlib
import unittest

SCRIPT = pathlib.Path(__file__).parents[1] / "home/local/bin/herdr-tab-autoname"
loader = importlib.machinery.SourceFileLoader("herdr_tab_autoname", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
if spec is None:
    raise RuntimeError(f"Could not load {SCRIPT}")
autoname = importlib.util.module_from_spec(spec)
loader.exec_module(autoname)


class HerdrTabAutonameTest(unittest.TestCase):
    def pi_pane(self, title="π - Fix session labels - dotfiles"):
        return {
            "agent": "pi",
            "cwd": "/src/dotfiles",
            "pane_id": "w1:p1",
            "terminal_title_stripped": title,
        }

    def test_extracts_pi_session_name_from_terminal_title(self):
        pane = self.pi_pane()
        self.assertEqual(
            autoname.pi_session_name_from_title(pane), "Fix session labels"
        )
        self.assertEqual(
            autoname.pi_session_label_for([pane]), "Fix session labels"
        )

    def test_rejects_generic_pi_title(self):
        pane = self.pi_pane("π - dotfiles")
        self.assertIsNone(autoname.pi_session_name_from_title(pane))
        self.assertIsNone(autoname.topic_from_title(pane))

    def test_adopts_a_direct_pi_extension_rename(self):
        session = object.__new__(autoname.Session)
        session.assigned = {"w1:t1": "dotfiles"}
        session.renamed_at = {}
        session.consider(
            {"tab_id": "w1:t1", "label": "Fix session labels"},
            [self.pi_pane()],
        )
        self.assertEqual(session.assigned["w1:t1"], "Fix session labels")

    def test_still_treats_other_labels_as_manual(self):
        session = object.__new__(autoname.Session)
        session.assigned = {"w1:t1": "dotfiles"}
        session.renamed_at = {}
        session.consider(
            {"tab_id": "w1:t1", "label": "My manual name"},
            [self.pi_pane()],
        )
        self.assertNotIn("w1:t1", session.assigned)


if __name__ == "__main__":
    unittest.main()
