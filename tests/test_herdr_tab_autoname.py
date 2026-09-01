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

    def agent_pane(self, title, pane_id="w1:p2", agent="claude"):
        return {
            "agent": agent,
            "cwd": "/src/dotfiles",
            "pane_id": pane_id,
            "terminal_title_stripped": title,
        }

    def shell_pane(self, pane_id="w1:p2"):
        return {
            "cwd": "/src/dotfiles",
            "pane_id": pane_id,
            "terminal_title_stripped": "zsh",
        }

    def labeler(self, project="dotfiles"):
        session = object.__new__(autoname.Session)
        session.project_label = lambda cwd: project
        return session

    def test_a_lone_topic_labels_the_whole_split(self):
        # A pane that says nothing abstains rather than vetoing, so the one
        # pane doing identifiable work still names the tab.
        session = self.labeler()
        self.assertEqual(
            session.label_for([self.pi_pane(), self.shell_pane()]),
            "Fix session labels",
        )

    def test_agreeing_panes_keep_their_shared_topic(self):
        session = self.labeler()
        panes = [self.pi_pane(), self.agent_pane("Fix session labels")]
        self.assertEqual(session.label_for(panes), "Fix session labels")

    def test_contradicting_panes_fall_back_to_the_project(self):
        session = self.labeler("dotfiles \uf418 split-labels")
        panes = [self.pi_pane(), self.agent_pane("Update the README")]
        self.assertEqual(session.label_for(panes), "dotfiles \uf418 split-labels")

    def test_recomputes_from_what_survives_a_pane_exit(self):
        session = self.labeler()
        # While Pi runs beside another agent the tab cannot name either one.
        panes = [self.pi_pane(), self.agent_pane("Update the README")]
        self.assertEqual(session.label_for(panes), "dotfiles")
        # Pi exits; Herdr drops the pane and the survivor gets to speak.
        self.assertEqual(
            session.label_for([self.agent_pane("Update the README")]),
            "Update the README",
        )

    def test_every_harness_is_a_peer_in_the_topic_vote(self):
        # Pi is not privileged over Claude, Codex or anyone else: whichever
        # agent is the only one saying something names the tab.
        session = self.labeler()
        for agent in ("claude", "codex", "gemini", "opencode"):
            with self.subTest(agent=agent):
                panes = [
                    self.agent_pane("Refactor the auth module", "w1:p1", agent),
                    self.shell_pane("w1:p2"),
                ]
                self.assertEqual(
                    session.label_for(panes), "Refactor the auth module"
                )

    def test_a_generic_agent_title_abstains_instead_of_vetoing(self):
        # "codex"/"Claude" name the harness, not the work, so they neither
        # claim the tab nor block the pane that is doing something.
        session = self.labeler()
        panes = [
            self.agent_pane("Tab renaming for herdr splits", "w1:p1", "claude"),
            self.agent_pane("codex", "w1:p2", "codex"),
        ]
        self.assertEqual(session.label_for(panes), "Tab renaming for herdr splits")
        both_generic = [
            self.agent_pane("Claude", "w1:p1", "claude"),
            self.agent_pane("codex", "w1:p2", "codex"),
        ]
        self.assertEqual(session.label_for(both_generic), "dotfiles")

    def test_two_harnesses_on_different_work_fall_back(self):
        session = self.labeler()
        panes = [
            self.agent_pane("Tab renaming for herdr splits", "w1:p1", "claude"),
            self.agent_pane("Refactor the auth module", "w1:p2", "codex"),
        ]
        self.assertEqual(session.label_for(panes), "dotfiles")

    def test_only_pi_is_trusted_without_agent_detection(self):
        # Pi's "π - NAME - cwd" shape can only come from Pi, so it is safe
        # before Herdr classifies the pane. A bare topic is indistinguishable
        # from a shell running a command, so it needs the agent field.
        session = self.labeler()
        undetected_pi = dict(self.pi_pane(), agent=None)
        self.assertEqual(session.label_for([undetected_pi]), "Fix session labels")
        self.assertEqual(
            session.label_for([dict(self.agent_pane("vim src/main.rs"), agent=None)]),
            "dotfiles",
        )

    def test_ignores_a_pi_rename_that_speaks_over_a_split(self):
        # The extension should not have renamed here, but a stale label from a
        # pane that was alone a moment ago must not be adopted as ours.
        session = object.__new__(autoname.Session)
        session.assigned = {}
        session.renamed_at = {}
        session.consider(
            {"tab_id": "w1:t1", "label": "Fix session labels"},
            [self.pi_pane(), self.agent_pane("Update the README")],
        )
        self.assertNotIn("w1:t1", session.assigned)


if __name__ == "__main__":
    unittest.main()
