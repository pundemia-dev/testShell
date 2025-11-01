import customtkinter as ctk

from widgets.config_frame import ConfigFrame
from widgets.button_radiobutton import BRadioButton


class ConfigRadiobutton(ConfigFrame):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.radiobutton = BRadioButton(self, ["\uf2a8", "\uf2aa", "\uf2ab", "\uf2a9"], default=0)
        self.radiobutton.grid(row=0, column=3, padx=0, pady=0, sticky="e")


