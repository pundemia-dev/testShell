import customtkinter as ctk

from widgets.navigation_button import NavigationButton
from widgets.tab import Tab

moduleName = "General"


class GeneralTab(Tab):
    def __init__(self, master):
        super().__init__(master, moduleName)


class GeneralNavigationButton(NavigationButton):
    def __init__(self, master, command):
        super().__init__(master, icon="\ufe1f", text=moduleName, command=command)
