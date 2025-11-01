import customtkinter as ctk


class Tab(ctk.CTkScrollableFrame):
    def __init__(self, master, tabName):
        super().__init__(master, corner_radius=0, fg_color="transparent")
        self.tabName = tabName
        self.headerPadX = 10
        self.headerPadY = 5
        self.elemPadX = 10
        self.elemPadY = 0

    def is_me(self, text):
        return text == self.tabName
