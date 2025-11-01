import customtkinter as ctk

from widgets.colors import colors


class BRadioButton(ctk.CTkFrame):
    def __init__(self, master, icons, default=0, keys=[]):
        super().__init__(master, fg_color="transparent")
        self.selected = default
        self.button_color = colors.onSecondaryContainer
        self.text_color = colors.secondaryContainer
        self.hover_color = colors.secondary
        self.selected_button_color = self.text_color
        self.selected_text_color = self.button_color

        self.buttons = []
        # icons.reverse()
        for ind, icon in enumerate(icons):
            ind = len(icons) - 1 - ind
            button = ctk.CTkButton(
                self,
                width=30,
                height=30,
                text=icon,
                hover_color=self.hover_color,
                border_spacing=0,
                # hover
                fg_color=self.button_color,
                text_color=self.text_color,
                corner_radius=10,
                font=("tabler-icons", 18),
                command=lambda ind=ind: self.select(ind),
            )
            button.pack(side="right", padx=5)
            self.buttons.append(button)

        self.buttons.reverse()

        self.select(self.selected)

    def select(self, ind):
        self.buttons[self.selected].configure(
            text_color=self.text_color, fg_color=self.button_color, state="normal"
        )
        self.buttons[ind].configure(
            text_color=self.selected_text_color,
            fg_color=self.selected_button_color,
            state="disabled",
        )
        self.selected = ind
