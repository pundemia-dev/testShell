import customtkinter as ctk

from widgets.colors import colors


class NavigationButton(ctk.CTkFrame):
    def __init__(self, master, icon, text, command):
        super().__init__(
            master,
            # height=300,
            fg_color="transparent",
            corner_radius=100,
        )
        self.selected = False
        self.command = command
        self.text = text
        self.hover_color = colors.inverseOnSurface
        self.text_color = colors.onSurfaceVariant
        self.icon_color = colors.onSurface
        self.selected_frame_color = colors.primaryContainer
        self.selected_label_color = colors.onPrimaryContainer
        self.rowconfigure(0, weight=0)
        self.columnconfigure(1, weight=1)

        self.icon = ctk.CTkLabel(
            self,
            text=icon,
            #  width=30,
            height=40,
            corner_radius=0,
            fg_color="transparent",
            text_color=self.icon_color,
            font=("tabler-icons", 25),
        )
        self.icon.grid(row=0, column=0, padx=(20, 5), pady=10, sticky="nsew")

        self.label = ctk.CTkLabel(
            self,
            text=self.text,
            corner_radius=0,
            fg_color="transparent",
            text_color=self.text_color,
            font=("Dank Mono", 15),
        )
        self.label.grid(row=0, column=1, padx=(5, 20), pady=10, sticky="nsew")

        self.bind("<Enter>", self.on_hover_enter)
        self.bind("<Leave>", self.on_hover_leave)
        self.icon.bind("<Enter>", self.on_hover_enter)
        self.icon.bind("<Leave>", self.on_hover_leave)
        self.label.bind("<Enter>", self.on_hover_enter)
        self.label.bind("<Leave>", self.on_hover_leave)
        self.icon.bind("<Button>", self.set_tab)
        self.label.bind("<Button>", self.set_tab)
        self.bind("<Button>", self.set_tab)

    def set_tab(self, _):
        if not self.selected:
            self.configure(fg_color=self.selected_frame_color)
            self.icon.configure(text_color=self.selected_label_color)
            self.label.configure(text_color=self.selected_label_color)
            self.selected = True
            self.command(self.text, self.unset_tab)

    def unset_tab(self):
        self.selected = False
        self.icon.configure(text_color=self.icon_color)
        self.label.configure(text_color=self.text_color)
        self.configure(fg_color="transparent")

    def on_hover_enter(self, _):
        if not self.selected:
            self.configure(fg_color=self.hover_color)

    def on_hover_leave(self, _):
        if not self.selected:
            self.configure(fg_color="transparent")
