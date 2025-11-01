import customtkinter as ctk

from widgets.colors import colors


class Switch(ctk.CTkFrame):
    def __init__(self, master, onvalue, offvalue):
        self.colors = (colors.tertiary, colors.tertiaryContainer)
        self.first_color = colors.tertiary
        self.second_color = colors.tertiaryContainer
        self.hover_color = colors.error
        self.position = True
        self.buttonPad = 3
        super().__init__(
            master,
            width=100,
            height=30,
            fg_color=self.colors[not self.position],
            corner_radius=100,
        )
        # self.columnconfigure(1, weight=1)
        self.button = ctk.CTkFrame(
            self,
            width=15,
            height=15,
            fg_color=self.colors[self.position],
            corner_radius=15,
        )
        self.fill = ctk.CTkFrame(
            self, width=5, height=5, fg_color="transparent", corner_radius=15
        )
        self.fill.grid(
            row=0, column=1, padx=self.buttonPad, pady=self.buttonPad, sticky="nsew"
        )
        self.bind("<Button>", self.toggle)
        self.button.bind("<Button>", self.toggle)
        self.fill.bind("<Button>", self.toggle)
        self.toggle(False)

    def toggle(self, _):
        self.position = not self.position
        self.button.grid_forget()
        self.button.grid(
            row=0,
            column=0 if self.position else 2,
            padx=self.buttonPad,
            pady=self.buttonPad,
            sticky="nsew",
        )
        self.configure(fg_color=self.colors[not self.position])
        self.button.configure(fg_color=self.colors[self.position])
        # self.button.pack_forget()
        # self.button.pack(side=["left", "right"][self.position], padx=self.buttonPad, pady=self.buttonPad)
