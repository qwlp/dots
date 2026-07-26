import sublime_plugin


class VintageCenteredScrollCommand(sublime_plugin.TextCommand):
    def run(self, edit, forward=True):
        self.view.run_command("vi_scroll_lines", {"forward": forward})
        self.view.run_command("center_on_cursor")
