import customtkinter as ctk

from widgets.navigation_button import NavigationButton
from widgets.tab import Tab

moduleName = "Quick"


class QuickTab(Tab):
    def __init__(self, master):
        super().__init__(master, moduleName)


class QuickNavigationButton(NavigationButton):
    def __init__(self, master, command):
        super().__init__(master, icon="\uf6ec", text=moduleName, command=command)
