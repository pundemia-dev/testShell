import customtkinter as ctk

from widgets.config_frame import ConfigFrame
from widgets.optionmenu import OptionMenu

class ConfigOptionMenu(ConfigFrame):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.optionMenu = OptionMenu(
            self,
            values=["Undefined", "Off", "On"],
            icons=["\uec9d", "\ueb55", "\uea5e"],
            default=0
        )
        self.optionMenu.grid(row=0, column=3, padx=0, pady=0, sticky="e")
