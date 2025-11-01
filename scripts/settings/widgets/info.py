import customtkinter as ctk


class Info(ctk.CTkLabel):
    def __init__(self, master, text, image):
        super().__init__(
            master,
            text="\ueac5",
            font=("tabler-icons", 20),
            fg_color="transparent",
            text_color=("gray30", "gray30"),
        )
        self.popupText = text
        self.tip_window = None
        self.bind("<Enter>", self.show_tip)
        self.bind("<Leave>", self.hide_tip)

    def show_tip(self, event=None):
        if self.tip_window or not self.popupText:
            return
        x = self.winfo_rootx() + 20
        y = self.winfo_rooty() + self.winfo_height() + 10
        self.tip_window = tw = ctk.CTkToplevel(self)
        tw.title("pShell: Settings - hint")
        tw.wm_overrideredirect(True)
        tw.wm_geometry(f"+{x}+{y}")
        popup = InfoPopup(tw, text=self.popupText)
        popup.pack()

    def hide_tip(self, event=None):
        if self.tip_window:
            self.tip_window.destroy()
            self.tip_window = None


class InfoPopup(ctk.CTkFrame):
    def __init__(self, master, text, image=None):
        super().__init__(master, fg_color="gray10", corner_radius=15)
        self.label = ctk.CTkLabel(
            self, text=text, fg_color="transparent", font=("Dank Mono", 15)
        )
        self.label.pack(side="left", padx=10, pady=10)
