import customtkinter as ctk

from widgets.navigation_button import NavigationButton
from widgets.tab import Tab

moduleName = "About"


class AboutTab(Tab):
    def __init__(self, master):
        super().__init__(master, moduleName)


class AboutNavigationButton(NavigationButton):
    def __init__(self, master, command):
        super().__init__(master, icon="\ueac5", text=moduleName, command=command)
