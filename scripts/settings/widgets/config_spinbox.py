import customtkinter as ctk

from widgets.config_frame import ConfigFrame
from widgets.spinbox import Spinbox


class ConfigSpinbox(ConfigFrame):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.spinbox = Spinbox(self, True, True)
        self.spinbox.grid(row=0, column=3, padx=0, pady=0, sticky="e")

