import customtkinter as ctk

from widgets.navigation_button import NavigationButton
from widgets.tab import Tab

moduleName = "Advanced"


class AdvancedTab(Tab):
    def __init__(self, master):
        super().__init__(master, moduleName)
        self.configure(fg_color="red")


class AdvancedNavigationButton(NavigationButton):
    def __init__(self, master, command):
        super().__init__(master, icon="\uf577", text=moduleName, command=command)
