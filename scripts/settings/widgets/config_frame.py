import customtkinter as ctk
from widgets.colors import colors
from widgets.fonts import fonts
from widgets.info import Info

class ConfigFrame(ctk.CTkFrame):
    def __init__(self, master, key, default, changed, icon=None, text=None, hintImage=None, hintText=None):
        super().__init__(master, fg_color="transparent")

        self._data = { 'icon': icon, 'text': text, 'hintImage': hintImage, 'hintText': hintText, 'key': key, 'default': default, 'changed': changed }

        self._text_color = colors.onSurface
        self._icon_color = colors.onSurfaceVariant


        self.columnconfigure(1, weight=1)

        if icon:
            self._icon = ctk.CTkLabel(
                self,
                text=self._data['icon'],
                corner_radius=0,
                fg_color='transparent',
                text_color=self._icon_color,
                font=(fonts.icons, 20)
            )
            self._icon.grid(row=0, column=0, padx=0, pady=0, sticky="nsew")

        if text:
            self._text = ctk.CTkLabel(
                self,
                text=self._data['text'],
                corner_radius=0,
                fg_color='transparent',
                text_color=self._text_color,
                font=(fonts.text, 14)
            )
            self._text.grid(row=0, column=1, padx=5, pady=10, sticky="w")

        if hintText or hintImage:
            self._hint = Info(self, self._data['hintText'], self._data['hintImage'])
            self._hint.grid(row=0, column=2, padx=5, pady=0, sticky="e")

    


