import customtkinter as ctk

from widgets.config_frame import ConfigFrame
from widgets.switch import Switch


class ConfigSwitch(ConfigFrame):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.switch = Switch(self, True, True)
        self.switch.grid(row=0, column=3, padx=0, pady=0, sticky="e")

