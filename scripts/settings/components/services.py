import customtkinter as ctk

from widgets.navigation_button import NavigationButton
from widgets.tab import Tab

moduleName = "Services"


class ServicesTab(Tab):
    def __init__(self, master):
        super().__init__(master, moduleName)


class ServicesNavigationButton(NavigationButton):
    def __init__(self, master, command):
        super().__init__(master, icon="\ueb20", text=moduleName, command=command)
