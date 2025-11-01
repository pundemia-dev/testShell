import customtkinter as ctk

from components.about import AboutNavigationButton, AboutTab
from components.advanced import AdvancedNavigationButton, AdvancedTab
from components.Bar import BarNavigationButton, BarTab
from components.general import GeneralNavigationButton, GeneralTab
from components.interface import InterfaceNavigationButton, InterfaceTab
from components.quick import QuickNavigationButton, QuickTab
from components.services import ServicesNavigationButton, ServicesTab
from widgets.colors import colors

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")


class App(ctk.CTk):
    def __init__(self):
        super().__init__(fg_color=colors.surfaceContainerLowest)

        # App
        self.title("pShell: Settings")
        self.geometry(f"{750}x{500}")

        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(1, weight=1)

        # Grid
        self.titleFrame = ctk.CTkFrame(self, fg_color="transparent")
        self.titleFrame.columnconfigure(0, weight=1)
        self.titleFrame.columnconfigure(1, weight=0)
        self.titleFrame.grid(
            row=0, column=0, columnspan=2, padx=5, pady=(5, 0), sticky="nsew"
        )

        self.navigation_frame = ctk.CTkFrame(
            self, corner_radius=0, fg_color="transparent"
        )
        self.navigation_frame.grid(row=1, column=0, sticky="nsew")

        self.contentFrame = ctk.CTkFrame(
            self, corner_radius=15, fg_color=colors.surfaceContainerLow
        )
        self.contentFrame.columnconfigure(0, weight=1)
        self.contentFrame.rowconfigure(0, weight=1)
        self.contentFrame.grid(
            row=1, column=1, padx=(0, 10), pady=(0, 10), sticky="nsew"
        )

        # Title Bar
        self.appNameLabel = ctk.CTkLabel(
            self.titleFrame,
            text="Settings",
            font=("Dank Mono", 20),
            fg_color="transparent",
            text_color=colors.onSurface,
        )
        self.appNameLabel.grid(row=0, column=0, padx=5, pady=5, sticky="nsew")

        self.quitButton = ctk.CTkButton(
            self.titleFrame,
            text="\ueb55",
            width=35,
            height=35,
            border_spacing=0,
            corner_radius=10,
            hover_color=colors.errorContainer,
            text_color=colors.outline,
            fg_color="transparent",
            font=("tabler-icons", 15),
            anchor="center",
            command=self.destroy,
        )
        self.quitButton.bind(
            "<Enter>",
            lambda _: self.quitButton.configure(
                text_color=colors.error, fg_color=colors.errorContainer
            ),
        )
        self.quitButton.bind(
            "<Leave>",
            lambda _: self.quitButton.configure(
                text_color=colors.outline, fg_color="transparent"
            ),
        )
        self.quitButton.grid(row=0, column=1, sticky="w")

        # Navigation
        self.unset_func = None
        self.navigationButtons = []
        for ind, buttonClass in enumerate(
            [
                QuickNavigationButton,
                GeneralNavigationButton,
                BarNavigationButton,
                InterfaceNavigationButton,
                ServicesNavigationButton,
                AdvancedNavigationButton,
                AboutNavigationButton,
            ]
        ):
            button = buttonClass(
                self.navigation_frame, command=self.select_frame_by_name
            )
            button.grid(row=ind + 2, column=0, padx=10, pady=0, sticky="nw")

        # Tabs
        self.currentTab = None
        self.tabs = []
        for tabClass in [
            QuickTab,
            GeneralTab,
            BarTab,
            InterfaceTab,
            ServicesTab,
            AdvancedTab,
            AboutTab,
        ]:
            tab = tabClass(self.contentFrame)
            self.tabs.append(tab)

        # Default tab
        self.select_frame_by_name("About", None)

    def select_frame_by_name(self, name, unset_func):
        for tab in self.tabs:
            if tab.is_me(name):
                tab.grid(row=0, column=0, padx=20, pady=20, sticky="nsew")
                if self.currentTab:
                    self.currentTab.grid_forget()
                    if self.unset_func:
                        self.unset_func()
                self.unset_func = unset_func
                self.currentTab = tab


if __name__ == "__main__":
    app = App()
    app.mainloop()
